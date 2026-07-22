extends Node
## Global app/game state: save data, catalog, orders, progression actions.

signal state_changed
signal coins_changed(amount: int)
signal stars_changed(amount: int)
signal reputation_changed(amount: int)
signal experience_changed(current: int, required: int, level: int)
signal player_level_changed(level: int)
signal selected_order_changed(order_id: String)
signal order_status_changed(order_id: String, status: int)
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
signal save_loaded
signal save_completed
signal decoration_purchased(decoration_id: StringName)
signal decoration_placed(slot_id: StringName, decoration_id: StringName)
signal decoration_removed(slot_id: StringName, decoration_id: StringName)
signal shop_level_upgraded(new_level: int)
signal appeal_changed(appeal: int, tier: String)

## True in editor / debug builds only. Production exports hide debug panels.
const DEBUG_TOOLS_ENABLED := true

var catalog := ContentCatalog.new()
var decor_catalog := DecorationCatalog.new()
var data: SaveData
var pending_level_ups: Array[Dictionary] = []
var last_completion_rewards: Dictionary = {}
var last_offline_payload: Dictionary = {}
var current_session_result: Dictionary = {}
var _busy: bool = false
var _purchase_lock: bool = false
var _rng := RandomNumberGenerator.new()
var _previous_appeal_tier: String = "Plain"


func _ready() -> void:
	_rng.randomize()
	catalog.build()
	decor_catalog.build()
	if SaveManager.has_save():
		data = SaveManager.load_game()
	else:
		data = SaveData.create_default()
	_post_load_setup()
	_apply_audio_settings()
	save_loaded.emit()
	emit_signal("state_changed")


func _post_load_setup() -> void:
	data.apply_worker_defaults()
	WorkerManager.repair_assignments(catalog, data)
	var decor_logs := DecorationManager.repair(decor_catalog, data)
	if OS.is_debug_build() and not decor_logs.is_empty():
		for msg in decor_logs:
			print("DecorationManager repair: ", msg)
	_previous_appeal_tier = str(data.shop_appeal_tier)
	_ensure_order_board()
	# Passive/offline systems remain in code for migration but are not exposed this phase.
	OfflineEarningsCalculator.mark_session_active(data)


func has_save() -> bool:
	return SaveManager.has_save()


func has_valid_save() -> bool:
	## Continue stays disabled when only a corrupt primary exists with no backup.
	if not SaveManager.has_valid_save_file():
		return false
	var loaded := SaveManager.load_game()
	return loaded != null and loaded.player_level >= 1


func new_game() -> void:
	var preserved_settings: Dictionary = {}
	if data != null and typeof(data.settings) == TYPE_DICTIONARY:
		preserved_settings = data.settings.duplicate(true)
	data = SaveData.create_default()
	if not preserved_settings.is_empty():
		data.settings = preserved_settings
	_post_load_setup()
	_apply_audio_settings()
	save_now()
	save_loaded.emit()
	state_changed.emit()


func continue_game() -> void:
	data = SaveManager.load_game()
	_post_load_setup()
	_apply_audio_settings()
	save_loaded.emit()
	state_changed.emit()


func save_now() -> void:
	OfflineEarningsCalculator.mark_session_active(data)
	SaveManager.save_game(data)
	save_completed.emit()


func reset_save() -> void:
	var preserved_settings: Dictionary = {}
	if data != null and typeof(data.settings) == TYPE_DICTIONARY:
		preserved_settings = data.settings.duplicate(true)
	SaveManager.delete_save()
	data = SaveData.create_default()
	if not preserved_settings.is_empty():
		data.settings = preserved_settings
	_ensure_order_board()
	_apply_audio_settings()
	save_now()
	save_loaded.emit()
	state_changed.emit()


func update_settings(patch: Dictionary) -> void:
	for key in patch.keys():
		data.settings[key] = patch[key]
	_apply_audio_settings()
	save_now()
	state_changed.emit()


