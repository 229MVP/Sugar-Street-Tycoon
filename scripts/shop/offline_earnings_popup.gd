class_name OfflineEarningsPopup
extends Control

signal collected

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
	panel.custom_minimum_size = Vector2(340, 320)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 16)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	var title := Label.new()
	title.text = "Welcome back!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	vbox.add_child(title)
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_body)
	_button = Button.new()
	_button.text = "Collect"
	_button.custom_minimum_size = Vector2(0, 48)
	_button.pressed.connect(_on_collect)
	vbox.add_child(_button)


func show_payload(payload: Dictionary) -> void:
	if payload.is_empty() or not payload.get("ok", true):
		# Still show if applied_coins present from storage apply.
		if int(payload.get("total_coins", 0)) <= 0 and int(payload.get("applied_coins", 0)) <= 0:
			return
	var secs := int(payload.get("elapsed_seconds", 0))
	var mins := secs / 60
	var hours := mins / 60
	var mins_rem := mins % 60
	var time_text := "%dh %dm" % [hours, mins_rem] if hours > 0 else "%d minutes" % maxi(mins, 1)
	_body.text = "Time away: %s\n\nBase income: %s\nEquipment bonus: %s\nWorker bonus: %s\n\nTotal ready to collect: %s\n(Added to walk-in storage)" % [
		time_text,
		RewardCalculator.format_coins(int(payload.get("base_income", 0))),
		RewardCalculator.format_coins(int(payload.get("equipment_bonus_coins", 0))),
		RewardCalculator.format_coins(int(payload.get("worker_bonus_coins", 0))),
		RewardCalculator.format_coins(int(payload.get("applied_coins", payload.get("total_coins", 0)))),
	]
	visible = true
	AudioManager.play(AudioManager.Sfx.OFFLINE_EARNINGS)
	AudioManager.play_popup()


func _on_collect() -> void:
	visible = false
	GameState.consume_offline_popup()
	# Collect moves stored coins into wallet.
	GameState.collect_passive_income()
	collected.emit()


func hide_popup() -> void:
	visible = false
