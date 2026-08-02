class_name DefinitionDatabase
extends RefCounted
## Single source of truth for all seed content: ingredients, recipes, upgrades,
## workers, customers, orders, rewards, puzzle levels, and equipment.
## `build()` seeds everything; `apply_to_catalog()` bridges definitions into the
## legacy ContentCatalog Data types so the existing match-3 board, orders flow,
## and UI keep working without a rewrite.

var ingredients: Dictionary = {} # id -> IngredientDefinition
var recipes: Dictionary = {} # id -> RecipeDefinition
var upgrades: Dictionary = {} # id -> UpgradeDefinition
var workers: Dictionary = {} # id -> WorkerDefinition
var customers: Dictionary = {} # id -> CustomerDefinition
var orders: Dictionary = {} # id -> OrderDefinition
var rewards: Dictionary = {} # id -> RewardDefinition
var levels: Dictionary = {} # id -> PuzzleLevelDefinition
var equipment: Dictionary = {} # id -> EquipmentDefinition

var ingredient_sequence: Array[String] = []
var recipe_sequence: Array[String] = []
var upgrade_sequence: Array[String] = []
var worker_sequence: Array[String] = []
var customer_sequence: Array[String] = []
var order_sequence: Array[String] = []
var equipment_sequence: Array[String] = []


func build() -> void:
	_seed_ingredients()
	_seed_equipment()
	_seed_upgrades()
	_seed_recipes()
	_seed_workers()
	_seed_customers()
	_seed_rewards()
	_seed_levels()
	_seed_orders()
	_validate_all()


func get_ingredient(id: String) -> IngredientDefinition:
	return ingredients.get(id) as IngredientDefinition


func get_recipe(id: String) -> RecipeDefinition:
	return recipes.get(id) as RecipeDefinition


func get_upgrade(id: String) -> UpgradeDefinition:
	return upgrades.get(id) as UpgradeDefinition


func get_worker(id: String) -> WorkerDefinition:
	return workers.get(id) as WorkerDefinition


func get_customer(id: String) -> CustomerDefinition:
	return customers.get(id) as CustomerDefinition


func get_order(id: String) -> OrderDefinition:
	return orders.get(id) as OrderDefinition


func get_reward(id: String) -> RewardDefinition:
	return rewards.get(id) as RewardDefinition


func get_equipment(id: String) -> EquipmentDefinition:
	return equipment.get(id) as EquipmentDefinition


## Canonical starter pantry amounts (String keys, save-file compatible).
func starter_ingredient_amounts() -> Dictionary:
	var out := {}
	for id in ingredient_sequence:
		var def := get_ingredient(id)
		if def and not def.is_tool:
			out[id] = maxi(0, def.starting_amount)
	return out


func starter_upgrade_levels() -> Dictionary:
	var out := {}
	for id in upgrade_sequence:
		var def := get_upgrade(id)
		if def:
			out[id] = def.starting_level
	return out


# ---------------------------------------------------------------------------
# Ingredients (12)
# ---------------------------------------------------------------------------

func _add_ingredient(id: String, name: String, cat: IngredientDefinition.Category, start: int,
		color: Color, desc: String = "", is_tool: bool = false, max_stack: int = 9999) -> void:
	var def := IngredientDefinition.new()
	def.id = id
	def.display_name = name
	def.category = cat
	def.starting_amount = start
	def.fallback_color = color
	def.description = desc if desc != "" else "Bakery ingredient: %s." % name
	def.is_tool = is_tool
	def.max_stack = max_stack
	ingredients[id] = def
	ingredient_sequence.append(id)


