extends Control
## Bakery title screen: Play / Continue / New Game / Settings / Exit.

const SettingsPopupScene := preload("res://scripts/ui/settings_popup.gd")

@onready var root_host: Control = %RootHost

var _confirm: ConfirmPopup
var _settings: Control
var _play_button: Button
var _continue_button: Button
var _logo: Control
var _exit_button: Button


func _ready() -> void:
	# Guardrail: this scene is the F5 entry point (project.godot run/main_scene).
	if OS.is_debug_build():
		var configured := str(ProjectSettings.get_setting("application/run/main_scene", ""))
		if configured != "res://scenes/main/title_screen.tscn":
			push_warning("TitleScreen: unexpected main_scene '%s'" % configured)
	theme = ThemeFactory.build()
	_build_ui()
	_refresh_continue()
	AudioManager.play(AudioManager.Sfx.SHOP_OPENED)


func _build_ui() -> void:
	for c in root_host.get_children():
		c.queue_free()

	var bg := ColorRect.new()
	bg.color = SugarStreetColors.WARM_CREAM
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_host.add_child(bg)

	var sky := ColorRect.new()
	sky.color = Color(0.75, 0.88, 0.95, 1)
	sky.set_anchors_preset(Control.PRESET_TOP_WIDE)
	sky.anchor_bottom = 0.42
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_host.add_child(sky)

	var street := ColorRect.new()
	street.color = SugarStreetColors.SOFT_PEACH
	street.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	street.anchor_top = 0.55
	street.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_host.add_child(street)

	var bakery := Panel.new()
	var bakery_style := ThemeFactory.wood_panel_style()
	bakery_style.bg_color = SugarStreetColors.WOOD_BROWN.lightened(0.1)
	bakery.add_theme_stylebox_override("panel", bakery_style)
	bakery.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	bakery.offset_left = -120
	bakery.offset_right = 120
	bakery.offset_top = -40
	bakery.offset_bottom = 90
	bakery.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_host.add_child(bakery)
	var bakery_label := Label.new()
	bakery_label.text = "My Bakery"
	bakery_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bakery_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bakery_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bakery_label.add_theme_color_override("font_color", SugarStreetColors.WHITE)
	bakery.add_child(bakery_label)

	_spawn_particles(root_host)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 20)
	root_host.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var top_row := HBoxContainer.new()
	vbox.add_child(top_row)
	_icon_btn(top_row, "⚙", _on_settings)
	var top_spacer := Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(top_spacer)

	_logo = VBoxContainer.new()
	vbox.add_child(_logo)
	var brand := Label.new()
	brand.text = "Sugar Street Tycoon"
	brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	brand.add_theme_font_size_override("font_size", 30)
	brand.add_theme_color_override("font_color", SugarStreetColors.BAKERY_BROWN)
	_logo.add_child(brand)
	var subtitle := Label.new()
	subtitle.text = "Match & Build"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_color", SugarStreetColors.CORAL_PINK)
	_logo.add_child(subtitle)
	var tagline := Label.new()
	tagline.text = "Bake · Match · Grow your shop"
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.add_theme_font_size_override("font_size", 14)
	tagline.add_theme_color_override("font_color", SugarStreetColors.DARK_TEXT)
	_logo.add_child(tagline)

	_logo.modulate.a = 0.0
	_logo.position.y = -20
	var logo_tween := create_tween()
	logo_tween.set_parallel(true)
	logo_tween.tween_property(_logo, "modulate:a", 1.0, 0.45)
	logo_tween.tween_property(_logo, "position:y", 0.0, 0.45).set_trans(Tween.TRANS_BACK)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	_play_button = Button.new()
	_play_button.text = "Play"
	_play_button.custom_minimum_size = Vector2(0, 56)
	ThemeFactory.apply_button_styles(_play_button, ThemeFactory.primary_button_styles())
	_play_button.add_theme_font_size_override("font_size", 24)
	_play_button.pressed.connect(_on_play)
	vbox.add_child(_play_button)
	call_deferred("_pulse_play")

	_continue_button = _menu_btn(vbox, "Continue", _on_continue, false)
	_menu_btn(vbox, "New Game", _on_new_game, false)
	_menu_btn(vbox, "Settings", _on_settings, true)

	if _is_desktop_exit_supported():
		_exit_button = _menu_btn(vbox, "Exit", _on_exit, true)

	var version := Label.new()
	version.text = "v%s · placeholder art" % str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version.add_theme_font_size_override("font_size", 12)
	version.add_theme_color_override("font_color", SugarStreetColors.WOOD_BROWN)
	vbox.add_child(version)

	_confirm = ConfirmPopup.new()
	root_host.add_child(_confirm)
	_settings = SettingsPopupScene.new()
	root_host.add_child(_settings)


