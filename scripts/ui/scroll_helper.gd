class_name ScrollHelper
extends RefCounted
## Touch-friendly ScrollContainer defaults for mobile screens.
## Hides scrollbar chrome while keeping drag-to-scroll. The deadzone is large
## enough to protect taps, but deliberately below the old 16 px value: on a
## phone that value made short thumb swipes feel as if the page were stuck.


const TOUCH_SCROLL_DEADZONE := 9


static func configure_vertical(scroll: ScrollContainer) -> void:
	if scroll == null:
		return
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.scroll_deadzone = TOUCH_SCROLL_DEADZONE
	# Let a nested horizontal chip row hand vertical wheel/trackpad scrolling
	# back to its outer vertical page instead of trapping the gesture.
	scroll.mouse_force_pass_scroll_events = true


static func configure_horizontal(scroll: ScrollContainer) -> void:
	if scroll == null:
		return
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.scroll_deadzone = TOUCH_SCROLL_DEADZONE
	scroll.mouse_force_pass_scroll_events = true
