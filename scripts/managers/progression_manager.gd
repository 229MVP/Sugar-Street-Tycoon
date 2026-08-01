class_name ProgressionManager
extends RefCounted
## Thin signal-bearing wrapper around PlayerProgression (XP curve, levels,
## stars, reputation). Keeps the existing XP/level-up math untouched.

signal experience_changed(current: int, required: int, level: int)
signal player_level_changed(level: int)
signal stars_changed(amount: int)
signal reputation_changed(amount: int)

var _data: SaveData
var _economy: EconomyManager


func setup(data: SaveData, economy: EconomyManager) -> void:
	_data = data
	_economy = economy


func bind_data(data: SaveData) -> void:
	_data = data


func player_level() -> int:
	return _data.player_level if _data else 1


func experience() -> int:
	return _data.experience if _data else 0


func xp_required_for_next_level() -> int:
	return PlayerProgression.xp_required_for_next_level(player_level())


func add_experience(amount: int) -> Array[Dictionary]:
	if amount <= 0 or _data == null:
		return []
	var level_before := _data.player_level
	var level_ups := PlayerProgression.apply_experience(_data, amount)
	experience_changed.emit(_data.experience, xp_required_for_next_level(), _data.player_level)
	if _data.player_level != level_before:
		player_level_changed.emit(_data.player_level)
	if not level_ups.is_empty():
		_economy.coins_changed.emit(_data.coins)
	return level_ups


func add_reputation(amount: int) -> void:
	if amount == 0 or _data == null:
		return
	_data.reputation = maxi(0, _data.reputation + amount)
	reputation_changed.emit(_data.reputation)


func add_stars(amount: int) -> void:
	if amount == 0 or _data == null:
		return
	_data.stars = maxi(0, _data.stars + amount)
	stars_changed.emit(_data.stars)
