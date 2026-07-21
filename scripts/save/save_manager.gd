class_name SaveManager
extends RefCounted
## Local JSON save/load with versioned migration and corruption recovery.

const SAVE_PATH := "user://sugar_street_save.json"
const BACKUP_PATH := "user://sugar_street_save.bak.json"


static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


static func save_game(data: SaveData) -> bool:
	if data == null:
		push_error("SaveManager: cannot save null data")
		return false
	data.last_saved_unix = int(Time.get_unix_time_from_system())
	var dict := _to_dict(data)
	var json := JSON.stringify(dict, "\t")
	# Keep a backup of the previous good save.
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
		return _load_backup_or_default()
	var data := _from_dict(parsed as Dictionary)
	if data == null:
		push_warning("SaveManager: failed to migrate save — trying backup.")
		return _load_backup_or_default()
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


static func _to_dict(data: SaveData) -> Dictionary:
	return {
		"version": data.version,
		"last_saved_unix": data.last_saved_unix,
		"player_level": data.player_level,
		"experience": data.experience,
		"coins": data.coins,
		"stars": data.stars,
		"reputation": data.reputation,
		"shop_name": data.shop_name,
		"shop_level": data.shop_level,
		"unlocked_recipes": _stringify_keys(data.unlocked_recipes),
		"equipment_levels": _stringify_keys(data.equipment_levels),
		"ingredients": _stringify_keys(data.ingredients),
		"best_level_stars": data.best_level_stars.duplicate(true),
		"best_level_scores": data.best_level_scores.duplicate(true),
		"order_statuses": _stringify_keys(data.order_statuses),
		"order_level_results": _stringify_keys(data.order_level_results),
		"completed_order_ids": data.completed_order_ids.duplicate(),
		"active_order_id": data.active_order_id,
		"visible_order_ids": data.visible_order_ids.duplicate(),
		"settings": data.settings.duplicate(true),
	}


static func _from_dict(dict: Dictionary) -> SaveData:
	var data := SaveData.create_default()
	data.version = int(dict.get("version", SaveData.SAVE_VERSION))
	data.last_saved_unix = int(dict.get("last_saved_unix", 0))
	data.player_level = maxi(1, int(dict.get("player_level", 1)))
	data.experience = maxi(0, int(dict.get("experience", 0)))
	data.coins = maxi(0, int(dict.get("coins", 500)))
	data.stars = maxi(0, int(dict.get("stars", 0)))
	data.reputation = maxi(0, int(dict.get("reputation", 0)))
	data.shop_name = str(dict.get("shop_name", data.shop_name))
	data.shop_level = maxi(1, int(dict.get("shop_level", 1)))
	data.unlocked_recipes = _merge_dict(data.unlocked_recipes, dict.get("unlocked_recipes", {}))
	data.equipment_levels = _merge_dict(data.equipment_levels, dict.get("equipment_levels", {}))
	data.ingredients = _merge_dict(data.ingredients, dict.get("ingredients", {}))
	data.best_level_stars = dict.get("best_level_stars", {}).duplicate(true) if typeof(dict.get("best_level_stars", {})) == TYPE_DICTIONARY else {}
	data.best_level_scores = dict.get("best_level_scores", {}).duplicate(true) if typeof(dict.get("best_level_scores", {})) == TYPE_DICTIONARY else {}
	data.order_statuses = _merge_dict({}, dict.get("order_statuses", {}))
	data.order_level_results = _merge_dict({}, dict.get("order_level_results", {}))
	var completed: Variant = dict.get("completed_order_ids", [])
	data.completed_order_ids = []
	if typeof(completed) == TYPE_ARRAY:
		for item in completed:
			data.completed_order_ids.append(str(item))
	data.active_order_id = str(dict.get("active_order_id", ""))
	var visible: Variant = dict.get("visible_order_ids", [])
	data.visible_order_ids = []
	if typeof(visible) == TYPE_ARRAY:
		for item in visible:
			data.visible_order_ids.append(str(item))
	var settings: Variant = dict.get("settings", {})
	if typeof(settings) == TYPE_DICTIONARY:
		for key in settings:
			data.settings[key] = settings[key]
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
