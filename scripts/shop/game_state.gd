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
signal worker_hired(worker_id: StringName)
signal worker_upgraded(worker_id: StringName, new_level: int)
signal worker_assigned(worker_id: StringName, station: String)
signal worker_unassigned(worker_id: StringName)
signal passive_income_changed(stored: float, rate: float)
signal passive_collected(amount: int)
signal offline_earnings_ready(payload: Dictionary)
signal level_up(new_level: int, coin_reward: int)
signal notifications_changed
signal save_completed

const DEBUG_TOOLS_ENABLED := true

var catalog := ContentCatalog.new()
var data: SaveData
var pending_level_ups: Array[Dictionary] = []
var last_completion_rewards: Dictionary = {}
var last_offline_payload: Dictionary = {}
var _busy: bool = false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	catalog.build()
	if SaveManager.has_save():
		data = SaveManager.load_game()
	else:
		data = SaveData.create_default()
	_post_load_setup()
	emit_signal("state_changed")


func _post_load_setup() -> void:
	data.apply_worker_defaults()
	WorkerManager.repair_assignments(catalog, data)
	_ensure_order_board()
	var offline := OfflineEarningsCalculator.calculate(catalog, data)
	if offline.get("ok", false):
		var added := OfflineEarningsCalculator.apply_to_storage(catalog, data, offline)
		if added > 0 or int(offline.get("total_coins", 0)) > 0:
			last_offline_payload = data.offline_pending_popup.duplicate(true)
			offline_earnings_ready.emit(last_offline_payload)
	PassiveIncomeManager.tick(catalog, data)
	OfflineEarningsCalculator.mark_session_active(data)


func has_save() -> bool:
	return SaveManager.has_save()


func new_game() -> void:
	data = SaveData.create_default()
	_post_load_setup()
	save_now()
	state_changed.emit()


func continue_game() -> void:
	data = SaveManager.load_game()
	_post_load_setup()
	state_changed.emit()


func save_now() -> void:
	OfflineEarningsCalculator.mark_session_active(data)
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
	var level := _build_level_for_order(order)
	if level == null or not level.validate():
		push_error("GameState: invalid level config for order '%s'" % order_id)
		return null
	data.active_order_id = order_id
	data.order_statuses[order_id] = SaveData.OrderStatus.LEVEL_IN_PROGRESS
	save_now()
	order_updated.emit(order_id)
	return level


func _build_level_for_order(order: OrderTemplate) -> LevelConfig:
	## Clone a board template and apply this order's objective / move limit.
	var base := catalog.get_level(order.level_id)
	if base == null:
		return null
	var level := LevelConfig.new()
	level.level_id = base.level_id
	level.level_name = "%s for %s" % [base.level_name, order.customer_name]
	level.columns = base.columns
	level.rows = base.rows
	level.piece_types = base.piece_types.duplicate()
	level.min_valid_moves = base.min_valid_moves
	level.move_limit = order.move_limit if order.move_limit > 0 else base.move_limit
	if order.target_piece_id != &"" and order.target_amount > 0:
		var obj := ObjectiveData.new()
		obj.piece_id = order.target_piece_id
		obj.target_amount = order.target_amount
		obj.description = order.objective_text()
		var objs: Array[ObjectiveData] = [obj]
		level.objectives = objs
	else:
		level.objectives = base.objectives.duplicate()
	return level


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
	var rewards := RewardCalculator.compute_order_rewards(order, data, catalog)
	var result: Dictionary = data.order_level_results.get(order_id, {})
	var stars_earned := int(result.get("stars", 1))
	var breakdown: Dictionary = rewards.get("breakdown", {})
	var chance := float(breakdown.get("bonus_ingredient_chance", 0.0))
	var bonus_ings := RewardCalculator.roll_bonus_ingredients(order, chance, _rng)
	for k in bonus_ings.keys():
		rewards["ingredients"][k] = int(rewards["ingredients"].get(k, 0)) + int(bonus_ings[k])

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
		"bonus_ingredients": bonus_ings,
		"breakdown": breakdown,
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
# Workers
# ---------------------------------------------------------------------------

