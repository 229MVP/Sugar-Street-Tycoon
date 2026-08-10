extends SceneTree
## Save schema v8 migration gate — tutorial_flags + Build 1 progress preservation.
##
## Intentional Build 1 → Build 2 UX behavior:
## - Existing completed/skipped linear tutorials stay completed (never re-enter onboarding).
## - tutorial_flags starts empty after v7→v8 so NEW contextual feature tips can show once.
## - Economy, orders, inventory, recipes, upgrades, workers, décor, boosters,
##   daily bonus, and settings are preserved bit-for-bit (modulo safe clamps).
## - Players are not trapped: feature tips are one-shot and skippable; linear flow stays done.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== SAVE V8 MIGRATION GATE ===")
	await process_frame
	var ok := true
	ok = _test_new_v8_save() and ok
	ok = _test_v7_without_flags() and ok
	ok = _test_v7_completed_tutorial() and ok
	ok = _test_v7_skipped_tutorial() and ok
	ok = _test_missing_partial_malformed_unknown_flags() and ok
	ok = _test_progress_preserved_across_migration() and ok
	ok = _test_repeated_v8_saveload_and_relaunch() and ok
	ok = _test_migration_idempotent_does_not_reset_flags() and ok
	print("=== SAVE V8 MIGRATION GATE: %s ===" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)


func _test_new_v8_save() -> bool:
	var fresh := SaveData.create_default()
	if fresh.version != 8:
		push_error("new save version expected 8, got %d" % fresh.version)
		return false
	if typeof(fresh.tutorial_flags) != TYPE_DICTIONARY:
		push_error("new save tutorial_flags not a Dictionary")
		return false
	if not fresh.tutorial_flags.is_empty():
		push_error("new save should start with empty tutorial_flags")
		return false
	if fresh.tutorial_completed or fresh.tutorial_step != 0:
		push_error("new save should start linear tutorial at step 0")
		return false
	var roundtrip := SaveManager._from_dict(SaveManager._to_dict(fresh))
	if roundtrip.version != SaveData.SAVE_VERSION:
		push_error("new v8 roundtrip lost version")
		return false
	if typeof(roundtrip.tutorial_flags) != TYPE_DICTIONARY or not roundtrip.tutorial_flags.is_empty():
		push_error("new v8 roundtrip corrupted tutorial_flags")
		return false
	print("[OK] new v8 save defaults")
	return true


func _test_v7_without_flags() -> bool:
	var v7 := _make_rich_v7_dict(false, 0)
	v7.erase("tutorial_flags")
	var loaded := SaveManager._from_dict(v7)
	if loaded.version != SaveData.SAVE_VERSION:
		push_error("v7 migration did not bump to v8")
		return false
	if typeof(loaded.tutorial_flags) != TYPE_DICTIONARY:
		push_error("v7 migration did not create tutorial_flags dict")
		return false
	if not loaded.tutorial_flags.is_empty():
		push_error("genuine v7 save without flags should migrate to empty dict")
		return false
	if loaded.tutorial_completed:
		push_error("incomplete v7 tutorial should stay incomplete")
		return false
	if TutorialManager.is_active(loaded) != true:
		push_error("incomplete v7 tutorial should remain active after migration")
		return false
	print("[OK] genuine v7 save without tutorial_flags")
	return true


func _test_v7_completed_tutorial() -> bool:
	var v7 := _make_rich_v7_dict(true, -1)
	v7.erase("tutorial_flags")
	var loaded := SaveManager._from_dict(v7)
	if not loaded.tutorial_completed or loaded.tutorial_step != -1:
		push_error("completed v7 tutorial intent not preserved")
		return false
	if TutorialManager.is_active(loaded):
		push_error("completed Build 1 player must NOT re-enter linear onboarding")
		return false
	# Expanded tips are available once — not a trap.
	if not TutorialManager.should_show_feature_tip(loaded, "inventory"):
		push_error("completed Build 1 player should receive new contextual inventory tip once")
		return false
	TutorialManager.mark_feature_seen(loaded, "inventory")
	if TutorialManager.should_show_feature_tip(loaded, "inventory"):
		push_error("contextual tip must not repeat after seen")
		return false
	print("[OK] completed v7 tutorial mapping (linear done; feature tips once)")
	return true


