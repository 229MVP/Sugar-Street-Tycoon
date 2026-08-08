extends SceneTree
## Special pieces regression: line, bomb, rainbow creation/activation.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== special pieces test ===")
	var ok := true
	ok = _test_planner() and ok
	ok = await _test_line_activation() and ok
	ok = await _test_rainbow_swap() and ok
	ok = await _test_board_integrity() and ok
	print("=== SPECIAL PIECES TEST: %s ===" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)


func _test_planner() -> bool:
	var groups := [{
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)],
		"size": 4,
		"type_id": &"strawberry",
	}]
	var plan := SpecialPiecePlanner.plan_creation(groups, Vector2i(2, 0))
	if plan.is_empty() or plan["kind"] != SpecialPieceKind.Kind.LINE_H:
		push_error("expected horizontal line special from 4-match")
		return false

	groups = [{
		"cells": [
			Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1),
			Vector2i(2, 0), Vector2i(2, 2),
		],
		"size": 3,
		"type_id": &"cupcake",
	}]
	plan = SpecialPiecePlanner.plan_creation(groups, Vector2i(2, 1))
	if plan.is_empty() or plan["kind"] != SpecialPieceKind.Kind.BOMB:
		push_error("expected bomb from T/L shape")
		return false

	groups = [{
		"cells": [
			Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2),
		],
		"size": 5,
		"type_id": &"chocolate",
	}]
	plan = SpecialPiecePlanner.plan_creation(groups, Vector2i(2, 2))
	if plan.is_empty() or plan["kind"] != SpecialPieceKind.Kind.RAINBOW:
		push_error("expected rainbow from 5-match")
		return false

	print("[OK] special planner")
	return true


func _test_line_activation() -> bool:
	var board := await _make_board()
	var piece: DessertPiece = board.grid[2][2]
	piece.set_special(SpecialPieceKind.Kind.LINE_H, piece.piece_type)
	var cells := SpecialPieceResolver.activation_cells(
		board.grid, board.columns, board.rows, Vector2i(2, 2), SpecialPieceKind.Kind.LINE_H
	)
	if cells.size() != board.columns:
		push_error("line special should clear entire row")
		board.queue_free()
		return false
	board.queue_free()
	print("[OK] line activation area")
	return true


func _test_rainbow_swap() -> bool:
	var board := await _make_board()
	var a: DessertPiece = board.grid[1][1]
	var b: DessertPiece = board.grid[1][2]
	a.set_special(SpecialPieceKind.Kind.RAINBOW, a.piece_type)
	var target_type: StringName = b.get_type_id()
	var cells := SpecialPieceResolver.swap_activation(
		board.grid, board.columns, board.rows, Vector2i(1, 1), Vector2i(2, 1)
	)
	var expected := 0
	for row in board.rows:
		for col in board.columns:
			var p: DessertPiece = board.grid[row][col]
			if p and p.get_match_type_id() == target_type:
				expected += 1
	if cells.size() != expected:
		push_error("rainbow swap should clear all of target color (%d vs %d)" % [cells.size(), expected])
		board.queue_free()
		return false
	board.queue_free()
	print("[OK] rainbow swap activation")
	return true


func _test_board_integrity() -> bool:
	var board := await _make_board()
	var before_children := board.get_node("PiecesRoot").get_child_count()
	var moves := SwapValidator.find_possible_moves(board.get_type_grid())
	if moves.is_empty():
		push_error("no moves on test board")
		board.queue_free()
		return false
	var ok: bool = await board.try_swap(moves[0]["from"], moves[0]["to"])
	if not ok:
		push_error("valid swap failed")
		board.queue_free()
		return false
	for row in board.rows:
		for col in board.columns:
			var piece: DessertPiece = board.grid[row][col]
			if piece == null:
				push_error("null grid cell after cascade")
				board.queue_free()
				return false
	var after_children := board.get_node("PiecesRoot").get_child_count()
	if after_children != board.rows * board.columns:
		push_error("orphaned/missing piece nodes after resolve")
		board.queue_free()
		return false
	if before_children != after_children and after_children != board.rows * board.columns:
		push_error("invalid piece node count")
		board.queue_free()
		return false
	board.queue_free()
	print("[OK] board integrity after cascade")
	return true


func _make_board() -> MatchBoard:
	var level := load("res://resources/levels/level_01.tres") as LevelConfig
	var board := MatchBoard.new()
	var pieces_root := Control.new()
	pieces_root.name = "PiecesRoot"
	board.add_child(pieces_root)
	var bg := Panel.new()
	bg.name = "BoardBackground"
	board.add_child(bg)
	root.add_child(board)
	board.set_anchors_preset(Control.PRESET_FULL_RECT)
	await board.setup_from_config(level)
	return board
