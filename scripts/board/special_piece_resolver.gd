class_name SpecialPieceResolver
extends RefCounted
## Computes cells cleared when a special piece activates.


static func activation_cells(
	grid: Array,
	columns: int,
	rows: int,
	pos: Vector2i,
	kind: int,
	partner_type_id: StringName = &""
) -> Dictionary:
	var matched: Dictionary = {}
	match kind:
		SpecialPieceKind.Kind.LINE_H:
			for col in columns:
				matched[Vector2i(col, pos.y)] = true
		SpecialPieceKind.Kind.LINE_V:
			for row in rows:
				matched[Vector2i(pos.x, row)] = true
		SpecialPieceKind.Kind.BOMB:
			for row in range(maxi(0, pos.y - 1), mini(rows, pos.y + 2)):
				for col in range(maxi(0, pos.x - 1), mini(columns, pos.x + 2)):
					matched[Vector2i(col, row)] = true
		SpecialPieceKind.Kind.RAINBOW:
			if partner_type_id == &"":
				_collect_all_colored(grid, columns, rows, matched)
			else:
				_collect_color(grid, columns, rows, partner_type_id, matched)
	return matched


static func swap_activation(
	grid: Array,
	columns: int,
	rows: int,
	a: Vector2i,
	b: Vector2i
) -> Dictionary:
	var piece_a: DessertPiece = _piece_at(grid, a)
	var piece_b: DessertPiece = _piece_at(grid, b)
	if piece_a == null or piece_b == null:
		return {}

	var kind_a := piece_a.special_kind
	var kind_b := piece_b.special_kind
	if kind_a == SpecialPieceKind.Kind.NONE and kind_b == SpecialPieceKind.Kind.NONE:
		return {}

	var matched: Dictionary = {}
	if kind_a == SpecialPieceKind.Kind.RAINBOW and kind_b == SpecialPieceKind.Kind.RAINBOW:
		_collect_everything(grid, columns, rows, matched)
	elif kind_a == SpecialPieceKind.Kind.RAINBOW:
		_collect_color(grid, columns, rows, piece_b.get_match_type_id(), matched)
	elif kind_b == SpecialPieceKind.Kind.RAINBOW:
		_collect_color(grid, columns, rows, piece_a.get_match_type_id(), matched)
	else:
		_merge_dict(matched, activation_cells(grid, columns, rows, a, kind_a))
		_merge_dict(matched, activation_cells(grid, columns, rows, b, kind_b))
	return matched


static func _piece_at(grid: Array, pos: Vector2i) -> DessertPiece:
	if pos.y < 0 or pos.y >= grid.size():
		return null
	var row: Array = grid[pos.y]
	if pos.x < 0 or pos.x >= row.size():
		return null
	return row[pos.x] as DessertPiece


static func _collect_color(
	grid: Array,
	columns: int,
	rows: int,
	type_id: StringName,
	matched: Dictionary
) -> void:
	for row in rows:
		for col in columns:
			var piece: DessertPiece = grid[row][col]
			if piece == null:
				continue
			if piece.get_match_type_id() == type_id:
				matched[Vector2i(col, row)] = true


static func _collect_all_colored(
	grid: Array,
	columns: int,
	rows: int,
	matched: Dictionary
) -> void:
	for row in rows:
		for col in columns:
			var piece: DessertPiece = grid[row][col]
			if piece == null:
				continue
			if piece.special_kind != SpecialPieceKind.Kind.RAINBOW:
				matched[Vector2i(col, row)] = true


static func _collect_everything(
	grid: Array,
	columns: int,
	rows: int,
	matched: Dictionary
) -> void:
	for row in rows:
		for col in columns:
			if grid[row][col] != null:
				matched[Vector2i(col, row)] = true


static func _merge_dict(target: Dictionary, source: Dictionary) -> void:
	for key in source.keys():
		target[key] = true
