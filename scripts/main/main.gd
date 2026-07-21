extends Control
## Working match-3 gameplay host scene.
## Instances the board gameplay into GameplaySlot. Do not remove this boot path.

@onready var gameplay_slot: Control = $GameplaySlot


func _ready() -> void:
	var gameplay := load("res://scenes/gameplay/gameplay.tscn") as PackedScene
	if gameplay == null:
		push_error("Main: failed to load gameplay.tscn")
		return
	var instance := gameplay.instantiate()
	gameplay_slot.add_child(instance)
