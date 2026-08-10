extends Control
## Decorate Shop: browse, buy, and manage decorations.


const SettingsPopupScene := preload("res://scripts/ui/settings_popup.gd")

const MIN_CARD_WIDTH := 240.0

var _top_bar: TopResourceBar
var _grid: GridContainer
## The bounded vertical page body. It deliberately contains the filter rows
## as well as the catalog so a vertical swipe that begins on a chip can still
## move the Decor page.
var _grid_scroll: ScrollContainer
var _filters: HBoxContainer
var _ownership: HBoxContainer
var _info: Label
var _category: String = "All"
var _own_filter: String = "All" # All / Owned / Available / Locked
var _details: DecorDetailsPopup
var _confirm: ConfirmPopup
var _settings: Control
var _feedback: Label
var _filter_touch_start := Vector2.ZERO
var _filter_start_horizontal: int = 0
var _filter_start_vertical: int = 0
var _filter_drag_axis: int = 0 # 0 undecided, 1 horizontal, 2 vertical
var _filter_gesture_dragged: bool = false


func _ready() -> void:
	theme = ThemeFactory.build()
	_category = str(GameState.data.settings.get("last_decor_category", "All"))
	_build()
	GameState.mark_decoration_unlocks_seen()
	GameState.state_changed.connect(_rebuild)
	_rebuild()
	AudioManager.play(AudioManager.Sfx.DECOR_SCREEN_OPENED)
	resized.connect(_on_resized)
	_grid_scroll.resized.connect(_on_resized)
	call_deferred("_on_resized")


func _build() -> void:
	for c in get_children():
		c.queue_free()
	var bg := ColorRect.new()
	bg.color = SugarStreetColors.WARM_CREAM
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var safe := SafeAreaContainer.new()
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe.set_min_margins(12, 12, 12, 8)
	add_child(safe)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	safe.add_child(vbox)

	_top_bar = TopResourceBar.new()
	vbox.add_child(_top_bar)
	_top_bar.menu_pressed.connect(func(): _settings.call("show_settings"))

	# Everything between the fixed resource bar and fixed bottom navigation is
	# one vertical page. The two chip rows below are nested horizontal scrollers;
	# their touch router provides a dominant-axis handoff to this page body.
	_grid_scroll = ScrollContainer.new()
	_grid_scroll.name = "DecorBodyScroll"
	_grid_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ScrollHelper.configure_vertical(_grid_scroll)
	vbox.add_child(_grid_scroll)

	var body := VBoxContainer.new()
	body.name = "DecorBody"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	_grid_scroll.add_child(body)

	var title := Label.new()
	title.text = "Decorate Shop"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", SugarStreetColors.BAKERY_BROWN)
	body.add_child(title)

	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.add_theme_color_override("font_color", SugarStreetColors.WOOD_BROWN)
	body.add_child(_info)

	var appeal_bar := ProgressBar.new()
	appeal_bar.name = "AppealBar"
	appeal_bar.custom_minimum_size = Vector2(0, 14)
	appeal_bar.show_percentage = false
	body.add_child(appeal_bar)

	_feedback = Label.new()
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback.add_theme_color_override("font_color", SugarStreetColors.MINT_GREEN)
	body.add_child(_feedback)

	var filters_scroll := ScrollContainer.new()
	filters_scroll.name = "CategoryScroll"
	filters_scroll.custom_minimum_size = Vector2(0, 44)
	filters_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ScrollHelper.configure_horizontal(filters_scroll)
	filters_scroll.gui_input.connect(_on_filter_gesture_input.bind(filters_scroll, filters_scroll))
	body.add_child(filters_scroll)
	_filters = HBoxContainer.new()
	_filters.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_filters.add_theme_constant_override("separation", 4)
	filters_scroll.add_child(_filters)
	for cat in ["All", "Wall", "Counter", "Plants", "Floor", "Lighting", "Seating", "Signage", "Display", "Window"]:
		_filter_btn(_filters, cat, true)

	var ownership_scroll := ScrollContainer.new()
	ownership_scroll.name = "OwnershipScroll"
	ownership_scroll.custom_minimum_size = Vector2(0, 44)
	ownership_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ScrollHelper.configure_horizontal(ownership_scroll)
	ownership_scroll.gui_input.connect(_on_filter_gesture_input.bind(ownership_scroll, ownership_scroll))
	body.add_child(ownership_scroll)
	_ownership = HBoxContainer.new()
	_ownership.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_ownership.add_theme_constant_override("separation", 4)
	ownership_scroll.add_child(_ownership)
	for own in ["All", "Owned", "Available", "Locked"]:
		_filter_btn(_ownership, own, false)

	_grid = GridContainer.new()
	_grid.name = "DecorGrid"
	_grid.columns = 1
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	body.add_child(_grid)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	body.add_child(actions)
	var preview := Button.new()
	preview.text = "Shop Preview"
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.custom_minimum_size = Vector2(0, 44)
	ThemeFactory.apply_button_styles(preview, ThemeFactory.soft_button_styles(), SugarStreetColors.DARK_TEXT)
	preview.pressed.connect(func(): SceneRouter.go_shop())
	actions.add_child(preview)
	var edit := Button.new()
	edit.text = "Edit Shop"
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.custom_minimum_size = Vector2(0, 44)
	ThemeFactory.apply_button_styles(edit, ThemeFactory.primary_button_styles())
	edit.pressed.connect(func():
		SceneRouter.go_shop()
		# Shop hub enters edit when flagged.
		GameState.data.settings["open_shop_edit"] = true
		GameState.save_now()
	)
	actions.add_child(edit)

	var back := Button.new()
	back.text = "Back to Shop"
	back.custom_minimum_size = Vector2(0, 44)
	ThemeFactory.apply_button_styles(back, ThemeFactory.secondary_button_styles())
	back.pressed.connect(func(): SceneRouter.go_shop())
	body.add_child(back)

	var nav := BottomNavigation.new()
	nav.selected_tab = BottomNavigation.TAB_SHOP
	vbox.add_child(nav)

	_details = DecorDetailsPopup.new()
	add_child(_details)
	_details.purchased.connect(func(id):
		_feedback.text = "Purchased! You can place it now."
		_rebuild()
	)
	_details.place_requested.connect(_on_place_from_details)
	_details.remove_requested.connect(_on_remove_from_details)
	_confirm = ConfirmPopup.new()
	add_child(_confirm)
	_settings = SettingsPopupScene.new()
	add_child(_settings)


