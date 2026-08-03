extends SceneTree
## Verifies the Beta 0.1 first-session tutorial (Phase 11): shows the right
## step on each screen, advances/persists correctly, supports skip-with-
## confirmation, resumes mid-flow after a "restart", and can be reset in
## debug mode.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Tutorial system test ===")
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
	ok = _test_new_game_starts_tutorial(gs) and ok
	ok = await _test_shop_hub_shows_intro_step(gs) and ok
	ok = await _test_orders_screen_shows_step(gs) and ok
	ok = await _test_gameplay_shows_step(gs) and ok
	ok = _test_skip_completes_tutorial(gs) and ok
	ok = _test_resume_after_close(gs) and ok
	ok = _test_debug_reset(gs) and ok

	print("=== RESULT: %s ===" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)


func _test_new_game_starts_tutorial(gs: Node) -> bool:
	if gs.data.tutorial_completed:
		push_error("new game should not start with tutorial completed")
		return false
	if gs.data.tutorial_step != 0:
		push_error("new game should start at tutorial step 0, got %d" % gs.data.tutorial_step)
		return false
	print("[OK] new game starts the tutorial at step 0")
	return true


func _test_shop_hub_shows_intro_step(gs: Node) -> bool:
	var scene: PackedScene = load("res://scenes/shop/shop_hub.tscn")
	var hub := scene.instantiate()
	root.add_child(hub)
	await process_frame
	await process_frame
	if hub._tutorial == null or not hub._tutorial.visible:
		push_error("shop hub did not show the tutorial intro overlay")
		hub.queue_free()
		return false
	# "Got It" advances the step and hides the overlay.
	hub._tutorial._on_next()
	await process_frame
	if gs.data.tutorial_step != 1:
		push_error("advancing from shop_hub_intro should move to step 1, got %d" % gs.data.tutorial_step)
		hub.queue_free()
		return false
	hub.queue_free()
	await process_frame
	print("[OK] Shop Hub shows step 0 and advances to step 1 on dismiss")
	return true


func _test_orders_screen_shows_step(gs: Node) -> bool:
	var scene: PackedScene = load("res://scenes/orders/orders_screen.tscn")
	var screen := scene.instantiate()
	root.add_child(screen)
	await process_frame
	await process_frame
	if screen._tutorial == null or not screen._tutorial.visible:
		push_error("orders screen did not show its tutorial step")
		screen.queue_free()
		return false
	screen._tutorial._on_next()
	await process_frame
	if gs.data.tutorial_step != 2:
		push_error("advancing from orders step should move to step 2, got %d" % gs.data.tutorial_step)
		screen.queue_free()
		return false
	screen.queue_free()
	await process_frame
	print("[OK] Orders screen shows step 1 and advances to step 2 on dismiss")
	return true


func _test_gameplay_shows_step(gs: Node) -> bool:
	var packed := load("res://scenes/main/main.tscn") as PackedScene
	var main_scene := packed.instantiate()
	root.add_child(main_scene)
	for _i in 30:
		await process_frame
	var slot := main_scene.get_node_or_null("GameplaySlot")
	var root_node = slot.get_child(0) if slot and slot.get_child_count() > 0 else null
	if root_node == null:
		push_error("could not find gameplay_root instance under GameplaySlot")
		main_scene.queue_free()
		return false
	await process_frame
	if not ("_tutorial" in root_node) or root_node._tutorial == null or not root_node._tutorial.visible:
		push_error("gameplay did not show its tutorial step")
		main_scene.queue_free()
		return false
	root_node._tutorial._on_next()
	await process_frame
	if gs.data.tutorial_step != 3:
		push_error("advancing from gameplay step should move to step 3, got %d" % gs.data.tutorial_step)
		main_scene.queue_free()
		return false
	main_scene.queue_free()
	await process_frame
	print("[OK] Gameplay shows step 2 and advances to step 3 on dismiss")
	return true


func _test_skip_completes_tutorial(gs: Node) -> bool:
	# Currently on step 3 ("level_complete"). Skipping should complete it
	# regardless of which step is active.
	TutorialManager.skip(gs.data)
	if not gs.data.tutorial_completed or gs.data.tutorial_step != -1:
		push_error("skip() did not mark the tutorial completed")
		return false
	if TutorialManager.is_active(gs.data):
		push_error("tutorial should no longer be active after skip")
		return false
	print("[OK] skip() completes the tutorial from any step")
	return true


func _test_resume_after_close(gs: Node) -> bool:
	# Simulate a fresh app session mid-tutorial (before completion).
	gs.data.tutorial_completed = false
	gs.data.tutorial_step = 2
	gs.save_now()
	gs.continue_game()
	if gs.data.tutorial_step != 2 or gs.data.tutorial_completed:
		push_error("tutorial progress did not survive a save/reload")
		return false
	if not TutorialManager.should_show(gs.data, "gameplay"):
		push_error("resumed tutorial should still point at the gameplay step")
		return false
	print("[OK] tutorial progress resumes correctly after save/reload")
	return true


func _test_debug_reset(gs: Node) -> bool:
	gs.data.tutorial_completed = true
	gs.data.tutorial_step = -1
	TutorialManager.reset_debug_only(gs.data)
	if gs.data.tutorial_completed or gs.data.tutorial_step != 0:
		push_error("debug reset did not restart the tutorial")
		return false
	print("[OK] debug-only reset restarts the tutorial at step 0")
	return true
