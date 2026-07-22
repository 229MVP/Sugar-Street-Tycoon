class_name ShopLevelUpgradePopup
extends Control
## Confirms shop-level upgrade requirements and rewards.


signal upgraded(new_level: int)
signal cancelled

var _panel: PanelContainer
var _title: Label
var _body: Label
var _upgrade: Button


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.08, 0.1, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(340, 420)
	_panel.add_theme_stylebox_override("panel", ThemeFactory._card(SugarStreetColors.SOFT_IVORY, 18))
	center.add_child(_panel)
	var margin := MarginContainer.new()
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(m, 16)
	_panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 22)
	_title.add_theme_color_override("font_color", SugarStreetColors.BAKERY_BROWN)
	vbox.add_child(_title)
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_color_override("font_color", SugarStreetColors.DARK_TEXT)
	vbox.add_child(_body)
	_upgrade = Button.new()
	_upgrade.text = "Upgrade Shop"
	_upgrade.custom_minimum_size = Vector2(0, 48)
	ThemeFactory.apply_button_styles(_upgrade, ThemeFactory.primary_button_styles())
	_upgrade.pressed.connect(_on_upgrade)
	vbox.add_child(_upgrade)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.custom_minimum_size = Vector2(0, 44)
	ThemeFactory.apply_button_styles(cancel, ThemeFactory.secondary_button_styles())
	cancel.pressed.connect(func():
		hide_popup()
		cancelled.emit()
	)
	vbox.add_child(cancel)


func show_upgrade() -> void:
	var check := GameState.can_upgrade_shop_level()
	var current := GameState.data.shop_level
	if current >= ShopLevelRules.MAX_SHOP_LEVEL:
		_title.text = "Shop Maxed"
		_body.text = "Your bakery is already Shop Level 5."
		_upgrade.disabled = true
	else:
		var next_level := current + 1
		var req: Dictionary = ShopLevelRules.requirements_for(next_level)
		_title.text = "Upgrade to Shop Level %d" % next_level
		_body.text = "\n".join([
			"Current: Shop Level %d" % current,
			"Next: Shop Level %d" % next_level,
			"",
			"Requires player level %d" % int(req.get("player_level", 1)),
			"Requires %s coins" % RewardCalculator.format_coins(int(req.get("coins", 0))),
			"Requires %d reputation (kept)" % int(req.get("reputation", 0)),
			"Requires %d Appeal (kept)" % int(req.get("appeal", 0)),
			"",
			"Unlocks slots: %s" % ", ".join(req.get("slots", [])),
			str(req.get("note", "")),
			"",
			"You have: Lv%d · %s coins · %d rep · %d Appeal" % [
				GameState.data.player_level,
				RewardCalculator.format_coins(GameState.data.coins),
				GameState.data.reputation,
				GameState.get_shop_appeal(),
			],
			"" if check.get("ok", false) else ("Blocked: %s" % check.get("reason", "")),
		])
		_upgrade.disabled = not check.get("ok", false)
	visible = true
	if not bool(GameState.data.settings.get("reduce_motion", false)):
		UiMotion.popup_in(self, _panel)
	AudioManager.play_popup()


func hide_popup() -> void:
	visible = false


func _on_upgrade() -> void:
	var result := GameState.upgrade_shop_level()
	if not result.get("ok", false):
		_body.text = str(result.get("reason", "Upgrade failed."))
		return
	AudioManager.play(AudioManager.Sfx.SHOP_LEVEL_UPGRADED)
	hide_popup()
	upgraded.emit(int(result.get("new_level", GameState.data.shop_level)))
