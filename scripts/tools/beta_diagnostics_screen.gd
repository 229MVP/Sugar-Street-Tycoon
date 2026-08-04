class_name BetaDiagnosticsScreen
extends Control
## Editor/debug-only Beta Diagnostics overlay (Phase 12). Never instantiated
## in a release/TestFlight build — gated by BuildConfig.debug_features_enabled()
## both here and at every call site that creates one.

var _info_label: Label
var _results_label: Label
var _results_scroll: ScrollContainer
var _panel: PanelContainer


func _ready() -> void:
	if not BuildConfig.debug_features_enabled():
		queue_free()
		return
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.05, 0.08, 0.75)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(365, 620)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.12, 0.98)
	style.set_corner_radius_all(16)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	_panel.add_theme_stylebox_override("panel", style)
	center.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_panel.add_child(vbox)

	var title := Label.new()
	title.text = "Beta Diagnostics"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_info_label = Label.new()
	_info_label.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	_info_label.add_theme_font_size_override("font_size", 12)
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_info_label)

	var run_btn := Button.new()
	run_btn.text = "Run Smoke Test"
	run_btn.custom_minimum_size = Vector2(0, 44)
	run_btn.pressed.connect(_on_run_smoke_test)
	vbox.add_child(run_btn)

	_results_scroll = ScrollContainer.new()
	_results_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_results_scroll.custom_minimum_size = Vector2(0, 220)
	vbox.add_child(_results_scroll)
	_results_label = Label.new()
	_results_label.add_theme_font_size_override("font_size", 11)
	_results_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.8))
	_results_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_results_label.text = "Press \"Run Smoke Test\" to check scenes, content, save, and required autoloads."
	_results_scroll.add_child(_results_label)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(0, 44)
	close_btn.pressed.connect(hide_panel)
	vbox.add_child(close_btn)

	set_process(false)


func show_panel() -> void:
	visible = true
	set_process(true)
	_refresh_info()


func hide_panel() -> void:
	visible = false
	set_process(false)


func _process(_delta: float) -> void:
	_refresh_info()


func _refresh_info() -> void:
	if _info_label == null:
		return
	var gs := get_node_or_null("/root/GameState")
	var router := get_node_or_null("/root/SceneRouter")
	var lines: PackedStringArray = []
	lines.append("Build: %s · %s" % [BuildConfig.version_label(), BuildConfig.environment_label()])
	lines.append("Save version: %d (min supported %d)" % [SaveData.SAVE_VERSION, BuildConfig.MINIMUM_SUPPORTED_SAVE_VERSION])
	lines.append("Current scene: %s" % (str(router.current_path) if router else "unknown"))
	lines.append("FPS: %d" % Engine.get_frames_per_second())
	if gs and gs.data:
		lines.append("Active order: %s" % (gs.data.active_order_id if gs.data.active_order_id != "" else "none"))
		lines.append("Coins: %d · Stars: %d · Rep: %d · Lv %d" % [gs.data.coins, gs.data.stars, gs.data.reputation, gs.data.player_level])
	var missing := 0
	for path in BetaSmokeTest.REQUIRED_SCENES:
		if not ResourceLoader.exists(path):
			missing += 1
	lines.append("Missing required resources: %d" % missing)
	_info_label.text = "\n".join(lines)


func _on_run_smoke_test() -> void:
	_results_label.text = "Running…"
	await get_tree().process_frame
	var result := BetaSmokeTest.run_full(get_tree())
	var lines: PackedStringArray = []
	lines.append("RESULT: %s" % ("PASS" if result["ok"] else "FAIL"))
	lines.append("")
	if result["messages"].is_empty():
		lines.append("No issues found.")
	else:
		for m in result["messages"]:
			lines.append("• %s" % m)
	_results_label.text = "\n".join(lines)
	_results_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7) if result["ok"] else Color(1.0, 0.6, 0.6))
