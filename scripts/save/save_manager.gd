class_name SaveManager
extends RefCounted
## Local JSON save/load with versioned migration and corruption recovery.

const SAVE_PATH := "user://sugar_street_save.json"
const BACKUP_PATH := "user://sugar_street_save.bak.json"


static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


static func has_valid_save_file() -> bool:
	## True only when primary or backup JSON parses as a dictionary.
	if has_save():
		var text := FileAccess.get_file_as_string(SAVE_PATH)
		if typeof(JSON.parse_string(text)) == TYPE_DICTIONARY:
			return true
	if FileAccess.file_exists(BACKUP_PATH):
		var bak := FileAccess.get_file_as_string(BACKUP_PATH)
		if typeof(JSON.parse_string(bak)) == TYPE_DICTIONARY:
			return true
	return false


static func save_game(data: SaveData) -> bool:
	if data == null:
		push_error("SaveManager: cannot save null data")
		return false
	var now := int(Time.get_unix_time_from_system())
	data.last_saved_unix = now
	data.last_active_unix = now
	data.version = SaveData.SAVE_VERSION
	var dict := _to_dict(data)
	var json := JSON.stringify(dict, "\t")
	if FileAccess.file_exists(SAVE_PATH):
		var prev := FileAccess.get_file_as_string(SAVE_PATH)
		var bak := FileAccess.open(BACKUP_PATH, FileAccess.WRITE)
		if bak:
			bak.store_string(prev)
			bak.close()
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: failed to open save for write: %s" % FileAccess.get_open_error())
		return false
	file.store_string(json)
	file.close()
	return true


