class_name RewardCalculator
extends RefCounted
## Order reward pipeline: base → equipment → checkout → decor appeal → workers → round.


static func oven_bonus_percent(level: int) -> float:
	return 0.02 * float(maxi(level - 1, 0))


static func mixer_bonus_percent(level: int) -> float:
	return 0.02 * float(maxi(level - 1, 0))


static func display_bonus_percent(level: int) -> float:
	return 0.02 * float(maxi(level - 1, 0))


static func checkout_bonus_percent(level: int) -> float:
	return 0.01 * float(maxi(level - 1, 0))


static func compute_order_rewards(template: OrderTemplate, data: SaveData, catalog: ContentCatalog = null, decor_catalog: DecorationCatalog = null) -> Dictionary:
	## Backward compatible: catalogs optional; worker/decor bonuses apply when provided.
	var oven := int(data.equipment_levels.get("oven", 1))
	var mixer := int(data.equipment_levels.get("mixer", 1))
	var display := int(data.equipment_levels.get("display_case", 1))
	var checkout := int(data.equipment_levels.get("checkout", 1))
	var checkout_mult := 1.0 + checkout_bonus_percent(checkout)

	var base_coins := template.coin_reward
	var base_xp := template.experience_reward
	var base_rep := template.reputation_reward

	var eq_coins := int(round(float(base_coins) * (1.0 + oven_bonus_percent(oven)) * checkout_mult))
	var eq_xp := int(round(float(base_xp) * (1.0 + mixer_bonus_percent(mixer)) * checkout_mult))
	var eq_rep := int(round(float(base_rep) * (1.0 + display_bonus_percent(display)) * checkout_mult))

	var appeal := int(data.shop_appeal)
	if decor_catalog != null:
		appeal = ShopAppealCalculator.calculate_appeal(decor_catalog, data.placed_decorations)
	var decor_rep_pct := ShopAppealCalculator.reputation_bonus_percent(appeal)
	var decor_rep := int(round(float(eq_rep) * (1.0 + decor_rep_pct)))

	var worker_coin_pct := 0.0
	var worker_xp_pct := 0.0
	var worker_rep_pct := 0.0
	var worker_all_pct := 0.0
	var coin_contrib: Array = []
	var xp_contrib: Array = []
	var rep_contrib: Array = []
	var all_contrib: Array = []
	var ingredient_chance := 0.0
	var ingredient_contrib: Array = []

	if catalog != null:
		var cinfo := WorkerBonusCalculator.order_coin_bonus_percent(catalog, data)
		var xinfo := WorkerBonusCalculator.order_xp_bonus_percent(catalog, data)
		var rinfo := WorkerBonusCalculator.order_reputation_bonus_percent(catalog, data)
		var ainfo := WorkerBonusCalculator.all_order_rewards_bonus_percent(catalog, data)
		var iinfo := WorkerBonusCalculator.bonus_ingredient_chance(catalog, data)
		worker_coin_pct = float(cinfo.get("percent", 0.0))
		worker_xp_pct = float(xinfo.get("percent", 0.0))
		worker_rep_pct = float(rinfo.get("percent", 0.0))
		worker_all_pct = float(ainfo.get("percent", 0.0))
		coin_contrib = cinfo.get("contributors", [])
		xp_contrib = xinfo.get("contributors", [])
		rep_contrib = rinfo.get("contributors", [])
		all_contrib = ainfo.get("contributors", [])
		ingredient_chance = float(iinfo.get("chance", 0.0))
		ingredient_contrib = iinfo.get("contributors", [])

	var final_coins := int(round(float(eq_coins) * (1.0 + worker_coin_pct) * (1.0 + worker_all_pct)))
	var final_xp := int(round(float(eq_xp) * (1.0 + worker_xp_pct) * (1.0 + worker_all_pct)))
	var final_rep := int(round(float(decor_rep) * (1.0 + worker_rep_pct) * (1.0 + worker_all_pct)))

	var ingredients := template.ingredient_rewards.duplicate(true)

	return {
		"coins": maxi(final_coins, 0),
		"experience": maxi(final_xp, 0),
		"reputation": maxi(final_rep, 0),
		"ingredients": ingredients,
		"breakdown": {
			"base": {"coins": base_coins, "experience": base_xp, "reputation": base_rep},
			"equipment": {"coins": eq_coins, "experience": eq_xp, "reputation": eq_rep},
			"decoration": {
				"appeal": appeal,
				"reputation_percent": decor_rep_pct,
				"reputation": decor_rep,
			},
			"worker": {
				"coins": final_coins,
				"experience": final_xp,
				"reputation": final_rep,
				"coin_percent": worker_coin_pct,
				"xp_percent": worker_xp_pct,
				"reputation_percent": worker_rep_pct,
				"all_percent": worker_all_pct,
				"coin_contributors": coin_contrib,
				"xp_contributors": xp_contrib,
				"reputation_contributors": rep_contrib,
				"all_contributors": all_contrib,
			},
			"bonus_ingredient_chance": ingredient_chance,
			"bonus_ingredient_contributors": ingredient_contrib,
		},
	}


static func roll_bonus_ingredients(template: OrderTemplate, chance: float, rng: RandomNumberGenerator = null) -> Dictionary:
	if chance <= 0.0:
		return {}
	var local_rng := rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		local_rng.randomize()
	if local_rng.randf() > chance:
		return {}
	var bonus := {}
	for key in template.ingredient_rewards.keys():
		bonus[key] = 1
	if bonus.is_empty():
		bonus[&"sugar"] = 1
	return bonus


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
