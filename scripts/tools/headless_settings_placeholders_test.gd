extends SceneTree
## Verifies the Beta 0.1 Settings placeholders (notifications, Privacy,
## Support) are wired to real actions and persist correctly.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Settings placeholders test ===")
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

	# Dynamic load (not a static type reference) so this dependency chain
	# compiles lazily at runtime, after autoloads are registered — avoids a
	# headless `-s` parse-order quirk where eagerly-typed references to
	# scripts using bare autoload identifiers (AudioManager/GameState) can
	# fail to resolve if compiled too early in the same process.
	var settings = load("res://scripts/ui/settings_popup.gd").new()
	root.add_child(settings)
	await process_frame
	settings.show_settings()
	await process_frame

	settings._notifications_check.button_pressed = true
	settings._music_slider.value = 0.45 # step-aligned (slider step = 0.05)
	settings._on_close()
	await process_frame

	var ok := true
	if gs.data.notification_preference != "enabled":
		push_error("notification_preference not saved")
		ok = false
	if absf(float(gs.data.settings.get("music_volume", 0.0)) - 0.45) > 0.001:
		push_error("music_volume not saved")
		ok = false

	settings._on_privacy_pressed()
	await process_frame
	if not settings._info.visible:
		push_error("privacy info popup did not show")
		ok = false
	settings._info._yes.pressed.emit()
	await process_frame

	settings._on_support_pressed()
	await process_frame
	if not settings._info.visible:
		push_error("support info popup did not show")
		ok = false

	if ok:
		print("[OK] notifications/Privacy/Support placeholders wired and persist")
	print("=== RESULT: %s ===" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
