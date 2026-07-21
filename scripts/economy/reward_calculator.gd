class_name RewardCalculator
extends RefCounted
## Applies equipment modifiers to order rewards.


static func oven_bonus_percent(level: int) -> float:
	return 0.02 * float(maxi(level - 1, 0))


static func mixer_bonus_percent(level: int) -> float:
	return 0.02 * float(maxi(level - 1, 0))


static func display_bonus_percent(level: int) -> float:
	return 0.02 * float(maxi(level - 1, 0))


static func checkout_bonus_percent(level: int) -> float:
	return 0.01 * float(maxi(level - 1, 0))


static func compute_order_rewards(template: OrderTemplate, data: SaveData) -> Dictionary:
	var oven := int(data.equipment_levels.get("oven", 1))
	var mixer := int(data.equipment_levels.get("mixer", 1))
	var display := int(data.equipment_levels.get("display_case", 1))
	var checkout := int(data.equipment_levels.get("checkout", 1))
	var checkout_mult := 1.0 + checkout_bonus_percent(checkout)

	var coins := int(round(float(template.coin_reward) * (1.0 + oven_bonus_percent(oven)) * checkout_mult))
	var xp := int(round(float(template.experience_reward) * (1.0 + mixer_bonus_percent(mixer)) * checkout_mult))
	var reputation := int(round(float(template.reputation_reward) * (1.0 + display_bonus_percent(display)) * checkout_mult))

	return {
		"coins": maxi(coins, 0),
		"experience": maxi(xp, 0),
		"reputation": maxi(reputation, 0),
		"ingredients": template.ingredient_rewards.duplicate(true),
	}


static func format_coins(amount: int) -> String:
	var n: int = absi(amount)
	var s: String = str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3, 3) + out
		s = s.substr(0, s.length() - 3)
	out = s + out
	if amount < 0:
		return "-" + out
	return out