func _apply_audio_settings() -> void:
	if data == null:
		return
	AudioManager.enabled = bool(data.settings.get("sfx_enabled", true))
	AudioManager.set_sfx_volume(float(data.settings.get("sfx_volume", 0.9)))
	AudioManager.set_music_volume(float(data.settings.get("music_volume", 0.8)))
	AudioManager.set_music_enabled(bool(data.settings.get("music_enabled", true)))


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
	var order := catalog.get_order(StringName(order_id))
	if order != null and order.requires_recipe_unlocked and not is_recipe_unlocked(order.recipe_id):
		var stored := int(data.order_statuses.get(order_id, SaveData.OrderStatus.LOCKED))
		if stored in [SaveData.OrderStatus.READY_TO_COMPLETE, SaveData.OrderStatus.LEVEL_IN_PROGRESS, SaveData.OrderStatus.COMPLETED]:
			return stored
		return SaveData.OrderStatus.LOCKED
	var status := int(data.order_statuses.get(order_id, SaveData.OrderStatus.AVAILABLE))
	# Recipe unlock promotes former LOCKED rows to Available.
	if status == SaveData.OrderStatus.LOCKED:
		return SaveData.OrderStatus.AVAILABLE
	return status


func is_order_reward_claimed(order_id: String) -> bool:
	return bool(data.order_reward_claimed.get(order_id, false))


func get_visible_orders() -> Array[OrderTemplate]:
	var result: Array[OrderTemplate] = []
	for id in data.visible_order_ids:
		var order := catalog.get_order(StringName(id))
		if order:
			result.append(order)
	return result


func get_orders_for_screen() -> Array[OrderTemplate]:
	## Full catalog order list for the Orders screen (includes locked).
	var result: Array[OrderTemplate] = []
	var seen: Dictionary = {}
	for id in data.visible_order_ids:
		var order := catalog.get_order(StringName(id))
		if order:
			result.append(order)
			seen[str(id)] = true
	for id_name in catalog.order_sequence:
		var id := str(id_name)
		if seen.has(id):
			continue
		var order := catalog.get_order(id_name)
		if order == null:
			continue
		# Show locked recipe orders so players can see unlock requirements.
		if order.requires_recipe_unlocked and not is_recipe_unlocked(order.recipe_id):
			result.append(order)
			seen[id] = true
			continue
		if id in data.completed_order_ids:
			continue
		result.append(order)
		seen[id] = true
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
	if status in [SaveData.OrderStatus.COMPLETED, SaveData.OrderStatus.READY_TO_COMPLETE, SaveData.OrderStatus.LEVEL_IN_PROGRESS, SaveData.OrderStatus.LOCKED]:
		return false
	# Clear previous selected if different.
	if data.active_order_id != "" and data.active_order_id != order_id:
		var prev := get_order_status(data.active_order_id)
		if prev == SaveData.OrderStatus.SELECTED or prev == SaveData.OrderStatus.FAILED:
			data.order_statuses[data.active_order_id] = SaveData.OrderStatus.AVAILABLE
			order_status_changed.emit(data.active_order_id, SaveData.OrderStatus.AVAILABLE)
	data.active_order_id = order_id
	data.order_statuses[order_id] = SaveData.OrderStatus.SELECTED
	save_now()
	selected_order_changed.emit(order_id)
	order_status_changed.emit(order_id, SaveData.OrderStatus.SELECTED)
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
	if status == SaveData.OrderStatus.COMPLETED or status == SaveData.OrderStatus.LOCKED:
		return null
	# READY_TO_COMPLETE allowed for practice replay without clearing the win.
	var level := _build_level_for_order(order)
	if level == null or not level.validate():
		push_error("GameState: invalid level config for order '%s'" % order_id)
		return null
	data.active_order_id = order_id
	if status != SaveData.OrderStatus.READY_TO_COMPLETE:
		data.order_statuses[order_id] = SaveData.OrderStatus.LEVEL_IN_PROGRESS
		order_status_changed.emit(order_id, SaveData.OrderStatus.LEVEL_IN_PROGRESS)
	selected_order_changed.emit(order_id)
	save_now()
	order_updated.emit(order_id)
	return level