func _filter_btn(parent: HBoxContainer, label: String, is_category: bool) -> void:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(44, 44)
	# PASS lets the surrounding strip observe finger gestures. The explicit
	# router below hands dominant vertical drags to the outer page body.
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.add_theme_font_size_override("font_size", 11)
	ThemeFactory.apply_button_styles(b, ThemeFactory.soft_button_styles(), SugarStreetColors.DARK_TEXT)
	b.pressed.connect(func():
		if _filter_gesture_dragged:
			return
		if is_category:
			_category = label
			GameState.data.settings["last_decor_category"] = label
			GameState.save_now()
		else:
			_own_filter = label
		_rebuild()
	)
	parent.add_child(b)
	var strip := parent.get_parent() as ScrollContainer
	if strip:
		b.gui_input.connect(_on_filter_gesture_input.bind(strip, b))


## Route Android touch drags that begin on a filter chip by their dominant
## axis. mouse_force_pass_scroll_events covers wheel events, not screen drags.
func _on_filter_gesture_input(event: InputEvent, strip: ScrollContainer, source: Control) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_filter_touch_start = touch.position
			_filter_start_horizontal = strip.scroll_horizontal
			_filter_start_vertical = _grid_scroll.scroll_vertical if _grid_scroll else 0
			_filter_drag_axis = 0
			_filter_gesture_dragged = false
			# The manual router owns the complete sequence so no ancestor receives
			# a touch-down without the matching drag/release.
			source.accept_event()
		else:
			source.accept_event()
			call_deferred("_clear_filter_gesture")
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		var displacement := drag.position - _filter_touch_start
		if _filter_drag_axis == 0 and displacement.length() >= ScrollHelper.TOUCH_SCROLL_DEADZONE:
			_filter_drag_axis = 1 if absf(displacement.x) >= absf(displacement.y) else 2
			_filter_gesture_dragged = true
		if _filter_drag_axis == 1:
			strip.scroll_horizontal = _filter_start_horizontal - int(round(displacement.x))
		elif _filter_drag_axis == 2 and _grid_scroll:
			_grid_scroll.scroll_vertical = _filter_start_vertical - int(round(displacement.y))
		source.accept_event()


func _clear_filter_gesture() -> void:
	_filter_drag_axis = 0
	_filter_gesture_dragged = false


func _rebuild() -> void:
	if _grid == null:
		return
	for c in _grid.get_children():
		c.queue_free()
	var summary := GameState.get_appeal_summary()
	var next_info: Dictionary = summary.get("next_tier", {})
	_info.text = "Shop Lv%d · Appeal %d (%s) · Next tier in %d · Coins %s" % [
		GameState.data.shop_level,
		int(summary.get("appeal", 0)),
		str(summary.get("tier", "Plain")),
		int(next_info.get("needed", 0)),
		RewardCalculator.format_coins(GameState.data.coins),
	]
	var bar := find_child("AppealBar", true, false) as ProgressBar
	if bar:
		bar.max_value = 100
		bar.value = float(next_info.get("progress", 0.0)) * 100.0

	var shown := 0
	for decor in GameState.decor_catalog.all_decorations():
		if not _passes_filters(decor):
			continue
		shown += 1
		_grid.add_child(_make_card(decor))
	if shown == 0:
		var empty := Label.new()
		empty.text = "No decorations found"
		empty.add_theme_color_override("font_color", SugarStreetColors.WOOD_BROWN)
		_grid.add_child(empty)
		if OS.is_debug_build():
			push_warning("DecorScreen: no decorations matched filters")


