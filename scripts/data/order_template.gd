class_name OrderTemplate
extends Resource
## Static customer order definition. Runtime status lives in SaveData.

enum Difficulty { EASY, MEDIUM, HARD }

@export var order_id: StringName = &""
@export var customer_name: String = ""
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


func difficulty_label() -> String:
	match difficulty:
		Difficulty.EASY: return "Easy"
		Difficulty.MEDIUM: return "Medium"
		Difficulty.HARD: return "Hard"
	return "Unknown"
