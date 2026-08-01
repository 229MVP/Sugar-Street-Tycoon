class_name WorkerDefinition
extends Resource
## Data-driven worker definition. Runtime hire/level/assignment state lives in
## SaveData (hired_workers / worker_levels / worker_assignments), mirroring the
## legacy WorkerData contract so the existing WorkerManager rules engine and
## worker roster UI keep working without a rewrite.

enum Role { BAKER, MIXER_SPECIALIST, CASHIER, DISPLAY_DECORATOR, ORDER_COORDINATOR, STORE_MANAGER }
enum Rarity { COMMON, UNCOMMON, RARE, PREMIUM }
enum Station { NONE, OVEN, MIXER, CHECKOUT, DISPLAY_CASE, ORDER_DESK, MANAGER }

const MAX_LEVEL := 10

## Stable string id used as the save-file key. Never change once shipped.
@export var id: String = ""
@export var display_name: String = ""
@export var role: Role = Role.BAKER
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var icon_path: String = ""
@export var portrait_color: Color = Color(0.9, 0.7, 0.75, 1)
@export var body_color: Color = Color(0.85, 0.55, 0.6, 1)
@export var rarity: Rarity = Rarity.COMMON
@export var unlock_player_level: int = 1
@export var unlock_reputation: int = 0
@export var hire_cost: int = 300
@export var compatible_station: Station = Station.OVEN
@export var available_at_start: bool = false
## Primary bonus type key used by WorkerBonusCalculator (e.g. "order_coins").
@export var primary_bonus_type: String = "order_coins"
@export var primary_bonus_per_level: float = 0.03
@export var primary_bonus_base: float = 0.0
@export var secondary_bonus_type: String = ""
@export var secondary_bonus_per_level: float = 0.0


func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	if id.strip_edges() == "":
		errors.append("WorkerDefinition: id is required")
	if display_name.strip_edges() == "":
		errors.append("WorkerDefinition '%s': display_name is required" % id)
	if hire_cost < 0:
		errors.append("WorkerDefinition '%s': hire_cost cannot be negative" % id)
	if compatible_station == Station.NONE:
		errors.append("WorkerDefinition '%s': compatible_station is required" % id)
	return errors


func rarity_multiplier() -> float:
	match rarity:
		Rarity.COMMON: return 1.0
		Rarity.UNCOMMON: return 1.2
		Rarity.RARE: return 1.5
		Rarity.PREMIUM: return 2.0
	return 1.0


## Bridge to the legacy WorkerData resource used by WorkerManager / roster UI.
func to_worker_data() -> WorkerData:
	var data := WorkerData.new()
	data.worker_id = StringName(id)
	data.display_name = display_name
	match role:
		Role.BAKER: data.role = WorkerData.Role.BAKER
		Role.MIXER_SPECIALIST: data.role = WorkerData.Role.MIXER_SPECIALIST
		Role.CASHIER: data.role = WorkerData.Role.CASHIER
		Role.DISPLAY_DECORATOR: data.role = WorkerData.Role.DISPLAY_DECORATOR
		Role.ORDER_COORDINATOR: data.role = WorkerData.Role.ORDER_COORDINATOR
		Role.STORE_MANAGER: data.role = WorkerData.Role.STORE_MANAGER
	data.description = description
	data.portrait_color = portrait_color
	data.body_color = body_color
	match rarity:
		Rarity.COMMON: data.rarity = WorkerData.Rarity.COMMON
		Rarity.UNCOMMON: data.rarity = WorkerData.Rarity.UNCOMMON
		Rarity.RARE: data.rarity = WorkerData.Rarity.RARE
		Rarity.PREMIUM: data.rarity = WorkerData.Rarity.PREMIUM
	data.unlock_player_level = unlock_player_level
	data.unlock_reputation = unlock_reputation
	data.hire_cost = hire_cost
	match compatible_station:
		Station.OVEN: data.compatible_station = WorkerData.Station.OVEN
		Station.MIXER: data.compatible_station = WorkerData.Station.MIXER
		Station.CHECKOUT: data.compatible_station = WorkerData.Station.CHECKOUT
		Station.DISPLAY_CASE: data.compatible_station = WorkerData.Station.DISPLAY_CASE
		Station.ORDER_DESK: data.compatible_station = WorkerData.Station.ORDER_DESK
		Station.MANAGER: data.compatible_station = WorkerData.Station.MANAGER
		_: data.compatible_station = WorkerData.Station.NONE
	data.available_at_start = available_at_start
	data.primary_bonus_type = StringName(primary_bonus_type)
	data.primary_bonus_per_level = primary_bonus_per_level
	data.primary_bonus_base = primary_bonus_base
	data.secondary_bonus_type = StringName(secondary_bonus_type)
	data.secondary_bonus_per_level = secondary_bonus_per_level
	return data
