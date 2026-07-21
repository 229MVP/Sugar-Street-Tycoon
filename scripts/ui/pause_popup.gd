class_name PausePopup
extends Control

signal resume_pressed
signal restart_pressed

@onready var panel: PanelContainer = %Panel
@onready var resume_button: Button = %ResumeButton
@onready var restart_button: Button = %RestartButton


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	resume_button.pressed.connect(func(): resume_pressed.emit())
	restart_button.pressed.connect(func(): restart_pressed.emit())


func show_pause() -> void:
	visible = true
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.15)


func hide_popup() -> void:
	visible = false
