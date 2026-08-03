class_name TutorialManager
extends RefCounted
## Lightweight first-session tutorial (Phase 11). A short sequence of
## skippable modal steps anchored to specific screens, covering:
##   1. Entering the Shop Hub        (step 0, screen "shop_hub_intro")
##   2. Selecting an order           (step 0, combined with #1)
##   3. Starting a puzzle            (step 1, screen "orders")
##   4. Swapping pieces              (step 2, screen "gameplay")
##   5. Understanding the goal       (step 2, combined with #4)
##   6. Completing the level         (step 3, screen "level_complete")
##   7. Claiming rewards             (step 3, combined with #6)
##   8. Opening one management screen(step 4, screen "shop_hub_final")
## Progress persists in SaveData.tutorial_step / tutorial_completed so the
## tutorial never repeats after finishing, and resumes at the same
## not-yet-dismissed step if the app closes mid-flow.

const STEP_COUNT := 5

const STEPS: Array[Dictionary] = [
	{
		"screen": "shop_hub_intro",
		"title": "Welcome to Sugar Street!",
		"body": "This is your Shop Hub. Tap Orders to see what your customers want today.",
	},
	{
		"screen": "orders",
		"title": "Start a Puzzle",
		"body": "Select an available order, then tap Start to begin its match-3 puzzle and prepare it.",
	},
	{
		"screen": "gameplay",
		"title": "Swap & Match",
		"body": "Tap or drag two adjacent desserts to swap them and match 3 or more. Your goal is shown at the top — clear it before you run out of moves!",
	},
	{
		"screen": "level_complete",
		"title": "Order Complete!",
		"body": "Great work! Tap Continue to return to the Shop Hub, then finish the order on the Orders screen to claim your coins and XP.",
	},
	{
		"screen": "shop_hub_final",
		"title": "Grow Your Bakery",
		"body": "Explore Inventory, Recipes, Upgrades, and Workers anytime to grow your shop.",
	},
]


static func is_active(data: SaveData) -> bool:
	return data != null and not data.tutorial_completed and data.tutorial_step >= 0 and data.tutorial_step < STEP_COUNT


## Returns the step dictionary for the current step, or {} if the tutorial
## isn't active (already completed or explicitly skipped).
static func current_step(data: SaveData) -> Dictionary:
	if not is_active(data):
		return {}
	return STEPS[data.tutorial_step]


## True if the tutorial is active and currently on the step matching `screen_key`.
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
	complete(data)


## Editor/debug-only helper so testers can re-run the tutorial. Wired from
## ShopDebugPanel; never reachable in a release build.
static func reset_debug_only(data: SaveData) -> void:
	if not BuildConfig.debug_features_enabled() or data == null:
		return
	data.tutorial_completed = false
	data.tutorial_step = 0
