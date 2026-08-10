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
	ok = await _test_shop_hub_edit_input_lock() and ok
	ok = await _test_worker_roster_scroll_configuration() and ok
	ok = await _test_badge_corner_anchor_and_caps() and ok
	ok = await _test_badges_do_not_intersect_copy() and ok
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
	var scroll := ScrollContainer.new()
	scroll.size = Vector2(120, 110)
	ScrollHelper.configure_horizontal(scroll)
	root.add_child(scroll)
	var strip := HBoxContainer.new()
	scroll.add_child(strip)
	var card := RecipeCard.new()
	card.recipe_id = &"test_recipe"
	strip.add_child(card)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(320, 100)
	strip.add_child(spacer)
	await process_frame
	await process_frame
	if card.mouse_filter != Control.MOUSE_FILTER_PASS:
		push_error("RecipeCard still blocks its parent horizontal scroll")
		return false
	var fire_count := {"value": 0}
	card.selected.connect(func(_id): fire_count["value"] += 1)
	# Simulate a real Android tap: a touch press followed by the emulated
	# mouse-button press Godot synthesizes for it.
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = Vector2(10, 10)
	card._on_gui_input(touch)
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	mouse.position = Vector2(10, 10)
	card._on_gui_input(mouse)
	if fire_count["value"] != 0:
		push_error("RecipeCard selected on press before the gesture could become a swipe")
		return false
	var touch_up := InputEventScreenTouch.new()
	touch_up.pressed = false
	touch_up.position = Vector2(10, 10)
	card._on_gui_input(touch_up)
	var mouse_up := InputEventMouseButton.new()
	mouse_up.button_index = MOUSE_BUTTON_LEFT
	mouse_up.pressed = false
	mouse_up.position = Vector2(10, 10)
	card._on_gui_input(mouse_up)
	if fire_count["value"] != 1:
		push_error("RecipeCard did not commit exactly one selection on tap release")
		return false
	await process_frame

	# A horizontal swipe must scroll the recipe strip without selecting the
	# card that was under the initial touch.
	var swipe_down := InputEventScreenTouch.new()
	swipe_down.pressed = true
	swipe_down.position = Vector2(100, 10)
	card._on_gui_input(swipe_down)
	var swipe_drag := InputEventScreenDrag.new()
	swipe_drag.position = Vector2(30, 10)
	card._on_gui_input(swipe_drag)
	var swipe_up := InputEventScreenTouch.new()
	swipe_up.pressed = false
	swipe_up.position = Vector2(30, 10)
	card._on_gui_input(swipe_up)
	if fire_count["value"] != 1:
		push_error("RecipeCard selected while the player swiped the recipe strip")
		return false
	if scroll.scroll_horizontal <= 0:
		push_error("RecipeCard swallowed the swipe instead of moving the recipe strip")
		return false
	await process_frame
	# A later, unrelated desktop mouse click (no touch involved) must still work.
	var mouse2 := InputEventMouseButton.new()
	mouse2.button_index = MOUSE_BUTTON_LEFT
	mouse2.pressed = true
	mouse2.position = Vector2(10, 10)
	card._on_gui_input(mouse2)
	var mouse2_up := InputEventMouseButton.new()
	mouse2_up.button_index = MOUSE_BUTTON_LEFT
	mouse2_up.pressed = false
	mouse2_up.position = Vector2(10, 10)
	card._on_gui_input(mouse2_up)
	if fire_count["value"] != 2:
		push_error("RecipeCard mouse-only click stopped working after touch dedupe guard")
		return false
	scroll.queue_free()
	print("[OK] RecipeCard taps select; finger swipes move the recipe strip")
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
	screen.size = Vector2(360, 640)
	root.add_child(screen)
	await process_frame
	await process_frame
	await process_frame
	var body_scroll: ScrollContainer = screen.get("_grid_scroll")
	if body_scroll == null or body_scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_SHOW_NEVER:
		push_error("Decor bounded vertical body is missing or misconfigured")
		return false
	if body_scroll.scroll_deadzone < 8 or body_scroll.scroll_deadzone > 10:
		push_error("Decor touch deadzone should be responsive (8-10 px), got %d" % body_scroll.scroll_deadzone)
		return false
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
	if not body_scroll.is_ancestor_of(filter_scroll):
		push_error("Decor filters sit outside the vertical body; vertical swipes on chips cannot move the page")
		return false
	var filter_bar := filter_scroll.get_h_scroll_bar()
	if filter_bar.max_value - filter_bar.page <= 0.0:
		push_error("Decor category chip row has no reachable horizontal scroll range at 360 px")
		return false
	var first_chip := filters.get_child(0) as Button
	if first_chip == null or first_chip.mouse_filter != Control.MOUSE_FILTER_PASS:
		push_error("Decor chips still block touch gestures from their scroll containers")
		return false
	# Exercise the same gui_input connection used on-device. A left drag moves
	# the chip strip; an upward drag beginning on a chip moves the outer page.
	var press := InputEventScreenTouch.new()
	press.pressed = true
	press.position = Vector2(100, 20)
	first_chip.emit_signal("gui_input", press)
	var horizontal_drag := InputEventScreenDrag.new()
	horizontal_drag.position = Vector2(40, 22)
	first_chip.emit_signal("gui_input", horizontal_drag)
	if filter_scroll.scroll_horizontal <= 0:
		push_error("Decor chip left-drag did not move its horizontal strip")
		return false
	var release := InputEventScreenTouch.new()
	release.pressed = false
	release.position = horizontal_drag.position
	first_chip.emit_signal("gui_input", release)
	await process_frame
	body_scroll.scroll_vertical = 0
	var vertical_press := InputEventScreenTouch.new()
	vertical_press.pressed = true
	vertical_press.position = Vector2(40, 80)
	first_chip.emit_signal("gui_input", vertical_press)
	var vertical_drag := InputEventScreenDrag.new()
	vertical_drag.position = Vector2(42, 20)
	first_chip.emit_signal("gui_input", vertical_drag)
	if body_scroll.scroll_vertical <= 0:
		push_error("Vertical drag beginning on a Decor chip did not move the page")
		return false
	var ownership: HBoxContainer = screen.get("_ownership")
	if not (ownership.get_parent() is ScrollContainer):
		push_error("Decor ownership filter row is not inside a ScrollContainer")
		return false
	var grid: GridContainer = screen.get("_grid")
	if grid == null or grid.columns != 1:
		push_error("Decor grid must reflow to one column at 360 px (got %d)" % (grid.columns if grid else 0))
		return false
	if grid.get_combined_minimum_size().x > body_scroll.size.x + 1.0:
		push_error("Decor card minimum widths overflow the 360 px viewport")
		return false
	var body_bar := body_scroll.get_v_scroll_bar()
	if body_bar.max_value - body_bar.page <= 0.0:
		push_error("Decor catalog does not expose a vertical scroll range")
		return false
	screen.queue_free()
	print("[OK] Decor nested chip scrolling + single-column narrow catalog fit")
	return true


