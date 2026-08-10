class_name BottomNavigation
extends Control
## Shared bottom tabs: Shop, Inventory, Customers, Events.


signal tab_selected(tab_id: String)

const TAB_SHOP := "shop"
const TAB_INVENTORY := "inventory"
const TAB_ORDERS := "orders"
const TAB_CUSTOMERS := TAB_ORDERS
const TAB_EVENTS := "events"
const TAB_RECIPES := "recipes" ## Kept for older screens; not shown in the bar.

var _buttons: Dictionary = {}
var _badges: Dictionary = {}
var _confirm: ConfirmPopup
var selected_tab: String = TAB_SHOP


func _ready() -> void:
	custom_minimum_size = Vector2(0, 72)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build()
	set_selected(selected_tab)
	_refresh_badges()
	var gs := get_node_or_null("/root/GameState")
	if gs:
		if not gs.notifications_changed.is_connected(_refresh_badges):
			gs.notifications_changed.connect(_refresh_badges)
		if not gs.state_changed.is_connected(_refresh_badges):
			gs.state_changed.connect(_refresh_badges)


func _build() -> void:
	while get_child_count() > 0:
		var child := get_child(0)
		remove_child(child)
		child.free()

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := ThemeFactory._card(SugarStreetColors.SOFT_IVORY, 18)
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	style.content_margin_left = 6
	style.content_margin_right = 6
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	panel.add_child(row)

	_add_tab(row, TAB_SHOP, "◆", "Shop")
	_add_tab(row, TAB_INVENTORY, "■", "Inventory")
	_add_tab(row, TAB_CUSTOMERS, "●", "Customers")
	_add_tab(row, TAB_EVENTS, "▲", "Events")

	_confirm = ConfirmPopup.new()
	add_child(_confirm)


func _add_tab(parent: HBoxContainer, id: String, icon: String, label: String) -> void:
	var btn := Button.new()
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(44, 56)
	btn.text = ""
	btn.pressed.connect(func(): _on_tab(id))
	parent.add_child(btn)
	_buttons[id] = btn
	var content := VBoxContainer.new()
	content.name = "Content"
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 0)
	btn.add_child(content)
	var icon_margin := MarginContainer.new()
	icon_margin.name = "IconMargin"
	icon_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	icon_margin.add_theme_constant_override("margin_left", 2)
	# Reserve the widest 99+ pill, its inset, and the small bounce scale.
	icon_margin.add_theme_constant_override("margin_right", 42)
	content.add_child(icon_margin)
	var icon_label := Label.new()
	icon_label.name = "IconLabel"
	icon_label.text = icon
	icon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", 12)
	icon_margin.add_child(icon_label)
	var copy := Label.new()
	copy.name = "ContentLabel"
	copy.text = label
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.size_flags_vertical = Control.SIZE_EXPAND_FILL
	copy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	copy.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	copy.add_theme_font_size_override("font_size", 11)
	content.add_child(copy)
	var badge := NotificationBadgeView.new()
	btn.add_child(badge)
	badge.place_top_right(2.0)
	_badges[id] = badge


func set_selected(tab_id: String) -> void:
	selected_tab = tab_id
	for id in _buttons.keys():
		var btn: Button = _buttons[id]
		if id == tab_id:
			ThemeFactory.apply_button_styles(btn, ThemeFactory.primary_button_styles(), SugarStreetColors.WHITE)
		else:
			ThemeFactory.apply_button_styles(btn, ThemeFactory.soft_button_styles(), SugarStreetColors.DARK_TEXT)
		var copy := btn.get_node_or_null("Content/ContentLabel") as Label
		if copy:
			copy.add_theme_color_override("font_color", SugarStreetColors.WHITE if id == tab_id else SugarStreetColors.DARK_TEXT)
		var icon_copy := btn.get_node_or_null("Content/IconMargin/IconLabel") as Label
		if icon_copy:
			icon_copy.add_theme_color_override("font_color", SugarStreetColors.WHITE if id == tab_id else SugarStreetColors.DARK_TEXT)
		btn.custom_minimum_size = Vector2(44, 56)


func _on_tab(tab_id: String) -> void:
	UiMotion.press_scale(_buttons[tab_id])
	var audio := get_node_or_null("/root/AudioManager")
	if audio:
		audio.play_button()
	var router := get_node_or_null("/root/SceneRouter")
	match tab_id:
		TAB_SHOP:
			set_selected(tab_id)
			tab_selected.emit(tab_id)
			if router:
				router.go_shop()
		TAB_INVENTORY:
			set_selected(tab_id)
			tab_selected.emit(tab_id)
			if router:
				router.go_inventory()
		TAB_ORDERS, TAB_CUSTOMERS:
			set_selected(tab_id)
			tab_selected.emit(tab_id)
			if router:
				router.go_orders()
		TAB_EVENTS:
			if _confirm:
				_confirm.show_confirm("Coming Soon", "Events unlock later.", "OK", "Close")
		TAB_RECIPES:
			if router:
				router.go_recipe_book()


func _refresh_badges() -> void:
	var gs := get_node_or_null("/root/GameState")
	if gs == null:
		return
	var ready := 0
	var available := 0
	for order in gs.get_visible_orders():
		var st: int = int(gs.get_order_status(str(order.order_id)))
		if st == SaveData.OrderStatus.READY_TO_COMPLETE:
			ready += 1
		elif st in [SaveData.OrderStatus.AVAILABLE, SaveData.OrderStatus.FAILED, SaveData.OrderStatus.SELECTED]:
			available += 1
	if _badges.has(TAB_CUSTOMERS):
		_badges[TAB_CUSTOMERS].set_count(ready if ready > 0 else available)
	if _badges.has(TAB_SHOP):
		_badges[TAB_SHOP].set_count(gs.affordable_upgrade_count())
	if _badges.has(TAB_INVENTORY):
		_badges[TAB_INVENTORY].set_count(0)
	if _badges.has(TAB_EVENTS):
		_badges[TAB_EVENTS].set_count(0)