func _test_v7_skipped_tutorial() -> bool:
	# Build 1 skip wrote the same completion markers as finish.
	var v7 := _make_rich_v7_dict(true, -1)
	v7.erase("tutorial_flags")
	v7["current_screen"] = "shop_hub"
	var loaded := SaveManager._from_dict(v7)
	if not loaded.tutorial_completed or loaded.tutorial_step != -1:
		push_error("skipped v7 tutorial intent not preserved")
		return false
	if TutorialManager.is_active(loaded):
		push_error("skipped Build 1 player must NOT be trapped in onboarding")
		return false
	# Skip of linear flow still allows first-visit feature tips (documented UX).
	if not TutorialManager.should_show_feature_tip(loaded, "settings"):
		push_error("skipped Build 1 player should still get settings tip once")
		return false
	print("[OK] skipped v7 tutorial mapping (linear done; feature tips once)")
	return true


func _test_missing_partial_malformed_unknown_flags() -> bool:
	# Missing
	var missing := _make_rich_v7_dict(true, -1)
	missing.erase("tutorial_flags")
	var m1 := SaveManager._from_dict(missing)
	if typeof(m1.tutorial_flags) != TYPE_DICTIONARY or not m1.tutorial_flags.is_empty():
		push_error("missing tutorial_flags should become {}")
		return false

	# Partial known flags
	var partial := _make_rich_v7_dict(true, -1)
	partial["version"] = 8
	partial["tutorial_flags"] = {"inventory": true, "recipes": false}
	var m2 := SaveManager._from_dict(partial)
	if not bool(m2.tutorial_flags.get("inventory", false)):
		push_error("partial true flag lost")
		return false
	if TutorialManager.should_show_feature_tip(m2, "inventory"):
		push_error("seen inventory tip should stay suppressed")
		return false
	if not TutorialManager.should_show_feature_tip(m2, "recipes"):
		push_error("recipes tip with false flag should still show")
		return false
	if not TutorialManager.should_show_feature_tip(m2, "upgrades"):
		push_error("absent upgrades flag should show tip")
		return false

	# Malformed types
	for bad in [null, "nope", 12, ["inventory"], true]:
		var broken := _make_rich_v7_dict(true, -1)
		broken["version"] = 7
		broken["tutorial_flags"] = bad
		var m3 := SaveManager._from_dict(broken)
		if typeof(m3.tutorial_flags) != TYPE_DICTIONARY:
			push_error("malformed tutorial_flags (%s) did not coerce to Dictionary" % str(bad))
			return false
		if not m3.tutorial_flags.is_empty():
			push_error("malformed tutorial_flags (%s) should yield empty dict" % str(bad))
			return false

	# Unknown keys preserved; do not block known tips
	var unknown := _make_rich_v7_dict(true, -1)
	unknown["version"] = 8
	unknown["tutorial_flags"] = {
		"inventory": true,
		"future_feature_xyz": true,
		"legacy_typo": 1,
	}
	var m4 := SaveManager._from_dict(unknown)
	if not m4.tutorial_flags.has("future_feature_xyz"):
		push_error("unknown tutorial flag keys must be preserved")
		return false
	if TutorialManager.should_show_feature_tip(m4, "inventory"):
		push_error("known seen flag incorrectly cleared")
		return false
	if not TutorialManager.should_show_feature_tip(m4, "workers"):
		push_error("unknown keys must not suppress other feature tips")
		return false

	print("[OK] missing/partial/malformed/unknown tutorial_flags")
	return true


