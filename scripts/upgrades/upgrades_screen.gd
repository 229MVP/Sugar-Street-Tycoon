extends Control
## Bakery upgrades — six data-driven upgrades sourced from UpgradeManager.
## Oven / Mixer / Display Case / Cash Register mirror legacy equipment bonuses;
## Decor / Lighting are new standalone effects (tip bonus, star reward bonus).


const SettingsPopupScene := preload("res://scripts/ui/settings_popup.gd")

var _list: VBoxContainer
var _confirm: ConfirmPopup
var _settings: Control
var _top_bar: TopResourceBar
var _feedback: Label
var _pending_id: String = ""


func _ready() -> void:
	theme = ThemeFactory.build()
	_build()
	GameState.state_changed.connect(_rebuild)
	if GameState.upgrades and not GameState.upgrades.upgrades_changed.is_connected(_rebuild):
		GameState.upgrades.upgrades_changed.connect(_rebuild)
	_rebuild()
	call_deferred("_show_feature_tip")


func _show_feature_tip() -> void:
	FeatureTipPresenter.maybe_show(self, "upgrades")


func _build() -> void:
	for c in get_children():
		c.queue_free()
	var bg := ColorRect.new()
	bg.color = SugarStreetColors.WARM_CREAM
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var safe := SafeAreaContainer.new()
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe.set_min_margins(12, 12, 12, 8)
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
	scroll.name = "UpgradeScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ScrollHelper.configure_vertical(scroll)
	vbox.add_child(scroll)
	_list = VBoxContainer.new()
	_list.name = "UpgradeList"
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
	if _list == null or not is_instance_valid(_list):
		return
	for c in _list.get_children():
		c.queue_free()
	_feedback.text = "Coins: %s · Upgrades apply immediately to bakery bonuses." % RewardCalculator.format_coins(GameState.data.coins)
	for id in GameState.upgrades.all_upgrade_ids():
		var def := GameState.upgrades.get_definition(id)
		if def == null:
			continue
		_list.add_child(_make_card(def))


func _make_card(def: UpgradeDefinition) -> PanelContainer:
	var level := GameState.upgrades.get_level(def.id)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", ThemeFactory._card(SugarStreetColors.SOFT_IVORY, 16))
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	card.add_child(root)

	# Placeholder icon chip — swappable for final art via `def.icon` later.
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	root.add_child(header)
	var icon := PanelContainer.new()
	icon.custom_minimum_size = Vector2(40, 40)
	var istyle := StyleBoxFlat.new()
	istyle.bg_color = def.fallback_color
	istyle.set_corner_radius_all(10)
	icon.add_theme_stylebox_override("panel", istyle)
	header.add_child(icon)

	var name_l := Label.new()
	name_l.text = def.display_name
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.add_theme_font_size_override("font_size", 18)
	name_l.add_theme_color_override("font_color", SugarStreetColors.BAKERY_BROWN)
	header.add_child(name_l)

	var lvl := Label.new()
	lvl.text = "Level %d / %d" % [level, def.max_level]
	lvl.add_theme_color_override("font_color", SugarStreetColors.WOOD_BROWN)
	root.add_child(lvl)

	var current := Label.new()
	current.text = "Current: %s" % _effect_text(def, level)
	current.add_theme_color_override("font_color", SugarStreetColors.DARK_TEXT)
	root.add_child(current)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 44)
	if level >= def.max_level:
		btn.text = "Maximum Level"
		btn.disabled = true
	else:
		var nxt := Label.new()
		nxt.text = "Next: %s" % _effect_text(def, level + 1)
		nxt.add_theme_color_override("font_color", SugarStreetColors.DARK_TEXT)
		root.add_child(nxt)
		var check := GameState.upgrades.can_purchase(def.id)
		var cost := def.cost_to_reach(level + 1)
		btn.text = "Upgrade for %s" % RewardCalculator.format_coins(cost)
		btn.disabled = not check.get("ok", false)
		btn.pressed.connect(_confirm_upgrade.bind(def.id))
	ThemeFactory.apply_button_styles(btn, ThemeFactory.primary_button_styles())
	root.add_child(btn)
	return card


func _effect_text(def: UpgradeDefinition, level: int) -> String:
	var value := def.effect_at_level(level)
	var pct := int(round(value * 100.0))
	match def.effect_type:
		UpgradeDefinition.EffectType.BAKING_SPEED:
			return "+%d%% order coins (faster baking)" % pct
		UpgradeDefinition.EffectType.BATCH_SIZE:
			return "+%d%% order XP (bigger batches)" % pct
		UpgradeDefinition.EffectType.COIN_REWARDS:
			return "+%d%% reputation" % pct
		UpgradeDefinition.EffectType.TRANSACTION_SPEED:
			return "+%d%% all order rewards" % pct
		UpgradeDefinition.EffectType.TIP_BONUS:
			return "+%d%% coin tips" % pct
		UpgradeDefinition.EffectType.STAR_REWARD_BONUS:
			return "+%d%% chance of a bonus star" % pct
	return "—"


func _confirm_upgrade(upgrade_id: String) -> void:
	var def := GameState.upgrades.get_definition(upgrade_id)
	var level := GameState.upgrades.get_level(upgrade_id)
	var cost := def.cost_to_reach(level + 1)
	_pending_id = upgrade_id
	_confirm.show_confirm(
		"Upgrade?",
		"Spend %s coins to upgrade %s to level %d?" % [RewardCalculator.format_coins(cost), def.display_name, level + 1],
		"Upgrade",
		"Cancel"
	)
	if not _confirm.confirmed.is_connected(_do_upgrade):
		_confirm.confirmed.connect(_do_upgrade, CONNECT_ONE_SHOT)


func _do_upgrade() -> void:
	var result := GameState.upgrades.purchase(_pending_id)
	if result.get("ok", false):
		AudioManager.play(AudioManager.Sfx.EQUIPMENT_UPGRADED)
		GameState.save_now()
		_feedback.text = "Upgraded to level %d!" % int(result.get("new_level", 0))
	else:
		_feedback.text = str(result.get("reason", "Upgrade failed."))
	_rebuild()
