extends Control
## Ingredient inventory as a responsive card grid.


const SettingsPopupScene := preload("res://scripts/ui/settings_popup.gd")

var _grid: GridContainer
var _top_bar: TopResourceBar
var _info: Label
var _settings: Control


func _ready() -> void:
	theme = ThemeFactory.build()
	_build()
	GameState.state_changed.connect(_rebuild)
	_rebuild()
	resized.connect(_on_resized)
	call_deferred("_on_resized")


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
	title.text = "Ingredient Inventory"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", SugarStreetColors.BAKERY_BROWN)
	vbox.add_child(title)

	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.add_theme_color_override("font_color", SugarStreetColors.WOOD_BROWN)
	_info.text = "Ingredients are earned from completed orders. Consumption comes later."
	vbox.add_child(_info)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(_grid)

	var back := Button.new()
	back.text = "Back to Shop"
	back.custom_minimum_size = Vector2(0, 44)
	ThemeFactory.apply_button_styles(back, ThemeFactory.secondary_button_styles())
	back.pressed.connect(func(): SceneRouter.go_shop())
	vbox.add_child(back)

	var nav := BottomNavigation.new()
	nav.selected_tab = BottomNavigation.TAB_INVENTORY
	vbox.add_child(nav)

	_settings = SettingsPopupScene.new()
	add_child(_settings)


func _on_resized() -> void:
	if _grid == null:
		return
	_grid.columns = 2 if size.x >= 360.0 else 1


func _rebuild() -> void:
	if _grid == null:
		return
	for c in _grid.get_children():
		c.queue_free()
	var count := 0
	for id in GameState.catalog.ingredients.keys():
		var item: IngredientData = GameState.catalog.ingredients[id]
		_grid.add_child(_make_card(item))
		count += 1
	if count == 0:
		var empty := Label.new()
		empty.text = "Inventory is empty"
		empty.add_theme_color_override("font_color", SugarStreetColors.WOOD_BROWN)
		_grid.add_child(empty)
		if OS.is_debug_build():
			push_warning("InventoryScreen: no ingredients in catalog")


func _make_card(item: IngredientData) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 88)
	card.add_theme_stylebox_override("panel", ThemeFactory._card(SugarStreetColors.SOFT_IVORY, 14))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)

	var icon := PanelContainer.new()
	icon.custom_minimum_size = Vector2(48, 48)
	var istyle := StyleBoxFlat.new()
	istyle.bg_color = item.color
	istyle.set_corner_radius_all(12)
	icon.add_theme_stylebox_override("panel", istyle)
	row.add_child(icon)
	var glyph := Label.new()
	glyph.text = item.display_name.substr(0, 1)
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	glyph.add_theme_color_override("font_color", SugarStreetColors.WHITE)
	glyph.add_theme_font_size_override("font_size", 20)
	icon.add_child(glyph)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var name_l := Label.new()
	name_l.text = item.display_name
	name_l.add_theme_font_size_override("font_size", 15)
	name_l.add_theme_color_override("font_color", SugarStreetColors.BAKERY_BROWN)
	col.add_child(name_l)
	var qty := Label.new()
	qty.text = "Qty %d · %s" % [GameState.get_ingredient_amount(item.ingredient_id), _category(item)]
	qty.add_theme_font_size_override("font_size", 12)
	qty.add_theme_color_override("font_color", SugarStreetColors.WOOD_BROWN)
	col.add_child(qty)
	return card


func _category(item: IngredientData) -> String:
	match str(item.ingredient_id):
		"chocolate", "strawberries", "grapes":
			return "Produce"
		"flour", "sugar", "cream", "caramel", "cookies", "cheesecake_filling":
			return "Baking"
		"packaging":
			return "Supplies"
	return "Ingredient"