func _passes_filters(decor: DecorationData) -> bool:
	if _category != "All" and decor.category_label() != _category:
		return false
	var owned := GameState.is_decoration_owned(decor.decoration_id)
	var unlocked := DecorationManager.is_decoration_unlocked(decor, GameState.data)
	match _own_filter:
		"Owned":
			return owned
		"Available":
			return unlocked and not owned
		"Locked":
			return not unlocked and not owned
	return true


func _make_card(decor: DecorationData) -> PanelContainer:
	var owned := GameState.is_decoration_owned(decor.decoration_id)
	var unlocked := DecorationManager.is_decoration_unlocked(decor, GameState.data)
	var placed := DecorationManager.find_slot_of_decoration(GameState.data, str(decor.decoration_id))
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 170)
	var style := ThemeFactory._card(SugarStreetColors.SOFT_IVORY if unlocked or owned else Color(0.92, 0.9, 0.88, 1), 14)
	card.add_theme_stylebox_override("panel", style)
	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 4)
	card.add_child(root)

	var icon := PanelContainer.new()
	icon.custom_minimum_size = Vector2(0, 44)
	var istyle := StyleBoxFlat.new()
	istyle.bg_color = decor.placeholder_color
	istyle.set_corner_radius_all(10)
	icon.add_theme_stylebox_override("panel", istyle)
	root.add_child(icon)
	var il := Label.new()
	il.text = "%s  %s" % [decor.placeholder_symbol, decor.display_name]
	il.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	il.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	il.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	il.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	il.add_theme_font_size_override("font_size", 13)
	il.add_theme_color_override("font_color", SugarStreetColors.BAKERY_BROWN)
	icon.add_child(il)

	var meta := Label.new()
	meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	meta.add_theme_font_size_override("font_size", 11)
	meta.add_theme_color_override("font_color", SugarStreetColors.WOOD_BROWN)
	meta.text = "%s · +%d Appeal · %s" % [decor.rarity_label(), decor.appeal_value, RewardCalculator.format_coins(decor.purchase_cost)]
	root.add_child(meta)

	var status := Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	status.add_theme_font_size_override("font_size", 11)
	status.add_theme_color_override("font_color", SugarStreetColors.DARK_TEXT)
	if placed != "":
		status.text = "Equipped · %s" % placed
	elif owned:
		status.text = "Owned"
	elif unlocked:
		status.text = "Available"
	else:
		status.text = DecorationManager.unlock_reason(decor, GameState.data)
	root.add_child(status)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 44)
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if owned:
		btn.text = "Details"
		ThemeFactory.apply_button_styles(btn, ThemeFactory.soft_button_styles(), SugarStreetColors.DARK_TEXT)
	elif unlocked:
		btn.text = "Buy"
		ThemeFactory.apply_button_styles(btn, ThemeFactory.primary_button_styles())
		btn.disabled = not GameState.can_purchase_decoration(decor.decoration_id).get("ok", false)
	else:
		btn.text = "Locked"
		ThemeFactory.apply_button_styles(btn, ThemeFactory.primary_button_styles())
		btn.disabled = true
	btn.pressed.connect(func(): _details.show_decoration(str(decor.decoration_id)))
	root.add_child(btn)

	if not bool(GameState.data.settings.get("reduce_motion", false)):
		card.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(card, "modulate:a", 1.0, 0.2)
	return card


func _on_place_from_details(decoration_id: String) -> void:
	GameState.data.settings["open_shop_edit"] = true
	GameState.data.settings["edit_focus_decoration"] = decoration_id
	GameState.save_now()
	SceneRouter.go_shop()


func _on_remove_from_details(decoration_id: String) -> void:
	var slot := DecorationManager.find_slot_of_decoration(GameState.data, decoration_id)
	if slot == "":
		return
	var result := GameState.remove_decoration_from_slot(StringName(slot))
	if result.get("ok", false):
		AudioManager.play(AudioManager.Sfx.DECOR_REMOVED)
		_feedback.text = "Removed from shop (still owned)."
		_rebuild()


func _on_resized() -> void:
	if _grid == null or _grid_scroll == null:
		return
	# Compute columns from the bounded page body's actual available width. A
	# 240 px floor intentionally makes phone portrait a single-column list;
	# two narrow cards were wider than the viewport once real decoration names
	# and requirements contributed their minimum widths.
	var available := _grid_scroll.size.x
	if available <= 0.0:
		available = maxf(0.0, size.x - 24.0)
	var separation := float(_grid.get_theme_constant("h_separation"))
	var columns := int(floor((available + separation) / (MIN_CARD_WIDTH + separation)))
	_grid.columns = maxi(1, columns)
