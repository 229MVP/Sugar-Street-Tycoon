class_name LevelUpPopup
extends Control

signal continue_pressed

var _title: Label
var _body: Label
var _button: Button


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
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(320, 260)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 18)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 28)
	_title.text = "Level Up!"
	vbox.add_child(_title)
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_body)
	_button = Button.new()
	_button.text = "Continue"
	_button.custom_minimum_size = Vector2(0, 48)
	_button.pressed.connect(func():
		hide_popup()
		continue_pressed.emit()
	)
	vbox.add_child(_button)


func show_level_up(new_level: int, coin_reward: int, features: String) -> void:
	_body.text = "New player level: %d\nCoin reward: +%s\n\n%s" % [
		new_level,
		RewardCalculator.format_coins(coin_reward),
		features,
	]
	visible = true
	AudioManager.play_popup()


func hide_popup() -> void:
	visible = false
