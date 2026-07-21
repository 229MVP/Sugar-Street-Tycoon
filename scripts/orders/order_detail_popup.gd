class_name OrderDetailPopup
extends Control

signal start_pressed(order_id: String)
signal complete_pressed(order_id: String)
signal cancelled

var _panel: PanelContainer
var _title: Label
var _body: Label
var _start: Button
var _complete: Button
var _cancel: Button
var _order_id: String = ""


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
	_panel.custom_minimum_size = Vector2(340, 360)
	center.add_child(_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	_panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(_title)
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_font_size_override("font_size", 16)
	vbox.add_child(_body)
	_start = Button.new()
	_start.text = "Start Order"
	_start.custom_minimum_size = Vector2(0, 48)
	_start.pressed.connect(func():
		hide_popup()
		start_pressed.emit(_order_id)
	)
	vbox.add_child(_start)
	_complete = Button.new()
	_complete.text = "Complete Order"
	_complete.custom_minimum_size = Vector2(0, 48)
	_complete.pressed.connect(func():
		hide_popup()
		complete_pressed.emit(_order_id)
	)
	vbox.add_child(_complete)
	_cancel = Button.new()
	_cancel.text = "Cancel"
	_cancel.custom_minimum_size = Vector2(0, 44)
	_cancel.pressed.connect(func():
		hide_popup()
		cancelled.emit()
	)
	vbox.add_child(_cancel)


func show_order(order: OrderTemplate, status: int) -> void:
	_order_id = str(order.order_id)
	var recipe := GameState.catalog.get_recipe(order.recipe_id)
	_title.text = "Order from %s" % order.customer_name
	var rewards := GameState.preview_order_rewards(order)
	var breakdown: Dictionary = rewards.get("breakdown", {})
	var base: Dictionary = breakdown.get("base", {})
	var equipment: Dictionary = breakdown.get("equipment", {})
	var worker: Dictionary = breakdown.get("worker", {})
	var worker_names: PackedStringArray = []
	for c in worker.get("coin_contributors", []):
		worker_names.append("%s (+%d%% coins)" % [str(c.get("name", "")), int(float(c.get("percent", 0.0)) * 100.0)])
	for c in worker.get("all_contributors", []):
		worker_names.append("%s (+%d%% all)" % [str(c.get("name", "")), int(float(c.get("percent", 0.0)) * 100.0)])
	var worker_line := "None" if worker_names.is_empty() else ", ".join(worker_names)
	var ingredients := ""
	for k in order.ingredient_rewards.keys():
		ingredients += "\n• %s x%d" % [str(k).capitalize(), int(order.ingredient_rewards[k])]
	var chance := float(breakdown.get("bonus_ingredient_chance", 0.0))
	_body.text = "Recipe: %s\nLevel: %s\nDifficulty: %s\n\nBase: %s coins / %d XP / %d rep\nAfter equipment: %s / %d / %d\nWorker bonus: %s\nFinal: %s coins / %d XP / %d rep\nBonus ingredient chance: %.0f%%%s\n\nStatus: %s" % [
		recipe.display_name if recipe else str(order.recipe_id),
		order.level_id,
		order.difficulty_label(),
		RewardCalculator.format_coins(int(base.get("coins", order.coin_reward))),
		int(base.get("experience", order.experience_reward)),
		int(base.get("reputation", order.reputation_reward)),
		RewardCalculator.format_coins(int(equipment.get("coins", 0))),
		int(equipment.get("experience", 0)),
		int(equipment.get("reputation", 0)),
		worker_line,
		RewardCalculator.format_coins(int(rewards["coins"])),
		int(rewards["experience"]),
		int(rewards["reputation"]),
		chance * 100.0,
		ingredients,
		_status_name(status),
	]
	_complete.visible = status == SaveData.OrderStatus.READY_TO_COMPLETE
	_start.visible = status != SaveData.OrderStatus.READY_TO_COMPLETE and status != SaveData.OrderStatus.COMPLETED
	_start.text = "Retry Level" if status == SaveData.OrderStatus.FAILED else "Start Order"
	visible = true
	AudioManager.play_popup()


func hide_popup() -> void:
	visible = false


func _status_name(status: int) -> String:
	match status:
		SaveData.OrderStatus.AVAILABLE: return "Available"
		SaveData.OrderStatus.SELECTED: return "Selected"
		SaveData.OrderStatus.LEVEL_IN_PROGRESS: return "Level In Progress"
		SaveData.OrderStatus.READY_TO_COMPLETE: return "Ready to Complete"
		SaveData.OrderStatus.COMPLETED: return "Completed"
		SaveData.OrderStatus.FAILED: return "Failed"
		SaveData.OrderStatus.EXPIRED: return "Expired"
	return "Unknown"
