extends Control
## Polished bakery title screen. Preserves Play / Continue / New Game / Settings / Exit behavior.

const SettingsPopupScene := preload("res://scripts/ui/settings_popup.gd")

var _confirm: ConfirmPopup
var _settings: Control
var _play_button: Button
var _continue_button: Button
var _continue_help: Label
var _logo: Control
var _bakery_preview: Control
var _exit_button: Button
var _reduce_motion: bool = false


func _ready() -> void:
	# Guardrail: this scene is the F5 entry point (project.godot run/main_scene).
	if OS.is_debug_build():
		var configured := str(ProjectSettings.get_setting("application/run/main_scene", ""))
		if configured != "res://scenes/main/title_screen.tscn":
			push_warning("TitleScreen: unexpected main_scene '%s'" % configured)
	theme = ThemeFactory.build()
	_reduce_motion = bool(GameState.data.settings.get("reduce_motion", false))
	_build_ui()
	_refresh_continue()
	AudioManager.play(AudioManager.Sfx.SHOP_OPENED)


func _build_ui() -> void:
	for c in get_children():
		c.queue_free()

	_build_background()
	_spawn_decorations()

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	margin.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(vbox)

	_logo = _build_logo()
	vbox.add_child(_logo)

	_bakery_preview = _build_bakery_preview()
	vbox.add_child(_bakery_preview)

	# Compact spacer — keeps bakery above buttons without huge empty sky.
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	vbox.add_child(spacer)

	_play_button = Button.new()
	_play_button.text = "Play"
	_play_button.custom_minimum_size = Vector2(0, 48)
	var play_styles := {
		"normal": _compact_btn(SugarStreetColors.MINT_GREEN, 16),
		"hover": _compact_btn(SugarStreetColors.MINT_GREEN.lightened(0.1), 16),
		"pressed": _compact_btn(SugarStreetColors.MINT_GREEN.darkened(0.1), 16),
		"disabled": _compact_btn(SugarStreetColors.DISABLED_FILL, 16),
		"focus": _compact_btn(SugarStreetColors.MINT_GREEN, 16, true),
	}
	ThemeFactory.apply_button_styles(_play_button, play_styles)
	_play_button.add_theme_font_size_override("font_size", 20)
	_play_button.pressed.connect(func():
		UiMotion.press_scale(_play_button)
		_on_play()
	)
	vbox.add_child(_play_button)
	call_deferred("_pulse_play")

	_continue_button = _secondary_btn("Continue", _on_continue, SugarStreetColors.SOFT_IVORY, SugarStreetColors.BAKERY_BROWN)
	vbox.add_child(_continue_button)
	_continue_help = Label.new()
	_continue_help.text = "No Save Found"
	_continue_help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_continue_help.add_theme_font_size_override("font_size", 11)
	_continue_help.add_theme_color_override("font_color", SugarStreetColors.WOOD_BROWN)
	_continue_help.visible = false
	vbox.add_child(_continue_help)

	var new_game := _secondary_btn("New Game", _on_new_game, SugarStreetColors.SOFT_PEACH, SugarStreetColors.BAKERY_BROWN)
	vbox.add_child(new_game)

	var util_row := HBoxContainer.new()
	util_row.add_theme_constant_override("separation", 10)
	vbox.add_child(util_row)
	var settings_btn := _secondary_btn("Settings", _on_settings, SugarStreetColors.CORAL_PINK, SugarStreetColors.WHITE, 44)
	settings_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	util_row.add_child(settings_btn)
	if _is_desktop_exit_supported():
		_exit_button = _secondary_btn("Exit", _on_exit, SugarStreetColors.WOOD_BROWN.lightened(0.15), SugarStreetColors.WHITE, 44)
		_exit_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		util_row.add_child(_exit_button)
	else:
		# Keep Settings full-width on mobile when Exit is hidden.
		pass

	var version := Label.new()
	version.text = "v%s · Development Build" % str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version.add_theme_font_size_override("font_size", 11)
	version.add_theme_color_override("font_color", SugarStreetColors.WOOD_BROWN)
	vbox.add_child(version)

	_confirm = ConfirmPopup.new()
	add_child(_confirm)
	_settings = SettingsPopupScene.new()
	add_child(_settings)

	_play_entrance_anims()


