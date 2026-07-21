extends Control
## Primary shop hub: stats, visual shop, orders, navigation.

@onready var shop_name_label: Label = %ShopNameLabel
@onready var player_level_label: Label = %PlayerLevelLabel
@onready var xp_label: Label = %XpLabel
@onready var coins_label: Label = %CoinsLabel
@onready var stars_label: Label = %StarsLabel
@onready var reputation_label: Label = %ReputationLabel
@onready var shop_level_label: Label = %ShopLevelLabel
@onready var orders_box: VBoxContainer = %OrdersBox
@onready var shop_visual_host: Control = %ShopVisualHost
@onready var popup_host: Control = %PopupHost
@onready var debug_host: Control = %DebugHost

@onready var recipe_button: Button = %RecipeButton
@onready var upgrade_button: Button = %UpgradeButton
@onready var inventory_button: Button = %InventoryButton
@onready var settings_button: Button = %SettingsButton
@onready var workers_button: Button = %WorkersButton
@onready var locations_button: Button = %LocationsButton
@onready var play_button: Button = %PlayButton
@onready var title_button: Button = %TitleButton

var _visual: ShopVisual
var _confirm: ConfirmPopup
var _order_detail: OrderDetailPopup
var _reward_popup: RewardPopup
var _level_up_popup: LevelUpPopup
var _debug_panel: ShopDebugPanel
var _recipe_badge: NotificationBadge
var _upgrade_badge: NotificationBadge
var _order_badges: Dictionary = {}


func _ready() -> void:
	_visual = ShopVisual.new()
	_visual.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shop_visual_host.add_child(_visual)

	_confirm = ConfirmPopup.new()
	popup_host.add_child(_confirm)
	_order_detail = OrderDetailPopup.new()
	popup_host.add_child(_order_detail)
	_reward_popup = RewardPopup.new()
	popup_host.add_child(_reward_popup)
	_level_up_popup = LevelUpPopup.new()
	popup_host.add_child(_level_up_popup)

	_recipe_badge = NotificationBadge.new()
	recipe_button.add_child(_recipe_badge)
	_recipe_badge.position = Vector2(recipe_button.size.x - 18, -4)
	_upgrade_badge = NotificationBadge.new()
	upgrade_button.add_child(_upgrade_badge)

	if GameState.DEBUG_TOOLS_ENABLED and OS.is_debug_build():
		_debug_panel = ShopDebugPanel.new()
		debug_host.add_child(_debug_panel)

	recipe_button.pressed.connect(func():
		AudioManager.play_button()
		SceneRouter.go_recipe_book()
	)
	upgrade_button.pressed.connect(func():
		AudioManager.play_button()
		SceneRouter.go_upgrades()
	)
	inventory_button.pressed.connect(func():
		AudioManager.play_button()
		SceneRouter.go_inventory()
	)
	settings_button.pressed.connect(_on_settings)
	title_button.pressed.connect(_on_title)
	play_button.pressed.connect(_on_play_selected)
	workers_button.disabled = true
	workers_button.text = "Workers (Locked)"
	locations_button.disabled = true
	locations_button.text = "Locations (Locked)"

	_order_detail.start_pressed.connect(_start_order)
	_order_detail.complete_pressed.connect(_complete_order)
	_reward_popup.continue_pressed.connect(_after_reward)
	_level_up_popup.continue_pressed.connect(func(): pass)

	GameState.state_changed.connect(refresh)
	GameState.notifications_changed.connect(_refresh_badges)
	AudioManager.play(AudioManager.Sfx.SHOP_OPENED)
	refresh()
	_refresh_badges()


func refresh() -> void:
	var d := GameState.data
	shop_name_label.text = d.shop_name
	player_level_label.text = "Player Lv.%d" % d.player_level
	var need := PlayerProgression.xp_required_for_next_level(d.player_level)
	xp_label.text = "XP %d / %d" % [d.experience, need]
	coins_label.text = "Coins %s" % RewardCalculator.format_coins(d.coins)
	stars_label.text = "Stars %d" % d.stars
	reputation_label.text = "Rep %d" % d.reputation
	shop_level_label.text = "Shop Lv.%d" % d.shop_level
	_rebuild_orders()
	if _visual:
		_visual.refresh()


func _rebuild_orders() -> void:
	for child in orders_box.get_children():
		child.queue_free()
	_order_badges.clear()
	for order in GameState.get_visible_orders():
		var status := GameState.get_order_status(str(order.order_id))
		var card := _make_order_card(order, status)
		orders_box.add_child(card)


