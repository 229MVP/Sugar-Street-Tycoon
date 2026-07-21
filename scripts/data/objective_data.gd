class_name ObjectiveData
extends Resource
## A single collect-style objective for a level.

@export var piece_id: StringName = &"strawberry"
@export var target_amount: int = 20
@export var description: String = "Collect strawberries"


func is_valid() -> bool:
	return piece_id != StringName() and target_amount > 0
