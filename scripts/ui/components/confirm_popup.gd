class_name ConfirmPopup
extends Control
## Generic yes/no confirmation overlay. Always presented through ModalLayer
## so it centers in the full viewport even when parented under a nav bar.

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
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.08, 0.1, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var safe := SafeAreaContainer.new()
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe.set_min_margins(12, 12, 12, 12)
	add_child(safe)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe.add_child(center)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(300, 180)
	_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	center.add_child(_panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	_panel.add_child(vbox)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 22)
	_title.add_theme_color_override("font_color", SugarStreetColors.BAKERY_BROWN)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_title)
	_body = Label.new()
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_color_override("font_color", SugarStreetColors.DARK_TEXT)
	vbox.add_child(_body)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	vbox.add_child(row)
	_no = Button.new()
	_no.text = "Cancel"
	_no.custom_minimum_size = Vector2(120, 44)
	ThemeFactory.apply_button_styles(_no, ThemeFactory.secondary_button_styles())
	_no.pressed.connect(_cancel)
	row.add_child(_no)
	_yes = Button.new()
	_yes.text = "Confirm"
	_yes.custom_minimum_size = Vector2(120, 44)
	ThemeFactory.apply_button_styles(_yes, ThemeFactory.primary_button_styles())
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
	# Same label for both buttons (info dialogs) → hide Cancel to avoid confusion.
	_no.visible = no_text.strip_edges() != yes_text.strip_edges()
	ModalLayer.present(self)
	var audio := _audio()
	if audio:
		audio.play_popup()


func hide_popup() -> void:
	ModalLayer.dismiss(self)
	visible = false


## Treat Android Back as the Cancel action, not as a silent hide. Callers use
## this signal to release busy locks and restore the underlying modal state.
func request_close_from_back() -> void:
	_cancel()


func _cancel() -> void:
	hide_popup()
	cancelled.emit()


func _audio() -> Node:
	return get_node_or_null("/root/AudioManager")
