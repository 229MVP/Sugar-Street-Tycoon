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
var _offline_popup: OfflineEarningsPopup
var _passive_panel: PassiveIncomePanel
var _activity: ShopActivityController
var _worker_info: ConfirmPopup
var _debug_panel: ShopDebugPanel
var _recipe_badge: NotificationBadge
var _upgrade_badge: NotificationBadge
var _workers_badge: NotificationBadge
var _order_badges: Dictionary = {}
var _worker_status_label: Label
var _passive_timer: float = 0.0


func _ready() -> void:
	_visual = ShopVisual.new()
	_visual.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shop_visual_host.add_child(_visual)
	_visual.worker_selected.connect(_on_shop_worker_selected)

	_activity = ShopActivityController.new()
	add_child(_activity)
	_activity.setup(shop_visual_host)

	_passive_panel = PassiveIncomePanel.new()
	_passive_panel.custom_minimum_size = Vector2(0, 110)
	# Insert above orders.
	var vbox := shop_name_label.get_parent().get_parent() # Header -> VBox
	if vbox is VBoxContainer:
		var orders_title_idx := -1
		for i in vbox.get_child_count():
			var child := vbox.get_child(i)
			if child is Label and (child as Label).text.begins_with("Customer"):
				orders_title_idx = i
				break
		if orders_title_idx >= 0:
			vbox.add_child(_passive_panel)
			vbox.move_child(_passive_panel, orders_title_idx)
		else:
			vbox.add_child(_passive_panel)

	_worker_status_label = Label.new()
	_worker_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_worker_status_label.add_theme_font_size_override("font_size", 12)
	shop_level_label.get_parent().add_child(_worker_status_label)

	_confirm = ConfirmPopup.new()
	popup_host.add_child(_confirm)
	_worker_info = ConfirmPopup.new()
	popup_host.add_child(_worker_info)
	_order_detail = OrderDetailPopup.new()
	popup_host.add_child(_order_detail)
	_reward_popup = RewardPopup.new()
	popup_host.add_child(_reward_popup)
	_level_up_popup = LevelUpPopup.new()
	popup_host.add_child(_level_up_popup)
	_offline_popup = OfflineEarningsPopup.new()
	popup_host.add_child(_offline_popup)

	_recipe_badge = NotificationBadge.new()
	recipe_button.add_child(_recipe_badge)
	_upgrade_badge = NotificationBadge.new()
	upgrade_button.add_child(_upgrade_badge)
	_workers_badge = NotificationBadge.new()
	workers_button.add_child(_workers_badge)

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
	workers_button.disabled = true
	workers_button.text = "Workers (Coming Soon)"
	locations_button.disabled = true
	locations_button.text = "Locations (Coming Soon)"
	settings_button.pressed.connect(_on_settings)
	title_button.pressed.connect(_on_title)
	play_button.pressed.connect(_on_play_selected)

	_order_detail.start_pressed.connect(_start_order)
	_order_detail.complete_pressed.connect(_complete_order)
	_reward_popup.continue_pressed.connect(_after_reward)
	_level_up_popup.continue_pressed.connect(func(): pass)
	_offline_popup.collected.connect(func():
		_passive_panel.refresh()
		refresh()
	)

	GameState.state_changed.connect(refresh)
	GameState.notifications_changed.connect(_refresh_badges)
	GameState.passive_income_changed.connect(func(_s, _r): _passive_panel.refresh())
	GameState.offline_earnings_ready.connect(_on_offline_ready)
	set_process(true)
	AudioManager.play(AudioManager.Sfx.SHOP_OPENED)
	refresh()
	_refresh_badges()
	# Show pending offline popup if present from load.
	if not GameState.data.offline_pending_popup.is_empty():
		_on_offline_ready(GameState.data.offline_pending_popup)


