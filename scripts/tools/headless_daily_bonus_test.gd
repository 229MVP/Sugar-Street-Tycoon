extends SceneTree
## Daily bonus regression: 7-day streak, claim rules, persistence.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== daily bonus test ===")
	DailyBonusManager._test_today_override = "2026-08-08"
	var ok := true
	ok = _test_reward_definitions() and ok
	ok = _test_day1_claim() and ok
	ok = _test_same_day_denied() and ok
	ok = _test_next_day_progression() and ok
	ok = _test_full_cycle() and ok
	ok = _test_missed_day_reset() and ok
	ok = _test_save_persistence() and ok
	DailyBonusManager._test_today_override = ""
	print("=== DAILY BONUS TEST: %s ===" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)


func _test_reward_definitions() -> bool:
	for day in range(1, DailyBonusManager.MAX_DAY + 1):
		var reward := DailyBonusManager.get_reward_for_day(day)
		if reward.is_empty():
			push_error("missing reward for day %d" % day)
			return false
	print("[OK] seven reward definitions")
	return true


func _test_day1_claim() -> bool:
	var data := SaveData.create_default()
	data.daily_bonus_state = {
		"streak_day": 0,
		"last_claim_date": "",
		"last_claim_unix": 0,
		"claimed_today": false,
	}
	var coins_before := data.coins
	var result := DailyBonusManager.claim(data)
	if not bool(result.get("ok", false)):
		push_error("day 1 claim failed")
		return false
	if int(result.get("day", 0)) != 1:
		push_error("expected day 1")
		return false
	if data.coins <= coins_before:
		push_error("day 1 coins not granted")
		return false
	print("[OK] day 1 claim")
	return true


func _test_same_day_denied() -> bool:
	var data := SaveData.create_default()
	data.daily_bonus_state = {
		"streak_day": 1,
		"last_claim_date": "2026-08-08",
		"last_claim_unix": 0,
		"claimed_today": true,
	}
	var result := DailyBonusManager.claim(data)
	if bool(result.get("ok", false)):
		push_error("second same-day claim should fail")
		return false
	print("[OK] same-day denied")
	return true


func _test_next_day_progression() -> bool:
	var data := SaveData.create_default()
	data.daily_bonus_state = {
		"streak_day": 1,
		"last_claim_date": "2026-08-07",
		"last_claim_unix": 0,
		"claimed_today": false,
	}
	DailyBonusManager._test_today_override = "2026-08-08"
	var result := DailyBonusManager.claim(data)
	if not bool(result.get("ok", false)) or int(result.get("day", 0)) != 2:
		push_error("expected day 2 progression")
		return false
	print("[OK] next-day progression")
	return true


func _test_full_cycle() -> bool:
	var data := SaveData.create_default()
	data.daily_bonus_state = {
		"streak_day": 0,
		"last_claim_date": "",
		"last_claim_unix": 0,
		"claimed_today": false,
	}
	var date := "2026-08-01"
	for expected_day in range(1, DailyBonusManager.MAX_DAY + 1):
		DailyBonusManager._test_today_override = date
		DailyBonusManager.sync_calendar_state(data.daily_bonus_state)
		var result := DailyBonusManager.claim(data)
		if not bool(result.get("ok", false)) or int(result.get("day", 0)) != expected_day:
			push_error("cycle failed at day %d" % expected_day)
			return false
		date = _next_date(date)
	DailyBonusManager._test_today_override = date
	DailyBonusManager.sync_calendar_state(data.daily_bonus_state)
	var wrap := DailyBonusManager.claim(data)
	if not bool(wrap.get("ok", false)) or int(wrap.get("day", 0)) != 1:
		push_error("expected cycle reset after day 7")
		return false
	print("[OK] days 1-7 + cycle reset")
	return true


func _test_missed_day_reset() -> bool:
	var data := SaveData.create_default()
	data.daily_bonus_state = {
		"streak_day": 4,
		"last_claim_date": "2026-08-01",
		"last_claim_unix": 0,
		"claimed_today": false,
	}
	DailyBonusManager._test_today_override = "2026-08-08"
	var result := DailyBonusManager.claim(data)
	if not bool(result.get("ok", false)) or int(result.get("day", 0)) != 1:
		push_error("missed day should restart at day 1")
		return false
	print("[OK] missed-day reset")
	return true


func _test_save_persistence() -> bool:
	var gs := root.get_node_or_null("GameState")
	if gs == null:
		push_error("GameState missing")
		return false
	gs.data.daily_bonus_state = {
		"streak_day": 5,
		"last_claim_date": "2026-08-08",
		"last_claim_unix": 123,
		"claimed_today": true,
	}
	gs.save_now()
	var loaded := SaveManager.load_game()
	if int(loaded.daily_bonus_state.get("streak_day", 0)) != 5:
		push_error("daily bonus streak not persisted")
		return false
	if str(loaded.daily_bonus_state.get("last_claim_date", "")) != "2026-08-08":
		push_error("daily bonus date not persisted")
		return false
	print("[OK] daily bonus save persistence")
	return true


func _prev_date(ymd: String) -> String:
	var p := ymd.split("-")
	var dt := {"year": int(p[0]), "month": int(p[1]), "day": int(p[2])}
	var unix := int(Time.get_unix_time_from_datetime_dict(dt)) - 86400
	var back := Time.get_datetime_dict_from_unix_time(unix)
	return "%04d-%02d-%02d" % [back.year, back.month, back.day]


func _next_date(ymd: String) -> String:
	var p := ymd.split("-")
	var dt := {"year": int(p[0]), "month": int(p[1]), "day": int(p[2])}
	var unix := int(Time.get_unix_time_from_datetime_dict(dt)) + 86400
	var nxt := Time.get_datetime_dict_from_unix_time(unix)
	return "%04d-%02d-%02d" % [nxt.year, nxt.month, nxt.day]
