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
var _booster_buttons: Dictionary = {}
var _active_booster: StringName = &""
var _confirm: ConfirmPopup
var _tutorial: TutorialOverlay


func _ready() -> void:
	var debug_hint := get_node_or_null("SafeArea/VBox/DebugHint")
	if debug_hint:
		debug_hint.visible = BuildConfig.debug_features_enabled()
	controller.board_path = controller.get_path_to(board)
	controller.set_board(board)
	if SceneRouter.pending_level_config != null:
		controller.configure_session(SceneRouter.pending_order_id, SceneRouter.pending_level_config)

	_style_board_frame()
	_build_booster_bar()
	_level_complete = LevelCompletePopup.new()
	$Overlays.add_child(_level_complete)
	_confirm = ConfirmPopup.new()
	$Overlays.add_child(_confirm)

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
	pause_popup.give_up_pressed.connect(_on_give_up_pressed)

	debug_panel.print_board.connect(controller.debug_print_board)
	debug_panel.restart.connect(controller.restart_level)
	debug_panel.check_moves.connect(controller.debug_check_moves)
	debug_panel.add_moves.connect(controller.debug_add_moves)
	debug_panel.add_objective.connect(controller.debug_add_objective)
	debug_panel.reshuffle.connect(controller.debug_reshuffle)
	if not board.booster_action_finished.is_connected(_on_booster_action_finished):
		board.booster_action_finished.connect(_on_booster_action_finished)
	if not board.booster_mode_changed.is_connected(_on_booster_mode_changed):
		board.booster_mode_changed.connect(_on_booster_mode_changed)
	call_deferred("_maybe_show_tutorial", "gameplay")
	call_deferred("_maybe_show_gameplay_feature_tips")


func _maybe_show_tutorial(screen_key: String) -> void:
	if not TutorialManager.should_show(GameState.data, screen_key):
		return
	var step := TutorialManager.current_step(GameState.data)
	_tutorial = TutorialOverlay.new()
	$Overlays.add_child(_tutorial)
	_tutorial.next_pressed.connect(func():
		TutorialManager.advance(GameState.data)
		GameState.save_now()
		_tutorial.queue_free()
		call_deferred("_maybe_show_gameplay_feature_tips")
	)
	_tutorial.skip_pressed.connect(func():
		TutorialManager.skip(GameState.data)
		GameState.save_now()
		_tutorial.queue_free()
	)
	_tutorial.show_step(str(step.get("title", "")), str(step.get("body", "")))


func _maybe_show_gameplay_feature_tips() -> void:
	## After the linear gameplay step (or when already completed), show one-shot
	## specials/boosters tips the first time the player is in a puzzle.
	if TutorialManager.is_active(GameState.data):
		return
	if TutorialManager.should_show_feature_tip(GameState.data, "special_pieces"):
		FeatureTipPresenter.maybe_show(self, "special_pieces")
		return
	if TutorialManager.should_show_feature_tip(GameState.data, "boosters"):
		FeatureTipPresenter.maybe_show(self, "boosters")


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
	vbox.move_child(_booster_bar, mini(3, vbox.get_child_count() - 1))
	var boosters := [
		[BoosterManager.HAMMER, "🔨", "Hammer"],
		[BoosterManager.SWAP, "↔", "Swap"],
	]
	for b in boosters:
		var booster_id: StringName = b[0]
		var btn := Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(64, 48)
		btn.toggle_mode = true
		ThemeFactory.apply_button_styles(btn, {
			"normal": ThemeFactory._btn(SugarStreetColors.SOFT_PEACH, 14),
			"hover": ThemeFactory._btn(SugarStreetColors.SOFT_PEACH, 14),
			"pressed": ThemeFactory._btn(SugarStreetColors.MINT_GREEN, 14),
			"disabled": ThemeFactory._btn(SugarStreetColors.SOFT_IVORY, 14),
			"focus": ThemeFactory._btn(SugarStreetColors.SOFT_PEACH, 14),
		}, SugarStreetColors.DARK_TEXT)
		btn.pressed.connect(func(): _on_booster_pressed(booster_id))
		_booster_bar.add_child(btn)
		_booster_buttons[booster_id] = btn
	_refresh_booster_bar()


