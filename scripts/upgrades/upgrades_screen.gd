extends Control
## Equipment upgrade screen.

@onready var list: VBoxContainer = %List
@onready var detail_label: Label = %DetailLabel
@onready var upgrade_button: Button = %UpgradeButton
@onready var feedback_label: Label = %FeedbackLabel
@onready var back_button: Button = %BackButton
@onready var coins_label: Label = %CoinsLabel
@onready var confirm_host: Control = %ConfirmHost

var _selected_id: StringName = &""
var _confirm: ConfirmPopup


func _ready() -> void:
	_confirm = ConfirmPopup.new()
	confirm_host.add_child(_confirm)
	back_button.pressed.connect(func():
		AudioManager.play_button()
		SceneRouter.go_shop()
	)
	upgrade_button.pressed.connect(_on_upgrade_pressed)
	GameState.state_changed.connect(refresh)
	refresh()


func refresh() -> void:
	coins_label.text = "Coins: %s" % RewardCalculator.format_coins(GameState.data.coins)
	for child in list.get_children():
		child.queue_free()
	for id in [&"oven", &"mixer", &"display_case", &"checkout"]:
		var eq := GameState.catalog.get_equipment(id)
		if eq == null:
			continue
		var level := GameState.get_equipment_level(id)
		var btn := Button.new()
		btn.text = "%s · Lv.%d/%d" % [eq.display_name, level, eq.max_level]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_select.bind(id))
		list.add_child(btn)
	if _selected_id == &"":
		_select(&"oven")
	else:
		_select(_selected_id)


func _select(equipment_id: StringName) -> void:
	_selected_id = equipment_id
	var eq := GameState.catalog.get_equipment(equipment_id)
	var level := GameState.get_equipment_level(equipment_id)
	var current_bonus := _bonus_text(equipment_id, level)
	var next_bonus := _bonus_text(equipment_id, mini(level + 1, eq.max_level))
	var stage := eq.stage_label_for(level)
	var next_stage := eq.stage_label_for(mini(level + 1, eq.max_level))
	detail_label.text = "%s\nCurrent level: %d\nStage: %s\nCurrent benefit: %s\n\nNext level: %d\nNext stage: %s\nNext benefit: %s\n\n%s" % [
		eq.display_name,
		level,
		stage,
		current_bonus,
		mini(level + 1, eq.max_level),
		next_stage,
		next_bonus,
		eq.benefit_description,
	]
	if level >= eq.max_level:
		upgrade_button.disabled = true
		upgrade_button.text = "Max Level"
		feedback_label.text = "This equipment is fully upgraded."
	else:
		var check := GameState.can_upgrade_equipment(equipment_id)
		var cost := eq.upgrade_cost_to(level + 1)
		upgrade_button.disabled = not check.get("ok", false)
		upgrade_button.text = "Upgrade for %s" % RewardCalculator.format_coins(cost)
		feedback_label.text = str(check.get("reason", ""))


func _bonus_text(equipment_id: StringName, level: int) -> String:
	match str(equipment_id):
		"oven":
			return "+%d%% order coins" % int(RewardCalculator.oven_bonus_percent(level) * 100.0)
		"mixer":
			return "+%d%% experience" % int(RewardCalculator.mixer_bonus_percent(level) * 100.0)
		"display_case":
			return "+%d%% reputation" % int(RewardCalculator.display_bonus_percent(level) * 100.0)
		"checkout":
			return "+%d%% all rewards" % int(RewardCalculator.checkout_bonus_percent(level) * 100.0)
	return "—"


func _on_upgrade_pressed() -> void:
	var eq := GameState.catalog.get_equipment(_selected_id)
	var level := GameState.get_equipment_level(_selected_id)
	var cost := eq.upgrade_cost_to(level + 1)
	_confirm.show_confirm(
		"Upgrade Equipment?",
		"Spend %s coins to upgrade %s to level %d?" % [
			RewardCalculator.format_coins(cost), eq.display_name, level + 1
		],
		"Upgrade",
		"Cancel"
	)
	if _confirm.confirmed.is_connected(_do_upgrade):
		_confirm.confirmed.disconnect(_do_upgrade)
	_confirm.confirmed.connect(_do_upgrade, CONNECT_ONE_SHOT)


func _do_upgrade() -> void:
	var result := GameState.upgrade_equipment(_selected_id)
	if result.get("ok", false):
		AudioManager.play(AudioManager.Sfx.EQUIPMENT_UPGRADED)
		feedback_label.text = "Upgraded to level %d!" % int(result.get("new_level", 0))
	else:
		feedback_label.text = str(result.get("reason", "Upgrade failed."))
	refresh()
