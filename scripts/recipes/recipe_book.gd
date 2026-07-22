extends Control
## Recipe Book — scrollable recipe cards with details panel and unlock action.


const SettingsPopupScene := preload("res://scripts/ui/settings_popup.gd")
const RecipeCardScene := preload("res://scenes/recipes/recipe_card.tscn")

const BROWN := Color("#593326")
const SECONDARY := Color("#8A5A45")
const CORAL := Color("#E97076")
const MINT := Color("#86C8AE")
const LOCKED_GRAY := Color("#817671")

const RECIPE_IDS: Array[StringName] = [
	&"chocolate_strawberries", &"classic_cupcakes", &"candied_grapes",
	&"cookies_cream_cupcakes", &"caramel_donuts",
]

var _list: HBoxContainer
var _scroll: ScrollContainer
var _details_panel: PanelContainer
var _details_label: Label
var _select_hint: Label
var _coin_label: Label
var _unlock_btn: Button
var _empty_label: Label
var _empty_actions: HBoxContainer
var _confirm: ConfirmPopup
var _settings: Control
var _top_bar: TopResourceBar
var _selected_id: StringName = &""
var _rebuilding: bool = false
var _signals_wired: bool = false
var _cards_created: int = 0
var _card_nodes: Dictionary = {} # recipe_id str -> card Control


func _ready() -> void:
	theme = ThemeFactory.build()
	_build_shell()
	_wire_game_signals()
	call_deferred("_safe_rebuild")
	if GameState.has_signal("save_loaded") and not GameState.save_loaded.is_connected(_safe_rebuild):
		GameState.save_loaded.connect(_safe_rebuild)
	AudioManager.play(AudioManager.Sfx.SHOP_OPENED)


func _build_shell() -> void:
	while get_child_count() > 0:
		var child := get_child(0)
		remove_child(child)
		child.free()

	var bg := ColorRect.new()
	bg.color = SugarStreetColors.WARM_CREAM
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var safe := MarginContainer.new()
	safe.name = "SafeArea"
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe.add_theme_constant_override("margin_left", 12)
	safe.add_theme_constant_override("margin_right", 12)
	safe.add_theme_constant_override("margin_top", 10)
	safe.add_theme_constant_override("margin_bottom", 8)
	add_child(safe)

	var vbox := VBoxContainer.new()
	vbox.name = "PageRoot"
	vbox.add_theme_constant_override("separation", 8)
	safe.add_child(vbox)

	_top_bar = TopResourceBar.new()
	vbox.add_child(_top_bar)
	_top_bar.menu_pressed.connect(func(): _settings.call("show_settings"))

	# Top row: title · coins · back
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)
	vbox.add_child(top_row)

	var title := Label.new()
	title.text = "Recipe Book"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", BROWN)
	top_row.add_child(title)

	_coin_label = Label.new()
	_coin_label.add_theme_font_size_override("font_size", 14)
	_coin_label.add_theme_color_override("font_color", BROWN)
	top_row.add_child(_coin_label)

	var back_top := Button.new()
	back_top.text = "Back"
	back_top.custom_minimum_size = Vector2(72, 44)
	ThemeFactory.apply_button_styles(back_top, ThemeFactory.secondary_button_styles())
	back_top.pressed.connect(func(): SceneRouter.go_shop())
	top_row.add_child(back_top)

	_select_hint = Label.new()
	_select_hint.text = "Select a recipe"
	_select_hint.add_theme_font_size_override("font_size", 14)
	_select_hint.add_theme_color_override("font_color", BROWN)
	vbox.add_child(_select_hint)

	# Horizontal recipe strip for portrait 405×720
	_scroll = ScrollContainer.new()
	_scroll.name = "RecipeScroll"
	_scroll.custom_minimum_size = Vector2(0, 120)
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(_scroll)

	_list = HBoxContainer.new()
	_list.name = "RecipeList"
	_list.add_theme_constant_override("separation", 8)
	_scroll.add_child(_list)

	_empty_label = Label.new()
	_empty_label.text = "No recipes could be loaded."
	_empty_label.visible = false
	_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty_label.add_theme_color_override("font_color", SECONDARY)
	vbox.add_child(_empty_label)

	_empty_actions = HBoxContainer.new()
	_empty_actions.visible = false
	_empty_actions.add_theme_constant_override("separation", 8)
	vbox.add_child(_empty_actions)
	var retry := Button.new()
	retry.text = "Retry Load"
	retry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	retry.custom_minimum_size = Vector2(0, 44)
	ThemeFactory.apply_button_styles(retry, ThemeFactory.primary_button_styles())
	retry.pressed.connect(_safe_rebuild)
	_empty_actions.add_child(retry)
	var back_empty := Button.new()
	back_empty.text = "Back"
	back_empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back_empty.custom_minimum_size = Vector2(0, 44)
	ThemeFactory.apply_button_styles(back_empty, ThemeFactory.secondary_button_styles())
	back_empty.pressed.connect(func(): SceneRouter.go_shop())
	_empty_actions.add_child(back_empty)

	# Details panel (fills remaining space above Unlock)
	_details_panel = PanelContainer.new()
	_details_panel.name = "DetailsPanel"
	_details_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_details_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_details_panel.custom_minimum_size = Vector2(0, 160)
	_details_panel.add_theme_stylebox_override("panel", ThemeFactory._card(SugarStreetColors.SOFT_IVORY, 14))
	vbox.add_child(_details_panel)

	var details_scroll := ScrollContainer.new()
	details_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_details_panel.add_child(details_scroll)

	_details_label = Label.new()
	_details_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_details_label.add_theme_font_size_override("font_size", 13)
	_details_label.add_theme_color_override("font_color", BROWN)
	_details_label.text = "Choose a recipe card above to see details, requirements, and unlock options."
	details_scroll.add_child(_details_label)

	_unlock_btn = Button.new()
	_unlock_btn.text = "Unlock"
	_unlock_btn.custom_minimum_size = Vector2(0, 48)
	_unlock_btn.disabled = true
	ThemeFactory.apply_button_styles(_unlock_btn, ThemeFactory.primary_button_styles())
	_unlock_btn.pressed.connect(_on_unlock_pressed)
	vbox.add_child(_unlock_btn)

	var nav := BottomNavigation.new()
	nav.selected_tab = BottomNavigation.TAB_RECIPES
	vbox.add_child(nav)

	_confirm = ConfirmPopup.new()
	add_child(_confirm)
	_settings = SettingsPopupScene.new()
	add_child(_settings)


