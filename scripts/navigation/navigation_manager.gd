class_name NavigationManager
extends Node
## Centralized scene paths and navigation for Sugar Street Tycoon.
## Registered as Autoload alias via SceneRouter wrapping, or used directly.

const TITLE := "res://scenes/main/title_screen.tscn"
const SHOP := "res://scenes/shop/shop_hub.tscn"
const ORDERS := "res://scenes/orders/orders_screen.tscn"
const GAMEPLAY := "res://scenes/main/main.tscn"
const INVENTORY := "res://scenes/inventory/inventory_screen.tscn"
const RECIPE_BOOK := "res://scenes/recipes/recipe_book.tscn"
const UPGRADES := "res://scenes/upgrades/upgrade_shop.tscn"


static func go(path: String) -> void:
	SceneRouter.go_path(path)


static func go_title() -> void:
	SceneRouter.go_title()


static func go_shop() -> void:
	SceneRouter.go_shop()


static func go_orders() -> void:
	SceneRouter.go_orders()


static func go_inventory() -> void:
	SceneRouter.go_inventory()


static func start_order(order_id: String) -> void:
	SceneRouter.start_order_level(order_id)


static func return_from_level() -> void:
	SceneRouter.return_to_shop_from_level()