func _pulse_play() -> void:
	if bool(GameState.data.settings.get("reduce_motion", false)):
		return
	UiMotion.pulse(_play_button, 1.04, 0.9)


func _refresh_continue() -> void:
	if _continue_button:
		_continue_button.disabled = not GameState.has_valid_save()


func _spawn_particles(host: Control) -> void:
	if bool(GameState.data.settings.get("reduce_motion", false)):
		return
	var colors := [SugarStreetColors.CORAL_PINK, SugarStreetColors.GOLDEN_YELLOW, SugarStreetColors.MINT_GREEN, SugarStreetColors.STRAWBERRY_PINK]
	for i in 10:
		var p := ColorRect.new()
		p.size = Vector2(10, 10)
		p.custom_minimum_size = Vector2(10, 10)
		p.color = colors[i % colors.size()]
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.modulate.a = 0.7
		host.add_child(p)
		p.position = Vector2(20 + (i * 37) % 360, 80 + (i * 53) % 500)
		var tween := create_tween().set_loops()
		tween.tween_property(p, "position:y", p.position.y - 18, 1.4 + float(i) * 0.05).set_trans(Tween.TRANS_SINE)
		tween.tween_property(p, "position:y", p.position.y + 8, 1.4 + float(i) * 0.05).set_trans(Tween.TRANS_SINE)


func _icon_btn(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(44, 44)
	ThemeFactory.apply_button_styles(b, ThemeFactory.secondary_button_styles())
	b.pressed.connect(func():
		UiMotion.press_scale(b)
		cb.call()
	)
	parent.add_child(b)
	return b


func _menu_btn(parent: Control, text: String, cb: Callable, secondary: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 48)
	if secondary:
		ThemeFactory.apply_button_styles(b, ThemeFactory.secondary_button_styles())
	else:
		ThemeFactory.apply_button_styles(b, {
			"normal": ThemeFactory._btn(SugarStreetColors.SOFT_PEACH, 18),
			"hover": ThemeFactory._btn(SugarStreetColors.SOFT_PEACH.lightened(0.08), 18),
			"pressed": ThemeFactory._btn(SugarStreetColors.SOFT_PEACH.darkened(0.08), 18),
			"disabled": ThemeFactory._btn(SugarStreetColors.DISABLED_FILL, 18),
			"focus": ThemeFactory._btn(SugarStreetColors.SOFT_PEACH, 18, true),
		}, SugarStreetColors.DARK_TEXT)
	b.pressed.connect(func():
		UiMotion.press_scale(b)
		cb.call()
	)
	parent.add_child(b)
	return b


func _on_play() -> void:
	AudioManager.play_button()
	if GameState.has_valid_save():
		GameState.continue_game()
	elif not GameState.has_save():
		GameState.save_now()
	SceneRouter.go_shop()


func _on_continue() -> void:
	AudioManager.play_button()
	if not GameState.has_valid_save():
		_refresh_continue()
		return
	GameState.continue_game()
	SceneRouter.go_shop()


func _on_new_game() -> void:
	AudioManager.play_button()
	_confirm.show_confirm("Start New Game?", "This resets starter progress. Settings are preserved.", "New Game", "Cancel")
	if not _confirm.confirmed.is_connected(_do_new_game):
		_confirm.confirmed.connect(_do_new_game, CONNECT_ONE_SHOT)


func _do_new_game() -> void:
	GameState.new_game()
	SceneRouter.go_shop()


func _on_settings() -> void:
	AudioManager.play_button()
	_settings.call("show_settings")


func _on_exit() -> void:
	AudioManager.play_button()
	if _is_desktop_exit_supported():
		GameState.save_now()
		get_tree().quit()


func _is_desktop_exit_supported() -> bool:
	var name := OS.get_name()
	return name in ["Windows", "macOS", "Linux", "FreeBSD", "NetBSD", "OpenBSD"]
