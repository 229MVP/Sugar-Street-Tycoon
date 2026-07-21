class_name MatchDetector
extends RefCounted
## Finds horizontal and vertical runs of 3+ identical pieces.

## Returns a dictionary of Vector2i -> true for every cell involved in a match.
static func find_matches(grid: Array, columns: int, rows: int) -> Dictionary:
	var matched: Dictionary = {}
	_find_horizontal(grid, columns, rows, matched)
	_find_vertical(grid, columns, rows, matched)
	return matched


## Groups matched cells into contiguous runs for scoring (size of each run).
## Overlapping L/T shapes may produce multiple runs that share cells; callers
## should score by unique cells with the largest run size touching each cell.
static func find_match_groups(grid: Array, columns: int, rows: int) -> Array:
	var groups: Array = []
	# Horizontal groups
	for row in rows:
		var col := 0
		while col < columns:
			var piece: DessertPiece = grid[row][col]
			if piece == null:
				col += 1
				continue
			var type_id := piece.get_type_id()
			var run_len := 1
			while col + run_len < columns:
				var next_piece: DessertPiece = grid[row][col + run_len]
				if next_piece == null or next_piece.get_type_id() != type_id:
					break
				run_len += 1
			if run_len >= 3:
				var cells: Array[Vector2i] = []
				for i in run_len:
					cells.append(Vector2i(col + i, row))
				groups.append({"cells": cells, "size": run_len, "type_id": type_id})
			col += run_len
	# Vertical groups
	for col in columns:
		var row := 0
		while row < rows:
			var piece: DessertPiece = grid[row][col]
			if piece == null:
				row += 1
				continue
			var type_id := piece.get_type_id()
			var run_len := 1
			while row + run_len < rows:
				var next_piece: DessertPiece = grid[row + run_len][col]
				if next_piece == null or next_piece.get_type_id() != type_id:
					break
				run_len += 1
			if run_len >= 3:
				var cells: Array[Vector2i] = []
				for i in run_len:
					cells.append(Vector2i(col, row + i))
				groups.append({"cells": cells, "size": run_len, "type_id": type_id})
			row += run_len
	return groups


## Per-cell score tier: uses the largest matching run that includes the cell.
static func cell_score_tiers(groups: Array) -> Dictionary:
	var tiers: Dictionary = {}
	for group in groups:
		var size: int = group["size"]
		for cell in group["cells"]:
			var key: Vector2i = cell
			if not tiers.has(key) or size > tiers[key]:
				tiers[key] = size
	return tiers


static func _find_horizontal(grid: Array, columns: int, rows: int, matched: Dictionary) -> void:
	for row in rows:
		var col := 0
		while col < columns:
			var piece: DessertPiece = grid[row][col]
			if piece == null:
				col += 1
				continue
			var type_id := piece.get_type_id()
			var run_len := 1
			while col + run_len < columns:
				var next_piece: DessertPiece = grid[row][col + run_len]
				if next_piece == null or next_piece.get_type_id() != type_id:
					break
				run_len += 1
			if run_len >= 3:
				for i in run_len:
					matched[Vector2i(col + i, row)] = true
			col += run_len


static func _find_vertical(grid: Array, columns: int, rows: int, matched: Dictionary) -> void:
	for col in columns:
		var row := 0
		while row < rows:
			var piece: DessertPiece = grid[row][col]
			if piece == null:
				row += 1
				continue
			var type_id := piece.get_type_id()
			var run_len := 1
			while row + run_len < rows:
				var next_piece: DessertPiece = grid[row + run_len][col]
				if next_piece == null or next_piece.get_type_id() != type_id:
					break
				run_len += 1
			if run_len >= 3:
				for i in run_len:
					matched[Vector2i(col, row + i)] = true
			row += run_len
