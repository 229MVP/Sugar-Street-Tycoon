class_name TutorialOverlay
extends Control
## Reusable full-screen tutorial step overlay. Blocks taps to whatever is
## underneath (mouse_filter = STOP + full-rect dim) so a player can't
## accidentally interact with the screen mid-explanation. Any screen can
## instantiate one, call show_step(), and listen for next_pressed/skip_pressed.

signal next_pressed
signal skip_pressed

var _title: Label
var _body: Label
var _next_btn: Button
var _skip_btn: Button
var _confirm: ConfirmPopup


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.07, 0.08, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(330, 0)
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
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_title)

	_body = Label.new()
	_body.add_theme_font_size_override("font_size", 14)
	_body.add_theme_color_override("font_color", Color(0.4, 0.3, 0.24))
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_body)

	_next_btn = Button.new()
	_next_btn.text = "Got It"
	_next_btn.custom_minimum_size = Vector2(0, 48)
	vbox.add_child(_next_btn)
	_next_btn.pressed.connect(_on_next)

	_skip_btn = Button.new()
	_skip_btn.text = "Skip Tutorial"
	_skip_btn.custom_minimum_size = Vector2(0, 40)
	_skip_btn.flat = true
	vbox.add_child(_skip_btn)
	_skip_btn.pressed.connect(_on_skip)

	_confirm = ConfirmPopup.new()
	add_child(_confirm)


func show_step(title: String, body: String) -> void:
	_title.text = title
	_body.text = body
	visible = true
	AudioManager.play_popup()


func _on_next() -> void:
	visible = false
	next_pressed.emit()


func _on_skip() -> void:
	_confirm.show_confirm(
		"Skip Tutorial?",
		"You can always explore the game on your own — this can be re-enabled from developer tools.",
		"Skip",
		"Keep Going"
	)
	if not _confirm.confirmed.is_connected(_do_skip):
		_confirm.confirmed.connect(_do_skip, CONNECT_ONE_SHOT)


func _do_skip() -> void:
	visible = false
	skip_pressed.emit()
