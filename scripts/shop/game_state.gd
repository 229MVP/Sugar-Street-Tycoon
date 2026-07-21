extends Node
## Global app/game state: save data, catalog, orders, progression actions.

signal state_changed
signal coins_changed(amount: int)
signal stars_changed(amount: int)
signal reputation_changed(amount: int)
signal experience_changed(current: int, required: int, level: int)
signal order_updated(order_id: String)
signal recipe_unlocked(recipe_id: StringName)
signal equipment_upgraded(equipment_id: StringName, new_level: int)
signal level_up(new_level: int, coin_reward: int)
signal notifications_changed
signal save_completed

const DEBUG_TOOLS_ENABLED := true

var catalog := ContentCatalog.new()
var data: SaveData
var pending_level_ups: Array[Dictionary] = []
var last_completion_rewards: Dictionary = {}
var _busy: bool = false


func _ready() -> void:
	catalog.build()
	if SaveManager.has_save():
		data = SaveManager.load_game()
	else:
		data = SaveData.create_default()
	_ensure_order_board()
	emit_signal("state_changed")


func has_save() -> bool:
	return SaveManager.has_save()


func new_game() -> void:
	data = SaveData.create_default()
	_ensure_order_board()
	save_now()
	state_changed.emit()


func continue_game() -> void:
	data = SaveManager.load_game()
	_ensure_order_board()
	state_changed.emit()


func save_now() -> void:
	SaveManager.save_game(data)
	save_completed.emit()


func reset_save() -> void:
	SaveManager.delete_save()
	data = SaveData.create_default()
	_ensure_order_board()
	save_now()
	state_changed.emit()


func is_busy() -> bool:
	return _busy


func set_busy(value: bool) -> void:
	_busy = value


# ---------------------------------------------------------------------------
# Queries
# ---------------------------------------------------------------------------

func is_recipe_unlocked(recipe_id: StringName) -> bool:
	return bool(data.unlocked_recipes.get(str(recipe_id), false))


func get_equipment_level(equipment_id: StringName) -> int:
	return int(data.equipment_levels.get(str(equipment_id), 1))


func get_ingredient_amount(ingredient_id: StringName) -> int:
	return int(data.ingredients.get(str(ingredient_id), 0))


func get_order_status(order_id: String) -> int:
	return int(data.order_statuses.get(order_id, SaveData.OrderStatus.AVAILABLE))


func get_visible_orders() -> Array[OrderTemplate]:
	var result: Array[OrderTemplate] = []
	for id in data.visible_order_ids:
		var order := catalog.get_order(StringName(id))
		if order:
			result.append(order)
	return result


func can_unlock_recipe(recipe_id: StringName) -> Dictionary:
	var recipe := catalog.get_recipe(recipe_id)
	if recipe == null:
		return {"ok": false, "reason": "Unknown recipe."}
	if is_recipe_unlocked(recipe_id):
		return {"ok": false, "reason": "Already unlocked."}
	if data.player_level < recipe.required_player_level:
		return {"ok": false, "reason": "Requires player level %d." % recipe.required_player_level}
	if data.stars < recipe.required_stars:
		return {"ok": false, "reason": "Requires %d stars." % recipe.required_stars}
	if data.coins < recipe.unlock_coin_cost:
		return {"ok": false, "reason": "Need %s coins." % RewardCalculator.format_coins(recipe.unlock_coin_cost)}
	return {"ok": true, "reason": ""}


func can_upgrade_equipment(equipment_id: StringName) -> Dictionary:
	var eq := catalog.get_equipment(equipment_id)
	if eq == null:
		return {"ok": false, "reason": "Unknown equipment."}
	var level := get_equipment_level(equipment_id)
	if level >= eq.max_level:
		return {"ok": false, "reason": "Maximum level reached."}
	var cost := eq.upgrade_cost_to(level + 1)
	if data.coins < cost:
		return {"ok": false, "reason": "Need %s coins." % RewardCalculator.format_coins(cost)}
	return {"ok": true, "reason": "", "cost": cost, "next_level": level + 1}


