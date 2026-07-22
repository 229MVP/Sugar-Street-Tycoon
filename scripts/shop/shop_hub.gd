extends Control
## Cozy bakery Shop Hub with décor visual, progress, edit mode, and navigation.


const SettingsPopupScene := preload("res://scripts/ui/settings_popup.gd")

var _confirm: ConfirmPopup
var _settings: Control
var _top_bar: TopResourceBar
var _bottom_nav: BottomNavigation
var _level_up: LevelUpPopup
var _orders_badge: NotificationBadgeView
var _recipes_badge: NotificationBadgeView
var _upgrades_badge: NotificationBadgeView
var _decor_badge: NotificationBadgeView
var _preview_host: VBoxContainer
var _station_labels: Dictionary = {}
var _decor_visual: ShopDecorVisual
var _progress_panel: PanelContainer
var _progress_body: Label
var _appeal_bar: ProgressBar
var _actions_host: Control
var _edit_overlay: ShopEditOverlay
var _shop_upgrade_popup: ShopLevelUpgradePopup
var _normal_chrome: Array = []


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
	if bool(GameState.data.settings.get("open_shop_edit", false)):
		GameState.data.settings["open_shop_edit"] = false
		GameState.save_now()
		call_deferred("_enter_edit_mode")


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
	_top_bar.menu_pressed.connect(_on_menu)

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

	_decor_visual = ShopDecorVisual.new()
	_decor_visual.custom_minimum_size = Vector2(0, 230)
	body.add_child(_decor_visual)

	_progress_panel = PanelContainer.new()
	_progress_panel.add_theme_stylebox_override("panel", ThemeFactory._card(SugarStreetColors.SOFT_IVORY, 14))
	body.add_child(_progress_panel)
	var prog_box := VBoxContainer.new()
	prog_box.add_theme_constant_override("separation", 6)
	_progress_panel.add_child(prog_box)
	var prog_title := Label.new()
	prog_title.text = "Shop Progress"
	prog_title.add_theme_font_size_override("font_size", 16)
	prog_title.add_theme_color_override("font_color", SugarStreetColors.BAKERY_BROWN)
	prog_box.add_child(prog_title)
	_progress_body = Label.new()
	_progress_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_progress_body.add_theme_font_size_override("font_size", 12)
	_progress_body.add_theme_color_override("font_color", SugarStreetColors.WOOD_BROWN)
	prog_box.add_child(_progress_body)
	_appeal_bar = ProgressBar.new()
	_appeal_bar.custom_minimum_size = Vector2(0, 12)
	_appeal_bar.show_percentage = false
	prog_box.add_child(_appeal_bar)
	var upgrade_btn := Button.new()
	upgrade_btn.text = "Upgrade Shop"
	upgrade_btn.custom_minimum_size = Vector2(0, 44)
	ThemeFactory.apply_button_styles(upgrade_btn, ThemeFactory.primary_button_styles())
	upgrade_btn.pressed.connect(func(): _shop_upgrade_popup.show_upgrade())
	prog_box.add_child(upgrade_btn)

	var stations := GridContainer.new()
	stations.columns = 2
	stations.add_theme_constant_override("h_separation", 8)
	stations.add_theme_constant_override("v_separation", 8)
	body.add_child(stations)
	_normal_chrome.append(stations)
	_add_station(stations, "oven", "Oven", Color(0.62, 0.42, 0.34))
	_add_station(stations, "mixer", "Mixer", Color(0.85, 0.68, 0.5))
	_add_station(stations, "display_case", "Display Case", Color(0.72, 0.86, 0.9))
	_add_station(stations, "checkout", "Checkout", Color(0.78, 0.62, 0.48))

	_actions_host = GridContainer.new()
	_actions_host.columns = 2
	_actions_host.add_theme_constant_override("h_separation", 8)
	_actions_host.add_theme_constant_override("v_separation", 8)
	body.add_child(_actions_host)
	_normal_chrome.append(_actions_host)
	_orders_badge = _nav_card(_actions_host, "Orders", "Open customer orders", func(): SceneRouter.go_orders(), true)
	_recipes_badge = _nav_card(_actions_host, "Recipes", "Unlock dessert recipes", func(): SceneRouter.go_recipe_book(), true)
	_upgrades_badge = _nav_card(_actions_host, "Upgrades", "Improve bakery equipment", func(): SceneRouter.go_upgrades(), true)
	_decor_badge = _nav_card(_actions_host, "Decor", "Customize your bakery", func(): SceneRouter.go_decor(), true)
	_nav_card(_actions_host, "Inventory", "View ingredients", func(): SceneRouter.go_inventory())
	_nav_card(_actions_host, "Edit Shop", "Place decorations", func(): _enter_edit_mode())

	var soon := HBoxContainer.new()
	soon.add_theme_constant_override("separation", 8)
	body.add_child(soon)
	_normal_chrome.append(soon)
	_small_btn(soon, "Workers\nComing Soon", func(): _coming_soon("Workers"), true)
	_small_btn(soon, "Locations\nComing Soon", func(): _coming_soon("Locations"), true)

	var util := HBoxContainer.new()
	util.add_theme_constant_override("separation", 8)
	body.add_child(util)
	_normal_chrome.append(util)
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
	_normal_chrome.append(preview_title)

	_preview_host = VBoxContainer.new()
	_preview_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_host.add_theme_constant_override("separation", 8)
	body.add_child(_preview_host)
	_normal_chrome.append(_preview_host)

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
	_shop_upgrade_popup = ShopLevelUpgradePopup.new()
	add_child(_shop_upgrade_popup)
	_shop_upgrade_popup.upgraded.connect(func(level):
		_celebrate_shop_level(level)
		_refresh()
	)
	_edit_overlay = ShopEditOverlay.new()
	add_child(_edit_overlay)
	_edit_overlay.closed.connect(_exit_edit_mode)

	if GameState.DEBUG_TOOLS_ENABLED and OS.is_debug_build():
		var debug := ShopDebugPanel.new()
		add_child(debug)