func _test_progress_preserved_across_migration() -> bool:
	var v7 := _make_rich_v7_dict(true, -1)
	v7.erase("tutorial_flags")
	var loaded := SaveManager._from_dict(v7)

	if loaded.coins != 4242:
		push_error("coins not preserved (%d)" % loaded.coins)
		return false
	if loaded.stars != 17:
		push_error("stars not preserved")
		return false
	if loaded.experience != 350:
		push_error("XP not preserved")
		return false
	if loaded.player_level != 4:
		push_error("player level not preserved")
		return false
	if loaded.reputation != 88:
		push_error("reputation not preserved")
		return false
	if int(loaded.settings.get("energy_placeholder", -1)) != 5:
		push_error("energy placeholder setting not preserved")
		return false
	if int(loaded.order_statuses.get("order_mia_001", -999)) != int(SaveData.OrderStatus.COMPLETED):
		push_error("order status not preserved: %s" % str(loaded.order_statuses.get("order_mia_001", null)))
		return false
	if not ("order_mia_001" in loaded.completed_order_ids):
		push_error("completed orders not preserved")
		return false
	if int(loaded.ingredients.get("flour", 0)) != 42:
		push_error("ingredients not preserved")
		return false
	var grapes_unlocked := bool(loaded.unlocked_recipes.get("candied_grapes", false)) \
			or bool(loaded.unlocked_recipes.get(&"candied_grapes", false))
	if not grapes_unlocked:
		push_error("recipes not preserved")
		return false
	if int(loaded.upgrade_levels.get("oven", 0)) != 3:
		push_error("upgrades not preserved")
		return false
	var oven_eq := int(loaded.equipment_levels.get("oven", 0))
	if oven_eq == 0:
		oven_eq = int(loaded.equipment_levels.get(&"oven", 0))
	if oven_eq != 3:
		push_error("equipment not preserved")
		return false
	if not bool(loaded.hired_workers.get("lily", false)):
		push_error("workers not preserved")
		return false
	if str(loaded.placed_decorations.get("front_sign", "")) != "wooden_starter_sign":
		push_error("decorations not preserved")
		return false
	if int(loaded.booster_inventory.get("hammer", 0)) != 7:
		push_error("boosters not preserved")
		return false
	if int(loaded.daily_bonus_state.get("streak_day", -1)) != 4:
		push_error("daily bonus not preserved")
		return false
	if bool(loaded.settings.get("music_enabled", true)) != false:
		push_error("settings not preserved")
		return false
	if float(loaded.settings.get("music_volume", -1.0)) != 0.25:
		push_error("settings volumes not preserved")
		return false
	if not loaded.tutorial_completed or loaded.tutorial_step != -1:
		push_error("tutorial completion intent lost during progress check")
		return false

	print("[OK] progress preserved across v7→v8 migration")
	return true


func _test_repeated_v8_saveload_and_relaunch() -> bool:
	SaveManager.delete_save()
	var gs: Node = root.get_node_or_null("/root/GameState")
	if gs == null:
		push_error("GameState missing")
		return false

	# Start from a migrated v7 payload written to disk as v8 after first save.
	var v7 := _make_rich_v7_dict(true, -1)
	v7.erase("tutorial_flags")
	var migrated := SaveManager._from_dict(v7)
	TutorialManager.mark_feature_seen(migrated, "inventory")
	TutorialManager.mark_feature_seen(migrated, "daily_bonus")
	gs.data = migrated
	gs.save_now()

	for i in range(3):
		gs.continue_game()
		if gs.data.version != SaveData.SAVE_VERSION:
			push_error("relaunch %d lost save version" % i)
			return false
		if not bool(gs.data.tutorial_flags.get("inventory", false)):
			push_error("relaunch %d reset inventory flag" % i)
			return false
		if not bool(gs.data.tutorial_flags.get("daily_bonus", false)):
			push_error("relaunch %d reset daily_bonus flag" % i)
			return false
		if gs.data.coins != 4242:
			push_error("relaunch %d lost coins" % i)
			return false
		if not gs.data.tutorial_completed:
			push_error("relaunch %d lost tutorial_completed" % i)
			return false
		gs.save_now()

	# Pure disk reload path (no GameState mutation between).
	var disk1 := SaveManager.load_game()
	var disk2 := SaveManager.load_game()
	if not bool(disk1.tutorial_flags.get("inventory", false)) \
			or not bool(disk2.tutorial_flags.get("inventory", false)):
		push_error("repeated load_game reset flags")
		return false
	if disk1.coins != disk2.coins or disk1.coins != 4242:
		push_error("repeated load_game changed progression")
		return false

	print("[OK] repeated v8 save/load + relaunch")
	return true


