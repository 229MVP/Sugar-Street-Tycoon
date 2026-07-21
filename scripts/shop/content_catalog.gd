class_name ContentCatalog
extends RefCounted
## Builds and caches game content. Uses code-defined defaults so the prototype
## does not depend on dozens of hand-authored .tres files, while still allowing
## .tres overrides to be loaded when present.


var recipes: Dictionary = {} # recipe_id -> RecipeData
var orders: Dictionary = {} # order_id -> OrderTemplate
var equipment: Dictionary = {} # equipment_id -> EquipmentData
var ingredients: Dictionary = {} # ingredient_id -> IngredientData
var levels: Dictionary = {} # level_id -> LevelConfig
var workers: Dictionary = {} # worker_id -> WorkerData
var worker_sequence: Array[StringName] = []
var order_sequence: Array[StringName] = []


func build() -> void:
	_build_ingredients()
	_build_equipment()
	_build_recipes()
	_build_levels()
	_build_orders()
	_build_workers()


func get_recipe(id: StringName) -> RecipeData:
	return recipes.get(str(id), recipes.get(id)) as RecipeData


func get_order(id: StringName) -> OrderTemplate:
	return orders.get(str(id), orders.get(id)) as OrderTemplate


func get_equipment(id: StringName) -> EquipmentData:
	return equipment.get(str(id), equipment.get(id)) as EquipmentData


func get_ingredient(id: StringName) -> IngredientData:
	return ingredients.get(str(id), ingredients.get(id)) as IngredientData


func get_worker(id: StringName) -> WorkerData:
	return workers.get(str(id), workers.get(id)) as WorkerData


func get_level(level_id: String) -> LevelConfig:
	if levels.has(level_id):
		return levels[level_id] as LevelConfig
	var path := "res://resources/levels/%s.tres" % level_id
	if ResourceLoader.exists(path):
		return load(path) as LevelConfig
	return null


func _build_ingredients() -> void:
	var defs := [
		[&"chocolate", "Chocolate", Color(0.36, 0.23, 0.13), 10],
		[&"strawberries", "Strawberries", Color(0.86, 0.27, 0.35), 10],
		[&"flour", "Flour", Color(0.93, 0.9, 0.82), 10],
		[&"sugar", "Sugar", Color(0.95, 0.95, 0.95), 10],
		[&"cream", "Cream", Color(0.98, 0.94, 0.88), 5],
		[&"grapes", "Grapes", Color(0.55, 0.3, 0.65), 0],
		[&"caramel", "Caramel", Color(0.78, 0.5, 0.2), 0],
		[&"cookies", "Cookies", Color(0.72, 0.5, 0.28), 0],
		[&"cheesecake_filling", "Cheesecake Filling", Color(0.96, 0.92, 0.75), 0],
		[&"packaging", "Packaging", Color(0.7, 0.78, 0.85), 5],
	]
	for d in defs:
		var item := IngredientData.new()
		item.ingredient_id = d[0]
		item.display_name = d[1]
		item.color = d[2]
		item.starting_amount = d[3]
		ingredients[str(item.ingredient_id)] = item


func _build_equipment() -> void:
	_add_equipment(&"oven", "Basic Oven", EquipmentData.EquipmentType.OVEN,
		["Small basic oven", "Cleaner modern oven", "Double oven", "Professional bakery oven", "Luxury commercial oven"],
		"Order coin rewards +2% per level above 1")
	_add_equipment(&"mixer", "Basic Mixer", EquipmentData.EquipmentType.MIXER,
		["Countertop mixer", "Upgraded mixer", "Pro stand mixer", "Industrial mixer", "Luxury mixer suite"],
		"Experience rewards +2% per level above 1")
	_add_equipment(&"display_case", "Small Display Case", EquipmentData.EquipmentType.DISPLAY_CASE,
		["Small case", "Wider case", "Lit display", "Premium display", "Luxury showcase"],
		"Reputation rewards +2% per level above 1")
	_add_equipment(&"checkout", "Basic Checkout Counter", EquipmentData.EquipmentType.CHECKOUT,
		["Basic counter", "Organized counter", "Modern POS counter", "Premium counter", "Flagship checkout"],
		"All order rewards +1% per level above 1")


func _add_equipment(id: StringName, name: String, type: EquipmentData.EquipmentType, stages: Array, benefit: String) -> void:
	var eq := EquipmentData.new()
	eq.equipment_id = id
	eq.display_name = name
	eq.equipment_type = type
	eq.max_level = 5
	eq.starting_level = 1
	eq.stage_labels.assign(stages)
	eq.benefit_description = benefit
	equipment[str(id)] = eq