func _enter_edit_mode() -> void:
	for node in _normal_chrome:
		if is_instance_valid(node):
			node.modulate.a = 0.35
			node.mouse_filter = Control.MOUSE_FILTER_IGNORE if node is Control else node.mouse_filter
	_edit_overlay.open_edit(_decor_visual)


func _exit_edit_mode() -> void:
	for node in _normal_chrome:
		if is_instance_valid(node):
			node.modulate.a = 1.0
			if node is Control:
				node.mouse_filter = Control.MOUSE_FILTER_STOP
	_refresh()


func _celebrate_shop_level(level: int) -> void:
	_confirm.show_confirm(
		"Shop Level %d!" % level,
		"New slots and décor unlocks are ready. Your bakery stage updated.",
		"Awesome",
		"Close"
	)
	if not bool(GameState.data.settings.get("reduce_motion", false)) and _decor_visual:
		UiMotion.pulse(_decor_visual, 1.03, 0.35)


func _add_station(parent: GridContainer, equipment_id: String, title: String, color: Color) -> void:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 56)
	card.add_theme_stylebox_override("panel", ThemeFactory._card(color, 14))
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
	btn.custom_minimum_size = Vector2(0, 60)
	btn.text = "%s\n%s" % [title, subtitle]
	ThemeFactory.apply_button_styles(
		btn,
		ThemeFactory.primary_button_styles() if title in ["Orders", "Decor", "Edit Shop"] else ThemeFactory.soft_button_styles(),
		SugarStreetColors.WHITE if title in ["Orders", "Decor", "Edit Shop"] else SugarStreetColors.DARK_TEXT
	)
	btn.add_theme_font_size_override("font_size", 13)
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
	if name_lbl:
		name_lbl.text = GameState.data.shop_name
	for eq_id in _station_labels.keys():
		var info: Dictionary = _station_labels[eq_id]
		var lvl := GameState.get_equipment_level(StringName(eq_id))
		(info["label"] as Label).text = "%s · Lv.%d" % [info["title"], lvl]
	_refresh_progress()
	_rebuild_previews()
	if _decor_visual:
		_decor_visual.refresh()
	var ready := GameState.ready_to_complete_count()
	var available := GameState.get_visible_orders().size()
	if _orders_badge:
		_orders_badge.set_count(ready if ready > 0 else available)
	if _recipes_badge:
		_recipes_badge.set_count(GameState.recipe_unlock_available_count())
	if _upgrades_badge:
		_upgrades_badge.set_count(GameState.affordable_upgrade_count())
	if _decor_badge:
		_decor_badge.set_count(int(GameState.decoration_notification_priority().get("count", 0)))


func _refresh_progress() -> void:
	var summary := GameState.get_appeal_summary()
	var next_info: Dictionary = summary.get("next_tier", {})
	var upgrade_check := GameState.can_upgrade_shop_level()
	var next_req := ShopLevelRules.requirements_for(GameState.data.shop_level + 1)
	var req_line := "Max shop level reached."
	if GameState.data.shop_level < ShopLevelRules.MAX_SHOP_LEVEL:
		req_line = "Next Lv%d needs: player %d · %s coins · %d rep · %d Appeal" % [
			GameState.data.shop_level + 1,
			int(next_req.get("player_level", 1)),
			RewardCalculator.format_coins(int(next_req.get("coins", 0))),
			int(next_req.get("reputation", 0)),
			int(next_req.get("appeal", 0)),
		]
	_progress_body.text = "\n".join([
		"Shop Level %d · Reputation %d" % [GameState.data.shop_level, GameState.data.reputation],
		"Appeal %d · Tier %s · Decor rep bonus +%d%%" % [
			int(summary.get("appeal", 0)),
			str(summary.get("tier", "Plain")),
			int(round(float(summary.get("reputation_bonus_percent", 0.0)) * 100.0)),
		],
		req_line,
		"" if upgrade_check.get("ok", false) else str(upgrade_check.get("reason", "")),
	])
	if _appeal_bar:
		_appeal_bar.max_value = 100
		_appeal_bar.value = float(next_info.get("progress", 0.0)) * 100.0


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
	var count := 0
	for order in orders:
		if count >= 3:
			break
		count += 1
		var status := GameState.get_order_status(str(order.order_id))
		var recipe := GameState.catalog.get_recipe(order.recipe_id)
		var preview := GameState.preview_order_rewards(order)
		var decor_pct := float(preview.get("breakdown", {}).get("decoration", {}).get("reputation_percent", 0.0))
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", ThemeFactory._card(SugarStreetColors.SOFT_IVORY, 14))
		_preview_host.add_child(card)
		var row := VBoxContainer.new()
		card.add_child(row)
		var title := Label.new()
		title.text = "%s · %s" % [order.customer_name, recipe.display_name if recipe else str(order.recipe_id)]
		title.add_theme_font_size_override("font_size", 14)
		title.add_theme_color_override("font_color", SugarStreetColors.BAKERY_BROWN)
		row.add_child(title)
		var meta := Label.new()
		meta.text = "Status: %s · %s coins · décor +%d%% rep" % [
			_status_name(status),
			RewardCalculator.format_coins(int(preview.get("coins", order.coin_reward))),
			int(round(decor_pct * 100.0)),
		]
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
