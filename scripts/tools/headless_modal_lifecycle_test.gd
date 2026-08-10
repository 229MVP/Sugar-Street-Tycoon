extends SceneTree
## Focused Android modal lifecycle/settings chrome regression gate.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== MODAL LIFECYCLE + SETTINGS CHROME TEST ===")
	var ok := true
	ok = await _test_one_back_closes_one_modal() and ok
	ok = await _test_settings_back_persists() and ok
	ok = await _test_reward_uses_full_viewport_host() and ok
	ok = _test_settings_chrome_contrast_and_thickness() and ok
	ok = await _test_clear_all_removes_hosted_controls() and ok
	print("=== MODAL LIFECYCLE + SETTINGS CHROME: %s ===" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)


func _test_one_back_closes_one_modal() -> bool:
	var host := ModalLayer.ensure(self)
	await process_frame
	var lower := ConfirmPopup.new()
	var upper := ConfirmPopup.new()
	root.add_child(lower)
	root.add_child(upper)
	await process_frame
	var cancelled := {"lower": 0, "upper": 0}
	lower.cancelled.connect(func(): cancelled["lower"] += 1)
	upper.cancelled.connect(func(): cancelled["upper"] += 1)
	lower.show_confirm("Lower", "Lower modal", "OK", "Cancel")
	upper.show_confirm("Upper", "Upper modal", "OK", "Cancel")
	await process_frame
	# Simulate the single OS notification that is broadcast to both autoloads.
	root.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await process_frame
	if cancelled["upper"] != 1 or cancelled["lower"] != 0:
		push_error("One Android Back did not cancel exactly the top modal")
		return false
	if not lower.visible or upper.visible or host.top_modal() != lower:
		push_error("Modal stack lost more than its top entry on one Back")
		return false
	root.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await process_frame
	if cancelled["lower"] != 1 or host.has_open_modal():
		push_error("Second Android Back did not cancel the remaining modal")
		return false
	lower.queue_free()
	upper.queue_free()
	print("[OK] one Android Back cancels exactly one stacked modal")
	return true


func _test_settings_back_persists() -> bool:
	var gs := root.get_node_or_null("/root/GameState")
	if gs == null:
		push_error("GameState missing for Settings persistence test")
		return false
	var original := bool(gs.data.settings.get("music_enabled", true))
	var original_tip_seen := bool(gs.data.tutorial_flags.get("settings", false))
	# Keep the one-shot Settings feature tip from becoming the top modal; this
	# case specifically validates Back while Settings itself is topmost.
	gs.data.tutorial_flags["settings"] = true
	var settings := SettingsPopup.new()
	root.add_child(settings)
	await process_frame
	settings.show_settings()
	await process_frame
	var check: CheckButton = settings.get("_music_check")
	check.button_pressed = not original
	if not ModalLayer.handle_back_static():
		push_error("Settings Back was not handled")
		return false
	if bool(gs.data.settings.get("music_enabled", original)) == original:
		push_error("Settings value was discarded by Android Back")
		return false
	# Restore test state without changing save semantics.
	gs.update_settings({"music_enabled": original})
	gs.data.tutorial_flags["settings"] = original_tip_seen
	gs.save_now()
	settings.queue_free()
	print("[OK] Settings values persist when dismissed with Android Back")
	return true


func _test_reward_uses_full_viewport_host() -> bool:
	var reward := RewardPopup.new()
	root.add_child(reward)
	await process_frame
	reward.show_rewards({
		"customer_name": "Test",
		"recipe_name": "Test Treat",
		"coins": 1,
		"experience": 1,
		"reputation": 1,
		"stars": 1,
		"ingredients": {},
	})
	await process_frame
	if reward.get_parent() != ModalLayer.ensure(self):
		push_error("RewardPopup bypassed ModalLayer")
		return false
	if reward.anchor_left != 0.0 or reward.anchor_top != 0.0 or reward.anchor_right != 1.0 or reward.anchor_bottom != 1.0:
		push_error("RewardPopup root is not full viewport")
		return false
	var panel: PanelContainer = reward.get("_panel")
	if panel == null or panel.custom_minimum_size.x > 320.0:
		push_error("RewardPopup panel is too wide for a 360px safe viewport")
		return false
	reward.hide_popup()
	reward.queue_free()
	print("[OK] RewardPopup is full-viewport hosted and narrow-screen safe")
	return true


func _test_settings_chrome_contrast_and_thickness() -> bool:
	var check := CheckButton.new()
	ThemeFactory.apply_check_button_styles(check)
	var normal := check.get_theme_stylebox("normal") as StyleBoxFlat
	var pressed := check.get_theme_stylebox("pressed") as StyleBoxFlat
	var focus := check.get_theme_stylebox("focus") as StyleBoxFlat
	var off_image := (check.get_theme_icon("unchecked") as ImageTexture).get_image()
	var on_image := (check.get_theme_icon("checked") as ImageTexture).get_image()
	# Sample the track above the knob's horizontal centerline.
	var off_track := off_image.get_pixel(20, 2)
	var on_track := on_image.get_pixel(20, 2)
	if off_track.is_equal_approx(normal.bg_color) or on_track.is_equal_approx(pressed.bg_color):
		push_error("CheckButton track still matches and disappears into its row")
		return false
	if focus.bg_color.a > 0.01:
		push_error("CheckButton focus overlay is opaque")
		return false
	var theme := ThemeFactory.build()
	var slider_track := theme.get_stylebox("slider", "HSlider")
	var slider_fill := theme.get_stylebox("grabber_area", "HSlider")
	if slider_track.get_minimum_size().y < 4.0 or slider_fill.get_minimum_size().y < 4.0:
		push_error("HSlider track/fill has zero or near-zero thickness")
		return false
	print("[OK] toggle tracks contrast with rows; slider tracks have thickness")
	return true


func _test_clear_all_removes_hosted_controls() -> bool:
	var host := ModalLayer.ensure(self)
	var first := ConfirmPopup.new()
	var second := ConfirmPopup.new()
	root.add_child(first)
	root.add_child(second)
	await process_frame
	first.show_confirm("First", "First", "OK", "Cancel")
	second.show_confirm("Second", "Second", "OK", "Cancel")
	await process_frame
	ModalLayer.clear_all_static()
	await process_frame
	if host.has_open_modal() or host.get_child_count() != 0:
		push_error("ModalLayer retained hosted controls after scene cleanup")
		return false
	print("[OK] scene cleanup removes all hosted modal controls")
	return true
