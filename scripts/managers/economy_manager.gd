class_name EconomyManager
extends RefCounted
## Single authority over coin balance. Rejects negative spends and never lets
## the balance drop below zero.

signal coins_changed(amount: int)

var _data: SaveData


func setup(data: SaveData) -> void:
	_data = data


func bind_data(data: SaveData) -> void:
	_data = data


func get_coins() -> int:
	return maxi(0, int(_data.coins)) if _data else 0


func can_afford(cost: int) -> bool:
	return cost >= 0 and get_coins() >= cost


func spend_coins(amount: int, _reason: String = "") -> Dictionary:
	if amount < 0:
		return {"ok": false, "reason": "Cannot spend a negative amount."}
	if not can_afford(amount):
		return {"ok": false, "reason": "Insufficient coins.", "need": amount, "have": get_coins()}
	_data.coins = maxi(0, _data.coins - amount)
	coins_changed.emit(_data.coins)
	return {"ok": true, "coins": _data.coins}


func add_coins(amount: int, _reason: String = "") -> Dictionary:
	if amount < 0:
		return {"ok": false, "reason": "Cannot add a negative amount."}
	_data.coins = maxi(0, _data.coins + amount)
	coins_changed.emit(_data.coins)
	return {"ok": true, "coins": _data.coins}
