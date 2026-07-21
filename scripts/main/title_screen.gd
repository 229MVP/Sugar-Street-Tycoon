extends Control
## Title screen: Sugar Street Tycoon — Match & Build.
## Play / Continue → Shop Hub. New Game resets starter save after confirm.

@onready var play_button: Button = %PlayButton
@onready var continue_button: Button = %ContinueButton
@onready var new_game_button: Button = %NewGameButton
@onready var settings_button: Button = %SettingsButton
@onready var exit_button: Button = %ExitButton
@onready var subtitle_label: Label = %SubtitleLabel
@onready var version_label: Label = %VersionLabel
@onready var confirm_host: Control = %ConfirmHost
@onready var decor_host: Control = %DecorHost

var _confirm: ConfirmPopup


func _ready() -> void:
	_confirm = ConfirmPopup.new()
	confirm_host.add_child(_confirm)
	_build_bakery_decor()
	_style_buttons()

	subtitle_label.text = "Match & Build"
	version_label.text = "v%s" % str(ProjectSettings.get_setting("application/config/version", "0.0.0"))

	play_button.pressed.connect(_on_play)
	continue_button.disabled = false
	continue_button.pressed.connect(_on_continue)
	new_game_button.pressed.connect(_on_new_game)
	settings_button.pressed.connect(_on_settings)
	exit_button.pressed.connect(_on_exit)
	exit_button.visible = OS.has_feature("pc") or OS.get_name() in ["Windows", "Linux", "macOS"]

	AudioManager.play(AudioManager.Sfx.SHOP_OPENED)
	_pulse_brand()


func _build_bakery_decor() -> void:
	## Soft candy discs and frosting bands for a bakery atmosphere.
	var palette := [
		Color(0.95, 0.45, 0.55, 0.55),
		Color(0.98, 0.75, 0.45, 0.5),
		Color(0.75, 0.9, 0.95, 0.5),
		Color(0.9, 0.7, 0.85, 0.45),
		Color(0.7, 0.85, 0.55, 0.45),
	]
	var positions := [
		Vector2(0.08, 0.18), Vector2(0.82, 0.14), Vector2(0.12, 0.72),
		Vector2(0.78, 0.68), Vector2(0.5, 0.86), Vector2(0.9, 0.4),
		Vector2(0.05, 0.45), Vector2(0.42, 0.12),
	]
	for i in positions.size():
		var disc := ColorRect.new()
		disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var size := 36.0 + float(i % 3) * 18.0
		disc.custom_minimum_size = Vector2(size, size)
		disc.size = Vector2(size, size)
		disc.color = palette[i % palette.size()]
		disc.set_meta("anchor", positions[i])
		decor_host.add_child(disc)
		# Soft round look via large corner radius style isn't on ColorRect;
		# modulate a gentle float animation instead.
		var tween := create_tween().set_loops()
		tween.tween_property(disc, "modulate:a", 0.55, 1.2 + float(i) * 0.08).set_trans(Tween.TRANS_SINE)
		tween.tween_property(disc, "modulate:a", 1.0, 1.2 + float(i) * 0.08).set_trans(Tween.TRANS_SINE)
	resized.connect(_layout_decor)
	call_deferred("_layout_decor")


func _layout_decor() -> void:
	for child in decor_host.get_children():
		if child is ColorRect and child.has_meta("anchor"):
			var a: Vector2 = child.get_meta("anchor")
			child.position = Vector2(size.x * a.x, size.y * a.y) - child.size * 0.5


func _style_buttons() -> void:
	_apply_button_style(play_button, Color(0.92, 0.35, 0.48), Color(1, 0.97, 0.96))
	_apply_button_style(continue_button, Color(0.95, 0.55, 0.45), Color(1, 0.97, 0.96))
	_apply_button_style(new_game_button, Color(0.98, 0.82, 0.55), Color(0.35, 0.22, 0.18))
	_apply_button_style(settings_button, Color(0.86, 0.72, 0.68), Color(0.3, 0.2, 0.2))
	_apply_button_style(exit_button, Color(0.78, 0.62, 0.6), Color(0.28, 0.18, 0.18))


func _apply_button_style(button: Button, fill: Color, font_color: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = fill
	normal.corner_radius_top_left = 18
	normal.corner_radius_top_right = 18
	normal.corner_radius_bottom_right = 18
	normal.corner_radius_bottom_left = 18
	normal.content_margin_left = 16
	normal.content_margin_right = 16
	normal.content_margin_top = 10
	normal.content_margin_bottom = 10
	normal.shadow_color = Color(0.35, 0.15, 0.2, 0.22)
	normal.shadow_size = 6
	normal.shadow_offset = Vector2(0, 3)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = fill.lightened(0.08)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = fill.darkened(0.08)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", font_color)
	button.add_theme_color_override("font_pressed_color", font_color)
	button.add_theme_font_size_override("font_size", 20)


func _pulse_brand() -> void:
	var brand := get_node_or_null("Margin/VBox/Brand") as CanvasItem
	if brand == null:
		return
	var tween := create_tween().set_loops()
	tween.tween_property(brand, "modulate", Color(1.05, 1.02, 0.98, 1), 1.4).set_trans(Tween.TRANS_SINE)
	tween.tween_property(brand, "modulate", Color.WHITE, 1.4).set_trans(Tween.TRANS_SINE)


func _on_play() -> void:
	AudioManager.play_button()
	if GameState.has_save():
		GameState.continue_game()
	SceneRouter.go_shop()


func _on_continue() -> void:
	AudioManager.play_button()
	if GameState.has_save():
		GameState.continue_game()
	SceneRouter.go_shop()


func _on_new_game() -> void:
	AudioManager.play_button()
	if GameState.has_save():
		_confirm.show_confirm(
			"Start New Game?",
			"This will reset your starter save data (level, coins, orders). Are you sure?",
			"New Game",
			"Cancel"
		)
		if not _confirm.confirmed.is_connected(_do_new_game):
			_confirm.confirmed.connect(_do_new_game, CONNECT_ONE_SHOT)
	else:
		_do_new_game()


func _do_new_game() -> void:
	GameState.new_game()
	SceneRouter.go_shop()


func _on_settings() -> void:
	AudioManager.play_button()
	_confirm.show_confirm(
		"Settings",
		"Music and SFX toggles will expand here. Audio is handled by AudioManager.",
		"OK",
		"Close"
	)


func _on_exit() -> void:
	AudioManager.play_button()
	GameState.save_now()
	get_tree().quit()