func _seed_ingredients() -> void:
	ingredients.clear()
	ingredient_sequence.clear()
	_add_ingredient("chocolate", "Chocolate", IngredientDefinition.Category.FLAVORING, 5, Color(0.36, 0.23, 0.13))
	_add_ingredient("strawberries", "Strawberries", IngredientDefinition.Category.FRUIT, 5, Color(0.86, 0.27, 0.35))
	_add_ingredient("flour", "Flour", IngredientDefinition.Category.BAKING, 5, Color(0.93, 0.9, 0.82))
	_add_ingredient("sugar", "Sugar", IngredientDefinition.Category.BAKING, 5, Color(0.95, 0.95, 0.95))
	_add_ingredient("cream", "Cream", IngredientDefinition.Category.BAKING, 3, Color(0.98, 0.94, 0.88))
	_add_ingredient("grapes", "Grapes", IngredientDefinition.Category.FRUIT, 0, Color(0.55, 0.3, 0.65))
	_add_ingredient("caramel", "Caramel", IngredientDefinition.Category.FLAVORING, 0, Color(0.78, 0.5, 0.2))
	_add_ingredient("cookies", "Cookies", IngredientDefinition.Category.FLAVORING, 0, Color(0.72, 0.5, 0.28))
	_add_ingredient("cheesecake_filling", "Cheesecake Filling", IngredientDefinition.Category.BAKING, 0, Color(0.96, 0.92, 0.75))
	_add_ingredient("packaging", "Packaging", IngredientDefinition.Category.SUPPLIES, 3, Color(0.7, 0.78, 0.85))
	_add_ingredient("butter", "Butter", IngredientDefinition.Category.BAKING, 2, Color(0.98, 0.86, 0.45))
	_add_ingredient("vanilla", "Vanilla", IngredientDefinition.Category.FLAVORING, 1, Color(0.92, 0.84, 0.62))


# ---------------------------------------------------------------------------
# Equipment (bridges into legacy EquipmentData; levels mirror linked upgrades)
# ---------------------------------------------------------------------------

func _add_equipment(id: String, name: String, type: EquipmentDefinition.EquipmentType, upgrade_id: String,
		stages: Array, benefit: String, color: Color, max_level: int) -> void:
	var def := EquipmentDefinition.new()
	def.id = id
	def.display_name = name
	def.equipment_type = type
	def.linked_upgrade_id = upgrade_id
	def.stage_labels = PackedStringArray(stages)
	def.benefit_description = benefit
	def.fallback_color = color
	def.max_level = max_level
	equipment[id] = def
	equipment_sequence.append(id)


func _seed_equipment() -> void:
	equipment.clear()
	equipment_sequence.clear()
	_add_equipment("oven", "Basic Oven", EquipmentDefinition.EquipmentType.OVEN, "oven",
		["Small basic oven", "Cleaner modern oven", "Double oven"],
		"Order coin rewards +2% per level above 1", Color(0.62, 0.42, 0.34), 3)
	_add_equipment("mixer", "Basic Mixer", EquipmentDefinition.EquipmentType.MIXER, "mixer",
		["Countertop mixer", "Upgraded mixer", "Pro stand mixer"],
		"Order XP rewards +2% per level above 1", Color(0.85, 0.68, 0.5), 3)
	_add_equipment("display_case", "Small Display Case", EquipmentDefinition.EquipmentType.DISPLAY_CASE, "display_case",
		["Small case", "Wider case", "Lit display"],
		"Reputation rewards +2% per level above 1", Color(0.72, 0.86, 0.9), 3)
	_add_equipment("checkout", "Cash Register", EquipmentDefinition.EquipmentType.CHECKOUT, "cash_register",
		["Basic register", "Organized counter", "Modern POS"],
		"All order rewards +1% per level above 1", Color(0.78, 0.62, 0.48), 3)


# ---------------------------------------------------------------------------
# Upgrades (6): Oven, Mixer, Display Case, Cash Register, Decor, Lighting
# ---------------------------------------------------------------------------

