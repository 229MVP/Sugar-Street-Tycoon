extends Control
## Cozy bakery Shop Hub with visible stations, order previews, and navigation.


const SettingsPopupScene := preload("res://scripts/ui/settings_popup.gd")

var _confirm: ConfirmPopup
var _settings: Control
var _top_bar: TopResourceBar
var _bottom_nav: BottomNavigation
var _level_up: LevelUpPopup
var _orders_badge: NotificationBadgeView
var _recipes_badge: NotificationBadgeView
var _upgrades_badge: NotificationBadgeView
var _preview_host: VBoxContainer
var _station_labels: Dictionary = {}


func _ready() -> void:
	theme = ThemeFactory.build()
	_build()
	if not GameState.state_changed.is_connected(_refresh):
		GameState.state_changed.connect(_refresh)
	if not GameState.notifications_changed.is_connected(_refresh):
		GameState.notifications_changed.connect(_refresh)
	_refresh()
	_show_pending_level_ups()
	AudioManager.play(AudioManager.Sfx.SHOP_OPENED)


func _build() -> void:
	for c in get_children():
		c.queue_free()

	var bg := ColorRect.new()
	bg.color = SugarStreetColors.WARM_CREAM
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var peach_band := ColorRect.new()
	peach_band.color = SugarStreetColors.SOFT_PEACH
	peach_band.set_anchors_preset(Control.PRESET_TOP_WIDE)
	peach_band.anchor_bottom = 0.18
	peach_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(peach_band)

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
	_top_bar.menu_pressed.connect(_on_menu)

	# Scroll middle content so Settings / previews stay reachable on short phones.
	var body_scroll := ScrollContainer.new()
	body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(body_scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	body_scroll.add_child(body)

	var shop_name := Label.new()
	shop_name.name = "ShopNameLabel"
	shop_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shop_name.add_theme_font_size_override("font_size", 22)
	shop_name.add_theme_color_override("font_color", SugarStreetColors.BAKERY_BROWN)
	body.add_child(shop_name)

	var progress := Label.new()
	progress.name = "ShopProgressLabel"
	progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress.add_theme_font_size_override("font_size", 13)
	progress.add_theme_color_override("font_color", SugarStreetColors.WOOD_BROWN)
	body.add_child(progress)

	var stations := GridContainer.new()
	stations.columns = 2
	stations.add_theme_constant_override("h_separation", 8)
	stations.add_theme_constant_override("v_separation", 8)
	body.add_child(stations)
	_add_station(stations, "oven", "Oven", Color(0.62, 0.42, 0.34))
	_add_station(stations, "mixer", "Mixer", Color(0.85, 0.68, 0.5))
	_add_station(stations, "display_case", "Display Case", Color(0.72, 0.86, 0.9))
	_add_station(stations, "checkout", "Checkout", Color(0.78, 0.62, 0.48))

	var dessert := PanelContainer.new()
	dessert.add_theme_stylebox_override("panel", ThemeFactory._card(SugarStreetColors.STRAWBERRY_PINK.lightened(0.35), 14))
	body.add_child(dessert)
	var dessert_lbl := Label.new()
	dessert_lbl.text = "Dessert Display Table · fresh treats ready"
	dessert_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dessert_lbl.add_theme_color_override("font_color", SugarStreetColors.BAKERY_BROWN)
	dessert.add_child(dessert_lbl)

	var actions := GridContainer.new()
	actions.columns = 2
	actions.add_theme_constant_override("h_separation", 8)
	actions.add_theme_constant_override("v_separation", 8)
	body.add_child(actions)
	_orders_badge = _nav_card(actions, "Orders", "Open customer orders", func(): SceneRouter.go_orders(), true)
	_recipes_badge = _nav_card(actions, "Recipes", "Unlock dessert recipes", func(): SceneRouter.go_recipe_book(), true)
	_upgrades_badge = _nav_card(actions, "Upgrades", "Improve bakery equipment", func(): SceneRouter.go_upgrades(), true)
	_nav_card(actions, "Inventory", "View ingredients", func(): SceneRouter.go_inventory())

	var soon := HBoxContainer.new()
	soon.add_theme_constant_override("separation", 8)
	body.add_child(soon)
	_small_btn(soon, "Workers\nComing Soon", func(): _coming_soon("Workers"), true)
	_small_btn(soon, "Locations\nComing Soon", func(): _coming_soon("Locations"), true)

	var util := HBoxContainer.new()
	util.add_theme_constant_override("separation", 8)
	body.add_child(util)
	_small_btn(util, "Settings", _on_settings)
	_small_btn(util, "Back to Title", func():
		GameState.save_now()
		SceneRouter.go_title()
	)

	var preview_title := Label.new()
	preview_title.text = "Today's Order Previews"
	preview_title.add_theme_font_size_override("font_size", 16)
	preview_title.add_theme_color_override("font_color", SugarStreetColors.BAKERY_BROWN)
	body.add_child(preview_title)

	_preview_host = VBoxContainer.new()
	_preview_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_host.add_theme_constant_override("separation", 8)
	body.add_child(_preview_host)

	_bottom_nav = BottomNavigation.new()
	_bottom_nav.selected_tab = BottomNavigation.TAB_SHOP
	vbox.add_child(_bottom_nav)

	_confirm = ConfirmPopup.new()
	add_child(_confirm)
	_settings = SettingsPopupScene.new()
	add_child(_settings)
	_level_up = LevelUpPopup.new()
	add_child(_level_up)
	_level_up.continue_pressed.connect(_show_pending_level_ups)


func _add_station(parent: GridContainer, equipment_id: String, title: String, color: Color) -> void:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 64)
	var style := ThemeFactory._card(color, 14)
	card.add_theme_stylebox_override("panel", style)
	parent.add_child(card)
	var lbl := Label.new()
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", SugarStreetColors.WHITE)
	lbl.add_theme_font_size_override("font_size", 14)
	card.add_child(lbl)
	_station_labels[equipment_id] = {"label": lbl, "title": title}


