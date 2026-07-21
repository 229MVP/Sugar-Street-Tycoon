class_name WorkerData
extends Resource
## Static worker definition. Runtime hire/level/assignment live in SaveData.

enum Role {
	BAKER,
	MIXER_SPECIALIST,
	CASHIER,
	DISPLAY_DECORATOR,
	ORDER_COORDINATOR,
	STORE_MANAGER,
}

enum Rarity { COMMON, UNCOMMON, RARE, PREMIUM }

enum Station {
	NONE,
	OVEN,
	MIXER,
	CHECKOUT,
	DISPLAY_CASE,
	ORDER_DESK,
	MANAGER,
}

const MAX_LEVEL := 10

@export var worker_id: StringName = &""
@export var display_name: String = ""
@export var role: Role = Role.BAKER
@export_multiline var description: String = ""
@export var portrait_color: Color = Color(0.9, 0.7, 0.75, 1)
@export var body_color: Color = Color(0.85, 0.55, 0.6, 1)
@export var rarity: Rarity = Rarity.COMMON
@export var unlock_player_level: int = 1
@export var unlock_reputation: int = 0
@export var unlock_equipment_id: StringName = &""
@export var unlock_equipment_level: int = 0
@export var unlock_recipe_id: StringName = &""
@export var hire_cost: int = 300
@export var compatible_station: Station = Station.OVEN
@export var available_at_start: bool = false
## Primary bonus type key used by WorkerBonusCalculator.
@export var primary_bonus_type: StringName = &"order_coins"
@export var primary_bonus_per_level: float = 0.03
@export var primary_bonus_base: float = 0.0
@export var secondary_bonus_type: StringName = &""
@export var secondary_bonus_per_level: float = 0.0


func role_label() -> String:
	match role:
		Role.BAKER: return "Baker"
		Role.MIXER_SPECIALIST: return "Mixer Specialist"
		Role.CASHIER: return "Cashier"
		Role.DISPLAY_DECORATOR: return "Display Decorator"
		Role.ORDER_COORDINATOR: return "Order Coordinator"
		Role.STORE_MANAGER: return "Store Manager"
	return "Worker"


func rarity_label() -> String:
	match rarity:
		Rarity.COMMON: return "Common"
		Rarity.UNCOMMON: return "Uncommon"
		Rarity.RARE: return "Rare"
		Rarity.PREMIUM: return "Premium"
	return "Common"


func rarity_multiplier() -> float:
	match rarity:
		Rarity.COMMON: return 1.0
		Rarity.UNCOMMON: return 1.2
		Rarity.RARE: return 1.5
		Rarity.PREMIUM: return 2.0
	return 1.0


func station_label() -> String:
	return WorkerData.station_to_label(compatible_station)


static func station_to_label(station: Station) -> String:
	match station:
		Station.OVEN: return "Oven"
		Station.MIXER: return "Mixer"
		Station.CHECKOUT: return "Checkout Counter"
		Station.DISPLAY_CASE: return "Display Case"
		Station.ORDER_DESK: return "Order Desk"
		Station.MANAGER: return "Manager Station"
	return "Unassigned"


static func station_from_string(value: String) -> Station:
	match value:
		"oven": return Station.OVEN
		"mixer": return Station.MIXER
		"checkout": return Station.CHECKOUT
		"display_case": return Station.DISPLAY_CASE
		"order_desk": return Station.ORDER_DESK
		"manager": return Station.MANAGER
	return Station.NONE


static func station_to_string(station: Station) -> String:
	match station:
		Station.OVEN: return "oven"
		Station.MIXER: return "mixer"
		Station.CHECKOUT: return "checkout"
		Station.DISPLAY_CASE: return "display_case"
		Station.ORDER_DESK: return "order_desk"
		Station.MANAGER: return "manager"
	return ""


static func base_upgrade_cost(to_level: int) -> int:
	match to_level:
		2: return 250
		3: return 400
		4: return 650
		5: return 1000
		6: return 1500
		7: return 2200
		8: return 3000
		9: return 4000
		10: return 5500
	return 0


func upgrade_cost(from_level: int) -> int:
	var next := from_level + 1
	if next > MAX_LEVEL:
		return 0
	return int(round(float(base_upgrade_cost(next)) * rarity_multiplier()))