func _add_upgrade(id: String, name: String, effect: UpgradeDefinition.EffectType, cost: int, per: float,
		linked_equipment: String, desc: String, color: Color, max_level: int) -> void:
	var def := UpgradeDefinition.new()
	def.id = id
	def.display_name = name
	def.effect_type = effect
	def.base_cost = cost
	def.cost_growth = 2.0 if max_level <= 3 else 1.6
	def.effect_per_level = per
	def.linked_equipment_id = linked_equipment
	def.description = desc
	def.fallback_color = color
	def.max_level = max_level
	def.starting_level = 1
	upgrades[id] = def
	upgrade_sequence.append(id)


func _seed_upgrades() -> void:
	upgrades.clear()
	upgrade_sequence.clear()
	# Oven / Mixer / Display Case / Cash Register mirror legacy equipment (max level 3,
	# base cost 500, growth 2.0 => 500/1000 exactly matching the original phase-cap costs).
	_add_upgrade("oven", "Oven", UpgradeDefinition.EffectType.BAKING_SPEED, 500, 0.02, "oven",
		"Faster baking and stronger coin payouts from warm ovens.", Color(0.62, 0.42, 0.34), 3)
	_add_upgrade("mixer", "Mixer", UpgradeDefinition.EffectType.BATCH_SIZE, 500, 0.02, "mixer",
		"Bigger batches: more XP earned per completed order.", Color(0.85, 0.68, 0.5), 3)
	_add_upgrade("display_case", "Display Case", UpgradeDefinition.EffectType.COIN_REWARDS, 500, 0.02, "display_case",
		"A prettier case wins more reputation from every customer.", Color(0.72, 0.86, 0.9), 3)
	_add_upgrade("cash_register", "Cash Register", UpgradeDefinition.EffectType.TRANSACTION_SPEED, 600, 0.01, "checkout",
		"Faster checkouts boost every order reward slightly.", Color(0.78, 0.62, 0.48), 3)
	# Decor / Lighting are new standalone upgrades (no legacy equipment link, max level 5).
	_add_upgrade("decor", "Decor", UpgradeDefinition.EffectType.TIP_BONUS, 700, 0.03, "",
		"Cozier décor earns bigger tips (bonus coins) on every order.", Color(0.86, 0.7, 0.78), 5)
	_add_upgrade("lighting", "Lighting", UpgradeDefinition.EffectType.STAR_REWARD_BONUS, 750, 0.04, "",
		"Better lighting raises your odds of an extra bonus star.", Color(0.96, 0.86, 0.45), 5)


# ---------------------------------------------------------------------------
# Recipes (8)
# ---------------------------------------------------------------------------

func _add_recipe(id: String, name: String, desc: String, cat: RecipeDefinition.Category,
		diff: RecipeDefinition.Difficulty, unlocked: bool, level: int, stars: int, unlock_cost: int,
		value: int, order_reqs: Dictionary, color: Color, craft_coins: int) -> void:
	var def := RecipeDefinition.new()
	def.id = id
	def.display_name = name
	def.description = desc
	def.category = cat
	def.difficulty = diff
	def.unlocked_by_default = unlocked
	def.required_player_level = level
	def.required_stars = stars
	def.unlock_coin_cost = unlock_cost
	def.base_selling_value = value
	def.order_ingredient_requirements = order_reqs
	def.fallback_color = color
	# Crafting reuses (a subset of) the order ingredient requirements for consistency.
	def.craft_ingredient_costs = order_reqs.duplicate(true)
	def.craft_coin_reward = craft_coins
	def.craft_xp_reward = maxi(5, craft_coins / 6)
	def.craft_reputation_reward = maxi(1, craft_coins / 20)
	recipes[id] = def
	recipe_sequence.append(id)


