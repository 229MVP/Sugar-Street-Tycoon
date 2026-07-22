extends SceneTree
## Verifies Orders and Recipe Book screens populate visible non-zero cards.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Orders / Recipe Book visibility test ===")
	await process_frame
	await process_frame

	var gs: Node = root.get_node_or_null("/root/GameState")
	if gs == null:
		push_error("GameState missing")
		quit(1)
		return

	SaveManager.delete_save()
	gs.new_game()
	await process_frame

	var ok := true
	ok = _check_catalog(gs) and ok
	ok = await _check_orders_screen(gs) and ok
	ok = await _check_recipe_book(gs) and ok

	print("=== RESULT: %s ===" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)


func _check_catalog(gs: Node) -> bool:
	var catalog = gs.catalog
	var order_ids := [
		&"order_mia_001", &"order_jordan_002", &"order_taylor_003",
		&"order_noah_004", &"order_morgan_005",
	]
	var recipe_ids := [
		&"chocolate_strawberries", &"classic_cupcakes", &"candied_grapes",
		&"cookies_cream_cupcakes", &"caramel_donuts",
	]
	for id in order_ids:
		if catalog.get_order(id) == null:
			push_error("missing order def %s" % str(id))
			return false
	for id in recipe_ids:
		if catalog.get_recipe(id) == null:
			push_error("missing recipe def %s" % str(id))
			return false
	var screen_orders: Array = gs.get_orders_for_screen()
	if screen_orders.size() < 5:
		push_error("get_orders_for_screen expected >=5 got %d" % screen_orders.size())
		return false
	if gs.get_order_status("order_morgan_005") != SaveData.OrderStatus.LOCKED:
		push_error("Morgan should be locked")
		return false
	if not gs.is_recipe_unlocked(&"chocolate_strawberries"):
		push_error("Chocolate Strawberries should be unlocked")
		return false
	print("[OK] catalog orders=%d recipes(target)=%d screen_orders=%d" % [
		catalog.order_sequence.size(), recipe_ids.size(), screen_orders.size()
	])
	return true


func _check_orders_screen(gs: Node) -> bool:
	var packed: PackedScene = load("res://scenes/orders/orders_screen.tscn")
	if packed == null:
		push_error("orders_screen.tscn missing")
		return false
	var screen: Control = packed.instantiate()
	root.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.size = Vector2(405, 720)
	await process_frame
	await process_frame
	await process_frame

	var list: Node = screen.find_child("OrderList", true, false)
	if list == null:
		push_error("OrderList parent missing")
		screen.queue_free()
		return false
	var cards: Array = list.get_children()
	if cards.size() < 5:
		push_error("Orders expected >=5 cards, got %d" % cards.size())
		screen.queue_free()
		return false

	var zero_size := 0
	var mia_ok := false
	var morgan_locked := false
	for card in cards:
		if not (card is Control):
			continue
		var c: Control = card
		if c.size.x <= 0.0 or c.size.y <= 0.0:
			# Force layout pass measurement via minimum size
			if c.get_combined_minimum_size().y < 150.0:
				zero_size += 1
		if "order_id" in c and str(c.order_id) == "order_mia_001":
			mia_ok = true
		if "order_id" in c and str(c.order_id) == "order_morgan_005":
			morgan_locked = true
			# Look for Locked button text
			var locked_btn := _find_button_text(c, "Locked")
			if locked_btn == null:
				push_error("Morgan card missing Locked button")
				screen.queue_free()
				return false
		var start_btn := _find_button_text(c, "Start Order")
		if "order_id" in c and str(c.order_id) == "order_mia_001" and start_btn == null:
			push_error("Mia missing Start Order")
			screen.queue_free()
			return false

	if zero_size > 0:
		push_error("%d order cards have near-zero size" % zero_size)
		screen.queue_free()
		return false
	if not mia_ok or not morgan_locked:
		push_error("Mia/Morgan cards missing among created cards")
		screen.queue_free()
		return false

	var scroll: ScrollContainer = screen.find_child("OrderScroll", true, false) as ScrollContainer
	if scroll == null or scroll.custom_minimum_size.y < 100.0:
		push_error("OrderScroll missing or too short")
		screen.queue_free()
		return false

	print("[OK] Orders screen cards=%d parent=%s scroll_min_y=%.0f" % [
		cards.size(), str(list.get_path()), scroll.custom_minimum_size.y
	])
	screen.queue_free()
	await process_frame
	return true


func _check_recipe_book(gs: Node) -> bool:
	var packed: PackedScene = load("res://scenes/recipes/recipe_book.tscn")
	if packed == null:
		push_error("recipe_book.tscn missing")
		return false
	var screen: Control = packed.instantiate()
	root.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.size = Vector2(405, 720)
	await process_frame
	await process_frame
	await process_frame

	var list: Node = screen.find_child("RecipeList", true, false)
	if list == null:
		push_error("RecipeList parent missing")
		screen.queue_free()
		return false
	var cards: Array = list.get_children()
	if cards.size() < 5:
		push_error("Recipe Book expected >=5 cards, got %d" % cards.size())
		screen.queue_free()
		return false

	# Select candied grapes and verify details + disabled unlock
	var grapes_card: Node = null
	for card in cards:
		if "recipe_id" in card and str(card.recipe_id) == "candied_grapes":
			grapes_card = card
			break
	if grapes_card == null:
		push_error("candied_grapes card missing")
		screen.queue_free()
		return false
	if grapes_card.has_signal("selected"):
		grapes_card.emit_signal("selected", &"candied_grapes")
	await process_frame

	var details: Label = null
	for n in screen.find_children("*", "Label", true, false):
		if n is Label and "Candied Grapes" in (n as Label).text and "Requires" in (n as Label).text:
			details = n
			break
	if details == null:
		# Fallback: find DetailsPanel label
		var panel := screen.find_child("DetailsPanel", true, false)
		if panel:
			details = panel.find_child("*", true, false) as Label
	# Unlock button should be disabled at starter (level 1, 0 stars)
	var unlock: Button = null
	for n in screen.find_children("*", "Button", true, false):
		if n is Button and ("Unlock" in (n as Button).text):
			unlock = n
			break
	if unlock == null:
		push_error("Unlock button missing")
		screen.queue_free()
		return false
	if not unlock.disabled:
		push_error("Unlock should be disabled for Candied Grapes at start")
		screen.queue_free()
		return false

	# White-on-cream check: title should be dark brown
	var title_ok := false
	for n in screen.find_children("*", "Label", true, false):
		if n is Label and (n as Label).text == "Recipe Book":
			var col: Color = (n as Label).get_theme_color("font_color")
			if col.r < 0.5 and col.g < 0.35:
				title_ok = true
			else:
				push_error("Recipe Book title not dark brown: %s" % str(col))
				screen.queue_free()
				return false
			break
	if not title_ok:
		push_error("Recipe Book title label missing")
		screen.queue_free()
		return false

	print("[OK] Recipe Book cards=%d parent=%s unlock_disabled=%s" % [
		cards.size(), str(list.get_path()), str(unlock.disabled)
	])
	screen.queue_free()
	await process_frame
	return true


func _find_button_text(root_node: Node, text: String) -> Button:
	for n in root_node.find_children("*", "Button", true, false):
		if n is Button and (n as Button).text == text:
			return n
	return null
