class_name BoosterManager
extends RefCounted
## Persistent hammer/swap booster inventory.

const HAMMER := &"hammer"
const SWAP := &"swap"

const STARTER_COUNTS := {
	"hammer": 3,
	"swap": 3,
}


static func ensure_defaults(data: SaveData) -> void:
	if typeof(data.booster_inventory) != TYPE_DICTIONARY:
		data.booster_inventory = {}
	for key in STARTER_COUNTS.keys():
		if not data.booster_inventory.has(key):
			data.booster_inventory[key] = int(STARTER_COUNTS[key])
		else:
			data.booster_inventory[key] = maxi(0, int(data.booster_inventory[key]))


static func get_count(data: SaveData, booster_id: StringName) -> int:
	ensure_defaults(data)
	return maxi(0, int(data.booster_inventory.get(str(booster_id), 0)))


static func can_use(data: SaveData, booster_id: StringName) -> bool:
	return get_count(data, booster_id) > 0


static func consume(data: SaveData, booster_id: StringName) -> bool:
	if not can_use(data, booster_id):
		return false
	data.booster_inventory[str(booster_id)] = get_count(data, booster_id) - 1
	return true


static func add(data: SaveData, booster_id: StringName, amount: int) -> void:
	ensure_defaults(data)
	var key := str(booster_id)
	data.booster_inventory[key] = maxi(0, get_count(data, booster_id) + amount)
