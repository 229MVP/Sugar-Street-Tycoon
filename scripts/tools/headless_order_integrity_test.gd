extends SceneTree
## Regression test for Beta 0.1 order/reward integrity requirements:
## no starting a second order while one is in progress, no double reward
## claims, failed orders grant nothing, currency/inventory never go negative.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Order integrity test ===")
	await process_frame
	await process_frame
	var gs: Node = root.get_node_or_null("/root/GameState")
	if gs == null:
		push_error("GameState missing")
		quit(1)
		return

	SaveManager.delete_save()
	gs.new_game()
	await process_frame

	var ok := true
	ok = _test_cannot_start_second_order_while_in_progress(gs) and ok
	ok = _test_resuming_same_order_allowed(gs) and ok
	ok = _test_failed_order_grants_nothing(gs) and ok
	ok = _test_reward_claimed_exactly_once(gs) and ok
	ok = _test_currency_never_negative(gs) and ok

	print("=== RESULT: %s ===" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)


func _test_cannot_start_second_order_while_in_progress(gs: Node) -> bool:
	gs.debug_reset_orders()
	var first := "order_mia_001"
	var second := "order_jordan_002"
	var level_a: LevelConfig = gs.begin_order_level(first)
	if level_a == null:
		push_error("could not start first order")
		return false
	if gs.get_order_status(first) != SaveData.OrderStatus.LEVEL_IN_PROGRESS:
		push_error("first order not marked in-progress")
		return false
	var level_b: LevelConfig = gs.begin_order_level(second)
	if level_b != null:
		push_error("starting a second order while the first is in progress should be blocked")
		return false
	if gs.data.active_order_id != first:
		push_error("active_order_id should remain the first order")
		return false
	print("[OK] cannot start a second order while one is in progress")
	return true


func _test_resuming_same_order_allowed(gs: Node) -> bool:
	var first := "order_mia_001"
	# Re-entering the SAME in-progress order (e.g. Continue) must still work.
	var level_again: LevelConfig = gs.begin_order_level(first)
	if level_again == null:
		push_error("resuming the same in-progress order should be allowed")
		return false
	print("[OK] resuming the same in-progress order is allowed")
	return true


func _test_failed_order_grants_nothing(gs: Node) -> bool:
	var order_id := "order_mia_001"
	var coins_before: int = gs.data.coins
	gs.on_level_lost(order_id)
	if gs.get_order_status(order_id) != SaveData.OrderStatus.FAILED:
		push_error("loss did not mark order FAILED")
		return false
	if gs.data.coins != coins_before:
		push_error("failed order granted coins")
		return false
	var claim: Dictionary = gs.complete_order(order_id)
	if not claim.is_empty():
		push_error("complete_order succeeded on a FAILED order")
		return false
	# A different order should now be startable since the first is FAILED, not in-progress.
	var other: LevelConfig = gs.begin_order_level("order_jordan_002")
	if other == null:
		push_error("should be able to start a different order after a loss")
		return false
	print("[OK] failed orders grant nothing and unblock the order slot")
	return true


func _test_reward_claimed_exactly_once(gs: Node) -> bool:
	gs.debug_reset_orders()
	var order_id := "order_mia_001"
	gs.begin_order_level(order_id)
	gs.on_level_won(order_id, 500, 10, 20)
	var first: Dictionary = gs.complete_order(order_id)
	if first.is_empty():
		push_error("first claim should succeed")
		return false
	var second: Dictionary = gs.complete_order(order_id)
	if not second.is_empty():
		push_error("duplicate claim should return empty")
		return false
	print("[OK] reward claimed exactly once")
	return true


func _test_currency_never_negative(gs: Node) -> bool:
	gs.data.coins = 10
	var result: Dictionary = gs.upgrades.purchase("oven")
	if result.get("ok", false) and gs.data.coins < 0:
		push_error("coins went negative after purchase")
		return false
	if gs.data.coins < 0:
		push_error("coins negative outright")
		return false
	var spend: Dictionary = gs.economy.spend_coins(999999)
	if spend.get("ok", false):
		push_error("overspend should be rejected")
		return false
	if gs.data.coins < 0:
		push_error("coins negative after rejected overspend")
		return false
	print("[OK] currency never goes negative")
	return true
