class_name OfflineEarningsCalculator
extends RefCounted
## Calculates capped offline passive income from last active timestamp.

const MIN_OFFLINE_SECONDS := 60
const MAX_OFFLINE_SECONDS := PassiveIncomeManager.MAX_STORAGE_SECONDS


static func calculate(catalog: ContentCatalog, data: SaveData, now_unix: int = -1) -> Dictionary:
	if now_unix < 0:
		now_unix = int(Time.get_unix_time_from_system())
	var last_active := data.last_active_unix
	if last_active <= 0:
		return _empty("no_timestamp")
	var elapsed := now_unix - last_active
	if elapsed < 0:
		if OS.is_debug_build():
			push_warning("OfflineEarnings: negative elapsed (%d) — rejecting (clock skew?)." % elapsed)
		data.last_active_unix = now_unix
		data.last_passive_tick_unix = now_unix
		return _empty("negative_time")
	if elapsed < MIN_OFFLINE_SECONDS:
		return _empty("too_short")
	if elapsed > MAX_OFFLINE_SECONDS:
		if OS.is_debug_build() and elapsed > MAX_OFFLINE_SECONDS * 2:
			print("OfflineEarnings: large gap %ds capped to 4h" % elapsed)
		elapsed = MAX_OFFLINE_SECONDS

	var info := PassiveIncomeManager.coins_per_minute(catalog, data)
	var rate: float = float(info["rate"])
	var base_earned := PassiveIncomeManager.BASE_COINS_PER_MINUTE * (float(elapsed) / 60.0)
	var equipment_part := base_earned * float(info["equipment_bonus"])
	var worker_part := (PassiveIncomeManager.BASE_COINS_PER_MINUTE * float(info["shop_multiplier"]) * (float(elapsed) / 60.0)) * float(info["worker_bonus"])
	# Total uses full formula (shop mult + equipment + workers).
	var total := rate * (float(elapsed) / 60.0)
	var shop_part := PassiveIncomeManager.BASE_COINS_PER_MINUTE * (float(info["shop_multiplier"]) - 1.0) * (float(elapsed) / 60.0)
	# Recalculate contribution breakdown more cleanly for UI.
	var plain := PassiveIncomeManager.BASE_COINS_PER_MINUTE * (float(elapsed) / 60.0)
	var after_shop := plain * float(info["shop_multiplier"])
	var after_equipment := after_shop * (1.0 + float(info["equipment_bonus"]))
	var after_workers := after_equipment * (1.0 + float(info["worker_bonus"]))
	total = after_workers

	return {
		"ok": true,
		"reason": "",
		"elapsed_seconds": elapsed,
		"base_income": int(floor(plain)),
		"shop_bonus_coins": int(floor(after_shop - plain)),
		"equipment_bonus_coins": int(floor(after_equipment - after_shop)),
		"worker_bonus_coins": int(floor(after_workers - after_equipment)),
		"total_coins": int(floor(total)),
		"rate": rate,
		"worker_contributors": info.get("worker_contributors", []),
	}


static func apply_to_storage(catalog: ContentCatalog, data: SaveData, calc: Dictionary) -> int:
	## Adds offline total into stored passive income (not wallet), once.
	if not calc.get("ok", false):
		return 0
	# Prevent double application using last_offline_calc_unix vs last_active.
	if data.last_offline_calc_unix >= data.last_active_unix and data.last_offline_calc_unix > 0:
		# Already calculated for this away period if we updated last_offline after apply.
		# Allow if last_offline is older than last_active (player left after previous calc).
		pass
	var now := int(Time.get_unix_time_from_system())
	if data.last_offline_calc_unix > 0 and data.last_offline_calc_unix >= data.last_active_unix:
		# This away period already processed.
		if OS.is_debug_build():
			print("OfflineEarnings: skip duplicate apply")
		return 0
	var amount := int(calc.get("total_coins", 0))
	if amount <= 0:
		data.last_offline_calc_unix = now
		data.last_passive_tick_unix = now
		return 0
	var cap := PassiveIncomeManager.stored_cap(catalog, data)
	var before := data.stored_passive_coins
	data.stored_passive_coins = minf(cap, data.stored_passive_coins + float(amount))
	var added := int(floor(data.stored_passive_coins - before))
	data.last_offline_calc_unix = now
	data.last_passive_tick_unix = now
	data.offline_pending_popup = calc.duplicate(true)
	data.offline_pending_popup["applied_coins"] = added
	return added


static func mark_session_active(data: SaveData) -> void:
	var now := int(Time.get_unix_time_from_system())
	data.last_active_unix = now


static func _empty(reason: String) -> Dictionary:
	return {
		"ok": false,
		"reason": reason,
		"elapsed_seconds": 0,
		"base_income": 0,
		"equipment_bonus_coins": 0,
		"worker_bonus_coins": 0,
		"total_coins": 0,
	}
