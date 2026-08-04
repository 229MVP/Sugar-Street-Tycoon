class_name DebugPanel
extends Control
## Development-only panel. Toggle with ` (backtick) or the Debug button.

signal print_board
signal restart
signal check_moves
signal add_moves
signal add_objective
signal reshuffle

@onready var panel: PanelContainer = %Panel


func _ready() -> void:
	visible = false
	if not BuildConfig.debug_features_enabled():
		# Never reachable in a release/TestFlight build, even via a Bluetooth
		# keyboard sending the debug_toggle_panel action.
		set_process_unhandled_input(false)
		return
	%PrintBoardButton.pressed.connect(func(): print_board.emit())
	%RestartButton.pressed.connect(func(): restart.emit())
	%CheckMovesButton.pressed.connect(func(): check_moves.emit())
	%AddMovesButton.pressed.connect(func(): add_moves.emit())
	%AddObjectiveButton.pressed.connect(func(): add_objective.emit())
	%ReshuffleButton.pressed.connect(func(): reshuffle.emit())
	%CloseButton.pressed.connect(hide_panel)


func _unhandled_input(event: InputEvent) -> void:
	if not BuildConfig.debug_features_enabled():
		return
	if event.is_action_pressed("debug_toggle_panel"):
		toggle()


func toggle() -> void:
	if visible:
		hide_panel()
	else:
		show_panel()


func show_panel() -> void:
	visible = true


func hide_panel() -> void:
	visible = false
