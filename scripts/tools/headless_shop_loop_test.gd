extends SceneTree
## Validates shop starter data, order→level→complete rewards, save, and unlocks.
## Uses /root/GameState node lookup so -s mode compiles before Autoload globals bind.


var _gs: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Shop loop smoke test ===")
	await process_frame
	await process_frame
	_gs = root.get_node_or_null("/root/GameState")
	if _gs == null:
		push_error("GameState autoload missing")
		quit(1)
		return

	var ok := true
	SaveManager.delete_save()
	_gs.new_game()

	ok = _test_starter() and ok
	ok = _test_order_visibility() and ok
	ok = await _test_win_complete_flow() and ok
	ok = _test_loss_no_reward() and ok
	ok = _test_stars_and_best() and ok
	ok = _test_recipe_unlock_gate() and ok
	ok = _test_upgrade() and ok
	ok = _test_save_persist() and ok
	ok = _test_corrupt_recovery() and ok

	print("=== RESULT: %s ===" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)


func _test_starter() -> bool:
	var d = _gs.data
	if d.coins != 500 or d.player_level != 1 or d.shop_level != 1:
		push_error("starter economy mismatch")
		return false
	if d.stars != 0 or d.reputation != 0:
		push_error("starter stars/rep mismatch")
		return false
	if not _gs.is_recipe_unlocked(&"chocolate_strawberries"):
		push_error("starter recipe missing")
		return false
	if not _gs.is_recipe_unlocked(&"classic_cupcakes"):
		push_error("starter cupcakes missing")
		return false
	if _gs.is_recipe_unlocked(&"candied_grapes"):
		push_error("candied grapes should be locked")
		return false
	print("[OK] starter data")
	return true


func _test_order_visibility() -> bool:
	var visible = _gs.get_visible_orders()
	if visible.size() != 3:
		push_error("expected 3 visible orders, got %d" % visible.size())
		return false
	for order in visible:
		if str(order.order_id) == "order_morgan":
			push_error("locked-recipe order should not be visible")
			return false
	print("[OK] order visibility")
	return true


func _test_win_complete_flow() -> bool:
	var order_id := "order_mia"
	var level = _gs.begin_order_level(order_id)
	if level == null or level.level_id != "level_01":
		push_error("failed to begin mia order/level")
		return false
	if level.move_limit != 20:
		push_error("mia moves expected 20, got %d" % level.move_limit)
		return false
	var obj = level.get_primary_objective()
	if obj == null or obj.piece_id != &"strawberry" or obj.target_amount != 20:
		push_error("mia objective mismatch")
		return false
	if _gs.get_order_status(order_id) != SaveData.OrderStatus.LEVEL_IN_PROGRESS:
		push_error("order not in progress")
		return false

	var result = _gs.on_level_won(order_id, 900, 10, 20)
	if _gs.get_order_status(order_id) != SaveData.OrderStatus.READY_TO_COMPLETE:
		push_error("order not ready to complete")
		return false
	if int(result.get("stars", 0)) != 3:
		push_error("expected 3 stars for 50% moves, got %s" % str(result.get("stars")))
		return false

	var coins_before: int = _gs.data.coins
	var stars_before: int = _gs.data.stars
	var rep_before: int = _gs.data.reputation
	var rewards = _gs.complete_order(order_id)
	if rewards.is_empty():
		push_error("complete_order returned empty")
		return false
	if _gs.data.coins <= coins_before:
		push_error("coins did not increase")
		return false
	if _gs.data.stars <= stars_before:
		push_error("stars did not increase")
		return false
	if _gs.data.reputation <= rep_before:
		push_error("reputation did not increase")
		return false
	var again = _gs.complete_order(order_id)
	if not again.is_empty():
		push_error("duplicate complete granted rewards")
		return false
	if _gs.get_order_status(order_id) != SaveData.OrderStatus.COMPLETED:
		push_error("order not marked completed")
		return false
	print("[OK] win → ready → complete once")
	return true


