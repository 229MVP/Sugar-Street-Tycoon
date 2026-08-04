extends SceneTree
## Verifies the Beta Diagnostics screen (Phase 12): opens, runs the smoke
## test, shows a PASS result, and closes without leaking duplicate instances.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Beta Diagnostics screen test ===")
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

	var diagnostics = load("res://scripts/tools/beta_diagnostics_screen.gd").new()
	root.add_child(diagnostics)
	await process_frame
	if not is_instance_valid(diagnostics):
		push_error("diagnostics screen freed itself in a debug build")
		quit(1)
		return
	diagnostics.show_panel()
	await process_frame
	if not diagnostics.visible:
		push_error("diagnostics screen did not become visible")
		ok = false

	diagnostics._on_run_smoke_test()
	await process_frame
	await process_frame
	if not diagnostics._results_label.text.begins_with("RESULT: PASS"):
		push_error("smoke test did not report PASS: %s" % diagnostics._results_label.text)
		ok = false
	else:
		print("[OK] smoke test reports PASS from the diagnostics screen")

	diagnostics.hide_panel()
	if diagnostics.visible:
		push_error("hide_panel() did not hide the overlay")
		ok = false

	# Direct BetaSmokeTest API sanity (data-only, no tree).
	var headless_result: Dictionary = BetaSmokeTest.run_full()
	if not headless_result.get("ok", false):
		push_error("BetaSmokeTest.run_full() without a tree reported failures: %s" % str(headless_result.get("messages", [])))
		ok = false
	else:
		print("[OK] BetaSmokeTest.run_full() passes without a SceneTree argument")

	diagnostics.queue_free()
	print("=== RESULT: %s ===" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
