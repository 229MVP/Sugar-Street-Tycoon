class_name DecorationManager
extends RefCounted
## Purchase / place / remove / repair decorations against SaveData + catalog.


static func is_slot_unlocked(slot: DecorationSlotDef, data: SaveData) -> bool:
	if slot == null:
		return false
	return data.shop_level >= slot.required_shop_level


static func is_decoration_unlocked(decor: DecorationData, data: SaveData) -> bool:
	if decor == null:
		return false
	if data.shop_level < decor.required_shop_level:
		return false
	if data.player_level < decor.required_player_level:
		return false
	if data.reputation < decor.required_reputation:
		return false
	return true


static func unlock_reason(decor: DecorationData, data: SaveData) -> String:
	if decor == null:
		return "Unknown decoration."
	var reasons: PackedStringArray = []
	if data.shop_level < decor.required_shop_level:
		reasons.append("Shop level %d" % decor.required_shop_level)
	if data.player_level < decor.required_player_level:
		reasons.append("Player level %d" % decor.required_player_level)
	if data.reputation < decor.required_reputation:
		reasons.append("%d reputation" % decor.required_reputation)
	if reasons.is_empty():
		return ""
	return "Requires " + " · ".join(reasons)


static func is_owned(data: SaveData, decoration_id: String) -> bool:
	return bool(data.owned_decorations.get(decoration_id, false))


static func is_compatible(decor: DecorationData, slot: DecorationSlotDef) -> bool:
	if decor == null or slot == null:
		return false
	if decor.matches_slot_type(slot.slot_type):
		return true
	return slot.compatible_categories.has(decor.category)


static func find_slot_of_decoration(data: SaveData, decoration_id: String) -> String:
	for slot_id in data.placed_decorations.keys():
		if str(data.placed_decorations[slot_id]) == decoration_id:
			return str(slot_id)
	return ""


static func can_purchase(decor: DecorationData, data: SaveData) -> Dictionary:
	if decor == null:
		return {"ok": false, "reason": "Unknown decoration."}
	if not is_decoration_unlocked(decor, data):
		return {"ok": false, "reason": unlock_reason(decor, data)}
	if is_owned(data, str(decor.decoration_id)):
		return {"ok": false, "reason": "Already owned."}
	if data.coins < decor.purchase_cost:
		return {"ok": false, "reason": "Need %s coins." % RewardCalculator.format_coins(decor.purchase_cost)}
	return {"ok": true, "reason": "", "cost": decor.purchase_cost}


static func purchase(decor: DecorationData, data: SaveData) -> Dictionary:
	var check := can_purchase(decor, data)
	if not check.get("ok", false):
		return check
	data.coins = maxi(0, data.coins - decor.purchase_cost)
	data.owned_decorations[str(decor.decoration_id)] = true
	data.unlocked_decorations[str(decor.decoration_id)] = true
	return {"ok": true, "reason": "", "cost": decor.purchase_cost}


static func can_place(decor: DecorationData, slot: DecorationSlotDef, data: SaveData) -> Dictionary:
	if decor == null:
		return {"ok": false, "reason": "Unknown decoration."}
	if slot == null:
		return {"ok": false, "reason": "Unknown slot."}
	if not is_owned(data, str(decor.decoration_id)):
		return {"ok": false, "reason": "Decoration not owned."}
	if not is_slot_unlocked(slot, data):
		return {"ok": false, "reason": "Slot unlocks at shop level %d." % slot.required_shop_level}
	if not is_compatible(decor, slot):
		return {"ok": false, "reason": "Not compatible with this slot."}
	return {"ok": true, "reason": ""}


static func place(decor: DecorationData, slot: DecorationSlotDef, data: SaveData, replace_existing: bool = false) -> Dictionary:
	var check := can_place(decor, slot, data)
	if not check.get("ok", false):
		return check
	var slot_key := str(slot.slot_id)
	var decor_key := str(decor.decoration_id)
	var existing := str(data.placed_decorations.get(slot_key, ""))
	if existing != "" and existing != decor_key and not replace_existing:
		return {"ok": false, "reason": "Slot occupied.", "needs_replace_confirm": true, "current": existing}
	# Remove from previous slot if already placed elsewhere.
	var previous := find_slot_of_decoration(data, decor_key)
	if previous != "" and previous != slot_key:
		data.placed_decorations.erase(previous)
	data.placed_decorations[slot_key] = decor_key
	return {
		"ok": true,
		"reason": "",
		"replaced": existing if existing != "" and existing != decor_key else "",
		"moved_from": previous if previous != slot_key else "",
	}


