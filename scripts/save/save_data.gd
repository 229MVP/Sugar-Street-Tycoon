class_name SaveData
extends Resource
## Serializable player / shop progress. Versioned for forward-compatible loads.

const SAVE_VERSION := 7
const WORKER_SAVE_VERSION := 1
const DECORATION_SAVE_VERSION := 1
const UPGRADE_SAVE_VERSION := 1

enum OrderStatus {
	AVAILABLE,
	SELECTED,
	LEVEL_IN_PROGRESS,
	READY_TO_COMPLETE,
	COMPLETED,
	FAILED,
	LOCKED,
	EXPIRED,
}

@export var version: int = SAVE_VERSION
## Human-readable app/build version that wrote this save (BuildConfig.APP_VERSION).
## Informational only — save compatibility is governed by `version`, not this.
@export var app_version: String = ""
@export var last_saved_unix: int = 0
@export var last_active_unix: int = 0
## Safe-resume destination: the scene path active when this save was last
## written, so a future "resume where I left off" feature has a stable field
## to read. Beta 0.1 always resumes at the Shop Hub regardless of this value.
@export var current_screen: String = ""

# Player
@export var player_level: int = 1
@export var experience: int = 0
@export var coins: int = 500
@export var stars: int = 0
@export var reputation: int = 0

# Shop
@export var shop_name: String = "Sugar Street Starter Shop"
@export var shop_level: int = 1
@export var shop_appeal: int = 0
@export var shop_appeal_tier: String = "Plain"

# Decorations (ownership / placement separate from catalog definitions)
@export var decoration_save_version: int = DECORATION_SAVE_VERSION
@export var owned_decorations: Dictionary = {} ## decoration_id -> true
@export var placed_decorations: Dictionary = {} ## slot_id -> decoration_id
@export var unlocked_decorations: Dictionary = {} ## decoration_id -> true

# Progression maps
@export var unlocked_recipes: Dictionary = {}
@export var equipment_levels: Dictionary = {}
@export var ingredients: Dictionary = {}
## Non-consumable pantry items (currently unused placeholders for future tools).
@export var tools: Dictionary = {}
## New data-driven upgrade system (Oven/Mixer/Display Case/Cash Register/Decor/Lighting).
@export var upgrade_save_version: int = UPGRADE_SAVE_VERSION
@export var upgrade_levels: Dictionary = {} ## upgrade_id -> level
## Lifetime crafted-item counters from the Recipe Book craft action.
@export var crafted_items: Dictionary = {} ## recipe_id -> count
@export var best_level_stars: Dictionary = {}
@export var best_level_scores: Dictionary = {}
@export var best_order_stars: Dictionary = {}
@export var best_order_scores: Dictionary = {}
@export var granted_level_stars: Dictionary = {} ## level_id -> permanent stars already awarded

# Orders
@export var order_statuses: Dictionary = {}
@export var order_level_results: Dictionary = {}
@export var order_reward_claimed: Dictionary = {} ## order_id -> bool
@export var completed_order_ids: Array[String] = []
@export var active_order_id: String = ""
@export var visible_order_ids: Array[String] = []

# Workers (kept for migration; UI gated Coming Soon this phase)
@export var worker_save_version: int = WORKER_SAVE_VERSION
@export var hired_workers: Dictionary = {} ## worker_id -> true
@export var worker_levels: Dictionary = {} ## worker_id -> level 1..10
@export var worker_assignments: Dictionary = {} ## station_id -> worker_id
@export var worker_unlock_flags: Dictionary = {} ## worker_id -> true (explicit unlock)

# Passive / offline income (kept for migration; UI gated)
@export var stored_passive_coins: float = 0.0
@export var last_passive_tick_unix: int = 0
@export var last_offline_calc_unix: int = 0
@export var offline_pending_popup: Dictionary = {} ## shown once then cleared on collect/dismiss

# Tutorial (first-session onboarding — see TutorialManager)
@export var tutorial_completed: bool = false
@export var tutorial_step: int = 0 ## Index into the tutorial step sequence; -1 once skipped/finished.