func get_worker(worker_id: StringName) -> WorkerData:
	return catalog.get_worker(worker_id)


func is_worker_hired(worker_id: StringName) -> bool:
	return WorkerManager.is_hired(data, str(worker_id))


func get_worker_level(worker_id: StringName) -> int:
	return WorkerManager.get_level(data, str(worker_id))


func can_hire_worker(worker_id: StringName) -> Dictionary:
	return WorkerManager.can_hire(catalog.get_worker(worker_id), data)


func hire_worker(worker_id: StringName) -> Dictionary:
	if _busy:
		return {"ok": false, "reason": "Busy."}
	var worker := catalog.get_worker(worker_id)
	var result := WorkerManager.hire(worker, data)
	if not result.get("ok", false):
		return result
	save_now()
	coins_changed.emit(data.coins)
	worker_hired.emit(worker_id)
	notifications_changed.emit()
	state_changed.emit()
	return result


func can_upgrade_worker(worker_id: StringName) -> Dictionary:
	return WorkerManager.can_upgrade(catalog.get_worker(worker_id), data)


func upgrade_worker(worker_id: StringName) -> Dictionary:
	if _busy:
		return {"ok": false, "reason": "Busy."}
	var worker := catalog.get_worker(worker_id)
	var result := WorkerManager.upgrade(worker, data)
	if not result.get("ok", false):
		return result
	save_now()
	coins_changed.emit(data.coins)
	worker_upgraded.emit(worker_id, int(result.get("new_level", 1)))
	notifications_changed.emit()
	state_changed.emit()
	return result


func assign_worker(worker_id: StringName, station: WorkerData.Station) -> Dictionary:
	var worker := catalog.get_worker(worker_id)
	var result := WorkerManager.assign(worker, data, station)
	if not result.get("ok", false):
		return result
	save_now()
	worker_assigned.emit(worker_id, WorkerData.station_to_string(station))
	notifications_changed.emit()
	state_changed.emit()
	return result


func unassign_worker(worker_id: StringName) -> Dictionary:
	var result := WorkerManager.unassign(data, str(worker_id))
	if not result.get("ok", false):
		return result
	save_now()
	worker_unassigned.emit(worker_id)
	notifications_changed.emit()
	state_changed.emit()
	return result


func get_assigned_worker_count() -> int:
	return data.worker_assignments.size()


func preview_order_rewards(order: OrderTemplate) -> Dictionary:
	return RewardCalculator.compute_order_rewards(order, data, catalog)


func worker_hire_available_count() -> int:
	var count := 0
	for id in catalog.workers.keys():
		if can_hire_worker(StringName(id)).get("ok", false):
			count += 1
	return count


func worker_upgrade_available_count() -> int:
	var count := 0
	for id in catalog.workers.keys():
		if can_upgrade_worker(StringName(id)).get("ok", false):
			count += 1
	return count


func empty_compatible_station_count() -> int:
	var count := 0
	for id in catalog.workers.keys():
		var worker: WorkerData = catalog.workers[id]
		if not is_worker_hired(worker.worker_id):
			continue
		if WorkerManager.assigned_station_of(data, str(worker.worker_id)) != WorkerData.Station.NONE:
			continue
		if WorkerManager.occupant_of(data, worker.compatible_station) == "":
			count += 1
	return count


# ---------------------------------------------------------------------------
# Passive / offline income
# ---------------------------------------------------------------------------

func tick_passive_income() -> void:
	var added := PassiveIncomeManager.tick(catalog, data)
	if added > 0.0:
		var info := PassiveIncomeManager.coins_per_minute(catalog, data)
		passive_income_changed.emit(data.stored_passive_coins, float(info["rate"]))
		notifications_changed.emit()


