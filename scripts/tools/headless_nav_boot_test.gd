extends SceneTree
## Validates title main scene, shop/orders loop, and Lily order level config.


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
		"res://scenes/orders/orders_screen.tscn",
		"res://scenes/main/main.tscn",
		"res://scenes/popups/level_complete_popup.tscn",
		"res://scenes/ui/top_resource_bar.tscn",
		"res://scenes/ui/bottom_navigation.tscn",
	]:
		if not ResourceLoader.exists(path):
			push_error("missing %s" % path)
			ok = false
		else:
			print("[OK] exists %s" % path)

	await process_frame
	await process_frame

	var gs := root.get_node_or_null("/root/GameState")
	var router := root.get_node_or_null("/root/SceneRouter")
	if gs == null or router == null:
		push_error("Autoloads missing")
		quit(1)
		return

	if str(router.GAMEPLAY_SCENE) != "res://scenes/main/main.tscn":
		push_error("GAMEPLAY_SCENE wrong")
		ok = false
	else:
		print("[OK] GAMEPLAY_SCENE = main.tscn")
	if str(router.ORDERS_SCENE) != "res://scenes/orders/orders_screen.tscn":
		push_error("ORDERS_SCENE wrong")
		ok = false
	else:
		print("[OK] ORDERS_SCENE")

	SaveManager.delete_save()
	gs.new_game()
	var visible: Array = gs.get_visible_orders()
	if visible.size() != 3:
		push_error("expected 3 starter orders")
		ok = false
	else:
		var names: PackedStringArray = []
		for o in visible:
			names.append(o.customer_name)
		if not ("Lily" in names and "Noah" in names and "Mrs. Maple" in names):
			push_error("starter customers mismatch: %s" % ", ".join(names))
			ok = false
		else:
			print("[OK] starter orders Lily/Noah/Mrs. Maple")

	ok = _check_order(gs.catalog.get_order(&"order_lily"), "Lily", &"strawberry", 20, 20, 320, 25, 5) and ok
	ok = _check_order(gs.catalog.get_order(&"order_noah"), "Noah", &"chocolate", 25, 22, 380, 35, 8) and ok
	ok = _check_order(gs.catalog.get_order(&"order_maple"), "Mrs. Maple", &"cookie", 30, 20, 350, 45, 10) and ok

	var level = gs.begin_order_level("order_lily")
	if level == null or level.move_limit != 20:
		push_error("lily level move_limit bad")
		ok = false
	elif level.get_primary_objective() == null or level.get_primary_objective().piece_id != &"strawberry" \
			or level.get_primary_objective().target_amount != 20:
		push_error("lily level objective bad")
		ok = false
	else:
		print("[OK] Lily configures 20 moves / 20 strawberries")

	var coins_before: int = gs.data.coins
	var stars_before: int = gs.data.stars
	gs.on_level_won("order_lily", 900, 10, 20)
	if gs.get_order_status("order_lily") != SaveData.OrderStatus.READY_TO_COMPLETE:
		push_error("not ready to complete")
		ok = false
	var rewards: Dictionary = gs.complete_order("order_lily")
	if rewards.is_empty() or gs.data.coins <= coins_before or gs.data.stars <= stars_before:
		push_error("complete rewards failed")
		ok = false
	elif not gs.complete_order("order_lily").is_empty():
		push_error("duplicate complete granted rewards")
		ok = false
	else:
		print("[OK] win → complete once")

	gs.begin_order_level("order_noah")
	var c2: int = gs.data.coins
	gs.on_level_lost("order_noah")
	if gs.get_order_status("order_noah") != SaveData.OrderStatus.FAILED or gs.data.coins != c2:
		push_error("loss reward leak")
		ok = false
	else:
		print("[OK] loss grants no rewards")

	for path in ["res://scenes/main/title_screen.tscn", "res://scenes/shop/shop_hub.tscn", "res://scenes/orders/orders_screen.tscn"]:
		var packed := load(path) as PackedScene
		var inst := packed.instantiate()
		root.add_child(inst)
		await process_frame
		await process_frame
		print("[OK] live instantiate %s" % path)
		inst.queue_free()
		await process_frame

	router.pending_order_id = "order_lily"
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
		push_error("main.tscn board/controller missing")
		ok = false
	else:
		var cfg = controller.get("level_config")
		if cfg == null or int(cfg.move_limit) != 20:
			push_error("move limit not applied")
			ok = false
		else:
			print("[OK] main.tscn loads Lily puzzle config")
		gp.queue_free()

	print("=== RESULT: %s ===" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)


func _check_order(order, customer: String, piece: StringName, amount: int, moves: int,
		coins: int, xp: int, rep: int) -> bool:
	if order == null:
		push_error("%s order missing" % customer)
		return false
	if order.customer_name != customer or order.target_piece_id != piece \
			or order.target_amount != amount or order.move_limit != moves:
		push_error("%s puzzle mismatch" % customer)
		return false
	if order.coin_reward != coins or order.experience_reward != xp or order.reputation_reward != rep:
		push_error("%s reward mismatch" % customer)
		return false
	print("[OK] %s order specs" % customer)
	return true
