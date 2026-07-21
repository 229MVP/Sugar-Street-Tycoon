class_name PassiveIncomePanel
extends PanelContainer
## Compact passive-income meter + collect button for the shop hub.

signal collect_pressed

var _stored_label: Label
var _rate_label: Label
var _contrib_label: Label
var _collect_button: Button
var _collecting: bool = false


func _ready() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.92)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	style.content_margin_left = 10
	style.content_margin_top = 8
	style.content_margin_right = 10
	style.content_margin_bottom = 8
	add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)

	var title := Label.new()
	title.text = "Walk-in Sales"
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)

	_stored_label = Label.new()
	vbox.add_child(_stored_label)
	_rate_label = Label.new()
	_rate_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(_rate_label)
	_contrib_label = Label.new()
	_contrib_label.add_theme_font_size_override("font_size", 11)
	_contrib_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_contrib_label)

	_collect_button = Button.new()
	_collect_button.text = "Collect"
	_collect_button.custom_minimum_size = Vector2(0, 40)
	_collect_button.pressed.connect(_on_collect)
	vbox.add_child(_collect_button)
	refresh()


func refresh() -> void:
	var info := GameState.get_passive_income_info()
	var stored: float = float(info.get("stored", 0.0))
	var rate: float = float(info.get("rate", 0.0))
	_stored_label.text = "Stored: %s coins" % RewardCalculator.format_coins(int(floor(stored)))
	_rate_label.text = "%.1f coins/min · Cap 4 hours" % rate
	var eq := int(float(info.get("equipment_bonus", 0.0)) * 100.0)
	var wk := int(float(info.get("worker_bonus", 0.0)) * 100.0)
	_contrib_label.text = "Shop x%.2f · Equipment +%d%% · Workers +%d%%" % [
		float(info.get("shop_multiplier", 1.0)), eq, wk
	]
	_collect_button.disabled = stored < 1.0 or _collecting
	if bool(info.get("storage_full", false)):
		_stored_label.text += " (FULL)"


func _on_collect() -> void:
	if _collecting:
		return
	_collecting = true
	_collect_button.disabled = true
	var amount := GameState.collect_passive_income()
	if amount > 0:
		AudioManager.play(AudioManager.Sfx.PASSIVE_COLLECTED)
		AudioManager.play(AudioManager.Sfx.COINS)
		var tween := create_tween()
		tween.tween_property(self, "modulate", Color(1.2, 1.15, 0.8), 0.12)
		tween.tween_property(self, "modulate", Color.WHITE, 0.18)
		await tween.finished
	_collecting = false
	refresh()
	collect_pressed.emit()
