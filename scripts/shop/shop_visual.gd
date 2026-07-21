class_name ShopVisual
extends Control
## Placeholder shop interior with equipment stages and assigned workers.

signal worker_selected(worker_id: StringName)

var _oven: Panel
var _mixer: Panel
var _display: Panel
var _checkout: Panel
var _order_desk: Panel
var _manager: Panel
var _counter: Panel
var _sign: Label
var _oven_label: Label
var _mixer_label: Label
var _display_label: Label
var _checkout_label: Label
var _order_label: Label
var _manager_label: Label
var _counter_label: Label
var _worker_layer: Control
var _worker_nodes: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_build()
	refresh()
	if not GameState.equipment_upgraded.is_connected(_on_upgraded):
		GameState.equipment_upgraded.connect(_on_upgraded)
	if not GameState.state_changed.is_connected(refresh):
		GameState.state_changed.connect(refresh)
	if not GameState.worker_assigned.is_connected(_on_worker_changed):
		GameState.worker_assigned.connect(_on_worker_changed)
	if not GameState.worker_unassigned.is_connected(_on_worker_unassigned):
		GameState.worker_unassigned.connect(_on_worker_unassigned)


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.98, 0.92, 0.88, 1)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_sign = Label.new()
	_sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sign.position = Vector2(20, 8)
	_sign.size = Vector2(280, 28)
	_sign.add_theme_font_size_override("font_size", 16)
	_sign.add_theme_color_override("font_color", Color(0.45, 0.2, 0.25))
	add_child(_sign)

	_display = _make_station(Color(0.75, 0.88, 0.95), Vector2(0.06, 0.18), Vector2(0.42, 0.24))
	_oven = _make_station(Color(0.55, 0.55, 0.6), Vector2(0.56, 0.16), Vector2(0.22, 0.26))
	_mixer = _make_station(Color(0.85, 0.7, 0.55), Vector2(0.06, 0.48), Vector2(0.24, 0.24))
	_checkout = _make_station(Color(0.7, 0.55, 0.45), Vector2(0.52, 0.48), Vector2(0.4, 0.22))
	_order_desk = _make_station(Color(0.78, 0.72, 0.88), Vector2(0.34, 0.48), Vector2(0.16, 0.22))
	_manager = _make_station(Color(0.55, 0.45, 0.5), Vector2(0.38, 0.28), Vector2(0.14, 0.16))
	_counter = _make_station(Color(0.92, 0.82, 0.7), Vector2(0.08, 0.86), Vector2(0.84, 0.08))

	_display_label = _label_on(_display)
	_oven_label = _label_on(_oven)
	_mixer_label = _label_on(_mixer)
	_checkout_label = _label_on(_checkout)
	_order_label = _label_on(_order_desk)
	_manager_label = _label_on(_manager)
	_counter_label = _label_on(_counter)

	_worker_layer = Control.new()
	_worker_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_worker_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_worker_layer)
	resized.connect(_layout)


func _make_station(color: Color, anchor_pos: Vector2, anchor_size: Vector2) -> Panel:
	var panel := Panel.new()
	panel.set_meta("ap", anchor_pos)
	panel.set_meta("as", anchor_size)
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.35, 0.25, 0.28, 0.55)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	return panel


func _label_on(panel: Panel) -> Label:
	var label := Label.new()
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.15, 0.12, 0.12))
	panel.add_child(label)
	return label


func _layout() -> void:
	_sign.size = Vector2(size.x - 40, 28)
	for panel in [_display, _oven, _mixer, _checkout, _order_desk, _manager, _counter]:
		if panel == null:
			continue
		var ap: Vector2 = panel.get_meta("ap")
		var asz: Vector2 = panel.get_meta("as")
		panel.position = Vector2(size.x * ap.x, size.y * ap.y)
		panel.size = Vector2(size.x * asz.x, size.y * asz.y)


func refresh() -> void:
	_layout()
	_sign.text = GameState.data.shop_name
	_apply_station(_oven, _oven_label, &"oven", Color(0.55, 0.55, 0.6))
	_apply_station(_mixer, _mixer_label, &"mixer", Color(0.85, 0.7, 0.55))
	_apply_station(_display, _display_label, &"display_case", Color(0.75, 0.88, 0.95))
	_apply_station(_checkout, _checkout_label, &"checkout", Color(0.7, 0.55, 0.45))
	_order_label.text = "Order Desk"
	_manager_label.text = "Manager"
	_counter_label.text = "Dessert Counter"
	_rebuild_workers()


func _apply_station(panel: Panel, label: Label, equipment_id: StringName, base_color: Color) -> void:
	var level := GameState.get_equipment_level(equipment_id)
	var eq := GameState.catalog.get_equipment(equipment_id)
	var style := panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	var t := clampf(float(level - 1) / 4.0, 0.0, 1.0)
	style.bg_color = base_color.lightened(t * 0.35)
	style.border_width_left = 2 + level
	style.border_width_top = 2 + level
	style.border_width_right = 2 + level
	style.border_width_bottom = 2 + level
	style.corner_radius_top_left = 8 + level * 2
	style.corner_radius_top_right = 8 + level * 2
	style.corner_radius_bottom_right = 8 + level * 2
	style.corner_radius_bottom_left = 8 + level * 2
	panel.add_theme_stylebox_override("panel", style)
	var stage := eq.stage_label_for(level) if eq else "Lv.%d" % level
	label.text = "%s\nLv.%d" % [stage, level]


func station_anchor(station: WorkerData.Station) -> Vector2:
	var panel: Panel = null
	match station:
		WorkerData.Station.OVEN: panel = _oven
		WorkerData.Station.MIXER: panel = _mixer
		WorkerData.Station.CHECKOUT: panel = _checkout
		WorkerData.Station.DISPLAY_CASE: panel = _display
		WorkerData.Station.ORDER_DESK: panel = _order_desk
		WorkerData.Station.MANAGER: panel = _manager
	if panel == null:
		return Vector2(size.x * 0.5, size.y * 0.5)
	return panel.position + Vector2(panel.size.x * 0.35, panel.size.y * 0.55)


func _rebuild_workers() -> void:
	for child in _worker_layer.get_children():
		child.queue_free()
	_worker_nodes.clear()
	for station_key in GameState.data.worker_assignments.keys():
		var worker_id := str(GameState.data.worker_assignments[station_key])
		var worker := GameState.catalog.get_worker(StringName(worker_id))
		if worker == null:
			continue
		var station := WorkerData.station_from_string(str(station_key))
		var node := ShopWorkerCharacter.new()
		_worker_layer.add_child(node)
		node.setup(worker, station_anchor(station))
		node.selected.connect(func(id): worker_selected.emit(id))
		_worker_nodes[worker_id] = node


func _on_upgraded(_id: StringName, _level: int) -> void:
	refresh()
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1.2, 1.15, 1.05), 0.12)
	tween.tween_property(self, "modulate", Color.WHITE, 0.2)


func _on_worker_changed(_id: StringName, _station: String) -> void:
	_rebuild_workers()


func _on_worker_unassigned(_id: StringName) -> void:
	_rebuild_workers()