func _nav_card(parent: GridContainer, title: String, subtitle: String, cb: Callable, with_badge: bool = false) -> NotificationBadgeView:
	var btn := Button.new()
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 64)
	btn.text = "%s\n%s" % [title, subtitle]
	ThemeFactory.apply_button_styles(btn, ThemeFactory.primary_button_styles() if title == "Orders" else ThemeFactory.soft_button_styles(),
		SugarStreetColors.WHITE if title == "Orders" else SugarStreetColors.DARK_TEXT)
	btn.add_theme_font_size_override("font_size", 14)
	btn.pressed.connect(func():
		UiMotion.press_scale(btn)
		AudioManager.play_button()
		cb.call()
	)
	parent.add_child(btn)
	var badge := NotificationBadgeView.new()
	btn.add_child(badge)
	badge.position = Vector2(8, 4)
	badge.visible = with_badge
	return badge


func _small_btn(parent: Control, text: String, cb: Callable, disabled: bool = false) -> void:
	var btn := Button.new()
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 48)
	btn.text = text
	btn.disabled = disabled
	ThemeFactory.apply_button_styles(btn, ThemeFactory.secondary_button_styles() if not disabled else {
		"normal": ThemeFactory._btn(SugarStreetColors.DISABLED_FILL, 14),
		"hover": ThemeFactory._btn(SugarStreetColors.DISABLED_FILL, 14),
		"pressed": ThemeFactory._btn(SugarStreetColors.DISABLED_FILL, 14),
		"disabled": ThemeFactory._btn(SugarStreetColors.DISABLED_FILL, 14),
		"focus": ThemeFactory._btn(SugarStreetColors.DISABLED_FILL, 14),
	})
	btn.pressed.connect(func():
		AudioManager.play_button()
		cb.call()
	)
	parent.add_child(btn)


func _refresh() -> void:
	var name_lbl := find_child("ShopNameLabel", true, false) as Label
	var prog_lbl := find_child("ShopProgressLabel", true, false) as Label
	if name_lbl:
		name_lbl.text = GameState.data.shop_name
	if prog_lbl:
		prog_lbl.text = "Shop Level %d · Reputation %d" % [GameState.data.shop_level, GameState.data.reputation]
	for eq_id in _station_labels.keys():
		var info: Dictionary = _station_labels[eq_id]
		var lvl := GameState.get_equipment_level(StringName(eq_id))
		(info["label"] as Label).text = "%s · Lv.%d" % [info["title"], lvl]
	_rebuild_previews()
	var ready := GameState.ready_to_complete_count()
	var available := GameState.get_visible_orders().size()
	if _orders_badge:
		_orders_badge.set_count(ready if ready > 0 else available)
	if _recipes_badge:
		_recipes_badge.set_count(GameState.recipe_unlock_available_count())
	if _upgrades_badge:
		_upgrades_badge.set_count(GameState.affordable_upgrade_count())


