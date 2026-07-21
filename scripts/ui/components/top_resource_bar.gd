class_name TopResourceBar
extends Control
## Shared top bar: level, energy, coins, stars, menu.


signal menu_pressed

var level_label: Label
var energy_label: Label
var coins_label: Label
var stars_label: Label
var menu_button: Button


func _ready() -> void:
	custom_minimum_size = Vector2(0, 52)
	_build()
	_connect_state()
	refresh()


func _build() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style := ThemeFactory._card(SugarStreetColors.SOFT_IVORY, 16)
	style.content_margin_left = 10
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)

	level_label = _chip(row, "Lv")
	energy_label = _chip(row, "⚡")
	coins_label = _chip(row, "🪙")
	stars_label = _chip(row, "★")

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	menu_button = Button.new()
	menu_button.text = "☰"
	menu_button.custom_minimum_size = Vector2(44, 44)
	ThemeFactory.apply_button_styles(menu_button, ThemeFactory.secondary_button_styles())
	menu_button.pressed.connect(func():
		UiMotion.press_scale(menu_button)
		menu_pressed.emit()
	)
	row.add_child(menu_button)


func _chip(parent: HBoxContainer, prefix: String) -> Label:
	var wrap := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = SugarStreetColors.WARM_CREAM
	s.set_corner_radius_all(12)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	s.border_color = SugarStreetColors.SOFT_BORDER
	s.border_width_left = 1
	s.border_width_top = 1
	s.border_width_right = 1
	s.border_width_bottom = 1
	wrap.add_theme_stylebox_override("panel", s)
	parent.add_child(wrap)
	var label := Label.new()
	label.text = prefix
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", SugarStreetColors.DARK_TEXT)
	label.set_meta("prefix", prefix)
	wrap.add_child(label)
	return label


func _connect_state() -> void:
	if GameState.state_changed.is_connected(refresh):
		return
	GameState.state_changed.connect(refresh)
	GameState.coins_changed.connect(func(_v): refresh())
	GameState.stars_changed.connect(func(_v): refresh())
	GameState.experience_changed.connect(func(_a, _b, _c): refresh())


func refresh() -> void:
	if GameState.data == null:
		return
	var d := GameState.data
	level_label.text = "Lv %d" % d.player_level
	energy_label.text = "⚡ 20"
	coins_label.text = "🪙 %s" % RewardCalculator.format_coins(d.coins)
	stars_label.text = "★ %d" % d.stars