func recipe_unlock_available_count() -> int:
	var count := 0
	for id in catalog.recipes.keys():
		if can_unlock_recipe(StringName(id)).get("ok", false):
			count += 1
	return count


func affordable_upgrade_count() -> int:
	var count := 0
	for id in catalog.equipment.keys():
		if can_upgrade_equipment(StringName(id)).get("ok", false):
			count += 1
	return count


func ready_to_complete_count() -> int:
	var count := 0
	for id in data.visible_order_ids:
		if get_order_status(id) == SaveData.OrderStatus.READY_TO_COMPLETE:
			count += 1
	return count


# ---------------------------------------------------------------------------
# Orders
# ---------------------------------------------------------------------------

func select_order(order_id: String) -> bool:
	if _busy:
		return false
	var order := catalog.get_order(StringName(order_id))
	if order == null:
		return false
	if order.requires_recipe_unlocked and not is_recipe_unlocked(order.recipe_id):
		return false
	var status := get_order_status(order_id)
	if status in [SaveData.OrderStatus.COMPLETED, SaveData.OrderStatus.READY_TO_COMPLETE, SaveData.OrderStatus.LEVEL_IN_PROGRESS]:
		return false
	# Clear previous selected if different.
	if data.active_order_id != "" and data.active_order_id != order_id:
		var prev := get_order_status(data.active_order_id)
		if prev == SaveData.OrderStatus.SELECTED or prev == SaveData.OrderStatus.FAILED:
			data.order_statuses[data.active_order_id] = SaveData.OrderStatus.AVAILABLE
	data.active_order_id = order_id
	data.order_statuses[order_id] = SaveData.OrderStatus.SELECTED
	save_now()
	order_updated.emit(order_id)
	state_changed.emit()
	return true


func begin_order_level(order_id: String) -> LevelConfig:
	var order := catalog.get_order(StringName(order_id))
	if order == null:
		return null
	if order.requires_recipe_unlocked and not is_recipe_unlocked(order.recipe_id):
		return null
	var status := get_order_status(order_id)
	if status == SaveData.OrderStatus.COMPLETED or status == SaveData.OrderStatus.READY_TO_COMPLETE:
		return null
	data.active_order_id = order_id
	data.order_statuses[order_id] = SaveData.OrderStatus.LEVEL_IN_PROGRESS
	save_now()
	order_updated.emit(order_id)
	return catalog.get_level(order.level_id)


func on_level_won(order_id: String, score: int, moves_remaining: int, move_limit: int) -> Dictionary:
	var stars_earned := PlayerProgression.calculate_stars(moves_remaining, move_limit)
	var level_id := ""
	var order := catalog.get_order(StringName(order_id))
	if order:
		level_id = order.level_id
	data.order_statuses[order_id] = SaveData.OrderStatus.READY_TO_COMPLETE
	data.order_level_results[order_id] = {
		"score": score,
		"moves_remaining": moves_remaining,
		"stars": stars_earned,
		"move_limit": move_limit,
	}
	if level_id != "":
		var prev_stars := int(data.best_level_stars.get(level_id, 0))
		if stars_earned > prev_stars:
			data.best_level_stars[level_id] = stars_earned
		var prev_score := int(data.best_level_scores.get(level_id, 0))
		if score > prev_score:
			data.best_level_scores[level_id] = score
	save_now()
	order_updated.emit(order_id)
	notifications_changed.emit()
	state_changed.emit()
	return data.order_level_results[order_id]


func on_level_lost(order_id: String) -> void:
	data.order_statuses[order_id] = SaveData.OrderStatus.FAILED
	save_now()
	order_updated.emit(order_id)
	state_changed.emit()