func build_level_config_for_order(order_id: String) -> LevelConfig:
	var order := catalog.get_order(StringName(order_id))
	if order == null:
		return null
	return _build_level_for_order(order)


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
	var targets := order.all_collection_targets()
	if not targets.is_empty():
		var objs: Array[ObjectiveData] = []
		for t in targets:
			var obj := ObjectiveData.new()
			obj.piece_id = StringName(str(t["piece_id"]))
			obj.target_amount = int(t["amount"])
			obj.description = "Collect %d %ss" % [obj.target_amount, str(obj.piece_id)]
			objs.append(obj)
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
	var prev_level_stars := int(data.best_level_stars.get(level_id, 0)) if level_id != "" else 0
	var prev_order_stars := int(data.best_order_stars.get(order_id, 0))
	var star_delta := maxi(0, stars_earned - maxi(prev_level_stars, prev_order_stars))
	data.order_statuses[order_id] = SaveData.OrderStatus.READY_TO_COMPLETE
	data.order_level_results[order_id] = {
		"score": score,
		"moves_remaining": moves_remaining,
		"stars": stars_earned,
		"star_delta": star_delta,
		"move_limit": move_limit,
		"objectives_complete": true,
	}
	current_session_result = data.order_level_results[order_id].duplicate(true)
	if level_id != "":
		if stars_earned > prev_level_stars:
			data.best_level_stars[level_id] = stars_earned
		var prev_score := int(data.best_level_scores.get(level_id, 0))
		if score > prev_score:
			data.best_level_scores[level_id] = score
	if stars_earned > prev_order_stars:
		data.best_order_stars[order_id] = stars_earned
	var prev_order_score := int(data.best_order_scores.get(order_id, 0))
	if score > prev_order_score:
		data.best_order_scores[order_id] = score
	save_now()
	order_status_changed.emit(order_id, SaveData.OrderStatus.READY_TO_COMPLETE)
	order_updated.emit(order_id)
	notifications_changed.emit()
	state_changed.emit()
	return data.order_level_results[order_id]


func on_level_lost(order_id: String) -> void:
	var status := get_order_status(order_id)
	# Preserve a prior Ready-to-Complete win during practice replay.
	if status == SaveData.OrderStatus.READY_TO_COMPLETE or status == SaveData.OrderStatus.COMPLETED:
		current_session_result = {"order_id": order_id, "failed_replay": true}
		save_now()
		return
	data.order_statuses[order_id] = SaveData.OrderStatus.FAILED
	current_session_result = {"order_id": order_id, "failed": true}
	save_now()
	order_status_changed.emit(order_id, SaveData.OrderStatus.FAILED)
	order_updated.emit(order_id)
	state_changed.emit()


