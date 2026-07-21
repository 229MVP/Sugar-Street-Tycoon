class_name NotificationBadgeView
extends Control
## Circular coral notification badge.


var _label: Label
var _count: int = 0


func _ready() -> void:
	custom_minimum_size = Vector2(22, 22)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := Panel.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = SugarStreetColors.CORAL_PINK
	style.set_corner_radius_all(11)
	style.shadow_size = 2
	style.shadow_color = SugarStreetColors.SHADOW
	bg.add_theme_stylebox_override("panel", style)
	add_child(bg)
	_label = Label.new()
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 11)
	_label.add_theme_color_override("font_color", SugarStreetColors.WHITE)
	add_child(_label)
	visible = false


func set_count(count: int) -> void:
	_count = maxi(0, count)
	visible = _count > 0
	if _label:
		_label.text = str(mini(_count, 9)) if _count < 10 else "9+"
	if visible:
		UiMotion.badge_bounce(self)
