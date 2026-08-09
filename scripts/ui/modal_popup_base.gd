class_name ModalPopupBase
extends Control
## Shared full-viewport modal root helpers. Popups should call
## prepare_fullscreen_root() in _ready and present_modal()/dismiss_modal()
## when showing/hiding so they never inherit nav-bar or scroll-body bounds.


func prepare_fullscreen_root() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0


func present_modal() -> void:
	prepare_fullscreen_root()
	ModalLayer.present(self)


func dismiss_modal() -> void:
	ModalLayer.dismiss(self)
	visible = false
