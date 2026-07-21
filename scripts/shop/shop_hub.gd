extends Control
## Cozy bakery Shop Hub — Figma-inspired frontend.


var _confirm: ConfirmPopup
var _top_bar: TopResourceBar
var _bottom_nav: BottomNavigation
var _orders_badge: NotificationBadgeView


func _ready() -> void:
	theme = ThemeFactory.build()
	_build()
	AudioManager.play(AudioManager.Sfx.SHOP_OPENED)
	if not GameState.state_changed.is_connected(_refresh_badges):
		GameState.state_changed.connect(_refresh_badges)
	if not GameState.notifications_changed.is_connected(_refresh_badges):
		GameState.notifications_changed.connect(_refresh_badges)
	_refresh_badges()


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
	_top_bar.menu_pressed.connect(_on_menu)

	# Bakery interior placeholder (shop_background.png missing).
	var interior := PanelContainer.new()
	interior.custom_minimum_size = Vector2(0, 180)
	interior.size_flags_vertical = Control.SIZE_EXPAND_FILL
	interior.size_flags_stretch_ratio = 1.2
	var interior_style := ThemeFactory._card(SugarStreetColors.SOFT_PEACH, 18)
	interior.add_theme_stylebox_override("panel", interior_style)
	vbox.add_child(interior)
	var interior_host := Control.new()
	interior_host.custom_minimum_size = Vector2(0, 160)
	interior.add_child(interior_host)
	_build_interior(interior_host)

	var sign := Label.new()
	sign.text = "My Bakery"
	sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign.add_theme_font_size_override("font_size", 22)
	sign.add_theme_color_override("font_color", SugarStreetColors.BAKERY_BROWN)
	vbox.add_child(sign)

	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 8)
	vbox.add_child(cards)
	_action_card(cards, "Recipes", "📖", func(): SceneRouter.go_recipe_book())
	_action_card(cards, "Upgrades", "🔧", func(): SceneRouter.go_upgrades())
	_action_card(cards, "Decor", "🎀", func(): _coming_soon("Decor"))

	var orders_btn := Button.new()
	orders_btn.text = "Orders"
	orders_btn.custom_minimum_size = Vector2(0, 54)
	ThemeFactory.apply_button_styles(orders_btn, ThemeFactory.primary_button_styles())
	orders_btn.add_theme_font_size_override("font_size", 22)
	orders_btn.pressed.connect(func():
		UiMotion.press_scale(orders_btn)
		AudioManager.play_button()
		SceneRouter.go_orders()
	)
	vbox.add_child(orders_btn)
	_orders_badge = NotificationBadgeView.new()
	orders_btn.add_child(_orders_badge)
	_orders_badge.position = Vector2(8, 4)

	var extras := HBoxContainer.new()
	extras.add_theme_constant_override("separation", 8)
	vbox.add_child(extras)
	_small_btn(extras, "Daily Bonus", func(): _coming_soon("Daily Bonus"))
	_small_btn(extras, "Workers\nComing Soon", func(): _coming_soon("Workers"), true)
	_small_btn(extras, "Locations\nComing Soon", func(): _coming_soon("Locations"), true)

	var title_btn := Button.new()
	title_btn.text = "Back to Title"
	title_btn.custom_minimum_size = Vector2(0, 44)
	ThemeFactory.apply_button_styles(title_btn, ThemeFactory.secondary_button_styles())
	title_btn.pressed.connect(func():
		AudioManager.play_button()
		GameState.save_now()
		SceneRouter.go_title()
	)
	vbox.add_child(title_btn)

	_bottom_nav = BottomNavigation.new()
	_bottom_nav.selected_tab = BottomNavigation.TAB_SHOP
	vbox.add_child(_bottom_nav)
	_bottom_nav.tab_selected.connect(_on_nav_tab)

	_confirm = ConfirmPopup.new()
	add_child(_confirm)


func _build_interior(host: Control) -> void:
	var stations := [
		["Oven", Color(0.55, 0.45, 0.4), Vector2(0.08, 0.2), Vector2(0.28, 0.35)],
		["Display", Color(0.7, 0.85, 0.9), Vector2(0.4, 0.15), Vector2(0.5, 0.3)],
		["Mixer", Color(0.85, 0.7, 0.55), Vector2(0.08, 0.6), Vector2(0.3, 0.28)],
		["Dessert Table", Color(0.92, 0.78, 0.65), Vector2(0.42, 0.55), Vector2(0.48, 0.32)],
	]
	for s in stations:
		var panel := Panel.new()
		var style := StyleBoxFlat.new()
		style.bg_color = s[1]
		style.set_corner_radius_all(12)
		style.border_color = SugarStreetColors.SOFT_BORDER
		style.set_border_width_all(2)
		panel.add_theme_stylebox_override("panel", style)
		host.add_child(panel)
		panel.set_meta("ap", s[2])
		panel.set_meta("as", s[3])
		var label := Label.new()
		label.text = s[0]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", SugarStreetColors.DARK_TEXT)
		panel.add_child(label)
	host.resized.connect(func(): _layout_interior(host))
	call_deferred("_layout_interior", host)


func _layout_interior(host: Control) -> void:
	for child in host.get_children():
		if child.has_meta("ap"):
			var ap: Vector2 = child.get_meta("ap")
			var asz: Vector2 = child.get_meta("as")
			child.position = Vector2(host.size.x * ap.x, host.size.y * ap.y)
			child.size = Vector2(host.size.x * asz.x, host.size.y * asz.y)


func _action_card(parent: Control, title: String, icon: String, cb: Callable) -> void:
	var btn := Button.new()
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 72)
	btn.text = "%s\n%s" % [icon, title]
	ThemeFactory.apply_button_styles(btn, {
		"normal": ThemeFactory._btn(SugarStreetColors.SOFT_IVORY, 16),
		"hover": ThemeFactory._btn(SugarStreetColors.WARM_CREAM, 16),
		"pressed": ThemeFactory._btn(SugarStreetColors.SOFT_PEACH, 16),
		"disabled": ThemeFactory._btn(SugarStreetColors.DISABLED_FILL, 16),
		"focus": ThemeFactory._btn(SugarStreetColors.SOFT_IVORY, 16, true),
	}, SugarStreetColors.DARK_TEXT)
	btn.pressed.connect(func():
		UiMotion.press_scale(btn)
		AudioManager.play_button()
		cb.call()
	)
	parent.add_child(btn)


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


func _on_menu() -> void:
	_confirm.show_confirm("Menu", "Settings, title, and account options live here.", "Settings", "Close")
	if not _confirm.confirmed.is_connected(_on_settings):
		_confirm.confirmed.connect(_on_settings, CONNECT_ONE_SHOT)


func _on_settings() -> void:
	_confirm.show_confirm("Settings", "Music and SFX toggles expand here.", "OK", "Close")


func _on_nav_tab(tab_id: String) -> void:
	if tab_id == BottomNavigation.TAB_EVENTS:
		_coming_soon("Events")


func _coming_soon(feature: String) -> void:
	_confirm.show_confirm("Coming Soon", "%s unlocks later." % feature, "OK", "Close")


func _refresh_badges() -> void:
	var ready := 0
	for order in GameState.get_visible_orders():
		if GameState.get_order_status(str(order.order_id)) == SaveData.OrderStatus.READY_TO_COMPLETE:
			ready += 1
	if _orders_badge:
		_orders_badge.set_count(ready if ready > 0 else GameState.get_visible_orders().size())
