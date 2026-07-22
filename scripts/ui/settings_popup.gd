class_name SettingsPopup
extends Control
## Functional settings: audio, vibration, reduce motion, reset save.


signal closed
signal reset_confirmed

var _music_slider: HSlider
var _sfx_slider: HSlider
var _music_check: CheckButton
var _sfx_check: CheckButton
var _vibration_check: CheckButton
var _motion_check: CheckButton
var _confirm: ConfirmPopup
var _busy: bool = false


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.color = Color(0.12, 0.08, 0.1, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(340, 480)
	panel.add_theme_stylebox_override("panel", ThemeFactory._card(SugarStreetColors.SOFT_IVORY, 18))
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Settings"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", SugarStreetColors.BAKERY_BROWN)
	vbox.add_child(title)

	_music_check = CheckButton.new()
	_music_check.text = "Music"
	vbox.add_child(_music_check)
	_music_slider = _labeled_slider(vbox, "Music Volume")

	_sfx_check = CheckButton.new()
	_sfx_check.text = "Sound Effects"
	vbox.add_child(_sfx_check)
	_sfx_slider = _labeled_slider(vbox, "SFX Volume")

	_vibration_check = CheckButton.new()
	_vibration_check.text = "Vibration"
	vbox.add_child(_vibration_check)

	_motion_check = CheckButton.new()
	_motion_check.text = "Reduce Motion"
	vbox.add_child(_motion_check)

	var reset_btn := Button.new()
	reset_btn.text = "Reset Save Data"
	reset_btn.custom_minimum_size = Vector2(0, 44)
	ThemeFactory.apply_button_styles(reset_btn, ThemeFactory.secondary_button_styles())
	reset_btn.pressed.connect(_on_reset_pressed)
	vbox.add_child(reset_btn)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(0, 48)
	ThemeFactory.apply_button_styles(close_btn, ThemeFactory.primary_button_styles())
	close_btn.pressed.connect(_on_close)
	vbox.add_child(close_btn)

	_confirm = ConfirmPopup.new()
	add_child(_confirm)


func _labeled_slider(parent: Control, label_text: String) -> HSlider:
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", SugarStreetColors.WOOD_BROWN)
	parent.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.custom_minimum_size = Vector2(0, 28)
	parent.add_child(slider)
	return slider


func show_settings() -> void:
	_load_from_state()
	visible = true
	AudioManager.play_popup()


func hide_popup() -> void:
	visible = false


func _load_from_state() -> void:
	var s: Dictionary = GameState.data.settings
	_music_check.button_pressed = bool(s.get("music_enabled", true))
	_sfx_check.button_pressed = bool(s.get("sfx_enabled", true))
	_music_slider.value = float(s.get("music_volume", 0.8))
	_sfx_slider.value = float(s.get("sfx_volume", 0.9))
	_vibration_check.button_pressed = bool(s.get("vibration", true))
	_motion_check.button_pressed = bool(s.get("reduce_motion", false))


func _on_close() -> void:
	if _busy:
		return
	_busy = true
	GameState.update_settings({
		"music_enabled": _music_check.button_pressed,
		"sfx_enabled": _sfx_check.button_pressed,
		"music_volume": _music_slider.value,
		"sfx_volume": _sfx_slider.value,
		"vibration": _vibration_check.button_pressed,
		"reduce_motion": _motion_check.button_pressed,
	})
	hide_popup()
	closed.emit()
	_busy = false


func _on_reset_pressed() -> void:
	AudioManager.play_button()
	_confirm.show_confirm(
		"Reset Save Data?",
		"This erases shop progress and returns you to starter values. Settings can be kept.",
		"Reset",
		"Cancel"
	)
	if not _confirm.confirmed.is_connected(_do_reset):
		_confirm.confirmed.connect(_do_reset, CONNECT_ONE_SHOT)


func _do_reset() -> void:
	GameState.reset_save()
	reset_confirmed.emit()
	_load_from_state()