func _make_order_card(order: OrderTemplate, status: int) -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.92)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	style.content_margin_left = 10
	style.content_margin_top = 8
	style.content_margin_right = 10
	style.content_margin_bottom = 8
	if status == SaveData.OrderStatus.READY_TO_COMPLETE:
		style.border_color = Color(0.3, 0.75, 0.55)
		style.border_width_left = 3
		style.border_width_top = 3
		style.border_width_right = 3
		style.border_width_bottom = 3
	elif status == SaveData.OrderStatus.FAILED:
		style.border_color = Color(0.85, 0.4, 0.4)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
	panel.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	panel.add_child(hbox)

	var avatar := ColorRect.new()
	avatar.custom_minimum_size = Vector2(44, 44)
	avatar.color = order.customer_color
	hbox.add_child(avatar)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)
	var recipe := GameState.catalog.get_recipe(order.recipe_id)
	var title := Label.new()
	title.text = "%s · %s" % [order.customer_name, recipe.display_name if recipe else str(order.recipe_id)]
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)
	var meta := Label.new()
	meta.text = "%s · %s · %s coins" % [order.difficulty_label(), order.level_id, RewardCalculator.format_coins(order.coin_reward)]
	meta.add_theme_font_size_override("font_size", 12)
	meta.add_theme_color_override("font_color", Color(0.35, 0.3, 0.32))
	vbox.add_child(meta)
	var status_label := Label.new()
	status_label.text = _status_text(status)
	status_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(status_label)

	var action := Button.new()
	action.custom_minimum_size = Vector2(110, 40)
	if status == SaveData.OrderStatus.READY_TO_COMPLETE:
		action.text = "Complete"
		action.pressed.connect(func(): _complete_order(str(order.order_id)))
	elif status == SaveData.OrderStatus.FAILED:
		action.text = "Retry"
		action.pressed.connect(func(): _open_order(str(order.order_id)))
	else:
		action.text = "View"
		action.pressed.connect(func(): _open_order(str(order.order_id)))
	hbox.add_child(action)

	if status == SaveData.OrderStatus.READY_TO_COMPLETE:
		var badge := NotificationBadge.new()
		panel.add_child(badge)
		badge.set_count(1)
		badge.position = Vector2(4, 4)
		_order_badges[str(order.order_id)] = badge
	return panel


func _status_text(status: int) -> String:
	match status:
		SaveData.OrderStatus.AVAILABLE: return "Available"
		SaveData.OrderStatus.SELECTED: return "Selected"
		SaveData.OrderStatus.LEVEL_IN_PROGRESS: return "In Progress"
		SaveData.OrderStatus.READY_TO_COMPLETE: return "Ready to Complete!"
		SaveData.OrderStatus.COMPLETED: return "Completed"
		SaveData.OrderStatus.FAILED: return "Failed — retry available"
		SaveData.OrderStatus.EXPIRED: return "Expired"
	return "Unknown"


func _open_order(order_id: String) -> void:
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


func _after_reward() -> void:
	var ups := GameState.consume_pending_level_ups()
	if not ups.is_empty():
		# Show the highest level-up if multiple.
		var last: Dictionary = ups[ups.size() - 1]
		AudioManager.play(AudioManager.Sfx.LEVEL_UP)
		_level_up_popup.show_level_up(int(last["new_level"]), int(last["coin_reward"]), _features_for_level(int(last["new_level"])))
	refresh()


func _features_for_level(level: int) -> String:
	var unlocked: PackedStringArray = []
	for id in GameState.catalog.recipes.keys():
		var recipe: RecipeData = GameState.catalog.recipes[id]
		if recipe.required_player_level == level and not recipe.unlocked_by_default:
			unlocked.append(recipe.display_name + " (can unlock)")
	if unlocked.is_empty():
		return "Keep serving customers to grow Sugar Street!"
	return "Newly available: " + ", ".join(unlocked)


func _on_play_selected() -> void:
	AudioManager.play_button()
	# Start first available / selected / failed order, or ready-to-complete prompt.
	for order in GameState.get_visible_orders():
		var status := GameState.get_order_status(str(order.order_id))
		if status == SaveData.OrderStatus.READY_TO_COMPLETE:
			_complete_order(str(order.order_id))
			return
	for order in GameState.get_visible_orders():
		var status := GameState.get_order_status(str(order.order_id))
		if status in [SaveData.OrderStatus.AVAILABLE, SaveData.OrderStatus.SELECTED, SaveData.OrderStatus.FAILED]:
			_open_order(str(order.order_id))
			return


func _on_settings() -> void:
	AudioManager.play_button()
	_confirm.show_confirm("Settings", "Audio hooks are active via AudioManager. Full settings UI comes later.", "OK", "Close")


func _on_title() -> void:
	AudioManager.play_button()
	GameState.save_now()
	SceneRouter.go_title()


func _refresh_badges() -> void:
	_recipe_badge.set_count(GameState.recipe_unlock_available_count())
	_upgrade_badge.set_count(GameState.affordable_upgrade_count())
	# Reposition after layout.
	_recipe_badge.position = Vector2(maxf(recipe_button.size.x - 18, 60), -4)
	_upgrade_badge.position = Vector2(maxf(upgrade_button.size.x - 18, 60), -4)
