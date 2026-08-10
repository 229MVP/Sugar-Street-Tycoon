class_name UpgradeDefinition
extends Resource
## Shop upgrade definition. Current level persists in SaveData.upgrade_levels.
## Upgrades linked to legacy equipment (oven/mixer/display_case/cash_register)
## mirror their level into SaveData.equipment_levels so RewardCalculator keeps
## working without modification. Décor and Lighting are new, standalone effects.

enum EffectType {
	BAKING_SPEED,
	BATCH_SIZE,
	COIN_REWARDS,
	TRANSACTION_SPEED,
	TIP_BONUS,
	STAR_REWARD_BONUS,
}

## Stable string id used as the save-file key. Never change once shipped.
@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var effect_type: EffectType = EffectType.COIN_REWARDS
@export var icon: Texture2D
@export var icon_path: String = ""
@export var fallback_color: Color = Color(0.78, 0.62, 0.48, 1)
@export var max_level: int = 5
@export var starting_level: int = 1
@export var base_cost: int = 500
@export var cost_growth: float = 2.0
@export var effect_per_level: float = 0.02 ## Fraction (percent bonus) applied per level above 1.
## Optional sync target in SaveData.equipment_levels (legacy RewardCalculator input).
@export var linked_equipment_id: String = ""


func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	if id.strip_edges() == "":
		errors.append("UpgradeDefinition: id is required")
	if display_name.strip_edges() == "":
		errors.append("UpgradeDefinition '%s': display_name is required" % id)
	if max_level < 1:
		errors.append("UpgradeDefinition '%s': max_level must be >= 1" % id)
	if starting_level < 1 or starting_level > max_level:
		errors.append("UpgradeDefinition '%s': starting_level out of range" % id)
	if base_cost < 0:
		errors.append("UpgradeDefinition '%s': base_cost cannot be negative" % id)
	return errors


## Coin cost to purchase the step that brings the upgrade to `next_level`.
func cost_to_reach(next_level: int) -> int:
	if next_level <= starting_level or next_level > max_level:
		return 0
	var tier := next_level - starting_level
	return int(round(float(base_cost) * pow(cost_growth, float(tier - 1))))


## Effect magnitude at a given level, expressed as a fraction (e.g. 0.06 = +6%).
func effect_at_level(level: int) -> float:
	return effect_per_level * float(maxi(level - 1, 0))


func effect_label() -> String:
	match effect_type:
		EffectType.BAKING_SPEED: return "Baking speed"
		EffectType.BATCH_SIZE: return "Batch size"
		EffectType.COIN_REWARDS: return "Coin rewards"
		EffectType.TRANSACTION_SPEED: return "Transaction speed"
		EffectType.TIP_BONUS: return "Tip bonus"
		EffectType.STAR_REWARD_BONUS: return "Star reward bonus"
	return "Upgrade"
