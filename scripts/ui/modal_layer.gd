class_name ModalLayer
extends CanvasLayer
## Full-viewport modal host above ordinary screen content and navigation.
## Guarantees popups are centered in the viewport (not a nav bar / VBox / scroll body),
## blocks input underneath, stacks modals, and consumes Android Back for the top modal.

const HOST_LAYER := 100

static var _instance: ModalLayer = null
var _stack: Array[Control] = []


func _enter_tree() -> void:
	layer = HOST_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_instance = self


func _exit_tree() -> void:
	if _instance == self:
		_instance = null


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if handle_back():
			get_viewport().set_input_as_handled()


static func ensure(tree: SceneTree = null) -> ModalLayer:
	if _instance != null and is_instance_valid(_instance):
		return _instance
	var host := ModalLayer.new()
	host.name = "ModalLayer"
	var root: Window = null
	if tree != null:
		root = tree.root
	elif Engine.get_main_loop() is SceneTree:
		root = (Engine.get_main_loop() as SceneTree).root
	if root == null:
		push_error("ModalLayer: no SceneTree root available")
		return host
	# Autoload _ready can run while the root is still wiring children.
	if root.is_node_ready():
		root.add_child(host)
	else:
		root.call_deferred("add_child", host)
	_instance = host
	return host


## Present a modal as a full-viewport child of the host. Reparents if needed.
static func present(modal: Control) -> void:
	if modal == null:
		return
	var host := ensure(modal.get_tree() if modal.is_inside_tree() else null)
	if host == null:
		return
	host._present(modal)


static func dismiss(modal: Control) -> void:
	if _instance == null or not is_instance_valid(_instance):
		return
	_instance._dismiss(modal)


static func handle_back_static() -> bool:
	if _instance == null or not is_instance_valid(_instance):
		return false
	return _instance.handle_back()


func _present(modal: Control) -> void:
	if modal.get_parent() != self:
		var previous := modal.get_parent()
		if previous != null:
			previous.remove_child(modal)
		add_child(modal)
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.offset_left = 0
	modal.offset_top = 0
	modal.offset_right = 0
	modal.offset_bottom = 0
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	modal.visible = true
	modal.move_to_front()
	# Drop earlier entries of the same modal so the stack stays unique.
	_stack.erase(modal)
	_stack.append(modal)


func _dismiss(modal: Control) -> void:
	_stack.erase(modal)
	if modal != null and is_instance_valid(modal):
		modal.visible = false


func handle_back() -> bool:
	## Close the topmost visible modal. Returns true when Back was consumed.
	_prune_stack()
	if _stack.is_empty():
		return false
	var top: Control = _stack[_stack.size() - 1]
	_stack.pop_back()
	if top.has_method("hide_popup"):
		top.call("hide_popup")
	else:
		top.visible = false
	return true


func top_modal() -> Control:
	_prune_stack()
	if _stack.is_empty():
		return null
	return _stack[_stack.size() - 1]


func has_open_modal() -> bool:
	_prune_stack()
	return not _stack.is_empty()


func _prune_stack() -> void:
	var kept: Array[Control] = []
	for modal in _stack:
		if modal != null and is_instance_valid(modal) and modal.visible:
			kept.append(modal)
	_stack = kept
