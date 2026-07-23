extends Control
## Cozy bakery Shop Hub with décor visual, progress, equipment, and navigation.


const SettingsPopupScene := preload("res://scripts/ui/settings_popup.gd")

const BROWN := Color("#593326")
const SECONDARY := Color("#8A5A45")

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
var _upgrade_btn: Button
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
	while get_child_count() > 0:
		var child := get_child(0)
		remove_child(child)
		child.free()

	var bg := ColorRect.new()
	bg.color = Color("#FFF5E8")
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
	body.add_theme_constant_override("separation", 10)
	body_scroll.add_child(body)

	# Bakery preview — shop name lives inside the preview header.
	_decor_visual = ShopDecorVisual.new()
	_decor_visual.custom_minimum_size = Vector2(0, 240)
	body.add_child(_decor_visual)

	# Shop Progress panel
	_progress_panel = PanelContainer.new()
	_progress_panel.add_theme_stylebox_override("panel", ThemeFactory._card(SugarStreetColors.SOFT_IVORY, 14))
	body.add_child(_progress_panel)
	var prog_box := VBoxContainer.new()
	prog_box.add_theme_constant_override("separation", 6)
	_progress_panel.add_child(prog_box)
	var prog_title := Label.new()
	prog_title.text = "Shop Progress"
	prog_title.add_theme_font_size_override("font_size", 16)
	prog_title.add_theme_color_override("font_color", BROWN)
	prog_box.add_child(prog_title)
	_progress_body = Label.new()
	_progress_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_progress_body.add_theme_font_size_override("font_size", 12)
	_progress_body.add_theme_color_override("font_color", SECONDARY)
	prog_box.add_child(_progress_body)
	_appeal_bar = ProgressBar.new()
	_appeal_bar.custom_minimum_size = Vector2(0, 12)
	_appeal_bar.show_percentage = false
	prog_box.add_child(_appeal_bar)
	_upgrade_btn = Button.new()
	_upgrade_btn.text = "Upgrade Shop"
	_upgrade_btn.custom_minimum_size = Vector2(0, 44)
	ThemeFactory.apply_button_styles(_upgrade_btn, ThemeFactory.primary_button_styles())
	_upgrade_btn.pressed.connect(func(): _shop_upgrade_popup.show_upgrade())
	prog_box.add_child(_upgrade_btn)

	# Equipment placeholders with bakery-themed shapes
	var stations := GridContainer.new()
	stations.columns = 2
	stations.add_theme_constant_override("h_separation", 8)
	stations.add_theme_constant_override("v_separation", 8)
	body.add_child(stations)
	_normal_chrome.append(stations)
	_add_station(stations, "oven", "Oven", Color(0.62, 0.42, 0.34), "oven")
	_add_station(stations, "mixer", "Mixer", Color(0.85, 0.68, 0.5), "mixer")
	_add_station(stations, "display_case", "Display Case", Color(0.72, 0.86, 0.9), "case")
	_add_station(stations, "checkout", "Checkout", Color(0.78, 0.62, 0.48), "table")

	# Top action row: Recipes · Upgrades · Decor
	var top_actions := GridContainer.new()
	top_actions.columns = 3
	top_actions.add_theme_constant_override("h_separation", 8)
	top_actions.add_theme_constant_override("v_separation", 8)
	body.add_child(top_actions)
	_normal_chrome.append(top_actions)
	_recipes_badge = _nav_card(top_actions, "Recipes", "Unlock desserts", func(): SceneRouter.go_recipe_book(), true, false)
	_upgrades_badge = _nav_card(top_actions, "Upgrades", "Improve gear", func(): SceneRouter.go_upgrades(), true, false)
	_decor_badge = _nav_card(top_actions, "Decor", "Customize", func(): SceneRouter.go_decor(), true, true)

	# Primary Orders button
	var orders_wrap := VBoxContainer.new()
	body.add_child(orders_wrap)
	_normal_chrome.append(orders_wrap)
	_orders_badge = _nav_card(orders_wrap, "Orders", "Serve today's customers", func(): SceneRouter.go_orders(), true, true, 64)

	# Secondary row: Daily Bonus · Workers · Locations
	var soon := GridContainer.new()
	soon.columns = 3
	soon.add_theme_constant_override("h_separation", 8)
	soon.add_theme_constant_override("v_separation", 8)
	body.add_child(soon)
	_normal_chrome.append(soon)
	_coming_soon_card(soon, "Daily Bonus")
	_coming_soon_card(soon, "Workers")
	_coming_soon_card(soon, "Locations")

	var util := HBoxContainer.new()
	util.add_theme_constant_override("separation", 8)
	body.add_child(util)
	_normal_chrome.append(util)
	_small_btn(util, "Edit Shop", func(): _enter_edit_mode())
	_small_btn(util, "Settings", _on_settings)
	_small_btn(util, "Back to Title", func():
		GameState.save_now()
		SceneRouter.go_title()
	, true)

	var preview_title := Label.new()
	preview_title.text = "Today's Order Previews"
	preview_title.add_theme_font_size_override("font_size", 16)
	preview_title.add_theme_color_override("font_color", BROWN)
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


