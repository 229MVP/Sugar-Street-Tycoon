class_name TopResourceBar
extends Control
## Shared top bar: level, XP, coins, stars, reputation, menu.


signal menu_pressed

var level_label: Label
var xp_bar: ProgressBar
var coins_label: Label
var stars_label: Label
var reputation_label: Label
var menu_button: Button


func _ready() -> void:
	custom_minimum_size = Vector2(0, 58)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build()
	_connect_state()
	refresh()


func _build() -> void:
	for c in get_children():
		c.queue_free()
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := ThemeFactory._card(SugarStreetColors.SOFT_IVORY, 16)
	style.content_margin_left = 8
	style.content_margin_right = 6
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	panel.add_child(col)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	col.add_child(row)

	level_label = _chip(row, "Lv 1")
	coins_label = _chip(row, "Coins 0")
	stars_label = _chip(row, "Stars 0")
	reputation_label = _chip(row, "Rep 0")

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	menu_button = Button.new()
	menu_button.text = "Menu"
	menu_button.custom_minimum_size = Vector2(56, 44)
	ThemeFactory.apply_button_styles(menu_button, ThemeFactory.secondary_button_styles())
	menu_button.add_theme_font_size_override("font_size", 13)
	menu_button.pressed.connect(func():
		UiMotion.press_scale(menu_button)
		menu_pressed.emit()
	)
	row.add_child(menu_button)

	xp_bar = ProgressBar.new()
	xp_bar.custom_minimum_size = Vector2(0, 12)
	xp_bar.show_percentage = false
	xp_bar.min_value = 0
	xp_bar.max_value = 100
	xp_bar.value = 0
	col.add_child(xp_bar)


func _chip(parent: HBoxContainer, text: String) -> Label:
	var wrap := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = SugarStreetColors.WARM_CREAM
	s.set_corner_radius_all(12)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	s.set_border_width_all(1)
	s.border_color = SugarStreetColors.SOFT_BORDER
	wrap.add_theme_stylebox_override("panel", s)
	parent.add_child(wrap)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", SugarStreetColors.DARK_TEXT)
	wrap.add_child(label)
	return label


func _connect_state() -> void:
	if GameState.state_changed.is_connected(refresh):
		return
	GameState.state_changed.connect(refresh)
	GameState.coins_changed.connect(func(_v): refresh())
	GameState.stars_changed.connect(func(_v): refresh())
	GameState.reputation_changed.connect(func(_v): refresh())
	GameState.experience_changed.connect(func(_a, _b, _c): refresh())
	GameState.player_level_changed.connect(func(_v): refresh())


func refresh() -> void:
	if level_label == null or GameState.data == null:
		return
	var d := GameState.data
	var need := PlayerProgression.xp_required_for_next_level(d.player_level)
	level_label.text = "Lv %d" % d.player_level
	coins_label.text = "Coins %s" % RewardCalculator.format_coins(d.coins)
	stars_label.text = "Stars %d" % d.stars
	reputation_label.text = "Rep %d" % d.reputation
	xp_bar.max_value = maxf(float(need), 1.0)
	xp_bar.value = float(clampi(d.experience, 0, need))
	xp_bar.tooltip_text = "XP %d / %d" % [d.experience, need]
