class_name BetaSmokeTest
extends RefCounted
## One-button automated smoke test (Phase 12). Debug-build only. Powers the
## Beta Diagnostics screen's "Run Smoke Test" button and is reused directly by
## `headless_content_counts_test.gd` so the same checks run in CI/regression.

const REQUIRED_SCENES := [
	"res://scenes/main/title_screen.tscn",
	"res://scenes/shop/shop_hub.tscn",
	"res://scenes/orders/orders_screen.tscn",
	"res://scenes/inventory/inventory_screen.tscn",
	"res://scenes/recipes/recipe_book.tscn",
	"res://scenes/upgrades/upgrades_screen.tscn",
	"res://scenes/workers/worker_roster.tscn",
	"res://scenes/decor/decor_screen.tscn",
	"res://scenes/gameplay/gameplay.tscn",
	"res://scenes/gameplay/board.tscn",
	"res://scenes/ui/hud.tscn",
	"res://scenes/ui/win_popup.tscn",
	"res://scenes/ui/loss_popup.tscn",
	"res://scenes/ui/pause_popup.tscn",
	"res://scenes/popups/level_complete_popup.tscn",
]

const REQUIRED_AUTOLOADS := ["GameState", "AudioManager", "SceneRouter"]

const VALID_WORKER_EFFECTS := [
	"order_coins", "order_xp", "order_reputation", "passive_income",
	"all_order_rewards", "bonus_ingredients", "bonus_star_chance", "",
]


## Full smoke test. Pass the active SceneTree (e.g. `get_tree()`) to also
## check autoloads and a live new-game initialization; omit it to run the
## pure data/content/save checks headlessly.
static func run_full(tree: SceneTree = null) -> Dictionary:
	var db := DefinitionDatabase.new()
	db.build()
	var sections := {
		"scenes": validate_scenes(),
		"content": validate_content(db),
		"save": validate_save_roundtrip(),
	}
	if tree:
		sections["autoloads"] = validate_autoloads(tree)
		sections["new_game"] = validate_new_game(tree)

	var all_ok := true
	var all_messages: Array[String] = []
	for key in sections.keys():
		var r: Dictionary = sections[key]
		all_ok = all_ok and bool(r.get("ok", false))
		for m in r.get("messages", []):
			all_messages.append("[%s] %s" % [key, m])
	return {"ok": all_ok, "messages": all_messages, "sections": sections}


static func validate_scenes() -> Dictionary:
	var messages: Array[String] = []
	var ok := true
	for path in REQUIRED_SCENES:
		if not ResourceLoader.exists(path):
			ok = false
			messages.append("missing scene: %s" % path)
	return {"ok": ok, "messages": messages}


static func validate_autoloads(tree: SceneTree) -> Dictionary:
	var messages: Array[String] = []
	var ok := true
	for singleton_name in REQUIRED_AUTOLOADS:
		if tree.root.get_node_or_null(singleton_name) == null:
			ok = false
			messages.append("missing autoload: %s" % singleton_name)
	return {"ok": ok, "messages": messages}


static func validate_save_roundtrip() -> Dictionary:
	var messages: Array[String] = []
	var ok := true
	var had_save := SaveManager.has_save()
	var backup_dict: Dictionary = {}
	if had_save:
		# Don't disturb a real player save during a diagnostics run.
		var existing := SaveManager.load_game()
		backup_dict = SaveManager._to_dict(existing)
	var data := SaveData.create_default()
	data.coins = 4321
	if not SaveManager.save_game(data):
		ok = false
		messages.append("save_game() returned false")
	else:
		var loaded := SaveManager.load_game()
		if loaded == null or loaded.coins != 4321:
			ok = false
			messages.append("load_game() roundtrip mismatch")
	if had_save:
		var restored := SaveManager._from_dict(backup_dict)
		SaveManager.save_game(restored)
	else:
		SaveManager.delete_save()
	return {"ok": ok, "messages": messages}


static func validate_new_game(tree: SceneTree) -> Dictionary:
	var messages: Array[String] = []
	var ok := true
	var gs := tree.root.get_node_or_null("GameState")
	if gs == null:
		return {"ok": false, "messages": ["GameState autoload missing — cannot test new_game()"]}
	var had_save := SaveManager.has_save()
	var backup_dict: Dictionary = {}
	if had_save:
		backup_dict = SaveManager._to_dict(SaveManager.load_game())
	gs.new_game()
	if gs.data == null or gs.data.player_level != 1 or gs.data.coins != 500:
		ok = false
		messages.append("new_game() did not initialize starter state correctly")
	if had_save:
		gs.data = SaveManager._from_dict(backup_dict)
		gs.save_now()
	return {"ok": ok, "messages": messages}


