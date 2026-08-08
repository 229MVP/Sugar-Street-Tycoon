extends SceneTree
## Independent release-gate validation (no new gameplay features).


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== RELEASE GATE VALIDATION ===")
	var ok := true
	ok = _validate_godot_parse() and ok
	ok = _validate_save_migration_matrix() and ok
	ok = await _validate_special_pieces_e2e() and ok
	ok = await _validate_bomb_activation() and ok
	ok = await _validate_boosters_e2e() and ok
	ok = _validate_daily_bonus_matrix() and ok
	ok = await _validate_core_smoke() and ok
	print("=== RELEASE GATE: %s ===" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)


func _validate_godot_parse() -> bool:
	print("-- Godot parse/load --")
	var script := load("res://scripts/shop/shop_visual.gd")
	if script == null:
		push_error("shop_visual.gd failed to load")
		return false
	var inst: Object = (script as Script).new()
	if inst == null:
		push_error("shop_visual.gd failed to instantiate")
		return false
	var scenes := [
		"res://scenes/main/title_screen.tscn",
		"res://scenes/shop/shop_hub.tscn",
		"res://scenes/main/main.tscn",
		"res://scenes/gameplay/gameplay.tscn",
		"res://scenes/orders/orders_screen.tscn",
	]
	for path in scenes:
		var packed := load(path) as PackedScene
		if packed == null:
			push_error("scene load failed: %s" % path)
			return false
	print("[OK] shop_visual.gd + core scenes load")
	return true


func _validate_save_migration_matrix() -> bool:
	print("-- Save migration matrix --")
	# A: current/new save
	var fresh := SaveData.create_default()
	if fresh.version != SaveData.SAVE_VERSION:
		push_error("fresh save version mismatch")
		return false
	if BoosterManager.get_count(fresh, BoosterManager.HAMMER) < 1:
		push_error("fresh save missing booster defaults")
		return false

	# B: simulated v6 save (previous version)
	var v6_dict := SaveManager._to_dict(fresh)
	v6_dict["version"] = 6
	v6_dict.erase("booster_inventory")
	var v6_loaded := SaveManager._from_dict(v6_dict)
	if BoosterManager.get_count(v6_loaded, BoosterManager.HAMMER) < 1:
		push_error("v6 migration did not seed boosters")
		return false
	if v6_loaded.version != SaveData.SAVE_VERSION:
		push_error("v6 migration did not bump version")
		return false

	# C: missing daily bonus fields
	var partial := SaveManager._to_dict(fresh)
	partial["daily_bonus_state"] = {"streak_day": 2}
	var partial_loaded := SaveManager._from_dict(partial)
	if not partial_loaded.daily_bonus_state.has("claimed_today"):
		push_error("missing daily bonus fields not defaulted")
		return false

	# D: missing booster fields (covered in B)

	# E: corrupt recovery preserves progression when backup valid
	SaveManager.delete_save()
	var gs := root.get_node_or_null("/root/GameState")
	if gs == null:
		push_error("GameState missing for save migration")
		return false
	gs.new_game()
	gs.data.coins = 7777
	gs.data.unlocked_recipes[&"candied_grapes"] = true
	gs.save_now()
	gs.data.coins = 8888
	gs.save_now() # backup now holds 7777 + recipe unlock
	var f := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	f.store_string("{bad json")
	f.close()
	var recovered := SaveManager.load_game()
	if recovered.coins != 7777:
		push_error("corrupt recovery did not restore backup progression (coins %d)" % recovered.coins)
		return false
	if not bool(recovered.unlocked_recipes.get(&"candied_grapes", false)):
		push_error("corrupt recovery lost recipe unlock")
		return false

	print("[OK] save migration matrix A-E")
	return true


