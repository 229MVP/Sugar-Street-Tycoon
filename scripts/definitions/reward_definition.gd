class_name RewardDefinition
extends Resource
## Reusable reward bundle: coins + XP + reputation + ingredient grants.
## Referenced by OrderDefinition so reward tuning lives in one reusable place
## instead of being duplicated across every order.

## Stable string id used as the save-file key. Never change once shipped.
@export var id: String = ""
@export var coins: int = 0
@export var experience: int = 0
@export var reputation: int = 0
@export var ingredients: Dictionary = {} ## ingredient_id -> amount


func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	if id.strip_edges() == "":
		errors.append("RewardDefinition: id is required")
	for key in ["coins", "experience", "reputation"]:
		if int(get(key)) < 0:
			errors.append("RewardDefinition '%s': %s cannot be negative" % [id, key])
	return errors


func to_dictionary() -> Dictionary:
	return {
		"coins": coins,
		"experience": experience,
		"reputation": reputation,
		"ingredients": ingredients.duplicate(true),
	}
