extends SceneTree
## Booster regression: hammer + swap inventory, targeting, persistence.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== boosters test ===")
	var ok := true
	ok = _test_inventory_defaults() and ok
	ok = await _test_hammer_use() and ok
	ok = await _test_swap_use() and ok
	ok = _test_zero_count_blocks() and ok
	ok = _test_save_roundtrip() and ok
	print("=== BOOSTERS TEST: %s ===" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)


func _test_inventory_defaults() -> bool:
	var data := SaveData.create_default()
	if BoosterManager.get_count(data, BoosterManager.HAMMER) < 1:
		push_error("starter hammer count missing")
		return false
	if BoosterManager.get_count(data, BoosterManager.SWAP) < 1:
		push_error("starter swap count missing")
		return false
	print("[OK] booster defaults")
	return true


func _test_hammer_use() -> bool:
	var board := await _make_board()
	var gs := root.get_node_or_null("GameState")
	if gs == null:
		push_error("GameState autoload missing")
		return false
	BoosterManager.add(gs.data, BoosterManager.HAMMER, 0)
	BoosterManager.add(gs.data, BoosterManager.HAMMER, 2)
	var before := BoosterManager.get_count(gs.data, BoosterManager.HAMMER)
	var target := Vector2i(0, 0)
	var ok: bool = await board.hammer_at(target)
	if not ok:
		push_error("hammer_at failed on valid tile")
		board.queue_free()
		return false
	if not BoosterManager.consume(gs.data, BoosterManager.HAMMER):
		push_error("hammer consume failed")
		board.queue_free()
		return false
	if BoosterManager.get_count(gs.data, BoosterManager.HAMMER) != before - 1:
		push_error("hammer inventory not decremented")
		board.queue_free()
		return false
	board.queue_free()
	print("[OK] hammer valid use + inventory")
	return true


func _test_swap_use() -> bool:
	var board := await _make_board()
	var gs := root.get_node("GameState")
	BoosterManager.add(gs.data, BoosterManager.SWAP, 1)
	var before := BoosterManager.get_count(gs.data, BoosterManager.SWAP)
	var a := Vector2i(0, 0)
	var b := Vector2i(1, 0)
	var ok: bool = await board.force_swap(a, b)
	if not ok:
		push_error("force_swap failed")
		board.queue_free()
		return false
	if not BoosterManager.consume(gs.data, BoosterManager.SWAP):
		push_error("swap consume failed")
		board.queue_free()
		return false
	if BoosterManager.get_count(gs.data, BoosterManager.SWAP) != before - 1:
		push_error("swap inventory not decremented")
		board.queue_free()
		return false
	board.queue_free()
	print("[OK] swap valid use + inventory")
	return true


func _test_zero_count_blocks() -> bool:
	var data := SaveData.create_default()
	data.booster_inventory = {"hammer": 0, "swap": 0}
	if BoosterManager.can_use(data, BoosterManager.HAMMER):
		push_error("zero hammer should block use")
		return false
	if BoosterManager.consume(data, BoosterManager.HAMMER):
		push_error("zero hammer should not consume")
		return false
	print("[OK] zero-count behavior")
	return true


func _test_save_roundtrip() -> bool:
	var gs := root.get_node("GameState")
	gs.data.booster_inventory = {"hammer": 4, "swap": 2}
	gs.save_now()
	var loaded := SaveManager.load_game()
	if BoosterManager.get_count(loaded, BoosterManager.HAMMER) != 4:
		push_error("hammer not persisted")
		return false
	if BoosterManager.get_count(loaded, BoosterManager.SWAP) != 2:
		push_error("swap not persisted")
		return false
	print("[OK] booster save roundtrip")
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
	await board.setup_from_config(level)
	return board
