class_name BottomNavigation
extends Control
## Shared bottom tabs: Shop, Orders, Recipes, Inventory.


signal tab_selected(tab_id: String)

const TAB_SHOP := "shop"
const TAB_ORDERS := "orders"
const TAB_RECIPES := "recipes"
const TAB_INVENTORY := "inventory"
## Legacy aliases used by older screens.
const TAB_CUSTOMERS := TAB_ORDERS
const TAB_EVENTS := "events"

var _buttons: Dictionary = {}
var _badges: Dictionary = {}
var selected_tab: String = TAB_SHOP


func _ready() -> void:
	custom_minimum_size = Vector2(0, 64)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build()
	set_selected(selected_tab)
	_refresh_badges()
	if not GameState.notifications_changed.is_connected(_refresh_badges):
		GameState.notifications_changed.connect(_refresh_badges)
	if not GameState.state_changed.is_connected(_refresh_badges):
		GameState.state_changed.connect(_refresh_badges)


func _build() -> void:
	for c in get_children():
		c.queue_free()
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := ThemeFactory._card(SugarStreetColors.SOFT_IVORY, 18)
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	panel.add_child(row)
	_add_tab(row, TAB_SHOP, "Shop")
	_add_tab(row, TAB_ORDERS, "Orders")
	_add_tab(row, TAB_RECIPES, "Recipes")
	_add_tab(row, TAB_INVENTORY, "Inventory")


func _add_tab(parent: HBoxContainer, id: String, label: String) -> void:
	var btn := Button.new()
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(44, 52)
	btn.text = label
	btn.add_theme_font_size_override("font_size", 13)
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


func _on_tab(tab_id: String) -> void:
	UiMotion.press_scale(_buttons[tab_id])
	set_selected(tab_id)
	tab_selected.emit(tab_id)
	match tab_id:
		TAB_SHOP:
			SceneRouter.go_shop()
		TAB_ORDERS, TAB_CUSTOMERS:
			SceneRouter.go_orders()
		TAB_RECIPES:
			SceneRouter.go_recipe_book()
		TAB_INVENTORY:
			SceneRouter.go_inventory()


func _refresh_badges() -> void:
	var ready := 0
	var available := 0
	for order in GameState.get_visible_orders():
		var st := GameState.get_order_status(str(order.order_id))
		if st == SaveData.OrderStatus.READY_TO_COMPLETE:
			ready += 1
		elif st in [SaveData.OrderStatus.AVAILABLE, SaveData.OrderStatus.FAILED, SaveData.OrderStatus.SELECTED]:
			available += 1
	if _badges.has(TAB_ORDERS):
		_badges[TAB_ORDERS].set_count(ready if ready > 0 else available)
	if _badges.has(TAB_RECIPES):
		_badges[TAB_RECIPES].set_count(GameState.recipe_unlock_available_count())
	if _badges.has(TAB_SHOP):
		_badges[TAB_SHOP].set_count(GameState.affordable_upgrade_count())
