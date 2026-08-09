class_name ScrollHelper
extends RefCounted
## Touch-friendly ScrollContainer defaults for mobile screens.
## Hides scrollbar chrome while keeping drag-to-scroll; raises deadzone so
## small taps on child buttons are not misread as scroll gestures.


static func configure_vertical(scroll: ScrollContainer) -> void:
	if scroll == null:
		return
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.scroll_deadzone = 16


static func configure_horizontal(scroll: ScrollContainer) -> void:
	if scroll == null:
		return
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.scroll_deadzone = 16
