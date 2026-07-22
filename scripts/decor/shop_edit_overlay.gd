class_name ShopEditOverlay
extends Control
## Fixed-slot edit mode: tap slot → choose compatible owned decoration.


signal closed
signal appeal_preview_changed(appeal: int)

var _visual: ShopDecorVisual
var _status: Label
var _picker: VBoxContainer
var _selected_slot: String = ""
var _confirm: ConfirmPopup
var _draft_placed: Dictionary = {}
var _baseline_placed: Dictionary = {}


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func open_edit(visual: ShopDecorVisual) -> void:
	_visual = visual
	_baseline_placed = GameState.data.placed_decorations.duplicate(true)
	_draft_placed = _baseline_placed.duplicate(true)
	_selected_slot = ""
	_build_if_needed()
	visible = true
	_visual.set_edit_mode(true)
	_visual.set_selected_slot("")
	_refresh_status()
	_rebuild_picker()
	AudioManager.play(AudioManager.Sfx.EDIT_MODE_OPENED)


func _build_if_needed() -> void:
	if get_child_count() > 0:
		return
	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 10)
	root.add_theme_constant_override("margin_right", 10)
	root.add_theme_constant_override("margin_top", 8)
	root.add_theme_constant_override("margin_bottom", 8)
	add_child(root)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	root.add_child(vbox)

	var header := Label.new()
	header.text = "Shop Edit Mode"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 20)
	header.add_theme_color_override("font_color", SugarStreetColors.BAKERY_BROWN)
	vbox.add_child(header)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", SugarStreetColors.WOOD_BROWN)
	vbox.add_child(_status)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	_picker = VBoxContainer.new()
	_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_picker.add_theme_constant_override("separation", 6)
	scroll.add_child(_picker)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	vbox.add_child(row)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.custom_minimum_size = Vector2(0, 48)
	ThemeFactory.apply_button_styles(cancel, ThemeFactory.secondary_button_styles())
	cancel.pressed.connect(_on_cancel)
	row.add_child(cancel)
	var save := Button.new()
	save.text = "Save Changes"
	save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save.custom_minimum_size = Vector2(0, 48)
	ThemeFactory.apply_button_styles(save, ThemeFactory.primary_button_styles())
	save.pressed.connect(_on_save)
	row.add_child(save)

	_confirm = ConfirmPopup.new()
	add_child(_confirm)

	if _visual and not _visual.slot_pressed.is_connected(_on_slot_pressed):
		_visual.slot_pressed.connect(_on_slot_pressed)


func _on_slot_pressed(slot_id: String) -> void:
	var slot := GameState.get_decoration_slot(StringName(slot_id))
	if slot == null:
		return
	if not DecorationManager.is_slot_unlocked(slot, GameState.data):
		_status.text = "🔒 %s unlocks at shop level %d." % [slot.display_name, slot.required_shop_level]
		return
	_selected_slot = slot_id
	_visual.set_selected_slot(slot_id)
	_rebuild_picker()
	_refresh_status()