func _wire_game_signals() -> void:
	if _signals_wired:
		return
	_signals_wired = true
	if not GameState.state_changed.is_connected(_safe_rebuild):
		GameState.state_changed.connect(_safe_rebuild)
	if not GameState.coins_changed.is_connected(_on_coins_changed):
		GameState.coins_changed.connect(_on_coins_changed)
	if not GameState.recipe_unlocked.is_connected(_on_recipe_unlocked):
		GameState.recipe_unlocked.connect(_on_recipe_unlocked)


func _on_coins_changed(_amount: int) -> void:
	_refresh_coin_label()
	_update_details()


func _on_recipe_unlocked(_recipe_id: StringName) -> void:
	_safe_rebuild()


func _safe_rebuild() -> void:
	if not is_inside_tree():
		return
	if _list == null or not is_instance_valid(_list):
		call_deferred("_safe_rebuild")
		return
	_rebuild()


func _rebuild() -> void:
	if _rebuilding or _list == null or not is_instance_valid(_list):
		return
	_rebuilding = true

	while _list.get_child_count() > 0:
		var child := _list.get_child(0)
		_list.remove_child(child)
		child.free()
	_card_nodes.clear()

	if GameState.catalog == null or GameState.catalog.recipes.is_empty():
		GameState.catalog.build()

	_refresh_coin_label()

	if not ResourceLoader.exists("res://scenes/recipes/recipe_card.tscn"):
		if OS.is_debug_build():
			push_error("RecipeBook: invalid card scene path res://scenes/recipes/recipe_card.tscn")
		_show_empty(true)
		_rebuilding = false
		return

	var missing: Array = []
	_cards_created = 0
	for id in RECIPE_IDS:
		var recipe := GameState.catalog.get_recipe(id)
		if recipe == null:
			missing.append(str(id))
			continue
		var card := RecipeCardScene.instantiate()
		if card == null:
			if OS.is_debug_build():
				push_error("RecipeBook: failed to instantiate recipe card")
			continue
		var unlocked := GameState.is_recipe_unlocked(recipe.recipe_id)
		var is_sel := recipe.recipe_id == _selected_id
		card.setup(recipe, unlocked, is_sel)
		card.selected.connect(_on_card_selected)
		_list.add_child(card)
		_card_nodes[str(recipe.recipe_id)] = card
		_cards_created += 1
		if OS.is_debug_build():
			print("RecipeBook: created card for %s" % str(recipe.recipe_id))

	var empty := _cards_created == 0
	_show_empty(empty)
	_update_details()

	if OS.is_debug_build():
		print("RecipeBook: definitions=%d cards=%d selected=%s missing=%s parent=%s" % [
			RECIPE_IDS.size(), _cards_created, str(_selected_id), missing,
			str(_list.get_path()) if is_inside_tree() else "RecipeList",
		])
		if empty:
			push_warning("RecipeBook: no recipes could be loaded")

	_rebuilding = false


