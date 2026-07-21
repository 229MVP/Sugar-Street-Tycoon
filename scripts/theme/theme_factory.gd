class_name ThemeFactory
extends RefCounted
## Builds the Sugar Street bakery Theme at runtime.


static func build() -> Theme:
	var theme := Theme.new()
	theme.set_default_font_size(16)
	theme.set_color("font_color", "Label", SugarStreetColors.DARK_TEXT)
	theme.set_color("font_color", "Button", SugarStreetColors.DARK_TEXT)
	theme.set_color("font_hover_color", "Button", SugarStreetColors.DARK_TEXT)
	theme.set_color("font_pressed_color", "Button", SugarStreetColors.DARK_TEXT)
	theme.set_color("font_disabled_color", "Button", SugarStreetColors.DISABLED_TEXT)
	theme.set_color("font_focus_color", "Button", SugarStreetColors.DARK_TEXT)

	theme.set_stylebox("normal", "Button", _btn(SugarStreetColors.SOFT_PEACH, 16))
	theme.set_stylebox("hover", "Button", _btn(SugarStreetColors.SOFT_PEACH.lightened(0.08), 16))
	theme.set_stylebox("pressed", "Button", _btn(SugarStreetColors.SOFT_PEACH.darkened(0.08), 16))
	theme.set_stylebox("disabled", "Button", _btn(SugarStreetColors.DISABLED_FILL, 16))
	theme.set_stylebox("focus", "Button", _btn(SugarStreetColors.SOFT_PEACH, 16, true))

	theme.set_stylebox("panel", "PanelContainer", _card(SugarStreetColors.SOFT_IVORY, 18))
	theme.set_stylebox("panel", "Panel", _card(SugarStreetColors.SOFT_IVORY, 18))

	theme.set_stylebox("panel", "PopupPanel", _card(SugarStreetColors.SOFT_IVORY, 20))

	theme.set_color("font_color", "ProgressBar", SugarStreetColors.DARK_TEXT)
	theme.set_stylebox("background", "ProgressBar", _bar_bg())
	theme.set_stylebox("fill", "ProgressBar", _bar_fill(SugarStreetColors.GOLDEN_YELLOW))

	return theme


static func primary_button_styles() -> Dictionary:
	return {
		"normal": _btn(SugarStreetColors.MINT_GREEN, 20),
		"hover": _btn(SugarStreetColors.MINT_GREEN.lightened(0.1), 20),
		"pressed": _btn(SugarStreetColors.MINT_GREEN.darkened(0.1), 20),
		"disabled": _btn(SugarStreetColors.DISABLED_FILL, 20),
		"focus": _btn(SugarStreetColors.MINT_GREEN, 20, true),
	}


static func secondary_button_styles() -> Dictionary:
	return {
		"normal": _btn(SugarStreetColors.CORAL_PINK, 18),
		"hover": _btn(SugarStreetColors.CORAL_PINK.lightened(0.08), 18),
		"pressed": _btn(SugarStreetColors.CORAL_PINK.darkened(0.08), 18),
		"disabled": _btn(SugarStreetColors.DISABLED_FILL, 18),
		"focus": _btn(SugarStreetColors.CORAL_PINK, 18, true),
	}


static func coral_header_style() -> StyleBoxFlat:
	return _btn(SugarStreetColors.CORAL_PINK, 16, false, false)


static func wood_panel_style() -> StyleBoxFlat:
	var s := _card(SugarStreetColors.WOOD_BROWN, 14)
	s.bg_color = SugarStreetColors.WOOD_BROWN
	return s


static func apply_button_styles(button: Button, styles: Dictionary, font_color: Color = SugarStreetColors.WHITE) -> void:
	for key in styles.keys():
		button.add_theme_stylebox_override(str(key), styles[key])
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", font_color)
	button.add_theme_color_override("font_pressed_color", font_color)
	button.add_theme_color_override("font_focus_color", font_color)
	button.add_theme_color_override("font_disabled_color", SugarStreetColors.DISABLED_TEXT)
	button.custom_minimum_size = Vector2(maxi(int(button.custom_minimum_size.x), 44), maxi(int(button.custom_minimum_size.y), 44))


static func _btn(fill: Color, radius: int, focused: bool = false, shadow: bool = true) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.set_corner_radius_all(radius)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	if shadow:
		s.shadow_color = SugarStreetColors.SHADOW
		s.shadow_size = 5
		s.shadow_offset = Vector2(0, 3)
	if focused:
		s.border_width_left = 2
		s.border_width_top = 2
		s.border_width_right = 2
		s.border_width_bottom = 2
		s.border_color = SugarStreetColors.GOLDEN_YELLOW
	s.border_width_top = maxi(s.border_width_top, 1)
	s.border_color = Color(1, 1, 1, 0.35) if s.border_width_left == 0 else s.border_color
	return s


static func _card(fill: Color, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.set_corner_radius_all(radius)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	s.border_width_left = 1
	s.border_width_top = 1
	s.border_width_right = 1
	s.border_width_bottom = 1
	s.border_color = SugarStreetColors.SOFT_BORDER
	s.shadow_color = SugarStreetColors.SHADOW
	s.shadow_size = 8
	s.shadow_offset = Vector2(0, 4)
	return s


static func _bar_bg() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = SugarStreetColors.SOFT_PEACH
	s.set_corner_radius_all(10)
	return s


static func _bar_fill(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(10)
	return s
