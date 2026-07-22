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
	_panel.custom_minimum_size = Vector2(340, 420)
	_panel.add_theme_stylebox_override("panel", ThemeFactory._card(SugarStreetColors.SOFT_IVORY, 18))
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
	_title.add_theme_color_override("font_color", SugarStreetColors.BAKERY_BROWN)
	vbox.add_child(_title)
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_font_size_override("font_size", 15)
	_body.add_theme_color_override("font_color", SugarStreetColors.DARK_TEXT)
	vbox.add_child(_body)
	_start = Button.new()
	_start.text = "Start Order"
	_start.custom_minimum_size = Vector2(0, 48)
	ThemeFactory.apply_button_styles(_start, ThemeFactory.primary_button_styles())
	_start.pressed.connect(func():
		hide_popup()
		start_pressed.emit(_order_id)
	)
	vbox.add_child(_start)
	_complete = Button.new()
	_complete.text = "Complete Order"
	_complete.custom_minimum_size = Vector2(0, 48)
	ThemeFactory.apply_button_styles(_complete, ThemeFactory.primary_button_styles())
	_complete.pressed.connect(func():
		hide_popup()
		complete_pressed.emit(_order_id)
	)
	vbox.add_child(_complete)
	_cancel = Button.new()
	_cancel.text = "Cancel"
	_cancel.custom_minimum_size = Vector2(0, 44)
	ThemeFactory.apply_button_styles(_cancel, ThemeFactory.secondary_button_styles())
	_cancel.pressed.connect(func():
		hide_popup()
		cancelled.emit()
	)
	vbox.add_child(_cancel)


func show_order(order: OrderTemplate, status: int) -> void:
	_order_id = str(order.order_id)
	var recipe := GameState.catalog.get_recipe(order.recipe_id)
	_title.text = "Order from %s" % order.customer_name
	var rewards := GameState.preview_order_rewards(order) if GameState.has_method("preview_order_rewards") else RewardCalculator.compute_order_rewards(order, GameState.data)
	var message := order.customer_message if order.customer_message != "" else "Please help with my order!"
	var ingredient_lines: PackedStringArray = []
	for ing_id in order.ingredient_rewards.keys():
		ingredient_lines.append("%s x%d" % [str(ing_id).capitalize(), int(order.ingredient_rewards[ing_id])])
	var ingredients_text := ", ".join(ingredient_lines) if not ingredient_lines.is_empty() else "None"
	var decor_pct := float(rewards.get("breakdown", {}).get("decoration", {}).get("reputation_percent", 0.0))
	_body.text = "“%s”\n\nRecipe: %s\nObjective: %s\nMoves: %d\nDifficulty: %s\n\nRewards:\nCoins: %s\nXP: %d\nReputation: %d (+%d%% décor appeal)\nIngredients: %s\n\nStatus: %s" % [
		message,
		recipe.display_name if recipe else str(order.recipe_id),
		order.objective_text(),
		order.move_limit if order.move_limit > 0 else 20,
		order.difficulty_label(),
		RewardCalculator.format_coins(int(rewards.get("coins", order.coin_reward))),
		int(rewards.get("experience", order.experience_reward)),
		int(rewards.get("reputation", order.reputation_reward)),
		int(round(decor_pct * 100.0)),
		ingredients_text,
		_status_name(status),
	]
	if status == SaveData.OrderStatus.LOCKED:
		_body.text += "\n\n%s" % order.unlock_requirement_text()
	_complete.visible = status == SaveData.OrderStatus.READY_TO_COMPLETE
	_start.visible = status not in [
		SaveData.OrderStatus.READY_TO_COMPLETE,
		SaveData.OrderStatus.COMPLETED,
		SaveData.OrderStatus.LOCKED,
	]
	_start.disabled = status == SaveData.OrderStatus.LOCKED
	match status:
		SaveData.OrderStatus.FAILED:
			_start.text = "Retry Order"
		SaveData.OrderStatus.SELECTED, SaveData.OrderStatus.LEVEL_IN_PROGRESS:
			_start.text = "Continue Order"
		_:
			_start.text = "Start Order"
	visible = true
	AudioManager.play_popup()


func hide_popup() -> void:
	visible = false


func _status_name(status: int) -> String:
	match status:
		SaveData.OrderStatus.AVAILABLE: return "Available"
		SaveData.OrderStatus.SELECTED: return "Selected"
		SaveData.OrderStatus.LEVEL_IN_PROGRESS: return "In Progress"
		SaveData.OrderStatus.READY_TO_COMPLETE: return "Ready to Complete"
		SaveData.OrderStatus.COMPLETED: return "Completed"
		SaveData.OrderStatus.FAILED: return "Failed"
		SaveData.OrderStatus.LOCKED: return "Locked"
		SaveData.OrderStatus.EXPIRED: return "Expired"
	return "Unknown"