func _build_recipes() -> void:
	_add_recipe(&"chocolate_strawberries", "Chocolate Strawberries",
		"Ripe strawberries dipped in glossy chocolate.",
		RecipeData.Category.FRUIT_TREATS, RecipeData.Rarity.COMMON, true,
		1, 0, 0, 120, {&"chocolate": 2, &"strawberries": 3}, Color(0.75, 0.25, 0.35))
	_add_recipe(&"classic_cupcakes", "Classic Cupcakes",
		"Soft vanilla cupcakes with swirled frosting.",
		RecipeData.Category.CUPCAKES, RecipeData.Rarity.COMMON, true,
		1, 0, 0, 140, {&"flour": 2, &"sugar": 2, &"cream": 1}, Color(1.0, 0.7, 0.8))
	_add_recipe(&"candied_grapes", "Candied Grapes",
		"Sparkling sugar-crusted grapes.",
		RecipeData.Category.FRUIT_TREATS, RecipeData.Rarity.UNCOMMON, false,
		2, 3, 300, 180, {&"grapes": 3, &"sugar": 2}, Color(0.55, 0.3, 0.7))
	_add_recipe(&"cookies_cream_cupcakes", "Cookies and Cream Cupcakes",
		"Cupcakes folded with crushed cookies and cream.",
		RecipeData.Category.CUPCAKES, RecipeData.Rarity.UNCOMMON, false,
		3, 6, 500, 220, {&"flour": 2, &"cookies": 2, &"cream": 2}, Color(0.85, 0.85, 0.9))
	_add_recipe(&"caramel_donuts", "Caramel Donuts",
		"Warm donuts glazed with rich caramel.",
		RecipeData.Category.DONUTS, RecipeData.Rarity.RARE, false,
		4, 10, 750, 280, {&"flour": 2, &"caramel": 2, &"sugar": 1}, Color(0.85, 0.55, 0.25))
	_add_recipe(&"cheesecake_cups", "Cheesecake Cups",
		"Mini cups of silky cheesecake.",
		RecipeData.Category.CHEESECAKES, RecipeData.Rarity.RARE, false,
		5, 15, 1000, 320, {&"cheesecake_filling": 2, &"cream": 1, &"packaging": 1}, Color(0.95, 0.9, 0.7))
	_add_recipe(&"deluxe_dessert_box", "Deluxe Dessert Box",
		"A curated box of signature Sugar Street treats.",
		RecipeData.Category.DESSERT_BOXES, RecipeData.Rarity.PREMIUM, false,
		7, 25, 2000, 500, {&"packaging": 2, &"chocolate": 2, &"cream": 2, &"strawberries": 2}, Color(0.7, 0.45, 0.55))


func _add_recipe(id: StringName, name: String, desc: String, cat: RecipeData.Category, rarity: RecipeData.Rarity,
		unlocked: bool, level: int, stars: int, cost: int, value: int, ingredients_req: Dictionary, color: Color) -> void:
	var recipe := RecipeData.new()
	recipe.recipe_id = id
	recipe.display_name = name
	recipe.description = desc
	recipe.category = cat
	recipe.rarity = rarity
	recipe.unlocked_by_default = unlocked
	recipe.required_player_level = level
	recipe.required_stars = stars
	recipe.unlock_coin_cost = cost
	recipe.base_selling_value = value
	recipe.ingredient_requirements = ingredients_req
	recipe.fallback_color = color
	recipes[str(id)] = recipe


func _build_levels() -> void:
	var piece_types := _load_piece_types()
	# Code fallbacks, then prefer .tres files when valid.
	levels["level_01"] = _make_level("level_01", "Strawberry Rush", 20, piece_types, [
		_obj(&"strawberry", 20, "Collect 20 strawberries")
	])
	levels["level_02"] = _make_level("level_02", "Cupcake Crowds", 22, piece_types, [
		_obj(&"cupcake", 20, "Collect 20 cupcakes")
	])
	levels["level_03"] = _make_level("level_03", "Berry Batch", 20, piece_types, [
		_obj(&"strawberry", 25, "Collect 25 strawberries")
	])
	levels["level_04"] = _make_level("level_04", "Cookie & Berry", 24, piece_types, [
		_obj(&"cookie", 20, "Collect 20 cookies"),
		_obj(&"strawberry", 15, "Collect 15 strawberries"),
	])
	levels["level_05"] = _make_level("level_05", "Candy Crush Hour", 18, piece_types, [
		_obj(&"candy", 40, "Collect 40 candy pieces")
	])
	for level_id in ["level_01", "level_02", "level_03", "level_04", "level_05"]:
		var path := "res://resources/levels/%s.tres" % level_id
		if ResourceLoader.exists(path):
			var file_level := load(path) as LevelConfig
			if file_level and file_level.validate():
				levels[level_id] = file_level


