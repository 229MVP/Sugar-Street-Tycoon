class_name DecorDetailsPopup
extends Control
## Purchase / place details for a single decoration.


signal purchased(decoration_id: String)
signal place_requested(decoration_id: String)
signal remove_requested(decoration_id: String)
signal closed

var _panel: PanelContainer
var _title: Label
var _body: Label
var _buy: Button
var _place: Button
var _remove: Button
var _decoration_id: String = ""
var _busy: bool = false


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
	_panel.custom_minimum_size = Vector2(340, 440)
	_panel.add_theme_stylebox_override("panel", ThemeFactory._card(SugarStreetColors.SOFT_IVORY, 18))
	center.add_child(_panel)
	var margin := MarginContainer.new()
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(m, 16)
	_panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
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
	_buy = Button.new()
	_buy.text = "Purchase"
	_buy.custom_minimum_size = Vector2(0, 48)
	ThemeFactory.apply_button_styles(_buy, ThemeFactory.primary_button_styles())
	_buy.pressed.connect(_on_buy)
	vbox.add_child(_buy)
	_place = Button.new()
	_place.text = "Place in Shop"
	_place.custom_minimum_size = Vector2(0, 48)
	ThemeFactory.apply_button_styles(_place, ThemeFactory.soft_button_styles(), SugarStreetColors.DARK_TEXT)
	_place.pressed.connect(func():
		hide_popup()
		place_requested.emit(_decoration_id)
	)
	vbox.add_child(_place)
	_remove = Button.new()
	_remove.text = "Remove from Slot"
	_remove.custom_minimum_size = Vector2(0, 44)
	ThemeFactory.apply_button_styles(_remove, ThemeFactory.secondary_button_styles())
	_remove.pressed.connect(func():
		hide_popup()
		remove_requested.emit(_decoration_id)
	)
	vbox.add_child(_remove)
	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(0, 44)
	ThemeFactory.apply_button_styles(close, ThemeFactory.secondary_button_styles())
	close.pressed.connect(func():
		hide_popup()
		closed.emit()
	)
	vbox.add_child(close)


func show_decoration(decoration_id: String) -> void:
	_decoration_id = decoration_id
	var decor := GameState.get_decoration(StringName(decoration_id))
	if decor == null:
		return
	var owned := GameState.is_decoration_owned(decor.decoration_id)
	var placed_slot := DecorationManager.find_slot_of_decoration(GameState.data, decoration_id)
	var unlocked := DecorationManager.is_decoration_unlocked(decor, GameState.data)
	_title.text = decor.display_name
	_body.text = "\n".join([
		decor.description,
		"",
		"Category: %s · Rarity: %s" % [decor.category_label(), decor.rarity_label()],
		"Appeal: +%d" % decor.appeal_value,
		"Cost: %s coins" % RewardCalculator.format_coins(decor.purchase_cost),
		"Requires shop Lv%d · player Lv%d · %d rep" % [
			decor.required_shop_level, decor.required_player_level, decor.required_reputation,
		],
		"Status: %s" % ("Owned" if owned else ("Locked" if not unlocked else "Available")),
		"" if placed_slot == "" else "Equipped in: %s" % placed_slot,
		"" if unlocked or owned else DecorationManager.unlock_reason(decor, GameState.data),
	])
	var can_buy := GameState.can_purchase_decoration(decor.decoration_id)
	_buy.visible = not owned
	_buy.disabled = not can_buy.get("ok", false) or _busy
	_buy.text = "Purchase · %s" % RewardCalculator.format_coins(decor.purchase_cost)
	_place.visible = owned
	_place.disabled = false
	_remove.visible = placed_slot != ""
	visible = true
	if not bool(GameState.data.settings.get("reduce_motion", false)):
		UiMotion.popup_in(self, _panel)
	AudioManager.play_popup()


func hide_popup() -> void:
	visible = false


func _on_buy() -> void:
	if _busy:
		return
	_busy = true
	_buy.disabled = true
	var confirm := ConfirmPopup.new()
	add_child(confirm)
	var decor := GameState.get_decoration(StringName(_decoration_id))
	confirm.show_confirm(
		"Buy %s?" % decor.display_name,
		"Spend %s coins? This cannot be refunded." % RewardCalculator.format_coins(decor.purchase_cost),
		"Buy",
		"Cancel"
	)
	confirm.confirmed.connect(func():
		var result := GameState.purchase_decoration(StringName(_decoration_id))
		_busy = false
		confirm.queue_free()
		if result.get("ok", false):
			AudioManager.play(AudioManager.Sfx.DECOR_PURCHASED)
			purchased.emit(_decoration_id)
			show_decoration(_decoration_id)
		else:
			_body.text = str(result.get("reason", "Purchase failed."))
			_buy.disabled = false
	, CONNECT_ONE_SHOT)
	confirm.cancelled.connect(func():
		_busy = false
		_buy.disabled = false
		confirm.queue_free()
	, CONNECT_ONE_SHOT)