func _rebuild_previews() -> void:
	if _preview_host == null:
		return
	for c in _preview_host.get_children():
		c.queue_free()
	var orders := GameState.get_visible_orders()
	if orders.is_empty():
		var empty := Label.new()
		empty.text = "No orders available"
		empty.add_theme_color_override("font_color", SugarStreetColors.WOOD_BROWN)
		_preview_host.add_child(empty)
		return
	for order in orders:
		var status := GameState.get_order_status(str(order.order_id))
		var recipe := GameState.catalog.get_recipe(order.recipe_id)
		var preview := GameState.preview_order_rewards(order)
		var card := PanelContainer.new()
		var style := ThemeFactory._card(SugarStreetColors.SOFT_IVORY, 14)
		if status == SaveData.OrderStatus.READY_TO_COMPLETE:
			style.bg_color = Color(0.88, 0.97, 0.92, 1)
			style.border_color = SugarStreetColors.MINT_GREEN
			style.set_border_width_all(2)
		card.add_theme_stylebox_override("panel", style)
		_preview_host.add_child(card)
		var row := VBoxContainer.new()
		card.add_child(row)
		var title := Label.new()
		title.text = "%s · %s" % [order.customer_name, recipe.display_name if recipe else str(order.recipe_id)]
		title.add_theme_font_size_override("font_size", 14)
		title.add_theme_color_override("font_color", SugarStreetColors.BAKERY_BROWN)
		row.add_child(title)
		var meta := Label.new()
		meta.text = "Status: %s · Reward: %s coins" % [_status_name(status), RewardCalculator.format_coins(int(preview.get("coins", order.coin_reward)))]
		meta.add_theme_font_size_override("font_size", 12)
		meta.add_theme_color_override("font_color", SugarStreetColors.WOOD_BROWN)
		row.add_child(meta)
		var open_btn := Button.new()
		open_btn.text = "Open Orders"
		open_btn.custom_minimum_size = Vector2(0, 44)
		ThemeFactory.apply_button_styles(open_btn, ThemeFactory.soft_button_styles(), SugarStreetColors.DARK_TEXT)
		open_btn.pressed.connect(func(): SceneRouter.go_orders())
		row.add_child(open_btn)


func _status_name(status: int) -> String:
	match status:
		SaveData.OrderStatus.AVAILABLE: return "Available"
		SaveData.OrderStatus.SELECTED: return "Selected"
		SaveData.OrderStatus.LEVEL_IN_PROGRESS: return "In Progress"
		SaveData.OrderStatus.READY_TO_COMPLETE: return "Ready to Complete"
		SaveData.OrderStatus.COMPLETED: return "Completed"
		SaveData.OrderStatus.FAILED: return "Failed"
		SaveData.OrderStatus.LOCKED: return "Locked"
	return "Unknown"


func _on_menu() -> void:
	_confirm.show_confirm("Menu", "Open settings?", "Settings", "Close")
	if not _confirm.confirmed.is_connected(_on_settings):
		_confirm.confirmed.connect(_on_settings, CONNECT_ONE_SHOT)


func _on_settings() -> void:
	_settings.call("show_settings")


func _coming_soon(feature: String) -> void:
	_confirm.show_confirm("Coming Soon", "%s unlocks later." % feature, "OK", "Close")


func _show_pending_level_ups() -> void:
	var ups := GameState.consume_pending_level_ups()
	if ups.is_empty():
		return
	var first: Dictionary = ups[0]
	for i in range(1, ups.size()):
		GameState.pending_level_ups.append(ups[i])
	_level_up.show_level_up(int(first.get("new_level", 1)), int(first.get("coin_reward", 0)), "Check Recipes for newly available unlocks.")
