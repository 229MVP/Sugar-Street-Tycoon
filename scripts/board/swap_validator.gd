class_name SwapValidator
extends RefCounted
## Validates adjacent swaps and enumerates possible moves.


static func are_adjacent(a: Vector2i, b: Vector2i) -> bool:
	var delta := (a - b).abs()
	return (delta.x == 1 and delta.y == 0) or (delta.x == 0 and delta.y == 1)


## Returns true if swapping the two cells would create at least one match of 3+.
## Operates on a lightweight type-id grid so it can be used during generation
## before piece nodes exist.
static func would_create_match(type_grid: Array, a: Vector2i, b: Vector2i) -> bool:
	if not are_adjacent(a, b):
		return false
	_swap_types(type_grid, a, b)
	var has_match := _has_any_match(type_grid)
	_swap_types(type_grid, a, b) # restore
	return has_match


static func find_possible_moves(type_grid: Array) -> Array[Dictionary]:
	var moves: Array[Dictionary] = []
	var rows := type_grid.size()
	if rows == 0:
		return moves
	var columns: int = (type_grid[0] as Array).size()
	# Check right and down neighbors only to avoid duplicates.
	for row in rows:
		for col in columns:
			var from := Vector2i(col, row)
			if col + 1 < columns:
				var to := Vector2i(col + 1, row)
				if would_create_match(type_grid, from, to):
					moves.append({"from": from, "to": to})
			if row + 1 < rows:
				var to := Vector2i(col, row + 1)
				if would_create_match(type_grid, from, to):
					moves.append({"from": from, "to": to})
	return moves


static func has_possible_move(type_grid: Array) -> bool:
	return not find_possible_moves(type_grid).is_empty()


static func has_any_match(type_grid: Array) -> bool:
	return _has_any_match(type_grid)


static func _swap_types(type_grid: Array, a: Vector2i, b: Vector2i) -> void:
	var tmp = type_grid[a.y][a.x]
	type_grid[a.y][a.x] = type_grid[b.y][b.x]
	type_grid[b.y][b.x] = tmp


static func _has_any_match(type_grid: Array) -> bool:
	var rows := type_grid.size()
	var columns: int = (type_grid[0] as Array).size()
	# Horizontal
	for row in rows:
		var col := 0
		while col < columns:
			var type_id = type_grid[row][col]
			var run_len := 1
			while col + run_len < columns and type_grid[row][col + run_len] == type_id:
				run_len += 1
			if type_id != null and type_id != &"" and run_len >= 3:
				return true
			col += run_len
	# Vertical
	for col in columns:
		var row := 0
		while row < rows:
			var type_id = type_grid[row][col]
			var run_len := 1
			while row + run_len < rows and type_grid[row + run_len][col] == type_id:
				run_len += 1
			if type_id != null and type_id != &"" and run_len >= 3:
				return true
			row += run_len
	return false