func _build_background() -> void:
	var cream := ColorRect.new()
	cream.color = SugarStreetColors.WARM_CREAM
	cream.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cream.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cream)

	# Soft sky band that blends into cream (no hard empty-blue / crowded-cream split).
	var sky_top := ColorRect.new()
	sky_top.color = Color(0.78, 0.90, 0.97, 1)
	sky_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	sky_top.anchor_bottom = 0.28
	sky_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sky_top)

	var sky_mid := ColorRect.new()
	sky_mid.color = Color(0.92, 0.94, 0.95, 0.55)
	sky_mid.set_anchors_preset(Control.PRESET_TOP_WIDE)
	sky_mid.anchor_top = 0.22
	sky_mid.anchor_bottom = 0.42
	sky_mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sky_mid)

	var peach_glow := ColorRect.new()
	peach_glow.color = Color(SugarStreetColors.SOFT_PEACH.r, SugarStreetColors.SOFT_PEACH.g, SugarStreetColors.SOFT_PEACH.b, 0.35)
	peach_glow.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	peach_glow.anchor_top = 0.72
	peach_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(peach_glow)


func _spawn_decorations() -> void:
	_add_cloud(Vector2(24, 36), 64)
	_add_cloud(Vector2(250, 28), 78)
	_add_cloud(Vector2(150, 70), 48)

	# Floating candy / sparkles stay in the decorative sky — not over buttons.
	var colors := [
		SugarStreetColors.CORAL_PINK,
		SugarStreetColors.GOLDEN_YELLOW,
		SugarStreetColors.MINT_GREEN,
		SugarStreetColors.STRAWBERRY_PINK,
	]
	for i in 8:
		var p := Panel.new()
		var style := StyleBoxFlat.new()
		style.bg_color = colors[i % colors.size()]
		style.set_corner_radius_all(20)
		p.add_theme_stylebox_override("panel", style)
		var sz := 10.0 + float(i % 3) * 3.0
		p.size = Vector2(sz, sz)
		p.custom_minimum_size = p.size
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.modulate.a = 0.55
		add_child(p)
		p.position = Vector2(16 + (i * 44) % 340, 24 + (i * 18) % 110)
		if _reduce_motion:
			continue
		var tween := create_tween().set_loops()
		tween.tween_property(p, "position:y", p.position.y - 10, 1.5 + float(i) * 0.05).set_trans(Tween.TRANS_SINE)
		tween.tween_property(p, "position:y", p.position.y + 6, 1.5 + float(i) * 0.05).set_trans(Tween.TRANS_SINE)

	_add_silhouette(Vector2(28, 100), "🍓", SugarStreetColors.STRAWBERRY_PINK)
	_add_silhouette(Vector2(330, 88), "🧁", SugarStreetColors.SOFT_PEACH)
	_add_sparkle(Vector2(190, 40))
	_add_sparkle(Vector2(70, 78))
	_add_sparkle(Vector2(310, 55))


func _add_cloud(pos: Vector2, width: float) -> void:
	var cloud := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.78)
	style.set_corner_radius_all(22)
	cloud.add_theme_stylebox_override("panel", style)
	cloud.position = pos
	cloud.size = Vector2(width, width * 0.42)
	cloud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cloud)


func _add_silhouette(pos: Vector2, symbol: String, tint: Color) -> void:
	var wrap := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(tint.r, tint.g, tint.b, 0.55)
	style.set_corner_radius_all(16)
	wrap.add_theme_stylebox_override("panel", style)
	wrap.position = pos
	wrap.custom_minimum_size = Vector2(36, 36)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wrap)
	var lbl := Label.new()
	lbl.text = symbol
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 18)
	wrap.add_child(lbl)


func _add_sparkle(pos: Vector2) -> void:
	var spark := Label.new()
	spark.text = "✦"
	spark.position = pos
	spark.add_theme_font_size_override("font_size", 14)
	spark.add_theme_color_override("font_color", SugarStreetColors.GOLDEN_YELLOW)
	spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spark.modulate.a = 0.7
	add_child(spark)
	if _reduce_motion:
		return
	var tween := create_tween().set_loops()
	tween.tween_property(spark, "modulate:a", 0.25, 0.8)
	tween.tween_property(spark, "modulate:a", 0.85, 0.8)


