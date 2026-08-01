class_name OrderManager
extends RefCounted
## Data-driven read layer over the order board. The authoritative order state
## machine (select / start / win / complete) remains in GameState — this
## manager exposes definition lookups plus a single `orders_changed` signal so
## UI can react without depending on visual scenes or GameState internals.

signal orders_changed

var _db: DefinitionDatabase
var _data: SaveData
var _catalog: ContentCatalog


func setup(database: DefinitionDatabase, data: SaveData, catalog: ContentCatalog) -> void:
	_db = database
	_data = data
	_catalog = catalog


func bind_data(data: SaveData) -> void:
	_data = data


func all_order_ids() -> Array[String]:
	return _db.order_sequence.duplicate() if _db else ([] as Array[String])


func get_definition(order_id: String) -> OrderDefinition:
	return _db.get_order(order_id) if _db else null


func customer_for(order_id: String) -> CustomerDefinition:
	var def := get_definition(order_id)
	return _db.get_customer(def.customer_id) if def and _db else null


func reward_for(order_id: String) -> RewardDefinition:
	var def := get_definition(order_id)
	return _db.get_reward(def.reward_id) if def and _db else null


func visible_order_ids() -> Array[String]:
	if _data == null:
		return []
	var out: Array[String] = []
	for id in _data.visible_order_ids:
		out.append(str(id))
	return out


## Called by GameState after any order mutation so listeners stay in sync
## without this manager owning the mutation logic itself.
func notify_changed() -> void:
	orders_changed.emit()