# Daily bonus (7-day streak rewards — see DailyBonusManager)
@export var daily_bonus_state: Dictionary = {
	"streak_day": 0,
	"last_claim_unix": 0,
	"last_claim_date": "",
	"claimed_today": false,
}

## In-level booster inventory (hammer destroys one tile, swap forces adjacent swap).
@export var booster_inventory: Dictionary = {
	"hammer": 3,
	"swap": 3,
}

## Placeholder until push notifications are implemented. One of:
## "not_set" | "enabled" | "disabled".
@export var notification_preference: String = "not_set"

# Settings
@export var settings: Dictionary = {
	"music_enabled": true,
	"sfx_enabled": true,
	"music_volume": 0.8,
	"sfx_volume": 0.9,
	"vibration": true,
	"reduce_motion": false,
}


## Canonical starter pantry. Keys are always plain Strings for save stability.
static func starter_ingredients() -> Dictionary:
	return {
		"chocolate": 5,
		"strawberries": 5,
		"flour": 5,
		"sugar": 5,
		"cream": 3,
		"grapes": 0,
		"caramel": 0,
		"cookies": 0,
		"cheesecake_filling": 0,
		"packaging": 3,
		"butter": 2,
		"vanilla": 1,
	}


## Canonical starter upgrade levels. Keys are always plain Strings for save stability.
static func starter_upgrade_levels() -> Dictionary:
	return {
		"oven": 1,
		"mixer": 1,
		"display_case": 1,
		"cash_register": 1,
		"decor": 1,
		"lighting": 1,
	}


## Add missing ingredient keys from the starter template without overwriting valid amounts.
## Clamps negatives to zero. Does not refill an intentional all-zero pantry.
static func ensure_ingredient_keys(ingredients: Dictionary) -> Dictionary:
	var out := {}
	# Normalize existing keys to String and clamp.
	for key in ingredients.keys():
		out[str(key)] = maxi(0, int(ingredients[key]))
	var starter := starter_ingredients()
	for key in starter.keys():
		if not out.has(key):
			out[key] = int(starter[key])
	return out


static func create_default() -> SaveData:
	var data := SaveData.new()
	data.version = SAVE_VERSION
	data.app_version = BuildConfig.APP_VERSION
	data.current_screen = ""
	data.tutorial_completed = false
	data.tutorial_step = 0
	data.daily_bonus_state = {
		"streak_day": 0,
		"last_claim_unix": 0,
		"last_claim_date": "",
		"claimed_today": false,
	}
	data.booster_inventory = BoosterManager.STARTER_COUNTS.duplicate(true)
	data.notification_preference = "not_set"
	data.worker_save_version = WORKER_SAVE_VERSION
	data.player_level = 1
	data.experience = 0
	data.coins = 500
	data.stars = 0
	data.reputation = 0
	data.shop_name = "Sugar Street Starter Shop"
	data.shop_level = 1
	data.shop_appeal = 0
	data.shop_appeal_tier = "Plain"
	data.decoration_save_version = DECORATION_SAVE_VERSION
	data.owned_decorations = {
		"wooden_starter_sign": true,
		"small_mint_plant": true,
	}
	data.unlocked_decorations = {
		"wooden_starter_sign": true,
		"small_mint_plant": true,
	}
	data.placed_decorations = {
		"front_sign": "wooden_starter_sign",
		"plant_corner": "small_mint_plant",
	}
	data.shop_appeal = 10
	data.shop_appeal_tier = "Plain"
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
	data.upgrade_save_version = UPGRADE_SAVE_VERSION
	data.upgrade_levels = starter_upgrade_levels()
	data.ingredients = starter_ingredients()
	data.tools = {}
	data.crafted_items = {}
	data.order_statuses = {}
	data.order_level_results = {}
	data.order_reward_claimed = {}
	data.completed_order_ids = []
	data.active_order_id = ""
	data.visible_order_ids = []
	data.best_level_stars = {}
	data.best_level_scores = {}
	data.best_order_stars = {}
	data.best_order_scores = {}
	data.granted_level_stars = {}
	data.hired_workers = {}
	data.worker_levels = {}
	data.worker_assignments = {}
	data.worker_unlock_flags = {"lily": true}
	data.stored_passive_coins = 0.0
	var now := int(Time.get_unix_time_from_system())
	data.last_saved_unix = now
	data.last_active_unix = now
	data.last_passive_tick_unix = now
	data.last_offline_calc_unix = now
	data.offline_pending_popup = {}
	data.settings = {
		"music_enabled": true,
		"sfx_enabled": true,
		"music_volume": 0.8,
		"sfx_volume": 0.9,
		"vibration": true,
		"reduce_motion": false,
		"last_decor_category": "All",
		"decor_seen_unlocks": {},
	}
	return data