func _build_logo() -> Control:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 2)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	root.add_child(row)

	# Icon sits beside the title — never overlapping letters.
	var icon := PanelContainer.new()
	icon.custom_minimum_size = Vector2(44, 44)
	var istyle := StyleBoxFlat.new()
	istyle.bg_color = SugarStreetColors.STRAWBERRY_PINK
	istyle.set_corner_radius_all(22)
	istyle.shadow_color = SugarStreetColors.SHADOW
	istyle.shadow_size = 4
	istyle.shadow_offset = Vector2(0, 2)
	icon.add_theme_stylebox_override("panel", istyle)
	row.add_child(icon)
	var icon_lbl := Label.new()
	icon_lbl.text = "🍓"
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_size_override("font_size", 22)
	icon.add_child(icon_lbl)

	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 0)
	row.add_child(titles)

	var sugar := Label.new()
	sugar.text = "Sugar Street"
	sugar.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	sugar.add_theme_font_size_override("font_size", 26)
	sugar.add_theme_color_override("font_color", SugarStreetColors.CORAL_PINK)
	titles.add_child(sugar)

	var tycoon := Label.new()
	tycoon.text = "TYCOON"
	tycoon.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	tycoon.add_theme_font_size_override("font_size", 28)
	tycoon.add_theme_color_override("font_color", SugarStreetColors.BAKERY_BROWN)
	titles.add_child(tycoon)

	var ribbon := PanelContainer.new()
	var rstyle := StyleBoxFlat.new()
	rstyle.bg_color = SugarStreetColors.MINT_GREEN
	rstyle.set_corner_radius_all(14)
	rstyle.content_margin_left = 16
	rstyle.content_margin_right = 16
	rstyle.content_margin_top = 6
	rstyle.content_margin_bottom = 6
	ribbon.add_theme_stylebox_override("panel", rstyle)
	root.add_child(ribbon)
	var match_lbl := Label.new()
	match_lbl.text = "MATCH & BUILD"
	match_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	match_lbl.add_theme_font_size_override("font_size", 13)
	match_lbl.add_theme_color_override("font_color", SugarStreetColors.WHITE)
	ribbon.add_child(match_lbl)

	return root


func _build_bakery_preview() -> Control:
	var frame := PanelContainer.new()
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.custom_minimum_size = Vector2(0, 168)
	var fstyle := ThemeFactory._card(SugarStreetColors.SOFT_IVORY, 18)
	fstyle.shadow_size = 10
	fstyle.shadow_offset = Vector2(0, 5)
	fstyle.content_margin_left = 10
	fstyle.content_margin_right = 10
	fstyle.content_margin_top = 10
	fstyle.content_margin_bottom = 10
	frame.add_theme_stylebox_override("panel", fstyle)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	frame.add_child(root)

	# Pink-and-white striped awning
	var awning := HBoxContainer.new()
	awning.add_theme_constant_override("separation", 0)
	awning.custom_minimum_size = Vector2(0, 22)
	root.add_child(awning)
	for i in 10:
		var stripe := ColorRect.new()
		stripe.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stripe.custom_minimum_size = Vector2(0, 22)
		stripe.color = SugarStreetColors.CORAL_PINK if i % 2 == 0 else SugarStreetColors.WHITE
		stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
		awning.add_child(stripe)

	var building := HBoxContainer.new()
	building.add_theme_constant_override("separation", 8)
	building.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(building)

	# Flower pot left
	_add_flower_pot(building)

	# Main bakery body
	var body := PanelContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var bstyle := StyleBoxFlat.new()
	bstyle.bg_color = SugarStreetColors.WOOD_BROWN.lightened(0.18)
	bstyle.set_corner_radius_all(10)
	bstyle.set_border_width_all(2)
	bstyle.border_color = SugarStreetColors.BAKERY_BROWN
	body.add_theme_stylebox_override("panel", bstyle)
	building.add_child(body)

	var body_col := VBoxContainer.new()
	body_col.add_theme_constant_override("separation", 6)
	body.add_child(body_col)

	var sign := PanelContainer.new()
	var sstyle := StyleBoxFlat.new()
	sstyle.bg_color = SugarStreetColors.GOLDEN_YELLOW
	sstyle.set_corner_radius_all(8)
	sstyle.content_margin_top = 4
	sstyle.content_margin_bottom = 4
	sign.add_theme_stylebox_override("panel", sstyle)
	body_col.add_child(sign)
	var sign_lbl := Label.new()
	sign_lbl.text = "My Bakery"
	sign_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign_lbl.add_theme_font_size_override("font_size", 13)
	sign_lbl.add_theme_color_override("font_color", SugarStreetColors.BAKERY_BROWN)
	sign.add_child(sign_lbl)

	var mid := HBoxContainer.new()
	mid.add_theme_constant_override("separation", 8)
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_col.add_child(mid)

	# Warm glowing window + dessert display
	var window := PanelContainer.new()
	window.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	window.custom_minimum_size = Vector2(0, 64)
	var wstyle := StyleBoxFlat.new()
	wstyle.bg_color = Color(1.0, 0.95, 0.75, 1) # warm window glow
	wstyle.set_corner_radius_all(8)
	wstyle.set_border_width_all(2)
	wstyle.border_color = SugarStreetColors.BAKERY_BROWN
	window.add_theme_stylebox_override("panel", wstyle)
	mid.add_child(window)
	var desserts := Label.new()
	desserts.text = "🧁  🍓  🍩"
	desserts.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desserts.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	desserts.add_theme_font_size_override("font_size", 18)
	window.add_child(desserts)

	# Wooden door
	var door := PanelContainer.new()
	door.custom_minimum_size = Vector2(44, 64)
	var dstyle := StyleBoxFlat.new()
	dstyle.bg_color = SugarStreetColors.BAKERY_BROWN
	dstyle.set_corner_radius_all(6)
	door.add_theme_stylebox_override("panel", dstyle)
	mid.add_child(door)
	var knob := Label.new()
	knob.text = "•"
	knob.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	knob.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	knob.add_theme_color_override("font_color", SugarStreetColors.GOLDEN_YELLOW)
	knob.add_theme_font_size_override("font_size", 18)
	door.add_child(knob)

	_add_flower_pot(building)
	return frame


