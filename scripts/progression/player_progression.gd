class_name PlayerProgression
extends RefCounted
## XP curve and level-up rewards.


static func xp_required_for_next_level(current_level: int) -> int:
	return 100 + ((current_level - 1) * 75)


static func level_up_coin_reward(new_level: int) -> int:
	return 100 * new_level


## Applies XP. Returns array of level-up dictionaries:
## { "new_level": int, "coin_reward": int }
static func apply_experience(data: SaveData, amount: int) -> Array[Dictionary]:
	var level_ups: Array[Dictionary] = []
	if amount <= 0 or data == null:
		return level_ups
	data.experience += amount
	while true:
		var need := xp_required_for_next_level(data.player_level)
		if data.experience < need:
			break
		data.experience -= need
		data.player_level += 1
		var reward := level_up_coin_reward(data.player_level)
		data.coins += reward
		level_ups.append({"new_level": data.player_level, "coin_reward": reward})
	return level_ups


static func calculate_stars(moves_remaining: int, move_limit: int) -> int:
	if move_limit <= 0:
		return 1
	var ratio := float(moves_remaining) / float(move_limit)
	if ratio >= 0.5:
		return 3
	if ratio >= 0.25:
		return 2
	return 1
