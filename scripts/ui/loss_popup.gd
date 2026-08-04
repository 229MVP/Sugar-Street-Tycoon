class_name LossPopup
extends Control
## Shown when moves run out before the objective is met.

signal replay_pressed
signal exit_pressed

@onready var panel: PanelContainer = %Panel
@onready var progress_label: Label = %ProgressLabel
@onready var replay_button: Button = %ReplayButton
@onready var exit_button: Button = %ExitButton

var _busy: bool = false


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	replay_button.pressed.connect(_on_replay)
	exit_button.pressed.connect(_on_exit)


func _on_replay() -> void:
	if _busy:
		return
	_busy = true
	replay_button.disabled = true
	replay_pressed.emit()


func _on_exit() -> void:
	if _busy:
		return
	_busy = true
	exit_button.disabled = true
	exit_pressed.emit()


func show_result(progress_text: String) -> void:
	_busy = false
	replay_button.disabled = false
	exit_button.disabled = false
	progress_label.text = "Progress: %s" % progress_text
	if exit_button:
		exit_button.text = "Return to Shop" if SceneRouter.pending_order_id != "" else "Exit"
	visible = true
	modulate.a = 0.0
	panel.scale = Vector2(0.85, 0.85)
	panel.pivot_offset = panel.size * 0.5
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.2)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	AudioManager.play_popup()


func hide_popup() -> void:
	visible = false
