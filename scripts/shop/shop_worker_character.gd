class_name ShopWorkerCharacter
extends Control
## Placeholder worker avatar near a shop station.

signal selected(worker_id: StringName)

var worker_id: StringName = &""
var _body: ColorRect
var _head: ColorRect
var _label: Label
var _base_pos: Vector2 = Vector2.ZERO
var _anim_time: float = 0.0


func setup(worker: WorkerData, station_pos: Vector2) -> void:
	worker_id = worker.worker_id
	custom_minimum_size = Vector2(46, 70)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	position = station_pos
	_base_pos = station_pos

	_body = ColorRect.new()
	_body.color = worker.body_color
	_body.position = Vector2(10, 24)
	_body.size = Vector2(26, 36)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_body)

	_head = ColorRect.new()
	_head.color = worker.portrait_color
	_head.position = Vector2(12, 4)
	_head.size = Vector2(22, 22)
	_head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_head)

	_label = Label.new()
	_label.text = worker.display_name.substr(0, 1)
	_label.position = Vector2(0, 52)
	_label.size = Vector2(46, 18)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 11)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)

	gui_input.connect(_on_gui_input)
	_anim_time = randf() * TAU


func _process(delta: float) -> void:
	_anim_time += delta * 2.5
	# Simple bounce / work motion.
	position = _base_pos + Vector2(sin(_anim_time) * 3.0, absf(sin(_anim_time * 1.4)) * -4.0)
	rotation = sin(_anim_time * 0.7) * 0.05


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			selected.emit(worker_id)
			accept_event()
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			selected.emit(worker_id)
			accept_event()
