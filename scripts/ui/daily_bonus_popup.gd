class_name DailyBonusPopup
extends Control
## Seven-day daily bonus claim popup.

signal closed

var _grid: GridContainer
var _claim_button: Button
var _status_label: Label
var _busy: bool = false


func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	_build()


func show_popup() -> void:
	_busy = false
	_refresh()
	ModalLayer.present(self)
	FeatureTipPresenter.maybe_show(self, "daily_bonus")


func hide_popup() -> void:
	ModalLayer.dismiss(self)
	visible = false
	_busy = false


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var safe := SafeAreaContainer.new()
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe.set_min_margins(18, 24, 18, 18)
	add_child(safe)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(320, 0)
	var style := ThemeFactory._card(SugarStreetColors.SOFT_IVORY, 18)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Daily Bonus"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", SugarStreetColors.DARK_TEXT)
	vbox.add_child(title)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(_status_label)

	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	vbox.add_child(_grid)

	_claim_button = Button.new()
	_claim_button.text = "Claim Reward"
	_claim_button.custom_minimum_size = Vector2(0, 44)
	ThemeFactory.apply_button_styles(_claim_button, ThemeFactory.primary_button_styles())
	_claim_button.pressed.connect(_on_claim_pressed)
	vbox.add_child(_claim_button)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(0, 40)
	ThemeFactory.apply_button_styles(close_btn, ThemeFactory.secondary_button_styles())
	close_btn.pressed.connect(_on_close_pressed)
	vbox.add_child(close_btn)


func _refresh() -> void:
	for child in _grid.get_children():
		child.queue_free()

	var state := GameState.data.daily_bonus_state
	DailyBonusManager.sync_calendar_state(state)
	for day in range(1, DailyBonusManager.MAX_DAY + 1):
		_grid.add_child(_make_day_card(day, DailyBonusManager.day_status(state, day)))

	if DailyBonusManager.can_claim_today(state):
		_status_label.text = "Day %d reward is ready!" % DailyBonusManager.get_display_day(state)
		_claim_button.text = "Claim Day %d" % DailyBonusManager.get_display_day(state)
		_claim_button.disabled = false
	else:
		_status_label.text = "Already claimed today. Come back tomorrow!"
		_claim_button.text = "Already Claimed"
		_claim_button.disabled = true


func _make_day_card(day: int, status: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bg := SugarStreetColors.SOFT_PEACH
	match status:
		"available":
			bg = SugarStreetColors.MINT_GREEN
		"claimed":
			bg = SugarStreetColors.SOFT_IVORY
	var style := ThemeFactory._card(bg, 12)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", style)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	card.add_child(v)

	var day_lbl := Label.new()
	day_lbl.text = "Day %d" % day
	day_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	day_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	v.add_child(day_lbl)

	var reward_lbl := Label.new()
	reward_lbl.text = DailyBonusManager.describe_reward(day)
	reward_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	reward_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reward_lbl.add_theme_font_size_override("font_size", 12)
	v.add_child(reward_lbl)

	var state_lbl := Label.new()
	match status:
		"available":
			state_lbl.text = "Today"
		"claimed":
			state_lbl.text = "Claimed"
		_:
			state_lbl.text = "Locked"
	state_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	state_lbl.add_theme_font_size_override("font_size", 11)
	v.add_child(state_lbl)
	return card


func _on_claim_pressed() -> void:
	if _busy:
		return
	_busy = true
	_claim_button.disabled = true
	var result := DailyBonusManager.claim(GameState.data)
	if not bool(result.get("ok", false)):
		_status_label.text = "Reward already claimed today."
		_busy = false
		_refresh()
		return
	GameState.save_now()
	GameState.emit_signal("state_changed")
	GameState.emit_signal("coins_changed", GameState.data.coins)
	_status_label.text = "Day %d claimed: %s" % [
		int(result.get("day", 1)),
		DailyBonusManager.describe_reward(int(result.get("day", 1))),
	]
	_refresh()
	_busy = false


func _on_close_pressed() -> void:
	hide_popup()
	closed.emit()
