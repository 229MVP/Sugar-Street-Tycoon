extends SceneTree
## Validates title main scene, shop loop, and Mia order level config without bare Autoload IDs.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Title/shop navigation smoke test ===")
	var ok := true

	var main_scene := str(ProjectSettings.get_setting("application/run/main_scene", ""))
	if main_scene != "res://scenes/main/title_screen.tscn":
		push_error("main scene is '%s'" % main_scene)
		ok = false
	else:
		print("[OK] main scene = title_screen.tscn")

	for path in [
		"res://scenes/main/title_screen.tscn",
		"res://scenes/shop/shop_hub.tscn",
		"res://scenes/main/main.tscn",
		"res://scenes/gameplay/gameplay.tscn",
	]:
		if not ResourceLoader.exists(path):
			push_error("missing %s" % path)
			ok = false
		else:
			print("[OK] exists %s" % path)

	# Wait a frame so Autoloads finish _ready.
	await process_frame
	await process_frame

	var gs := root.get_node_or_null("/root/GameState")
	var router := root.get_node_or_null("/root/SceneRouter")
	if gs == null or router == null:
		push_error("Autoloads missing (GameState/SceneRouter)")
		ok = false
		print("=== RESULT: FAIL ===")
		quit(1)
		return

	if str(router.TITLE_SCENE) != "res://scenes/main/title_screen.tscn":
		push_error("SceneRouter TITLE_SCENE wrong: %s" % str(router.TITLE_SCENE))
		ok = false
	else:
		print("[OK] SceneRouter TITLE_SCENE")
	if str(router.GAMEPLAY_SCENE) != "res://scenes/main/main.tscn":
		push_error("SceneRouter GAMEPLAY_SCENE wrong: %s" % str(router.GAMEPLAY_SCENE))
		ok = false
	else:
		print("[OK] SceneRouter GAMEPLAY_SCENE = main.tscn")

	SaveManager.delete_save()
	gs.new_game()

	var visible: Array = gs.get_visible_orders()
	if visible.size() != 3:
		push_error("expected 3 starter orders, got %d" % visible.size())
		ok = false
	else:
		var names: PackedStringArray = []
		for o in visible:
			names.append(o.customer_name)
		if not ("Mia" in names and "Jordan" in names and "Taylor" in names):
			push_error("starter customers mismatch: %s" % ", ".join(names))
			ok = false
		else:
			print("[OK] starter orders Mia/Jordan/Taylor")

	ok = _check_order(gs.catalog.get_order(&"order_mia"), "Mia", &"strawberry", 20, 20, 150, 25, 5) and ok
	ok = _check_order(gs.catalog.get_order(&"order_jordan"), "Jordan", &"cupcake", 20, 22, 200, 35, 7) and ok
	ok = _check_order(gs.catalog.get_order(&"order_taylor"), "Taylor", &"strawberry", 25, 20, 275, 45, 10) and ok

	var level = gs.begin_order_level("order_mia")
	if level == null or level.move_limit != 20:
		push_error("mia level move_limit bad")
		ok = false
	elif level.get_primary_objective() == null or level.get_primary_objective().piece_id != &"strawberry" \
			or level.get_primary_objective().target_amount != 20:
		push_error("mia level objective bad")
		ok = false
	else:
		print("[OK] Mia order configures 20 moves / 20 strawberries")

	# Win → ready → complete once
	var coins_before: int = gs.data.coins
	var stars_before: int = gs.data.stars
	gs.on_level_won("order_mia", 900, 10, 20)
	if gs.get_order_status("order_mia") != SaveData.OrderStatus.READY_TO_COMPLETE:
		push_error("not ready to complete")
		ok = false
	var rewards: Dictionary = gs.complete_order("order_mia")
	if rewards.is_empty() or gs.data.coins <= coins_before or gs.data.stars <= stars_before:
		push_error("complete rewards failed")
		ok = false
	elif not gs.complete_order("order_mia").is_empty():
		push_error("duplicate complete granted rewards")
		ok = false
	else:
		print("[OK] win → complete once")

	# Loss grants nothing
	gs.begin_order_level("order_jordan")
	var c2: int = gs.data.coins
	gs.on_level_lost("order_jordan")
	if gs.get_order_status("order_jordan") != SaveData.OrderStatus.FAILED or gs.data.coins != c2:
		push_error("loss reward leak")
		ok = false
	else:
		print("[OK] loss grants no rewards")

	# Save persist
	gs.save_now()
	var loaded := SaveManager.load_game()
	if loaded.coins != gs.data.coins or loaded.stars != gs.data.stars:
		push_error("save persist mismatch")
		ok = false
	else:
		print("[OK] save persists")

	# Instantiate title + shop (catch missing unique nodes)
	for path in ["res://scenes/main/title_screen.tscn", "res://scenes/shop/shop_hub.tscn"]:
		var packed := load(path) as PackedScene
		var inst := packed.instantiate()
		root.add_child(inst)
		await process_frame
		await process_frame
		if not is_instance_valid(inst):
			push_error("scene freed unexpectedly: %s" % path)
			ok = false
		else:
			print("[OK] live instantiate %s" % path)
			inst.queue_free()
			await process_frame

	# Gameplay board still boots via main.tscn with injected Mia config
	router.pending_order_id = "order_mia"
	router.pending_level_config = level
	var gp: Node = (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	root.add_child(gp)
	var board: Node = null
	var controller: Node = null
	for _i in 120:
		await process_frame
		board = root.get_tree().get_first_node_in_group("match_board")
		controller = root.get_tree().get_first_node_in_group("game_controller")
		if board and controller:
			break
	if board == null or controller == null:
		push_error("gameplay board/controller missing via main.tscn")
		ok = false
	else:
		var cfg = controller.get("level_config")
		var sid = str(controller.get("session_order_id"))
		if cfg == null or int(cfg.move_limit) != 20:
			push_error("gameplay move limit not applied")
			ok = false
		elif sid != "order_mia":
			push_error("session order not applied")
			ok = false
		else:
			print("[OK] main.tscn loads puzzle with Mia order config")
		gp.queue_free()

	print("=== RESULT: %s ===" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)


func _check_order(order, customer: String, piece: StringName, amount: int, moves: int,
		coins: int, xp: int, rep: int) -> bool:
	if order == null:
		push_error("%s order missing" % customer)
		return false
	if order.customer_name != customer:
		push_error("%s name mismatch" % customer)
		return false
	if order.target_piece_id != piece or order.target_amount != amount or order.move_limit != moves:
		push_error("%s puzzle mismatch" % customer)
		return false
	if order.coin_reward != coins or order.experience_reward != xp or order.reputation_reward != rep:
		push_error("%s reward mismatch" % customer)
		return false
	print("[OK] %s order specs" % customer)
	return true