func _seed_recipes() -> void:
	recipes.clear()
	recipe_sequence.clear()
	_add_recipe("chocolate_strawberries", "Chocolate Strawberries",
		"Ripe strawberries dipped in glossy chocolate.",
		RecipeDefinition.Category.FRUIT_TREATS, RecipeDefinition.Difficulty.EASY,
		true, 1, 0, 0, 120, {"chocolate": 2, "strawberries": 3}, Color(0.75, 0.25, 0.35), 40)
	_add_recipe("classic_cupcakes", "Classic Cupcakes",
		"Soft vanilla cupcakes with swirled frosting.",
		RecipeDefinition.Category.CUPCAKES, RecipeDefinition.Difficulty.EASY,
		true, 1, 0, 0, 140, {"flour": 2, "sugar": 2, "cream": 1}, Color(1.0, 0.7, 0.8), 45)
	_add_recipe("candied_grapes", "Candied Grapes",
		"Sparkling sugar-crusted grapes.",
		RecipeDefinition.Category.FRUIT_TREATS, RecipeDefinition.Difficulty.MEDIUM,
		false, 2, 3, 300, 180, {"grapes": 3, "sugar": 2}, Color(0.55, 0.3, 0.7), 60)
	_add_recipe("cookies_cream_cupcakes", "Cookies and Cream Cupcakes",
		"Cupcakes folded with crushed cookies and cream.",
		RecipeDefinition.Category.CUPCAKES, RecipeDefinition.Difficulty.MEDIUM,
		false, 3, 6, 500, 220, {"flour": 2, "cookies": 2, "cream": 2}, Color(0.85, 0.85, 0.9), 75)
	_add_recipe("chocolate_cupcakes", "Chocolate Cupcakes",
		"Rich chocolate cupcakes with soft frosting.",
		RecipeDefinition.Category.CUPCAKES, RecipeDefinition.Difficulty.EASY,
		false, 2, 2, 200, 150, {"flour": 2, "chocolate": 2, "cream": 1}, Color(0.45, 0.28, 0.2), 50)
	_add_recipe("caramel_donuts", "Caramel Donuts",
		"Warm donuts glazed with rich caramel.",
		RecipeDefinition.Category.DONUTS, RecipeDefinition.Difficulty.HARD,
		false, 4, 10, 750, 280, {"flour": 2, "caramel": 2, "sugar": 1}, Color(0.85, 0.55, 0.25), 95)
	_add_recipe("cheesecake_cups", "Cheesecake Cups",
		"Mini cups of silky cheesecake.",
		RecipeDefinition.Category.CHEESECAKES, RecipeDefinition.Difficulty.HARD,
		false, 5, 15, 1000, 320, {"cheesecake_filling": 2, "cream": 1, "packaging": 1}, Color(0.95, 0.9, 0.7), 110)
	_add_recipe("butter_cookies", "Butter Cookies",
		"Crumbly, golden cookies baked with real butter and vanilla.",
		RecipeDefinition.Category.COOKIES, RecipeDefinition.Difficulty.EASY,
		false, 2, 1, 150, 130, {"butter": 1, "flour": 2, "vanilla": 1}, Color(0.9, 0.75, 0.4), 45)


# ---------------------------------------------------------------------------
# Workers (6): Lily, Marco, Sophie, Ethan, Mia, Noah
# ---------------------------------------------------------------------------

func _add_worker(id: String, name: String, role: WorkerDefinition.Role, rarity: WorkerDefinition.Rarity,
		desc: String, level_req: int, rep_req: int, hire_cost: int, station: WorkerDefinition.Station,
		available: bool, primary_type: String, primary_per: float, primary_base: float,
		secondary_type: String, secondary_per: float, portrait: Color, body: Color) -> void:
	var def := WorkerDefinition.new()
	def.id = id
	def.display_name = name
	def.role = role
	def.rarity = rarity
	def.description = desc
	def.unlock_player_level = level_req
	def.unlock_reputation = rep_req
	def.hire_cost = hire_cost
	def.compatible_station = station
	def.available_at_start = available
	def.primary_bonus_type = primary_type
	def.primary_bonus_per_level = primary_per
	def.primary_bonus_base = primary_base
	def.secondary_bonus_type = secondary_type
	def.secondary_bonus_per_level = secondary_per
	def.portrait_color = portrait
	def.body_color = body
	workers[id] = def
	worker_sequence.append(id)


