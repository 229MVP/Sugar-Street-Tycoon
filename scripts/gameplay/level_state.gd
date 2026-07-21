class_name LevelState
extends RefCounted
## High-level level lifecycle: playing, won, lost, paused.

enum State { READY, PLAYING, PAUSED, WON, LOST }

signal state_changed(new_state: State)
signal moves_changed(moves_remaining: int)

var state: State = State.READY
var moves_remaining: int = 0
var move_limit: int = 0


func setup(config: LevelConfig) -> void:
	move_limit = config.move_limit
	moves_remaining = config.move_limit
	state = State.READY
	moves_changed.emit(moves_remaining)
	state_changed.emit(state)


func start_playing() -> void:
	_set_state(State.PLAYING)


func pause() -> void:
	if state == State.PLAYING:
		_set_state(State.PAUSED)


func resume() -> void:
	if state == State.PAUSED:
		_set_state(State.PLAYING)


func consume_move() -> void:
	if state != State.PLAYING:
		return
	moves_remaining = maxi(moves_remaining - 1, 0)
	moves_changed.emit(moves_remaining)


func add_moves(amount: int) -> void:
	moves_remaining += amount
	moves_changed.emit(moves_remaining)


func mark_won() -> void:
	_set_state(State.WON)


func mark_lost() -> void:
	_set_state(State.LOST)


func can_accept_input() -> bool:
	return state == State.PLAYING


func _set_state(new_state: State) -> void:
	if state == new_state:
		return
	state = new_state
	state_changed.emit(state)
