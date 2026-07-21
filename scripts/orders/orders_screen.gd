extends Control
## Today’s Orders screen with scrollable customer cards.


var _list: VBoxContainer
var _confirm: ConfirmPopup
var _order_detail: OrderDetailPopup
var _reward_popup: RewardPopup
var _top_bar: TopResourceBar
var _bottom_nav: BottomNavigation


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
	safe.add_theme_constant_override("margin_bottom", 10)
	add_child(safe)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	safe.add_child(vbox)

	_top_bar = TopResourceBar.new()
	vbox.add_child(_top_bar)
	_top_bar.menu_pressed.connect(func(): _coming_soon("Menu"))

	var title_row := HBoxContainer.new()
	vbox.add_child(title_row)
	var title := Label.new()
	title.text = "Today’s Orders"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", SugarStreetColors.BAKERY_BROWN)
	title_row.add_child(title)
	var timer := Label.new()
	timer.text = "⏱ 4h 12m"
	timer.add_theme_font_size_override("font_size", 13)
	timer.add_theme_color_override("font_color", SugarStreetColors.WOOD_BROWN)
	title_row.add_child(timer)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_list)

	var chest := PanelContainer.new()
	chest.add_theme_stylebox_override("panel", ThemeFactory._card(SugarStreetColors.SOFT_IVORY, 14))
	vbox.add_child(chest)
	var chest_box := VBoxContainer.new()
	chest.add_child(chest_box)
	var chest_label := Label.new()
	chest_label.text = "🎁 Bonus Chest  ·  1 / 3 orders"
	chest_label.add_theme_color_override("font_color", SugarStreetColors.DARK_TEXT)
	chest_box.add_child(chest_label)
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 3
	bar.value = mini(float(GameState.data.completed_order_ids.size()), 3.0)
	bar.custom_minimum_size = Vector2(0, 14)
	chest_box.add_child(bar)

	_bottom_nav = BottomNavigation.new()
	_bottom_nav.selected_tab = BottomNavigation.TAB_CUSTOMERS
	vbox.add_child(_bottom_nav)
	_bottom_nav.tab_selected.connect(func(tab):
		if tab == BottomNavigation.TAB_EVENTS:
			_coming_soon("Events")
	)

	_confirm = ConfirmPopup.new()
	add_child(_confirm)
	_order_detail = OrderDetailPopup.new()
	add_child(_order_detail)
	_reward_popup = RewardPopup.new()
	add_child(_reward_popup)
	_order_detail.start_pressed.connect(_start_order)
	_order_detail.complete_pressed.connect(_complete_order)
	_reward_popup.continue_pressed.connect(_rebuild)


func _rebuild() -> void:
	if _list == null:
		return
	for c in _list.get_children():
		c.queue_free()
	for order in GameState.get_visible_orders():
		var card := CustomerOrderCard.new()
		_list.add_child(card)
		card.setup(order, GameState.get_order_status(str(order.order_id)))
		card.start_pressed.connect(_start_order)
		card.complete_pressed.connect(_complete_order)
		card.details_pressed.connect(_open_details)


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
		return
	AudioManager.play(AudioManager.Sfx.ORDER_COMPLETED)
	AudioManager.play(AudioManager.Sfx.COINS)
	_reward_popup.show_rewards(rewards)
	_rebuild()


func _coming_soon(feature: String) -> void:
	_confirm.show_confirm("Coming Soon", "%s unlocks later." % feature, "OK", "Close")