func get_passive_income_info() -> Dictionary:
	var info := PassiveIncomeManager.coins_per_minute(catalog, data)
	info["stored"] = data.stored_passive_coins
	info["storage_full"] = data.stored_passive_coins >= float(info["max_storage_coins"]) - 0.01
	return info


func collect_passive_income() -> int:
	if _busy:
		return 0
	_busy = true
	tick_passive_income()
	var amount := PassiveIncomeManager.collect(data)
	if amount > 0:
		data.offline_pending_popup = {}
		save_now()
		coins_changed.emit(data.coins)
		passive_collected.emit(amount)
		var info := get_passive_income_info()
		passive_income_changed.emit(0.0, float(info["rate"]))
		notifications_changed.emit()
		state_changed.emit()
	_busy = false
	return amount


func consume_offline_popup() -> Dictionary:
	var payload := data.offline_pending_popup.duplicate(true)
	data.offline_pending_popup = {}
	return payload


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
	_post_load_setup()
	state_changed.emit()


func debug_unlock_all_workers() -> void:
	for id in catalog.workers.keys():
		data.worker_unlock_flags[str(id)] = true
	data.player_level = maxi(data.player_level, 8)
	data.reputation = maxi(data.reputation, 150)
	save_now()
	notifications_changed.emit()
	state_changed.emit()


func debug_hire_all_workers() -> void:
	debug_add_coins(50000)
	debug_unlock_all_workers()
	for id in catalog.workers.keys():
		if not is_worker_hired(StringName(id)):
			WorkerManager.hire(catalog.get_worker(StringName(id)), data)
	save_now()
	state_changed.emit()


func debug_assign_all_workers() -> void:
	for id in catalog.workers.keys():
		var worker: WorkerData = catalog.workers[id]
		if is_worker_hired(worker.worker_id):
			WorkerManager.assign(worker, data, worker.compatible_station)
	save_now()
	state_changed.emit()


func debug_clear_assignments() -> void:
	data.worker_assignments.clear()
	save_now()
	state_changed.emit()


func debug_set_worker_level(worker_id: StringName, level: int) -> void:
	if not is_worker_hired(worker_id):
		return
	data.worker_levels[str(worker_id)] = clampi(level, 1, WorkerData.MAX_LEVEL)
	save_now()
	state_changed.emit()


func debug_simulate_offline_hour() -> void:
	data.last_active_unix = int(Time.get_unix_time_from_system()) - 3600
	data.last_offline_calc_unix = 0
	var calc := OfflineEarningsCalculator.calculate(catalog, data)
	OfflineEarningsCalculator.apply_to_storage(catalog, data, calc)
	last_offline_payload = data.offline_pending_popup.duplicate(true)
	offline_earnings_ready.emit(last_offline_payload)
	save_now()
	state_changed.emit()


func debug_fill_passive_storage() -> void:
	PassiveIncomeManager.fill_storage_for_debug(catalog, data)
	save_now()
	passive_income_changed.emit(data.stored_passive_coins, float(get_passive_income_info()["rate"]))
	state_changed.emit()


func debug_clear_passive_storage() -> void:
	data.stored_passive_coins = 0.0
	save_now()
	passive_income_changed.emit(0.0, float(get_passive_income_info()["rate"]))
	state_changed.emit()


func debug_print_workers() -> void:
	print(JSON.stringify({
		"hired": data.hired_workers,
		"levels": data.worker_levels,
		"assignments": data.worker_assignments,
		"bonuses": WorkerBonusCalculator.summarize_active_bonuses(catalog, data),
		"passive": get_passive_income_info(),
	}, "\t"))


func debug_corrupt_worker_save() -> void:
	SaveManager.write_corrupted_worker_data(data)
	data = SaveManager.load_game()
	WorkerManager.repair_assignments(catalog, data)
	save_now()
	state_changed.emit()


func debug_reset_workers_only() -> void:
	data.hired_workers.clear()
	data.worker_levels.clear()
	data.worker_assignments.clear()
	data.worker_unlock_flags = {"ava": true}
	data.stored_passive_coins = 0.0
	save_now()
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
