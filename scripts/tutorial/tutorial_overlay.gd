class_name TutorialOverlay
extends Control
## Full-screen tutorial step overlay. Presented via ModalLayer so it always
## sits above screen content and navigation.

signal next_pressed
signal skip_pressed

var _title: Label
var _body: Label
var _next_btn: Button
var _skip_btn: Button
var _confirm: ConfirmPopup
var _allow_skip: bool = true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.07, 0.08, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var safe := SafeAreaContainer.new()
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe.set_min_margins(16, 20, 16, 20)
	add_child(safe)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(300, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 0.97, 0.93, 1)
	style.set_corner_radius_all(18)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 20)
	_title.add_theme_color_override("font_color", Color(0.35, 0.2, 0.12))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_title)

	_body = Label.new()
	_body.add_theme_font_size_override("font_size", 14)
	_body.add_theme_color_override("font_color", Color(0.4, 0.3, 0.24))
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_body)

	_next_btn = Button.new()
	_next_btn.text = "Got It"
	_next_btn.custom_minimum_size = Vector2(0, 48)
	ThemeFactory.apply_button_styles(_next_btn, ThemeFactory.primary_button_styles())
	vbox.add_child(_next_btn)
	_next_btn.pressed.connect(_on_next)

	_skip_btn = Button.new()
	_skip_btn.text = "Skip Tutorial"
	_skip_btn.custom_minimum_size = Vector2(0, 40)
	ThemeFactory.apply_button_styles(_skip_btn, ThemeFactory.soft_button_styles(), SugarStreetColors.BAKERY_BROWN)
	vbox.add_child(_skip_btn)
	_skip_btn.pressed.connect(_on_skip)

	_confirm = ConfirmPopup.new()
	add_child(_confirm)


func show_step(title: String, body: String, allow_skip: bool = true) -> void:
	_title.text = title
	_body.text = body
	_allow_skip = allow_skip
	_skip_btn.visible = allow_skip
	ModalLayer.present(self)
	var audio := get_node_or_null("/root/AudioManager")
	if audio:
		audio.play_popup()


func hide_popup() -> void:
	ModalLayer.dismiss(self)
	visible = false


func _on_next() -> void:
	hide_popup()
	next_pressed.emit()


func _on_skip() -> void:
	if not _allow_skip:
		return
	_confirm.show_confirm(
		"Skip Tutorial?",
		"You can explore the bakery on your own anytime. Skipping will not affect your progress or rewards.",
		"Skip",
		"Keep Going"
	)
	if not _confirm.confirmed.is_connected(_do_skip):
		_confirm.confirmed.connect(_do_skip, CONNECT_ONE_SHOT)


func _do_skip() -> void:
	hide_popup()
	skip_pressed.emit()