func _test_loss_no_reward() -> bool:
	var order_id := "order_jordan"
	_gs.begin_order_level(order_id)
	var coins_before: int = _gs.data.coins
	_gs.on_level_lost(order_id)
	if _gs.get_order_status(order_id) != SaveData.OrderStatus.FAILED:
		push_error("loss did not mark failed")
		return false
	if _gs.data.coins != coins_before:
		push_error("loss granted coins")
		return false
	var empty = _gs.complete_order(order_id)
	if not empty.is_empty():
		push_error("failed order could be completed")
		return false
	print("[OK] loss grants no rewards")
	return true


func _test_stars_and_best() -> bool:
	_gs.data.best_level_stars["level_02"] = 3
	_gs.begin_order_level("order_riley")
	_gs.on_level_won("order_riley", 100, 1, 22)
	if int(_gs.data.best_level_stars.get("level_02", 0)) != 3:
		push_error("best stars decreased")
		return false
	print("[OK] best stars retained")
	return true


func _test_recipe_unlock_gate() -> bool:
	var check = _gs.can_unlock_recipe(&"candied_grapes")
	if check.get("ok", false):
		push_error("candied grapes unlockable too early")
		return false
	_gs.debug_add_stars(3)
	_gs.debug_add_coins(300)
	_gs.debug_add_xp(100)
	check = _gs.can_unlock_recipe(&"candied_grapes")
	if not check.get("ok", false):
		_gs.debug_add_coins(300)
		check = _gs.can_unlock_recipe(&"candied_grapes")
	if not check.get("ok", false):
		push_error("should be able to unlock candied grapes now: %s" % str(check))
		return false
	var coins_before: int = _gs.data.coins
	var result = _gs.unlock_recipe(&"candied_grapes")
	if not result.get("ok", false):
		push_error("unlock failed")
		return false
	if _gs.data.coins >= coins_before:
		push_error("unlock did not deduct coins")
		return false
	var dup = _gs.unlock_recipe(&"candied_grapes")
	if dup.get("ok", false):
		push_error("duplicate unlock allowed")
		return false
	if not _gs.is_recipe_unlocked(&"candied_grapes"):
		push_error("recipe not unlocked")
		return false
	print("[OK] recipe unlock gating")
	return true


func _test_upgrade() -> bool:
	_gs.debug_add_coins(5000)
	var before: int = _gs.get_equipment_level(&"oven")
	var cost_check = _gs.can_upgrade_equipment(&"oven")
	if not cost_check.get("ok", false):
		push_error("oven should be upgradable")
		return false
	var coins_before: int = _gs.data.coins
	var result = _gs.upgrade_equipment(&"oven")
	if not result.get("ok", false):
		push_error("upgrade failed")
		return false
	if _gs.get_equipment_level(&"oven") != before + 1:
		push_error("oven level not increased")
		return false
	if _gs.data.coins >= coins_before:
		push_error("upgrade did not deduct coins")
		return false
	_gs.debug_max_equipment()
	var blocked = _gs.can_upgrade_equipment(&"oven")
	if blocked.get("ok", false):
		push_error("max level still upgradable")
		return false
	print("[OK] equipment upgrades")
	return true


func _test_save_persist() -> bool:
	_gs.data.coins = 1234
	_gs.save_now()
	var loaded := SaveManager.load_game()
	if loaded.coins != 1234:
		push_error("save did not persist coins")
		return false
	print("[OK] save persist")
	return true


func _test_corrupt_recovery() -> bool:
	SaveManager.write_corrupted_save_for_debug()
	var recovered := SaveManager.load_game()
	if recovered == null:
		push_error("corrupt save returned null")
		return false
	if recovered.player_level < 1:
		push_error("recovered save invalid")
		return false
	print("[OK] corrupt save recovery")
	return true
