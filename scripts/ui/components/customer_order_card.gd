class_name CustomerOrderCard
extends PanelContainer
## Reusable customer order card for the Orders screen.


signal start_pressed(order_id: String)
signal complete_pressed(order_id: String)
signal details_pressed(order_id: String)

var order_id: String = ""


func setup(order: OrderTemplate, status: int) -> void:
	order_id = str(order.order_id)
	for c in get_children():
		c.queue_free()

	var style := ThemeFactory._card(SugarStreetColors.SOFT_IVORY, 16)
	if status == SaveData.OrderStatus.READY_TO_COMPLETE:
		style.bg_color = Color(0.9, 0.98, 0.93, 1)
		style.border_color = SugarStreetColors.MINT_GREEN
		style.set_border_width_all(3)
	elif status == SaveData.OrderStatus.FAILED:
		style.border_color = SugarStreetColors.CORAL_PINK
		style.set_border_width_all(2)
	elif status == SaveData.OrderStatus.LOCKED:
		style.bg_color = Color(0.92, 0.9, 0.88, 1)
		style.border_color = SugarStreetColors.DISABLED_FILL
		style.set_border_width_all(2)
	add_theme_stylebox_override("panel", style)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	root.add_child(header)

	var portrait := ColorRect.new()
	portrait.custom_minimum_size = Vector2(52, 52)
	portrait.color = order.customer_color if status != SaveData.OrderStatus.LOCKED else order.customer_color.darkened(0.35)
	header.add_child(portrait)
	var portrait_label := Label.new()
	portrait_label.text = order.customer_name.substr(0, 1)
	portrait_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	portrait_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	portrait_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait_label.add_theme_color_override("font_color", SugarStreetColors.WHITE)
	portrait_label.add_theme_font_size_override("font_size", 22)
	portrait.add_child(portrait_label)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(info)
	var name_l := Label.new()
	name_l.text = order.customer_name
	name_l.add_theme_font_size_override("font_size", 17)
	name_l.add_theme_color_override("font_color", SugarStreetColors.BAKERY_BROWN)
	info.add_child(name_l)
	var msg := Label.new()
	msg.text = "“%s”" % (order.customer_message if order.customer_message != "" else "Please help with my order!")
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.add_theme_font_size_override("font_size", 12)
	msg.add_theme_color_override("font_color", SugarStreetColors.WOOD_BROWN)
	info.add_child(msg)

	var recipe := GameState.catalog.get_recipe(order.recipe_id)
	var preview := GameState.preview_order_rewards(order)
	_row(root, "Recipe", recipe.display_name if recipe else str(order.recipe_id))
	_row(root, "Objective", order.objective_text())
	_row(root, "Moves", str(order.move_limit))
	_row(root, "Rewards", "%s coins · %d XP · %d rep" % [
		RewardCalculator.format_coins(int(preview.get("coins", order.coin_reward))),
		int(preview.get("experience", order.experience_reward)),
		int(preview.get("reputation", order.reputation_reward)),
	])
	_row(root, "Difficulty", order.difficulty_label())
	_row(root, "Status", _status_name(status))

	if status == SaveData.OrderStatus.LOCKED:
		_row(root, "Unlock", order.unlock_requirement_text())

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	root.add_child(actions)

	var details := Button.new()
	details.text = "Details"
	details.custom_minimum_size = Vector2(90, 44)
	ThemeFactory.apply_button_styles(details, {
		"normal": ThemeFactory._btn(SugarStreetColors.SOFT_PEACH, 14),
		"hover": ThemeFactory._btn(SugarStreetColors.SOFT_PEACH.lightened(0.08), 14),
		"pressed": ThemeFactory._btn(SugarStreetColors.SOFT_PEACH.darkened(0.08), 14),
		"disabled": ThemeFactory._btn(SugarStreetColors.DISABLED_FILL, 14),
		"focus": ThemeFactory._btn(SugarStreetColors.SOFT_PEACH, 14, true),
	}, SugarStreetColors.DARK_TEXT)
	details.pressed.connect(func(): details_pressed.emit(order_id))
	actions.add_child(details)

	var action := Button.new()
	action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action.custom_minimum_size = Vector2(0, 44)
	match status:
		SaveData.OrderStatus.READY_TO_COMPLETE:
			action.text = "Complete Order"
			ThemeFactory.apply_button_styles(action, ThemeFactory.primary_button_styles())
			action.pressed.connect(func(): complete_pressed.emit(order_id))
		SaveData.OrderStatus.COMPLETED:
			action.text = "Completed"
			action.disabled = true
			ThemeFactory.apply_button_styles(action, ThemeFactory.primary_button_styles())
		SaveData.OrderStatus.LOCKED:
			action.text = "Locked"
			action.disabled = true
			ThemeFactory.apply_button_styles(action, ThemeFactory.primary_button_styles())
		SaveData.OrderStatus.FAILED:
			action.text = "Retry Order"
			ThemeFactory.apply_button_styles(action, ThemeFactory.primary_button_styles())
			action.pressed.connect(func(): start_pressed.emit(order_id))
		SaveData.OrderStatus.SELECTED, SaveData.OrderStatus.LEVEL_IN_PROGRESS:
			action.text = "Continue Order"
			ThemeFactory.apply_button_styles(action, ThemeFactory.primary_button_styles())
			action.pressed.connect(func(): start_pressed.emit(order_id))
		_:
			action.text = "Start Order"
			ThemeFactory.apply_button_styles(action, ThemeFactory.primary_button_styles())
			action.pressed.connect(func(): start_pressed.emit(order_id))
	actions.add_child(action)

	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.2)


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


func _row(parent: Control, key: String, value: String) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var k := Label.new()
	k.text = key + ":"
	k.custom_minimum_size = Vector2(84, 0)
	k.add_theme_font_size_override("font_size", 12)
	k.add_theme_color_override("font_color", SugarStreetColors.WOOD_BROWN)
	row.add_child(k)
	var v := Label.new()
	v.text = value
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_theme_font_size_override("font_size", 12)
	v.add_theme_color_override("font_color", SugarStreetColors.DARK_TEXT)
	row.add_child(v)
