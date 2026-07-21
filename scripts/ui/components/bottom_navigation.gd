class_name BottomNavigation
extends Control
## Shared bottom tabs: Shop, Inventory, Customers, Events.


signal tab_selected(tab_id: String)

const TAB_SHOP := "shop"
const TAB_INVENTORY := "inventory"
const TAB_CUSTOMERS := "customers"
const TAB_EVENTS := "events"

var _buttons: Dictionary = {}
var _badges: Dictionary = {}
var selected_tab: String = TAB_SHOP


func _ready() -> void:
	custom_minimum_size = Vector2(0, 64)
	_build()
	set_selected(selected_tab)
	_refresh_badges()
	if not GameState.notifications_changed.is_connected(_refresh_badges):
		GameState.notifications_changed.connect(_refresh_badges)
	if not GameState.state_changed.is_connected(_refresh_badges):
		GameState.state_changed.connect(_refresh_badges)


func _build() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style := ThemeFactory._card(SugarStreetColors.SOFT_IVORY, 18)
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	panel.add_child(row)
	_add_tab(row, TAB_SHOP, "Shop", "🏠")
	_add_tab(row, TAB_INVENTORY, "Inventory", "🎒")
	_add_tab(row, TAB_CUSTOMERS, "Customers", "👥")
	_add_tab(row, TAB_EVENTS, "Events", "🎉")


func _add_tab(parent: HBoxContainer, id: String, label: String, icon: String) -> void:
	var btn := Button.new()
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(44, 52)
	btn.text = "%s\n%s" % [icon, label]
	btn.add_theme_font_size_override("font_size", 12)
	btn.pressed.connect(func(): _on_tab(id))
	parent.add_child(btn)
	_buttons[id] = btn
	var badge := NotificationBadgeView.new()
	btn.add_child(badge)
	badge.position = Vector2(52, 2)
	_badges[id] = badge


func set_selected(tab_id: String) -> void:
	selected_tab = tab_id
	for id in _buttons.keys():
		var btn: Button = _buttons[id]
		if id == tab_id:
			ThemeFactory.apply_button_styles(btn, ThemeFactory.primary_button_styles(), SugarStreetColors.WHITE)
		else:
			ThemeFactory.apply_button_styles(btn, {
				"normal": ThemeFactory._btn(SugarStreetColors.WARM_CREAM, 14),
				"hover": ThemeFactory._btn(SugarStreetColors.SOFT_PEACH, 14),
				"pressed": ThemeFactory._btn(SugarStreetColors.SOFT_PEACH.darkened(0.05), 14),
				"disabled": ThemeFactory._btn(SugarStreetColors.DISABLED_FILL, 14),
				"focus": ThemeFactory._btn(SugarStreetColors.WARM_CREAM, 14, true),
			}, SugarStreetColors.DARK_TEXT)


func _on_tab(tab_id: String) -> void:
	UiMotion.press_scale(_buttons[tab_id])
	match tab_id:
		TAB_SHOP:
			set_selected(tab_id)
			tab_selected.emit(tab_id)
			SceneRouter.go_shop()
		TAB_INVENTORY:
			set_selected(tab_id)
			tab_selected.emit(tab_id)
			SceneRouter.go_inventory()
		TAB_CUSTOMERS:
			set_selected(tab_id)
			tab_selected.emit(tab_id)
			SceneRouter.go_orders()
		TAB_EVENTS:
			tab_selected.emit(tab_id)
			# Coming Soon — emit only; parent may show popup.


func _refresh_badges() -> void:
	var ready := 0
	var available := 0
	for order in GameState.get_visible_orders():
		var st := GameState.get_order_status(str(order.order_id))
		if st == SaveData.OrderStatus.READY_TO_COMPLETE:
			ready += 1
		elif st in [SaveData.OrderStatus.AVAILABLE, SaveData.OrderStatus.FAILED, SaveData.OrderStatus.SELECTED]:
			available += 1
	if _badges.has(TAB_CUSTOMERS):
		_badges[TAB_CUSTOMERS].set_count(ready if ready > 0 else available)
	if _badges.has(TAB_SHOP):
		_badges[TAB_SHOP].set_count(GameState.recipe_unlock_available_count() + GameState.affordable_upgrade_count())
