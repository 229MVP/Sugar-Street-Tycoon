extends Control
## Root of the gameplay scene — wires HUD, popups, board, and controller.

@onready var controller: GameController = $GameController
@onready var hud: GameHUD = $SafeArea/VBox/HUD
@onready var board: MatchBoard = $SafeArea/VBox/BoardArea/Board
@onready var win_popup: WinPopup = $Overlays/WinPopup
@onready var loss_popup: LossPopup = $Overlays/LossPopup
@onready var pause_popup: PausePopup = $Overlays/PausePopup
@onready var debug_panel: DebugPanel = $Overlays/DebugPanel


func _ready() -> void:
	controller.board_path = controller.get_path_to(board)
	controller.set_board(board)
	if SceneRouter.pending_level_config != null:
		controller.configure_session(SceneRouter.pending_order_id, SceneRouter.pending_level_config)

	hud.bind_controller(controller)

	controller.show_win.connect(_on_show_win)
	controller.show_loss.connect(_on_show_loss)
	controller.show_pause.connect(pause_popup.show_pause)
	controller.hide_overlays.connect(_hide_all_overlays)

	hud.pause_pressed.connect(controller.pause_game)
	hud.restart_pressed.connect(controller.restart_level)

	win_popup.continue_pressed.connect(_on_win_continue)
	win_popup.replay_pressed.connect(controller.restart_level)
	loss_popup.replay_pressed.connect(controller.restart_level)
	loss_popup.exit_pressed.connect(_on_loss_exit)
	pause_popup.resume_pressed.connect(controller.resume_game)
	pause_popup.restart_pressed.connect(controller.restart_level)

	debug_panel.print_board.connect(controller.debug_print_board)
	debug_panel.restart.connect(controller.restart_level)
	debug_panel.check_moves.connect(controller.debug_check_moves)
	debug_panel.add_moves.connect(controller.debug_add_moves)
	debug_panel.add_objective.connect(controller.debug_add_objective)
	debug_panel.reshuffle.connect(controller.debug_reshuffle)


func _on_show_win(score: int, moves_remaining: int) -> void:
	pause_popup.hide_popup()
	loss_popup.hide_popup()
	var stars := PlayerProgression.calculate_stars(moves_remaining, controller.level_state.move_limit)
	win_popup.show_result(score, moves_remaining, stars)


func _on_show_loss(progress_text: String) -> void:
	pause_popup.hide_popup()
	win_popup.hide_popup()
	loss_popup.show_result(progress_text)


func _on_win_continue() -> void:
	# Rewards are NOT granted here — player completes the order in the shop hub.
	if controller.session_order_id != "":
		SceneRouter.return_to_shop_from_level()
	else:
		controller.restart_level()


func _on_loss_exit() -> void:
	if controller.session_order_id != "":
		SceneRouter.return_to_shop_from_level()
	else:
		controller.exit_to_ready()


func _hide_all_overlays() -> void:
	win_popup.hide_popup()
	loss_popup.hide_popup()
	pause_popup.hide_popup()
