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


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	continue_button.pressed.connect(func(): continue_pressed.emit())
	replay_button.pressed.connect(func(): replay_pressed.emit())


func show_result(score: int, moves_remaining: int) -> void:
	score_label.text = "Final score: %d" % score
	moves_label.text = "Moves remaining: %d" % moves_remaining
	visible = true
	modulate.a = 0.0
	panel.scale = Vector2(0.85, 0.85)
	panel.pivot_offset = panel.size * 0.5
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.2)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func hide_popup() -> void:
	visible = false