static func remove_from_slot(slot_id: String, data: SaveData) -> Dictionary:
	if not data.placed_decorations.has(slot_id):
		return {"ok": false, "reason": "Slot is empty."}
	var decor_id := str(data.placed_decorations[slot_id])
	data.placed_decorations.erase(slot_id)
	return {"ok": true, "reason": "", "decoration_id": decor_id}


static func apply_defaults(catalog: DecorationCatalog, data: SaveData) -> void:
	if typeof(data.owned_decorations) != TYPE_DICTIONARY:
		data.owned_decorations = {}
	if typeof(data.placed_decorations) != TYPE_DICTIONARY:
		data.placed_decorations = {}
	if typeof(data.unlocked_decorations) != TYPE_DICTIONARY:
		data.unlocked_decorations = {}
	for id in catalog.default_owned_ids():
		data.owned_decorations[id] = true
		data.unlocked_decorations[id] = true
	if data.placed_decorations.is_empty():
		data.placed_decorations = catalog.default_placements().duplicate(true)
	data.shop_level = clampi(data.shop_level, 1, ShopLevelRules.MAX_SHOP_LEVEL)
	refresh_unlocks(catalog, data)
	recalculate_appeal(catalog, data)


static func refresh_unlocks(catalog: DecorationCatalog, data: SaveData) -> Array:
	## Marks newly eligible decorations unlocked (for badges). Returns new unlock ids.
	var newly: Array = []
	for decor in catalog.all_decorations():
		var id := str(decor.decoration_id)
		var was := bool(data.unlocked_decorations.get(id, false))
		if is_decoration_unlocked(decor, data):
			data.unlocked_decorations[id] = true
			if not was and not decor.owned_by_default:
				newly.append(id)
	return newly


static func recalculate_appeal(catalog: DecorationCatalog, data: SaveData) -> int:
	var appeal := ShopAppealCalculator.calculate_appeal(catalog, data.placed_decorations)
	var prev_tier := str(data.shop_appeal_tier)
	data.shop_appeal = appeal
	data.shop_appeal_tier = ShopAppealCalculator.tier_name(appeal)
	return appeal if prev_tier == data.shop_appeal_tier else appeal


