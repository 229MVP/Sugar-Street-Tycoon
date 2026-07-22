class_name RecipeCard
extends PanelContainer
## Selectable recipe card for the Recipe Book list.


signal selected(recipe_id: StringName)

const BROWN := Color("#593326")
const SECONDARY := Color("#8A5A45")
const CORAL := Color("#E97076")
const LOCKED_GRAY := Color("#817671")

var recipe_id: StringName = &""
var _selected: bool = false
var _input_wired: bool = false


func _ready() -> void:
	visible = true
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP
	if custom_minimum_size.y < 88.0:
		custom_minimum_size = Vector2(160, 100)
	if not _input_wired:
		gui_input.connect(_on_gui_input)
		_input_wired = true


func setup(recipe: RecipeData, unlocked: bool, is_selected: bool = false) -> void:
	recipe_id = recipe.recipe_id
	_selected = is_selected
	_clear_children_immediate()
	visible = true
	custom_minimum_size = Vector2(160, 100)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP
	if not _input_wired:
		gui_input.connect(_on_gui_input)
		_input_wired = true

	var style := ThemeFactory._card(SugarStreetColors.SOFT_IVORY if unlocked else Color(0.93, 0.9, 0.88, 1), 14)
	if _selected:
		style.border_color = CORAL
		style.set_border_width_all(3)
	elif not unlocked:
		style.border_color = LOCKED_GRAY
		style.set_border_width_all(2)
	add_theme_stylebox_override("panel", style)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 4)
	add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	root.add_child(header)

	var icon := PanelContainer.new()
	icon.custom_minimum_size = Vector2(44, 44)
	var istyle := StyleBoxFlat.new()
	istyle.bg_color = recipe.fallback_color if unlocked else recipe.fallback_color.darkened(0.35)
	istyle.set_corner_radius_all(12)
	icon.add_theme_stylebox_override("panel", istyle)
	header.add_child(icon)
	var glyph := Label.new()
	glyph.text = recipe.display_name.substr(0, 1)
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	glyph.add_theme_color_override("font_color", SugarStreetColors.WHITE)
	glyph.add_theme_font_size_override("font_size", 18)
	icon.add_child(glyph)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(info)

	var name_l := Label.new()
	name_l.text = recipe.display_name
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_l.add_theme_font_size_override("font_size", 14)
	name_l.add_theme_color_override("font_color", BROWN)
	info.add_child(name_l)

	var meta := Label.new()
	meta.text = "%s · %s" % [recipe.category_label(), recipe.rarity_label()]
	meta.add_theme_font_size_override("font_size", 11)
	meta.add_theme_color_override("font_color", SECONDARY)
	info.add_child(meta)

	var status := Label.new()
	if unlocked:
		status.text = "Unlocked"
		status.add_theme_color_override("font_color", Color("#86C8AE"))
	else:
		status.text = "Locked · Lv.%d · %d★ · %s" % [
			recipe.required_player_level,
			recipe.required_stars,
			RewardCalculator.format_coins(recipe.unlock_coin_cost),
		]
		status.add_theme_color_override("font_color", LOCKED_GRAY)
	status.add_theme_font_size_override("font_size", 11)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(status)


func set_selected(value: bool) -> void:
	_selected = value
	var style := get_theme_stylebox("panel")
	if style is StyleBoxFlat:
		var copy: StyleBoxFlat = (style as StyleBoxFlat).duplicate()
		if _selected:
			copy.border_color = CORAL
			copy.set_border_width_all(3)
		else:
			copy.border_color = SugarStreetColors.SOFT_BORDER
			copy.set_border_width_all(1)
		add_theme_stylebox_override("panel", copy)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		selected.emit(recipe_id)
	elif event is InputEventScreenTouch and event.pressed:
		selected.emit(recipe_id)


func _clear_children_immediate() -> void:
	while get_child_count() > 0:
		var child := get_child(0)
		remove_child(child)
		child.free()