func complete_order(order_id: String) -> Dictionary:
	if _busy:
		return {}
	if get_order_status(order_id) != SaveData.OrderStatus.READY_TO_COMPLETE:
		return {}
	if order_id in data.completed_order_ids:
		return {}
	if is_order_reward_claimed(order_id):
		return {}
	var order := catalog.get_order(StringName(order_id))
	if order == null:
		return {}

	_busy = true
	var rewards := RewardCalculator.compute_order_rewards(order, data, catalog, decor_catalog)
	var result: Dictionary = data.order_level_results.get(order_id, {})
	var stars_earned := int(result.get("stars", 1))
	var level_id := order.level_id
	var best_stars := int(data.best_level_stars.get(level_id, stars_earned))
	var already_granted := int(data.granted_level_stars.get(level_id, 0))
	var permanent_stars := maxi(0, best_stars - already_granted)
	var breakdown: Dictionary = rewards.get("breakdown", {})
	# Worker bonus ingredient rolls are placeholders this phase (chance typically 0).
	var chance := float(breakdown.get("bonus_ingredient_chance", 0.0))
	var bonus_ings := RewardCalculator.roll_bonus_ingredients(order, chance, _rng)
	for k in bonus_ings.keys():
		rewards["ingredients"][k] = int(rewards["ingredients"].get(k, 0)) + int(bonus_ings[k])

	data.coins += int(rewards["coins"])
	data.reputation += int(rewards["reputation"])
	data.stars += permanent_stars
	data.granted_level_stars[level_id] = already_granted + permanent_stars
	for ing_id in rewards["ingredients"].keys():
		var add_amt := int(rewards["ingredients"][ing_id])
		var key := str(ing_id)
		data.ingredients[key] = maxi(0, int(data.ingredients.get(key, 0)) + add_amt)

	var level_before := data.player_level
	pending_level_ups = PlayerProgression.apply_experience(data, int(rewards["experience"]))
	for up in pending_level_ups:
		level_up.emit(int(up.get("new_level", data.player_level)), int(up.get("coin_reward", 0)))
	if data.player_level != level_before:
		player_level_changed.emit(data.player_level)

	data.order_reward_claimed[order_id] = true
	data.order_statuses[order_id] = SaveData.OrderStatus.COMPLETED
	data.completed_order_ids.append(order_id)
	if data.active_order_id == order_id:
		data.active_order_id = ""
		selected_order_changed.emit("")
	_replace_visible_order(order_id)

	last_completion_rewards = {
		"order_id": order_id,
		"customer_name": order.customer_name,
		"recipe_id": str(order.recipe_id),
		"recipe_name": catalog.get_recipe(order.recipe_id).display_name if catalog.get_recipe(order.recipe_id) else str(order.recipe_id),
		"coins": rewards["coins"],
		"experience": rewards["experience"],
		"reputation": rewards["reputation"],
		"stars": permanent_stars,
		"stars_earned_run": stars_earned,
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
	order_status_changed.emit(order_id, SaveData.OrderStatus.COMPLETED)
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
	for id_name in catalog.order_sequence:
		var order := catalog.get_order(id_name)
		if order == null or order.recipe_id != recipe_id:
			continue
		var oid := str(id_name)
		if int(data.order_statuses.get(oid, SaveData.OrderStatus.LOCKED)) == SaveData.OrderStatus.LOCKED:
			data.order_statuses[oid] = SaveData.OrderStatus.AVAILABLE
			order_status_changed.emit(oid, SaveData.OrderStatus.AVAILABLE)
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
	# Shop level is an independent progression track (decoration system).
	save_now()
	coins_changed.emit(data.coins)
	equipment_upgraded.emit(equipment_id, next_level)
	notifications_changed.emit()
	state_changed.emit()
	return {"ok": true, "reason": "", "new_level": next_level}


# ---------------------------------------------------------------------------
# Decorations / Shop Appeal / Shop Level
# ---------------------------------------------------------------------------

func get_decoration(decoration_id: StringName) -> DecorationData:
	return decor_catalog.get_decoration(decoration_id)


func get_decoration_slot(slot_id: StringName) -> DecorationSlotDef:
	return decor_catalog.get_slot(slot_id)


func is_decoration_owned(decoration_id: StringName) -> bool:
	return DecorationManager.is_owned(data, str(decoration_id))


func get_shop_appeal() -> int:
	return ShopAppealCalculator.calculate_appeal(decor_catalog, data.placed_decorations)


func get_appeal_summary() -> Dictionary:
	return ShopAppealCalculator.summarize(decor_catalog, data)


func can_purchase_decoration(decoration_id: StringName) -> Dictionary:
	return DecorationManager.can_purchase(decor_catalog.get_decoration(decoration_id), data)


func purchase_decoration(decoration_id: StringName) -> Dictionary:
	if _busy or _purchase_lock:
		return {"ok": false, "reason": "Busy."}
	_purchase_lock = true
	var result := DecorationManager.purchase(decor_catalog.get_decoration(decoration_id), data)
	_purchase_lock = false
	if not result.get("ok", false):
		return result
	_sync_appeal(false)
	save_now()
	coins_changed.emit(data.coins)
	decoration_purchased.emit(decoration_id)
	notifications_changed.emit()
	state_changed.emit()
	return result


func can_place_decoration(decoration_id: StringName, slot_id: StringName) -> Dictionary:
	return DecorationManager.can_place(
		decor_catalog.get_decoration(decoration_id),
		decor_catalog.get_slot(slot_id),
		data
	)


func place_decoration(decoration_id: StringName, slot_id: StringName, replace_existing: bool = false) -> Dictionary:
	if _busy:
		return {"ok": false, "reason": "Busy."}
	var result := DecorationManager.place(
		decor_catalog.get_decoration(decoration_id),
		decor_catalog.get_slot(slot_id),
		data,
		replace_existing
	)
	if not result.get("ok", false):
		return result
	var prev_tier := _previous_appeal_tier
	_sync_appeal(true)
	save_now()
	decoration_placed.emit(slot_id, decoration_id)
	if _previous_appeal_tier != prev_tier:
		AudioManager.play(AudioManager.Sfx.APPEAL_TIER_UP)
	notifications_changed.emit()
	state_changed.emit()
	return result


func remove_decoration_from_slot(slot_id: StringName) -> Dictionary:
	if _busy:
		return {"ok": false, "reason": "Busy."}
	var result := DecorationManager.remove_from_slot(str(slot_id), data)
	if not result.get("ok", false):
		return result
	_sync_appeal(true)
	save_now()
	decoration_removed.emit(slot_id, StringName(str(result.get("decoration_id", ""))))
	notifications_changed.emit()
	state_changed.emit()
	return result


func can_upgrade_shop_level() -> Dictionary:
	return ShopLevelRules.can_upgrade(data, get_shop_appeal())


func upgrade_shop_level() -> Dictionary:
	if _busy:
		return {"ok": false, "reason": "Busy."}
	var check := can_upgrade_shop_level()
	if not check.get("ok", false):
		return check
	var cost: int = int(check.get("cost", 0))
	var next_level: int = int(check.get("next_level", data.shop_level + 1))
	data.coins = maxi(0, data.coins - cost)
	data.shop_level = next_level
	var newly := DecorationManager.refresh_unlocks(decor_catalog, data)
	_sync_appeal(false)
	save_now()
	coins_changed.emit(data.coins)
	shop_level_upgraded.emit(next_level)
	notifications_changed.emit()
	state_changed.emit()
	return {
		"ok": true,
		"reason": "",
		"new_level": next_level,
		"new_unlocks": newly,
		"new_slots": check.get("requirements", {}).get("slots", []),
	}


func decoration_notification_priority() -> Dictionary:
	## Highest-priority badge for Decor button.
	if can_upgrade_shop_level().get("ok", false):
		return {"count": 1, "kind": "shop_upgrade"}
	var empty_slots := DecorationManager.empty_unlocked_slot_count(decor_catalog, data)
	if empty_slots > 0:
		return {"count": empty_slots, "kind": "empty_slot"}
	var affordable := DecorationManager.affordable_count(decor_catalog, data)
	if affordable > 0:
		return {"count": affordable, "kind": "affordable"}
	var newly := DecorationManager.newly_unlocked_count(decor_catalog, data)
	if newly > 0:
		return {"count": newly, "kind": "unlocked"}
	return {"count": 0, "kind": ""}


func mark_decoration_unlocks_seen() -> void:
	if typeof(data.settings.get("decor_seen_unlocks", null)) != TYPE_DICTIONARY:
		data.settings["decor_seen_unlocks"] = {}
	var seen: Dictionary = data.settings["decor_seen_unlocks"]
	for decor in decor_catalog.all_decorations():
		var id := str(decor.decoration_id)
		if bool(data.unlocked_decorations.get(id, false)):
			seen[id] = true
	data.settings["decor_seen_unlocks"] = seen
	notifications_changed.emit()


func _sync_appeal(emit_signal_if_changed: bool = true) -> void:
	var prev := int(data.shop_appeal)
	var prev_tier := str(data.shop_appeal_tier)
	var appeal := DecorationManager.recalculate_appeal(decor_catalog, data)
	_previous_appeal_tier = str(data.shop_appeal_tier)
	if emit_signal_if_changed and (appeal != prev or data.shop_appeal_tier != prev_tier):
		appeal_changed.emit(appeal, data.shop_appeal_tier)


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
	return RewardCalculator.compute_order_rewards(order, data, catalog, decor_catalog)


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
		data.equipment_levels[str(id)] = 3
	save_now()
	state_changed.emit()


func debug_print_gamestate() -> void:
	print(JSON.stringify({
		"player_level": data.player_level,
		"experience": data.experience,
		"coins": data.coins,
		"stars": data.stars,
		"reputation": data.reputation,
		"shop_level": data.shop_level,
		"shop_appeal": data.shop_appeal,
		"shop_appeal_tier": data.shop_appeal_tier,
		"owned_decorations": data.owned_decorations,
		"placed_decorations": data.placed_decorations,
		"active_order_id": data.active_order_id,
		"visible_order_ids": data.visible_order_ids,
		"order_statuses": data.order_statuses,
		"unlocked_recipes": data.unlocked_recipes,
		"equipment_levels": data.equipment_levels,
		"ingredients": data.ingredients,
		"best_level_stars": data.best_level_stars,
		"session_result": current_session_result,
	}, "\t"))


func debug_print_save() -> void:
	print(JSON.stringify(SaveManager._to_dict(data), "\t"))


func debug_corrupt_save() -> void:
	SaveManager.write_corrupted_save_for_debug()
	data = SaveManager.load_game()
	_post_load_setup()
	save_loaded.emit()
	state_changed.emit()


func debug_win_current_level() -> void:
	if data.active_order_id == "":
		return
	var order := catalog.get_order(StringName(data.active_order_id))
	var moves := order.move_limit if order else 20
	on_level_won(data.active_order_id, 9999, int(moves * 0.5), moves)


func debug_lose_current_level() -> void:
	if data.active_order_id == "":
		return
	on_level_lost(data.active_order_id)


func debug_set_moves_remaining(amount: int) -> void:
	## Hook for gameplay debug; stored for HUD tools to read.
	current_session_result["debug_moves_remaining"] = amount
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


func resync_appeal() -> void:
	_sync_appeal(true)
	notifications_changed.emit()
	state_changed.emit()


func debug_set_player_level(level: int) -> void:
	data.player_level = clampi(level, 1, 99)
	save_now()
	player_level_changed.emit(data.player_level)
	notifications_changed.emit()
	state_changed.emit()


func debug_unlock_all_decorations() -> void:
	for decor in decor_catalog.all_decorations():
		data.unlocked_decorations[str(decor.decoration_id)] = true
	save_now()
	notifications_changed.emit()
	state_changed.emit()


func debug_own_all_decorations() -> void:
	debug_add_coins(50000)
	for decor in decor_catalog.all_decorations():
		data.owned_decorations[str(decor.decoration_id)] = true
		data.unlocked_decorations[str(decor.decoration_id)] = true
	save_now()
	notifications_changed.emit()
	state_changed.emit()


func debug_clear_decoration_placements() -> void:
	data.placed_decorations.clear()
	_sync_appeal(true)
	save_now()
	state_changed.emit()


func debug_auto_place_highest_appeal() -> void:
	DecorationManager.auto_place_highest_appeal(decor_catalog, data)
	_sync_appeal(true)
	save_now()
	state_changed.emit()


func debug_set_shop_level(level: int) -> void:
	data.shop_level = clampi(level, 1, ShopLevelRules.MAX_SHOP_LEVEL)
	DecorationManager.refresh_unlocks(decor_catalog, data)
	var logs := DecorationManager.repair(decor_catalog, data)
	if OS.is_debug_build():
		for msg in logs:
			print("debug_set_shop_level repair: ", msg)
	save_now()
	notifications_changed.emit()
	state_changed.emit()


func debug_print_decorations() -> void:
	print(JSON.stringify({
		"owned": data.owned_decorations,
		"placed": data.placed_decorations,
		"appeal": get_appeal_summary(),
		"shop_level": data.shop_level,
	}, "\t"))


func debug_corrupt_decoration_save() -> void:
	SaveManager.write_corrupted_decoration_data(data)
	data = SaveManager.load_game()
	_post_load_setup()
	save_loaded.emit()
	state_changed.emit()


func debug_test_decoration_repair() -> void:
	debug_corrupt_decoration_save()
	var logs := DecorationManager.repair(decor_catalog, data)
	print("decoration repair logs: ", logs)
	save_now()
	state_changed.emit()


func debug_reset_decorations_only() -> void:
	data.owned_decorations = {
		"wooden_starter_sign": true,
		"small_mint_plant": true,
	}
	data.unlocked_decorations = data.owned_decorations.duplicate(true)
	data.placed_decorations = {
		"front_sign": "wooden_starter_sign",
		"plant_corner": "small_mint_plant",
	}
	data.shop_level = 1
	_sync_appeal(true)
	save_now()
	notifications_changed.emit()
	state_changed.emit()


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

func _ensure_order_board() -> void:
	# Keep active / ready / failed orders; fill remaining slots with available (not locked) orders.
	var kept: Array[String] = []
	for id in data.visible_order_ids:
		var order := catalog.get_order(StringName(id))
		if order == null:
			continue
		var status := get_order_status(id)
		if status in [SaveData.OrderStatus.READY_TO_COMPLETE, SaveData.OrderStatus.LEVEL_IN_PROGRESS, SaveData.OrderStatus.SELECTED, SaveData.OrderStatus.FAILED]:
			kept.append(id)
			continue
		if status == SaveData.OrderStatus.LOCKED:
			continue
		if order.requires_recipe_unlocked and not is_recipe_unlocked(order.recipe_id):
			data.order_statuses[id] = SaveData.OrderStatus.LOCKED
			continue
		if status == SaveData.OrderStatus.COMPLETED or is_order_reward_claimed(id):
			continue
		kept.append(id)
		if not data.order_statuses.has(id):
			data.order_statuses[id] = SaveData.OrderStatus.AVAILABLE
	data.visible_order_ids = kept
	while data.visible_order_ids.size() < 3:
		var next_id := _pick_next_available_order()
		if next_id == "":
			break
		data.visible_order_ids.append(next_id)
		if not data.order_statuses.has(next_id):
			data.order_statuses[next_id] = SaveData.OrderStatus.AVAILABLE
	# Track locked recipe orders so UI can surface unlock requirements.
	for id_name in catalog.order_sequence:
		var id := str(id_name)
		var order := catalog.get_order(id_name)
		if order == null:
			continue
		if order.requires_recipe_unlocked and not is_recipe_unlocked(order.recipe_id):
			if not data.order_statuses.has(id) or int(data.order_statuses[id]) == SaveData.OrderStatus.AVAILABLE:
				data.order_statuses[id] = SaveData.OrderStatus.LOCKED


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
		if is_order_reward_claimed(id):
			continue
		var order := catalog.get_order(id_name)
		if order == null:
			continue
		if order.requires_recipe_unlocked and not is_recipe_unlocked(order.recipe_id):
			continue
		var status := get_order_status(id)
		if status == SaveData.OrderStatus.COMPLETED or status == SaveData.OrderStatus.LOCKED:
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
		if id in data.completed_order_ids:
			data.completed_order_ids.erase(id)
			data.order_reward_claimed.erase(id)
			data.order_statuses[id] = SaveData.OrderStatus.AVAILABLE
			data.order_level_results.erase(id)
			return id
	return ""
