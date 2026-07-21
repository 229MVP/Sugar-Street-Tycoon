class_name SaveData
extends Resource
## Serializable player / shop progress. Versioned for forward-compatible loads.

const SAVE_VERSION := 1

enum OrderStatus {
	AVAILABLE,
	SELECTED,
	LEVEL_IN_PROGRESS,
	READY_TO_COMPLETE,
	COMPLETED,
	FAILED,
	EXPIRED,
}

@export var version: int = SAVE_VERSION
@export var last_saved_unix: int = 0

# Player
@export var player_level: int = 1
@export var experience: int = 0
@export var coins: int = 500
@export var stars: int = 0
@export var reputation: int = 0

# Shop
@export var shop_name: String = "Sugar Street Starter Shop"
@export var shop_level: int = 1

# Progression maps (serialized as Dictionaries)
@export var unlocked_recipes: Dictionary = {} # recipe_id -> true
@export var equipment_levels: Dictionary = {} # equipment_id -> level
@export var ingredients: Dictionary = {} # ingredient_id -> amount
@export var best_level_stars: Dictionary = {} # level_id -> 1..3
@export var best_level_scores: Dictionary = {} # level_id -> score

# Orders
@export var order_statuses: Dictionary = {} # order_id -> OrderStatus int
@export var order_level_results: Dictionary = {} # order_id -> {score, moves_remaining, stars}
@export var completed_order_ids: Array[String] = []
@export var active_order_id: String = ""
@export var visible_order_ids: Array[String] = [] ## Up to 3 shown in hub

# Settings
@export var settings: Dictionary = {
	"music_enabled": true,
	"sfx_enabled": true,
}


static func create_default() -> SaveData:
	var data := SaveData.new()
	data.version = SAVE_VERSION
	data.player_level = 1
	data.experience = 0
	data.coins = 500
	data.stars = 0
	data.reputation = 0
	data.shop_name = "Sugar Street Starter Shop"
	data.shop_level = 1
	data.unlocked_recipes = {
		&"chocolate_strawberries": true,
		&"classic_cupcakes": true,
	}
	data.equipment_levels = {
		&"oven": 1,
		&"mixer": 1,
		&"display_case": 1,
		&"checkout": 1,
	}
	data.ingredients = {
		&"chocolate": 10,
		&"strawberries": 10,
		&"flour": 10,
		&"sugar": 10,
		&"cream": 5,
		&"grapes": 0,
		&"caramel": 0,
		&"cookies": 0,
		&"cheesecake_filling": 0,
		&"packaging": 5,
	}
	data.order_statuses = {}
	data.order_level_results = {}
	data.completed_order_ids = []
	data.active_order_id = ""
	data.visible_order_ids = []
	data.best_level_stars = {}
	data.best_level_scores = {}
	data.last_saved_unix = int(Time.get_unix_time_from_system())
	return data


func duplicate_deep() -> SaveData:
	var copy := SaveData.new()
	copy.version = version
	copy.last_saved_unix = last_saved_unix
	copy.player_level = player_level
	copy.experience = experience
	copy.coins = coins
	copy.stars = stars
	copy.reputation = reputation
	copy.shop_name = shop_name
	copy.shop_level = shop_level
	copy.unlocked_recipes = unlocked_recipes.duplicate(true)
	copy.equipment_levels = equipment_levels.duplicate(true)
	copy.ingredients = ingredients.duplicate(true)
	copy.best_level_stars = best_level_stars.duplicate(true)
	copy.best_level_scores = best_level_scores.duplicate(true)
	copy.order_statuses = order_statuses.duplicate(true)
	copy.order_level_results = order_level_results.duplicate(true)
	copy.completed_order_ids = completed_order_ids.duplicate()
	copy.active_order_id = active_order_id
	copy.visible_order_ids = visible_order_ids.duplicate()
	copy.settings = settings.duplicate(true)
	return copy
