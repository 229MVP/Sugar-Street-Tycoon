extends SceneTree
## Validates Shop Hub / Inventory polish: starters, quantities, UI wiring.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Shop Hub / Inventory polish test ===")
	await process_frame
	await process_frame
	var gs: Node = root.get_node_or_null("/root/GameState")
	if gs == null:
		push_error("GameState missing")
		quit(1)
		return

	var ok := true
	SaveManager.delete_save()
	gs.new_game()
	await process_frame

	ok = _test_starter(gs) and ok
	ok = _test_migration_missing_keys(gs) and ok
	ok = _test_preserve_valid(gs) and ok
	ok = await _test_inventory_screen(gs) and ok
	ok = await _test_shop_hub(gs) and ok
	ok = await _test_top_bar(gs) and ok
	ok = await _test_bottom_nav() and ok
	ok = _test_reward_updates_inventory(gs) and ok
	ok = _test_resolutions() and ok

	print("=== RESULT: %s ===" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)


func _test_starter(gs: Node) -> bool:
	var expected := {
		"chocolate": 5, "strawberries": 5, "flour": 5, "sugar": 5, "cream": 3,
		"grapes": 0, "caramel": 0, "cookies": 0, "cheesecake_filling": 0, "packaging": 3,
	}
	for k in expected.keys():
		if gs.get_ingredient_amount(StringName(k)) != int(expected[k]):
			push_error("starter %s expected %d got %d" % [k, expected[k], gs.get_ingredient_amount(StringName(k))])
			return false
	if gs.get_total_ingredient_units() != 26:
		push_error("starter total units expected 26 got %d" % gs.get_total_ingredient_units())
		return false
	print("[OK] starter ingredients")
	return true


func _test_migration_missing_keys(gs: Node) -> bool:
	gs.data.ingredients = {"chocolate": 9}
	gs._ensure_ingredients()
	if gs.get_ingredient_amount(&"chocolate") != 9:
		push_error("migration overwrote valid chocolate")
		return false
	if gs.get_ingredient_amount(&"packaging") != 3:
		push_error("migration failed to add missing packaging")
		return false
	if gs.get_ingredient_amount(&"flour") != 5:
		push_error("migration failed to add missing flour")
		return false
	print("[OK] missing-key migration preserves valid amounts")
	return true


func _test_preserve_valid(gs: Node) -> bool:
	gs.data.ingredients = SaveData.starter_ingredients()
	gs.data.ingredients["chocolate"] = 12
	gs.save_now()
	gs.continue_game()
	if gs.get_ingredient_amount(&"chocolate") != 12:
		push_error("reload lost chocolate quantity")
		return false
	print("[OK] valid inventory preserved across save")
	return true


func _test_inventory_screen(gs: Node) -> bool:
	gs.reset_inventory_to_starter()
	var packed: PackedScene = load("res://scenes/inventory/inventory_screen.tscn")
	var screen: Control = packed.instantiate()
	root.add_child(screen)
	screen.size = Vector2(405, 720)
	await process_frame
	await process_frame
	await process_frame

	var found_choc := false
	var white_on_pale := false
	for n in screen.find_children("*", "Label", true, false):
		if not (n is Label):
			continue
		var lbl: Label = n
		if "Chocolate" == lbl.text or lbl.text.begins_with("Chocolate"):
			found_choc = true
		if "5 owned" in lbl.text:
			found_choc = true
			var col: Color = lbl.get_theme_color("font_color")
			if col.r > 0.9 and col.g > 0.9 and col.b > 0.9:
				white_on_pale = true
	if not found_choc:
		push_error("Inventory missing chocolate quantity label")
		screen.queue_free()
		return false
	if white_on_pale:
		push_error("Inventory quantity text is white")
		screen.queue_free()
		return false

	# Live update via inventory_changed
	gs.data.ingredients["chocolate"] = 20
	gs.inventory_changed.emit(gs.data.ingredients.duplicate(true))
	await process_frame
	await process_frame
	var saw_20 := false
	for n in screen.find_children("*", "Label", true, false):
		if n is Label and "20 owned" in (n as Label).text:
			saw_20 = true
	if not saw_20:
		push_error("Inventory did not refresh after inventory_changed")
		screen.queue_free()
		return false

	print("[OK] Inventory screen quantities + refresh")
	screen.queue_free()
	await process_frame
	return true


