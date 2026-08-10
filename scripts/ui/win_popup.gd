class_name WinPopup
extends Control
## Shown when the level objective is completed.

signal continue_pressed
signal replay_pressed

@onready var panel: PanelContainer = %Panel
@onready var score_label: Label = %ScoreLabel
@onready var moves_label: Label = %MovesLabel
@onready var continue_button: Button = %ContinueButton
@onready var replay_button: Button = %ReplayButton
@onready var stars_label: Label = get_node_or_null("%StarsLabel")

var _busy: bool = false


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	continue_button.pressed.connect(_on_continue)
	replay_button.pressed.connect(_on_replay)
	if stars_label == null:
		stars_label = Label.new()
		stars_label.name = "StarsLabel"
		stars_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		panel.get_node("VBox").add_child(stars_label)
		panel.get_node("VBox").move_child(stars_label, 3)


func _on_continue() -> void:
	if _busy:
		return
	_busy = true
	continue_button.disabled = true
	continue_pressed.emit()


func _on_replay() -> void:
	if _busy:
		return
	_busy = true
	replay_button.disabled = true
	replay_pressed.emit()


func show_result(score: int, moves_remaining: int, stars: int = 1) -> void:
	_busy = false
	continue_button.disabled = false
	replay_button.disabled = false
	score_label.text = "Final score: %d" % score
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	moves_label.text = "Moves remaining: %d" % moves_remaining
	moves_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if stars_label:
		stars_label.text = "Stars earned: %s" % "★".repeat(stars) + "☆".repeat(maxi(0, 3 - stars))
		stars_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stars_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	continue_button.text = "Return to Shop" if SceneRouter.pending_order_id != "" else "Continue"
	ModalLayer.present(self)
	modulate.a = 0.0
	panel.scale = Vector2(0.85, 0.85)
	panel.pivot_offset = panel.size * 0.5
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.2)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	AudioManager.play_popup()


func hide_popup() -> void:
	ModalLayer.dismiss(self)
	visible = false


func request_close_from_back() -> void:
	_on_continue()
