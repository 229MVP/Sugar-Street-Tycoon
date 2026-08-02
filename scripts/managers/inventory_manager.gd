class_name InventoryManager
extends RefCounted
## Data-driven inventory: ingredient quantities, tools, and décor ownership
## queries. Pure data layer — no dependency on visual scenes.

signal inventory_changed(ingredients: Dictionary)
signal item_selected(item_id: String)
signal insufficient_items(item_id: String, need: int, have: int)

var _db: DefinitionDatabase
var _data: SaveData
var selected_item_id: String = ""


func setup(database: DefinitionDatabase, data: SaveData) -> void:
	_db = database
	_data = data
	ensure_defaults()


func bind_data(data: SaveData) -> void:
	_data = data
	ensure_defaults()


func ensure_defaults() -> void:
	if _data == null or _db == null:
		return
	if typeof(_data.ingredients) != TYPE_DICTIONARY:
		_data.ingredients = {}
	if typeof(_data.tools) != TYPE_DICTIONARY:
		_data.tools = {}
	_data.ingredients = SaveData.ensure_ingredient_keys(_data.ingredients)
	# Fill any definition keys still missing (e.g. newly added ingredients).
	for id in _db.ingredient_sequence:
		var def := _db.get_ingredient(id)
		if def == null:
			continue
		if def.is_tool:
			if not _data.tools.has(id):
				_data.tools[id] = maxi(0, def.starting_amount)
		elif not _data.ingredients.has(id):
			_data.ingredients[id] = maxi(0, def.starting_amount)


func get_amount(item_id: String) -> int:
	ensure_defaults()
	var def := _db.get_ingredient(item_id) if _db else null
	if def and def.is_tool:
		return maxi(0, int(_data.tools.get(item_id, 0)))
	return maxi(0, int(_data.ingredients.get(item_id, 0)))


func has_amount(item_id: String, amount: int) -> bool:
	return get_amount(item_id) >= amount


func can_afford(costs: Dictionary) -> Dictionary:
	for key in costs.keys():
		var need := int(costs[key])
		var have := get_amount(str(key))
		if have < need:
			return {"ok": false, "item_id": str(key), "need": need, "have": have}
	return {"ok": true}


func add(item_id: String, amount: int) -> Dictionary:
	if amount == 0:
		return {"ok": true, "amount": get_amount(item_id)}
	if amount < 0:
		return remove(item_id, -amount)
	ensure_defaults()
	var def := _db.get_ingredient(item_id) if _db else null
	var max_stack := def.max_stack if def else 9999
	var new_amount: int = mini(max_stack, get_amount(item_id) + amount)
	if def and def.is_tool:
		_data.tools[item_id] = new_amount
	else:
		_data.ingredients[item_id] = new_amount
	inventory_changed.emit(_snapshot())
	return {"ok": true, "amount": new_amount}


func remove(item_id: String, amount: int) -> Dictionary:
	if amount <= 0:
		return {"ok": false, "reason": "Amount must be positive."}
	ensure_defaults()
	var have := get_amount(item_id)
	if have < amount:
		insufficient_items.emit(item_id, amount, have)
		return {"ok": false, "reason": "Insufficient %s." % item_id, "need": amount, "have": have}
	var def := _db.get_ingredient(item_id) if _db else null
	var new_amount := have - amount
	if def and def.is_tool:
		_data.tools[item_id] = new_amount
	else:
		_data.ingredients[item_id] = new_amount
	inventory_changed.emit(_snapshot())
	return {"ok": true, "amount": new_amount}


func consume(costs: Dictionary) -> Dictionary:
	var check := can_afford(costs)
	if not check.get("ok", false):
		insufficient_items.emit(str(check.get("item_id", "")), int(check.get("need", 0)), int(check.get("have", 0)))
		return check
	for key in costs.keys():
		remove(str(key), int(costs[key]))
	return {"ok": true}


func select_item(item_id: String) -> void:
	selected_item_id = item_id
	item_selected.emit(item_id)


func selected_details() -> Dictionary:
	if selected_item_id == "":
		return {}
	var def := _db.get_ingredient(selected_item_id) if _db else null
	return {
		"id": selected_item_id,
		"amount": get_amount(selected_item_id),
		"definition": def,
		"is_decor_owned": bool(_data.owned_decorations.get(selected_item_id, false)),
	}


func total_units() -> int:
	ensure_defaults()
	var total := 0
	for key in _data.ingredients.keys():
		total += maxi(0, int(_data.ingredients[key]))
	for key in _data.tools.keys():
		total += maxi(0, int(_data.tools[key]))
	return total


func reset_to_starter() -> void:
	if _db == null or _data == null:
		return
	_data.ingredients = _db.starter_ingredient_amounts()
	_data.tools = {}
	inventory_changed.emit(_snapshot())


func _snapshot() -> Dictionary:
	var out := _data.ingredients.duplicate(true) if _data else {}
	if _data and typeof(_data.tools) == TYPE_DICTIONARY:
		for k in _data.tools.keys():
			out[str(k)] = int(_data.tools[k])
	return out
