class_name ShopAppealCalculator
extends RefCounted
## Appeal totals, tiers, and order reputation bonus from placed decorations.


const TIER_THRESHOLDS := [
	{"name": "Plain", "min": 0},
	{"name": "Cozy", "min": 25},
	{"name": "Charming", "min": 60},
	{"name": "Popular", "min": 110},
	{"name": "Premium", "min": 175},
	{"name": "Iconic", "min": 250},
]

const REP_BONUS_PER_APPEAL_BLOCK := 25
const MAX_REP_BONUS_PERCENT := 0.10


static func calculate_appeal(catalog: DecorationCatalog, placed: Dictionary) -> int:
	var total := 0
	for slot_id in placed.keys():
		var decor_id := str(placed[slot_id])
		if decor_id == "" or decor_id == "null":
			continue
		var decor: DecorationData = catalog.get_decoration(StringName(decor_id))
		if decor:
			total += maxi(0, decor.appeal_value)
	return total


static func tier_name(appeal: int) -> String:
	var name := "Plain"
	for tier in TIER_THRESHOLDS:
		if appeal >= int(tier["min"]):
			name = str(tier["name"])
	return name


static func tier_index(appeal: int) -> int:
	var idx := 0
	for i in TIER_THRESHOLDS.size():
		if appeal >= int(TIER_THRESHOLDS[i]["min"]):
			idx = i
	return idx


static func next_tier_info(appeal: int) -> Dictionary:
	var idx := tier_index(appeal)
	if idx >= TIER_THRESHOLDS.size() - 1:
		return {
			"current": tier_name(appeal),
			"next": "",
			"needed": 0,
			"progress": 1.0,
			"current_min": int(TIER_THRESHOLDS[idx]["min"]),
			"next_min": int(TIER_THRESHOLDS[idx]["min"]),
		}
	var cur_min := int(TIER_THRESHOLDS[idx]["min"])
	var next_min := int(TIER_THRESHOLDS[idx + 1]["min"])
	var span := maxi(1, next_min - cur_min)
	var progress := clampf(float(appeal - cur_min) / float(span), 0.0, 1.0)
	return {
		"current": str(TIER_THRESHOLDS[idx]["name"]),
		"next": str(TIER_THRESHOLDS[idx + 1]["name"]),
		"needed": maxi(0, next_min - appeal),
		"progress": progress,
		"current_min": cur_min,
		"next_min": next_min,
	}


static func reputation_bonus_percent(appeal: int) -> float:
	var blocks := int(floor(float(maxi(appeal, 0)) / float(REP_BONUS_PER_APPEAL_BLOCK)))
	return minf(float(blocks) * 0.01, MAX_REP_BONUS_PERCENT)


static func top_contributors(catalog: DecorationCatalog, placed: Dictionary, limit: int = 3) -> Array:
	var rows: Array = []
	for slot_id in placed.keys():
		var decor_id := str(placed[slot_id])
		var decor: DecorationData = catalog.get_decoration(StringName(decor_id))
		if decor == null:
			continue
		rows.append({
			"slot_id": str(slot_id),
			"decoration_id": str(decor.decoration_id),
			"name": decor.display_name,
			"appeal": decor.appeal_value,
		})
	rows.sort_custom(func(a, b): return int(a["appeal"]) > int(b["appeal"]))
	if rows.size() > limit:
		return rows.slice(0, limit)
	return rows


static func summarize(catalog: DecorationCatalog, data: SaveData) -> Dictionary:
	var appeal := calculate_appeal(catalog, data.placed_decorations)
	var next_info := next_tier_info(appeal)
	return {
		"appeal": appeal,
		"tier": tier_name(appeal),
		"tier_index": tier_index(appeal),
		"next_tier": next_info,
		"reputation_bonus_percent": reputation_bonus_percent(appeal),
		"top_contributors": top_contributors(catalog, data.placed_decorations),
	}
