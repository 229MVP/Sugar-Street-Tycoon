extends SceneTree
## Physical Android UI remediation gate — modal theming, toggle/slider chrome,
## touch/mouse gesture dedup, decor responsive layout, badge placement, and
## the previously-unhosted popups (Shop Level Upgrade, Decor Details, Level Up).


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== PHYSICAL ANDROID UI REMEDIATION TEST ===")
	var ok := true
	ok = await _test_modal_layer_theme_inheritance() and ok
	ok = _test_check_button_icons_not_default() and ok
	ok = _test_slider_grabber_icons_not_default() and ok
	ok = await _test_recipe_card_touch_mouse_dedupe() and ok
	ok = await _test_dessert_piece_touch_mouse_dedupe() and ok
	ok = await _test_decor_filter_scroll_and_columns() and ok
	ok = await _test_shop_edit_mode_bottom_sheet() and ok
	ok = await _test_badge_corner_anchor_and_caps() and ok
	ok = await _test_previously_unhosted_popups_on_modal_layer() and ok
	print("=== PHYSICAL ANDROID UI REMEDIATION: %s ===" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)


func _test_modal_layer_theme_inheritance() -> bool:
	# CanvasLayer is not a Control, so anything reparented under ModalLayer
	# previously fell back to Godot's bare default theme once detached from
	# the screen that built ThemeFactory's theme — this is the root cause of
	# "white/washed out" modal chrome and reappearing scrollbar chrome.
	var confirm := ConfirmPopup.new()
	root.add_child(confirm)
	await process_frame
	confirm.show_confirm("Theme Test", "Body", "OK", "Close")
	await process_frame
	if confirm.theme == null:
		push_error("Presented modal has no theme — will fall back to engine defaults")
		return false
	var empty_sb: StyleBox = confirm.theme.get_stylebox("scroll", "VScrollBar")
	if empty_sb == null or not (empty_sb is StyleBoxEmpty):
		push_error("Modal theme missing hidden-scrollbar chrome override")
		return false
	confirm.hide_popup()
	confirm.queue_free()
	print("[OK] ModalLayer assigns the app theme to presented modals")
	return true


func _test_check_button_icons_not_default() -> bool:
	var check := CheckButton.new()
	ThemeFactory.apply_check_button_styles(check)
	for icon_name in ["checked", "unchecked", "checked_disabled", "unchecked_disabled"]:
		if not check.has_theme_icon_override(icon_name):
			push_error("CheckButton missing icon override: %s" % icon_name)
			return false
	print("[OK] CheckButton switch glyph icons overridden (no default pale icon)")
	return true


func _test_slider_grabber_icons_not_default() -> bool:
	var theme := ThemeFactory.build()
	for icon_name in ["grabber", "grabber_highlight", "grabber_disabled"]:
		if not theme.has_icon(icon_name, "HSlider"):
			push_error("HSlider missing icon override: %s" % icon_name)
			return false
	print("[OK] HSlider grabber icons overridden (no default pale knob)")
	return true


func _test_recipe_card_touch_mouse_dedupe() -> bool:
	var card := RecipeCard.new()
	card.recipe_id = &"test_recipe"
	root.add_child(card)
	await process_frame
	var fire_count := {"value": 0}
	card.selected.connect(func(_id): fire_count["value"] += 1)
	# Simulate a real Android tap: a touch press followed by the emulated
	# mouse-button press Godot synthesizes for it.
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	card._on_gui_input(touch)
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	card._on_gui_input(mouse)
	if fire_count["value"] != 1:
		push_error("RecipeCard fired 'selected' %d times for one tap (expected 1)" % fire_count["value"])
		return false
	var touch_up := InputEventScreenTouch.new()
	touch_up.pressed = false
	card._on_gui_input(touch_up)
	# A later, unrelated desktop mouse click (no touch involved) must still work.
	var mouse2 := InputEventMouseButton.new()
	mouse2.button_index = MOUSE_BUTTON_LEFT
	mouse2.pressed = true
	card._on_gui_input(mouse2)
	if fire_count["value"] != 2:
		push_error("RecipeCard mouse-only click stopped working after touch dedupe guard")
		return false
	card.queue_free()
	print("[OK] RecipeCard ignores emulated mouse duplicate of a touch tap")
	return true


func _test_dessert_piece_touch_mouse_dedupe() -> bool:
	var scene: PackedScene = load("res://scenes/pieces/dessert_piece.tscn")
	if scene == null:
		push_error("dessert_piece.tscn failed to load")
		return false
	var piece: DessertPiece = scene.instantiate()
	root.add_child(piece)
	await process_frame
	var fire_count := {"value": 0}
	piece.selected.connect(func(_p): fire_count["value"] += 1)
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = Vector2(10, 10)
	piece._on_gui_input(touch)
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	mouse.position = Vector2(10, 10)
	piece._on_gui_input(mouse)
	if fire_count["value"] != 1:
		push_error("DessertPiece fired 'selected' %d times for one tap (expected 1)" % fire_count["value"])
		return false
	# Release should also only be processed once (touch release wins; the
	# synthesized mouse release that follows must be a no-op).
	var touch_up := InputEventScreenTouch.new()
	touch_up.pressed = false
	touch_up.position = Vector2(10, 10)
	piece._on_gui_input(touch_up)
	var mouse_up := InputEventMouseButton.new()
	mouse_up.button_index = MOUSE_BUTTON_LEFT
	mouse_up.pressed = false
	mouse_up.position = Vector2(10, 10)
	piece._on_gui_input(mouse_up) # must not error or re-trigger drag logic
	piece.queue_free()
	print("[OK] DessertPiece ignores emulated mouse duplicate of a touch tap")
	return true


