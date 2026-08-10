extends SceneTree
## Worker + passive + offline + migration smoke tests.


var GS: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Worker system smoke test ===")
	GS = root.get_node("GameState")
	var ok := true
	SaveManager.delete_save()
	GS.new_game()

	ok = _test_lily_available() and ok
	ok = _test_hire_and_duplicate() and ok
	ok = _test_upgrade_rarity_and_cap() and ok
	ok = _test_assignment_rules() and ok
	ok = _test_bonuses_only_when_assigned() and ok
	ok = _test_passive_and_collect() and ok
	ok = _test_offline_cap_and_negative() and ok
	ok = _test_migration_and_repair() and ok
	ok = _test_order_rewards_once() and ok

	print("=== RESULT: %s ===" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)


func _test_lily_available() -> bool:
	var lily = GS.catalog.get_worker(&"lily")
	if lily == null or not WorkerManager.is_unlocked(lily, GS.data):
		push_error("Lily should be available at level 1")
		return false
	var marco = GS.catalog.get_worker(&"marco")
	if WorkerManager.is_unlocked(marco, GS.data):
		push_error("Marco should be locked at level 1")
		return false
	print("[OK] worker unlock gates")
	return true


func _test_hire_and_duplicate() -> bool:
	var before: int = GS.data.coins
	var result: Dictionary = GS.hire_worker(&"lily")
	if not result.get("ok", false):
		push_error("hire lily failed: %s" % str(result))
		return false
	if GS.data.coins != before - 300:
		push_error("hire cost wrong")
		return false
	var dup: Dictionary = GS.hire_worker(&"lily")
	if dup.get("ok", false):
		push_error("duplicate hire allowed")
		return false
	GS.data.coins = 10
	GS.data.player_level = 2
	var poor: Dictionary = GS.can_hire_worker(&"marco")
	if poor.get("ok", false):
		push_error("insufficient coins should block hire")
		return false
	print("[OK] hiring")
	return true


func _test_upgrade_rarity_and_cap() -> bool:
	GS.debug_add_coins(100000)
	GS.data.player_level = 3
	GS.hire_worker(&"mia")
	var mia_cost: int = GS.catalog.get_worker(&"mia").upgrade_cost(1)
	var expected := int(round(250.0 * 1.2))
	if mia_cost != expected:
		push_error("rarity multiplier wrong: %d vs %d" % [mia_cost, expected])
		return false
	for i in 9:
		var up: Dictionary = GS.upgrade_worker(&"mia")
		if not up.get("ok", false):
			push_error("upgrade failed at step %d" % i)
			return false
	if GS.get_worker_level(&"mia") != 10:
		push_error("not level 10")
		return false
	var capped: Dictionary = GS.can_upgrade_worker(&"mia")
	if capped.get("ok", false):
		push_error("level >10 allowed")
		return false
	print("[OK] upgrades")
	return true


func _test_assignment_rules() -> bool:
	GS.assign_worker(&"lily", WorkerData.Station.OVEN)
	var bad: Dictionary = WorkerManager.can_assign(GS.catalog.get_worker(&"lily"), GS.data, WorkerData.Station.MIXER)
	if bad.get("ok", false):
		push_error("incompatible station allowed")
		return false
	GS.data.player_level = 2
	GS.debug_add_coins(1000)
	GS.hire_worker(&"marco")
	GS.assign_worker(&"marco", WorkerData.Station.CHECKOUT)
	var unhired_assign: Dictionary = WorkerManager.can_assign(GS.catalog.get_worker(&"noah"), GS.data, WorkerData.Station.MANAGER)
	if unhired_assign.get("ok", false):
		push_error("unhired assign allowed")
		return false
	print("[OK] assignments")
	return true


func _test_bonuses_only_when_assigned() -> bool:
	GS.debug_clear_assignments()
	var none: Dictionary = WorkerBonusCalculator.order_coin_bonus_percent(GS.catalog, GS.data)
	if float(none.get("percent", 0.0)) != 0.0:
		push_error("unassigned workers granting bonuses")
		return false
	GS.assign_worker(&"marco", WorkerData.Station.CHECKOUT)
	GS.debug_set_worker_level(&"marco", 2)
	var active: Dictionary = WorkerBonusCalculator.order_coin_bonus_percent(GS.catalog, GS.data)
	if absf(float(active.get("percent", 0.0)) - 0.06) > 0.001:
		push_error("marco lv2 should be 6%%, got %s" % str(active.get("percent")))
		return false
	print("[OK] worker bonuses")
	return true