static func repair(catalog: DecorationCatalog, data: SaveData) -> Array:
	## Returns list of repair messages for debug logging.
	var logs: Array = []
	if typeof(data.owned_decorations) != TYPE_DICTIONARY:
		data.owned_decorations = {}
		logs.append("owned_decorations reset")
	if typeof(data.placed_decorations) != TYPE_DICTIONARY:
		data.placed_decorations = {}
		logs.append("placed_decorations reset")
	if typeof(data.unlocked_decorations) != TYPE_DICTIONARY:
		data.unlocked_decorations = {}
		logs.append("unlocked_decorations reset")

	if data.shop_level < 1:
		data.shop_level = 1
		logs.append("shop_level raised to 1")
	if data.shop_level > ShopLevelRules.MAX_SHOP_LEVEL:
		data.shop_level = ShopLevelRules.MAX_SHOP_LEVEL
		logs.append("shop_level capped at 5")

	# Deduplicate owned keys / drop unknowns.
	var owned_clean := {}
	for key in data.owned_decorations.keys():
		var id := str(key)
		if catalog.get_decoration(StringName(id)) == null:
			logs.append("removed unknown owned decoration %s" % id)
			continue
		if bool(data.owned_decorations[key]):
			owned_clean[id] = true
	data.owned_decorations = owned_clean

	# Ensure starter ownership.
	for id in catalog.default_owned_ids():
		if not data.owned_decorations.has(id):
			data.owned_decorations[id] = true
			logs.append("restored starter ownership %s" % id)

	# Validate placements.
	var placed_clean := {}
	var used_decors := {}
	for key in data.placed_decorations.keys():
		var slot_id := str(key)
		var decor_id := str(data.placed_decorations[key])
		var slot: DecorationSlotDef = catalog.get_slot(StringName(slot_id))
		var decor: DecorationData = catalog.get_decoration(StringName(decor_id))
		if slot == null:
			logs.append("removed placement in unknown slot %s" % slot_id)
			continue
		if decor == null:
			logs.append("removed unknown decoration %s from %s" % [decor_id, slot_id])
			continue
		if not is_owned(data, decor_id):
			logs.append("removed unowned placement %s" % decor_id)
			continue
		if not is_slot_unlocked(slot, data):
			logs.append("cleared locked slot %s" % slot_id)
			continue
		if not is_compatible(decor, slot):
			logs.append("cleared incompatible %s in %s" % [decor_id, slot_id])
			continue
		if used_decors.has(decor_id):
			logs.append("cleared duplicate placement of %s" % decor_id)
			continue
		placed_clean[slot_id] = decor_id
		used_decors[decor_id] = true
	data.placed_decorations = placed_clean

	# If starter slots empty after repair, restore defaults when possible.
	var defaults := catalog.default_placements()
	for slot_id in defaults.keys():
		if placed_clean.has(slot_id):
			continue
		var decor_id := str(defaults[slot_id])
		var slot: DecorationSlotDef = catalog.get_slot(StringName(slot_id))
		var decor: DecorationData = catalog.get_decoration(StringName(decor_id))
		if slot and decor and is_slot_unlocked(slot, data) and is_owned(data, decor_id) and not used_decors.has(decor_id):
			data.placed_decorations[slot_id] = decor_id
			used_decors[decor_id] = true
			logs.append("restored default placement %s → %s" % [decor_id, slot_id])

	refresh_unlocks(catalog, data)
	var calculated := ShopAppealCalculator.calculate_appeal(catalog, data.placed_decorations)
	if data.shop_appeal != calculated:
		logs.append("recalculated appeal %d → %d" % [data.shop_appeal, calculated])
	data.shop_appeal = calculated
	data.shop_appeal_tier = ShopAppealCalculator.tier_name(calculated)
	data.decoration_save_version = SaveData.DECORATION_SAVE_VERSION
	return logs


static func affordable_count(catalog: DecorationCatalog, data: SaveData) -> int:
	var count := 0
	for decor in catalog.all_decorations():
		if can_purchase(decor, data).get("ok", false):
			count += 1
	return count


static func empty_unlocked_slot_count(catalog: DecorationCatalog, data: SaveData) -> int:
	var count := 0
	for slot in catalog.all_slots():
		if not is_slot_unlocked(slot, data):
			continue
		if str(data.placed_decorations.get(str(slot.slot_id), "")) == "":
			count += 1
	return count


static func newly_unlocked_count(catalog: DecorationCatalog, data: SaveData) -> int:
	## Unlocked, not owned, and not yet acknowledged.
	var seen: Dictionary = data.settings.get("decor_seen_unlocks", {}) if typeof(data.settings.get("decor_seen_unlocks", {})) == TYPE_DICTIONARY else {}
	var count := 0
	for decor in catalog.all_decorations():
		var id := str(decor.decoration_id)
		if not bool(data.unlocked_decorations.get(id, false)):
			continue
		if is_owned(data, id):
			continue
		if bool(seen.get(id, false)):
			continue
		count += 1
	return count


static func auto_place_highest_appeal(catalog: DecorationCatalog, data: SaveData) -> void:
	## Debug helper: greedily place highest appeal owned decor into empty/compatible slots.
	var owned: Array = []
	for decor in catalog.all_decorations():
		if is_owned(data, str(decor.decoration_id)):
			owned.append(decor)
	owned.sort_custom(func(a, b): return a.appeal_value > b.appeal_value)
	data.placed_decorations.clear()
	var used := {}
	for slot in catalog.all_slots():
		if not is_slot_unlocked(slot, data):
			continue
		for decor in owned:
			var id := str(decor.decoration_id)
			if used.has(id):
				continue
			if is_compatible(decor, slot):
				data.placed_decorations[str(slot.slot_id)] = id
				used[id] = true
				break
	recalculate_appeal(catalog, data)