func apply_worker_defaults() -> void:
	## Called during migration / repair for older saves.
	if app_version.strip_edges() == "":
		app_version = BuildConfig.APP_VERSION
	if typeof(current_screen) != TYPE_STRING:
		current_screen = ""
	if typeof(daily_bonus_state) != TYPE_DICTIONARY:
		daily_bonus_state = {}
	for key in ["streak_day", "last_claim_unix"]:
		if not daily_bonus_state.has(key):
			daily_bonus_state[key] = 0
	if not daily_bonus_state.has("last_claim_date"):
		daily_bonus_state["last_claim_date"] = ""
	if not daily_bonus_state.has("claimed_today"):
		daily_bonus_state["claimed_today"] = false
	BoosterManager.ensure_defaults(self)
	DailyBonusManager.sync_calendar_state(daily_bonus_state)
	if notification_preference not in ["not_set", "enabled", "disabled"]:
		notification_preference = "not_set"
	tutorial_step = maxi(-1, tutorial_step)
	if worker_save_version < 1:
		worker_save_version = WORKER_SAVE_VERSION
	if typeof(hired_workers) != TYPE_DICTIONARY:
		hired_workers = {}
	if typeof(worker_levels) != TYPE_DICTIONARY:
		worker_levels = {}
	if typeof(worker_assignments) != TYPE_DICTIONARY:
		worker_assignments = {}
	if typeof(worker_unlock_flags) != TYPE_DICTIONARY:
		worker_unlock_flags = {}
	# "ava" was the original starter worker; "lily" replaced her in the new roster.
	if bool(worker_unlock_flags.get("ava", false)):
		worker_unlock_flags["lily"] = true
	if not worker_unlock_flags.has("lily"):
		worker_unlock_flags["lily"] = true
	if typeof(tools) != TYPE_DICTIONARY:
		tools = {}
	if typeof(crafted_items) != TYPE_DICTIONARY:
		crafted_items = {}
	if typeof(upgrade_levels) != TYPE_DICTIONARY:
		upgrade_levels = {}
	if upgrade_levels.is_empty():
		upgrade_levels = starter_upgrade_levels()
	upgrade_save_version = maxi(upgrade_save_version, UPGRADE_SAVE_VERSION)
	if stored_passive_coins < 0.0:
		stored_passive_coins = 0.0
	var now := int(Time.get_unix_time_from_system())
	if last_active_unix <= 0:
		last_active_unix = now
	if last_passive_tick_unix <= 0:
		last_passive_tick_unix = now
	if last_offline_calc_unix <= 0:
		last_offline_calc_unix = now
	if typeof(offline_pending_popup) != TYPE_DICTIONARY:
		offline_pending_popup = {}
	if typeof(order_reward_claimed) != TYPE_DICTIONARY:
		order_reward_claimed = {}
	if typeof(best_order_stars) != TYPE_DICTIONARY:
		best_order_stars = {}
	if typeof(best_order_scores) != TYPE_DICTIONARY:
		best_order_scores = {}
	if typeof(granted_level_stars) != TYPE_DICTIONARY:
		granted_level_stars = {}
	if typeof(settings) != TYPE_DICTIONARY:
		settings = {}
	for key in ["music_enabled", "sfx_enabled", "vibration"]:
		if not settings.has(key):
			settings[key] = true
	if not settings.has("music_volume"):
		settings["music_volume"] = 0.8
	if not settings.has("sfx_volume"):
		settings["sfx_volume"] = 0.9
	if not settings.has("reduce_motion"):
		settings["reduce_motion"] = false
	if not settings.has("last_decor_category"):
		settings["last_decor_category"] = "All"
	if typeof(settings.get("decor_seen_unlocks", null)) != TYPE_DICTIONARY:
		settings["decor_seen_unlocks"] = {}
	if typeof(owned_decorations) != TYPE_DICTIONARY:
		owned_decorations = {}
	if typeof(placed_decorations) != TYPE_DICTIONARY:
		placed_decorations = {}
	if typeof(unlocked_decorations) != TYPE_DICTIONARY:
		unlocked_decorations = {}
	if decoration_save_version < 1:
		decoration_save_version = DECORATION_SAVE_VERSION
	shop_level = clampi(shop_level, 1, 5)
	shop_appeal = maxi(0, shop_appeal)
	# Cap equipment at phase max (3).
	for eq_id in equipment_levels.keys():
		equipment_levels[eq_id] = clampi(int(equipment_levels[eq_id]), 1, 3)
	# Broad ceiling here; UpgradeManager.ensure_defaults() clamps per-definition max_level.
	for up_id in upgrade_levels.keys():
		upgrade_levels[up_id] = clampi(int(upgrade_levels[up_id]), 1, 5)
	version = maxi(version, SAVE_VERSION)


