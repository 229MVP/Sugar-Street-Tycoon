class_name LevelConfig
extends Resource
## Data-driven level configuration loaded by the board / game controller.

@export var level_id: String = "level_01"
@export var level_name: String = "Test Kitchen"
@export var columns: int = 8
@export var rows: int = 8
@export var move_limit: int = 20
@export var piece_types: Array[PieceType] = []
@export var objectives: Array[ObjectiveData] = []
## Minimum number of valid swaps that must exist after board generation / reshuffle.
@export var min_valid_moves: int = 1


func get_primary_objective() -> ObjectiveData:
	if objectives.is_empty():
		return null
	return objectives[0]


func get_piece_type(piece_id: StringName) -> PieceType:
	for piece_type in piece_types:
		if piece_type != null and piece_type.id == piece_id:
			return piece_type
	return null


func validate() -> bool:
	if columns < 3 or rows < 3:
		push_error("LevelConfig '%s': board must be at least 3x3." % level_id)
		return false
	if move_limit <= 0:
		push_error("LevelConfig '%s': move_limit must be > 0." % level_id)
		return false
	if piece_types.size() < 3:
		push_error("LevelConfig '%s': need at least 3 piece types." % level_id)
		return false
	for piece_type in piece_types:
		if piece_type == null or not piece_type.is_valid():
			push_error("LevelConfig '%s': invalid piece type entry." % level_id)
			return false
	if objectives.is_empty():
		push_error("LevelConfig '%s': at least one objective is required." % level_id)
		return false
	for objective in objectives:
		if objective == null or not objective.is_valid():
			push_error("LevelConfig '%s': invalid objective entry." % level_id)
			return false
		if get_piece_type(objective.piece_id) == null:
			push_error("LevelConfig '%s': objective piece '%s' not in piece_types." % [level_id, objective.piece_id])
			return false
	return true
