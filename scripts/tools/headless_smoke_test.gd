extends SceneTree
## Run: godot --headless --path . -s res://scripts/tools/headless_smoke_test.gd


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Sugar Street Tycoon smoke test ===")
	var ok := true
	ok = _test_resources() and ok
	ok = _test_match_and_swap() and ok
	var level_ok: bool = await _test_level_start()
	ok = level_ok and ok
	print("=== RESULT: %s ===" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)


func _test_resources() -> bool:
	var level := load("res://resources/levels/level_01.tres") as LevelConfig
	if level == null:
		push_error("Failed to load level_01.tres")
		return false
	if not level.validate():
		push_error("level_01 failed validation")
		return false
	if level.piece_types.size() != 6:
		push_error("Expected 6 piece types")
		return false
	if level.move_limit != 20:
		push_error("Expected 20 moves")
		return false
	var obj := level.get_primary_objective()
	if obj == null or obj.piece_id != &"strawberry" or obj.target_amount != 20:
		push_error("Primary objective mismatch")
		return false
	print("[OK] resources")
	return true


func _test_match_and_swap() -> bool:
	var grid: Array = [
		[&"a", &"a", &"b", &"c"],
		[&"d", &"e", &"a", &"f"],
		[&"g", &"h", &"a", &"i"],
		[&"j", &"k", &"l", &"m"],
	]
	if not SwapValidator.are_adjacent(Vector2i(2, 0), Vector2i(2, 1)):
		push_error("adjacency failed")
		return false
	if not SwapValidator.would_create_match(grid, Vector2i(2, 0), Vector2i(2, 1)):
		push_error("expected valid match-creating swap")
		return false
	if SwapValidator.would_create_match(grid, Vector2i(0, 0), Vector2i(0, 1)):
		push_error("expected invalid swap")
		return false
	if not SwapValidator.has_possible_move(grid):
		push_error("expected possible moves")
		return false
	print("[OK] match/swap validator")
	return true


func _test_level_start() -> bool:
	## Boot through main.tscn (working puzzle host), not the title screen.
	var packed := load("res://scenes/main/main.tscn") as PackedScene
	if packed == null:
		push_error("main.tscn missing")
		return false
	var main_scene: Node = packed.instantiate()
	root.add_child(main_scene)

	var board: Node = null
	var controller: Node = null
	for _i in 90:
		await process_frame
		board = main_scene.get_tree().get_first_node_in_group("match_board")
		controller = main_scene.get_tree().get_first_node_in_group("game_controller")
		if board == null or controller == null:
			continue
		if int(board.get("grid").size()) != int(board.get("rows")):
			continue
		var filled := true
		for row in range(int(board.get("rows"))):
			for col in range(int(board.get("columns"))):
				if board.get("grid")[row][col] == null:
					filled = false
					break
			if not filled:
				break
		if filled and not board.call("is_input_locked"):
			break

	if board == null or controller == null:
		push_error("board/controller not found in tree")
		return false
	if board.get("grid").is_empty():
		push_error("board grid empty after start")
		return false
	if SwapValidator.has_any_match(board.call("get_type_grid")):
		push_error("starting board contains matches")
		return false
	if not board.call("has_possible_moves"):
		push_error("starting board has no moves")
		return false
	if int(controller.call("get_moves")) != 20:
		push_error("moves not 20 at start (got %d)" % int(controller.call("get_moves")))
		return false
	if int(controller.call("get_target")) != 20:
		push_error("objective target not 20")
		return false
	print("[OK] main.tscn puzzle start (no initial matches, has moves, HUD state)")
	main_scene.queue_free()
	await process_frame
	return true
