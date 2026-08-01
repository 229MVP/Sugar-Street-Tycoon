class_name OrderDefinition
extends Resource
## Data-driven customer order. Bridges into the existing OrderTemplate resource
## so the working orders board / match-3 launch flow is untouched.

enum Difficulty { EASY, MEDIUM, HARD }

## Stable string id used as the save-file key. Never change once shipped.
@export var id: String = ""
@export var customer_id: String = ""
@export var recipe_id: String = ""
@export var level_id: String = "level_01"
@export var reward_id: String = ""
@export var difficulty: Difficulty = Difficulty.EASY
@export var requires_recipe_unlocked: bool = true
## Puzzle overrides applied when starting this order (keeps board systems intact).
@export var target_piece_id: String = ""
@export var target_amount: int = 0
@export var move_limit: int = 0
@export var objective_description: String = ""
## Extra collection goals: Array of {"piece_id": String, "amount": int}
@export var additional_objectives: Array[Dictionary] = []


func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	if id.strip_edges() == "":
		errors.append("OrderDefinition: id is required")
	if customer_id.strip_edges() == "":
		errors.append("OrderDefinition '%s': customer_id is required" % id)
	if recipe_id.strip_edges() == "":
		errors.append("OrderDefinition '%s': recipe_id is required" % id)
	return errors


func difficulty_label() -> String:
	match difficulty:
		Difficulty.EASY: return "Easy"
		Difficulty.MEDIUM: return "Medium"
		Difficulty.HARD: return "Hard"
	return "Unknown"


## Bridge to the legacy OrderTemplate resource used by ContentCatalog / GameState.
func to_order_template(customer: CustomerDefinition, reward: RewardDefinition) -> OrderTemplate:
	var order := OrderTemplate.new()
	order.order_id = StringName(id)
	order.customer_name = customer.display_name if customer else customer_id.capitalize()
	order.customer_message = customer.greeting if customer else ""
	order.customer_color = customer.fallback_color if customer else Color(0.9, 0.55, 0.65, 1)
	order.recipe_id = StringName(recipe_id)
	order.level_id = level_id
	order.coin_reward = reward.coins if reward else 100
	order.experience_reward = reward.experience if reward else 20
	order.reputation_reward = reward.reputation if reward else 5
	var ing: Dictionary = {}
	if reward:
		for key in reward.ingredients.keys():
			ing[StringName(str(key))] = int(reward.ingredients[key])
	order.ingredient_rewards = ing
	match difficulty:
		Difficulty.EASY: order.difficulty = OrderTemplate.Difficulty.EASY
		Difficulty.MEDIUM: order.difficulty = OrderTemplate.Difficulty.MEDIUM
		Difficulty.HARD: order.difficulty = OrderTemplate.Difficulty.HARD
	order.requires_recipe_unlocked = requires_recipe_unlocked
	order.target_piece_id = StringName(target_piece_id)
	order.target_amount = target_amount
	order.move_limit = move_limit
	order.objective_description = objective_description
	var extra: Array = []
	for entry in additional_objectives:
		extra.append({"piece_id": StringName(str(entry.get("piece_id", ""))), "amount": int(entry.get("amount", 0))})
	order.additional_objectives = extra
	return order
