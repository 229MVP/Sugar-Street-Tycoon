class_name OrderTemplate
extends Resource
## Static customer order definition. Runtime status lives in SaveData.

enum Difficulty { EASY, MEDIUM, HARD }

@export var order_id: StringName = &""
@export var customer_name: String = ""
@export var customer_message: String = ""
@export var customer_avatar: Texture2D
@export var customer_color: Color = Color(0.9, 0.55, 0.65, 1)
@export var recipe_id: StringName = &""
@export var level_id: String = "level_01"
@export var coin_reward: int = 100
@export var experience_reward: int = 20
@export var reputation_reward: int = 5
@export var ingredient_rewards: Dictionary = {} # ingredient_id -> amount
@export var difficulty: Difficulty = Difficulty.EASY
@export var time_limit_seconds: float = 0.0 ## Reserved for future timed orders.
@export var requires_recipe_unlocked: bool = true

## Puzzle overrides applied when starting this order (keeps board systems intact).
@export var target_piece_id: StringName = &""
@export var target_amount: int = 0
@export var move_limit: int = 0
@export var objective_description: String = ""
## Extra collection goals: Array of Dictionaries { "piece_id": StringName/String, "amount": int }
@export var additional_objectives: Array = []


func difficulty_label() -> String:
	match difficulty:
		Difficulty.EASY: return "Easy"
		Difficulty.MEDIUM: return "Medium"
		Difficulty.HARD: return "Hard"
	return "Unknown"


func recipe_display_name(catalog: ContentCatalog = null) -> String:
	if catalog != null:
		var recipe := catalog.get_recipe(recipe_id)
		if recipe:
			return recipe.display_name
	return str(recipe_id).replace("_", " ").capitalize()


func all_collection_targets() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if target_piece_id != &"" and target_amount > 0:
		result.append({"piece_id": target_piece_id, "amount": target_amount})
	for entry in additional_objectives:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var pid: Variant = entry.get("piece_id", &"")
		var amt := int(entry.get("amount", 0))
		if str(pid) == "" or amt <= 0:
			continue
		result.append({"piece_id": StringName(str(pid)), "amount": amt})
	return result


func objective_text() -> String:
	if objective_description != "":
		return objective_description
	var targets := all_collection_targets()
	if targets.is_empty():
		return "Complete the puzzle"
	if targets.size() == 1:
		return "Collect %d %ss" % [int(targets[0]["amount"]), str(targets[0]["piece_id"])]
	var parts: PackedStringArray = []
	for t in targets:
		parts.append("%d %ss" % [int(t["amount"]), str(t["piece_id"])])
	return "Collect " + " + ".join(parts)


func unlock_requirement_text() -> String:
	if requires_recipe_unlocked:
		return "Unlock recipe: %s" % recipe_display_name()
	return "Locked"