func _add_station(parent: GridContainer, equipment_id: String, title: String, color: Color, shape: String) -> void:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 78)
	var style := ThemeFactory._card(SugarStreetColors.SOFT_IVORY, 14)
	card.add_theme_stylebox_override("panel", style)
	parent.add_child(card)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)

	var icon := _equipment_icon(shape, color)
	row.add_child(icon)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)
	var name_l := Label.new()
	name_l.text = title
	name_l.add_theme_font_size_override("font_size", 14)
	name_l.add_theme_color_override("font_color", BROWN)
	col.add_child(name_l)
	var lvl := Label.new()
	lvl.add_theme_font_size_override("font_size", 12)
	lvl.add_theme_color_override("font_color", SECONDARY)
	col.add_child(lvl)
	_station_labels[equipment_id] = {"label": lvl, "title": title}


func _equipment_icon(shape: String, color: Color) -> Control:
	var wrap := Control.new()
	wrap.custom_minimum_size = Vector2(52, 52)
	match shape:
		"oven":
			var body := PanelContainer.new()
			body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			var bstyle := StyleBoxFlat.new()
			bstyle.bg_color = color
			bstyle.set_corner_radius_all(10)
			body.add_theme_stylebox_override("panel", bstyle)
			wrap.add_child(body)
			var door := ColorRect.new()
			door.color = color.darkened(0.25)
			door.position = Vector2(10, 16)
			door.size = Vector2(32, 26)
			wrap.add_child(door)
			var knob := ColorRect.new()
			knob.color = SugarStreetColors.GOLDEN_YELLOW
			knob.position = Vector2(36, 26)
			knob.size = Vector2(6, 6)
			wrap.add_child(knob)
		"mixer":
			var bowl := PanelContainer.new()
			bowl.position = Vector2(8, 22)
			bowl.size = Vector2(36, 24)
			var bowl_s := StyleBoxFlat.new()
			bowl_s.bg_color = color
			bowl_s.set_corner_radius_all(12)
			bowl.add_theme_stylebox_override("panel", bowl_s)
			wrap.add_child(bowl)
			var arm := ColorRect.new()
			arm.color = color.darkened(0.2)
			arm.position = Vector2(22, 6)
			arm.size = Vector2(8, 22)
			wrap.add_child(arm)
			var head := PanelContainer.new()
			head.position = Vector2(14, 2)
			head.size = Vector2(24, 12)
			var head_s := StyleBoxFlat.new()
			head_s.bg_color = color.darkened(0.1)
			head_s.set_corner_radius_all(6)
			head.add_theme_stylebox_override("panel", head_s)
			wrap.add_child(head)
		"case":
			var glass := PanelContainer.new()
			glass.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			var gstyle := StyleBoxFlat.new()
			gstyle.bg_color = color
			gstyle.set_corner_radius_all(8)
			gstyle.set_border_width_all(2)
			gstyle.border_color = Color(1, 1, 1, 0.55)
			glass.add_theme_stylebox_override("panel", gstyle)
			wrap.add_child(glass)
			for i in range(3):
				var treat := PanelContainer.new()
				treat.position = Vector2(8 + i * 13, 28)
				treat.size = Vector2(10, 10)
				var tstyle := StyleBoxFlat.new()
				tstyle.bg_color = [SugarStreetColors.CORAL_PINK, SugarStreetColors.MINT_GREEN, SugarStreetColors.GOLDEN_YELLOW][i]
				tstyle.set_corner_radius_all(5)
				treat.add_theme_stylebox_override("panel", tstyle)
				wrap.add_child(treat)
		_:
			var table := PanelContainer.new()
			table.position = Vector2(4, 18)
			table.size = Vector2(44, 22)
			var tstyle := StyleBoxFlat.new()
			tstyle.bg_color = color
			tstyle.set_corner_radius_all(6)
			table.add_theme_stylebox_override("panel", tstyle)
			wrap.add_child(table)
			for i in range(2):
				var treat := PanelContainer.new()
				treat.position = Vector2(12 + i * 16, 8)
				treat.size = Vector2(12, 12)
				var cstyle := StyleBoxFlat.new()
				cstyle.bg_color = SugarStreetColors.CORAL_PINK if i == 0 else SugarStreetColors.MINT_GREEN
				cstyle.set_corner_radius_all(6)
				treat.add_theme_stylebox_override("panel", cstyle)
				wrap.add_child(treat)
	return wrap


