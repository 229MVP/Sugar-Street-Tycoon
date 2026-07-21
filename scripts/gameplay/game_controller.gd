class_name GameController
extends Node
## Orchestrates board, objectives, score, moves, and win/loss flow.

signal hud_refresh_requested
signal show_win(score: int, moves_remaining: int)
signal show_loss(progress_text: String)
signal show_pause
signal hide_overlays
signal objective_pulse
signal status_message(text: String)

@export var level_config: LevelConfig
@export var board_path: NodePath
@export var debug_enabled: bool = true

var score_tracker := ScoreTracker.new()
var objective_tracker := ObjectiveTracker.new()
var level_state := LevelState.new()

var _board: MatchBoard
var _waiting_for_swap_result: bool = false


func _ready() -> void:
	add_to_group("game_controller")
	if level_config == null:
		level_config = load("res://resources/levels/level_01.tres") as LevelConfig
	# Defer so gameplay_root can inject the board reference first.
	call_deferred("_bootstrap")


func set_board(board: MatchBoard) -> void:
	_board = board


func _bootstrap() -> void:
	if _board == null and board_path != NodePath(""):
		_board = get_node_or_null(board_path) as MatchBoard
	if _board == null:
		_board = get_parent().get_node_or_null("SafeArea/VBox/BoardArea/Board") as MatchBoard
	if _board == null:
		_board = get_tree().get_first_node_in_group("match_board") as MatchBoard
	_connect_signals()
	await start_level(level_config)


func _unhandled_input(event: InputEvent) -> void:
	if not debug_enabled:
		return
	if event.is_action_pressed("debug_print_board"):
		debug_print_board()
	elif event.is_action_pressed("debug_restart"):
		restart_level()
	elif event.is_action_pressed("debug_check_moves"):
		debug_check_moves()
	elif event.is_action_pressed("debug_add_moves"):
		debug_add_moves(5)
	elif event.is_action_pressed("debug_add_objective"):
		debug_add_objective(5)
	elif event.is_action_pressed("debug_reshuffle"):
		debug_reshuffle()


func start_level(config: LevelConfig = null) -> void:
	if config != null:
		level_config = config
	if level_config == null or not level_config.validate():
		push_error("GameController: cannot start — invalid level config.")
		return

	hide_overlays.emit()
	score_tracker.reset()
	objective_tracker.setup(level_config.objectives)
	level_state.setup(level_config)
	level_state.start_playing()

	if _board:
		await _board.setup_from_config(level_config)

	hud_refresh_requested.emit()
	status_message.emit("Order up! Match desserts to fill the tray.")


func restart_level() -> void:
	await start_level(level_config)


func pause_game() -> void:
	if not level_state.can_accept_input():
		return
	level_state.pause()
	if _board:
		_board.set_input_locked(true)
	show_pause.emit()


func resume_game() -> void:
	if level_state.state != LevelState.State.PAUSED:
		return
	level_state.resume()
	if _board:
		_board.set_input_locked(false)
	hide_overlays.emit()


func exit_to_ready() -> void:
	## Prototype exit: restart is enough; main menu comes later.
	await restart_level()


func get_score() -> int:
	return score_tracker.score


func get_moves() -> int:
	return level_state.moves_remaining


func get_objective_text() -> String:
	return objective_tracker.get_primary_description()


func get_progress_text() -> String:
	return objective_tracker.get_progress_text()


func get_collected() -> int:
	return objective_tracker.get_progress(objective_tracker.get_primary_piece_id())


func get_target() -> int:
	return objective_tracker.get_target(objective_tracker.get_primary_piece_id())


# ---------------------------------------------------------------------------
# Board signal handlers
# ---------------------------------------------------------------------------

func _connect_signals() -> void:
	if _board == null:
		push_error("GameController: board not found.")
		return
	if not _board.swap_resolved.is_connected(_on_swap_resolved):
		_board.swap_resolved.connect(_on_swap_resolved)
	if not _board.pieces_cleared.is_connected(_on_pieces_cleared):
		_board.pieces_cleared.connect(_on_pieces_cleared)
	if not _board.board_stable.is_connected(_on_board_stable):
		_board.board_stable.connect(_on_board_stable)
	objective_tracker.progress_changed.connect(_on_objective_progress)
	objective_tracker.objective_completed.connect(_on_objective_completed)
	level_state.moves_changed.connect(func(_m): hud_refresh_requested.emit())
	score_tracker.score_changed.connect(func(_s, _d): hud_refresh_requested.emit())


func _on_swap_resolved(was_valid: bool) -> void:
	if not level_state.can_accept_input() and level_state.state != LevelState.State.PLAYING:
		# During resolution state is still PLAYING; keep going.
		pass
	if was_valid:
		level_state.consume_move()
		hud_refresh_requested.emit()
	else:
		status_message.emit("That swap doesn't make a match.")


func _on_pieces_cleared(cleared_types: Dictionary, score_delta: int, cascade_index: int) -> void:
	score_tracker.add_clear_score(score_delta, cascade_index)
	objective_tracker.register_cleared(cleared_types)
	objective_pulse.emit()
	hud_refresh_requested.emit()


func _on_board_stable() -> void:
	score_tracker.reset_cascade_multiplier()
	_evaluate_end_conditions()


func _on_objective_progress(_piece_id: StringName, _current: int, _target: int) -> void:
	hud_refresh_requested.emit()


func _on_objective_completed() -> void:
	# Win is evaluated when the board finishes cascading so the player sees the full resolve.
	pass


func _evaluate_end_conditions() -> void:
	if level_state.state != LevelState.State.PLAYING:
		return
	if objective_tracker.is_complete():
		level_state.mark_won()
		if _board:
			_board.set_input_locked(true)
		show_win.emit(score_tracker.score, level_state.moves_remaining)
		return
	if level_state.moves_remaining <= 0:
		level_state.mark_lost()
		if _board:
			_board.set_input_locked(true)
		show_loss.emit(objective_tracker.get_progress_text())


# ---------------------------------------------------------------------------
# Debug helpers
# ---------------------------------------------------------------------------

func debug_print_board() -> void:
	if _board:
		_board.print_board()
	status_message.emit("Board printed to Output.")


func debug_check_moves() -> void:
	if _board == null:
		return
	var moves := SwapValidator.find_possible_moves(_board.get_type_grid())
	var msg := "Possible moves: %d" % moves.size()
	print(msg)
	if not moves.is_empty():
		print("Example: %s -> %s" % [moves[0]["from"], moves[0]["to"]])
	status_message.emit(msg)


func debug_add_moves(amount: int = 5) -> void:
	level_state.add_moves(amount)
	status_message.emit("+%d moves" % amount)
	hud_refresh_requested.emit()


func debug_add_objective(amount: int = 5) -> void:
	var id := objective_tracker.get_primary_piece_id()
	objective_tracker.add_debug_progress(id, amount)
	status_message.emit("+%d objective progress" % amount)
	hud_refresh_requested.emit()
	_evaluate_end_conditions()


func debug_reshuffle() -> void:
	if _board:
		await _board.force_reshuffle()
		status_message.emit("Board reshuffled.")