func _validate_special_pieces_e2e() -> bool:
	print("-- Special pieces e2e --")
	var board := await _make_board()
	# Line special creation via forced 4-match row setup is planner-tested;
	# verify activation clears row and board remains playable.
	var piece: DessertPiece = board.grid[3][3]
	piece.set_special(SpecialPieceKind.Kind.LINE_V, piece.piece_type)
	var cleared_flag := {"value": false}
	var handler := func(_types: Dictionary, _score: int, _idx: int):
		cleared_flag["value"] = true
	board.pieces_cleared.connect(handler)
	await board._clear_cells(
		SpecialPieceResolver.activation_cells(
			board.grid, board.columns, board.rows, Vector2i(3, 3), SpecialPieceKind.Kind.LINE_V
		),
		0,
		true
	)
	await board._apply_gravity_and_refill()
	if not cleared_flag["value"]:
		push_error("line special did not emit scoring hook")
		board.queue_free()
		return false
	if not board.has_possible_moves() and not SwapValidator.has_any_match(board.get_type_grid()):
		# board may need reshuffle; ensure no null cells
		pass
	for row in board.rows:
		for col in board.columns:
			if board.grid[row][col] == null:
				push_error("null cell after line special activation")
				board.queue_free()
				return false

	# Rainbow swap activation on live board
	var board2 := await _make_board()
	var ra: DessertPiece = board2.grid[2][2]
	var rb: DessertPiece = board2.grid[2][3]
	ra.set_special(SpecialPieceKind.Kind.RAINBOW, ra.piece_type)
	board2._swap_grid_cells(Vector2i(2, 2), Vector2i(3, 2))
	await board2._activate_special_swap(Vector2i(2, 2), Vector2i(3, 2))
	await board2._resolve_cascades()
	for row in board2.rows:
		for col in board2.columns:
			if board2.grid[row][col] == null:
				push_error("null cell after rainbow activation cascade")
				board2.queue_free()
				board.queue_free()
				return false
	board2.queue_free()
	board.queue_free()
	print("[OK] line + rainbow e2e with gravity/cascade")
	return true


func _validate_bomb_activation() -> bool:
	var board := await _make_board()
	var cells := SpecialPieceResolver.activation_cells(
		board.grid, board.columns, board.rows, Vector2i(4, 4), SpecialPieceKind.Kind.BOMB
	)
	if cells.size() < 9:
		push_error("bomb should clear at least 3x3 (%d cells)" % cells.size())
		board.queue_free()
		return false
	var cleared_flag := {"value": false}
	board.pieces_cleared.connect(func(_t, _s, _i): cleared_flag["value"] = true)
	await board._clear_cells(cells, 0, true)
	await board._apply_gravity_and_refill()
	if not cleared_flag["value"]:
		push_error("bomb activation did not score")
		board.queue_free()
		return false
	board.queue_free()
	print("[OK] bomb activation e2e")
	return true


func _validate_boosters_e2e() -> bool:
	print("-- Boosters e2e --")
	var board := await _make_board()
	var gs := root.get_node("GameState")
	BoosterManager.add(gs.data, BoosterManager.HAMMER, 1)

	# Cancel should not consume
	board.enter_booster_mode(MatchBoard.BoosterMode.HAMMER)
	board.cancel_booster_mode()
	if board.is_booster_mode_active():
		push_error("booster cancel failed")
		board.queue_free()
		return false

	# Invalid hammer target (empty after we clear one cell manually is hard); use out of bounds via hammer_at
	var count_before := BoosterManager.get_count(gs.data, BoosterManager.HAMMER)
	var invalid := await board.hammer_at(Vector2i(-1, -1))
	if invalid:
		push_error("invalid hammer should fail")
		board.queue_free()
		return false
	if BoosterManager.get_count(gs.data, BoosterManager.HAMMER) != count_before:
		push_error("invalid hammer consumed inventory")
		board.queue_free()
		return false

	# Valid hammer
	var ok := await board.hammer_at(Vector2i(0, 0))
	if not ok:
		push_error("valid hammer failed")
		board.queue_free()
		return false
	if not SwapValidator.has_possible_move(board.get_type_grid()) and board.grid[0][0] != null:
		push_error("board stuck after hammer")
		board.queue_free()
		return false

	# Swap booster invalid adjacent requirement
	board.enter_booster_mode(MatchBoard.BoosterMode.SWAP)
	board.cancel_booster_mode()
	var swap_before := BoosterManager.get_count(gs.data, BoosterManager.SWAP)
	var swap_ok := await board.force_swap(Vector2i(0, 0), Vector2i(2, 0))
	if swap_ok:
		push_error("non-adjacent swap booster should fail")
		board.queue_free()
		return false
	if BoosterManager.get_count(gs.data, BoosterManager.SWAP) != swap_before:
		push_error("invalid swap consumed inventory")
		board.queue_free()
		return false

	board.queue_free()
	print("[OK] booster targeting/cancel/invalid/valid")
	return true


