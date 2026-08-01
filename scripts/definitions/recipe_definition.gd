class_name RecipeDefinition
extends Resource
## Data-driven dessert recipe. Supports two independent gates:
##   1) Order-unlock (spends coins once so the recipe can fulfil customer orders).
##   2) Crafting (consumes pantry ingredients to earn coins/XP/reputation on demand).
## Both gates share the same `unlocked_recipes` save flag as a single source of truth.

enum Category { FRUIT_TREATS, CUPCAKES, COOKIES, DONUTS, CHEESECAKES, DESSERT_BOXES }
enum Difficulty { EASY, MEDIUM, HARD, EXPERT }

## Stable string id used as the save-file key. Never change once shipped.
@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var category: Category = Category.FRUIT_TREATS
@export var difficulty: Difficulty = Difficulty.EASY
@export var icon: Texture2D
@export var icon_path: String = ""
@export var fallback_color: Color = Color(1, 0.75, 0.8, 1)

## Locked/unlocked gating (shared with legacy order-unlock flow).
@export var unlocked_by_default: bool = false
@export var required_player_level: int = 1
@export var required_stars: int = 0
@export var unlock_coin_cost: int = 0

## Order-fulfilment metadata (bridged into legacy RecipeData for match-3 orders).
@export var base_selling_value: int = 100
@export var order_ingredient_requirements: Dictionary = {} ## ingredient_id -> amount

## Crafting: consumes ingredients directly for on-demand rewards.
@export var craft_ingredient_costs: Dictionary = {} ## ingredient_id -> amount
@export var craft_coin_reward: int = 0
@export var craft_xp_reward: int = 0
@export var craft_reputation_reward: int = 0


func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	if id.strip_edges() == "":
		errors.append("RecipeDefinition: id is required")
	if display_name.strip_edges() == "":
		errors.append("RecipeDefinition '%s': display_name is required" % id)
	if unlock_coin_cost < 0:
		errors.append("RecipeDefinition '%s': unlock_coin_cost cannot be negative" % id)
	if craft_coin_reward < 0:
		errors.append("RecipeDefinition '%s': craft_coin_reward cannot be negative" % id)
	for key in craft_ingredient_costs.keys():
		if int(craft_ingredient_costs[key]) < 0:
			errors.append("RecipeDefinition '%s': craft cost for '%s' cannot be negative" % [id, str(key)])
	return errors


func category_label() -> String:
	match category:
		Category.FRUIT_TREATS: return "Fruit Treats"
		Category.CUPCAKES: return "Cupcakes"
		Category.COOKIES: return "Cookies"
		Category.DONUTS: return "Donuts"
		Category.CHEESECAKES: return "Cheesecakes"
		Category.DESSERT_BOXES: return "Dessert Boxes"
	return "Unknown"


func difficulty_label() -> String:
	match difficulty:
		Difficulty.EASY: return "Easy"
		Difficulty.MEDIUM: return "Medium"
		Difficulty.HARD: return "Hard"
		Difficulty.EXPERT: return "Expert"
	return "Unknown"


## Bridge to the legacy RecipeData resource used by ContentCatalog / orders / UI.
func to_recipe_data() -> RecipeData:
	var data := RecipeData.new()
	data.recipe_id = StringName(id)
	data.display_name = display_name
	data.description = description
	match category:
		Category.FRUIT_TREATS: data.category = RecipeData.Category.FRUIT_TREATS
		Category.CUPCAKES: data.category = RecipeData.Category.CUPCAKES
		Category.COOKIES: data.category = RecipeData.Category.COOKIES
		Category.DONUTS: data.category = RecipeData.Category.DONUTS
		Category.CHEESECAKES: data.category = RecipeData.Category.CHEESECAKES
		Category.DESSERT_BOXES: data.category = RecipeData.Category.DESSERT_BOXES
	match difficulty:
		Difficulty.EASY: data.rarity = RecipeData.Rarity.COMMON
		Difficulty.MEDIUM: data.rarity = RecipeData.Rarity.UNCOMMON
		Difficulty.HARD: data.rarity = RecipeData.Rarity.RARE
		Difficulty.EXPERT: data.rarity = RecipeData.Rarity.PREMIUM
	data.unlocked_by_default = unlocked_by_default
	data.required_player_level = required_player_level
	data.required_stars = required_stars
	data.unlock_coin_cost = unlock_coin_cost
	data.base_selling_value = base_selling_value
	var req: Dictionary = {}
	for key in order_ingredient_requirements.keys():
		req[StringName(str(key))] = int(order_ingredient_requirements[key])
	data.ingredient_requirements = req
	data.fallback_color = fallback_color
	data.icon = icon
	return data
