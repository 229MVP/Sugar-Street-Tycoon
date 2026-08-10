class_name OrderCard
extends PanelContainer
## Reusable customer order card for the Orders screen.


signal start_pressed(order_id: String)
signal complete_pressed(order_id: String)
signal details_pressed(order_id: String)

const BROWN := Color("#593326")
const SECONDARY := Color("#8A5A45")
const LOCKED_GRAY := Color("#817671")
const SWIPE_CANCEL_DISTANCE := 6.0

var order_id: String = ""
var _touch_start := Vector2.ZERO
var _touch_scroll_start: int = 0
var _touch_active: bool = false
var _touch_dragged: bool = false
var _touch_scroll: ScrollContainer


func _ready() -> void:
	visible = true
	modulate.a = 1.0
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if custom_minimum_size.y < 150.0:
		custom_minimum_size = Vector2(0, 160)


func setup(order: OrderTemplate, status: int) -> void:
	order_id = str(order.order_id)
	_clear_children_immediate()
	visible = true
	modulate.a = 1.0
	custom_minimum_size = Vector2(0, 160)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Let the outer order list participate in gestures that begin anywhere on
	# the card. Buttons get an explicit touch router below because Android
	# otherwise treats their whole 44 px rows as non-scrollable islands.
	mouse_filter = Control.MOUSE_FILTER_PASS

	var style := ThemeFactory._card(SugarStreetColors.SOFT_IVORY, 14)
	if status == SaveData.OrderStatus.READY_TO_COMPLETE:
		style.bg_color = Color(0.9, 0.98, 0.93, 1)
		style.border_color = SugarStreetColors.MINT_GREEN
		style.set_border_width_all(3)
	elif status == SaveData.OrderStatus.FAILED:
		style.border_color = SugarStreetColors.CORAL_PINK
		style.set_border_width_all(2)
	elif status == SaveData.OrderStatus.LOCKED:
		style.bg_color = Color(0.93, 0.9, 0.88, 1)
		style.border_color = LOCKED_GRAY
		style.set_border_width_all(2)
	elif status == SaveData.OrderStatus.COMPLETED:
		style.bg_color = Color(0.94, 0.92, 0.9, 1)
	add_theme_stylebox_override("panel", style)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 4)
	add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	root.add_child(header)

	var portrait := PanelContainer.new()
	portrait.custom_minimum_size = Vector2(48, 48)
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = order.customer_color if status != SaveData.OrderStatus.LOCKED else order.customer_color.darkened(0.35)
	pstyle.set_corner_radius_all(24)
	portrait.add_theme_stylebox_override("panel", pstyle)
	header.add_child(portrait)
	var portrait_label := Label.new()
	portrait_label.text = order.customer_name.substr(0, 1)
	portrait_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	portrait_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	portrait_label.add_theme_color_override("font_color", SugarStreetColors.WHITE)
	portrait_label.add_theme_font_size_override("font_size", 20)
	portrait.add_child(portrait_label)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(info)
	var name_l := Label.new()
	name_l.text = order.customer_name
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_l.add_theme_font_size_override("font_size", 16)
	name_l.add_theme_color_override("font_color", BROWN)
	info.add_child(name_l)
	var msg := Label.new()
	msg.text = '"%s"' % (order.customer_message if order.customer_message != "" else "Please help with my order!")
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	msg.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	msg.add_theme_font_size_override("font_size", 11)
	msg.add_theme_color_override("font_color", SECONDARY)
	info.add_child(msg)

	var recipe := GameState.catalog.get_recipe(order.recipe_id)
	var preview := GameState.preview_order_rewards(order)
	_meta(root, "Recipe · %s" % (recipe.display_name if recipe else str(order.recipe_id)))
	_meta(root, "Objective · %s" % order.objective_text())
	_meta(root, "Moves %d · %s · %s" % [
		order.move_limit,
		order.difficulty_label(),
		_status_name(status),
	])
	_meta(root, "Rewards · %s coins · %d XP · %d rep" % [
		RewardCalculator.format_coins(int(preview.get("coins", order.coin_reward))),
		int(preview.get("experience", order.experience_reward)),
		int(preview.get("reputation", order.reputation_reward)),
	])
	if status == SaveData.OrderStatus.LOCKED:
		_meta(root, order.unlock_requirement_text())

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	root.add_child(actions)

	var details := Button.new()
	details.text = "Details"
	details.custom_minimum_size = Vector2(90, 44)
	ThemeFactory.apply_button_styles(details, ThemeFactory.soft_button_styles(), BROWN)
	details.mouse_filter = Control.MOUSE_FILTER_PASS
	details.gui_input.connect(_on_scroll_touch_input.bind(details))
	details.pressed.connect(func():
		if not _touch_dragged:
			details_pressed.emit(order_id)
	)
	actions.add_child(details)

	var action := Button.new()
	action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action.custom_minimum_size = Vector2(0, 44)
	action.mouse_filter = Control.MOUSE_FILTER_PASS
	action.gui_input.connect(_on_scroll_touch_input.bind(action))
	match status:
		SaveData.OrderStatus.READY_TO_COMPLETE:
			action.text = "Complete Order"
			ThemeFactory.apply_button_styles(action, ThemeFactory.primary_button_styles())
			action.pressed.connect(func():
				if not _touch_dragged:
					complete_pressed.emit(order_id)
			)
		SaveData.OrderStatus.COMPLETED:
			action.text = "Completed"
			action.disabled = true
			ThemeFactory.apply_button_styles(action, ThemeFactory.primary_button_styles())
		SaveData.OrderStatus.LOCKED:
			action.text = "Locked"
			action.disabled = true
			ThemeFactory.apply_button_styles(action, ThemeFactory.primary_button_styles())
		SaveData.OrderStatus.FAILED:
			action.text = "Retry"
			ThemeFactory.apply_button_styles(action, ThemeFactory.primary_button_styles())
			action.pressed.connect(func():
				if not _touch_dragged:
					start_pressed.emit(order_id)
			)
		SaveData.OrderStatus.SELECTED, SaveData.OrderStatus.LEVEL_IN_PROGRESS:
			action.text = "Continue"
			ThemeFactory.apply_button_styles(action, ThemeFactory.primary_button_styles())
			action.pressed.connect(func():
				if not _touch_dragged:
					start_pressed.emit(order_id)
			)
		_:
			action.text = "Start Order"
			ThemeFactory.apply_button_styles(action, ThemeFactory.primary_button_styles())
			action.pressed.connect(func():
				if not _touch_dragged:
					start_pressed.emit(order_id)
			)
	actions.add_child(action)