func _load_piece_types() -> Array[PieceType]:
	var ids := ["chocolate", "strawberry", "cupcake", "donut", "cookie", "candy"]
	var arr: Array[PieceType] = []
	for id in ids:
		var path := "res://resources/pieces/%s.tres" % id
		if ResourceLoader.exists(path):
			arr.append(load(path) as PieceType)
	return arr


func _obj(piece_id: StringName, amount: int, desc: String) -> ObjectiveData:
	var obj := ObjectiveData.new()
	obj.piece_id = piece_id
	obj.target_amount = amount
	obj.description = desc
	return obj


func _make_level(id: String, name: String, moves: int, pieces: Array[PieceType], objectives: Array) -> LevelConfig:
	var level := LevelConfig.new()
	level.level_id = id
	level.level_name = name
	level.columns = 8
	level.rows = 8
	level.move_limit = moves
	level.piece_types = pieces
	var objs: Array[ObjectiveData] = []
	for o in objectives:
		objs.append(o)
	level.objectives = objs
	level.min_valid_moves = 1
	return level


func _build_orders() -> void:
	_add_order(&"order_mia", "Mia", &"chocolate_strawberries", "level_01",
		150, 25, 5, OrderTemplate.Difficulty.EASY,
		{&"chocolate": 2, &"strawberries": 2}, Color(0.95, 0.55, 0.65),
		&"strawberry", 20, 20, "Collect 20 strawberries")
	_add_order(&"order_jordan", "Jordan", &"classic_cupcakes", "level_02",
		200, 35, 7, OrderTemplate.Difficulty.EASY,
		{&"flour": 2, &"sugar": 2, &"cream": 1}, Color(0.55, 0.7, 0.95),
		&"cupcake", 20, 22, "Collect 20 cupcakes")
	_add_order(&"order_taylor", "Taylor", &"chocolate_strawberries", "level_03",
		275, 45, 10, OrderTemplate.Difficulty.MEDIUM,
		{&"chocolate": 3, &"strawberries": 2}, Color(0.7, 0.85, 0.55),
		&"strawberry", 25, 20, "Collect 25 strawberries")
	_add_order(&"order_chris", "Chris", &"classic_cupcakes", "level_04",
		325, 55, 12, OrderTemplate.Difficulty.MEDIUM,
		{&"flour": 2, &"cookies": 1, &"cream": 1}, Color(0.95, 0.75, 0.45),
		&"cookie", 20, 24, "Collect 20 cookies")
	_add_order(&"order_morgan", "Morgan", &"candied_grapes", "level_05",
		450, 75, 18, OrderTemplate.Difficulty.HARD,
		{&"grapes": 3, &"sugar": 2}, Color(0.65, 0.45, 0.85),
		&"candy", 40, 18, "Collect 40 candy pieces")
	# Extra filler orders so the board can rotate after completions.
	_add_order(&"order_avery", "Avery", &"chocolate_strawberries", "level_01",
		160, 28, 6, OrderTemplate.Difficulty.EASY,
		{&"chocolate": 1, &"strawberries": 2}, Color(0.9, 0.6, 0.5),
		&"strawberry", 20, 20, "Collect 20 strawberries")
	_add_order(&"order_riley", "Riley", &"classic_cupcakes", "level_02",
		210, 38, 8, OrderTemplate.Difficulty.EASY,
		{&"flour": 2, &"sugar": 1}, Color(0.5, 0.8, 0.75),
		&"cupcake", 20, 22, "Collect 20 cupcakes")
	_add_order(&"order_sam", "Sam", &"cookies_cream_cupcakes", "level_04",
		360, 60, 14, OrderTemplate.Difficulty.MEDIUM,
		{&"cookies": 2, &"cream": 1}, Color(0.8, 0.8, 0.9),
		&"cookie", 20, 24, "Collect 20 cookies")
	_add_order(&"order_casey", "Casey", &"caramel_donuts", "level_05",
		480, 80, 20, OrderTemplate.Difficulty.HARD,
		{&"caramel": 2, &"flour": 1}, Color(0.85, 0.55, 0.35),
		&"candy", 40, 18, "Collect 40 candy pieces")
	order_sequence = [
		&"order_mia", &"order_jordan", &"order_taylor", &"order_chris", &"order_morgan",
		&"order_avery", &"order_riley", &"order_sam", &"order_casey",
	]


