extends Control
## Boot scene — loads the gameplay prototype.
## Later this can become a title / shop hub screen.

@onready var gameplay_slot: Control = $GameplaySlot


func _ready() -> void:
	var gameplay := load("res://scenes/gameplay/gameplay.tscn") as PackedScene
	if gameplay == null:
		push_error("Main: failed to load gameplay.tscn")
		return
	var instance := gameplay.instantiate()
	gameplay_slot.add_child(instance)
