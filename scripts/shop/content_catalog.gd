class_name ContentCatalog
extends RefCounted
## Builds and caches game content. Content is seeded from DefinitionDatabase
## (typed Resource definitions) and bridged into these legacy Data types so
## the existing match-3 board, orders flow, and UI keep working unmodified.


var recipes: Dictionary = {} # recipe_id -> RecipeData
var orders: Dictionary = {} # order_id -> OrderTemplate
var equipment: Dictionary = {} # equipment_id -> EquipmentData
var ingredients: Dictionary = {} # ingredient_id -> IngredientData
var levels: Dictionary = {} # level_id -> LevelConfig
var workers: Dictionary = {} # worker_id -> WorkerData
var worker_sequence: Array[StringName] = []
var order_sequence: Array[StringName] = []
var definitions := DefinitionDatabase.new()


func build() -> void:
	definitions.build()
	definitions.apply_to_catalog(self)


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
