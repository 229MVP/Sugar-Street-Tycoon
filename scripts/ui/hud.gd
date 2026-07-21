class_name GameHUD
extends Control
## Portrait HUD: title, objective, progress, moves, score, pause/restart.

signal pause_pressed
signal restart_pressed

@onready var title_label: Label = %TitleLabel
@onready var objective_label: Label = %ObjectiveLabel
@onready var progress_label: Label = %ProgressLabel
@onready var moves_label: Label = %MovesLabel
@onready var score_label: Label = %ScoreLabel
@onready var status_label: Label = %StatusLabel
@onready var pause_button: Button = %PauseButton
@onready var restart_button: Button = %RestartButton
@onready var progress_bar: ProgressBar = %ProgressBar


func _ready() -> void:
	pause_button.pressed.connect(func(): pause_pressed.emit())
	restart_button.pressed.connect(func(): restart_pressed.emit())
	title_label.text = "Sugar Street Tycoon"


func bind_controller(controller: GameController) -> void:
	controller.hud_refresh_requested.connect(func(): refresh(controller))
	controller.status_message.connect(_on_status)
	controller.objective_pulse.connect(_pulse_progress)
	refresh(controller)


func refresh(controller: GameController) -> void:
	objective_label.text = controller.get_objective_text()
	progress_label.text = controller.get_progress_text()
	moves_label.text = str(controller.get_moves())
	score_label.text = str(controller.get_score())
	var target := controller.get_target()
	progress_bar.max_value = maxf(float(target), 1.0)
	progress_bar.value = float(controller.get_collected())


func _on_status(text: String) -> void:
	status_label.text = text
	status_label.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(1.6)
	tween.tween_property(status_label, "modulate:a", 0.35, 0.4)


func _pulse_progress() -> void:
	var tween := create_tween()
	tween.tween_property(progress_label, "scale", Vector2(1.15, 1.15), 0.1)
	tween.tween_property(progress_label, "scale", Vector2.ONE, 0.12)
