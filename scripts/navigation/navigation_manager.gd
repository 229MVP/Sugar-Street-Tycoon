class_name NavigationManager
extends RefCounted
## Centralized scene paths and navigation for Sugar Street Tycoon.

const TITLE := "res://scenes/main/title_screen.tscn"
const SHOP := "res://scenes/shop/shop_hub.tscn"
const ORDERS := "res://scenes/orders/orders_screen.tscn"
const GAMEPLAY := "res://scenes/main/main.tscn"
const INVENTORY := "res://scenes/inventory/inventory_screen.tscn"
const RECIPE_BOOK := "res://scenes/recipes/recipe_book.tscn"
const UPGRADES := "res://scenes/upgrades/upgrades_screen.tscn"


static func go(path: String) -> void:
	SceneRouter.go_path(path)


static func go_to_title() -> void:
	SceneRouter.go_title()


static func go_title() -> void:
	go_to_title()


static func go_to_shop() -> void:
	SceneRouter.go_shop()


static func go_shop() -> void:
	go_to_shop()


static func go_to_orders() -> void:
	SceneRouter.go_orders()


static func go_orders() -> void:
	go_to_orders()


static func go_to_gameplay() -> void:
	SceneRouter.go_to_gameplay()


static func go_to_recipes() -> void:
	SceneRouter.go_recipe_book()


static func go_to_upgrades() -> void:
	SceneRouter.go_upgrades()


static func go_to_inventory() -> void:
	SceneRouter.go_inventory()


static func go_inventory() -> void:
	go_to_inventory()


static func reload_current_level() -> void:
	SceneRouter.reload_current_level()


static func start_order(order_id: String) -> void:
	SceneRouter.start_order_level(order_id)


static func return_from_level() -> void:
	SceneRouter.return_to_shop_from_level()