func _seed_workers() -> void:
	workers.clear()
	worker_sequence.clear()
	_add_worker("lily", "Lily", WorkerDefinition.Role.BAKER, WorkerDefinition.Rarity.COMMON,
		"A cheerful baker who keeps the ovens humming — faster bakes mean faster learning.",
		1, 0, 300, WorkerDefinition.Station.OVEN, true,
		"order_xp", 0.03, 0.0, "", 0.0,
		Color(0.95, 0.65, 0.7), Color(0.9, 0.45, 0.55))
	_add_worker("marco", "Marco", WorkerDefinition.Role.CASHIER, WorkerDefinition.Rarity.COMMON,
		"A quick-fingered cashier who rings up more coins per order.",
		2, 0, 450, WorkerDefinition.Station.CHECKOUT, false,
		"order_coins", 0.03, 0.0, "", 0.0,
		Color(0.55, 0.7, 0.95), Color(0.35, 0.5, 0.85))
	_add_worker("mia", "Mia", WorkerDefinition.Role.MIXER_SPECIALIST, WorkerDefinition.Rarity.UNCOMMON,
		"A warm mixer specialist whose desserts earn better tips from customers.",
		3, 0, 750, WorkerDefinition.Station.MIXER, false,
		"order_coins", 0.02, 0.0, "", 0.0,
		Color(0.7, 0.9, 0.75), Color(0.4, 0.75, 0.55))
	_add_worker("sophie", "Sophie", WorkerDefinition.Role.DISPLAY_DECORATOR, WorkerDefinition.Rarity.UNCOMMON,
		"A display decorator whose eye for style wins the shop more reputation.",
		4, 0, 1000, WorkerDefinition.Station.DISPLAY_CASE, false,
		"order_reputation", 0.03, 0.0, "", 0.0,
		Color(0.95, 0.8, 0.5), Color(0.85, 0.6, 0.3))
	_add_worker("ethan", "Ethan", WorkerDefinition.Role.ORDER_COORDINATOR, WorkerDefinition.Rarity.RARE,
		"An order coordinator who restocks the pantry faster, snagging bonus ingredients.",
		5, 0, 1500, WorkerDefinition.Station.ORDER_DESK, false,
		"bonus_ingredients", 0.02, 0.05, "", 0.0,
		Color(0.8, 0.65, 0.95), Color(0.6, 0.4, 0.85))
	_add_worker("noah", "Noah", WorkerDefinition.Role.STORE_MANAGER, WorkerDefinition.Rarity.PREMIUM,
		"A seasoned store manager whose lucky streak gives every order a chance at a bonus star.",
		8, 150, 4000, WorkerDefinition.Station.MANAGER, false,
		"bonus_star_chance", 0.015, 0.0, "all_order_rewards", 0.01,
		Color(0.45, 0.35, 0.4), Color(0.3, 0.22, 0.28))


# ---------------------------------------------------------------------------
# Customers (6)
# ---------------------------------------------------------------------------

func _add_customer(id: String, name: String, greeting: String, color: Color, favorites: Array[String]) -> void:
	var def := CustomerDefinition.new()
	def.id = id
	def.display_name = name
	def.greeting = greeting
	def.fallback_color = color
	def.favorite_recipe_ids = PackedStringArray(favorites)
	customers[id] = def
	customer_sequence.append(id)