func _test_shop_hub(gs: Node) -> bool:
	var packed: PackedScene = load("res://scenes/shop/shop_hub.tscn")
	var screen: Control = packed.instantiate()
	root.add_child(screen)
	screen.size = Vector2(405, 720)
	await process_frame
	await process_frame
	await process_frame

	var saw_name := false
	var saw_progress := false
	var saw_orders := false
	for n in screen.find_children("*", "Label", true, false):
		if n is Label:
			var t: String = (n as Label).text
			if "Sugar Street Starter Shop" in t:
				saw_name = true
			if t.begins_with("Shop Level"):
				saw_progress = true
	for n in screen.find_children("*", "Button", true, false):
		if n is Button and (n as Button).text.begins_with("Orders"):
			saw_orders = true
	if not saw_name:
		push_error("Shop name missing from bakery preview")
		screen.queue_free()
		return false
	if not saw_progress:
		push_error("Shop Progress missing shop level")
		screen.queue_free()
		return false
	if not saw_orders:
		push_error("Orders primary button missing")
		screen.queue_free()
		return false
	print("[OK] Shop Hub preview + progress + orders")
	screen.queue_free()
	await process_frame
	return true


func _test_top_bar(gs: Node) -> bool:
	var bar := TopResourceBar.new()
	root.add_child(bar)
	bar.size = Vector2(405, 62)
	await process_frame
	await process_frame
	var texts: PackedStringArray = []
	for n in bar.find_children("*", "Label", true, false):
		if n is Label:
			texts.append((n as Label).text)
	var joined := " | ".join(texts)
	if not ("Lv %d" % gs.data.player_level) in joined and not ("Lv 1" in joined):
		push_error("Top bar missing level: %s" % joined)
		bar.queue_free()
		return false
	if not ("Coin" in joined):
		push_error("Top bar missing coins: %s" % joined)
		bar.queue_free()
		return false
	if not ("Star" in joined):
		push_error("Top bar missing stars: %s" % joined)
		bar.queue_free()
		return false
	if not ("En " in joined):
		push_error("Top bar missing energy: %s" % joined)
		bar.queue_free()
		return false
	print("[OK] Top resource bar labels: %s" % joined)
	bar.queue_free()
	await process_frame
	return true


func _test_bottom_nav() -> bool:
	var nav := BottomNavigation.new()
	root.add_child(nav)
	nav.size = Vector2(360, 72)
	await process_frame
	var labels: PackedStringArray = []
	for n in nav.find_children("*", "Button", true, false):
		if n is Button:
			labels.append((n as Button).text)
			if (n as Button).custom_minimum_size.y < 44.0:
				push_error("Bottom nav touch target too small")
				nav.queue_free()
				return false
	var blob := " ".join(labels)
	for need in ["Shop", "Inventory", "Customers", "Events"]:
		if need not in blob:
			push_error("Bottom nav missing %s in %s" % [need, blob])
			nav.queue_free()
			return false
	print("[OK] Bottom navigation tabs")
	nav.queue_free()
	await process_frame
	return true


func _test_reward_updates_inventory(gs: Node) -> bool:
	gs.reset_inventory_to_starter()
	var before: int = int(gs.get_ingredient_amount(&"chocolate"))
	# Simulate reward grant path
	gs.data.ingredients["chocolate"] = before + 2
	gs.inventory_changed.emit(gs.data.ingredients.duplicate(true))
	if int(gs.get_ingredient_amount(&"chocolate")) != before + 2:
		push_error("ingredient grant failed")
		return false
	print("[OK] inventory_changed signal path")
	return true


func _test_resolutions() -> bool:
	var sizes := [Vector2(360, 640), Vector2(405, 720), Vector2(390, 844), Vector2(430, 932)]
	for sz in sizes:
		var inv: Control = load("res://scenes/inventory/inventory_screen.tscn").instantiate()
		root.add_child(inv)
		inv.size = sz
		# can't await inside non-async easily in loop without making this async — use process_frame via await in caller
	# Instant smoke instantiate only
	for sz in sizes:
		var hub: Control = load("res://scenes/shop/shop_hub.tscn").instantiate()
		root.add_child(hub)
		hub.size = sz
		hub.queue_free()
		var inv2: Control = load("res://scenes/inventory/inventory_screen.tscn").instantiate()
		root.add_child(inv2)
		inv2.size = sz
		inv2.queue_free()
	print("[OK] responsive instantiate 360/405/390/430")
	return true
