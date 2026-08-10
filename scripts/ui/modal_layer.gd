class_name ModalLayer
extends CanvasLayer
## Full-viewport modal host above ordinary screen content and navigation.
## Guarantees popups are centered in the viewport (not a nav bar / VBox / scroll body),
## blocks input underneath, stacks modals, and consumes Android Back for the top modal.

const HOST_LAYER := 100

static var _instance: ModalLayer = null
static var _shared_theme: Theme = null
var _stack: Array[Control] = []


func _enter_tree() -> void:
	layer = HOST_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_instance = self


## CanvasLayer breaks Control theme inheritance (it isn't a Control ancestor),
## so anything reparented here would otherwise silently fall back to Godot's
## bare default theme — plain white/gray panels, visible scrollbar chrome,
## and washed-out toggle/slider chrome. Every presented modal gets the app
## theme directly so it always matches the rest of the game.
static func _app_theme() -> Theme:
	if _shared_theme == null:
		_shared_theme = ThemeFactory.build()
	return _shared_theme


func _exit_tree() -> void:
	if _instance == self:
		_instance = null


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


static func clear_all_static() -> void:
	if _instance == null or not is_instance_valid(_instance):
		return
	_instance.clear_all()


func _present(modal: Control) -> void:
	if modal.get_parent() != self:
		var previous := modal.get_parent()
		if previous != null:
			previous.remove_child(modal)
		add_child(modal)
	if modal.theme == null:
		modal.theme = _app_theme()
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
	if top.has_method("request_close_from_back"):
		top.call("request_close_from_back")
	elif top.has_method("hide_popup"):
		top.call("hide_popup")
	else:
		top.visible = false
	return true


## Presented controls are reparented under this persistent host. A scene
## transition must remove them explicitly or a visible full-screen scrim can
## outlive its source scene and cover the next screen.
func clear_all() -> void:
	_stack.clear()
	for child in get_children():
		if child is CanvasItem:
			(child as CanvasItem).visible = false
		child.queue_free()


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
