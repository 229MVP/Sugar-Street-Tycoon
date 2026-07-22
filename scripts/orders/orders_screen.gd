extends Control
## Today’s Orders screen with scrollable customer cards.


const SettingsPopupScene := preload("res://scripts/ui/settings_popup.gd")

var _list: VBoxContainer
var _confirm: ConfirmPopup
var _order_detail: OrderDetailPopup
var _reward_popup: RewardPopup
var _level_up: LevelUpPopup
var _settings: Control
var _top_bar: TopResourceBar
var _bottom_nav: BottomNavigation
var _empty_label: Label


func _ready() -> void:
	theme = ThemeFactory.build()
	_build()
	_rebuild()
	GameState.state_changed.connect(_rebuild)
	GameState.notifications_changed.connect(_rebuild)
	AudioManager.play(AudioManager.Sfx.SHOP_OPENED)


func _build() -> void:
	for c in get_children():
		c.queue_free()

	var bg := ColorRect.new()
	bg.color = SugarStreetColors.WARM_CREAM
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var safe := MarginContainer.new()
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe.add_theme_constant_override("margin_left", 12)
	safe.add_theme_constant_override("margin_right", 12)
	safe.add_theme_constant_override("margin_top", 10)
	safe.add_theme_constant_override("margin_bottom", 8)
	add_child(safe)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	safe.add_child(vbox)

	_top_bar = TopResourceBar.new()
	vbox.add_child(_top_bar)
	_top_bar.menu_pressed.connect(_on_settings)

	var title := Label.new()
	title.text = "Customer Orders"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", SugarStreetColors.BAKERY_BROWN)
	vbox.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_list)

	_empty_label = Label.new()
	_empty_label.text = "No orders available"
	_empty_label.visible = false
	_empty_label.add_theme_color_override("font_color", SugarStreetColors.WOOD_BROWN)
	vbox.add_child(_empty_label)

	var back := Button.new()
	back.text = "Back to Shop"
	back.custom_minimum_size = Vector2(0, 44)
	ThemeFactory.apply_button_styles(back, ThemeFactory.secondary_button_styles())
	back.pressed.connect(func(): SceneRouter.go_shop())
	vbox.add_child(back)

	_bottom_nav = BottomNavigation.new()
	_bottom_nav.selected_tab = BottomNavigation.TAB_ORDERS
	vbox.add_child(_bottom_nav)

	_confirm = ConfirmPopup.new()
	add_child(_confirm)
	_order_detail = OrderDetailPopup.new()
	add_child(_order_detail)
	_reward_popup = RewardPopup.new()
	add_child(_reward_popup)
	_level_up = LevelUpPopup.new()
	add_child(_level_up)
	_settings = SettingsPopupScene.new()
	add_child(_settings)
	_order_detail.start_pressed.connect(_start_order)
	_order_detail.complete_pressed.connect(_complete_order)
	_reward_popup.continue_pressed.connect(_after_reward)
	_level_up.continue_pressed.connect(_show_pending_level_ups)


func _rebuild() -> void:
	if _list == null:
		return
	for c in _list.get_children():
		c.queue_free()
	var orders := GameState.get_orders_for_screen()
	_empty_label.visible = orders.is_empty()
	if orders.is_empty() and OS.is_debug_build():
		push_warning("OrdersScreen: no orders available to display")
	for order in orders:
		var card := CustomerOrderCard.new()
		_list.add_child(card)
		card.setup(order, GameState.get_order_status(str(order.order_id)))
		card.details_pressed.connect(_open_details)
		card.complete_pressed.connect(_complete_order)
		# Start/Continue/Retry always open details first.
		card.start_pressed.connect(_open_details)


func _open_details(order_id: String) -> void:
	AudioManager.play_button()
	var order := GameState.catalog.get_order(StringName(order_id))
	if order:
		_order_detail.show_order(order, GameState.get_order_status(order_id))


func _start_order(order_id: String) -> void:
	if GameState.is_busy():
		return
	AudioManager.play(AudioManager.Sfx.ORDER_SELECTED)
	SceneRouter.start_order_level(order_id)


func _complete_order(order_id: String) -> void:
	if GameState.is_busy():
		return
	AudioManager.play_button()
	var rewards := GameState.complete_order(order_id)
	if rewards.is_empty():
		if OS.is_debug_build():
			push_warning("OrdersScreen: complete_order returned empty for %s" % order_id)
		return
	AudioManager.play(AudioManager.Sfx.ORDER_COMPLETED)
	AudioManager.play(AudioManager.Sfx.COINS)
	_reward_popup.show_rewards(rewards)
	_rebuild()


func _after_reward() -> void:
	_rebuild()
	_show_pending_level_ups()


func _show_pending_level_ups() -> void:
	var ups := GameState.consume_pending_level_ups()
	if ups.is_empty():
		return
	var first: Dictionary = ups[0]
	for i in range(1, ups.size()):
		GameState.pending_level_ups.append(ups[i])
	_level_up.show_level_up(int(first.get("new_level", 1)), int(first.get("coin_reward", 0)), "New recipes may now be available.")


func _on_settings() -> void:
	_settings.call("show_settings")