## Content/data integrity: duplicate ids, negative balances, and cross-references.
static func validate_content(db: DefinitionDatabase) -> Dictionary:
	var messages: Array[String] = []
	var ok := true

	if db.ingredient_sequence.size() != db.ingredients.size():
		ok = false
		messages.append("duplicate ingredient id detected")
	if db.recipe_sequence.size() != db.recipes.size():
		ok = false
		messages.append("duplicate recipe id detected")
	if db.upgrade_sequence.size() != db.upgrades.size():
		ok = false
		messages.append("duplicate upgrade id detected")
	if db.worker_sequence.size() != db.workers.size():
		ok = false
		messages.append("duplicate worker id detected")
	if db.customer_sequence.size() != db.customers.size():
		ok = false
		messages.append("duplicate customer id detected")
	if db.order_sequence.size() != db.orders.size():
		ok = false
		messages.append("duplicate order id detected")

	for id in db.ingredient_sequence:
		var def := db.get_ingredient(id)
		if def == null:
			ok = false
			messages.append("ingredient '%s' failed to load" % id)
			continue
		if def.starting_amount < 0:
			ok = false
			messages.append("ingredient '%s' has a negative starting_amount" % id)

	for id in db.recipe_sequence:
		var recipe := db.get_recipe(id)
		if recipe == null:
			ok = false
			messages.append("recipe '%s' failed to load" % id)
			continue
		for iid in recipe.order_ingredient_requirements.keys():
			if not db.ingredients.has(str(iid)):
				ok = false
				messages.append("recipe '%s' references unknown ingredient '%s'" % [id, iid])
		for iid in recipe.craft_ingredient_costs.keys():
			if not db.ingredients.has(str(iid)):
				ok = false
				messages.append("recipe '%s' craft cost references unknown ingredient '%s'" % [id, iid])
		if recipe.unlock_coin_cost < 0 or recipe.craft_coin_reward < 0:
			ok = false
			messages.append("recipe '%s' has a negative cost/reward" % id)

	for id in db.order_sequence:
		var order := db.get_order(id)
		if order == null:
			ok = false
			messages.append("order '%s' failed to load" % id)
			continue
		if not db.customers.has(order.customer_id):
			ok = false
			messages.append("order '%s' references unknown customer '%s'" % [id, order.customer_id])
		if not db.levels.has(order.level_id):
			ok = false
			messages.append("order '%s' references unknown level '%s'" % [id, order.level_id])
		if not db.rewards.has(order.reward_id):
			ok = false
			messages.append("order '%s' references unknown reward '%s'" % [id, order.reward_id])
		if not db.recipes.has(order.recipe_id):
			ok = false
			messages.append("order '%s' references unknown recipe '%s'" % [id, order.recipe_id])

	for id in db.worker_sequence:
		var worker := db.get_worker(id)
		if worker == null:
			ok = false
			messages.append("worker '%s' failed to load" % id)
			continue
		if worker.primary_bonus_type not in VALID_WORKER_EFFECTS:
			ok = false
			messages.append("worker '%s' has an unknown primary_bonus_type '%s'" % [id, worker.primary_bonus_type])
		if worker.secondary_bonus_type != "" and worker.secondary_bonus_type not in VALID_WORKER_EFFECTS:
			ok = false
			messages.append("worker '%s' has an unknown secondary_bonus_type '%s'" % [id, worker.secondary_bonus_type])
		if worker.hire_cost < 0:
			ok = false
			messages.append("worker '%s' has a negative hire_cost" % id)

	for id in db.upgrade_sequence:
		var upgrade := db.get_upgrade(id)
		if upgrade == null:
			ok = false
			messages.append("upgrade '%s' failed to load" % id)
			continue
		if upgrade.max_level < 1:
			ok = false
			messages.append("upgrade '%s' has an invalid max_level" % id)
		if upgrade.base_cost < 0:
			ok = false
			messages.append("upgrade '%s' has a negative base_cost" % id)

	return {"ok": ok, "messages": messages}
