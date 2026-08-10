class_name NotificationBadgeView
extends Control
## Circular coral notification badge.


var _label: Label
var _count: int = 0


const BASE_SIZE := 22.0


func _ready() -> void:
	custom_minimum_size = Vector2(BASE_SIZE, BASE_SIZE)
	# Badge overlays must never intercept taps meant for the button/card
	# underneath them.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := Panel.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = SugarStreetColors.CORAL_PINK
	style.set_corner_radius_all(11)
	style.shadow_size = 2
	style.shadow_color = SugarStreetColors.SHADOW
	bg.add_theme_stylebox_override("panel", style)
	add_child(bg)
	_label = Label.new()
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.clip_text = false
	_label.add_theme_font_size_override("font_size", 11)
	_label.add_theme_color_override("font_color", SugarStreetColors.WHITE)
	add_child(_label)
	visible = false


## Anchors this badge to the top-right corner of its parent, regardless of
## the parent's width — a dedicated corner overlay so it never lands on top
## of left/center-aligned icon or title text.
func place_top_right(margin: float = 4.0) -> void:
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_right = -margin
	offset_left = offset_right - custom_minimum_size.x
	offset_top = margin
	offset_bottom = offset_top + custom_minimum_size.y


func set_count(count: int) -> void:
	_count = maxi(0, count)
	visible = _count > 0
	var text := "99+" if _count > 99 else str(_count)
	if _label:
		_label.text = text
	# Widen from a circle into a pill as the label grows past one digit so
	# "10" and "99+" stay fully inside the badge and centered, never clipped.
	var width := BASE_SIZE
	if text.length() == 2:
		width = 28.0
	elif text.length() >= 3:
		width = 34.0
	custom_minimum_size = Vector2(width, BASE_SIZE)
	size = custom_minimum_size
	if anchor_left == 1.0 and anchor_right == 1.0:
		place_top_right(-offset_right if offset_right < 0.0 else 4.0)
	if visible:
		UiMotion.badge_bounce(self)
