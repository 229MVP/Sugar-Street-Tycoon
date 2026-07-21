class_name WorkerBonusCalculator
extends RefCounted
## Centralized active worker bonus math. Only hired+assigned workers apply.


static func get_assigned_worker_id(data: SaveData, station: WorkerData.Station) -> String:
	var key := WorkerData.station_to_string(station)
	return str(data.worker_assignments.get(key, ""))


static func get_worker_level(data: SaveData, worker_id: String) -> int:
	return clampi(int(data.worker_levels.get(worker_id, 1)), 1, WorkerData.MAX_LEVEL)


static func is_active(data: SaveData, worker_id: String) -> bool:
	if not bool(data.hired_workers.get(worker_id, false)):
		return false
	for station_key in data.worker_assignments.keys():
		if str(data.worker_assignments[station_key]) == worker_id:
			return true
	return false


static func active_workers(catalog: ContentCatalog, data: SaveData) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for station_key in data.worker_assignments.keys():
		var worker_id := str(data.worker_assignments[station_key])
		if worker_id == "" or not bool(data.hired_workers.get(worker_id, false)):
			continue
		var worker := catalog.get_worker(StringName(worker_id))
		if worker == null:
			continue
		var station := WorkerData.station_from_string(str(station_key))
		if station != worker.compatible_station:
			continue
		result.append({
			"worker": worker,
			"level": get_worker_level(data, worker_id),
			"station": station,
		})
	return result


static func order_coin_bonus_percent(catalog: ContentCatalog, data: SaveData) -> Dictionary:
	## Returns {percent, contributors: [{name, percent}]}
	return _sum_bonus(catalog, data, &"order_coins")


static func order_xp_bonus_percent(catalog: ContentCatalog, data: SaveData) -> Dictionary:
	return _sum_bonus(catalog, data, &"order_xp")


static func order_reputation_bonus_percent(catalog: ContentCatalog, data: SaveData) -> Dictionary:
	return _sum_bonus(catalog, data, &"order_reputation")


static func all_order_rewards_bonus_percent(catalog: ContentCatalog, data: SaveData) -> Dictionary:
	return _sum_bonus(catalog, data, &"all_order_rewards")


static func passive_income_bonus_percent(catalog: ContentCatalog, data: SaveData) -> Dictionary:
	return _sum_bonus(catalog, data, &"passive_income")


static func bonus_ingredient_chance(catalog: ContentCatalog, data: SaveData) -> Dictionary:
	## Chance is absolute (0..1), not additive percent of base.
	var total := 0.0
	var contributors: Array = []
	for entry in active_workers(catalog, data):
		var worker: WorkerData = entry["worker"]
		var level: int = entry["level"]
		if worker.primary_bonus_type == &"bonus_ingredients":
			var chance := worker.primary_bonus_base + worker.primary_bonus_per_level * float(level)
			total += chance
			contributors.append({"name": worker.display_name, "chance": chance})
	return {"chance": clampf(total, 0.0, 0.95), "contributors": contributors}


static func _sum_bonus(catalog: ContentCatalog, data: SaveData, bonus_type: StringName) -> Dictionary:
	var total := 0.0
	var contributors: Array = []
	for entry in active_workers(catalog, data):
		var worker: WorkerData = entry["worker"]
		var level: int = entry["level"]
		var amount := 0.0
		if worker.primary_bonus_type == bonus_type:
			amount += worker.primary_bonus_per_level * float(level)
		if worker.secondary_bonus_type == bonus_type:
			amount += worker.secondary_bonus_per_level * float(level)
		if amount > 0.0:
			total += amount
			contributors.append({"name": worker.display_name, "percent": amount})
	return {"percent": total, "contributors": contributors}


static func summarize_active_bonuses(catalog: ContentCatalog, data: SaveData) -> Dictionary:
	return {
		"order_coins": order_coin_bonus_percent(catalog, data),
		"order_xp": order_xp_bonus_percent(catalog, data),
		"order_reputation": order_reputation_bonus_percent(catalog, data),
		"all_order_rewards": all_order_rewards_bonus_percent(catalog, data),
		"passive_income": passive_income_bonus_percent(catalog, data),
		"bonus_ingredients": bonus_ingredient_chance(catalog, data),
	}
