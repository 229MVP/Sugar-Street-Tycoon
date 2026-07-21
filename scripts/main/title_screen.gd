extends Control
## Polished bakery title screen matching the Sugar Street Figma design.


@onready var root_host: Control = %RootHost

var _confirm: ConfirmPopup
var _play_button: Button
var _logo: Control


func _ready() -> void:
	theme = ThemeFactory.build()
	_build_ui()
	AudioManager.play(AudioManager.Sfx.SHOP_OPENED)


func _build_ui() -> void:
	for c in root_host.get_children():
		c.queue_free()

	var bg := ColorRect.new()
	bg.color = SugarStreetColors.WARM_CREAM
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_host.add_child(bg)

	# Soft sky / bakery outdoor bands (placeholder for title_background.png).
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
	bakery_label.text = "🥐  My Bakery  🧁"
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
	_icon_btn(top_row, "⚙️", _on_settings)
	var top_spacer := Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(top_spacer)
	_icon_btn(top_row, "🏆", func(): _coming_soon("Trophies"))
	_icon_btn(top_row, "❤️", func(): _coming_soon("Favorites"))

	_logo = VBoxContainer.new()
	vbox.add_child(_logo)
	var brand := Label.new()
	brand.text = "Sugar Street"
	brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	brand.add_theme_font_size_override("font_size", 36)
	brand.add_theme_color_override("font_color", SugarStreetColors.BAKERY_BROWN)
	_logo.add_child(brand)
	var tycoon := Label.new()
	tycoon.text = "TYCOON"
	tycoon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tycoon.add_theme_font_size_override("font_size", 42)
	tycoon.add_theme_color_override("font_color", SugarStreetColors.CORAL_PINK)
	_logo.add_child(tycoon)
	var subtitle := Label.new()
	subtitle.text = "MATCH & BUILD"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", SugarStreetColors.WOOD_BROWN)
	_logo.add_child(subtitle)
	var tagline := Label.new()
	tagline.text = "Bake · Build · Bloom"
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.add_theme_font_size_override("font_size", 14)
	tagline.add_theme_color_override("font_color", SugarStreetColors.DARK_TEXT)
	_logo.add_child(tagline)

	# Logo entrance.
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
	_play_button.text = "PLAY"
	_play_button.custom_minimum_size = Vector2(0, 56)
	ThemeFactory.apply_button_styles(_play_button, ThemeFactory.primary_button_styles())
	_play_button.add_theme_font_size_override("font_size", 24)
	_play_button.pressed.connect(_on_play)
	vbox.add_child(_play_button)
	call_deferred("_pulse_play")

	_menu_btn(vbox, "Continue", _on_continue, false)
	_menu_btn(vbox, "New Game", _on_new_game, false)
	_menu_btn(vbox, "Settings", _on_settings, true)

	var sign_in := Button.new()
	sign_in.text = "f  Sign in with Facebook"
	sign_in.custom_minimum_size = Vector2(0, 44)
	ThemeFactory.apply_button_styles(sign_in, {
		"normal": ThemeFactory._btn(Color(0.25, 0.4, 0.75), 14),
		"hover": ThemeFactory._btn(Color(0.3, 0.45, 0.8), 14),
		"pressed": ThemeFactory._btn(Color(0.2, 0.35, 0.65), 14),
		"disabled": ThemeFactory._btn(SugarStreetColors.DISABLED_FILL, 14),
		"focus": ThemeFactory._btn(Color(0.25, 0.4, 0.75), 14, true),
	})
	sign_in.pressed.connect(func(): _coming_soon("Sign in"))
	vbox.add_child(sign_in)

	var version := Label.new()
	version.text = "v%s · placeholder art" % str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version.add_theme_font_size_override("font_size", 12)
	version.add_theme_color_override("font_color", SugarStreetColors.WOOD_BROWN)
	vbox.add_child(version)

	_confirm = ConfirmPopup.new()
	root_host.add_child(_confirm)


func _pulse_play() -> void:
	UiMotion.pulse(_play_button, 1.04, 0.9)


func _spawn_particles(host: Control) -> void:
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


func _menu_btn(parent: Control, text: String, cb: Callable, secondary: bool) -> void:
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
		_confirm.show_confirm("Start New Game?", "This resets starter progress. Continue?", "New Game", "Cancel")
		if not _confirm.confirmed.is_connected(_do_new_game):
			_confirm.confirmed.connect(_do_new_game, CONNECT_ONE_SHOT)
	else:
		_do_new_game()


func _do_new_game() -> void:
	GameState.new_game()
	SceneRouter.go_shop()


func _on_settings() -> void:
	AudioManager.play_button()
	_confirm.show_confirm("Settings", "Music and SFX toggles expand here. Audio uses AudioManager.", "OK", "Close")


func _coming_soon(feature: String) -> void:
	AudioManager.play_button()
	_confirm.show_confirm("Coming Soon", "%s will unlock in a later update." % feature, "OK", "Close")
