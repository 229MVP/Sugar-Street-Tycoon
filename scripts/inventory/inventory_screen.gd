extends Control
## Ingredient Inventory — readable categorized cards with live GameState quantities.


const SettingsPopupScene := preload("res://scripts/ui/settings_popup.gd")

const BG := Color("#FFF5E8")
const BROWN := Color("#593326")
const SECONDARY := Color("#8A5A45")
const CARD_BG := Color("#FFF9F2")
const CARD_BORDER := Color("#E7AAAE")
const CORAL := Color("#E97076")

const CATEGORY_ORDER: Array[Dictionary] = [
	{"id": "fruit", "label": "Fruit", "ids": ["strawberries", "grapes"]},
	{"id": "baking", "label": "Baking", "ids": ["flour", "sugar", "cream", "cheesecake_filling"]},
	{"id": "flavoring", "label": "Flavoring", "ids": ["chocolate", "caramel", "cookies"]},
	{"id": "supplies", "label": "Supplies", "ids": ["packaging"]},
]

var _list: VBoxContainer
var _scroll: ScrollContainer
var _summary: Label
var _empty_label: Label
var _top_bar: TopResourceBar
var _settings: Control
var _section_grids: Array = []
var _rebuilding: bool = false
var _signals_wired: bool = false


func _ready() -> void:
	theme = ThemeFactory.build()
	_build_shell()
	_wire_signals()
	call_deferred("_safe_rebuild")
	resized.connect(_on_resized)
	call_deferred("_on_resized")
	AudioManager.play(AudioManager.Sfx.SHOP_OPENED)


func _build_shell() -> void:
	while get_child_count() > 0:
		var child := get_child(0)
		remove_child(child)
		child.free()

	var bg := ColorRect.new()
	bg.color = BG
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

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	vbox.add_child(title_row)

	var title := Label.new()
	title.text = "Ingredient Inventory"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", BROWN)
	title_row.add_child(title)

	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(72, 44)
	ThemeFactory.apply_button_styles(back, ThemeFactory.secondary_button_styles())
	back.pressed.connect(func(): SceneRouter.go_shop())
	title_row.add_child(back)

	var desc := Label.new()
	desc.text = "Ingredients are earned from completed customer orders."
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", SECONDARY)
	vbox.add_child(desc)

	_summary = Label.new()
	_summary.add_theme_font_size_override("font_size", 13)
	_summary.add_theme_color_override("font_color", BROWN)
	vbox.add_child(_summary)

	_scroll = ScrollContainer.new()
	_scroll.name = "InventoryScroll"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.custom_minimum_size = Vector2(0, 200)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(_scroll)

	_list = VBoxContainer.new()
	_list.name = "InventoryList"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 12)
	_scroll.add_child(_list)

	_empty_label = Label.new()
	_empty_label.visible = false
	_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty_label.text = "No ingredients yet. Complete customer orders to earn supplies."
	_empty_label.add_theme_color_override("font_color", SECONDARY)
	_list.add_child(_empty_label)

	if GameState.DEBUG_TOOLS_ENABLED and OS.is_debug_build():
		var reset := Button.new()
		reset.text = "Reset Inventory to Starter Values"
		reset.custom_minimum_size = Vector2(0, 44)
		ThemeFactory.apply_button_styles(reset, ThemeFactory.soft_button_styles(), BROWN)
		reset.pressed.connect(func():
			GameState.reset_inventory_to_starter()
			_safe_rebuild()
		)
		vbox.add_child(reset)

	var nav := BottomNavigation.new()
	nav.selected_tab = BottomNavigation.TAB_INVENTORY
	vbox.add_child(nav)

	_settings = SettingsPopupScene.new()
	add_child(_settings)


func _wire_signals() -> void:
	if _signals_wired:
		return
	_signals_wired = true
	if GameState.has_signal("inventory_changed") and not GameState.inventory_changed.is_connected(_on_inventory_changed):
		GameState.inventory_changed.connect(_on_inventory_changed)
	if not GameState.state_changed.is_connected(_safe_rebuild):
		GameState.state_changed.connect(_safe_rebuild)
	if GameState.has_signal("save_loaded") and not GameState.save_loaded.is_connected(_safe_rebuild):
		GameState.save_loaded.connect(_safe_rebuild)


func _on_inventory_changed(_ingredients: Dictionary) -> void:
	_safe_rebuild()


func _on_resized() -> void:
	var cols := 2 if size.x >= 390.0 else 1
	for grid in _section_grids:
		if is_instance_valid(grid):
			grid.columns = cols


func _safe_rebuild() -> void:
	if not is_inside_tree():
		return
	if _list == null or not is_instance_valid(_list):
		call_deferred("_safe_rebuild")
		return
	_rebuild()


func _rebuild() -> void:
	if _rebuilding or _list == null:
		return
	_rebuilding = true

	# Keep empty label; remove category sections.
	for child in _list.get_children():
		if child == _empty_label:
			continue
		_list.remove_child(child)
		child.free()
	_section_grids.clear()

	GameState._ensure_ingredients()
	var total := GameState.get_total_ingredient_units()
	_summary.text = "Total ingredient units: %d" % total
	_empty_label.visible = total <= 0

	for cat in CATEGORY_ORDER:
		var section := VBoxContainer.new()
		section.add_theme_constant_override("separation", 6)
		_list.add_child(section)

		var header := Label.new()
		header.text = str(cat["label"])
		header.add_theme_font_size_override("font_size", 14)
		header.add_theme_color_override("font_color", BROWN)
		section.add_child(header)

		var grid := GridContainer.new()
		grid.columns = 2 if size.x >= 390.0 else 1
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		section.add_child(grid)
		_section_grids.append(grid)

		for id in cat["ids"]:
			var item: IngredientData = GameState.catalog.get_ingredient(StringName(id))
			if item == null:
				item = IngredientData.new()
				item.ingredient_id = StringName(id)
				item.display_name = str(id).replace("_", " ").capitalize()
				item.color = CORAL
			grid.add_child(_make_card(item, str(cat["label"])))

	if OS.is_debug_build():
		print("InventoryScreen: total_units=%d parent=%s" % [
			total, str(_list.get_path()) if is_inside_tree() else "InventoryList"
		])

	_rebuilding = false
	call_deferred("_on_resized")


func _make_card(item: IngredientData, category_label: String) -> PanelContainer:
	var amount := GameState.get_ingredient_amount(item.ingredient_id)
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 96)
	var style := StyleBoxFlat.new()
	style.bg_color = CARD_BG
	style.set_corner_radius_all(14)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.set_border_width_all(1)
	style.border_color = CARD_BORDER
	card.add_theme_stylebox_override("panel", style)

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
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)

	var name_l := Label.new()
	name_l.text = item.display_name
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_l.add_theme_font_size_override("font_size", 15)
	name_l.add_theme_color_override("font_color", BROWN)
	col.add_child(name_l)

	var qty := Label.new()
	qty.text = "%d owned" % amount
	qty.add_theme_font_size_override("font_size", 13)
	qty.add_theme_color_override("font_color", SECONDARY if amount > 0 else Color("#817671"))
	col.add_child(qty)

	var meta := Label.new()
	meta.text = "%s · %s" % [category_label, "Available" if amount > 0 else "Empty"]
	meta.add_theme_font_size_override("font_size", 11)
	meta.add_theme_color_override("font_color", SECONDARY)
	col.add_child(meta)
	return card