func complete_order(order_id: String) -> Dictionary:
	if _busy:
		return {}
	if get_order_status(order_id) != SaveData.OrderStatus.READY_TO_COMPLETE:
		return {}
	if order_id in data.completed_order_ids:
		return {}
	var order := catalog.get_order(StringName(order_id))
	if order == null:
		return {}

	_busy = true
	var rewards := RewardCalculator.compute_order_rewards(order, data)
	var result: Dictionary = data.order_level_results.get(order_id, {})
	var stars_earned := int(result.get("stars", 1))

	data.coins += int(rewards["coins"])
	data.reputation += int(rewards["reputation"])
	data.stars += stars_earned
	for ing_id in rewards["ingredients"].keys():
		var add_amt := int(rewards["ingredients"][ing_id])
		var key := str(ing_id)
		data.ingredients[key] = int(data.ingredients.get(key, 0)) + add_amt

	pending_level_ups = PlayerProgression.apply_experience(data, int(rewards["experience"]))

	data.order_statuses[order_id] = SaveData.OrderStatus.COMPLETED
	data.completed_order_ids.append(order_id)
	if data.active_order_id == order_id:
		data.active_order_id = ""
	_replace_visible_order(order_id)

	last_completion_rewards = {
		"order_id": order_id,
		"customer_name": order.customer_name,
		"recipe_id": str(order.recipe_id),
		"recipe_name": catalog.get_recipe(order.recipe_id).display_name if catalog.get_recipe(order.recipe_id) else str(order.recipe_id),
		"coins": rewards["coins"],
		"experience": rewards["experience"],
		"reputation": rewards["reputation"],
		"stars": stars_earned,
		"ingredients": rewards["ingredients"],
		"level_ups": pending_level_ups.duplicate(true),
	}

	save_now()
	coins_changed.emit(data.coins)
	stars_changed.emit(data.stars)
	reputation_changed.emit(data.reputation)
	experience_changed.emit(data.experience, PlayerProgression.xp_required_for_next_level(data.player_level), data.player_level)
	order_updated.emit(order_id)
	notifications_changed.emit()
	state_changed.emit()
	_busy = false
	return last_completion_rewards


func consume_pending_level_ups() -> Array[Dictionary]:
	var ups := pending_level_ups.duplicate(true)
	pending_level_ups.clear()
	return ups


# ---------------------------------------------------------------------------
# Recipes / upgrades / inventory helpers
# ---------------------------------------------------------------------------

func unlock_recipe(recipe_id: StringName) -> Dictionary:
	var check := can_unlock_recipe(recipe_id)
	if not check.get("ok", false):
		return check
	var recipe := catalog.get_recipe(recipe_id)
	data.coins = maxi(0, data.coins - recipe.unlock_coin_cost)
	data.unlocked_recipes[str(recipe_id)] = true
	_ensure_order_board()
	save_now()
	coins_changed.emit(data.coins)
	recipe_unlocked.emit(recipe_id)
	notifications_changed.emit()
	state_changed.emit()
	return {"ok": true, "reason": ""}


func upgrade_equipment(equipment_id: StringName) -> Dictionary:
	var check := can_upgrade_equipment(equipment_id)
	if not check.get("ok", false):
		return check
	var eq := catalog.get_equipment(equipment_id)
	var next_level: int = int(check["next_level"])
	var cost: int = int(check["cost"])
	data.coins = maxi(0, data.coins - cost)
	data.equipment_levels[str(equipment_id)] = next_level
	# Shop level = average equipment tier (simple progression signal).
	var total := 0
	for id in data.equipment_levels.keys():
		total += int(data.equipment_levels[id])
	data.shop_level = maxi(1, int(round(float(total) / float(maxi(data.equipment_levels.size(), 1)))))
	save_now()
	coins_changed.emit(data.coins)
	equipment_upgraded.emit(equipment_id, next_level)
	notifications_changed.emit()
	state_changed.emit()
	return {"ok": true, "reason": "", "new_level": next_level}


# ---------------------------------------------------------------------------
# Debug
# ---------------------------------------------------------------------------

func debug_add_coins(amount: int = 1000) -> void:
	data.coins += amount
	save_now()
	coins_changed.emit(data.coins)
	notifications_changed.emit()
	state_changed.emit()


func debug_add_stars(amount: int = 10) -> void:
	data.stars += amount
	save_now()
	stars_changed.emit(data.stars)
	notifications_changed.emit()
	state_changed.emit()


func debug_add_xp(amount: int = 500) -> void:
	pending_level_ups = PlayerProgression.apply_experience(data, amount)
	save_now()
	experience_changed.emit(data.experience, PlayerProgression.xp_required_for_next_level(data.player_level), data.player_level)
	coins_changed.emit(data.coins)
	notifications_changed.emit()
	state_changed.emit()


