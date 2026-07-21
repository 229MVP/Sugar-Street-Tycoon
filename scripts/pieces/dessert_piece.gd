class_name DessertPiece
extends Control
## Visual + input node for a single dessert on the board.
## Board logic owns grid coordinates; this node handles presentation and gestures.

signal selected(piece: DessertPiece)
signal drag_released(piece: DessertPiece, direction: Vector2i)

const SELECT_SCALE := 1.12
const ANIM_SELECT := 0.12
const ANIM_SWAP := 0.18
const ANIM_INVALID := 0.16
const ANIM_CLEAR := 0.2
const ANIM_FALL := 0.18
const ANIM_SPAWN := 0.22

var piece_type: PieceType
var grid_pos: Vector2i = Vector2i.ZERO
var cell_size: float = 64.0
var input_enabled: bool = true

var _dragging: bool = false
var _press_local: Vector2 = Vector2.ZERO
var _base_scale: Vector2 = Vector2.ONE
var _selected: bool = false

@onready var _sprite: TextureRect = $TextureRect
@onready var _label: Label = $FallbackLabel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_base_scale = scale
	gui_input.connect(_on_gui_input)
	_apply_visuals()
	_apply_size()


func setup(type: PieceType, pos: Vector2i, size: float) -> void:
	piece_type = type
	grid_pos = pos
	cell_size = size
	if is_inside_tree():
		_apply_visuals()
		_apply_size()


func get_type_id() -> StringName:
	if piece_type == null:
		return &""
	return piece_type.id


func set_selected(is_selected: bool) -> void:
	_selected = is_selected
	pivot_offset = size * 0.5
	var target := _base_scale * (SELECT_SCALE if is_selected else 1.0)
	var tween := create_tween()
	tween.tween_property(self, "scale", target, ANIM_SELECT).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Fire-and-forget movers return duration so the board can await in parallel.
func move_to(world_pos: Vector2, duration: float, trans: Tween.TransitionType = Tween.TRANS_QUAD, ease_type: Tween.EaseType = Tween.EASE_IN) -> float:
	var tween := create_tween()
	tween.tween_property(self, "position", world_pos, duration).set_trans(trans).set_ease(ease_type)
	return duration


func play_clear() -> float:
	pivot_offset = size * 0.5
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", _base_scale * 0.2, ANIM_CLEAR).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, ANIM_CLEAR)
	return ANIM_CLEAR


func play_spawn_from(start_pos: Vector2, end_pos: Vector2) -> float:
	position = start_pos
	modulate.a = 0.0
	pivot_offset = size * 0.5
	scale = _base_scale * 0.5
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position", end_pos, ANIM_SPAWN).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, ANIM_SPAWN * 0.7)
	tween.tween_property(self, "scale", _base_scale, ANIM_SPAWN).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return ANIM_SPAWN


func snap_to(world_pos: Vector2) -> void:
	position = world_pos


func _apply_visuals() -> void:
	if piece_type == null:
		return
	if _sprite:
		_sprite.texture = piece_type.texture
		_sprite.visible = piece_type.texture != null
		_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if piece_type.texture == null:
			_sprite.modulate = piece_type.color
		else:
			_sprite.modulate = Color.WHITE
	if _label:
		_label.text = piece_type.fallback_label if piece_type.texture == null else ""
		_label.visible = piece_type.texture == null
		_label.modulate = piece_type.color


func _apply_size() -> void:
	custom_minimum_size = Vector2(cell_size, cell_size)
	size = Vector2(cell_size, cell_size)
	pivot_offset = size * 0.5
	if _sprite:
		_sprite.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var pad := cell_size * 0.08
		_sprite.offset_left = pad
		_sprite.offset_top = pad
		_sprite.offset_right = -pad
		_sprite.offset_bottom = -pad
	if _label:
		_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func refresh_layout() -> void:
	_apply_size()


func _on_gui_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_dragging = true
			_press_local = mb.position
			selected.emit(self)
			accept_event()
		elif _dragging:
			_dragging = false
			_emit_drag_if_needed(mb.position)
			accept_event()
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_dragging = true
			_press_local = st.position
			selected.emit(self)
			accept_event()
		elif _dragging:
			_dragging = false
			_emit_drag_if_needed(st.position)
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		accept_event()


func _emit_drag_if_needed(release_local: Vector2) -> void:
	var delta := release_local - _press_local
	var threshold := cell_size * 0.22
	if delta.length() < threshold:
		return
	var direction := Vector2i.ZERO
	if absf(delta.x) > absf(delta.y):
		direction = Vector2i(1 if delta.x > 0.0 else -1, 0)
	else:
		direction = Vector2i(0, 1 if delta.y > 0.0 else -1)
	drag_released.emit(self, direction)
