class_name WorkerManager
extends RefCounted
## Hire / upgrade / assign / validate workers against SaveData + catalog.


static func is_unlocked(worker: WorkerData, data: SaveData) -> bool:
	if worker == null:
		return false
	if worker.available_at_start or bool(data.worker_unlock_flags.get(str(worker.worker_id), false)):
		# Still enforce level/rep if flagged only by flag for start workers.
		pass
	if data.player_level < worker.unlock_player_level:
		return false
	if data.reputation < worker.unlock_reputation:
		return false
	if worker.unlock_equipment_id != StringName() and worker.unlock_equipment_level > 0:
		var eq_level := int(data.equipment_levels.get(str(worker.unlock_equipment_id), 1))
		if eq_level < worker.unlock_equipment_level:
			return false
	if worker.unlock_recipe_id != StringName():
		if not bool(data.unlocked_recipes.get(str(worker.unlock_recipe_id), false)):
			return false
	return true


static func unlock_reason(worker: WorkerData, data: SaveData) -> String:
	if worker == null:
		return "Unknown worker."
	var reasons: PackedStringArray = []
	if data.player_level < worker.unlock_player_level:
		reasons.append("Reach player level %d" % worker.unlock_player_level)
	if data.reputation < worker.unlock_reputation:
		reasons.append("Earn %d reputation" % worker.unlock_reputation)
	if worker.unlock_equipment_id != StringName() and worker.unlock_equipment_level > 0:
		var eq_level := int(data.equipment_levels.get(str(worker.unlock_equipment_id), 1))
		if eq_level < worker.unlock_equipment_level:
			reasons.append("Upgrade %s to level %d" % [str(worker.unlock_equipment_id).replace("_", " ").capitalize(), worker.unlock_equipment_level])
	if worker.unlock_recipe_id != StringName():
		if not bool(data.unlocked_recipes.get(str(worker.unlock_recipe_id), false)):
			reasons.append("Unlock recipe %s" % str(worker.unlock_recipe_id).replace("_", " ").capitalize())
	if reasons.is_empty():
		return ""
	return " · ".join(reasons)


static func is_hired(data: SaveData, worker_id: String) -> bool:
	return bool(data.hired_workers.get(worker_id, false))


static func get_level(data: SaveData, worker_id: String) -> int:
	return clampi(int(data.worker_levels.get(worker_id, 1)), 1, WorkerData.MAX_LEVEL)


static func can_hire(worker: WorkerData, data: SaveData) -> Dictionary:
	if worker == null:
		return {"ok": false, "reason": "Unknown worker."}
	if not is_unlocked(worker, data):
		return {"ok": false, "reason": unlock_reason(worker, data)}
	if is_hired(data, str(worker.worker_id)):
		return {"ok": false, "reason": "Already hired."}
	if data.coins < worker.hire_cost:
		return {"ok": false, "reason": "Need %s coins." % RewardCalculator.format_coins(worker.hire_cost)}
	return {"ok": true, "reason": "", "cost": worker.hire_cost}


static func hire(worker: WorkerData, data: SaveData) -> Dictionary:
	var check := can_hire(worker, data)
	if not check.get("ok", false):
		return check
	data.coins = maxi(0, data.coins - worker.hire_cost)
	data.hired_workers[str(worker.worker_id)] = true
	data.worker_levels[str(worker.worker_id)] = 1
	data.worker_unlock_flags[str(worker.worker_id)] = true
	return {"ok": true, "reason": ""}


static func can_upgrade(worker: WorkerData, data: SaveData) -> Dictionary:
	if worker == null:
		return {"ok": false, "reason": "Unknown worker."}
	if not is_hired(data, str(worker.worker_id)):
		return {"ok": false, "reason": "Hire this worker first."}
	var level := get_level(data, str(worker.worker_id))
	if level >= WorkerData.MAX_LEVEL:
		return {"ok": false, "reason": "Maximum level reached."}
	var cost := worker.upgrade_cost(level)
	if data.coins < cost:
		return {"ok": false, "reason": "Need %s coins." % RewardCalculator.format_coins(cost)}
	return {"ok": true, "reason": "", "cost": cost, "next_level": level + 1}


