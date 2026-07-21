class_name LevelCompletePopup
extends Control
## Cream card + coral ribbon Level Complete popup.


signal continue_pressed
signal replay_pressed

var _panel: PanelContainer
var _title: Label
var _stars: Label
var _score: Label
var _rewards: Label
var _continue: Button
var _replay: Button
var _busy: bool = false
var _confetti: Array[ColorRect] = []


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.2, 0.12, 0.1, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(320, 360)
	_panel.add_theme_stylebox_override("panel", ThemeFactory._card(SugarStreetColors.SOFT_IVORY, 22))
	center.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_panel.add_child(vbox)

	var ribbon := PanelContainer.new()
	ribbon.add_theme_stylebox_override("panel", ThemeFactory.coral_header_style())
	vbox.add_child(ribbon)
	_title = Label.new()
	_title.text = "Level Complete"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 24)
	_title.add_theme_color_override("font_color", SugarStreetColors.WHITE)
	ribbon.add_child(_title)

	_stars = Label.new()
	_stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stars.add_theme_font_size_override("font_size", 28)
	_stars.add_theme_color_override("font_color", SugarStreetColors.GOLDEN_YELLOW)
	vbox.add_child(_stars)

	_score = Label.new()
	_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score.add_theme_color_override("font_color", SugarStreetColors.DARK_TEXT)
	vbox.add_child(_score)

	_rewards = Label.new()
	_rewards.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rewards.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rewards.add_theme_color_override("font_color", SugarStreetColors.WOOD_BROWN)
	vbox.add_child(_rewards)

	_continue = Button.new()
	_continue.text = "Continue"
	_continue.custom_minimum_size = Vector2(0, 50)
	ThemeFactory.apply_button_styles(_continue, ThemeFactory.primary_button_styles())
	_continue.pressed.connect(_on_continue)
	vbox.add_child(_continue)

	_replay = Button.new()
	_replay.text = "Replay"
	_replay.custom_minimum_size = Vector2(0, 44)
	ThemeFactory.apply_button_styles(_replay, ThemeFactory.secondary_button_styles())
	_replay.pressed.connect(_on_replay)
	vbox.add_child(_replay)


func show_result(score: int, moves_remaining: int, stars: int, coins: int = 0, xp: int = 0, rep: int = 0) -> void:
	_busy = false
	_stars.text = "★".repeat(stars) + "☆".repeat(maxi(0, 3 - stars))
	_score.text = "Score %d  ·  Moves left %d" % [score, moves_remaining]
	_rewards.text = "Order ready to complete\nPreview: %s coins · %d XP · %d rep" % [
		RewardCalculator.format_coins(coins), xp, rep
	]
	_continue.disabled = false
	_replay.disabled = false
	_spawn_confetti()
	UiMotion.popup_in(self, _panel)
	AudioManager.play_popup()


func hide_popup() -> void:
	visible = false
	for c in _confetti:
		if is_instance_valid(c):
			c.queue_free()
	_confetti.clear()


func _on_continue() -> void:
	if _busy:
		return
	_busy = true
	_continue.disabled = true
	continue_pressed.emit()


func _on_replay() -> void:
	if _busy:
		return
	_busy = true
	_replay.disabled = true
	replay_pressed.emit()


func _spawn_confetti() -> void:
	var colors := [SugarStreetColors.CORAL_PINK, SugarStreetColors.GOLDEN_YELLOW, SugarStreetColors.MINT_GREEN, SugarStreetColors.STRAWBERRY_PINK]
	for i in 18:
		var bit := ColorRect.new()
		bit.size = Vector2(8, 12)
		bit.color = colors[i % colors.size()]
		bit.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bit)
		bit.position = Vector2(40 + randi() % 320, -20 - randi() % 40)
		_confetti.append(bit)
		var tween := create_tween()
		tween.tween_property(bit, "position", Vector2(bit.position.x + randf_range(-40, 40), 520 + randf() * 80), 1.1 + randf() * 0.4)
		tween.parallel().tween_property(bit, "modulate:a", 0.0, 1.2)