## Buttons consume Android screen drags before ScrollContainer sees them.
## Own the complete touch sequence and route its absolute displacement to the
## nearest vertical scroll list, while leaving short releases as normal taps.
func _on_scroll_touch_input(event: InputEvent, source: Control) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_touch_active = true
			_touch_dragged = false
			_touch_start = touch.position
			_touch_scroll = _vertical_scroll_ancestor()
			_touch_scroll_start = _touch_scroll.scroll_vertical if _touch_scroll else 0
			source.accept_event()
		elif _touch_active:
			_touch_active = false
			source.accept_event()
			_touch_scroll = null
			call_deferred("_clear_touch_dragged")
	elif event is InputEventScreenDrag and _touch_active:
		var drag := event as InputEventScreenDrag
		var displacement := drag.position - _touch_start
		if displacement.length() >= SWIPE_CANCEL_DISTANCE:
			_touch_dragged = true
			if _touch_scroll:
				_touch_scroll.scroll_vertical = _touch_scroll_start - int(round(displacement.y))
		source.accept_event()


func _vertical_scroll_ancestor() -> ScrollContainer:
	var candidate := get_parent()
	while candidate != null:
		if candidate is ScrollContainer:
			var scroll := candidate as ScrollContainer
			if scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
				return scroll
		candidate = candidate.get_parent()
	return null


func _clear_touch_dragged() -> void:
	_touch_dragged = false


func _clear_children_immediate() -> void:
	while get_child_count() > 0:
		var child := get_child(0)
		remove_child(child)
		child.free()


func _meta(parent: Control, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", BROWN)
	parent.add_child(lbl)


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
