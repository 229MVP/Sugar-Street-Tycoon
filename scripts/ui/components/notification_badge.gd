class_name NotificationBadge
extends Control
## Small reusable red badge with optional count.

var _label: Label
var _bg: ColorRect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(22, 22)
	_bg = ColorRect.new()
	_bg.color = Color(0.9, 0.25, 0.35, 1)
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.add_theme_font_size_override("font_size", 12)
	_label.add_theme_color_override("font_color", Color.WHITE)
	add_child(_label)
	visible = false


func set_count(count: int) -> void:
	if count <= 0:
		visible = false
		return
	visible = true
	_label.text = str(mini(count, 99))
