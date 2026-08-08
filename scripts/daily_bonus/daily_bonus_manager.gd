class_name DailyBonusManager
extends RefCounted
## Seven-day escalating daily reward streak.

const MAX_DAY := 7

const REWARDS := [
	{"coins": 100},
	{"coins": 150},
	{"hammer": 1},
	{"coins": 250},
	{"swap": 1},
	{"coins": 350, "hammer": 1},
	{"coins": 500, "hammer": 1, "swap": 1},
]


static func sync_calendar_state(state: Dictionary) -> void:
	var today := _today_key()
	var last_date := str(state.get("last_claim_date", ""))
	state["claimed_today"] = last_date == today
	if not state.has("streak_day"):
		state["streak_day"] = 0
	if not state.has("last_claim_unix"):
		state["last_claim_unix"] = 0


static func can_claim_today(state: Dictionary) -> bool:
	sync_calendar_state(state)
	return not bool(state.get("claimed_today", false))


static func get_display_day(state: Dictionary) -> int:
	sync_calendar_state(state)
	if bool(state.get("claimed_today", false)):
		return clampi(int(state.get("streak_day", 1)), 1, MAX_DAY)
	var streak := int(state.get("streak_day", 0))
	if streak <= 0:
		return 1
	if _is_next_calendar_day(state):
		if streak >= MAX_DAY:
			return 1
		return streak + 1
	return 1


static func get_reward_for_day(day: int) -> Dictionary:
	var idx := clampi(day, 1, MAX_DAY) - 1
	return REWARDS[idx].duplicate(true)


static func describe_reward(day: int) -> String:
	var reward := get_reward_for_day(day)
	var parts: PackedStringArray = []
	if reward.has("coins"):
		parts.append("%d coins" % int(reward["coins"]))
	if reward.has("hammer"):
		parts.append("%d hammer" % int(reward["hammer"]))
	if reward.has("swap"):
		parts.append("%d swap" % int(reward["swap"]))
	return ", ".join(parts)


static func claim(data: SaveData) -> Dictionary:
	var state := data.daily_bonus_state
	sync_calendar_state(state)
	if not can_claim_today(state):
		return {"ok": false, "reason": "already_claimed"}

	var next_day := 1
	var streak := int(state.get("streak_day", 0))
	if streak > 0 and _is_next_calendar_day(state):
		next_day = streak + 1
		if next_day > MAX_DAY:
			next_day = 1
	elif streak > 0 and not _is_next_calendar_day(state) and not bool(state.get("claimed_today", false)):
		# Missed one or more days — restart cycle.
		next_day = 1

	var reward := get_reward_for_day(next_day)
	_apply_reward(data, reward)

	state["streak_day"] = next_day
	state["last_claim_date"] = _today_key()
	state["last_claim_unix"] = int(Time.get_unix_time_from_system())
	state["claimed_today"] = true
	data.daily_bonus_state = state
	return {"ok": true, "day": next_day, "reward": reward}


static func day_status(state: Dictionary, day: int) -> String:
	sync_calendar_state(state)
	var streak := int(state.get("streak_day", 0))
	var avail := get_display_day(state)
	var claimed_today := bool(state.get("claimed_today", false))
	if claimed_today:
		return "claimed" if day <= streak else "locked"
	if day == avail:
		return "available"
	if streak > 0 and _is_next_calendar_day(state) and day <= streak:
		return "claimed"
	return "locked"


static func _apply_reward(data: SaveData, reward: Dictionary) -> void:
	if reward.has("coins"):
		data.coins = maxi(0, data.coins + int(reward["coins"]))
	if reward.has("hammer"):
		BoosterManager.add(data, BoosterManager.HAMMER, int(reward["hammer"]))
	if reward.has("swap"):
		BoosterManager.add(data, BoosterManager.SWAP, int(reward["swap"]))


static var _test_today_override: String = ""


static func _today_key() -> String:
	if _test_today_override != "":
		return _test_today_override
	var dt := Time.get_datetime_dict_from_system(true)
	return "%04d-%02d-%02d" % [dt.year, dt.month, dt.day]


static func _is_next_calendar_day(state: Dictionary) -> bool:
	var last_date := str(state.get("last_claim_date", ""))
	if last_date == "":
		return true
	var last_parts := last_date.split("-")
	if last_parts.size() != 3:
		return true
	var last_dt := {
		"year": int(last_parts[0]),
		"month": int(last_parts[1]),
		"day": int(last_parts[2]),
	}
	var today_parts := _today_key().split("-")
	var today_dt := {
		"year": int(today_parts[0]),
		"month": int(today_parts[1]),
		"day": int(today_parts[2]),
	}
	var last_unix := Time.get_unix_time_from_datetime_dict(last_dt)
	var today_unix := Time.get_unix_time_from_datetime_dict(today_dt)
	var day_delta := int((today_unix - last_unix) / 86400)
	return day_delta == 1