func _test_passive_and_collect() -> bool:
	GS.data.stored_passive_coins = 0.0
	GS.data.last_passive_tick_unix = int(Time.get_unix_time_from_system()) - 120
	var added: float = PassiveIncomeManager.tick(GS.catalog, GS.data)
	if added <= 0.0:
		push_error("passive tick earned nothing")
		return false
	var before: int = GS.data.coins
	var collected: int = GS.collect_passive_income()
	if collected <= 0 or GS.data.coins != before + collected:
		push_error("collect failed")
		return false
	if GS.collect_passive_income() != 0:
		push_error("duplicate collect")
		return false
	PassiveIncomeManager.fill_storage_for_debug(GS.catalog, GS.data)
	var cap: float = PassiveIncomeManager.stored_cap(GS.catalog, GS.data)
	GS.data.last_passive_tick_unix = int(Time.get_unix_time_from_system()) - 99999
	PassiveIncomeManager.tick(GS.catalog, GS.data)
	if GS.data.stored_passive_coins > cap + 0.1:
		push_error("storage exceeded cap")
		return false
	print("[OK] passive income")
	return true


func _test_offline_cap_and_negative() -> bool:
	GS.data.last_active_unix = int(Time.get_unix_time_from_system()) + 5000
	var neg: Dictionary = OfflineEarningsCalculator.calculate(GS.catalog, GS.data)
	if neg.get("ok", false):
		push_error("negative time should fail")
		return false
	GS.data.last_active_unix = int(Time.get_unix_time_from_system()) - (5 * 60 * 60)
	GS.data.last_offline_calc_unix = 0
	var calc: Dictionary = OfflineEarningsCalculator.calculate(GS.catalog, GS.data)
	if not calc.get("ok", false):
		push_error("offline calc failed")
		return false
	if int(calc.get("elapsed_seconds", 0)) != PassiveIncomeManager.MAX_STORAGE_SECONDS:
		push_error("offline not capped to 4h")
		return false
	OfflineEarningsCalculator.apply_to_storage(GS.catalog, GS.data, calc)
	var again: int = OfflineEarningsCalculator.apply_to_storage(GS.catalog, GS.data, calc)
	if again != 0:
		push_error("offline applied twice")
		return false
	print("[OK] offline earnings")
	return true


func _test_migration_and_repair() -> bool:
	var old := {
		"version": 1,
		"coins": 777,
		"player_level": 3,
		"experience": 10,
		"stars": 2,
		"reputation": 5,
		"shop_name": "Sugar Street Starter Shop",
		"shop_level": 1,
		"unlocked_recipes": {"chocolate_strawberries": true, "classic_cupcakes": true},
		"equipment_levels": {"oven": 2, "mixer": 1, "display_case": 1, "checkout": 1},
		"ingredients": {"sugar": 3},
		"order_statuses": {},
		"order_level_results": {},
		"completed_order_ids": [],
		"visible_order_ids": [],
		"settings": {},
	}
	var migrated: SaveData = SaveManager._from_dict(old)
	if migrated.coins != 777 or migrated.version != SaveData.SAVE_VERSION:
		push_error("migration failed")
		return false
	if not bool(migrated.worker_unlock_flags.get("lily", false)):
		push_error("lily unlock default missing")
		return false
	migrated.hired_workers = {"lily": true}
	migrated.worker_levels = {"lily": 99}
	migrated.worker_assignments = {"mixer": "lily", "oven": "lily"}
	migrated.stored_passive_coins = -9.0
	WorkerManager.repair_assignments(GS.catalog, migrated)
	if int(migrated.worker_levels.get("lily", 1)) != 10:
		push_error("level not clamped")
		return false
	if migrated.worker_assignments.has("mixer"):
		push_error("incompatible assignment not removed")
		return false
	if migrated.stored_passive_coins < 0.0:
		push_error("negative storage not repaired")
		return false
	print("[OK] migration/repair")
	return true


func _test_order_rewards_once() -> bool:
	GS.debug_reset_orders()
	GS.assign_worker(&"lily", WorkerData.Station.OVEN)
	var order_id := "order_mia_001"
	GS.begin_order_level(order_id)
	GS.on_level_won(order_id, 500, 10, 20)
	var preview: Dictionary = GS.preview_order_rewards(GS.catalog.get_order(&"order_mia_001"))
	if int(preview.get("coins", 0)) <= 150:
		push_error("worker/equipment bonus not in preview")
		return false
	var first: Dictionary = GS.complete_order(order_id)
	var second: Dictionary = GS.complete_order(order_id)
	if first.is_empty() or not second.is_empty():
		push_error("order reward once failed")
		return false
	print("[OK] order rewards once with worker bonus")
	return true
