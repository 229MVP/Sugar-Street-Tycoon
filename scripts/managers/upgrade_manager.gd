class_name UpgradeManager
extends RefCounted
## Purchases and applies the six bakery upgrades (Oven, Mixer, Display Case,
## Cash Register, Decor, Lighting). Oven/Mixer/Display Case/Cash Register
## mirror their level into SaveData.equipment_levels so the legacy
## RewardCalculator keeps computing order bonuses without modification.

signal upgrade_purchased(upgrade_id: String, new_level: int)
signal upgrades_changed

var _db: DefinitionDatabase
var _data: SaveData
var _economy: EconomyManager


func setup(database: DefinitionDatabase, data: SaveData, economy: EconomyManager) -> void:
	_db = database
	_data = data
	_economy = economy
	ensure_defaults()


func bind_data(data: SaveData) -> void:
	_data = data
	ensure_defaults()


func ensure_defaults() -> void:
	if _data == null or _db == null:
		return
	if typeof(_data.upgrade_levels) != TYPE_DICTIONARY:
		_data.upgrade_levels = {}
	if typeof(_data.equipment_levels) != TYPE_DICTIONARY:
		_data.equipment_levels = {}
	for id in _db.upgrade_sequence:
		var def := _db.get_upgrade(id)
		if def == null:
			continue
		if not _data.upgrade_levels.has(id):
			# Migrate from legacy equipment ids when possible (checkout -> cash_register).
			var legacy := 0
			if def.linked_equipment_id != "":
				legacy = int(_data.equipment_levels.get(def.linked_equipment_id, 0))
			_data.upgrade_levels[id] = legacy if legacy > 0 else def.starting_level
		_data.upgrade_levels[id] = clampi(int(_data.upgrade_levels[id]), 1, def.max_level)
	_sync_equipment_mirror()


## Reads the stored level directly. Safe to call from ensure_defaults() (does
## NOT call ensure_defaults() itself — avoids re-entrant recursion).
func _raw_level(upgrade_id: String) -> int:
	var def := _db.upgrades.get(upgrade_id) as UpgradeDefinition
	if def == null:
		return 1
	return clampi(int(_data.upgrade_levels.get(upgrade_id, def.starting_level)), 1, def.max_level)


func get_level(upgrade_id: String) -> int:
	ensure_defaults()
	return _raw_level(upgrade_id)


func all_upgrade_ids() -> Array[String]:
	return _db.upgrade_sequence.duplicate() if _db else ([] as Array[String])


func get_definition(upgrade_id: String) -> UpgradeDefinition:
	return _db.get_upgrade(upgrade_id) if _db else null


func cost_for_next(upgrade_id: String) -> int:
	var def := get_definition(upgrade_id)
	if def == null:
		return 0
	var level := get_level(upgrade_id)
	if level >= def.max_level:
		return 0
	return def.cost_to_reach(level + 1)


func effect_value(upgrade_id: String) -> float:
	var def := get_definition(upgrade_id)
	if def == null:
		return 0.0
	return def.effect_at_level(get_level(upgrade_id))


func can_purchase(upgrade_id: String) -> Dictionary:
	var def := get_definition(upgrade_id)
	if def == null:
		return {"ok": false, "reason": "Unknown upgrade."}
	var level := get_level(upgrade_id)
	if level >= def.max_level:
		return {"ok": false, "reason": "Maximum level reached."}
	var cost := def.cost_to_reach(level + 1)
	if not _economy.can_afford(cost):
		return {"ok": false, "reason": "Need %s coins." % RewardCalculator.format_coins(cost), "cost": cost}
	return {"ok": true, "cost": cost, "next_level": level + 1}


func purchase(upgrade_id: String) -> Dictionary:
	var check := can_purchase(upgrade_id)
	if not check.get("ok", false):
		return check
	var cost: int = int(check["cost"])
	var next_level: int = int(check["next_level"])
	var spend := _economy.spend_coins(cost, "upgrade:%s" % upgrade_id)
	if not spend.get("ok", false):
		return spend
	_data.upgrade_levels[upgrade_id] = next_level
	_sync_equipment_mirror()
	upgrade_purchased.emit(upgrade_id, next_level)
	upgrades_changed.emit()
	return {"ok": true, "new_level": next_level, "cost": cost}


## Forces an upgrade to its maximum level without spending coins (debug/testing helper).
func force_max(upgrade_id: String) -> void:
	var def := get_definition(upgrade_id)
	if def == null:
		return
	_data.upgrade_levels[upgrade_id] = def.max_level
	_sync_equipment_mirror()
	upgrades_changed.emit()


func global_effects() -> Dictionary:
	return {
		"baking_speed": effect_value("oven"),
		"batch_size": effect_value("mixer"),
		"coin_rewards": effect_value("display_case"),
		"transaction_speed": effect_value("cash_register"),
		"tip_bonus": effect_value("decor"),
		"star_bonus": effect_value("lighting"),
	}


func _sync_equipment_mirror() -> void:
	## Keep legacy equipment_levels in sync for RewardCalculator / existing UI.
	## IMPORTANT: uses `_raw_level()`, never `get_level()` — calling get_level()
	## here would re-enter ensure_defaults() and recurse infinitely.
	for id in _db.upgrade_sequence:
		var def: UpgradeDefinition = _db.upgrades.get(id) as UpgradeDefinition
		if def == null or def.linked_equipment_id == "":
			continue
		var level := clampi(_raw_level(id), 1, 3)
		_data.equipment_levels[def.linked_equipment_id] = level