func _show_empty(empty: bool) -> void:
	_empty_label.visible = empty
	_empty_actions.visible = empty
	_scroll.visible = not empty
	_details_panel.visible = not empty
	_unlock_btn.visible = not empty
	_select_hint.visible = not empty


func _refresh_coin_label() -> void:
	if _coin_label:
		_coin_label.text = "%s coins" % RewardCalculator.format_coins(GameState.data.coins)


func _on_card_selected(recipe_id: StringName) -> void:
	_selected_id = recipe_id
	for key in _card_nodes.keys():
		var card = _card_nodes[key]
		if is_instance_valid(card) and card.has_method("set_selected"):
			card.set_selected(StringName(key) == recipe_id)
	if OS.is_debug_build():
		print("RecipeBook: selected recipe ID=%s" % str(recipe_id))
	_update_details()


func _update_details() -> void:
	_refresh_coin_label()
	if _selected_id == &"":
		_select_hint.text = "Select a recipe"
		_details_label.text = "Choose a recipe card above to see details, requirements, and unlock options."
		_details_label.add_theme_color_override("font_color", BROWN)
		_unlock_btn.text = "Unlock"
		_unlock_btn.disabled = true
		return

	var recipe := GameState.catalog.get_recipe(_selected_id)
	if recipe == null:
		_details_label.text = "Recipe data missing."
		_unlock_btn.disabled = true
		return

	var unlocked := GameState.is_recipe_unlocked(recipe.recipe_id)
	_select_hint.text = recipe.display_name
	_select_hint.add_theme_color_override("font_color", BROWN)

	var lines: PackedStringArray = []
	lines.append(recipe.display_name)
	lines.append("%s · %s" % [recipe.category_label(), recipe.rarity_label()])
	lines.append("")
	lines.append(recipe.description)
	lines.append("")
	lines.append("Status: %s" % ("Unlocked" if unlocked else "Locked"))
	lines.append("Requires player level %d (you: %d)" % [recipe.required_player_level, GameState.data.player_level])
	lines.append("Requires %d stars (you: %d)" % [recipe.required_stars, GameState.data.stars])
	lines.append("Unlock cost: %s coins (you: %s)" % [
		RewardCalculator.format_coins(recipe.unlock_coin_cost),
		RewardCalculator.format_coins(GameState.data.coins),
	])
	if not recipe.ingredient_requirements.is_empty():
		var parts: PackedStringArray = []
		for iid in recipe.ingredient_requirements.keys():
			parts.append("%s×%s" % [str(recipe.ingredient_requirements[iid]), str(iid)])
		lines.append("Ingredients: %s" % ", ".join(parts))
	_details_label.text = "\n".join(lines)
	_details_label.add_theme_color_override("font_color", BROWN)

	if unlocked:
		_unlock_btn.text = "Unlocked"
		_unlock_btn.disabled = true
	else:
		var check := GameState.can_unlock_recipe(recipe.recipe_id)
		_unlock_btn.text = "Unlock for %s" % RewardCalculator.format_coins(recipe.unlock_coin_cost)
		_unlock_btn.disabled = not check.get("ok", false)


func _on_unlock_pressed() -> void:
	if _selected_id == &"":
		return
	var recipe := GameState.catalog.get_recipe(_selected_id)
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
	_confirm.confirmed.connect(_do_unlock.bind(_selected_id), CONNECT_ONE_SHOT)


func _do_unlock(recipe_id: StringName = &"") -> void:
	if recipe_id == &"":
		return
	var result := GameState.unlock_recipe(recipe_id)
	if result.get("ok", false):
		AudioManager.play(AudioManager.Sfx.RECIPE_UNLOCKED)
		_selected_id = recipe_id
		_safe_rebuild()
	else:
		_details_label.text = str(result.get("reason", "Could not unlock."))
		_details_label.add_theme_color_override("font_color", CORAL)