func _add_order(id: StringName, customer: String, recipe_id: StringName, level_id: String,
		coins: int, xp: int, rep: int, diff: OrderTemplate.Difficulty,
		ingredients_reward: Dictionary, color: Color,
		target_piece: StringName = &"", target_amt: int = 0, moves: int = 0,
		objective_desc: String = "") -> void:
	var order := OrderTemplate.new()
	order.order_id = id
	order.customer_name = customer
	order.recipe_id = recipe_id
	order.level_id = level_id
	order.coin_reward = coins
	order.experience_reward = xp
	order.reputation_reward = rep
	order.difficulty = diff
	order.ingredient_rewards = ingredients_reward
	order.customer_color = color
	order.requires_recipe_unlocked = true
	order.target_piece_id = target_piece
	order.target_amount = target_amt
	order.move_limit = moves
	order.objective_description = objective_desc
	orders[str(id)] = order


func _build_workers() -> void:
	_add_worker(&"ava", "Ava", WorkerData.Role.BAKER, WorkerData.Rarity.COMMON,
		"A cheerful baker who keeps the ovens humming.",
		1, 0, 300, WorkerData.Station.OVEN, true,
		&"order_coins", 0.03, 0.0, &"", 0.0,
		Color(0.95, 0.65, 0.7), Color(0.9, 0.45, 0.55))
	_add_worker(&"marcus", "Marcus", WorkerData.Role.CASHIER, WorkerData.Rarity.COMMON,
		"Friendly cashier who turns smiles into reputation.",
		2, 0, 450, WorkerData.Station.CHECKOUT, false,
		&"order_reputation", 0.02, 0.0, &"", 0.0,
		Color(0.55, 0.7, 0.95), Color(0.35, 0.5, 0.85))
	_add_worker(&"lily", "Lily", WorkerData.Role.MIXER_SPECIALIST, WorkerData.Rarity.UNCOMMON,
		"Mixer specialist who helps the team learn faster.",
		3, 0, 750, WorkerData.Station.MIXER, false,
		&"order_xp", 0.03, 0.0, &"", 0.0,
		Color(0.7, 0.9, 0.75), Color(0.4, 0.75, 0.55))
	_add_worker(&"noah", "Noah", WorkerData.Role.DISPLAY_DECORATOR, WorkerData.Rarity.UNCOMMON,
		"Display decorator who attracts walk-in shoppers.",
		4, 0, 1000, WorkerData.Station.DISPLAY_CASE, false,
		&"passive_income", 0.05, 0.0, &"", 0.0,
		Color(0.95, 0.8, 0.5), Color(0.85, 0.6, 0.3))
	_add_worker(&"sofia", "Sofia", WorkerData.Role.ORDER_COORDINATOR, WorkerData.Rarity.RARE,
		"Order coordinator who snags bonus ingredients.",
		5, 0, 1500, WorkerData.Station.ORDER_DESK, false,
		&"bonus_ingredients", 0.02, 0.05, &"", 0.0,
		Color(0.8, 0.65, 0.95), Color(0.6, 0.4, 0.85))
	_add_worker(&"chef_andre", "Chef Andre", WorkerData.Role.STORE_MANAGER, WorkerData.Rarity.PREMIUM,
		"Store manager who boosts every reward and walk-in sales.",
		8, 150, 4000, WorkerData.Station.MANAGER, false,
		&"all_order_rewards", 0.02, 0.0, &"passive_income", 0.03,
		Color(0.45, 0.35, 0.4), Color(0.3, 0.22, 0.28))
	worker_sequence = [&"ava", &"marcus", &"lily", &"noah", &"sofia", &"chef_andre"]


func _add_worker(id: StringName, name: String, role: WorkerData.Role, rarity: WorkerData.Rarity,
		desc: String, level_req: int, rep_req: int, hire_cost: int, station: WorkerData.Station,
		available: bool, primary_type: StringName, primary_per: float, primary_base: float,
		secondary_type: StringName, secondary_per: float, portrait: Color, body: Color) -> void:
	var worker := WorkerData.new()
	worker.worker_id = id
	worker.display_name = name
	worker.role = role
	worker.rarity = rarity
	worker.description = desc
	worker.unlock_player_level = level_req
	worker.unlock_reputation = rep_req
	worker.hire_cost = hire_cost
	worker.compatible_station = station
	worker.available_at_start = available
	worker.primary_bonus_type = primary_type
	worker.primary_bonus_per_level = primary_per
	worker.primary_bonus_base = primary_base
	worker.secondary_bonus_type = secondary_type
	worker.secondary_bonus_per_level = secondary_per
	worker.portrait_color = portrait
	worker.body_color = body
	workers[str(id)] = worker
