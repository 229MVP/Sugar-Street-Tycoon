class_name PuzzleLevelDefinition
extends Resource
## Data-driven match-3 board template. Bridges into the existing LevelConfig /
## ObjectiveData resources so the working match-3 board is untouched.

## Stable string id used as the save-file key. Never change once shipped.
@export var id: String = ""
@export var display_name: String = ""
@export var columns: int = 8
@export var rows: int = 8
@export var move_limit: int = 20
@export var min_valid_moves: int = 1
@export var piece_type_ids: PackedStringArray = ["chocolate", "strawberry", "cupcake", "donut", "cookie", "candy"]
## Array of {"piece_id": String, "amount": int, "description": String}
@export var objectives: Array[Dictionary] = []


func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	if id.strip_edges() == "":
		errors.append("PuzzleLevelDefinition: id is required")
	if columns < 3 or rows < 3:
		errors.append("PuzzleLevelDefinition '%s': board must be at least 3x3" % id)
	if move_limit < 1:
		errors.append("PuzzleLevelDefinition '%s': move_limit must be >= 1" % id)
	if objectives.is_empty():
		errors.append("PuzzleLevelDefinition '%s': requires at least one objective" % id)
	return errors


## Bridge into the legacy LevelConfig resource used by the match-3 board scene.
func to_level_config(piece_types: Array[PieceType]) -> LevelConfig:
	var level := LevelConfig.new()
	level.level_id = id
	level.level_name = display_name
	level.columns = columns
	level.rows = rows
	level.move_limit = move_limit
	level.min_valid_moves = min_valid_moves
	level.piece_types = piece_types
	var objs: Array[ObjectiveData] = []
	for entry in objectives:
		var obj := ObjectiveData.new()
		obj.piece_id = StringName(str(entry.get("piece_id", "")))
		obj.target_amount = int(entry.get("amount", 0))
		obj.description = str(entry.get("description", ""))
		objs.append(obj)
	level.objectives = objs
	return level
