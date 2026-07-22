extends Control
## Recipe Book with visible unlockable recipe cards.


const SettingsPopupScene := preload("res://scripts/ui/settings_popup.gd")

var _list: VBoxContainer
var _confirm: ConfirmPopup
var _settings: Control
var _top_bar: TopResourceBar
var _feedback: Label


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
	title.text = "Recipe Book"
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
	nav.selected_tab = BottomNavigation.TAB_RECIPES
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
	var ids := [
		&"chocolate_strawberries", &"classic_cupcakes", &"candied_grapes",
		&"cookies_cream_cupcakes", &"caramel_donuts",
	]
	var shown := 0
	for id in ids:
		var recipe := GameState.catalog.get_recipe(id)
		if recipe == null:
			continue
		shown += 1
		_list.add_child(_make_card(recipe))
	if shown == 0:
		var empty := Label.new()
		empty.text = "No recipes found"
		empty.add_theme_color_override("font_color", SugarStreetColors.WOOD_BROWN)
		_list.add_child(empty)
		if OS.is_debug_build():
			push_warning("RecipeBook: catalog returned no target recipes")
	_feedback.text = "Coins: %s · Unlock recipes to open new customer orders." % RewardCalculator.format_coins(GameState.data.coins)


func _make_card(recipe: RecipeData) -> PanelContainer:
	var unlocked := GameState.is_recipe_unlocked(recipe.recipe_id)
	var card := PanelContainer.new()
	var style := ThemeFactory._card(SugarStreetColors.SOFT_IVORY if unlocked else Color(0.93, 0.9, 0.88, 1), 16)
	card.add_theme_stylebox_override("panel", style)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	card.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	root.add_child(header)
	var icon := PanelContainer.new()
	icon.custom_minimum_size = Vector2(56, 56)
	var istyle := StyleBoxFlat.new()
	istyle.bg_color = recipe.fallback_color
	istyle.set_corner_radius_all(14)
	icon.add_theme_stylebox_override("panel", istyle)
	header.add_child(icon)
	var icon_l := Label.new()
	icon_l.text = recipe.display_name.substr(0, 1)
	icon_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_l.add_theme_color_override("font_color", SugarStreetColors.WHITE)
	icon_l.add_theme_font_size_override("font_size", 22)
	icon.add_child(icon_l)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(info)
	var name_l := Label.new()
	name_l.text = recipe.display_name
	name_l.add_theme_font_size_override("font_size", 17)
	name_l.add_theme_color_override("font_color", SugarStreetColors.BAKERY_BROWN)
	info.add_child(name_l)
	var meta := Label.new()
	meta.text = "%s · %s · %s" % [recipe.category_label(), recipe.rarity_label(), "Unlocked" if unlocked else "Locked"]
	meta.add_theme_font_size_override("font_size", 12)
	meta.add_theme_color_override("font_color", SugarStreetColors.WOOD_BROWN)
	info.add_child(meta)

	var req := Label.new()
	req.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	req.text = "Requires Lv.%d · %d stars · %s coins" % [
		recipe.required_player_level, recipe.required_stars, RewardCalculator.format_coins(recipe.unlock_coin_cost)
	]
	req.add_theme_font_size_override("font_size", 12)
	req.add_theme_color_override("font_color", SugarStreetColors.DARK_TEXT)
	root.add_child(req)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 44)
	if unlocked:
		btn.text = "Unlocked"
		btn.disabled = true
	else:
		var check := GameState.can_unlock_recipe(recipe.recipe_id)
		btn.text = "Unlock for %s" % RewardCalculator.format_coins(recipe.unlock_coin_cost)
		btn.disabled = not check.get("ok", false)
		btn.pressed.connect(_confirm_unlock.bind(recipe.recipe_id))
	ThemeFactory.apply_button_styles(btn, ThemeFactory.primary_button_styles())
	root.add_child(btn)
	return card


func _confirm_unlock(recipe_id: StringName) -> void:
	var recipe := GameState.catalog.get_recipe(recipe_id)
	if recipe == null:
		return
	_confirm.show_confirm(
		"Unlock Recipe?",
		"Spend %s coins to unlock %s?" % [RewardCalculator.format_coins(recipe.unlock_coin_cost), recipe.display_name],
		"Unlock",
		"Cancel"
	)
	if _confirm.confirmed.is_connected(_do_unlock):
		_confirm.confirmed.disconnect(_do_unlock)
	_confirm.confirmed.connect(_do_unlock.bind(recipe_id), CONNECT_ONE_SHOT)


func _do_unlock(recipe_id: StringName = &"") -> void:
	if recipe_id == &"":
		return
	var result := GameState.unlock_recipe(recipe_id)
	if result.get("ok", false):
		AudioManager.play(AudioManager.Sfx.RECIPE_UNLOCKED)
		_feedback.text = "Recipe unlocked! Related orders may now appear."
	else:
		_feedback.text = str(result.get("reason", "Could not unlock."))
	_rebuild()