func debug_add_reputation(amount: int = 25) -> void:
	data.reputation += amount
	save_now()
	reputation_changed.emit(data.reputation)
	state_changed.emit()


func debug_unlock_all_recipes() -> void:
	for id in catalog.recipes.keys():
		data.unlocked_recipes[str(id)] = true
	_ensure_order_board()
	save_now()
	notifications_changed.emit()
	state_changed.emit()


func debug_complete_current_order() -> void:
	if data.active_order_id == "":
		return
	var order := catalog.get_order(StringName(data.active_order_id))
	if order == null:
		return
	on_level_won(data.active_order_id, 1000, 10, 20)
	complete_order(data.active_order_id)


func debug_reset_orders() -> void:
	data.order_statuses.clear()
	data.order_level_results.clear()
	data.completed_order_ids.clear()
	data.active_order_id = ""
	data.visible_order_ids.clear()
	_ensure_order_board()
	save_now()
	state_changed.emit()


func debug_max_equipment() -> void:
	for id in catalog.equipment.keys():
		data.equipment_levels[str(id)] = 5
	data.shop_level = 5
	save_now()
	state_changed.emit()


func debug_print_save() -> void:
	print(JSON.stringify(SaveManager._to_dict(data), "\t"))


func debug_corrupt_save() -> void:
	SaveManager.write_corrupted_save_for_debug()
	data = SaveManager.load_game()
	_ensure_order_board()
	state_changed.emit()


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

func _ensure_order_board() -> void:
	# Drop visible orders that require locked recipes (unless already in progress/ready).
	var kept: Array[String] = []
	for id in data.visible_order_ids:
		var order := catalog.get_order(StringName(id))
		if order == null:
			continue
		var status := get_order_status(id)
		if status in [SaveData.OrderStatus.READY_TO_COMPLETE, SaveData.OrderStatus.LEVEL_IN_PROGRESS, SaveData.OrderStatus.SELECTED, SaveData.OrderStatus.FAILED]:
			kept.append(id)
			continue
		if order.requires_recipe_unlocked and not is_recipe_unlocked(order.recipe_id):
			continue
		if status == SaveData.OrderStatus.COMPLETED:
			continue
		kept.append(id)
	data.visible_order_ids = kept
	while data.visible_order_ids.size() < 3:
		var next_id := _pick_next_available_order()
		if next_id == "":
			break
		data.visible_order_ids.append(next_id)
		if not data.order_statuses.has(next_id):
			data.order_statuses[next_id] = SaveData.OrderStatus.AVAILABLE


func _replace_visible_order(order_id: String) -> void:
	var idx := data.visible_order_ids.find(order_id)
	if idx >= 0:
		data.visible_order_ids.remove_at(idx)
	var next_id := _pick_next_available_order()
	if next_id != "":
		data.visible_order_ids.append(next_id)
		data.order_statuses[next_id] = SaveData.OrderStatus.AVAILABLE


func _pick_next_available_order() -> String:
	for id_name in catalog.order_sequence:
		var id := str(id_name)
		if id in data.visible_order_ids:
			continue
		if id in data.completed_order_ids:
			continue
		var order := catalog.get_order(id_name)
		if order == null:
			continue
		if order.requires_recipe_unlocked and not is_recipe_unlocked(order.recipe_id):
			continue
		var status := get_order_status(id)
		if status == SaveData.OrderStatus.COMPLETED:
			continue
		return id
	# Recycle completed pool for endless prototype play, excluding locked recipes.
	for id_name in catalog.order_sequence:
		var id := str(id_name)
		if id in data.visible_order_ids:
			continue
		var order := catalog.get_order(id_name)
		if order == null:
			continue
		if order.requires_recipe_unlocked and not is_recipe_unlocked(order.recipe_id):
			continue
		# Allow reappearing after completion for prototype longevity.
		if id in data.completed_order_ids:
			data.completed_order_ids.erase(id)
			data.order_statuses[id] = SaveData.OrderStatus.AVAILABLE
			data.order_level_results.erase(id)
			return id
	return ""