static func load_game() -> SaveData:
	if not has_save():
		return SaveData.create_default()
	var text := FileAccess.get_file_as_string(SAVE_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("SaveManager: corrupted save — trying backup.")
		return _recover_and_rewrite()
	var data := _from_dict(parsed as Dictionary)
	if data == null:
		push_warning("SaveManager: failed to migrate save — trying backup.")
		return _recover_and_rewrite()
	return data


static func delete_save() -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	if dir.file_exists("sugar_street_save.json"):
		dir.remove("sugar_street_save.json")
	if dir.file_exists("sugar_street_save.bak.json"):
		dir.remove("sugar_street_save.bak.json")


static func write_corrupted_save_for_debug() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string("{ this is not valid json ;;;")
		file.close()


static func write_corrupted_worker_data(data: SaveData) -> void:
	## Leaves core progress intact but breaks worker fields for recovery tests.
	data.worker_levels = {"ava": -5, "ghost": 99}
	data.worker_assignments = {"oven": "ava", "mixer": "ava", "checkout": "nobody"}
	data.stored_passive_coins = -50.0
	data.hired_workers = {"ava": true}
	save_game(data)


static func write_corrupted_decoration_data(data: SaveData) -> void:
	## Leaves core progress intact but breaks decoration fields for recovery tests.
	data.owned_decorations = {"ghost_lamp": true, "wooden_starter_sign": true}
	data.placed_decorations = {
		"front_sign": "ghost_lamp",
		"missing_slot": "wooden_starter_sign",
		"plant_corner": "wooden_starter_sign",
		"wall_right": "framed_cupcake_print",
	}
	data.shop_level = 99
	data.shop_appeal = -40
	save_game(data)


static func _load_backup_or_default() -> SaveData:
	if FileAccess.file_exists(BACKUP_PATH):
		var text := FileAccess.get_file_as_string(BACKUP_PATH)
		var parsed: Variant = JSON.parse_string(text)
		if typeof(parsed) == TYPE_DICTIONARY:
			var data := _from_dict(parsed as Dictionary)
			if data:
				push_warning("SaveManager: recovered from backup.")
				return data
	push_warning("SaveManager: using default save after corruption.")
	return SaveData.create_default()


static func _recover_and_rewrite() -> SaveData:
	## Recover once, then overwrite the corrupt primary so the next boot is clean.
	var data := _load_backup_or_default()
	if data:
		save_game(data)
	return data


static func _to_dict(data: SaveData) -> Dictionary:
	return {
		"version": data.version,
		"last_saved_unix": data.last_saved_unix,
		"last_active_unix": data.last_active_unix,
		"player_level": data.player_level,
		"experience": data.experience,
		"coins": data.coins,
		"stars": data.stars,
		"reputation": data.reputation,
		"shop_name": data.shop_name,
		"shop_level": data.shop_level,
		"shop_appeal": data.shop_appeal,
		"shop_appeal_tier": data.shop_appeal_tier,
		"decoration_save_version": data.decoration_save_version,
		"owned_decorations": _stringify_keys(data.owned_decorations),
		"placed_decorations": _stringify_keys(data.placed_decorations),
		"unlocked_decorations": _stringify_keys(data.unlocked_decorations),
		"unlocked_recipes": _stringify_keys(data.unlocked_recipes),
		"equipment_levels": _stringify_keys(data.equipment_levels),
		"ingredients": _stringify_keys(data.ingredients),
		"best_level_stars": data.best_level_stars.duplicate(true),
		"best_level_scores": data.best_level_scores.duplicate(true),
		"best_order_stars": data.best_order_stars.duplicate(true),
		"best_order_scores": data.best_order_scores.duplicate(true),
		"granted_level_stars": data.granted_level_stars.duplicate(true),
		"order_statuses": _stringify_keys(data.order_statuses),
		"order_level_results": _stringify_keys(data.order_level_results),
		"order_reward_claimed": _stringify_keys(data.order_reward_claimed),
		"completed_order_ids": data.completed_order_ids.duplicate(),
		"active_order_id": data.active_order_id,
		"selected_order_id": data.active_order_id,
		"visible_order_ids": data.visible_order_ids.duplicate(),
		"settings": data.settings.duplicate(true),
		"worker_save_version": data.worker_save_version,
		"hired_workers": _stringify_keys(data.hired_workers),
		"worker_levels": _stringify_keys(data.worker_levels),
		"worker_assignments": _stringify_keys(data.worker_assignments),
		"worker_unlock_flags": _stringify_keys(data.worker_unlock_flags),
		"stored_passive_coins": data.stored_passive_coins,
		"last_passive_tick_unix": data.last_passive_tick_unix,
		"last_offline_calc_unix": data.last_offline_calc_unix,
		"offline_pending_popup": data.offline_pending_popup.duplicate(true),
	}


static func _from_dict(dict: Dictionary) -> SaveData:
	var data := SaveData.create_default()
	var old_version := int(dict.get("version", 1))
	data.version = old_version
	data.last_saved_unix = int(dict.get("last_saved_unix", 0))
	data.last_active_unix = int(dict.get("last_active_unix", data.last_saved_unix))
	data.player_level = maxi(1, int(dict.get("player_level", 1)))
	data.experience = maxi(0, int(dict.get("experience", 0)))
	data.coins = maxi(0, int(dict.get("coins", 500)))
	data.stars = maxi(0, int(dict.get("stars", 0)))
	data.reputation = maxi(0, int(dict.get("reputation", 0)))
	data.shop_name = str(dict.get("shop_name", data.shop_name))
	data.shop_level = maxi(1, int(dict.get("shop_level", 1)))
	data.shop_appeal = maxi(0, int(dict.get("shop_appeal", 0)))
	data.shop_appeal_tier = str(dict.get("shop_appeal_tier", "Plain"))
	data.decoration_save_version = int(dict.get("decoration_save_version", 0))
	data.owned_decorations = _merge_dict({}, dict.get("owned_decorations", {}))
	data.placed_decorations = _merge_dict({}, dict.get("placed_decorations", {}))
	data.unlocked_decorations = _merge_dict({}, dict.get("unlocked_decorations", {}))
	data.unlocked_recipes = _merge_dict(data.unlocked_recipes, dict.get("unlocked_recipes", {}))
	data.equipment_levels = _merge_dict(data.equipment_levels, dict.get("equipment_levels", {}))
	# Merge saved pantry onto starter defaults, then fill any missing keys.
	# Never clobber valid existing quantities; only add absent ingredient IDs.
	data.ingredients = _merge_dict(data.ingredients, dict.get("ingredients", {}))
	data.ingredients = SaveData.ensure_ingredient_keys(data.ingredients)
	data.best_level_stars = dict.get("best_level_stars", {}).duplicate(true) if typeof(dict.get("best_level_stars", {})) == TYPE_DICTIONARY else {}
	data.best_level_scores = dict.get("best_level_scores", {}).duplicate(true) if typeof(dict.get("best_level_scores", {})) == TYPE_DICTIONARY else {}
	data.best_order_stars = dict.get("best_order_stars", {}).duplicate(true) if typeof(dict.get("best_order_stars", {})) == TYPE_DICTIONARY else {}
	data.best_order_scores = dict.get("best_order_scores", {}).duplicate(true) if typeof(dict.get("best_order_scores", {})) == TYPE_DICTIONARY else {}
	data.granted_level_stars = dict.get("granted_level_stars", {}).duplicate(true) if typeof(dict.get("granted_level_stars", {})) == TYPE_DICTIONARY else {}
	data.order_statuses = _merge_dict({}, dict.get("order_statuses", {}))
	data.order_level_results = _merge_dict({}, dict.get("order_level_results", {}))
	data.order_reward_claimed = _merge_dict({}, dict.get("order_reward_claimed", {}))
	var completed: Variant = dict.get("completed_order_ids", [])
	data.completed_order_ids = []
	if typeof(completed) == TYPE_ARRAY:
		for item in completed:
			data.completed_order_ids.append(str(item))
	# Backfill reward-claimed for already completed orders from older saves.
	for cid in data.completed_order_ids:
		if not data.order_reward_claimed.has(cid):
			data.order_reward_claimed[cid] = true
	data.active_order_id = str(dict.get("active_order_id", dict.get("selected_order_id", "")))
	var visible: Variant = dict.get("visible_order_ids", [])
	data.visible_order_ids = []
	if typeof(visible) == TYPE_ARRAY:
		for item in visible:
			data.visible_order_ids.append(str(item))
	var settings: Variant = dict.get("settings", {})
	if typeof(settings) == TYPE_DICTIONARY:
		for key in settings:
			data.settings[key] = settings[key]

	# Worker / passive migration (v1 → v2 defaults already present).
	data.worker_save_version = int(dict.get("worker_save_version", 0))
	data.hired_workers = _merge_dict({}, dict.get("hired_workers", {}))
	data.worker_levels = _merge_dict({}, dict.get("worker_levels", {}))
	data.worker_assignments = _merge_dict({}, dict.get("worker_assignments", {}))
	data.worker_unlock_flags = _merge_dict(data.worker_unlock_flags, dict.get("worker_unlock_flags", {}))
	data.stored_passive_coins = float(dict.get("stored_passive_coins", 0.0))
	data.last_passive_tick_unix = int(dict.get("last_passive_tick_unix", data.last_active_unix))
	data.last_offline_calc_unix = int(dict.get("last_offline_calc_unix", 0))
	var offline_popup: Variant = dict.get("offline_pending_popup", {})
	data.offline_pending_popup = offline_popup.duplicate(true) if typeof(offline_popup) == TYPE_DICTIONARY else {}

	if old_version < 2 or data.worker_save_version < 1:
		if OS.is_debug_build():
			print("SaveManager: migrating save v%d → worker system defaults" % old_version)
	if old_version < 3:
		if OS.is_debug_build():
			print("SaveManager: migrating save v%d → vertical-slice v3 (Mia orders / reward claims)" % old_version)
		# Drop obsolete visible order IDs from earlier catalogs; board rebuilds on load.
		var cleaned: Array[String] = []
		for oid in data.visible_order_ids:
			if str(oid).begins_with("order_mia") or str(oid).begins_with("order_jordan") \
					or str(oid).begins_with("order_taylor") or str(oid).begins_with("order_noah_004") \
					or str(oid).begins_with("order_morgan_005"):
				cleaned.append(oid)
		data.visible_order_ids = cleaned
	if old_version < 4 or data.decoration_save_version < 1:
		if OS.is_debug_build():
			print("SaveManager: migrating save v%d → decoration system v4" % old_version)
		# Shop level was previously derived from equipment; reset to independent progression start.
		data.shop_level = 1
		data.owned_decorations = {
			"wooden_starter_sign": true,
			"small_mint_plant": true,
		}
		data.unlocked_decorations = {
			"wooden_starter_sign": true,
			"small_mint_plant": true,
		}
		data.placed_decorations = {
			"front_sign": "wooden_starter_sign",
			"plant_corner": "small_mint_plant",
		}
		data.shop_appeal = 10
		data.shop_appeal_tier = "Plain"
		data.decoration_save_version = SaveData.DECORATION_SAVE_VERSION
	data.apply_worker_defaults()

	data.version = SaveData.SAVE_VERSION
	return data


static func _stringify_keys(source: Dictionary) -> Dictionary:
	var out := {}
	for key in source.keys():
		out[str(key)] = source[key]
	return out


static func _merge_dict(base: Dictionary, incoming: Variant) -> Dictionary:
	var out := base.duplicate(true)
	if typeof(incoming) != TYPE_DICTIONARY:
		return out
	for key in (incoming as Dictionary).keys():
		out[str(key)] = incoming[key]
	return out