func _seed_customers() -> void:
	customers.clear()
	customer_sequence.clear()
	_add_customer("mia_customer", "Mia", "I need something sweet and fruity!", Color(0.95, 0.55, 0.7), ["chocolate_strawberries"])
	_add_customer("jordan", "Jordan", "Cupcakes always make the day better.", Color(0.55, 0.75, 0.95), ["classic_cupcakes"])
	_add_customer("taylor", "Taylor", "Make it extra chocolatey.", Color(0.55, 0.4, 0.3), ["chocolate_strawberries", "chocolate_cupcakes"])
	_add_customer("noah_customer", "Noah", "I need desserts for a small celebration.", Color(0.55, 0.65, 0.9), ["classic_cupcakes"])
	_add_customer("morgan", "Morgan", "I heard your candied fruit is incredible.", Color(0.65, 0.45, 0.85), ["candied_grapes"])
	_add_customer("elena", "Elena", "Something buttery and homemade, please.", Color(0.85, 0.7, 0.4), ["butter_cookies"])


# ---------------------------------------------------------------------------
# Rewards
# ---------------------------------------------------------------------------

func _add_reward(id: String, coins: int, xp: int, rep: int, ings: Dictionary) -> void:
	var def := RewardDefinition.new()
	def.id = id
	def.coins = coins
	def.experience = xp
	def.reputation = rep
	def.ingredients = ings
	rewards[id] = def


func _seed_rewards() -> void:
	rewards.clear()
	_add_reward("reward_mia", 150, 25, 5, {"strawberries": 2, "chocolate": 2})
	_add_reward("reward_jordan", 200, 35, 7, {"flour": 2, "sugar": 2})
	_add_reward("reward_taylor", 275, 45, 10, {"chocolate": 3, "packaging": 1})
	_add_reward("reward_noah", 325, 55, 12, {"flour": 3, "cream": 2})
	_add_reward("reward_morgan", 450, 75, 18, {"grapes": 2, "sugar": 2})
	_add_reward("reward_elena", 260, 40, 9, {"butter": 2, "vanilla": 1})


# ---------------------------------------------------------------------------
# Puzzle levels
# ---------------------------------------------------------------------------

func _add_level(id: String, name: String, moves: int, objectives: Array[Dictionary]) -> void:
	var def := PuzzleLevelDefinition.new()
	def.id = id
	def.display_name = name
	def.columns = 8
	def.rows = 8
	def.move_limit = moves
	def.min_valid_moves = 1
	def.objectives = objectives
	levels[id] = def


func _seed_levels() -> void:
	levels.clear()
	_add_level("level_01", "Strawberry Rush", 20, [{"piece_id": "strawberry", "amount": 20, "description": "Collect 20 strawberries"}])
	_add_level("level_02", "Cupcake Crowds", 22, [{"piece_id": "cupcake", "amount": 22, "description": "Collect 22 cupcakes"}])
	_add_level("level_03", "Chocolate Crowds", 20, [{"piece_id": "chocolate", "amount": 25, "description": "Collect 25 chocolate pieces"}])
	_add_level("level_04", "Celebration Batch", 24, [
		{"piece_id": "cupcake", "amount": 18, "description": "Collect 18 cupcakes"},
		{"piece_id": "candy", "amount": 12, "description": "Collect 12 candy pieces"},
	])
	_add_level("level_05", "Candy Crush Hour", 18, [{"piece_id": "candy", "amount": 35, "description": "Collect 35 candy pieces"}])
	_add_level("level_06", "Butter Batch", 20, [{"piece_id": "cookie", "amount": 24, "description": "Collect 24 cookies"}])


# ---------------------------------------------------------------------------
# Orders
# ---------------------------------------------------------------------------

func _add_order(id: String, customer_id: String, recipe_id: String, level_id: String, reward_id: String,
		diff: OrderDefinition.Difficulty, target_piece: String = "", target_amt: int = 0, moves: int = 0,
		objective_desc: String = "", extra: Array[Dictionary] = []) -> void:
	var def := OrderDefinition.new()
	def.id = id
	def.customer_id = customer_id
	def.recipe_id = recipe_id
	def.level_id = level_id
	def.reward_id = reward_id
	def.difficulty = diff
	def.requires_recipe_unlocked = true
	def.target_piece_id = target_piece
	def.target_amount = target_amt
	def.move_limit = moves
	def.objective_description = objective_desc
	def.additional_objectives = extra
	orders[id] = def
	order_sequence.append(id)


