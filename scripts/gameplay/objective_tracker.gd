class_name ObjectiveTracker
extends RefCounted
## Tracks collect-style objectives for the active level.

signal progress_changed(piece_id: StringName, current: int, target: int)
signal objective_completed

var _targets: Dictionary = {} # StringName -> int
var _progress: Dictionary = {} # StringName -> int
var _descriptions: Dictionary = {} # StringName -> String
var _completed: bool = false


func setup(objectives: Array[ObjectiveData]) -> void:
	_targets.clear()
	_progress.clear()
	_descriptions.clear()
	_completed = false
	for objective in objectives:
		if objective == null:
			continue
		_targets[objective.piece_id] = objective.target_amount
		_progress[objective.piece_id] = 0
		_descriptions[objective.piece_id] = objective.description
		progress_changed.emit(objective.piece_id, 0, objective.target_amount)


func reset() -> void:
	for piece_id in _targets.keys():
		_progress[piece_id] = 0
		progress_changed.emit(piece_id, 0, _targets[piece_id])
	_completed = false


func register_cleared(cleared_types: Dictionary) -> void:
	if _completed:
		return
	for type_id in cleared_types.keys():
		if not _targets.has(type_id):
			continue
		var amount: int = int(cleared_types[type_id])
		var current: int = int(_progress.get(type_id, 0))
		var target: int = int(_targets[type_id])
		current = mini(current + amount, target)
		_progress[type_id] = current
		progress_changed.emit(type_id, current, target)
	if is_complete() and not _completed:
		_completed = true
		objective_completed.emit()


func add_debug_progress(piece_id: StringName, amount: int) -> void:
	var fake := {piece_id: amount}
	register_cleared(fake)


func get_progress(piece_id: StringName) -> int:
	return int(_progress.get(piece_id, 0))


func get_target(piece_id: StringName) -> int:
	return int(_targets.get(piece_id, 0))


func get_primary_piece_id() -> StringName:
	if _targets.is_empty():
		return &""
	return _targets.keys()[0]


func get_primary_description() -> String:
	var id := get_primary_piece_id()
	return str(_descriptions.get(id, "Complete the order"))


func is_complete() -> bool:
	for piece_id in _targets.keys():
		if int(_progress.get(piece_id, 0)) < int(_targets[piece_id]):
			return false
	return not _targets.is_empty()


func get_progress_text() -> String:
	var id := get_primary_piece_id()
	return "%d / %d" % [get_progress(id), get_target(id)]