func _rebuild_picker() -> void:
	for c in _picker.get_children():
		c.queue_free()
	if _selected_slot == "":
		var tip := Label.new()
		tip.text = "Tap a highlighted slot to place, replace, or remove a decoration."
		tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tip.add_theme_color_override("font_color", SugarStreetColors.DARK_TEXT)
		_picker.add_child(tip)
		return
	var slot := GameState.get_decoration_slot(StringName(_selected_slot))
	var current := str(GameState.data.placed_decorations.get(_selected_slot, ""))
	var title := Label.new()
	title.text = "%s · current: %s" % [slot.display_name, current if current != "" else "Empty"]
	title.add_theme_color_override("font_color", SugarStreetColors.BAKERY_BROWN)
	_picker.add_child(title)

	if current != "":
		var remove_btn := Button.new()
		remove_btn.text = "Remove Current"
		remove_btn.custom_minimum_size = Vector2(0, 44)
		ThemeFactory.apply_button_styles(remove_btn, ThemeFactory.secondary_button_styles())
		remove_btn.pressed.connect(func(): _request_remove())
		_picker.add_child(remove_btn)

	var options := 0
	for decor in GameState.decor_catalog.all_decorations():
		if not GameState.is_decoration_owned(decor.decoration_id):
			continue
		if not DecorationManager.is_compatible(decor, slot):
			continue
		options += 1
		var btn := Button.new()
		var placed_elsewhere := DecorationManager.find_slot_of_decoration(GameState.data, str(decor.decoration_id))
		btn.text = "%s (+%d Appeal)%s" % [
			decor.display_name,
			decor.appeal_value,
			" · equipped" if placed_elsewhere != "" else "",
		]
		btn.custom_minimum_size = Vector2(0, 48)
		ThemeFactory.apply_button_styles(btn, ThemeFactory.soft_button_styles(), SugarStreetColors.DARK_TEXT)
		btn.pressed.connect(_request_place.bind(str(decor.decoration_id)))
		_picker.add_child(btn)
	if options == 0:
		var empty := Label.new()
		empty.text = "No owned decorations fit this slot. Buy compatible décor first."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_picker.add_child(empty)


func _request_place(decoration_id: String) -> void:
	var current := str(GameState.data.placed_decorations.get(_selected_slot, ""))
	if current != "" and current != decoration_id:
		_confirm.show_confirm(
			"Replace Decoration?",
			"Replace the current decoration in this slot?",
			"Replace",
			"Cancel"
		)
		if _confirm.confirmed.is_connected(_do_place):
			_confirm.confirmed.disconnect(_do_place)
		_confirm.confirmed.connect(func(): _do_place(decoration_id, true), CONNECT_ONE_SHOT)
		return
	_do_place(decoration_id, true)


func _do_place(decoration_id: String, replace_existing: bool) -> void:
	var result := GameState.place_decoration(StringName(decoration_id), StringName(_selected_slot), replace_existing)
	if not result.get("ok", false):
		_status.text = str(result.get("reason", "Could not place."))
		return
	if str(result.get("replaced", "")) != "":
		AudioManager.play(AudioManager.Sfx.DECOR_REPLACED)
	else:
		AudioManager.play(AudioManager.Sfx.DECOR_PLACED)
	_draft_placed = GameState.data.placed_decorations.duplicate(true)
	_visual.refresh()
	_rebuild_picker()
	_refresh_status()
	appeal_preview_changed.emit(GameState.get_shop_appeal())


func _request_remove() -> void:
	var result := GameState.remove_decoration_from_slot(StringName(_selected_slot))
	if result.get("ok", false):
		AudioManager.play(AudioManager.Sfx.DECOR_REMOVED)
		_draft_placed = GameState.data.placed_decorations.duplicate(true)
		_visual.refresh()
		_rebuild_picker()
		_refresh_status()
		appeal_preview_changed.emit(GameState.get_shop_appeal())


func _refresh_status() -> void:
	var summary := GameState.get_appeal_summary()
	var delta := int(summary["appeal"]) - ShopAppealCalculator.calculate_appeal(GameState.decor_catalog, _baseline_placed)
	_status.text = "Live Appeal: %d (%s) · Change: %+d%s" % [
		int(summary["appeal"]),
		str(summary["tier"]),
		delta,
		"" if _selected_slot == "" else " · Selected: %s" % _selected_slot,
	]


func _on_cancel() -> void:
	# Restore baseline placements.
	GameState.data.placed_decorations = _baseline_placed.duplicate(true)
	GameState.resync_appeal()
	GameState.save_now()
	_close()


func _on_save() -> void:
	AudioManager.play(AudioManager.Sfx.EDIT_MODE_SAVED)
	GameState.save_now()
	_close()


func _close() -> void:
	if _visual:
		_visual.set_edit_mode(false)
		_visual.set_selected_slot("")
	visible = false
	closed.emit()
