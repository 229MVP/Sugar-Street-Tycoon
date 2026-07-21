extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("=== swap integration test ===")
	var packed := load("res://scenes/main/main.tscn") as PackedScene
	var main_scene := packed.instantiate()
	root.add_child(main_scene)
	var board: MatchBoard
	var controller: GameController
	for _i in 90:
		await process_frame
		board = main_scene.get_tree().get_first_node_in_group("match_board") as MatchBoard
		controller = main_scene.get_tree().get_first_node_in_group("game_controller") as GameController
		if board and controller and board.grid.size() == board.rows and not board.is_input_locked():
			var filled := true
			for r in board.rows:
				for c in board.columns:
					if board.grid[r][c] == null:
						filled = false
			if filled:
				break
	var moves := SwapValidator.find_possible_moves(board.get_type_grid())
	if moves.is_empty():
		push_error("no moves to test")
		quit(1)
		return
	var before_moves := controller.get_moves()
	var move: Dictionary = moves[0]
	print("Trying swap ", move["from"], " -> ", move["to"])
	var ok: bool = await board.try_swap(move["from"], move["to"])
	print("swap valid=", ok, " moves now=", controller.get_moves(), " score=", controller.get_score())
	if not ok:
		push_error("expected valid swap to succeed")
		quit(1)
		return
	if controller.get_moves() != before_moves - 1:
		push_error("move was not consumed")
		quit(1)
		return
	if SwapValidator.has_any_match(board.get_type_grid()):
		push_error("matches remain after resolve")
		quit(1)
		return
	print("=== SWAP TEST PASS ===")
	quit(0)
