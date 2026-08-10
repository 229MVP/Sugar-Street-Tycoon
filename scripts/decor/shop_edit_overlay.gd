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
var _return_parent: Node

## Shadows the GameState/AudioManager autoloads with local members so this
## class compiles when instantiated directly (e.g. from a headless `-s`
## test) rather than only when reached through the normal scene boot chain.
@onready var GameState: Node = get_node_or_null("/root/GameState")
@onready var AudioManager: Node = get_node_or_null("/root/AudioManager")


func _ready() -> void:
	visible = false
	# The full-viewport root is only a layout host. It must never consume taps
	# in the transparent area above the sheet, because those taps select the
	# highlighted slots in ShopDecorVisual underneath.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func open_edit(visual: ShopDecorVisual) -> void:
	_visual = visual
	_baseline_placed = GameState.data.placed_decorations.duplicate(true)
	_draft_placed = _baseline_placed.duplicate(true)
	_selected_slot = ""
	_build_if_needed()
	_return_parent = get_parent()
	# Register as the active modal so Android Back cancels the draft. Override
	# ModalLayer's normal full-screen blocker immediately: only this special
	# bottom sheet is intentionally click-through outside its card.
	ModalLayer.present(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_visual.set_edit_mode(true)
	_visual.set_selected_slot("")
	_refresh_status()
	_rebuild_picker()
	AudioManager.play(AudioManager.Sfx.EDIT_MODE_OPENED)


const CARD_HEIGHT := 340.0

func _build_if_needed() -> void:
	if get_child_count() > 0:
		return
	# Bottom-sheet card, not a full-screen scrim: the shop visual above must
	# stay visible AND tappable so the player can pick a highlighted slot
	# while this instructional/picker card is open. Only the card itself is
	# opaque, so it never gets visually confused with the HUD/visual behind
	# it (the literal "collision"), without blocking taps to the slots.
	var safe := SafeAreaContainer.new()
	safe.anchor_left = 0.0
	safe.anchor_right = 1.0
	safe.anchor_top = 1.0
	safe.anchor_bottom = 1.0
	safe.offset_left = 0.0
	safe.offset_right = 0.0
	safe.offset_top = -CARD_HEIGHT
	safe.offset_bottom = 0.0
	safe.set_min_margins(12, 8, 12, 12)
	add_child(safe)

	var card := PanelContainer.new()
	card.name = "EditSheetCard"
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", ThemeFactory._card(SugarStreetColors.SOFT_IVORY, 18))
	safe.add_child(card)

	var margin := MarginContainer.new()
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(m, 14)
	card.add_child(margin)

	# Fixed header (title + live status) — always visible, never scrolls.
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	var header := Label.new()
	header.text = "Shop Edit Mode"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 20)
	header.add_theme_color_override("font_color", SugarStreetColors.BAKERY_BROWN)
	vbox.add_child(header)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", SugarStreetColors.WOOD_BROWN)
	vbox.add_child(_status)

	# Bounded scrolling body — the only part that grows/shrinks with content.
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 120)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ScrollHelper.configure_vertical(scroll)
	vbox.add_child(scroll)
	_picker = VBoxContainer.new()
	_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_picker.add_theme_constant_override("separation", 6)
	scroll.add_child(_picker)

	# Fixed footer with reserved space — never overlapped by scroll content.
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
	var slot = GameState.get_decoration_slot(StringName(slot_id))
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
	var slot = GameState.get_decoration_slot(StringName(_selected_slot))
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
	var result = GameState.place_decoration(StringName(decoration_id), StringName(_selected_slot), replace_existing)
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
	var result = GameState.remove_decoration_from_slot(StringName(_selected_slot))
	if result.get("ok", false):
		AudioManager.play(AudioManager.Sfx.DECOR_REMOVED)
		_draft_placed = GameState.data.placed_decorations.duplicate(true)
		_visual.refresh()
		_rebuild_picker()
		_refresh_status()
		appeal_preview_changed.emit(GameState.get_shop_appeal())


func _refresh_status() -> void:
	var summary = GameState.get_appeal_summary()
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


func cancel_edit() -> void:
	## Public cancellation path used by Android Back through ModalLayer.
	if visible:
		_on_cancel()


func hide_popup() -> void:
	## ModalLayer calls hide_popup() for the top entry on Android Back.
	cancel_edit()


func is_editing() -> bool:
	return visible


func _on_save() -> void:
	AudioManager.play(AudioManager.Sfx.EDIT_MODE_SAVED)
	GameState.save_now()
	_close()


func _close() -> void:
	if _visual:
		_visual.set_edit_mode(false)
		_visual.set_selected_slot("")
	ModalLayer.dismiss(self)
	# ModalLayer reparents presented controls to its CanvasLayer. Return the
	# hidden overlay to its screen so changing scenes frees it normally.
	if _return_parent != null and is_instance_valid(_return_parent) and get_parent() != _return_parent:
		var modal_parent := get_parent()
		if modal_parent != null:
			modal_parent.remove_child(self)
		_return_parent.add_child(self)
	_return_parent = null
	closed.emit()
