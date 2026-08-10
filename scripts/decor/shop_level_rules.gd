class_name ShopLevelRules
extends RefCounted
## Shop level 1–5 upgrade requirements and unlock summaries.


const MAX_SHOP_LEVEL := 5

## level -> {player_level, coins, reputation, appeal, unlocks_slots, unlocks_note}
const REQUIREMENTS := {
	2: {
		"player_level": 2,
		"coins": 1000,
		"reputation": 25,
		"appeal": 20,
		"slots": ["wall_right", "display_accent"],
		"note": "Unlocks Wall Right and Display Accent slots.",
	},
	3: {
		"player_level": 4,
		"coins": 2500,
		"reputation": 75,
		"appeal": 55,
		"slots": ["floor_center", "window"],
		"note": "Unlocks Floor Center and Window slots plus better flooring visuals.",
	},
	4: {
		"player_level": 6,
		"coins": 5000,
		"reputation": 150,
		"appeal": 100,
		"slots": ["lighting"],
		"note": "Unlocks Lighting and premium sign/lighting stage.",
	},
	5: {
		"player_level": 8,
		"coins": 10000,
		"reputation": 300,
		"appeal": 175,
		"slots": ["seating"],
		"note": "Unlocks Seating and luxury bakery interior stage.",
	},
}


static func requirements_for(next_level: int) -> Dictionary:
	return REQUIREMENTS.get(next_level, {}).duplicate(true)


static func can_upgrade(data: SaveData, appeal: int) -> Dictionary:
	var current := clampi(data.shop_level, 1, MAX_SHOP_LEVEL)
	if current >= MAX_SHOP_LEVEL:
		return {"ok": false, "reason": "Shop is already at maximum level.", "next_level": current}
	var next_level := current + 1
	var req: Dictionary = REQUIREMENTS[next_level]
	var reasons: PackedStringArray = []
	if data.player_level < int(req["player_level"]):
		reasons.append("Reach player level %d" % int(req["player_level"]))
	if data.coins < int(req["coins"]):
		reasons.append("Need %s coins" % RewardCalculator.format_coins(int(req["coins"])))
	if data.reputation < int(req["reputation"]):
		reasons.append("Need %d reputation" % int(req["reputation"]))
	if appeal < int(req["appeal"]):
		reasons.append("Need %d Appeal" % int(req["appeal"]))
	if not reasons.is_empty():
		return {
			"ok": false,
			"reason": " · ".join(reasons),
			"next_level": next_level,
			"requirements": req,
		}
	return {
		"ok": true,
		"reason": "",
		"next_level": next_level,
		"requirements": req,
		"cost": int(req["coins"]),
	}
