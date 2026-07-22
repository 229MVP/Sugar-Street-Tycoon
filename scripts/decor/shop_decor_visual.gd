class_name ShopDecorVisual
extends Control
## Centralized placeholder rendering for shop stage + placed decorations.


signal slot_pressed(slot_id: String)

var _bg: ColorRect
var _trim: ColorRect
var _header: PanelContainer
var _name_label: Label
var _stage_label: Label
var _lights: Array = []
var _slot_nodes: Dictionary = {} ## slot_id -> PanelContainer
var _edit_mode: bool = false
var _selected_slot: String = ""


func _ready() -> void:
	custom_minimum_size = Vector2(0, 240)
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
	while get_child_count() > 0:
		var child := get_child(0)
		remove_child(child)
		child.free()
	_lights.clear()
	_slot_nodes.clear()

	_bg = ColorRect.new()
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	# Warm wall wash stripe
	var wash := ColorRect.new()
	wash.color = Color(1, 1, 1, 0.18)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wash)
	wash.set_meta("role", "wash")

	_trim = ColorRect.new()
	_trim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_trim)

	for i in range(3):
		var light := PanelContainer.new()
		light.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var lstyle := StyleBoxFlat.new()
		lstyle.bg_color = Color("#F4BC4B")
		lstyle.set_corner_radius_all(10)
		lstyle.shadow_color = Color(1, 0.85, 0.4, 0.35)
		lstyle.shadow_size = 6
		light.add_theme_stylebox_override("panel", lstyle)
		add_child(light)
		_lights.append(light)

	_header = PanelContainer.new()
	_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hstyle := StyleBoxFlat.new()
	hstyle.bg_color = Color("#FFF9F2")
	hstyle.set_corner_radius_all(12)
	hstyle.content_margin_left = 10
	hstyle.content_margin_right = 10
	hstyle.content_margin_top = 6
	hstyle.content_margin_bottom = 6
	hstyle.set_border_width_all(1)
	hstyle.border_color = SugarStreetColors.SOFT_BORDER
	_header.add_theme_stylebox_override("panel", hstyle)
	add_child(_header)
	var hbox := VBoxContainer.new()
	hbox.add_theme_constant_override("separation", 2)
	_header.add_child(hbox)
	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 15)
	_name_label.add_theme_color_override("font_color", SugarStreetColors.BAKERY_BROWN)
	hbox.add_child(_name_label)
	_stage_label = Label.new()
	_stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stage_label.add_theme_font_size_override("font_size", 11)
	_stage_label.add_theme_color_override("font_color", SugarStreetColors.WOOD_BROWN)
	hbox.add_child(_stage_label)

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
	if _name_label:
		_name_label.text = GameState.data.shop_name
	_stage_label.text = "Shop Lv %d · Appeal %d · %s" % [
		level, GameState.data.shop_appeal, GameState.data.shop_appeal_tier
	]
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
	while panel.get_child_count() > 0:
		var child := panel.get_child(0)
		panel.remove_child(child)
		child.free()
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
	for child in get_children():
		if child is ColorRect and child.has_meta("role") and str(child.get_meta("role")) == "wash":
			child.position = Vector2(0, size.y * 0.08)
			child.size = Vector2(size.x, size.y * 0.55)
	_trim.position = Vector2(0, size.y * 0.88)
	_trim.size = Vector2(size.x, size.y * 0.12)
	if _header:
		_header.position = Vector2(10, 8)
		_header.size = Vector2(size.x - 20, 44)
	for i in range(_lights.size()):
		var light: Control = _lights[i]
		var x := size.x * (0.22 + 0.28 * float(i))
		light.position = Vector2(x - 7, 56)
		light.size = Vector2(14, 14)
	for slot in GameState.decor_catalog.all_slots():
		var panel: PanelContainer = _slot_nodes.get(str(slot.slot_id))
		if panel == null:
			continue
		# Push slots slightly down to clear the name header.
		var y := maxf(slot.anchor_pos.y, 0.28)
		panel.position = Vector2(slot.anchor_pos.x * size.x, y * size.y)
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
