extends SceneTree
## Verifies the data-driven architecture: definitions, inventory, crafting,
## upgrades, workers, and save/reload/new-game behavior.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Managers architecture test ===")
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
	ok = _test_definitions(gs) and ok
	ok = _test_inventory(gs) and ok
	ok = _test_craft(gs) and ok
	ok = _test_upgrades(gs) and ok
	ok = _test_workers(gs) and ok
	ok = _test_save_reload(gs) and ok
	ok = _test_new_game_reset(gs) and ok

	print("=== RESULT: %s ===" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)


func _test_definitions(gs: Node) -> bool:
	var db: DefinitionDatabase = gs.definitions
	if db == null:
		push_error("definitions missing")
		return false
	if db.ingredient_sequence.size() != 12:
		push_error("expected 12 ingredients, got %d" % db.ingredient_sequence.size())
		return false
	if db.recipe_sequence.size() != 8:
		push_error("expected 8 recipes, got %d" % db.recipe_sequence.size())
		return false
	if db.upgrade_sequence.size() != 6:
		push_error("expected 6 upgrades, got %d" % db.upgrade_sequence.size())
		return false
	if db.worker_sequence.size() != 6:
		push_error("expected 6 workers, got %d" % db.worker_sequence.size())
		return false
	if db.customer_sequence.size() != 6:
		push_error("expected 6 customers, got %d" % db.customer_sequence.size())
		return false
	print("[OK] seeded definitions 12 ingredients / 8 recipes / 6 upgrades / 6 workers / 6 customers")
	return true


func _test_inventory(gs: Node) -> bool:
	var inv: InventoryManager = gs.inventory
	if inv.get_amount("chocolate") != 5:
		push_error("starter chocolate wrong")
		return false
	var added := inv.add("chocolate", 3)
	if not added.get("ok", false) or inv.get_amount("chocolate") != 8:
		push_error("add failed: %s" % str(added))
		return false
	var removed := inv.remove("chocolate", 2)
	if not removed.get("ok", false) or inv.get_amount("chocolate") != 6:
		push_error("remove failed")
		return false
	var blocked := inv.remove("chocolate", 999)
	if blocked.get("ok", false):
		push_error("over-remove allowed")
		return false
	var consume_check := inv.consume({"chocolate": 2, "strawberries": 1})
	if not consume_check.get("ok", false):
		push_error("valid consume blocked: %s" % str(consume_check))
		return false
	if inv.get_amount("chocolate") != 4 or inv.get_amount("strawberries") != 4:
		push_error("consume did not deduct correctly")
		return false
	var over_consume := inv.consume({"chocolate": 999})
	if over_consume.get("ok", false):
		push_error("insufficient consume should fail")
		return false
	print("[OK] inventory add/remove/consume/guards")
	return true


func _test_craft(gs: Node) -> bool:
	var recipes: RecipeManager = gs.recipes
	gs.inventory.reset_to_starter()
	var bad := recipes.craft("candied_grapes")
	if bad.get("ok", false):
		push_error("locked recipe craft allowed")
		return false
	# chocolate_strawberries needs 2 chocolate + 3 strawberries; starter has 5 each.
	var ok_craft := recipes.craft("chocolate_strawberries")
	if not ok_craft.get("ok", false):
		push_error("valid craft failed: %s" % str(ok_craft))
		return false
	if gs.inventory.get_amount("chocolate") != 3 or gs.inventory.get_amount("strawberries") != 2:
		push_error("craft did not consume ingredients")
		return false
	if recipes.crafted_count("chocolate_strawberries") != 1:
		push_error("crafted count not tracked")
		return false
	# Second craft needs 2+3 more; only have 3 choc + 2 strawberries left -> should fail.
	var blocked := recipes.craft("chocolate_strawberries")
	if blocked.get("ok", false):
		push_error("insufficient craft should fail")
		return false
	print("[OK] craft valid/invalid + duplicate-safe consumption")
	return true


