extends SceneTree
func _init():
	call_deferred("_run")
func _run():
	print("=== Safe area smoke test ===")
	await process_frame
	await process_frame
	var gs: Node = root.get_node_or_null("/root/GameState")
	SaveManager.delete_save()
	gs.new_game()
	await process_frame
	var ok := true
	var scenes := [
		"res://scenes/workers/worker_roster.tscn",
		"res://scenes/shop/shop_hub.tscn",
		"res://scenes/inventory/inventory_screen.tscn",
		"res://scenes/recipes/recipe_book.tscn",
		"res://scenes/orders/orders_screen.tscn",
		"res://scenes/upgrades/upgrades_screen.tscn",
		"res://scenes/decor/decor_screen.tscn",
		"res://scenes/main/title_screen.tscn",
		"res://scenes/gameplay/gameplay.tscn",
	]
	for path in scenes:
		var packed: PackedScene = load(path)
		var inst := packed.instantiate()
		root.add_child(inst)
		await process_frame
		await process_frame
		if not is_instance_valid(inst):
			push_error("failed to instantiate %s" % path)
			ok = false
		else:
			print("[OK] instantiated ", path)
		inst.queue_free()
		await process_frame
	print("=== RESULT: %s ===" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
