extends Control
## Worker roster: hire, upgrade, assign, remove assignment.

@onready var list: VBoxContainer = %List
@onready var detail_label: Label = %DetailLabel
@onready var hire_button: Button = %HireButton
@onready var upgrade_button: Button = %UpgradeButton
@onready var assign_button: Button = %AssignButton
@onready var unassign_button: Button = %UnassignButton
@onready var feedback_label: Label = %FeedbackLabel
@onready var back_button: Button = %BackButton
@onready var coins_label: Label = %CoinsLabel
@onready var confirm_host: Control = %ConfirmHost

var _selected_id: StringName = &""
var _confirm: ConfirmPopup
var _busy: bool = false


func _ready() -> void:
	_confirm = ConfirmPopup.new()
	confirm_host.add_child(_confirm)
	back_button.pressed.connect(func():
		AudioManager.play_button()
		GameState.save_now()
		SceneRouter.go_shop()
	)
	hire_button.pressed.connect(_on_hire)
	upgrade_button.pressed.connect(_on_upgrade)
	assign_button.pressed.connect(_on_assign)
	unassign_button.pressed.connect(_on_unassign)
	GameState.state_changed.connect(refresh)
	refresh()


func refresh() -> void:
	coins_label.text = "Coins: %s" % RewardCalculator.format_coins(GameState.data.coins)
	for child in list.get_children():
		child.queue_free()
	for id_name in GameState.catalog.worker_sequence:
		var worker := GameState.catalog.get_worker(id_name)
		if worker == null:
			continue
		var hired := GameState.is_worker_hired(worker.worker_id)
		var unlocked := WorkerManager.is_unlocked(worker, GameState.data)
		var level := GameState.get_worker_level(worker.worker_id) if hired else 1
		var station := WorkerManager.assigned_station_of(GameState.data, str(worker.worker_id))
		var btn := Button.new()
		var status := "Hired Lv.%d" % level if hired else ("Available" if unlocked else "Locked")
		btn.text = "%s · %s · %s · %s" % [worker.display_name, worker.role_label(), worker.rarity_label(), status]
		if station != WorkerData.Station.NONE:
			btn.text += " @ %s" % WorkerData.station_to_label(station)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_select.bind(worker.worker_id))
		list.add_child(btn)
	if _selected_id == &"":
		_select(&"ava")
	else:
		_select(_selected_id)


func _select(worker_id: StringName) -> void:
	_selected_id = worker_id
	var worker := GameState.catalog.get_worker(worker_id)
	if worker == null:
		return
	var hired := GameState.is_worker_hired(worker_id)
	var unlocked := WorkerManager.is_unlocked(worker, GameState.data)
	var level := GameState.get_worker_level(worker_id) if hired else 1
	var station := WorkerManager.assigned_station_of(GameState.data, str(worker_id))
	var bonus_now := _bonus_text(worker, level)
	var bonus_next := _bonus_text(worker, mini(level + 1, WorkerData.MAX_LEVEL))
	var unlock_txt := WorkerManager.unlock_reason(worker, GameState.data)
	detail_label.text = "%s\n%s · %s\n%s\n\nStation: %s\nAssignment: %s\nLevel: %s\n\nCurrent bonus:\n%s\n\nNext level:\n%s\n\nHire: %s\nUpgrade: %s\n\n%s" % [
		worker.display_name,
		worker.role_label(),
		worker.rarity_label(),
		worker.description,
		worker.station_label(),
		WorkerData.station_to_label(station) if station != WorkerData.Station.NONE else "None",
		("%d / %d" % [level, WorkerData.MAX_LEVEL]) if hired else "—",
		bonus_now,
		bonus_next,
		RewardCalculator.format_coins(worker.hire_cost),
		RewardCalculator.format_coins(worker.upgrade_cost(level)) if hired and level < WorkerData.MAX_LEVEL else "MAX",
		("Unlocked" if unlocked else "Locked: " + unlock_txt),
	]

	var hire_check := GameState.can_hire_worker(worker_id)
	hire_button.disabled = not hire_check.get("ok", false) or _busy
	hire_button.text = "Hired" if hired else "Hire for %s" % RewardCalculator.format_coins(worker.hire_cost)

	var up_check := GameState.can_upgrade_worker(worker_id)
	upgrade_button.disabled = not up_check.get("ok", false) or _busy
	if hired and level >= WorkerData.MAX_LEVEL:
		upgrade_button.text = "Max Level"
	else:
		upgrade_button.text = "Upgrade" if up_check.get("ok", false) else "Upgrade"

	assign_button.disabled = not hired or _busy
	assign_button.text = "Assign to %s" % worker.station_label()
	unassign_button.disabled = station == WorkerData.Station.NONE or _busy

	if not unlocked:
		feedback_label.text = unlock_txt
	elif hired:
		feedback_label.text = str(up_check.get("reason", "Ready."))
	else:
		feedback_label.text = str(hire_check.get("reason", "Ready to hire."))