func _process(delta: float) -> void:
	_passive_timer += delta
	if _passive_timer >= 1.0:
		_passive_timer = 0.0
		GameState.tick_passive_income()
		if _passive_panel:
			_passive_panel.refresh()
	var modal_open := _order_detail.visible or _reward_popup.visible or _confirm.visible or _offline_popup.visible or _level_up_popup.visible
	if _activity:
		_activity.set_paused(modal_open)


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
	if _worker_status_label:
		_worker_status_label.text = "Workers assigned: %d / 6" % GameState.get_assigned_worker_count()
	_rebuild_orders()
	if _visual:
		_visual.refresh()
	if _passive_panel:
		_passive_panel.refresh()


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
	style.bg_color = Color(1, 1, 1, 0.94)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	style.content_margin_left = 10
	style.content_margin_top = 8
	style.content_margin_right = 10
	style.content_margin_bottom = 8
	if status == SaveData.OrderStatus.READY_TO_COMPLETE:
		style.bg_color = Color(0.88, 0.98, 0.92, 1)
		style.border_color = Color(0.25, 0.7, 0.5)
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
	avatar.custom_minimum_size = Vector2(48, 48)
	avatar.color = order.customer_color
	hbox.add_child(avatar)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)
	var recipe := GameState.catalog.get_recipe(order.recipe_id)
	var title := Label.new()
	title.text = "%s" % order.customer_name
	title.add_theme_font_size_override("font_size", 17)
	vbox.add_child(title)
	var recipe_label := Label.new()
	recipe_label.text = "Recipe: %s" % (recipe.display_name if recipe else str(order.recipe_id))
	recipe_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(recipe_label)
	var objective := Label.new()
	objective.text = "Objective: %s" % order.objective_text()
	objective.add_theme_font_size_override("font_size", 12)
	objective.add_theme_color_override("font_color", Color(0.35, 0.3, 0.32))
	vbox.add_child(objective)
	var moves := Label.new()
	moves.text = "Moves: %d" % (order.move_limit if order.move_limit > 0 else 20)
	moves.add_theme_font_size_override("font_size", 12)
	moves.add_theme_color_override("font_color", Color(0.35, 0.3, 0.32))
	vbox.add_child(moves)
	var rewards := Label.new()
	rewards.text = "Rewards: %s coins · %d XP · %d rep" % [
		RewardCalculator.format_coins(order.coin_reward),
		order.experience_reward,
		order.reputation_reward,
	]
	rewards.add_theme_font_size_override("font_size", 12)
	rewards.add_theme_color_override("font_color", Color(0.4, 0.32, 0.28))
	vbox.add_child(rewards)
	var status_label := Label.new()
	status_label.text = _status_text(status)
	status_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(status_label)

	var action := Button.new()
	action.custom_minimum_size = Vector2(120, 44)
	if status == SaveData.OrderStatus.READY_TO_COMPLETE:
		action.text = "Complete Order"
		action.pressed.connect(func(): _complete_order(str(order.order_id)))
	elif status == SaveData.OrderStatus.FAILED:
		action.text = "Start Order"
		action.pressed.connect(func(): _start_order(str(order.order_id)))
	elif status == SaveData.OrderStatus.COMPLETED:
		action.text = "Done"
		action.disabled = true
	else:
		action.text = "Start Order"
		action.pressed.connect(func(): _start_order(str(order.order_id)))
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
	# Workers badge priority: offline/full storage > hire > upgrade > empty station
	var worker_count := 0
	var info := GameState.get_passive_income_info()
	if bool(info.get("storage_full", false)) or float(info.get("stored", 0.0)) >= 1.0:
		worker_count = maxi(worker_count, 1)
	worker_count = maxi(worker_count, GameState.worker_hire_available_count())
	if worker_count == 0:
		worker_count = GameState.worker_upgrade_available_count()
	if worker_count == 0:
		worker_count = GameState.empty_compatible_station_count()
	_workers_badge.set_count(worker_count)
	_recipe_badge.position = Vector2(maxf(recipe_button.size.x - 18, 60), -4)
	_upgrade_badge.position = Vector2(maxf(upgrade_button.size.x - 18, 60), -4)
	_workers_badge.position = Vector2(maxf(workers_button.size.x - 18, 60), -4)


func _on_offline_ready(payload: Dictionary) -> void:
	if payload.is_empty():
		return
	_offline_popup.show_payload(payload)


func _on_shop_worker_selected(worker_id: StringName) -> void:
	var worker := GameState.catalog.get_worker(worker_id)
	if worker == null:
		return
	var level := GameState.get_worker_level(worker_id)
	_worker_info.show_confirm(
		worker.display_name,
		"%s · Lv.%d\n%s\nStation: %s" % [worker.role_label(), level, worker.description, worker.station_label()],
		"OK",
		"Close"
	)
