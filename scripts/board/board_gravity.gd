class_name BoardGravity
extends RefCounted
## Applies gravity (pieces fall into empty cells) and plans refill spawns.


## Compacts each column downward. Returns list of move descriptors:
## { "piece": DessertPiece, "from": Vector2i, "to": Vector2i }
static func apply_gravity(grid: Array, columns: int, rows: int) -> Array:
	var moves: Array = []
	for col in columns:
		var write_row := rows - 1
		for read_row in range(rows - 1, -1, -1):
			var piece: DessertPiece = grid[read_row][col]
			if piece == null:
				continue
			if write_row != read_row:
				grid[write_row][col] = piece
				grid[read_row][col] = null
				var from := Vector2i(col, read_row)
				var to := Vector2i(col, write_row)
				piece.grid_pos = to
				moves.append({"piece": piece, "from": from, "to": to})
			write_row -= 1
		# Clear anything above the compacted stack (already null, but be explicit).
		for row in range(write_row, -1, -1):
			grid[row][col] = null
	return moves


## Returns spawn descriptors for empty cells: { "pos": Vector2i }
static func find_empty_cells(grid: Array, columns: int, rows: int) -> Array:
	var empties: Array = []
	for col in columns:
		for row in rows:
			if grid[row][col] == null:
				empties.append({"pos": Vector2i(col, row)})
	return empties
