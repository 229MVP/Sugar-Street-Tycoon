extends Control
## Equipment upgrades with visible benefit cards.


const SettingsPopupScene := preload("res://scripts/ui/settings_popup.gd")

var _list: VBoxContainer
var _confirm: ConfirmPopup
var _settings: Control
var _top_bar: TopResourceBar
var _feedback: Label
var _pending_id: StringName = &""


func _ready() -> void:
	theme = ThemeFactory.build()
	_build()
	GameState.state_changed.connect(_rebuild)
	_rebuild()


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
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		safe.add_theme_constant_override(m, 12 if m != "margin_bottom" else 8)
	add_child(safe)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	safe.add_child(vbox)

	_top_bar = TopResourceBar.new()
	vbox.add_child(_top_bar)
	_top_bar.menu_pressed.connect(func(): _settings.call("show_settings"))

	var title := Label.new()
	title.text = "Bakery Upgrades"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", SugarStreetColors.BAKERY_BROWN)
	vbox.add_child(title)

	_feedback = Label.new()
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback.add_theme_color_override("font_color", SugarStreetColors.WOOD_BROWN)
	vbox.add_child(_feedback)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_list)

	var back := Button.new()
	back.text = "Back to Shop"
	back.custom_minimum_size = Vector2(0, 44)
	ThemeFactory.apply_button_styles(back, ThemeFactory.secondary_button_styles())
	back.pressed.connect(func(): SceneRouter.go_shop())
	vbox.add_child(back)

	var nav := BottomNavigation.new()
	nav.selected_tab = BottomNavigation.TAB_SHOP
	vbox.add_child(nav)

	_confirm = ConfirmPopup.new()
	add_child(_confirm)
	_settings = SettingsPopupScene.new()
	add_child(_settings)


func _rebuild() -> void:
	if _list == null:
		return
	for c in _list.get_children():
		c.queue_free()
	_feedback.text = "Coins: %s · Equipment bonuses apply to order rewards." % RewardCalculator.format_coins(GameState.data.coins)
	for id in [&"oven", &"mixer", &"display_case", &"checkout"]:
		var eq := GameState.catalog.get_equipment(id)
		if eq == null:
			continue
		_list.add_child(_make_card(eq))


func _make_card(eq: EquipmentData) -> PanelContainer:
	var level := GameState.get_equipment_level(eq.equipment_id)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", ThemeFactory._card(SugarStreetColors.SOFT_IVORY, 16))
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	card.add_child(root)

	var name_l := Label.new()
	name_l.text = eq.display_name
	name_l.add_theme_font_size_override("font_size", 18)
	name_l.add_theme_color_override("font_color", SugarStreetColors.BAKERY_BROWN)
	root.add_child(name_l)

	var lvl := Label.new()
	lvl.text = "Level %d / %d · Next: %d" % [level, eq.max_level, mini(level + 1, eq.max_level)]
	lvl.add_theme_color_override("font_color", SugarStreetColors.WOOD_BROWN)
	root.add_child(lvl)

	var current := Label.new()
	current.text = "Current: %s" % _bonus_text(eq.equipment_id, level)
	current.add_theme_color_override("font_color", SugarStreetColors.DARK_TEXT)
	root.add_child(current)
	var nxt := Label.new()
	nxt.text = "Next: %s" % _bonus_text(eq.equipment_id, mini(level + 1, eq.max_level))
	nxt.add_theme_color_override("font_color", SugarStreetColors.DARK_TEXT)
	root.add_child(nxt)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 44)
	if level >= eq.max_level:
		btn.text = "Maximum Level"
		btn.disabled = true
	else:
		var check := GameState.can_upgrade_equipment(eq.equipment_id)
		var cost := eq.upgrade_cost_to(level + 1)
		btn.text = "Upgrade for %s" % RewardCalculator.format_coins(cost)
		btn.disabled = not check.get("ok", false)
		btn.pressed.connect(_confirm_upgrade.bind(eq.equipment_id))
	ThemeFactory.apply_button_styles(btn, ThemeFactory.primary_button_styles())
	root.add_child(btn)
	return card


func _bonus_text(equipment_id: StringName, level: int) -> String:
	match str(equipment_id):
		"oven":
			return "+%d%% order coins" % int(RewardCalculator.oven_bonus_percent(level) * 100.0)
		"mixer":
			return "+%d%% order XP" % int(RewardCalculator.mixer_bonus_percent(level) * 100.0)
		"display_case":
			return "+%d%% reputation" % int(RewardCalculator.display_bonus_percent(level) * 100.0)
		"checkout":
			return "+%d%% all rewards" % int(RewardCalculator.checkout_bonus_percent(level) * 100.0)
	return "—"


func _confirm_upgrade(equipment_id: StringName) -> void:
	var eq := GameState.catalog.get_equipment(equipment_id)
	var level := GameState.get_equipment_level(equipment_id)
	var cost := eq.upgrade_cost_to(level + 1)
	_pending_id = equipment_id
	_confirm.show_confirm(
		"Upgrade Equipment?",
		"Spend %s coins to upgrade %s to level %d?" % [RewardCalculator.format_coins(cost), eq.display_name, level + 1],
		"Upgrade",
		"Cancel"
	)
	if not _confirm.confirmed.is_connected(_do_upgrade):
		_confirm.confirmed.connect(_do_upgrade, CONNECT_ONE_SHOT)


func _do_upgrade() -> void:
	var result := GameState.upgrade_equipment(_pending_id)
	if result.get("ok", false):
		AudioManager.play(AudioManager.Sfx.EQUIPMENT_UPGRADED)
		_feedback.text = "Upgraded to level %d!" % int(result.get("new_level", 0))
	else:
		_feedback.text = str(result.get("reason", "Upgrade failed."))
	_rebuild()