func _bonus_text(worker: WorkerData, level: int) -> String:
	var lines: PackedStringArray = []
	match str(worker.primary_bonus_type):
		"order_coins":
			lines.append("Order coins +%d%%" % int(worker.primary_bonus_per_level * float(level) * 100.0))
		"order_xp":
			lines.append("Order XP +%d%%" % int(worker.primary_bonus_per_level * float(level) * 100.0))
		"order_reputation":
			lines.append("Order reputation +%d%%" % int(worker.primary_bonus_per_level * float(level) * 100.0))
		"passive_income":
			lines.append("Passive income +%d%%" % int(worker.primary_bonus_per_level * float(level) * 100.0))
		"all_order_rewards":
			lines.append("All order rewards +%d%%" % int(worker.primary_bonus_per_level * float(level) * 100.0))
		"bonus_ingredients":
			var chance := worker.primary_bonus_base + worker.primary_bonus_per_level * float(level)
			lines.append("Bonus ingredient chance %.0f%%" % (chance * 100.0))
	if worker.secondary_bonus_type != StringName():
		if str(worker.secondary_bonus_type) == "passive_income":
			lines.append("Passive income +%d%%" % int(worker.secondary_bonus_per_level * float(level) * 100.0))
	return "\n".join(lines)


func _on_hire() -> void:
	var worker := GameState.catalog.get_worker(_selected_id)
	if worker == null:
		return
	_confirm.show_confirm("Hire Worker?", "Spend %s coins to hire %s?" % [
		RewardCalculator.format_coins(worker.hire_cost), worker.display_name
	], "Hire", "Cancel")
	if _confirm.confirmed.is_connected(_do_hire):
		_confirm.confirmed.disconnect(_do_hire)
	_confirm.confirmed.connect(_do_hire, CONNECT_ONE_SHOT)


func _do_hire() -> void:
	if _busy:
		return
	_busy = true
	var result := GameState.hire_worker(_selected_id)
	_busy = false
	if result.get("ok", false):
		AudioManager.play(AudioManager.Sfx.WORKER_HIRED)
		feedback_label.text = "Hired!"
		var tween := create_tween()
		tween.tween_property(detail_label, "modulate", Color(1.2, 1.1, 0.8), 0.12)
		tween.tween_property(detail_label, "modulate", Color.WHITE, 0.2)
	else:
		feedback_label.text = str(result.get("reason", "Hire failed."))
	refresh()


func _on_upgrade() -> void:
	var worker := GameState.catalog.get_worker(_selected_id)
	var level := GameState.get_worker_level(_selected_id)
	var cost := worker.upgrade_cost(level)
	_confirm.show_confirm("Upgrade Worker?", "Spend %s coins to upgrade %s to level %d?" % [
		RewardCalculator.format_coins(cost), worker.display_name, level + 1
	], "Upgrade", "Cancel")
	if _confirm.confirmed.is_connected(_do_upgrade):
		_confirm.confirmed.disconnect(_do_upgrade)
	_confirm.confirmed.connect(_do_upgrade, CONNECT_ONE_SHOT)


func _do_upgrade() -> void:
	if _busy:
		return
	_busy = true
	var result := GameState.upgrade_worker(_selected_id)
	_busy = false
	if result.get("ok", false):
		AudioManager.play(AudioManager.Sfx.WORKER_UPGRADED)
		feedback_label.text = "Upgraded to level %d!" % int(result.get("new_level", 1))
	else:
		feedback_label.text = str(result.get("reason", "Upgrade failed."))
	refresh()


func _on_assign() -> void:
	var worker := GameState.catalog.get_worker(_selected_id)
	var check := WorkerManager.can_assign(worker, GameState.data, worker.compatible_station)
	if not check.get("ok", false):
		feedback_label.text = str(check.get("reason", ""))
		return
	if check.get("needs_replace_confirm", false):
		var other_id := str(check.get("replaces", ""))
		var other := GameState.catalog.get_worker(StringName(other_id))
		_confirm.show_confirm(
			"Replace Worker?",
			"Replace %s at the %s with %s?" % [
				other.display_name if other else other_id,
				worker.station_label(),
				worker.display_name
			],
			"Replace",
			"Cancel"
		)
		if _confirm.confirmed.is_connected(_do_assign):
			_confirm.confirmed.disconnect(_do_assign)
		_confirm.confirmed.connect(_do_assign, CONNECT_ONE_SHOT)
	else:
		_do_assign()


func _do_assign() -> void:
	var worker := GameState.catalog.get_worker(_selected_id)
	var result := GameState.assign_worker(_selected_id, worker.compatible_station)
	if result.get("ok", false):
		AudioManager.play(AudioManager.Sfx.WORKER_ASSIGNED)
		feedback_label.text = "Assigned to %s." % worker.station_label()
	else:
		feedback_label.text = str(result.get("reason", "Assign failed."))
	refresh()


func _on_unassign() -> void:
	var result := GameState.unassign_worker(_selected_id)
	if result.get("ok", false):
		AudioManager.play(AudioManager.Sfx.WORKER_REMOVED)
		feedback_label.text = "Assignment cleared."
	else:
		feedback_label.text = str(result.get("reason", ""))
	refresh()