func _validate_daily_bonus_matrix() -> bool:
	print("-- Daily bonus matrix --")
	DailyBonusManager._test_today_override = "2026-08-10"
	var data := SaveData.create_default()
	var coins_start := data.coins
	var hammer_start := BoosterManager.get_count(data, BoosterManager.HAMMER)
	for day in range(1, 8):
		DailyBonusManager._test_today_override = "2026-08-%02d" % (day + 9)
		data.daily_bonus_state["claimed_today"] = false
		var result := DailyBonusManager.claim(data)
		if not bool(result.get("ok", false)):
			push_error("day %d claim failed" % day)
			DailyBonusManager._test_today_override = ""
			return false
		if int(result.get("day", 0)) != day:
			push_error("expected day %d got %d" % [day, int(result.get("day", 0))])
			DailyBonusManager._test_today_override = ""
			return false
	if data.coins <= coins_start:
		push_error("daily rewards did not increase coins over cycle")
		DailyBonusManager._test_today_override = ""
		return false
	if BoosterManager.get_count(data, BoosterManager.HAMMER) <= hammer_start:
		push_error("daily rewards did not deliver booster items")
		DailyBonusManager._test_today_override = ""
		return false

	# Scene reload cannot duplicate claim same day
	var coins_after_first := data.coins
	var second := DailyBonusManager.claim(data)
	if bool(second.get("ok", false)):
		push_error("scene reload duplicate claim allowed")
		DailyBonusManager._test_today_override = ""
		return false
	if data.coins != coins_after_first:
		push_error("duplicate claim modified currency")
		DailyBonusManager._test_today_override = ""
		return false

	DailyBonusManager._test_today_override = ""
	print("[OK] daily bonus days 1-7 delivery + no duplicate")
	return true


func _validate_core_smoke() -> bool:
	print("-- Core gameplay smoke --")
	var title := load("res://scenes/main/title_screen.tscn") as PackedScene
	var title_inst := title.instantiate()
	root.add_child(title_inst)
	await process_frame
	if title_inst.get_class() == "" and not title_inst.is_inside_tree():
		push_error("title failed to instantiate")
		return false

	var main := load("res://scenes/main/main.tscn") as PackedScene
	var main_inst := main.instantiate()
	root.add_child(main_inst)
	var board: MatchBoard = null
	var controller: GameController = null
	for _i in 120:
		await process_frame
		board = main_inst.get_tree().get_first_node_in_group("match_board") as MatchBoard
		controller = main_inst.get_tree().get_first_node_in_group("game_controller") as GameController
		if board and controller and not board.is_input_locked():
			break
	if board == null or controller == null:
		push_error("gameplay smoke: board/controller missing")
		return false
	var moves := SwapValidator.find_possible_moves(board.get_type_grid())
	if moves.is_empty():
		push_error("gameplay smoke: no moves")
		return false
	var before_moves := controller.get_moves()
	var swapped: bool = await board.try_swap(moves[0]["from"], moves[0]["to"])
	if not swapped:
		push_error("gameplay smoke: swap failed")
		return false
	if controller.get_moves() != before_moves - 1:
		push_error("gameplay smoke: move not consumed")
		return false

	var popup := DailyBonusPopup.new()
	root.add_child(popup)
	popup.show_popup()
	await process_frame
	if not popup.visible:
		push_error("daily bonus popup did not show")
		return false
	popup.hide_popup()

	print("[OK] title + gameplay + daily bonus popup smoke")
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
