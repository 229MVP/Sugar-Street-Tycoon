class_name RecipeManager
extends RefCounted
## Recipe unlock gating + on-demand crafting. Shares `SaveData.unlocked_recipes`
## as the single source of truth with the legacy order-unlock flow in
## GameState, so a recipe unlocked either way is usable everywhere.

signal recipe_unlocked(recipe_id: String)
signal recipe_crafted(recipe_id: String, rewards: Dictionary)
signal recipes_changed

var _db: DefinitionDatabase
var _data: SaveData
var _inventory: InventoryManager
var _economy: EconomyManager


func setup(database: DefinitionDatabase, data: SaveData, inventory: InventoryManager, economy: EconomyManager) -> void:
	_db = database
	_data = data
	_inventory = inventory
	_economy = economy


func bind_data(data: SaveData) -> void:
	_data = data


func ensure_default_unlocks() -> void:
	if _db == null or _data == null:
		return
	if typeof(_data.unlocked_recipes) != TYPE_DICTIONARY:
		_data.unlocked_recipes = {}
	for id in _db.recipe_sequence:
		var def := _db.get_recipe(id)
		if def and def.unlocked_by_default and not _data.unlocked_recipes.has(id):
			_data.unlocked_recipes[id] = true


func all_recipe_ids() -> Array[String]:
	return _db.recipe_sequence.duplicate() if _db else ([] as Array[String])


func get_definition(recipe_id: String) -> RecipeDefinition:
	return _db.get_recipe(recipe_id) if _db else null


func is_unlocked(recipe_id: String) -> bool:
	return bool(_data.unlocked_recipes.get(recipe_id, false))


func can_unlock(recipe_id: String) -> Dictionary:
	var def := get_definition(recipe_id)
	if def == null:
		return {"ok": false, "reason": "Unknown recipe."}
	if is_unlocked(recipe_id):
		return {"ok": false, "reason": "Already unlocked."}
	if _data.player_level < def.required_player_level:
		return {"ok": false, "reason": "Requires player level %d." % def.required_player_level}
	if _data.stars < def.required_stars:
		return {"ok": false, "reason": "Requires %d stars." % def.required_stars}
	if not _economy.can_afford(def.unlock_coin_cost):
		return {"ok": false, "reason": "Need %s coins." % RewardCalculator.format_coins(def.unlock_coin_cost)}
	return {"ok": true, "cost": def.unlock_coin_cost}


func unlock(recipe_id: String) -> Dictionary:
	var check := can_unlock(recipe_id)
	if not check.get("ok", false):
		return check
	var def := get_definition(recipe_id)
	var spend := _economy.spend_coins(def.unlock_coin_cost, "unlock_recipe:%s" % recipe_id)
	if not spend.get("ok", false):
		return spend
	_data.unlocked_recipes[recipe_id] = true
	recipe_unlocked.emit(recipe_id)
	recipes_changed.emit()
	return {"ok": true, "cost": def.unlock_coin_cost}


func can_craft(recipe_id: String) -> Dictionary:
	var def := get_definition(recipe_id)
	if def == null:
		return {"ok": false, "reason": "Unknown recipe."}
	if not is_unlocked(recipe_id):
		return {"ok": false, "reason": "Unlock this recipe first."}
	var afford := _inventory.can_afford(def.craft_ingredient_costs)
	if not afford.get("ok", false):
		var item_id := str(afford.get("item_id", ""))
		return {
			"ok": false,
			"reason": "Need %d more %s." % [int(afford.get("need", 0)) - int(afford.get("have", 0)), item_id],
			"item_id": item_id,
		}
	return {"ok": true}


func craft(recipe_id: String) -> Dictionary:
	var check := can_craft(recipe_id)
	if not check.get("ok", false):
		return check
	var def := get_definition(recipe_id)
	var consumed := _inventory.consume(def.craft_ingredient_costs)
	if not consumed.get("ok", false):
		return consumed
	_economy.add_coins(def.craft_coin_reward, "craft:%s" % recipe_id)
	if typeof(_data.crafted_items) != TYPE_DICTIONARY:
		_data.crafted_items = {}
	_data.crafted_items[recipe_id] = int(_data.crafted_items.get(recipe_id, 0)) + 1
	var rewards := {
		"coins": def.craft_coin_reward,
		"experience": def.craft_xp_reward,
		"reputation": def.craft_reputation_reward,
	}
	recipe_crafted.emit(recipe_id, rewards)
	recipes_changed.emit()
	return {"ok": true, "rewards": rewards, "total_crafted": int(_data.crafted_items[recipe_id])}


func crafted_count(recipe_id: String) -> int:
	if _data == null or typeof(_data.crafted_items) != TYPE_DICTIONARY:
		return 0
	return int(_data.crafted_items.get(recipe_id, 0))
