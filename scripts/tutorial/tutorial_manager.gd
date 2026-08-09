class_name TutorialManager
extends RefCounted
## Progressive + contextual first-session tutorials.
## Linear STEPS cover the core loop; FEATURE_TIPS appear once when the player
## first opens each management/feature surface. Progress persists in
## SaveData.tutorial_step / tutorial_completed / tutorial_flags.

const STEP_COUNT := 5

const STEPS: Array[Dictionary] = [
	{
		"screen": "shop_hub_intro",
		"title": "Welcome to Sugar Street!",
		"body": "This is your Shop Hub. Coins, stars, and energy sit at the top. Tap Orders to see what customers want today.",
	},
	{
		"screen": "orders",
		"title": "Orders, Goals & Rewards",
		"body": "Each order shows its goal, move limit, and rewards. Select an available order, then Start to begin its match-3 puzzle.",
	},
	{
		"screen": "gameplay",
		"title": "Swap, Specials & Boosters",
		"body": "Swap adjacent desserts to match 3+. Longer matches create Line, Bomb, and Rainbow specials. Use Hammer or Swap boosters from the bar when you need help — quantities are saved.",
	},
	{
		"screen": "level_complete",
		"title": "Winning an Order",
		"body": "Clear the goal before moves run out to win. Continue back to the Shop, then finish the order on Orders to claim coins and XP. If you fail, you can retry anytime.",
	},
	{
		"screen": "shop_hub_final",
		"title": "Grow Your Bakery",
		"body": "Explore Inventory, Recipes, Upgrades, Workers, Daily Bonus, and Settings from the hub. Each area has a short tip the first time you open it.",
	},
]

## One-shot contextual tips keyed by feature id.
const FEATURE_TIPS: Dictionary = {
	"inventory": {
		"title": "Inventory",
		"body": "Ingredients you earn and craft live here. Tap a row for quantity details — keep stocked so recipes and orders stay ready.",
	},
	"recipes": {
		"title": "Recipes",
		"body": "Unlock recipes with coins, then craft them when you have the ingredients. Crafted goods help grow your bakery.",
	},
	"upgrades": {
		"title": "Upgrades",
		"body": "Improve the Oven, Mixer, Display Case, and more. Each level costs coins and boosts rewards or shop speed.",
	},
	"workers": {
		"title": "Workers",
		"body": "Hire staff and assign them to stations. Workers grant bonus coins, XP, reputation, and passive income.",
	},
	"daily_bonus": {
		"title": "Daily Bonus",
		"body": "Claim one escalating reward each calendar day. Come back tomorrow to keep your streak — Day 7 is the biggest payout.",
	},
	"settings": {
		"title": "Settings",
		"body": "Adjust music, sound, vibration, and motion. Privacy and Support info live here too.",
	},
	"loss": {
		"title": "Out of Moves",
		"body": "You ran out of moves before finishing the goal. Retry the order or return to the Shop — progress is saved either way.",
	},
	"special_pieces": {
		"title": "Special Pieces",
		"body": "Match 4 for a Line clear, L/T shapes for a Bomb, and 5 for a Rainbow. Activate specials by matching or swapping them.",
	},
	"boosters": {
		"title": "Boosters",
		"body": "Hammer destroys one tile. Swap forces any adjacent exchange. Counts never go below zero and persist in your save.",
	},
}


static func is_active(data: SaveData) -> bool:
	return data != null and not data.tutorial_completed and data.tutorial_step >= 0 and data.tutorial_step < STEP_COUNT


static func current_step(data: SaveData) -> Dictionary:
	if not is_active(data):
		return {}
	return STEPS[data.tutorial_step]


static func should_show(data: SaveData, screen_key: String) -> bool:
	var step := current_step(data)
	return not step.is_empty() and str(step.get("screen", "")) == screen_key


static func advance(data: SaveData) -> void:
	if data == null:
		return
	data.tutorial_step += 1
	if data.tutorial_step >= STEP_COUNT:
		complete(data)


static func complete(data: SaveData) -> void:
	if data == null:
		return
	data.tutorial_completed = true
	data.tutorial_step = -1


static func skip(data: SaveData) -> void:
	## Skipping finishes only the linear first-session flow. Contextual
	## feature tips still appear once when each area is opened for the first time.
	complete(data)


static func reset_debug_only(data: SaveData) -> void:
	if not BuildConfig.debug_features_enabled() or data == null:
		return
	data.tutorial_completed = false
	data.tutorial_step = 0
	data.tutorial_flags = {}


static func should_show_feature_tip(data: SaveData, feature_id: String) -> bool:
	if data == null or feature_id.strip_edges() == "":
		return false
	# While the linear tutorial is still active, avoid stacking tips.
	if is_active(data):
		return false
	_ensure_flags(data)
	return not bool(data.tutorial_flags.get(str(feature_id), false))


static func feature_tip(feature_id: String) -> Dictionary:
	return FEATURE_TIPS.get(str(feature_id), {})


static func mark_feature_seen(data: SaveData, feature_id: String) -> void:
	if data == null:
		return
	_ensure_flags(data)
	data.tutorial_flags[str(feature_id)] = true


static func _ensure_flags(data: SaveData) -> void:
	if typeof(data.tutorial_flags) != TYPE_DICTIONARY:
		data.tutorial_flags = {}
