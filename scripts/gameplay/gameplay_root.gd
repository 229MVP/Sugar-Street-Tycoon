extends Control
## Root of the gameplay scene — wires HUD, popups, board, and controller.
## Level Complete uses the new bakery popup; board systems stay intact.

@onready var controller: GameController = $GameController
@onready var hud: GameHUD = $SafeArea/VBox/HUD
@onready var board: MatchBoard = $SafeArea/VBox/BoardArea/Board
@onready var win_popup: WinPopup = $Overlays/WinPopup
@onready var loss_popup: LossPopup = $Overlays/LossPopup
@onready var pause_popup: PausePopup = $Overlays/PausePopup
@onready var debug_panel: DebugPanel = $Overlays/DebugPanel

var _level_complete: LevelCompletePopup
var _booster_bar: HBoxContainer


func _ready() -> void:
	controller.board_path = controller.get_path_to(board)
	controller.set_board(board)
	if SceneRouter.pending_level_config != null:
		controller.configure_session(SceneRouter.pending_order_id, SceneRouter.pending_level_config)

	_style_board_frame()
	_build_booster_bar()
	_level_complete = LevelCompletePopup.new()
	$Overlays.add_child(_level_complete)

	hud.bind_controller(controller)

	controller.show_win.connect(_on_show_win)
	controller.show_loss.connect(_on_show_loss)
	controller.show_pause.connect(pause_popup.show_pause)
	controller.hide_overlays.connect(_hide_all_overlays)

	hud.pause_pressed.connect(controller.pause_game)
	hud.restart_pressed.connect(controller.restart_level)

	win_popup.continue_pressed.connect(_on_win_continue)
	win_popup.replay_pressed.connect(_on_replay)
	_level_complete.continue_pressed.connect(_on_win_continue)
	_level_complete.replay_pressed.connect(_on_replay)
	loss_popup.replay_pressed.connect(_on_replay)
	loss_popup.exit_pressed.connect(_on_loss_exit)
	pause_popup.resume_pressed.connect(controller.resume_game)
	pause_popup.restart_pressed.connect(controller.restart_level)

	debug_panel.print_board.connect(controller.debug_print_board)
	debug_panel.restart.connect(controller.restart_level)
	debug_panel.check_moves.connect(controller.debug_check_moves)
	debug_panel.add_moves.connect(controller.debug_add_moves)
	debug_panel.add_objective.connect(controller.debug_add_objective)
	debug_panel.reshuffle.connect(controller.debug_reshuffle)


func _style_board_frame() -> void:
	var area := $SafeArea/VBox/BoardArea as Control
	if area == null:
		return
	# Soft framed look without replacing MatchBoard.
	var frame := Panel.new()
	frame.name = "BoardFrame"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style := ThemeFactory._card(SugarStreetColors.SOFT_IVORY, 18)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	frame.add_theme_stylebox_override("panel", style)
	area.add_child(frame)
	area.move_child(frame, 0)
	if board:
		board.z_index = 1


func _build_booster_bar() -> void:
	var vbox := $SafeArea/VBox as VBoxContainer
	if vbox == null:
		return
	_booster_bar = HBoxContainer.new()
	_booster_bar.add_theme_constant_override("separation", 8)
	_booster_bar.custom_minimum_size = Vector2(0, 52)
	vbox.add_child(_booster_bar)
	# Place before debug hint if present.
	vbox.move_child(_booster_bar, mini(3, vbox.get_child_count() - 1))
	var boosters := [
		["🥄", "Whisk", 3],
		["🍬", "Stripe", 2],
		["💣", "Bomb", 1],
		["✋", "Swap", 2],
	]
	for b in boosters:
		var btn := Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(44, 48)
		btn.text = "%s\nx%d" % [b[0], b[2]]
		btn.disabled = true # Visual placeholder — no unfinished logic.
		ThemeFactory.apply_button_styles(btn, {
			"normal": ThemeFactory._btn(SugarStreetColors.SOFT_PEACH, 14),
			"hover": ThemeFactory._btn(SugarStreetColors.SOFT_PEACH, 14),
			"pressed": ThemeFactory._btn(SugarStreetColors.SOFT_PEACH, 14),
			"disabled": ThemeFactory._btn(SugarStreetColors.SOFT_IVORY, 14),
			"focus": ThemeFactory._btn(SugarStreetColors.SOFT_PEACH, 14),
		}, SugarStreetColors.DARK_TEXT)
		_booster_bar.add_child(btn)


func _on_show_win(score: int, moves_remaining: int) -> void:
	pause_popup.hide_popup()
	loss_popup.hide_popup()
	win_popup.hide_popup()
	var stars := PlayerProgression.calculate_stars(moves_remaining, controller.level_state.move_limit)
	var coins := 0
	var xp := 0
	var rep := 0
	if controller.session_order_id != "":
		var order := GameState.catalog.get_order(StringName(controller.session_order_id))
		if order:
			coins = order.coin_reward
			xp = order.experience_reward
			rep = order.reputation_reward
	_level_complete.show_result(score, moves_remaining, stars, coins, xp, rep)


func _on_show_loss(progress_text: String) -> void:
	pause_popup.hide_popup()
	win_popup.hide_popup()
	_level_complete.hide_popup()
	loss_popup.show_result(progress_text)


func _on_win_continue() -> void:
	# Mark ready-to-complete in GameState already happened on win via controller.
	if controller.session_order_id != "":
		SceneRouter.return_to_shop_from_level()
	else:
		controller.restart_level()


func _on_replay() -> void:
	_level_complete.hide_popup()
	win_popup.hide_popup()
	loss_popup.hide_popup()
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
	if _level_complete:
		_level_complete.hide_popup()
