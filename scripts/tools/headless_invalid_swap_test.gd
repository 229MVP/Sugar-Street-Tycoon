extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("=== invalid swap test ===")
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
			break
	var before := controller.get_moves()
	# Find an adjacent pair that does NOT create a match.
	var found := false
	for row in board.rows:
		for col in board.columns:
			for dir in [Vector2i(1,0), Vector2i(0,1)]:
				var a := Vector2i(col, row)
				var b: Vector2i = a + dir
				if b.x >= board.columns or b.y >= board.rows:
					continue
				if not SwapValidator.would_create_match(board.get_type_grid(), a, b):
					var ok: bool = await board.try_swap(a, b)
					print("invalid swap result=", ok, " moves=", controller.get_moves())
					if ok:
						push_error("invalid swap reported valid")
						quit(1)
						return
					if controller.get_moves() != before:
						push_error("invalid swap consumed a move")
						quit(1)
						return
					found = true
					break
			if found:
				break
		if found:
			break
	if not found:
		push_error("could not find invalid adjacent swap")
		quit(1)
		return
	print("=== INVALID SWAP TEST PASS ===")
	quit(0)
