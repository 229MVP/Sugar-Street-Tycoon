class_name SpecialPiecePlanner
extends RefCounted
## Chooses which special piece (if any) is created from a resolved match cluster.


static func plan_creation(
	groups: Array,
	prefer_pos: Vector2i = Vector2i(-1, -1)
) -> Dictionary:
	## Returns empty dict or:
	## { "pos": Vector2i, "kind": SpecialPieceKind.Kind, "type_id": StringName }
	if groups.is_empty():
		return {}

	var cells: Dictionary = {}
	var type_id: StringName = &""
	var max_line := 0
	var has_horizontal_four := false
	var has_vertical_four := false
	var horizontal_line_pos := Vector2i.ZERO
	var vertical_line_pos := Vector2i.ZERO

	for group in groups:
		var size: int = group["size"]
		var gid: StringName = group["type_id"]
		if type_id == &"":
			type_id = gid
		max_line = maxi(max_line, size)
		for cell in group["cells"]:
			cells[cell] = true
			if size == 4:
				var first: Vector2i = group["cells"][0]
				var last: Vector2i = group["cells"][group["cells"].size() - 1]
				if first.y == last.y:
					has_horizontal_four = true
					horizontal_line_pos = _pick_preferred(group["cells"], prefer_pos)
				elif first.x == last.x:
					has_vertical_four = true
					vertical_line_pos = _pick_preferred(group["cells"], prefer_pos)

	var cell_list: Array[Vector2i] = []
	for cell in cells.keys():
		cell_list.append(cell)

	if max_line >= 5:
		return {
			"pos": _pick_preferred(cell_list, prefer_pos),
			"kind": SpecialPieceKind.Kind.RAINBOW,
			"type_id": type_id,
		}

	if _is_bomb_shape(cell_list):
		return {
			"pos": _pick_preferred(cell_list, prefer_pos),
			"kind": SpecialPieceKind.Kind.BOMB,
			"type_id": type_id,
		}

	if has_horizontal_four:
		return {
			"pos": horizontal_line_pos,
			"kind": SpecialPieceKind.Kind.LINE_H,
			"type_id": type_id,
		}

	if has_vertical_four:
		return {
			"pos": vertical_line_pos,
			"kind": SpecialPieceKind.Kind.LINE_V,
			"type_id": type_id,
		}

	return {}


static func _pick_preferred(cells: Array, prefer_pos: Vector2i) -> Vector2i:
	if prefer_pos.x >= 0 and prefer_pos.y >= 0:
		for cell in cells:
			if cell == prefer_pos:
				return prefer_pos
	if cells.is_empty():
		return Vector2i.ZERO
	return cells[cells.size() / 2]


static func _is_bomb_shape(cells: Array[Vector2i]) -> bool:
	## L/T shapes with 5+ connected cells in an orthogonal cluster.
	if cells.size() < 5:
		return false
	var cell_set: Dictionary = {}
	for cell in cells:
		cell_set[cell] = true
	for cell in cells:
		var neighbors := 0
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if cell_set.has(cell + offset):
				neighbors += 1
		if neighbors >= 3:
			return true
	return false