func _test_decor_filter_scroll_and_columns() -> bool:
	var screen: Control = (load("res://scripts/decor/decor_screen.gd") as GDScript).new()
	root.add_child(screen)
	await process_frame
	await process_frame
	var filters: HBoxContainer = screen.get("_filters")
	if filters == null:
		push_error("Decor filters not found")
		return false
	if not (filters.get_parent() is ScrollContainer):
		push_error("Decor category filter row is not inside a ScrollContainer (will clip/overflow)")
		return false
	var filter_scroll: ScrollContainer = filters.get_parent()
	if filter_scroll.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_SHOW_NEVER:
		push_error("Decor filter scroll chrome not hidden")
		return false
	var ownership: HBoxContainer = screen.get("_ownership")
	if not (ownership.get_parent() is ScrollContainer):
		push_error("Decor ownership filter row is not inside a ScrollContainer")
		return false
	var grid: GridContainer = screen.get("_grid")
	if grid == null or grid.columns < 1:
		push_error("Decor grid columns not computed")
		return false
	screen.queue_free()
	print("[OK] Decor filter chips scroll horizontally; grid columns computed")
	return true


func _test_shop_edit_mode_bottom_sheet() -> bool:
	var overlay := ShopEditOverlay.new()
	root.add_child(overlay)
	var visual := ShopDecorVisual.new()
	root.add_child(visual)
	await process_frame
	overlay.open_edit(visual)
	await process_frame
	if not overlay.visible:
		push_error("ShopEditOverlay did not open")
		return false
	# Must be anchored as a bottom sheet (not a full-screen scrim) so the
	# shop visual above stays visible and tappable for slot selection.
	var safe := overlay.get_child(0)
	if not (safe is SafeAreaContainer):
		push_error("ShopEditOverlay root child is not a SafeAreaContainer")
		return false
	if safe.anchor_top != 1.0 or safe.anchor_bottom != 1.0:
		push_error("ShopEditOverlay is not anchored to the bottom of the viewport")
		return false
	for c in overlay.get_children():
		if c is ColorRect and (c as ColorRect).mouse_filter == Control.MOUSE_FILTER_STOP:
			push_error("ShopEditOverlay has a full-screen input-blocking scrim; would break slot taps")
			return false
	overlay.queue_free()
	visual.queue_free()
	print("[OK] Shop Edit Mode uses a non-blocking bottom-sheet card")
	return true


func _test_badge_corner_anchor_and_caps() -> bool:
	var badge := NotificationBadgeView.new()
	root.add_child(badge)
	await process_frame
	badge.place_top_right(4.0)
	if badge.anchor_left != 1.0 or badge.anchor_top != 0.0:
		push_error("Badge not anchored to top-right corner")
		return false
	var cases := {1: "1", 9: "9", 10: "10", 150: "99+"}
	for count in cases.keys():
		badge.set_count(count)
		var label: Label = badge.get_child(1)
		if label.text != cases[count]:
			push_error("Badge text for count %d expected '%s' got '%s'" % [count, cases[count], label.text])
			return false
		if label.horizontal_alignment != HORIZONTAL_ALIGNMENT_CENTER:
			push_error("Badge label not centered for count %d" % count)
			return false
	badge.queue_free()
	print("[OK] Badge corner anchoring + 1/9/10/99+ centered text")
	return true


func _test_previously_unhosted_popups_on_modal_layer() -> bool:
	var host := ModalLayer.ensure(self)

	var level_up := LevelUpPopup.new()
	root.add_child(level_up)
	await process_frame
	level_up.show_level_up(2, 100, "Test feature unlocked.")
	await process_frame
	if level_up.get_parent() != host:
		push_error("LevelUpPopup not presented via ModalLayer")
		return false
	if level_up.get_global_rect().size.x <= 0.0:
		push_error("LevelUpPopup has zero-size rect (missing FULL_RECT self-anchor)")
		return false
	level_up.hide_popup()
	level_up.queue_free()

	var shop_upgrade := ShopLevelUpgradePopup.new()
	root.add_child(shop_upgrade)
	await process_frame
	shop_upgrade.show_upgrade()
	await process_frame
	if shop_upgrade.get_parent() != host:
		push_error("ShopLevelUpgradePopup not presented via ModalLayer")
		return false
	shop_upgrade.hide_popup()
	shop_upgrade.queue_free()

	var decor_details := DecorDetailsPopup.new()
	root.add_child(decor_details)
	await process_frame
	var gs := root.get_node_or_null("/root/GameState")
	if gs == null:
		push_error("GameState missing for decor details test")
		return false
	var any_id := ""
	for decor in gs.decor_catalog.all_decorations():
		any_id = str(decor.decoration_id)
		break
	if any_id == "":
		push_error("No decorations available to test DecorDetailsPopup")
		return false
	decor_details.show_decoration(any_id)
	await process_frame
	if decor_details.get_parent() != host:
		push_error("DecorDetailsPopup not presented via ModalLayer")
		return false
	decor_details.hide_popup()
	decor_details.queue_free()

	print("[OK] LevelUpPopup / ShopLevelUpgradePopup / DecorDetailsPopup now hosted on ModalLayer")
	return true
