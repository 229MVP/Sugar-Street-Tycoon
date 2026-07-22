class_name ShopDecorVisual
extends Control
## Centralized placeholder rendering for shop stage + placed decorations.


var _bg: ColorRect
var _trim: ColorRect
var _stage_label: Label
var _slot_nodes: Dictionary = {} ## slot_id -> PanelContainer
var _edit_mode: bool = false
var _selected_slot: String = ""

signal slot_pressed(slot_id: String)


func _ready() -> void:
	custom_minimum_size = Vector2(0, 220)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clip_contents = true
	_build()
	refresh()
	if not GameState.state_changed.is_connected(refresh):
		GameState.state_changed.connect(refresh)
	if not GameState.appeal_changed.is_connected(_on_appeal):
		GameState.appeal_changed.connect(_on_appeal)
	resized.connect(_layout)


func _build() -> void:
	for c in get_children():
		c.queue_free()
	_bg = ColorRect.new()
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	_trim = ColorRect.new()
	_trim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_trim)

	_stage_label = Label.new()
	_stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stage_label.add_theme_font_size_override("font_size", 12)
	_stage_label.add_theme_color_override("font_color", SugarStreetColors.BAKERY_BROWN)
	add_child(_stage_label)

	for slot in GameState.decor_catalog.all_slots():
		var panel := PanelContainer.new()
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.gui_input.connect(_on_slot_gui.bind(str(slot.slot_id)))
		add_child(panel)
		_slot_nodes[str(slot.slot_id)] = panel
	_layout()


func set_edit_mode(enabled: bool) -> void:
	_edit_mode = enabled
	refresh()


func set_selected_slot(slot_id: String) -> void:
	_selected_slot = slot_id
	refresh()


func refresh() -> void:
	if _bg == null:
		return
	var level := clampi(GameState.data.shop_level, 1, 5)
	_apply_stage(level)
	_stage_label.text = "Shop Stage %d · %s" % [level, GameState.data.shop_appeal_tier]
	for slot in GameState.decor_catalog.all_slots():
		var sid := str(slot.slot_id)
		var panel: PanelContainer = _slot_nodes.get(sid)
		if panel == null:
			continue
		_paint_slot(panel, slot)
	_layout()


func _apply_stage(level: int) -> void:
	match level:
		1:
			_bg.color = Color("#F6E4D4")
			_trim.color = Color("#D7B39A")
		2:
			_bg.color = Color("#F8EADF")
			_trim.color = Color("#E7AAAE")
		3:
			_bg.color = Color("#F3E7DC")
			_trim.color = Color("#86C8AE")
		4:
			_bg.color = Color("#F7E8D8")
			_trim.color = Color("#F4BC4B")
		_:
			_bg.color = Color("#F4E2CF")
			_trim.color = Color("#F4BC4B")


func _paint_slot(panel: PanelContainer, slot: DecorationSlotDef) -> void:
	for c in panel.get_children():
		c.queue_free()
	var unlocked := DecorationManager.is_slot_unlocked(slot, GameState.data)
	var placed_id := str(GameState.data.placed_decorations.get(str(slot.slot_id), ""))
	var decor: DecorationData = GameState.decor_catalog.get_decoration(StringName(placed_id)) if placed_id != "" else null
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(12)
	style.set_border_width_all(2)
	if not unlocked:
		style.bg_color = Color(0.75, 0.72, 0.7, 0.85)
		style.border_color = SugarStreetColors.DISABLED_FILL
	elif decor:
		style.bg_color = decor.placeholder_color.lightened(0.15)
		style.border_color = decor.placeholder_color.darkened(0.2)
	else:
		style.bg_color = Color(1, 1, 1, 0.35)
		style.border_color = SugarStreetColors.SOFT_BORDER
	if _edit_mode and unlocked:
		style.set_border_width_all(3)
		style.border_color = SugarStreetColors.MINT_GREEN if _selected_slot != str(slot.slot_id) else SugarStreetColors.GOLDEN_YELLOW
	panel.add_theme_stylebox_override("panel", style)

	var lbl := Label.new()
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", SugarStreetColors.BAKERY_BROWN)
	if not unlocked:
		lbl.text = "🔒 Lv%d\n%s" % [slot.required_shop_level, slot.display_name]
	elif decor:
		lbl.text = "%s\n%s" % [decor.placeholder_symbol, decor.display_name]
	else:
		lbl.text = "＋\n%s" % slot.display_name
	panel.add_child(lbl)


func _layout() -> void:
	if size.x < 8 or size.y < 8:
		return
	_trim.position = Vector2(0, size.y * 0.88)
	_trim.size = Vector2(size.x, size.y * 0.12)
	_stage_label.position = Vector2(8, 4)
	_stage_label.size = Vector2(size.x - 16, 18)
	for slot in GameState.decor_catalog.all_slots():
		var panel: PanelContainer = _slot_nodes.get(str(slot.slot_id))
		if panel == null:
			continue
		panel.position = Vector2(slot.anchor_pos.x * size.x, slot.anchor_pos.y * size.y)
		panel.size = Vector2(maxi(44, slot.anchor_size.x * size.x), maxi(44, slot.anchor_size.y * size.y))


func _on_slot_gui(event: InputEvent, slot_id: String) -> void:
	if not _edit_mode:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		slot_pressed.emit(slot_id)
	elif event is InputEventScreenTouch and event.pressed:
		slot_pressed.emit(slot_id)


func _on_appeal(_appeal: int, _tier: String) -> void:
	refresh()