func _refresh_booster_bar() -> void:
	for booster_id in _booster_buttons.keys():
		var btn: Button = _booster_buttons[booster_id]
		var count := BoosterManager.get_count(GameState.data, booster_id)
		var label := "Hammer" if booster_id == BoosterManager.HAMMER else "Swap"
		var icon := "🔨" if booster_id == BoosterManager.HAMMER else "↔"
		btn.text = "%s %s\nx%d" % [icon, label, count]
		btn.disabled = count <= 0 or board.is_input_locked() or board.is_resolving()
		btn.button_pressed = _active_booster == booster_id


func _on_booster_pressed(booster_id: StringName) -> void:
	if board.is_input_locked() or board.is_resolving():
		return
	if _active_booster == booster_id:
		_cancel_booster_mode()
		return
	if not BoosterManager.can_use(GameState.data, booster_id):
		_refresh_booster_bar()
		return
	_cancel_booster_mode()
	_active_booster = booster_id
	var mode := MatchBoard.BoosterMode.HAMMER if booster_id == BoosterManager.HAMMER else MatchBoard.BoosterMode.SWAP
	board.enter_booster_mode(mode)
	_refresh_booster_bar()
	controller.status_message.emit(
		"Tap a tile to smash it." if booster_id == BoosterManager.HAMMER
		else "Select two adjacent tiles to swap."
	)


func _cancel_booster_mode() -> void:
	if _active_booster != &"":
		board.cancel_booster_mode()
	_active_booster = &""
	_refresh_booster_bar()


func _on_booster_mode_changed(active: bool) -> void:
	if not active:
		_active_booster = &""
	_refresh_booster_bar()


func _on_booster_action_finished(mode: int, success: bool) -> void:
	if not success:
		controller.status_message.emit("Booster canceled.")
		_cancel_booster_mode()
		return
	var booster_id := BoosterManager.HAMMER if mode == MatchBoard.BoosterMode.HAMMER else BoosterManager.SWAP
	if BoosterManager.consume(GameState.data, booster_id):
		GameState.save_now()
	_refresh_booster_bar()
	_active_booster = &""
	controller.status_message.emit("Booster used!")


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
	call_deferred("_maybe_show_tutorial", "level_complete")


func _on_show_loss(progress_text: String) -> void:
	pause_popup.hide_popup()
	win_popup.hide_popup()
	_level_complete.hide_popup()
	loss_popup.show_result(progress_text)


func _on_win_continue() -> void:
	# Mark ready-to-complete in GameState already happened on win via controller.
	_level_complete.hide_popup()
	win_popup.hide_popup()
	if controller.session_order_id != "":
		SceneRouter.return_to_shop_from_level()
	else:
		controller.restart_level()


func _on_replay() -> void:
	_cancel_booster_mode()
	_level_complete.hide_popup()
	win_popup.hide_popup()
	loss_popup.hide_popup()
	controller.restart_level()


func _on_give_up_pressed() -> void:
	_cancel_booster_mode()
	## Destructive action (forfeits the current attempt) — require confirmation.
	_confirm.show_confirm(
		"Give Up?",
		"You'll return to the Shop Hub and this attempt will be marked failed.",
		"Give Up",
		"Keep Playing"
	)
	if not _confirm.confirmed.is_connected(_do_give_up):
		_confirm.confirmed.connect(_do_give_up, CONNECT_ONE_SHOT)
	if not _confirm.cancelled.is_connected(_on_give_up_cancelled):
		_confirm.cancelled.connect(_on_give_up_cancelled, CONNECT_ONE_SHOT)


func _on_give_up_cancelled() -> void:
	pause_popup.show_pause()


func _do_give_up() -> void:
	pause_popup.hide_popup()
	controller.exit_to_ready()


func _on_loss_exit() -> void:
	loss_popup.hide_popup()
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
