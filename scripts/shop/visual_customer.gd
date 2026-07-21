class_name VisualCustomer
extends Control
## Pooled visual-only customer. Does not affect economy.

enum State { IDLE, ENTERING, WAITING, LEAVING }

var state: State = State.IDLE
var _body: ColorRect
var _path_from: Vector2 = Vector2.ZERO
var _path_to: Vector2 = Vector2.ZERO
var _t: float = 0.0
var _wait: float = 0.0
var active: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(28, 40)
	size = custom_minimum_size
	_body = ColorRect.new()
	_body.size = Vector2(28, 40)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_body)
	visible = false
	set_process(false)


func activate(from_pos: Vector2, to_pos: Vector2, color: Color) -> void:
	_body.color = color
	_path_from = from_pos
	_path_to = to_pos
	position = from_pos
	_t = 0.0
	_wait = 0.0
	state = State.ENTERING
	active = true
	visible = true
	set_process(true)
	AudioManager.play(AudioManager.Sfx.CUSTOMER_ENTER)


func _process(delta: float) -> void:
	match state:
		State.ENTERING:
			_t += delta * 0.55
			position = _path_from.lerp(_path_to, clampf(_t, 0.0, 1.0))
			if _t >= 1.0:
				state = State.WAITING
				_wait = randf_range(0.8, 1.8)
		State.WAITING:
			_wait -= delta
			position.y = _path_to.y + sin(Time.get_ticks_msec() * 0.01) * 2.0
			if _wait <= 0.0:
				state = State.LEAVING
				_t = 0.0
				_path_from = position
				_path_to = Vector2(size.x + get_parent().size.x if get_parent() else 400.0, position.y)
		State.LEAVING:
			_t += delta * 0.65
			position = _path_from.lerp(_path_to, clampf(_t, 0.0, 1.0))
			if _t >= 1.0:
				deactivate()


func deactivate() -> void:
	if active:
		AudioManager.play(AudioManager.Sfx.CUSTOMER_LEAVE)
	active = false
	visible = false
	state = State.IDLE
	set_process(false)