func _test_shop_edit_mode_bottom_sheet() -> bool:
	var overlay := ShopEditOverlay.new()
	root.add_child(overlay)
	var visual := ShopDecorVisual.new()
	root.add_child(visual)
	await process_frame
	var original_parent := overlay.get_parent()
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
	if overlay.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		push_error("ShopEditOverlay transparent full-screen root blocks highlighted slot taps")
		return false
	var sheet := safe.get_child(0) as Control
	if sheet == null or sheet.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		push_error("ShopEditOverlay sheet controls are not interactive")
		return false
	if safe.size.y >= overlay.size.y:
		push_error("ShopEditOverlay sheet covers the full viewport instead of only the bottom region")
		return false
	for c in overlay.get_children():
		if c is ColorRect and (c as ColorRect).mouse_filter == Control.MOUSE_FILTER_STOP:
			push_error("ShopEditOverlay has a full-screen input-blocking scrim; would break slot taps")
			return false
	if not ModalLayer.handle_back_static():
		push_error("Android Back did not find Shop Edit Mode on the modal stack")
		return false
	await process_frame
	if overlay.visible or bool(visual.get("_edit_mode")):
		push_error("Android Back did not cancel Shop Edit Mode")
		return false
	if overlay.get_parent() != original_parent:
		push_error("Closed ShopEditOverlay was not returned to its screen for cleanup")
		return false
	overlay.queue_free()
	visual.queue_free()
	print("[OK] Shop Edit Mode sheet is click-through above + Android Back cancels")
	return true


