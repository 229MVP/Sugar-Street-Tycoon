class_name PassiveIncomeManager
extends RefCounted
## Passive shop income accumulation with a 4-hour storage cap.

const BASE_COINS_PER_MINUTE := 10.0
const MAX_STORAGE_SECONDS := 4 * 60 * 60 ## 4 hours


static func shop_level_multiplier(shop_level: int) -> float:
	match clampi(shop_level, 1, 5):
		1: return 1.0
		2: return 1.15
		3: return 1.30
		4: return 1.50
		5: return 1.75
	return 1.0


static func coins_per_minute(catalog: ContentCatalog, data: SaveData) -> Dictionary:
	var display_level := int(data.equipment_levels.get("display_case", 1))
	var equipment_bonus := RewardCalculator.display_bonus_percent(display_level) ## reuse 2%/lvl above 1
	# Spec: Display Case contributes to passive income — use 3% per level above 1 for clarity.
	equipment_bonus = 0.03 * float(maxi(display_level - 1, 0))
	var worker_info := WorkerBonusCalculator.passive_income_bonus_percent(catalog, data)
	var worker_bonus: float = float(worker_info.get("percent", 0.0))
	var shop_mult := shop_level_multiplier(data.shop_level)
	var rate := BASE_COINS_PER_MINUTE * shop_mult * (1.0 + equipment_bonus) * (1.0 + worker_bonus)
	return {
		"rate": rate,
		"base": BASE_COINS_PER_MINUTE,
		"shop_multiplier": shop_mult,
		"equipment_bonus": equipment_bonus,
		"worker_bonus": worker_bonus,
		"worker_contributors": worker_info.get("contributors", []),
		"max_storage_seconds": MAX_STORAGE_SECONDS,
		"max_storage_coins": rate * (float(MAX_STORAGE_SECONDS) / 60.0),
	}


static func stored_cap(catalog: ContentCatalog, data: SaveData) -> float:
	var info := coins_per_minute(catalog, data)
	return float(info["max_storage_coins"])


static func tick(catalog: ContentCatalog, data: SaveData, now_unix: int = -1) -> float:
	## Accumulate since last_passive_tick_unix. Returns coins added this tick.
	if now_unix < 0:
		now_unix = int(Time.get_unix_time_from_system())
	if data.last_passive_tick_unix <= 0:
		data.last_passive_tick_unix = now_unix
		return 0.0
	var elapsed := now_unix - data.last_passive_tick_unix
	if elapsed <= 0:
		return 0.0
	var info := coins_per_minute(catalog, data)
	var rate: float = float(info["rate"])
	var cap: float = float(info["max_storage_coins"])
	if data.stored_passive_coins >= cap:
		data.last_passive_tick_unix = now_unix
		return 0.0
	var earned := rate * (float(elapsed) / 60.0)
	var before := data.stored_passive_coins
	data.stored_passive_coins = minf(cap, data.stored_passive_coins + earned)
	data.last_passive_tick_unix = now_unix
	return data.stored_passive_coins - before


static func collect(data: SaveData) -> int:
	var amount := int(floor(data.stored_passive_coins))
	if amount <= 0:
		data.stored_passive_coins = 0.0
		return 0
	data.coins += amount
	data.stored_passive_coins = 0.0
	return amount


static func fill_storage_for_debug(catalog: ContentCatalog, data: SaveData) -> void:
	data.stored_passive_coins = stored_cap(catalog, data)