func _nav_card(parent: Control, title: String, subtitle: String, cb: Callable, with_badge: bool = false, primary: bool = false, min_h: float = 56.0) -> NotificationBadgeView:
	var btn := Button.new()
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, min_h)
	btn.text = "%s\n%s" % [title, subtitle]
	ThemeFactory.apply_button_styles(
		btn,
		ThemeFactory.primary_button_styles() if primary else ThemeFactory.soft_button_styles(),
		SugarStreetColors.WHITE if primary else BROWN
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


func _coming_soon_card(parent: Control, title: String) -> void:
	var btn := Button.new()
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 52)
	btn.text = "%s\nComing Soon" % title
	btn.disabled = true
	btn.clip_text = true
	ThemeFactory.apply_button_styles(btn, {
		"normal": ThemeFactory._btn(SugarStreetColors.DISABLED_FILL, 12),
		"hover": ThemeFactory._btn(SugarStreetColors.DISABLED_FILL, 12),
		"pressed": ThemeFactory._btn(SugarStreetColors.DISABLED_FILL, 12),
		"disabled": ThemeFactory._btn(SugarStreetColors.DISABLED_FILL, 12),
		"focus": ThemeFactory._btn(SugarStreetColors.DISABLED_FILL, 12),
	}, SugarStreetColors.DISABLED_TEXT)
	btn.add_theme_font_size_override("font_size", 11)
	btn.pressed.connect(func(): _coming_soon(title))
	parent.add_child(btn)


func _small_btn(parent: Control, text: String, cb: Callable, secondary_quiet: bool = false) -> void:
	var btn := Button.new()
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 44)
	btn.text = text
	if secondary_quiet:
		ThemeFactory.apply_button_styles(btn, ThemeFactory.soft_button_styles(), BROWN)
		btn.add_theme_font_size_override("font_size", 12)
	else:
		ThemeFactory.apply_button_styles(btn, ThemeFactory.secondary_button_styles())
		btn.add_theme_font_size_override("font_size", 13)
	btn.pressed.connect(func():
		AudioManager.play_button()
		cb.call()
	)
	parent.add_child(btn)


func _refresh() -> void:
	for eq_id in _station_labels.keys():
		var info: Dictionary = _station_labels[eq_id]
		var lvl := GameState.get_equipment_level(StringName(eq_id))
		(info["label"] as Label).text = "Level %d" % lvl
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
	var upgrade_check := GameState.can_upgrade_shop_level()
	var next_req := ShopLevelRules.requirements_for(GameState.data.shop_level + 1)
	var next_line := "Max shop level reached."
	if GameState.data.shop_level < ShopLevelRules.MAX_SHOP_LEVEL:
		next_line = "Next level:\n%d reputation · %d appeal · %s coins" % [
			int(next_req.get("reputation", 0)),
			int(next_req.get("appeal", 0)),
			RewardCalculator.format_coins(int(next_req.get("coins", 0))),
		]
	_progress_body.text = "\n".join([
		"Shop Level %d" % GameState.data.shop_level,
		"Appeal: %d" % int(summary.get("appeal", 0)),
		"Reputation: %d" % GameState.data.reputation,
		next_line,
	])
	if _appeal_bar:
		var next_info: Dictionary = summary.get("next_tier", {})
		_appeal_bar.max_value = 100
		_appeal_bar.value = float(next_info.get("progress", 0.0)) * 100.0
	if _upgrade_btn:
		var can := bool(upgrade_check.get("ok", false))
		_upgrade_btn.disabled = not can
		_upgrade_btn.text = "Upgrade Shop" if can else "Upgrade Shop (locked)"


func _rebuild_previews() -> void:
	if _preview_host == null:
		return
	while _preview_host.get_child_count() > 0:
		var child := _preview_host.get_child(0)
		_preview_host.remove_child(child)
		child.free()
	var orders := GameState.get_visible_orders()
	if orders.is_empty():
		var empty := Label.new()
		empty.text = "No orders available"
		empty.add_theme_color_override("font_color", SECONDARY)
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
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", ThemeFactory._card(SugarStreetColors.SOFT_IVORY, 14))
		_preview_host.add_child(card)
		var row := VBoxContainer.new()
		card.add_child(row)
		var title := Label.new()
		title.text = "%s · %s" % [order.customer_name, recipe.display_name if recipe else str(order.recipe_id)]
		title.add_theme_font_size_override("font_size", 14)
		title.add_theme_color_override("font_color", BROWN)
		row.add_child(title)
		var meta := Label.new()
		meta.text = "Status: %s · %s coins" % [
			_status_name(status),
			RewardCalculator.format_coins(int(preview.get("coins", order.coin_reward))),
		]
		meta.add_theme_font_size_override("font_size", 12)
		meta.add_theme_color_override("font_color", SECONDARY)
		row.add_child(meta)
		var open_btn := Button.new()
		open_btn.text = "Open Orders"
		open_btn.custom_minimum_size = Vector2(0, 44)
		ThemeFactory.apply_button_styles(open_btn, ThemeFactory.soft_button_styles(), BROWN)
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