func _add_flower_pot(parent: Control) -> void:
	var pot := VBoxContainer.new()
	pot.custom_minimum_size = Vector2(28, 0)
	pot.alignment = BoxContainer.ALIGNMENT_END
	parent.add_child(pot)
	var bloom := Label.new()
	bloom.text = "🌸"
	bloom.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bloom.add_theme_font_size_override("font_size", 14)
	pot.add_child(bloom)
	var base := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = SugarStreetColors.CORAL_PINK.darkened(0.1)
	style.set_corner_radius_all(4)
	base.add_theme_stylebox_override("panel", style)
	base.custom_minimum_size = Vector2(22, 18)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pot.add_child(base)


func _secondary_btn(text: String, cb: Callable, fill: Color, font_color: Color, height: float = 44) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, height)
	ThemeFactory.apply_button_styles(b, {
		"normal": _compact_btn(fill, 14),
		"hover": _compact_btn(fill.lightened(0.08), 14),
		"pressed": _compact_btn(fill.darkened(0.08), 14),
		"disabled": _compact_btn(SugarStreetColors.DISABLED_FILL, 14),
		"focus": _compact_btn(fill, 14, true),
	}, font_color)
	b.add_theme_font_size_override("font_size", 15)
	b.pressed.connect(func():
		UiMotion.press_scale(b)
		cb.call()
	)
	return b


func _compact_btn(fill: Color, radius: int, focused: bool = false) -> StyleBoxFlat:
	var s := ThemeFactory._btn(fill, radius, focused, true)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	s.shadow_size = 4
	s.shadow_offset = Vector2(0, 2)
	return s


func _play_entrance_anims() -> void:
	if _reduce_motion:
		return
	_logo.modulate.a = 0.0
	_logo.position.y = -16
	_bakery_preview.modulate.a = 0.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_logo, "modulate:a", 1.0, 0.4)
	tween.tween_property(_logo, "position:y", 0.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_bakery_preview, "modulate:a", 1.0, 0.5).set_delay(0.12)


func _pulse_play() -> void:
	if _reduce_motion or _play_button == null:
		return
	UiMotion.pulse(_play_button, 1.03, 1.0)


func _refresh_continue() -> void:
	if _continue_button == null:
		return
	var has_save := GameState.has_valid_save()
	_continue_button.disabled = not has_save
	if _continue_help:
		_continue_help.visible = not has_save


# ---------------------------------------------------------------------------
# Preserved button behavior (do not change navigation / save logic)
# ---------------------------------------------------------------------------

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
