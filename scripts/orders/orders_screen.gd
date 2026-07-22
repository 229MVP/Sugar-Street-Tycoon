extends Control
## Today's Orders — reliably populates scrollable customer cards from GameState.


const SettingsPopupScene := preload("res://scripts/ui/settings_popup.gd")
const OrderCardScene := preload("res://scenes/orders/order_card.tscn")

const BROWN := Color("#593326")
const SECONDARY := Color("#8A5A45")

var _list: VBoxContainer
var _scroll: ScrollContainer
var _empty_label: Label
var _empty_actions: HBoxContainer
var _confirm: ConfirmPopup
var _order_detail: OrderDetailPopup
var _reward_popup: RewardPopup
var _level_up: LevelUpPopup
var _settings: Control
var _top_bar: TopResourceBar
var _bottom_nav: BottomNavigation
var _rebuilding: bool = false
var _signals_wired: bool = false
var _cards_created: int = 0


func _ready() -> void:
	theme = ThemeFactory.build()
	_build_shell()
	_wire_game_signals()
	# Populate after the container has a real size.
	call_deferred("_safe_rebuild")
	if GameState.has_signal("save_loaded") and not GameState.save_loaded.is_connected(_safe_rebuild):
		GameState.save_loaded.connect(_safe_rebuild)
	AudioManager.play(AudioManager.Sfx.SHOP_OPENED)


func _build_shell() -> void:
	while get_child_count() > 0:
		var child := get_child(0)
		remove_child(child)
		child.free()

	var bg := ColorRect.new()
	bg.color = SugarStreetColors.WARM_CREAM
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var safe := MarginContainer.new()
	safe.name = "SafeArea"
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe.add_theme_constant_override("margin_left", 12)
	safe.add_theme_constant_override("margin_right", 12)
	safe.add_theme_constant_override("margin_top", 10)
	safe.add_theme_constant_override("margin_bottom", 8)
	add_child(safe)

	var vbox := VBoxContainer.new()
	vbox.name = "PageRoot"
	vbox.add_theme_constant_override("separation", 8)
	safe.add_child(vbox)

	_top_bar = TopResourceBar.new()
	vbox.add_child(_top_bar)
	_top_bar.menu_pressed.connect(_on_settings)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	vbox.add_child(title_row)
	var title := Label.new()
	title.text = "Today's Orders"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", BROWN)
	title_row.add_child(title)
	var timer_lbl := Label.new()
	timer_lbl.text = "Day open"
	timer_lbl.add_theme_font_size_override("font_size", 12)
	timer_lbl.add_theme_color_override("font_color", SECONDARY)
	title_row.add_child(timer_lbl)

	_scroll = ScrollContainer.new()
	_scroll.name = "OrderScroll"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.custom_minimum_size = Vector2(0, 240)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(_scroll)

	_list = VBoxContainer.new()
	_list.name = "OrderList"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	_scroll.add_child(_list)

	_empty_label = Label.new()
	_empty_label.text = "No customer orders are available."
	_empty_label.visible = false
	_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty_label.add_theme_color_override("font_color", SECONDARY)
	vbox.add_child(_empty_label)

	_empty_actions = HBoxContainer.new()
	_empty_actions.visible = false
	_empty_actions.add_theme_constant_override("separation", 8)
	vbox.add_child(_empty_actions)
	var retry := Button.new()
	retry.text = "Retry Load"
	retry.custom_minimum_size = Vector2(0, 44)
	retry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ThemeFactory.apply_button_styles(retry, ThemeFactory.primary_button_styles())
	retry.pressed.connect(_safe_rebuild)
	_empty_actions.add_child(retry)
	var back_empty := Button.new()
	back_empty.text = "Back to Shop"
	back_empty.custom_minimum_size = Vector2(0, 44)
	back_empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ThemeFactory.apply_button_styles(back_empty, ThemeFactory.secondary_button_styles())
	back_empty.pressed.connect(func(): SceneRouter.go_shop())
	_empty_actions.add_child(back_empty)

	# Footer stays below the scroll list so it never covers cards.
	var chest := PanelContainer.new()
	chest.name = "BonusChest"
	chest.custom_minimum_size = Vector2(0, 56)
	chest.add_theme_stylebox_override("panel", ThemeFactory._card(SugarStreetColors.SOFT_IVORY, 14))
	vbox.add_child(chest)
	var chest_row := HBoxContainer.new()
	chest_row.add_theme_constant_override("separation", 10)
	chest.add_child(chest_row)
	var chest_icon := PanelContainer.new()
	chest_icon.custom_minimum_size = Vector2(36, 36)
	var cstyle := StyleBoxFlat.new()
	cstyle.bg_color = SugarStreetColors.GOLDEN_YELLOW
	cstyle.set_corner_radius_all(10)
	chest_icon.add_theme_stylebox_override("panel", cstyle)
	chest_row.add_child(chest_icon)
	var chest_info := VBoxContainer.new()
	chest_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chest_row.add_child(chest_info)
	var chest_title := Label.new()
	chest_title.text = "Bonus Chest"
	chest_title.add_theme_font_size_override("font_size", 14)
	chest_title.add_theme_color_override("font_color", BROWN)
	chest_info.add_child(chest_title)
	var chest_sub := Label.new()
	chest_sub.text = "Complete orders to fill today's chest."
	chest_sub.add_theme_font_size_override("font_size", 11)
	chest_sub.add_theme_color_override("font_color", SECONDARY)
	chest_info.add_child(chest_sub)

	var back := Button.new()
	back.text = "Back to Shop"
	back.custom_minimum_size = Vector2(0, 44)
	ThemeFactory.apply_button_styles(back, ThemeFactory.secondary_button_styles())
	back.pressed.connect(func(): SceneRouter.go_shop())
	vbox.add_child(back)

	_bottom_nav = BottomNavigation.new()
	_bottom_nav.selected_tab = BottomNavigation.TAB_CUSTOMERS
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
	if not _order_detail.start_pressed.is_connected(_start_order):
		_order_detail.start_pressed.connect(_start_order)
	if not _order_detail.complete_pressed.is_connected(_complete_order):
		_order_detail.complete_pressed.connect(_complete_order)
	if not _reward_popup.continue_pressed.is_connected(_after_reward):
		_reward_popup.continue_pressed.connect(_after_reward)
	if not _level_up.continue_pressed.is_connected(_show_pending_level_ups):
		_level_up.continue_pressed.connect(_show_pending_level_ups)


