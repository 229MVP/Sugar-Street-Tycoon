class_name DecorationCatalog
extends RefCounted
## Definitions for fixed decoration slots and the starter decoration set.


var decorations: Dictionary = {} ## StringName -> DecorationData
var decoration_sequence: Array[StringName] = []
var slots: Dictionary = {} ## StringName -> DecorationSlotDef
var slot_sequence: Array[StringName] = []


func build() -> void:
	decorations.clear()
	decoration_sequence.clear()
	slots.clear()
	slot_sequence.clear()
	_build_slots()
	_build_decorations()


func get_decoration(id: StringName) -> DecorationData:
	return decorations.get(id)


func get_slot(id: StringName) -> DecorationSlotDef:
	return slots.get(id)


func all_decorations() -> Array:
	var out: Array = []
	for id in decoration_sequence:
		out.append(decorations[id])
	return out


func all_slots() -> Array:
	var out: Array = []
	for id in slot_sequence:
		out.append(slots[id])
	return out


func default_owned_ids() -> Array[String]:
	var out: Array[String] = []
	for id in decoration_sequence:
		var d: DecorationData = decorations[id]
		if d.owned_by_default:
			out.append(str(id))
	return out


func default_placements() -> Dictionary:
	return {
		"front_sign": "wooden_starter_sign",
		"plant_corner": "small_mint_plant",
	}


func _build_slots() -> void:
	_add_slot(&"front_sign", "Front Sign", &"front_sign", 1,
		[DecorationData.Category.SIGNAGE], Vector2(0.22, 0.02), Vector2(0.56, 0.10))
	_add_slot(&"wall_left", "Wall Left", &"wall", 1,
		[DecorationData.Category.WALL], Vector2(0.04, 0.16), Vector2(0.22, 0.18))
	_add_slot(&"wall_right", "Wall Right", &"wall", 2,
		[DecorationData.Category.WALL], Vector2(0.74, 0.16), Vector2(0.22, 0.18))
	_add_slot(&"counter_accent", "Counter Accent", &"counter", 1,
		[DecorationData.Category.COUNTER], Vector2(0.30, 0.62), Vector2(0.40, 0.12))
	_add_slot(&"display_accent", "Display Accent", &"display", 2,
		[DecorationData.Category.DISPLAY], Vector2(0.08, 0.40), Vector2(0.28, 0.14))
	_add_slot(&"floor_center", "Floor Center", &"floor", 3,
		[DecorationData.Category.FLOOR], Vector2(0.28, 0.78), Vector2(0.44, 0.12))
	_add_slot(&"window", "Window", &"window", 3,
		[DecorationData.Category.WINDOW], Vector2(0.62, 0.36), Vector2(0.30, 0.16))
	_add_slot(&"plant_corner", "Plant Corner", &"plants", 1,
		[DecorationData.Category.PLANTS], Vector2(0.78, 0.72), Vector2(0.18, 0.18))
	_add_slot(&"lighting", "Lighting", &"lighting", 4,
		[DecorationData.Category.LIGHTING], Vector2(0.34, 0.12), Vector2(0.32, 0.10))
	_add_slot(&"seating", "Seating", &"seating", 5,
		[DecorationData.Category.SEATING], Vector2(0.06, 0.70), Vector2(0.22, 0.18))


func _add_slot(
	id: StringName,
	name: String,
	slot_type: StringName,
	level: int,
	categories: Array,
	pos: Vector2,
	size: Vector2
) -> void:
	slots[id] = DecorationSlotDef.new(id, name, slot_type, level, categories, pos, size)
	slot_sequence.append(id)


