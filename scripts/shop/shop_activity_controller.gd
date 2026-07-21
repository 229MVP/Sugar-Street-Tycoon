class_name ShopActivityController
extends Node
## Lightweight visual-only shop activity (customers + FX). Paused with modals.

const POOL_SIZE := 4

var _host: Control
var _pool: Array[VisualCustomer] = []
var _spawn_timer: float = 0.0
var _paused: bool = false
var _colors: Array[Color] = [
	Color(0.95, 0.7, 0.7), Color(0.7, 0.85, 0.95), Color(0.85, 0.9, 0.7),
	Color(0.9, 0.8, 0.6), Color(0.8, 0.75, 0.95),
]


func setup(host: Control) -> void:
	_host = host
	for i in POOL_SIZE:
		var c := VisualCustomer.new()
		_host.add_child(c)
		_pool.append(c)
	_spawn_timer = randf_range(1.5, 3.0)
	set_process(true)


func set_paused(paused: bool) -> void:
	_paused = paused


func _process(delta: float) -> void:
	if _paused or _host == null or not is_inside_tree():
		return
	_spawn_timer -= delta
	if _spawn_timer > 0.0:
		return
	_spawn_timer = randf_range(2.5, 5.5)
	_spawn_one()


func _spawn_one() -> void:
	for c in _pool:
		if not c.active:
			var y := _host.size.y * randf_range(0.55, 0.82)
			var from_pos := Vector2(-40, y)
			var to_pos := Vector2(_host.size.x * randf_range(0.35, 0.7), y)
			c.activate(from_pos, to_pos, _colors[randi() % _colors.size()])
			return


func clear_all() -> void:
	for c in _pool:
		c.deactivate()
