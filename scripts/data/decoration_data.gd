class_name DecorationData
extends Resource
## Catalog definition for a placeable shop decoration (ownership lives in SaveData).

enum Category {
	WALL,
	COUNTER,
	FLOOR,
	LIGHTING,
	PLANTS,
	SEATING,
	SIGNAGE,
	DISPLAY,
	WINDOW,
	ACCENT,
}

enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	PREMIUM,
}

@export var decoration_id: StringName = &""
@export var display_name: String = ""
@export var description: String = ""
@export var category: Category = Category.ACCENT
@export var rarity: Rarity = Rarity.COMMON
@export var compatible_slot_types: Array[StringName] = []
@export var purchase_cost: int = 0
@export var appeal_value: int = 0
@export var required_shop_level: int = 1
@export var required_player_level: int = 1
@export var required_reputation: int = 0
@export var owned_by_default: bool = false
@export var visual_stage: int = 1
@export var placeholder_symbol: String = "✦"
@export var placeholder_color: Color = Color(0.9, 0.7, 0.6, 1)
@export var event_tag: StringName = &""


func category_label() -> String:
	match category:
		Category.WALL: return "Wall"
		Category.COUNTER: return "Counter"
		Category.FLOOR: return "Floor"
		Category.LIGHTING: return "Lighting"
		Category.PLANTS: return "Plants"
		Category.SEATING: return "Seating"
		Category.SIGNAGE: return "Signage"
		Category.DISPLAY: return "Display"
		Category.WINDOW: return "Window"
		Category.ACCENT: return "Accent"
	return "Accent"


func rarity_label() -> String:
	match rarity:
		Rarity.COMMON: return "Common"
		Rarity.UNCOMMON: return "Uncommon"
		Rarity.RARE: return "Rare"
		Rarity.PREMIUM: return "Premium"
	return "Common"


func matches_slot_type(slot_type: StringName) -> bool:
	return compatible_slot_types.has(slot_type)
