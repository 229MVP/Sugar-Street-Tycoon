class_name PieceType
extends Resource
## Defines a dessert piece type. Swap the texture later without changing board logic.

@export var id: StringName = &""
@export var display_name: String = ""
@export var color: Color = Color.WHITE
@export var texture: Texture2D
## Optional short label drawn when texture is missing (editor/dev fallback).
@export var fallback_label: String = ""


func is_valid() -> bool:
	return id != StringName() and not display_name.is_empty()
