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
	btn.text = "%s\n%s" % [icon, label]
	btn.add_theme_font_size_override("font_size", 12)
	btn.clip_text = false
	btn.pressed.connect(func(): _on_tab(id))
	parent.add_child(btn)
	_buttons[id] = btn
	var badge := NotificationBadgeView.new()
	btn.add_child(badge)
	badge.position = Vector2(4, 2)
	_badges[id] = badge


func set_selected(tab_id: String) -> void:
	selected_tab = tab_id
	for id in _buttons.keys():
		var btn: Button = _buttons[id]
		if id == tab_id:
			ThemeFactory.apply_button_styles(btn, ThemeFactory.primary_button_styles(), SugarStreetColors.WHITE)
		else:
			ThemeFactory.apply_button_styles(btn, ThemeFactory.soft_button_styles(), SugarStreetColors.DARK_TEXT)
		btn.add_theme_font_size_override("font_size", 12)
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