func _seed_orders() -> void:
	orders.clear()
	order_sequence.clear()
	_add_order("order_mia_001", "mia_customer", "chocolate_strawberries", "level_01", "reward_mia",
		OrderDefinition.Difficulty.EASY, "strawberry", 20, 20, "Collect 20 strawberries")
	_add_order("order_jordan_002", "jordan", "classic_cupcakes", "level_02", "reward_jordan",
		OrderDefinition.Difficulty.EASY, "cupcake", 22, 22, "Collect 22 cupcakes")
	_add_order("order_taylor_003", "taylor", "chocolate_strawberries", "level_03", "reward_taylor",
		OrderDefinition.Difficulty.MEDIUM, "chocolate", 25, 20, "Collect 25 chocolate pieces")
	_add_order("order_noah_004", "noah_customer", "classic_cupcakes", "level_04", "reward_noah",
		OrderDefinition.Difficulty.MEDIUM, "cupcake", 18, 24, "Collect 18 cupcakes + 12 candy",
		[{"piece_id": "candy", "amount": 12}])
	_add_order("order_morgan_005", "morgan", "candied_grapes", "level_05", "reward_morgan",
		OrderDefinition.Difficulty.HARD, "candy", 35, 18, "Collect 35 candy pieces")
	_add_order("order_elena_006", "elena", "butter_cookies", "level_06", "reward_elena",
		OrderDefinition.Difficulty.EASY, "cookie", 24, 20, "Collect 24 cookies")


# ---------------------------------------------------------------------------
# Bridging + validation
# ---------------------------------------------------------------------------

func _validate_all() -> void:
	var collections := [ingredients, recipes, upgrades, workers, customers, orders, rewards, levels, equipment]
	for collection in collections:
		for key in collection.keys():
			var def = collection[key]
			if def and def.has_method("validate"):
				for err in def.validate():
					push_warning(str(err))


## Populates the legacy ContentCatalog with Data resources bridged from these
## definitions. Keeps the existing match-3 board / orders / UI code untouched.
func apply_to_catalog(catalog: ContentCatalog) -> void:
	catalog.ingredients.clear()
	for id in ingredient_sequence:
		catalog.ingredients[id] = get_ingredient(id).to_ingredient_data()

	catalog.equipment.clear()
	for id in equipment_sequence:
		catalog.equipment[id] = get_equipment(id).to_equipment_data()

	catalog.recipes.clear()
	for id in recipe_sequence:
		catalog.recipes[id] = get_recipe(id).to_recipe_data()

	var piece_types := _load_piece_types()
	catalog.levels.clear()
	for id in levels.keys():
		var lvl_def: PuzzleLevelDefinition = levels[id]
		catalog.levels[id] = lvl_def.to_level_config(piece_types)

	catalog.orders.clear()
	catalog.order_sequence.clear()
	for id in order_sequence:
		var order_def := get_order(id)
		var customer := get_customer(order_def.customer_id)
		var reward := get_reward(order_def.reward_id)
		var template := order_def.to_order_template(customer, reward)
		catalog.orders[id] = template
		catalog.order_sequence.append(StringName(id))

	catalog.workers.clear()
	catalog.worker_sequence.clear()
	for id in worker_sequence:
		catalog.workers[id] = get_worker(id).to_worker_data()
		catalog.worker_sequence.append(StringName(id))


func _load_piece_types() -> Array[PieceType]:
	var ids := ["chocolate", "strawberry", "cupcake", "donut", "cookie", "candy"]
	var arr: Array[PieceType] = []
	for id in ids:
		var path := "res://resources/pieces/%s.tres" % id
		if ResourceLoader.exists(path):
			arr.append(load(path) as PieceType)
	return arr
