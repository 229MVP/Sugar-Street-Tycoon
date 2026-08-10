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
var _notifications_check: CheckButton
var _confirm: ConfirmPopup
var _info: ConfirmPopup
var _busy: bool = false


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.color = Color(0.12, 0.08, 0.1, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var safe := SafeAreaContainer.new()
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe.set_min_margins(12, 12, 12, 12)
	add_child(safe)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(320, 560)
	panel.add_theme_stylebox_override("panel", ThemeFactory._card(SugarStreetColors.SOFT_IVORY, 18))
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	margin.add_child(outer)

	var title := Label.new()
	title.text = "Settings"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", SugarStreetColors.BAKERY_BROWN)
	outer.add_child(title)

	# Scrollable body — keeps Reset/Close reachable even on short screens
	# regardless of how many settings rows this panel grows to.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ScrollHelper.configure_vertical(scroll)
	outer.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(vbox)

	_music_check = CheckButton.new()
	_music_check.text = "Music"
	ThemeFactory.apply_check_button_styles(_music_check)
	vbox.add_child(_music_check)
	_music_slider = _labeled_slider(vbox, "Music Volume")

	_sfx_check = CheckButton.new()
	_sfx_check.text = "Sound Effects"
	ThemeFactory.apply_check_button_styles(_sfx_check)
	vbox.add_child(_sfx_check)
	_sfx_slider = _labeled_slider(vbox, "SFX Volume")

	_vibration_check = CheckButton.new()
	_vibration_check.text = "Vibration"
	ThemeFactory.apply_check_button_styles(_vibration_check)
	vbox.add_child(_vibration_check)

	_motion_check = CheckButton.new()
	_motion_check.text = "Reduce Motion"
	ThemeFactory.apply_check_button_styles(_motion_check)
	vbox.add_child(_motion_check)

	_notifications_check = CheckButton.new()
	_notifications_check.text = "Notifications"
	ThemeFactory.apply_check_button_styles(_notifications_check)
	vbox.add_child(_notifications_check)

	vbox.add_child(HSeparator.new())

	var language_row := HBoxContainer.new()
	vbox.add_child(language_row)
	var language_label := Label.new()
	language_label.text = "Language"
	language_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	language_label.add_theme_color_override("font_color", SugarStreetColors.WOOD_BROWN)
	language_row.add_child(language_label)
	var language_value := Label.new()
	language_value.text = "English"
	language_value.add_theme_color_override("font_color", SugarStreetColors.DARK_TEXT)
	language_row.add_child(language_value)

	var privacy_btn := Button.new()
	privacy_btn.text = "Privacy Policy"
	privacy_btn.custom_minimum_size = Vector2(0, 44)
	ThemeFactory.apply_button_styles(privacy_btn, ThemeFactory.soft_button_styles(), SugarStreetColors.BAKERY_BROWN)
	privacy_btn.pressed.connect(_on_privacy_pressed)
	vbox.add_child(privacy_btn)

	var support_btn := Button.new()
	support_btn.text = "Support"
	support_btn.custom_minimum_size = Vector2(0, 44)
	ThemeFactory.apply_button_styles(support_btn, ThemeFactory.soft_button_styles(), SugarStreetColors.BAKERY_BROWN)
	support_btn.pressed.connect(_on_support_pressed)
	vbox.add_child(support_btn)

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
	outer.add_child(close_btn)

	_confirm = ConfirmPopup.new()
	add_child(_confirm)
	_info = ConfirmPopup.new()
	add_child(_info)


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
	_busy = false
	_load_from_state()
	ModalLayer.present(self)
	var audio := get_node_or_null("/root/AudioManager")
	if audio:
		audio.play_popup()
	FeatureTipPresenter.maybe_show(self, "settings")


func hide_popup() -> void:
	ModalLayer.dismiss(self)
	visible = false
	_busy = false


## Android Back is a user dismissal just like the Close button. Persist the
## values before closing so a toggle cannot appear to revert on reopen.
func request_close_from_back() -> void:
	_commit_and_close()


func _load_from_state() -> void:
	var gs := get_node_or_null("/root/GameState")
	if gs == null:
		return
	var s: Dictionary = gs.data.settings
	_music_check.button_pressed = bool(s.get("music_enabled", true))
	_sfx_check.button_pressed = bool(s.get("sfx_enabled", true))
	_music_slider.value = float(s.get("music_volume", 0.8))
	_sfx_slider.value = float(s.get("sfx_volume", 0.9))
	_vibration_check.button_pressed = bool(s.get("vibration", true))
	_motion_check.button_pressed = bool(s.get("reduce_motion", false))
	_notifications_check.button_pressed = gs.data.notification_preference == "enabled"


func _on_close() -> void:
	_commit_and_close()


func _commit_and_close() -> void:
	if _busy:
		return
	_busy = true
	var gs := get_node_or_null("/root/GameState")
	if gs:
		gs.update_settings({
			"music_enabled": _music_check.button_pressed,
			"sfx_enabled": _sfx_check.button_pressed,
			"music_volume": _music_slider.value,
			"sfx_volume": _sfx_slider.value,
			"vibration": _vibration_check.button_pressed,
			"reduce_motion": _motion_check.button_pressed,
		})
		gs.data.notification_preference = "enabled" if _notifications_check.button_pressed else "disabled"
		gs.save_now()
	hide_popup()
	closed.emit()


func _on_privacy_pressed() -> void:
	var audio := get_node_or_null("/root/AudioManager")
	if audio:
		audio.play_button()
	_info.show_confirm(
		"Privacy Policy",
		"Sugar Street Tycoon is a beta build. A full privacy policy will be published before public release. This build stores progress only on your device.",
		"OK", "OK"
	)


func _on_support_pressed() -> void:
	var audio := get_node_or_null("/root/AudioManager")
	if audio:
		audio.play_button()
	_info.show_confirm(
		"Support",
		"Thanks for testing Sugar Street Tycoon! Please report bugs and feedback through your TestFlight invite.",
		"OK", "OK"
	)


func _on_reset_pressed() -> void:
	var audio := get_node_or_null("/root/AudioManager")
	if audio:
		audio.play_button()
	_confirm.show_confirm(
		"Reset Save Data?",
		"This erases shop progress and returns you to starter values. Settings can be kept.",
		"Reset",
		"Cancel"
	)
	if not _confirm.confirmed.is_connected(_do_reset):
		_confirm.confirmed.connect(_do_reset, CONNECT_ONE_SHOT)


func _do_reset() -> void:
	var gs := get_node_or_null("/root/GameState")
	if gs:
		gs.reset_save()
	reset_confirmed.emit()
	_load_from_state()