func clone_save_data() -> SaveData:
	var copy := SaveData.new()
	copy.version = version
	copy.app_version = app_version
	copy.current_screen = current_screen
	copy.tutorial_completed = tutorial_completed
	copy.tutorial_step = tutorial_step
	copy.daily_bonus_state = daily_bonus_state.duplicate(true)
	copy.booster_inventory = booster_inventory.duplicate(true)
	copy.notification_preference = notification_preference
	copy.last_saved_unix = last_saved_unix
	copy.last_active_unix = last_active_unix
	copy.player_level = player_level
	copy.experience = experience
	copy.coins = coins
	copy.stars = stars
	copy.reputation = reputation
	copy.shop_name = shop_name
	copy.shop_level = shop_level
	copy.shop_appeal = shop_appeal
	copy.shop_appeal_tier = shop_appeal_tier
	copy.decoration_save_version = decoration_save_version
	copy.owned_decorations = owned_decorations.duplicate(true)
	copy.placed_decorations = placed_decorations.duplicate(true)
	copy.unlocked_decorations = unlocked_decorations.duplicate(true)
	copy.unlocked_recipes = unlocked_recipes.duplicate(true)
	copy.equipment_levels = equipment_levels.duplicate(true)
	copy.upgrade_save_version = upgrade_save_version
	copy.upgrade_levels = upgrade_levels.duplicate(true)
	copy.ingredients = ingredients.duplicate(true)
	copy.tools = tools.duplicate(true)
	copy.crafted_items = crafted_items.duplicate(true)
	copy.best_level_stars = best_level_stars.duplicate(true)
	copy.best_level_scores = best_level_scores.duplicate(true)
	copy.best_order_stars = best_order_stars.duplicate(true)
	copy.best_order_scores = best_order_scores.duplicate(true)
	copy.granted_level_stars = granted_level_stars.duplicate(true)
	copy.order_statuses = order_statuses.duplicate(true)
	copy.order_level_results = order_level_results.duplicate(true)
	copy.order_reward_claimed = order_reward_claimed.duplicate(true)
	copy.completed_order_ids = completed_order_ids.duplicate()
	copy.active_order_id = active_order_id
	copy.visible_order_ids = visible_order_ids.duplicate()
	copy.settings = settings.duplicate(true)
	copy.worker_save_version = worker_save_version
	copy.hired_workers = hired_workers.duplicate(true)
	copy.worker_levels = worker_levels.duplicate(true)
	copy.worker_assignments = worker_assignments.duplicate(true)
	copy.worker_unlock_flags = worker_unlock_flags.duplicate(true)
	copy.stored_passive_coins = stored_passive_coins
	copy.last_passive_tick_unix = last_passive_tick_unix
	copy.last_offline_calc_unix = last_offline_calc_unix
	copy.offline_pending_popup = offline_pending_popup.duplicate(true)
	return copy
