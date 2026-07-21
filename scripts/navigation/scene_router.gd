extends Node
## Central scene navigation for the app shell.

const TITLE_SCENE := "res://scenes/main/title_screen.tscn"
const SHOP_SCENE := "res://scenes/shop/shop_hub.tscn"
const ORDERS_SCENE := "res://scenes/orders/orders_screen.tscn"
const GAMEPLAY_SCENE := "res://scenes/main/main.tscn"
const RECIPE_BOOK_SCENE := "res://scenes/recipes/recipe_book.tscn"
const UPGRADE_SCENE := "res://scenes/upgrades/upgrade_shop.tscn"
const INVENTORY_SCENE := "res://scenes/inventory/inventory_screen.tscn"
const WORKER_ROSTER_SCENE := "res://scenes/workers/worker_roster.tscn"

signal scene_changed(path: String)

var current_path: String = ""
var pending_order_id: String = ""
var pending_level_config: LevelConfig = null
var return_after_level_path: String = ORDERS_SCENE


func go_path(path: String) -> void:
	_change(path)


func go_title() -> void:
	_change(TITLE_SCENE)


func go_shop() -> void:
	pending_order_id = ""
	pending_level_config = null
	_change(SHOP_SCENE)


func go_orders() -> void:
	_change(ORDERS_SCENE)


func go_recipe_book() -> void:
	_change(RECIPE_BOOK_SCENE)


func go_upgrades() -> void:
	_change(UPGRADE_SCENE)


func go_inventory() -> void:
	_change(INVENTORY_SCENE)


func go_workers() -> void:
	# Workers are Coming Soon in this UI phase.
	push_warning("SceneRouter: workers screen gated as Coming Soon")


func start_order_level(order_id: String) -> void:
	var level := GameState.begin_order_level(order_id)
	if level == null:
		push_error("SceneRouter: could not begin order '%s'" % order_id)
		return
	pending_order_id = order_id
	pending_level_config = level
	return_after_level_path = ORDERS_SCENE
	AudioManager.play(AudioManager.Sfx.ORDER_SELECTED)
	_change(GAMEPLAY_SCENE)


func return_to_shop_from_level() -> void:
	pending_level_config = null
	var target := return_after_level_path if return_after_level_path != "" else ORDERS_SCENE
	_change(target)


func _change(path: String) -> void:
	current_path = path
	scene_changed.emit(path)
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("SceneRouter: failed to change to %s (error %s)" % [path, str(err)])
