class_name PausePopup
extends Control

signal resume_pressed
signal restart_pressed
signal give_up_pressed

@onready var panel: PanelContainer = %Panel
@onready var resume_button: Button = %ResumeButton
@onready var restart_button: Button = %RestartButton

var _give_up_button: Button
var _busy: bool = false


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	resume_button.pressed.connect(_on_resume)
	restart_button.pressed.connect(_on_restart)
	if _give_up_button == null:
		_give_up_button = Button.new()
		_give_up_button.name = "GiveUpButton"
		_give_up_button.text = "Give Up (Return to Shop)"
		_give_up_button.custom_minimum_size = Vector2(0, 44)
		panel.get_node("VBox").add_child(_give_up_button)
	_give_up_button.pressed.connect(_on_give_up)


func show_pause() -> void:
	_busy = false
	resume_button.disabled = false
	restart_button.disabled = false
	_give_up_button.disabled = false
	visible = true
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.15)


func hide_popup() -> void:
	visible = false


func _on_resume() -> void:
	if _busy:
		return
	_busy = true
	resume_pressed.emit()


func _on_restart() -> void:
	if _busy:
		return
	_busy = true
	restart_button.disabled = true
	restart_pressed.emit()


func _on_give_up() -> void:
	if _busy:
		return
	_busy = true
	_give_up_button.disabled = true
	give_up_pressed.emit()