func _build_decorations() -> void:
	# Front Sign
	_add_decor(&"wooden_starter_sign", "Wooden Starter Sign",
		"A friendly hand-painted bakery sign.", DecorationData.Category.SIGNAGE,
		DecorationData.Rarity.COMMON, [&"front_sign"], 0, 5, 1, 1, 0, true, "🪧", Color("#9A5C3B"))
	_add_decor(&"pink_neon_dessert_sign", "Pink Neon Dessert Sign",
		"Glowing neon script that draws dessert lovers.", DecorationData.Category.SIGNAGE,
		DecorationData.Rarity.UNCOMMON, [&"front_sign"], 600, 18, 2, 1, 0, false, "💡", Color("#F48A9C"))
	_add_decor(&"golden_sugar_street_sign", "Golden Sugar Street Sign",
		"Premium gold lettering for iconic storefronts.", DecorationData.Category.SIGNAGE,
		DecorationData.Rarity.RARE, [&"front_sign"], 1800, 35, 4, 1, 100, false, "✨", Color("#F4BC4B"))

	# Wall
	_add_decor(&"framed_cupcake_print", "Framed Cupcake Print",
		"A cute framed cupcake illustration.", DecorationData.Category.WALL,
		DecorationData.Rarity.COMMON, [&"wall"], 200, 8, 1, 1, 0, false, "🖼", Color("#F6C5AC"))
	_add_decor(&"strawberry_wall_clock", "Strawberry Wall Clock",
		"Keeps time in berry-sweet style.", DecorationData.Category.WALL,
		DecorationData.Rarity.UNCOMMON, [&"wall"], 450, 14, 2, 1, 0, false, "🕒", Color("#E97076"))
	_add_decor(&"dessert_recipe_chalkboard", "Dessert Recipe Chalkboard",
		"Daily specials chalked with flair.", DecorationData.Category.WALL,
		DecorationData.Rarity.RARE, [&"wall"], 900, 22, 3, 1, 0, false, "📋", Color("#593326"))

	# Counter
	_add_decor(&"small_dessert_jar_set", "Small Dessert Jar Set",
		"Glass jars of toppings for the counter.", DecorationData.Category.COUNTER,
		DecorationData.Rarity.COMMON, [&"counter"], 250, 9, 1, 1, 0, false, "🫙", Color("#86C8AE"))
	_add_decor(&"pastel_cake_stand", "Pastel Cake Stand",
		"A soft pastel stand for featured cakes.", DecorationData.Category.COUNTER,
		DecorationData.Rarity.UNCOMMON, [&"counter"], 500, 16, 2, 1, 0, false, "🎂", Color("#F48A9C"))
	_add_decor(&"luxury_dessert_tower", "Luxury Dessert Tower",
		"A stacked tower of showcase treats.", DecorationData.Category.COUNTER,
		DecorationData.Rarity.RARE, [&"counter"], 1500, 32, 4, 1, 0, false, "🏛", Color("#F4BC4B"))

	# Plants
	_add_decor(&"small_mint_plant", "Small Mint Plant",
		"A tiny mint pot for a fresh corner.", DecorationData.Category.PLANTS,
		DecorationData.Rarity.COMMON, [&"plants"], 0, 5, 1, 1, 0, true, "🌱", Color("#86C8AE"))
	_add_decor(&"strawberry_blossom_planter", "Strawberry Blossom Planter",
		"Blooming planter with strawberry accents.", DecorationData.Category.PLANTS,
		DecorationData.Rarity.COMMON, [&"plants"], 350, 12, 1, 1, 0, false, "🌸", Color("#F48A9C"))
	_add_decor(&"golden_indoor_tree", "Golden Indoor Tree",
		"A statement indoor tree with warm tones.", DecorationData.Category.PLANTS,
		DecorationData.Rarity.RARE, [&"plants"], 1200, 27, 3, 1, 0, false, "🌳", Color("#F4BC4B"))

	# Floor
	_add_decor(&"cream_welcome_mat", "Cream Welcome Mat",
		"Soft cream mat for the entrance.", DecorationData.Category.FLOOR,
		DecorationData.Rarity.COMMON, [&"floor"], 300, 10, 3, 1, 0, false, "🟫", Color("#FFF4E8"))
	_add_decor(&"strawberry_swirl_rug", "Strawberry Swirl Rug",
		"A swirled berry-pattern rug.", DecorationData.Category.FLOOR,
		DecorationData.Rarity.UNCOMMON, [&"floor"], 750, 20, 3, 1, 0, false, "🟥", Color("#E97076"))

	# Lighting
	_add_decor(&"warm_pendant_lights", "Warm Pendant Lights",
		"Warm hanging lights for a cozy glow.", DecorationData.Category.LIGHTING,
		DecorationData.Rarity.UNCOMMON, [&"lighting"], 850, 24, 4, 1, 0, false, "💡", Color("#F4BC4B"))

	# Seating
	_add_decor(&"cozy_pink_cafe_table", "Cozy Pink Café Table",
		"A pink café table with matching chairs.", DecorationData.Category.SEATING,
		DecorationData.Rarity.RARE, [&"seating"], 1500, 35, 5, 1, 0, false, "🪑", Color("#F48A9C"))

	# Display / Window extras mapped to those slot types via category + compatible types
	# (Display Accent and Window use DISPLAY / WINDOW categories; add one each for unlock variety.)
	# Spec lists 16 decorations; Display/Window slot types accept DISPLAY/WINDOW categories.
	# Framed items already cover walls; display_accent uses DISPLAY — add mapping:
	# Small Dessert Jar could also fit display? Spec says Counter only. Keep Display Accent
	# compatible with DISPLAY category — use luxury pieces via category Display.
	# Re-tag Pastel Cake Stand stays Counter. For Display Accent unlock at shop 2,
	# players need DISPLAY-category items. Spec didn't list Display-category pieces.
	# Compatible categories on display_accent include DISPLAY — add Framed Cupcake also to display?
	# Better: allow Wall category on display_accent as "display wall art" OR add
	# display_accent compatible with COUNTER and WALL as accents.
	# Spec: "Compatible decoration categories" per slot. Display Accent → Display.
	# I'll make Framed Cupcake Print also compatible with display slot type, and
	# Cream Welcome Mat already floor. For Window, Window category needed —
	# Strawberry Wall Clock could be window-adjacent; add Window as second compatible
	# for chalkboard? Cleaner: update slot defs so Display accepts WALL+COUNTER+DISPLAY
	# and Window accepts WALL+WINDOW. That matches practical starter set of 16.

	# Patch slot categories for usable placements with the 16 listed items:
	(slots[&"display_accent"] as DecorationSlotDef).compatible_categories = [
		DecorationData.Category.DISPLAY, DecorationData.Category.COUNTER, DecorationData.Category.WALL,
	]
	(slots[&"window"] as DecorationSlotDef).compatible_categories = [
		DecorationData.Category.WINDOW, DecorationData.Category.WALL, DecorationData.Category.SIGNAGE,
	]


func _add_decor(
	id: StringName,
	name: String,
	desc: String,
	category: DecorationData.Category,
	rarity: DecorationData.Rarity,
	slot_types: Array,
	cost: int,
	appeal: int,
	shop_level: int,
	player_level: int,
	reputation: int,
	owned_default: bool,
	symbol: String,
	color: Color
) -> void:
	var d := DecorationData.new()
	d.decoration_id = id
	d.display_name = name
	d.description = desc
	d.category = category
	d.rarity = rarity
	d.compatible_slot_types.clear()
	for t in slot_types:
		d.compatible_slot_types.append(t)
	d.purchase_cost = cost
	d.appeal_value = appeal
	d.required_shop_level = shop_level
	d.required_player_level = player_level
	d.required_reputation = reputation
	d.owned_by_default = owned_default
	d.placeholder_symbol = symbol
	d.placeholder_color = color
	d.visual_stage = shop_level
	decorations[id] = d
	decoration_sequence.append(id)