func _wire_game_signals() -> void:
	if _signals_wired:
		return
	_signals_wired = true
	if not GameState.state_changed.is_connected(_safe_rebuild):
		GameState.state_changed.connect(_safe_rebuild)
	if not GameState.notifications_changed.is_connected(_safe_rebuild):
		GameState.notifications_changed.connect(_safe_rebuild)
	if not GameState.order_status_changed.is_connected(_on_order_status_changed):
		GameState.order_status_changed.connect(_on_order_status_changed)


func _on_order_status_changed(_order_id: String, _status: int) -> void:
	_safe_rebuild()


func _safe_rebuild() -> void:
	if not is_inside_tree():
		return
	if _list == null or not is_instance_valid(_list):
		call_deferred("_safe_rebuild")
		return
	_rebuild()


func _rebuild() -> void:
	if _rebuilding or _list == null or not is_instance_valid(_list):
		return
	_rebuilding = true

	while _list.get_child_count() > 0:
		var child := _list.get_child(0)
		_list.remove_child(child)
		child.free()

	# Ensure catalog/order board is ready before reading.
	if GameState.catalog == null or GameState.catalog.order_sequence.is_empty():
		GameState.catalog.build()
	GameState._ensure_order_board()

	if not ResourceLoader.exists("res://scenes/orders/order_card.tscn"):
		if OS.is_debug_build():
			push_error("OrdersScreen: invalid card scene path res://scenes/orders/order_card.tscn")
		_show_empty(true)
		_rebuilding = false
		return

	var defs := GameState.catalog.order_sequence.size()
	var orders := GameState.get_orders_for_screen()
	_cards_created = 0
	var missing: Array = []

	for expected in [
		&"order_mia_001", &"order_jordan_002", &"order_taylor_003",
		&"order_noah_004", &"order_morgan_005",
	]:
		if GameState.catalog.get_order(expected) == null:
			missing.append(str(expected))

	for order in orders:
		var card := OrderCardScene.instantiate()
		if card == null:
			if OS.is_debug_build():
				push_error("OrdersScreen: failed to instantiate order card")
			continue
		card.visible = true
		card.custom_minimum_size = Vector2(0, 160)
		_list.add_child(card)
		card.setup(order, GameState.get_order_status(str(order.order_id)))
		card.details_pressed.connect(_open_details)
		card.complete_pressed.connect(_complete_order)
		card.start_pressed.connect(_open_details)
		_cards_created += 1
		if OS.is_debug_build():
			print("OrdersScreen: created card for %s" % str(order.order_id))

	var empty := orders.is_empty() or _cards_created == 0
	_show_empty(empty)

	if OS.is_debug_build():
		print("OrdersScreen: definitions=%d cards=%d parent=%s missing=%s" % [
			defs, _cards_created, str(_list.get_path()) if is_inside_tree() else "OrderList", missing
		])
		if empty:
			push_warning("OrdersScreen: no orders available to display")

	_rebuilding = false


func _show_empty(empty: bool) -> void:
	_empty_label.visible = empty
	_empty_actions.visible = empty
	_scroll.visible = not empty


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
	_safe_rebuild()


func _after_reward() -> void:
	_safe_rebuild()
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