func _test_migration_idempotent_does_not_reset_flags() -> bool:
	# Simulate: migrate once, set flags, serialize as v8, load many times.
	var v7 := _make_rich_v7_dict(true, -1)
	v7.erase("tutorial_flags")
	var once := SaveManager._from_dict(v7)
	TutorialManager.mark_feature_seen(once, "upgrades")
	TutorialManager.mark_feature_seen(once, "workers")
	var as_v8 := SaveManager._to_dict(once)
	if int(as_v8.get("version", 0)) != SaveData.SAVE_VERSION:
		push_error("serialized migrated save not stamped v8")
		return false

	for i in range(5):
		var again := SaveManager._from_dict(as_v8)
		if again.version != SaveData.SAVE_VERSION:
			push_error("idempotent pass %d version mismatch" % i)
			return false
		if not bool(again.tutorial_flags.get("upgrades", false)) \
				or not bool(again.tutorial_flags.get("workers", false)):
			push_error("idempotent pass %d reset feature flags" % i)
			return false
		# Re-running _from_dict on the original v7 dict must still yield empty flags
		# (no memory of prior session) — that is expected and not a reset of a v8 save.
		as_v8 = SaveManager._to_dict(again)

	# Re-migrating the same raw v7 payload repeatedly stays empty (idempotent seed).
	for i in range(3):
		var fresh_mig := SaveManager._from_dict(v7)
		if not fresh_mig.tutorial_flags.is_empty():
			push_error("raw v7 re-migration unexpectedly seeded flags")
			return false
		if not fresh_mig.tutorial_completed:
			push_error("raw v7 re-migration lost completion")
			return false

	print("[OK] migration idempotent; flags not repeatedly reset")
	return true


func _make_rich_v7_dict(tutorial_completed: bool, tutorial_step: int) -> Dictionary:
	## Build a genuine Build 1 / v7-shaped dictionary (no tutorial_flags key by default).
	var base := SaveData.create_default()
	base.coins = 4242
	base.stars = 17
	base.experience = 350
	base.player_level = 4
	base.reputation = 88
	base.tutorial_completed = tutorial_completed
	base.tutorial_step = tutorial_step
	base.ingredients["flour"] = 42
	base.ingredients["sugar"] = 33
	base.unlocked_recipes[&"candied_grapes"] = true
	base.upgrade_levels["oven"] = 3
	base.equipment_levels[&"oven"] = 3
	base.hired_workers["lily"] = true
	base.worker_levels["lily"] = 2
	base.worker_assignments["mixer"] = "lily"
	base.placed_decorations["front_sign"] = "wooden_starter_sign"
	base.owned_decorations["wooden_starter_sign"] = true
	base.booster_inventory = {"hammer": 7, "swap": 2}
	base.daily_bonus_state = {
		"streak_day": 4,
		"last_claim_unix": 1700000000,
		"last_claim_date": "2026-08-01",
		"claimed_today": true,
	}
	base.settings = {
		"music_enabled": false,
		"sfx_enabled": true,
		"music_volume": 0.25,
		"sfx_volume": 0.9,
		"vibration": false,
		"reduce_motion": true,
		"energy_placeholder": 5,
		"last_decor_category": "All",
		"decor_seen_unlocks": {},
	}
	base.order_statuses = {"order_mia_001": SaveData.OrderStatus.COMPLETED}
	base.order_reward_claimed = {"order_mia_001": true}
	base.completed_order_ids = ["order_mia_001"]
	base.visible_order_ids = ["order_mia_001", "order_mia_002"]
	base.best_order_stars = {"order_mia_001": 3}
	base.best_order_scores = {"order_mia_001": 12000}

	var dict := SaveManager._to_dict(base)
	dict["version"] = 7
	dict.erase("tutorial_flags") # genuine v7 never had this key
	return dict
