class_name RewardPopup
extends Control

signal continue_pressed

var _title: Label
var _body: Label
var _button: Button
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
	_panel.custom_minimum_size = Vector2(340, 380)
	center.add_child(_panel)
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 18)
	_panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 26)
	_title.text = "Order completed"
	vbox.add_child(_title)
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_body)
	_button = Button.new()
	_button.text = "Continue"
	_button.custom_minimum_size = Vector2(0, 48)
	_button.pressed.connect(func():
		hide_popup()
		continue_pressed.emit()
	)
	vbox.add_child(_button)


func show_rewards(rewards: Dictionary) -> void:
	var ingredients := ""
	var ings: Dictionary = rewards.get("ingredients", {})
	for k in ings.keys():
		ingredients += "\n• %s x%d" % [str(k).replace("_", " ").capitalize(), int(ings[k])]
	_body.text = "Customer: %s\nRecipe: %s\n\nCoins: +%s\nExperience: +%d\nReputation: +%d\nStars: +%d%s" % [
		str(rewards.get("customer_name", "")),
		str(rewards.get("recipe_name", "")),
		RewardCalculator.format_coins(int(rewards.get("coins", 0))),
		int(rewards.get("experience", 0)),
		int(rewards.get("reputation", 0)),
		int(rewards.get("stars", 0)),
		ingredients,
	]
	visible = true
	_panel.scale = Vector2(0.9, 0.9)
	_panel.pivot_offset = _panel.size * 0.5
	var tween := create_tween()
	tween.tween_property(_panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	AudioManager.play_popup()


func hide_popup() -> void:
	visible = false
