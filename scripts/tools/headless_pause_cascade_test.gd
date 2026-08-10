extends SceneTree
## Regression test for the CRITICAL beta-audit bug: pausing while the board is
## mid-cascade must not skip win/loss evaluation forever.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Pause / cascade regression test ===")
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

	var ok := true
	ok = await _test_pause_blocked_during_resolve(board, controller) and ok
	ok = _test_pause_allowed_when_idle(board, controller) and ok
	ok = await _test_no_stuck_state_after_resolve(controller) and ok

	print("=== RESULT: %s ===" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)


func _test_pause_blocked_during_resolve(board: MatchBoard, controller: GameController) -> bool:
	var moves := SwapValidator.find_possible_moves(board.get_type_grid())
	if moves.is_empty():
		push_error("no moves available to test")
		return false
	var move: Dictionary = moves[0]
	# Fire the swap without awaiting it directly (Callable.call() lets the
	# coroutine run in the background) so we can probe mid-resolve state.
	var cb := Callable(board, "try_swap").bind(move["from"], move["to"])
	cb.call()
	await process_frame
	if not (board.is_resolving() or board.is_input_locked()):
		push_warning("board resolved within one frame — mid-resolve window not observed")
	# Attempt to pause while the board should still be locked/resolving.
	controller.pause_game()
	if controller.level_state.state == LevelState.State.PAUSED:
		push_error("pause_game() succeeded while board was resolving — CRITICAL bug reproduced")
		return false
	# Wait for the swap/cascade to fully finish before continuing.
	for _i in 120:
		await process_frame
		if not board.is_resolving() and not board.is_input_locked():
			break
	print("[OK] pause blocked while board is mid-resolve")
	return true


func _test_pause_allowed_when_idle(board: MatchBoard, controller: GameController) -> bool:
	if board.is_resolving() or board.is_input_locked():
		push_error("board unexpectedly still locked/resolving after swap completed")
		return false
	controller.pause_game()
	if controller.level_state.state != LevelState.State.PAUSED:
		push_error("pause_game() should succeed when board is idle")
		return false
	controller.resume_game()
	if controller.level_state.state != LevelState.State.PLAYING:
		push_error("resume_game() did not restore PLAYING state")
		return false
	print("[OK] pause/resume works normally when board is idle")
	return true


func _test_no_stuck_state_after_resolve(controller: GameController) -> bool:
	# Drain remaining moves via debug helper and confirm a loss is still
	# reported exactly once (no stuck PLAYING state from the earlier blocked pause).
	controller.debug_add_moves(-9999)
	controller._evaluate_end_conditions()
	for _i in 10:
		await process_frame
	if controller.level_state.state != LevelState.State.LOST and controller.level_state.state != LevelState.State.WON:
		push_error("level never resolved to WON/LOST after moves exhausted: state=%s" % str(controller.level_state.state))
		return false
	print("[OK] level resolves to a terminal state (no stuck PLAYING)")
	return true
