class_name WorkerService
extends RefCounted
## Signal-bearing façade around the existing WorkerManager rules engine (hire /
## upgrade / assign / unassign) plus legacy-id migration for the renamed
## six-worker roster (Lily, Marco, Sophie, Ethan, Mia, Noah).

signal worker_hired(worker_id: String)
signal worker_upgraded(worker_id: String, new_level: int)
signal worker_assigned(worker_id: String, station: String)
signal worker_unassigned(worker_id: String)
signal workers_changed

var _db: DefinitionDatabase
var _data: SaveData
var _catalog: ContentCatalog


func setup(database: DefinitionDatabase, data: SaveData, catalog: ContentCatalog) -> void:
	_db = database
	_data = data
	_catalog = catalog
	ensure_defaults()


func bind_data(data: SaveData) -> void:
	_data = data
	ensure_defaults()


func ensure_defaults() -> void:
	if _data == null:
		return
	_data.apply_worker_defaults()
	if _catalog:
		WorkerManager.repair_assignments(_catalog, _data)


func all_worker_ids() -> Array[String]:
	return _db.worker_sequence.duplicate() if _db else ([] as Array[String])


func get_definition(worker_id: String) -> WorkerDefinition:
	return _db.get_worker(worker_id) if _db else null


func get_worker_data(worker_id: String) -> WorkerData:
	return _catalog.get_worker(StringName(worker_id)) if _catalog else null


func is_hired(worker_id: String) -> bool:
	return WorkerManager.is_hired(_data, worker_id)


func is_unlocked(worker_id: String) -> bool:
	return WorkerManager.is_unlocked(get_worker_data(worker_id), _data)


func get_level(worker_id: String) -> int:
	return WorkerManager.get_level(_data, worker_id)


func assigned_station(worker_id: String) -> WorkerData.Station:
	return WorkerManager.assigned_station_of(_data, worker_id)


func can_hire(worker_id: String) -> Dictionary:
	return WorkerManager.can_hire(get_worker_data(worker_id), _data)


func hire(worker_id: String) -> Dictionary:
	var worker := get_worker_data(worker_id)
	# WorkerManager.hire validates unlock/duplicate/affordability and deducts
	# coins exactly once — do not spend through EconomyManager as well.
	var result := WorkerManager.hire(worker, _data)
	if not result.get("ok", false):
		return result
	worker_hired.emit(worker_id)
	workers_changed.emit()
	return result


func can_upgrade(worker_id: String) -> Dictionary:
	return WorkerManager.can_upgrade(get_worker_data(worker_id), _data)


func upgrade(worker_id: String) -> Dictionary:
	var result := WorkerManager.upgrade(get_worker_data(worker_id), _data)
	if not result.get("ok", false):
		return result
	worker_upgraded.emit(worker_id, int(result.get("new_level", 1)))
	workers_changed.emit()
	return result


func can_assign(worker_id: String, station: WorkerData.Station) -> Dictionary:
	return WorkerManager.can_assign(get_worker_data(worker_id), _data, station)


func assign(worker_id: String, station: WorkerData.Station) -> Dictionary:
	var result := WorkerManager.assign(get_worker_data(worker_id), _data, station)
	if result.get("ok", false):
		worker_assigned.emit(worker_id, WorkerData.station_to_string(station))
		workers_changed.emit()
	return result


func unassign(worker_id: String) -> Dictionary:
	var result := WorkerManager.unassign(_data, worker_id)
	if result.get("ok", false):
		worker_unassigned.emit(worker_id)
		workers_changed.emit()
	return result


func global_effects() -> Dictionary:
	if _catalog == null:
		return {}
	return {
		"coins": WorkerBonusCalculator.order_coin_bonus_percent(_catalog, _data),
		"xp": WorkerBonusCalculator.order_xp_bonus_percent(_catalog, _data),
		"reputation": WorkerBonusCalculator.order_reputation_bonus_percent(_catalog, _data),
		"all": WorkerBonusCalculator.all_order_rewards_bonus_percent(_catalog, _data),
		"ingredients": WorkerBonusCalculator.bonus_ingredient_chance(_catalog, _data),
		"bonus_star_chance": WorkerBonusCalculator.bonus_star_chance(_catalog, _data),
	}