static func upgrade(worker: WorkerData, data: SaveData) -> Dictionary:
	var check := can_upgrade(worker, data)
	if not check.get("ok", false):
		return check
	var cost: int = int(check["cost"])
	var next_level: int = int(check["next_level"])
	data.coins = maxi(0, data.coins - cost)
	data.worker_levels[str(worker.worker_id)] = next_level
	return {"ok": true, "reason": "", "new_level": next_level}


static func assigned_station_of(data: SaveData, worker_id: String) -> WorkerData.Station:
	for station_key in data.worker_assignments.keys():
		if str(data.worker_assignments[station_key]) == worker_id:
			return WorkerData.station_from_string(str(station_key))
	return WorkerData.Station.NONE


static func occupant_of(data: SaveData, station: WorkerData.Station) -> String:
	return str(data.worker_assignments.get(WorkerData.station_to_string(station), ""))


static func can_assign(worker: WorkerData, data: SaveData, station: WorkerData.Station) -> Dictionary:
	if worker == null:
		return {"ok": false, "reason": "Unknown worker."}
	if not is_hired(data, str(worker.worker_id)):
		return {"ok": false, "reason": "Hire this worker first."}
	if station != worker.compatible_station:
		return {"ok": false, "reason": "Only compatible with %s." % worker.station_label()}
	var current_occupant := occupant_of(data, station)
	return {
		"ok": true,
		"reason": "",
		"replaces": current_occupant,
		"needs_replace_confirm": current_occupant != "" and current_occupant != str(worker.worker_id),
	}


static func assign(worker: WorkerData, data: SaveData, station: WorkerData.Station) -> Dictionary:
	var check := can_assign(worker, data, station)
	if not check.get("ok", false):
		return check
	# Clear previous station for this worker.
	var prev := assigned_station_of(data, str(worker.worker_id))
	if prev != WorkerData.Station.NONE:
		data.worker_assignments.erase(WorkerData.station_to_string(prev))
	var key := WorkerData.station_to_string(station)
	data.worker_assignments[key] = str(worker.worker_id)
	return {"ok": true, "reason": "", "replaced": str(check.get("replaces", ""))}


static func unassign(data: SaveData, worker_id: String) -> Dictionary:
	var station := assigned_station_of(data, worker_id)
	if station == WorkerData.Station.NONE:
		return {"ok": false, "reason": "Worker is not assigned."}
	data.worker_assignments.erase(WorkerData.station_to_string(station))
	return {"ok": true, "reason": ""}


static func repair_assignments(catalog: ContentCatalog, data: SaveData) -> void:
	## Fix invalid levels, duplicate stations, incompatible assignments.
	var seen_workers: Dictionary = {}
	var cleaned: Dictionary = {}
	for station_key in data.worker_assignments.keys():
		var worker_id := str(data.worker_assignments[station_key])
		if worker_id == "":
			continue
		if not is_hired(data, worker_id):
			if OS.is_debug_build():
				print("WorkerManager repair: unassigned non-hired ", worker_id)
			continue
		if seen_workers.has(worker_id):
			if OS.is_debug_build():
				print("WorkerManager repair: duplicate assignment for ", worker_id)
			continue
		var worker := catalog.get_worker(StringName(worker_id))
		if worker == null:
			if OS.is_debug_build():
				print("WorkerManager repair: unknown worker ", worker_id)
			continue
		var station := WorkerData.station_from_string(str(station_key))
		if station != worker.compatible_station:
			if OS.is_debug_build():
				print("WorkerManager repair: incompatible station for ", worker_id)
			continue
		cleaned[WorkerData.station_to_string(station)] = worker_id
		seen_workers[worker_id] = true
	data.worker_assignments = cleaned

	for worker_id in data.hired_workers.keys():
		var level := int(data.worker_levels.get(str(worker_id), 1))
		if level < 1 or level > WorkerData.MAX_LEVEL:
			if OS.is_debug_build():
				print("WorkerManager repair: clamped level for ", worker_id)
			data.worker_levels[str(worker_id)] = clampi(level, 1, WorkerData.MAX_LEVEL)

	if data.stored_passive_coins < 0.0:
		data.stored_passive_coins = 0.0
