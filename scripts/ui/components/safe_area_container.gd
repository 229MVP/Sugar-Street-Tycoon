class_name SafeAreaContainer
extends MarginContainer
## Drop-in replacement for a plain MarginContainer that additionally keeps
## content clear of device notches / home-indicator safe areas (iPhone
## Dynamic Island, rounded corners, etc.) on top of a configurable minimum
## padding. On desktop/editor/headless (or any device without an inset
## safe-area, i.e. most Android phones), the extra inset is zero and this
## behaves exactly like a normal MarginContainer with the min_margin_* values.

@export var min_margin_left: int = 12
@export var min_margin_right: int = 12
@export var min_margin_top: int = 10
@export var min_margin_bottom: int = 8


func _ready() -> void:
	_apply_safe_margins()
	var vp := get_viewport()
	if vp and not vp.size_changed.is_connected(_apply_safe_margins):
		vp.size_changed.connect(_apply_safe_margins)


func set_min_margins(left: int, top: int, right: int, bottom: int) -> void:
	min_margin_left = left
	min_margin_top = top
	min_margin_right = right
	min_margin_bottom = bottom
	_apply_safe_margins()


func _apply_safe_margins() -> void:
	var insets := _get_safe_area_insets()
	add_theme_constant_override("margin_left", min_margin_left + int(insets.x))
	add_theme_constant_override("margin_top", min_margin_top + int(insets.y))
	add_theme_constant_override("margin_right", min_margin_right + int(insets.z))
	add_theme_constant_override("margin_bottom", min_margin_bottom + int(insets.w))


## Returns (left, top, right, bottom) safe-area inset in this viewport's
## logical/scaled pixels. Falls back to all-zero when safe-area info isn't
## available (desktop, editor, headless, unsupported platforms).
func _get_safe_area_insets() -> Vector4:
	if not is_inside_tree():
		return Vector4.ZERO
	var screen_rect := DisplayServer.screen_get_usable_rect()
	var safe_rect := DisplayServer.get_display_safe_area()
	if screen_rect.size.x <= 0 or screen_rect.size.y <= 0 or safe_rect.size.x <= 0:
		return Vector4.ZERO
	var vp := get_viewport()
	if vp == null:
		return Vector4.ZERO
	var vp_size := vp.get_visible_rect().size
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		return Vector4.ZERO
	var scale_x := vp_size.x / float(screen_rect.size.x)
	var scale_y := vp_size.y / float(screen_rect.size.y)
	var left := float(safe_rect.position.x - screen_rect.position.x) * scale_x
	var top := float(safe_rect.position.y - screen_rect.position.y) * scale_y
	var right := float((screen_rect.position.x + screen_rect.size.x) - (safe_rect.position.x + safe_rect.size.x)) * scale_x
	var bottom := float((screen_rect.position.y + screen_rect.size.y) - (safe_rect.position.y + safe_rect.size.y)) * scale_y
	return Vector4(maxf(left, 0.0), maxf(top, 0.0), maxf(right, 0.0), maxf(bottom, 0.0))
