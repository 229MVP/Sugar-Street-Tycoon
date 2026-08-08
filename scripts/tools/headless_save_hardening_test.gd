extends SceneTree
## Regression test for Beta 0.1 save hardening: atomic write, new v6 fields,
## and the corrupt-save recovery note used for the Continue error state.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Save hardening test ===")
	await process_frame
	await process_frame
	var gs: Node = root.get_node_or_null("/root/GameState")
	if gs == null:
		push_error("GameState missing")
		quit(1)
		return

	var ok := true
	ok = _test_atomic_write_no_temp_leftover(gs) and ok
	ok = _test_new_fields_roundtrip(gs) and ok
	ok = _test_corrupt_primary_recovers_from_backup(gs) and ok
	ok = _test_total_corruption_sets_reset_note(gs) and ok

	print("=== RESULT: %s ===" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)


func _test_atomic_write_no_temp_leftover(gs: Node) -> bool:
	SaveManager.delete_save()
	gs.new_game()
	gs.save_now()
	if FileAccess.file_exists(SaveManager.TEMP_PATH):
		push_error("temp save file left behind after save_game()")
		return false
	if not FileAccess.file_exists(SaveManager.SAVE_PATH):
		push_error("primary save missing after save_game()")
		return false
	print("[OK] atomic write leaves no temp file")
	return true


func _test_new_fields_roundtrip(gs: Node) -> bool:
	gs.data.tutorial_completed = true
	gs.data.tutorial_step = 5
	gs.data.notification_preference = "enabled"
	gs.data.daily_bonus_state = {"streak_day": 3, "last_claim_unix": 12345, "claimed_today": true}
	gs.data.booster_inventory = {"hammer": 4, "swap": 2}
	gs.save_now()
	gs.continue_game()
	if gs.data.app_version != BuildConfig.APP_VERSION:
		push_error("app_version not persisted: %s" % gs.data.app_version)
		return false
	if not gs.data.tutorial_completed or gs.data.tutorial_step != 5:
		push_error("tutorial fields not persisted")
		return false
	if gs.data.notification_preference != "enabled":
		push_error("notification_preference not persisted")
		return false
	if int(gs.data.daily_bonus_state.get("streak_day", -1)) != 3:
		push_error("daily_bonus_state not persisted")
		return false
	if gs.data.current_screen == null:
		push_error("current_screen field missing")
		return false
	print("[OK] app_version/current_screen/tutorial/daily-bonus/notification fields round-trip")
	return true


func _test_corrupt_primary_recovers_from_backup(gs: Node) -> bool:
	SaveManager.delete_save()
	gs.new_game()
	gs.data.coins = 4242
	gs.save_now() # good backup now holds the previous (500-coin) state on disk
	# Corrupt only the primary; leave the backup (from the save above) intact.
	var f := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	f.store_string("{ not valid json ;;;")
	f.close()
	var loaded := SaveManager.load_game()
	if SaveManager.last_recovery_note != "recovered_from_backup":
		push_error("expected recovered_from_backup note, got '%s'" % SaveManager.last_recovery_note)
		return false
	if loaded == null:
		push_error("recovery returned null data")
		return false
	print("[OK] corrupt primary recovers from backup with correct note")
	return true


func _test_total_corruption_sets_reset_note(gs: Node) -> bool:
	SaveManager.delete_save()
	gs.new_game()
	var f := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	f.store_string("{ not valid json ;;;")
	f.close()
	var bf := FileAccess.open(SaveManager.BACKUP_PATH, FileAccess.WRITE)
	bf.store_string("{ also not valid ;;;")
	bf.close()
	var loaded := SaveManager.load_game()
	if SaveManager.last_recovery_note != "reset_to_defaults":
		push_error("expected reset_to_defaults note, got '%s'" % SaveManager.last_recovery_note)
		return false
	if loaded == null or loaded.player_level != 1:
		push_error("total corruption did not fall back to a usable default save")
		return false
	print("[OK] total corruption falls back to defaults with correct note")
	return true