func _test_upgrades(gs: Node) -> bool:
	var ups: UpgradeManager = gs.upgrades
	var before: int = gs.data.coins
	var result := ups.purchase("oven")
	if not result.get("ok", false):
		push_error("upgrade purchase failed: %s" % str(result))
		return false
	if ups.get_level("oven") != 2:
		push_error("oven not level 2")
		return false
	if gs.data.coins >= before:
		push_error("coins not spent")
		return false
	if gs.get_equipment_level(&"oven") != 2:
		push_error("equipment mirror not synced")
		return false
	gs.data.coins = 0
	var poor := ups.purchase("mixer")
	if poor.get("ok", false):
		push_error("unaffordable upgrade allowed")
		return false
	# Oven/Mixer/Display Case/Cash Register cap at legacy equipment max level (3).
	ups.force_max("oven")
	var maxed := ups.purchase("oven")
	if maxed.get("ok", false):
		push_error("max level still upgradable")
		return false
	print("[OK] upgrades purchase/block/max-level")
	return true


func _test_workers(gs: Node) -> bool:
	gs.data.coins = 5000
	var workers: WorkerService = gs.workers
	var hire := workers.hire("lily")
	if not hire.get("ok", false):
		push_error("hire lily failed: %s" % str(hire))
		return false
	var dup := workers.hire("lily")
	if dup.get("ok", false):
		push_error("duplicate hire allowed")
		return false
	var assign := workers.assign("lily", WorkerData.Station.OVEN)
	if not assign.get("ok", false):
		push_error("assign failed: %s" % str(assign))
		return false
	var bad_station := workers.can_assign("lily", WorkerData.Station.MIXER)
	if bad_station.get("ok", false):
		push_error("duplicate/incompatible assign allowed")
		return false
	var unhired := workers.can_assign("marco", WorkerData.Station.CHECKOUT)
	if unhired.get("ok", false):
		push_error("unhired worker assign allowed")
		return false
	# Re-assigning the same worker to their station must stay idempotent (no
	# duplicate entries in the station->worker assignment map).
	workers.assign("lily", WorkerData.Station.OVEN)
	workers.assign("lily", WorkerData.Station.OVEN)
	if gs.data.worker_assignments.size() != 1:
		push_error("duplicate assignment entries created: %s" % str(gs.data.worker_assignments))
		return false
	if str(gs.data.worker_assignments.get("oven", "")) != "lily":
		push_error("oven station assignment corrupted")
		return false
	print("[OK] worker hire/assign guards (no duplicate hire or assignment)")
	return true


func _test_save_reload(gs: Node) -> bool:
	gs.data.coins = 1234
	gs.inventory.add("butter", 4)
	if gs.upgrades.can_purchase("lighting").get("ok", false):
		gs.upgrades.purchase("lighting")
	# Capture expected values AFTER any purchase side effects, right before saving.
	var expected_coins: int = gs.data.coins
	gs.save_now()
	var lighting_level: int = gs.upgrades.get_level("lighting")
	var butter_amt: int = gs.inventory.get_amount("butter")
	var crafted_before: int = gs.recipes.crafted_count("chocolate_strawberries")
	gs.continue_game()
	if gs.data.coins != expected_coins:
		push_error("coins not restored: expected %d got %d" % [expected_coins, gs.data.coins])
		return false
	if gs.inventory.get_amount("butter") != butter_amt:
		push_error("butter not restored")
		return false
	if gs.upgrades.get_level("lighting") != lighting_level:
		push_error("lighting level not restored")
		return false
	if gs.recipes.crafted_count("chocolate_strawberries") != crafted_before:
		push_error("crafted_items not restored")
		return false
	if not gs.workers.is_hired("lily"):
		push_error("hired worker not restored")
		return false
	print("[OK] save/reload preserves inventory, upgrades, crafted items, workers")
	return true


func _test_new_game_reset(gs: Node) -> bool:
	gs.data.coins = 99999
	gs.inventory.add("chocolate", 50)
	gs.new_game()
	if gs.data.coins != 500:
		push_error("new game coins wrong")
		return false
	if gs.inventory.get_amount("chocolate") != 5:
		push_error("new game pantry wrong")
		return false
	if gs.upgrades.get_level("oven") != 1:
		push_error("new game upgrades wrong")
		return false
	if gs.workers.is_hired("lily"):
		push_error("new game workers not reset")
		return false
	print("[OK] new game resets coins/inventory/upgrades/workers")
	return true
