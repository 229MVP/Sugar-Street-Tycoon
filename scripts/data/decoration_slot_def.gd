class_name DecorationSlotDef
extends RefCounted
## Fixed shop decoration slot definition.

var slot_id: StringName = &""
var display_name: String = ""
var slot_type: StringName = &""
var required_shop_level: int = 1
var compatible_categories: Array = []
## Normalized shop-preview anchors (0..1).
var anchor_pos: Vector2 = Vector2(0.1, 0.1)
var anchor_size: Vector2 = Vector2(0.2, 0.12)


func _init(
	p_id: StringName = &"",
	p_name: String = "",
	p_type: StringName = &"",
	p_level: int = 1,
	p_categories: Array = [],
	p_pos: Vector2 = Vector2(0.1, 0.1),
	p_size: Vector2 = Vector2(0.2, 0.12)
) -> void:
	slot_id = p_id
	display_name = p_name
	slot_type = p_type
	required_shop_level = p_level
	compatible_categories = p_categories.duplicate()
	anchor_pos = p_pos
	anchor_size = p_size
