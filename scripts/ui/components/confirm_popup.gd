class_name ConfirmPopup
extends Control
## Generic yes/no confirmation overlay.

signal confirmed
signal cancelled

var _title: Label
var _body: Label
var _yes: Button
var _no: Button
var _panel: PanelContainer


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.08, 0.1, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(320, 200)
	center.add_child(_panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	_panel.add_child(vbox)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(_title)
	_body = Label.new()
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_body)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	vbox.add_child(row)
	_no = Button.new()
	_no.text = "Cancel"
	_no.custom_minimum_size = Vector2(120, 44)
	_no.pressed.connect(func():
		hide_popup()
		cancelled.emit()
	)
	row.add_child(_no)
	_yes = Button.new()
	_yes.text = "Confirm"
	_yes.custom_minimum_size = Vector2(120, 44)
	_yes.pressed.connect(func():
		hide_popup()
		confirmed.emit()
	)
	row.add_child(_yes)


func show_confirm(title: String, body: String, yes_text: String = "Confirm", no_text: String = "Cancel") -> void:
	_title.text = title
	_body.text = body
	_yes.text = yes_text
	_no.text = no_text
	visible = true
	AudioManager.play_popup()


func hide_popup() -> void:
	visible = false
