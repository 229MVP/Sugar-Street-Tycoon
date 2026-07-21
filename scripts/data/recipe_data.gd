class_name RecipeData
extends Resource
## Static definition of a dessert recipe that customers can order.

enum Category { FRUIT_TREATS, CUPCAKES, COOKIES, DONUTS, CHEESECAKES, DESSERT_BOXES }
enum Rarity { COMMON, UNCOMMON, RARE, PREMIUM }

@export var recipe_id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var category: Category = Category.FRUIT_TREATS
@export var rarity: Rarity = Rarity.COMMON
@export var unlocked_by_default: bool = false
@export var required_player_level: int = 1
@export var required_stars: int = 0
@export var unlock_coin_cost: int = 0
@export var required_equipment_levels: Dictionary = {} # equipment_id -> min level
@export var base_selling_value: int = 100
@export var preparation_time: float = 0.0 ## Reserved for future use.
@export var ingredient_requirements: Dictionary = {} # ingredient_id -> amount
@export var fallback_color: Color = Color(1, 0.75, 0.8, 1)


func category_label() -> String:
	match category:
		Category.FRUIT_TREATS: return "Fruit Treats"
		Category.CUPCAKES: return "Cupcakes"
		Category.COOKIES: return "Cookies"
		Category.DONUTS: return "Donuts"
		Category.CHEESECAKES: return "Cheesecakes"
		Category.DESSERT_BOXES: return "Dessert Boxes"
	return "Unknown"


func rarity_label() -> String:
	match rarity:
		Rarity.COMMON: return "Common"
		Rarity.UNCOMMON: return "Uncommon"
		Rarity.RARE: return "Rare"
		Rarity.PREMIUM: return "Premium"
	return "Unknown"