func _test_shop_hub_edit_input_lock() -> bool:
	var gs := root.get_node_or_null("/root/GameState")
	var prior_completed: bool = bool(gs.data.tutorial_completed)
	var prior_step: int = int(gs.data.tutorial_step)
	var prior_pending: Array = gs.pending_level_ups.duplicate(true)
	gs.data.tutorial_completed = true
	gs.data.tutorial_step = -1
	gs.pending_level_ups.clear()
	var hub: Control = (load("res://scripts/shop/shop_hub.gd") as GDScript).new()
	hub.size = Vector2(405, 720)
	root.add_child(hub)
	await process_frame
	await process_frame
	var scroll := hub.get("_body_scroll") as ScrollContainer
	if scroll == null:
		push_error("Shop Hub body scroll was not retained for edit-mode control")
		return false
	var prior_mode := scroll.vertical_scroll_mode
	var available_range := maxi(0, int(scroll.get_v_scroll_bar().max_value - scroll.get_v_scroll_bar().page))
	var prior_position := mini(32, available_range)
	scroll.scroll_vertical = prior_position
	hub.call("_enter_edit_mode")
	if not bool(hub.call("is_edit_mode_active")) or scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		push_error("Shop Hub did not lock body scrolling during edit mode")
		return false
	if scroll.scroll_vertical != 0:
		push_error("Shop Hub did not reset to the tappable shop preview before editing")
		return false
	var locked: Dictionary = hub.get("_pre_edit_button_disabled")
	if locked.is_empty():
		push_error("Shop Hub did not retain/disable unrelated descendant buttons")
		return false
	for candidate in locked.keys():
		if is_instance_valid(candidate) and not (candidate as BaseButton).disabled:
			push_error("An unrelated Shop Hub button remains active during edit mode")
			return false
	var overlay := hub.get("_edit_overlay") as ShopEditOverlay
	overlay.cancel_edit()
	await process_frame
	if bool(hub.call("is_edit_mode_active")) or scroll.vertical_scroll_mode != prior_mode:
		push_error("Shop Hub did not restore controls/scroll mode after edit cancel")
		return false
	if scroll.scroll_vertical != prior_position:
		push_error("Shop Hub did not restore its pre-edit scroll position")
		return false
	hub.queue_free()
	gs.data.tutorial_completed = prior_completed
	gs.data.tutorial_step = prior_step
	gs.pending_level_ups = prior_pending
	print("[OK] Shop Hub edit mode locks unrelated actions and restores scroll")
	return true


func _test_worker_roster_scroll_configuration() -> bool:
	var gs := root.get_node_or_null("/root/GameState")
	var prior_flag := bool(gs.data.tutorial_flags.get("workers", false))
	gs.data.tutorial_flags["workers"] = true
	var roster: Control = (load("res://scenes/workers/worker_roster.tscn") as PackedScene).instantiate()
	root.add_child(roster)
	await process_frame
	var scroll := roster.get_node("Margin/VBox/Split/Scroll") as ScrollContainer
	if roster.theme == null:
		push_error("Worker Roster did not apply the app theme")
		return false
	if (
		scroll.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED
		or scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_SHOW_NEVER
		or scroll.scroll_deadzone < 8
		or scroll.scroll_deadzone > 10
	):
		push_error("Worker Roster scroll is not configured for responsive vertical touch")
		return false
	roster.queue_free()
	gs.data.tutorial_flags["workers"] = prior_flag
	print("[OK] Worker Roster uses the app theme + touch scroll defaults")
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


func _test_badges_do_not_intersect_copy() -> bool:
	var nav := BottomNavigation.new()
	nav.size = Vector2(336, 72)
	root.add_child(nav)
	await process_frame
	await process_frame
	var nav_badges: Dictionary = nav.get("_badges")
	var nav_buttons: Dictionary = nav.get("_buttons")
	var nav_badge := nav_badges[BottomNavigation.TAB_SHOP] as NotificationBadgeView
	nav_badge.set_count(150)
	await process_frame
	var nav_button := nav_buttons[BottomNavigation.TAB_SHOP] as Button
	var nav_icon := nav_button.get_node("Content/IconMargin/IconLabel") as Label
	var nav_copy := nav_button.get_node("Content/ContentLabel") as Label
	if nav_badge.get_global_rect().intersects(nav_icon.get_global_rect()) or nav_badge.get_global_rect().intersects(nav_copy.get_global_rect()):
		push_error("Bottom navigation 99+ badge intersects its icon or label")
		return false
	nav.queue_free()

	var grid := GridContainer.new()
	grid.columns = 3
	grid.size = Vector2(336, 64)
	grid.add_theme_constant_override("h_separation", 8)
	root.add_child(grid)
	var hub: Control = (load("res://scripts/shop/shop_hub.gd") as GDScript).new()
	var first_badge: NotificationBadgeView = hub.call(
		"_nav_card", grid, "Upgrades", "Improve gear", func(): pass, true, false, 56.0
	)
	hub.call("_nav_card", grid, "Recipes", "Unlock desserts", func(): pass, false, false, 56.0)
	hub.call("_nav_card", grid, "Decor", "Customize", func(): pass, false, true, 56.0)
	await process_frame
	await process_frame
	first_badge.set_count(150)
	await process_frame
	var card := first_badge.get_parent() as Button
	var title := card.get_node("Content/TitleMargin/TitleLabel") as Label
	var subtitle := card.get_node("Content/SubtitleLabel") as Label
	if first_badge.get_global_rect().intersects(title.get_global_rect()) or first_badge.get_global_rect().intersects(subtitle.get_global_rect()):
		push_error("Three-column Shop card 99+ badge intersects title/subtitle copy")
		return false
	grid.queue_free()
	hub.free()
	print("[OK] Shop and bottom-navigation badges reserve non-overlapping copy regions")
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
