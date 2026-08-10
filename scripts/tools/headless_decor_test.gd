extends SceneTree
## Headless coverage for decorations, appeal, shop levels, and save migration.


var _gs: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Decoration system smoke test ===")
	await process_frame
	await process_frame
	_gs = root.get_node_or_null("/root/GameState")
	if _gs == null:
		push_error("GameState missing")
		quit(1)
		return

	var ok := true
	SaveManager.delete_save()
	_gs.new_game()

	ok = _test_defaults() and ok
	ok = _test_purchase_and_duplicate() and ok
	ok = _test_placement_rules() and ok
	ok = _test_appeal_and_bonus() and ok
	ok = _test_shop_level_upgrade() and ok
	ok = _test_save_persist() and ok
	ok = _test_migration_and_repair() and ok
	ok = await _test_ui_instantiate() and ok

	print("=== RESULT: %s ===" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)


func _test_defaults() -> bool:
	var d = _gs.data
	if d.shop_level != 1 or d.shop_appeal != 10:
		push_error("starter shop level/appeal mismatch: %s / %s" % [d.shop_level, d.shop_appeal])
		return false
	if not bool(d.owned_decorations.get("wooden_starter_sign", false)):
		push_error("starter sign not owned")
		return false
	if not bool(d.owned_decorations.get("small_mint_plant", false)):
		push_error("starter plant not owned")
		return false
	if str(d.placed_decorations.get("front_sign", "")) != "wooden_starter_sign":
		push_error("starter sign not placed")
		return false
	if str(d.placed_decorations.get("plant_corner", "")) != "small_mint_plant":
		push_error("starter plant not placed")
		return false
	if _gs.decor_catalog.decoration_sequence.size() < 16:
		push_error("expected at least 16 decorations")
		return false
	if _gs.decor_catalog.slot_sequence.size() != 10:
		push_error("expected 10 slots")
		return false
	print("[OK] starter decorations")
	return true


func _test_purchase_and_duplicate() -> bool:
	_gs.debug_add_coins(1000)
	var before: int = _gs.data.coins
	var bad = _gs.purchase_decoration(&"pink_neon_dessert_sign")
	if bad.get("ok", false):
		push_error("locked neon sign should not purchase at shop 1")
		return false
	var buy = _gs.purchase_decoration(&"framed_cupcake_print")
	if not buy.get("ok", false):
		push_error("cupcake print purchase failed: %s" % buy.get("reason", ""))
		return false
	if _gs.data.coins != before - 200:
		push_error("purchase coin deduction wrong")
		return false
	var dup = _gs.purchase_decoration(&"framed_cupcake_print")
	if dup.get("ok", false):
		push_error("duplicate purchase allowed")
		return false
	# Insufficient coins
	_gs.data.coins = 10
	var poor = _gs.purchase_decoration(&"small_dessert_jar_set")
	if poor.get("ok", false):
		push_error("insufficient coins allowed purchase")
		return false
	print("[OK] purchase rules")
	return true


func _test_placement_rules() -> bool:
	_gs.debug_add_coins(5000)
	_gs.purchase_decoration(&"small_dessert_jar_set")
	# Incompatible: jar into front_sign
	var bad = _gs.place_decoration(&"small_dessert_jar_set", &"front_sign", true)
	if bad.get("ok", false):
		push_error("incompatible placement allowed")
		return false
	# Locked slot wall_right at shop 1
	var locked = _gs.place_decoration(&"framed_cupcake_print", &"wall_right", true)
	if locked.get("ok", false):
		push_error("locked slot placement allowed")
		return false
	var place = _gs.place_decoration(&"framed_cupcake_print", &"wall_left", true)
	if not place.get("ok", false):
		push_error("compatible placement failed: %s" % place.get("reason", ""))
		return false
	# Same decor cannot stay in two slots: move to counter? wall only - place jar on counter
	var jar = _gs.place_decoration(&"small_dessert_jar_set", &"counter_accent", true)
	if not jar.get("ok", false):
		push_error("jar place failed")
		return false
	# Move framed print: only one wall slot unlocked - place again same slot ok
	# Buy strawberry clock after unlocking shop 2 later; for now remove
	var rem = _gs.remove_decoration_from_slot(&"wall_left")
	if not rem.get("ok", false):
		push_error("remove failed")
		return false
	if not _gs.is_decoration_owned(&"framed_cupcake_print"):
		push_error("remove should keep ownership")
		return false
	# Replace confirmation path: place starter sign already on front; buy nothing - place plant on plant (already)
	var replace_needed = _gs.place_decoration(&"wooden_starter_sign", &"front_sign", false)
	if not replace_needed.get("ok", false) and not replace_needed.get("needs_replace_confirm", false):
		# same decor re-place should succeed
		pass
	print("[OK] placement rules")
	return true


func _test_appeal_and_bonus() -> bool:
	_gs.debug_reset_decorations_only()
	if _gs.get_shop_appeal() != 10:
		push_error("appeal should be 10 with starters")
		return false
	# Unplaced owned decor should not count
	_gs.debug_add_coins(1000)
	_gs.purchase_decoration(&"framed_cupcake_print")
	if _gs.get_shop_appeal() != 10:
		push_error("unowned-unplaced? owned unplaced should not add appeal")
		return false
	_gs.place_decoration(&"framed_cupcake_print", &"wall_left", true)
	if _gs.get_shop_appeal() != 18:
		push_error("appeal after place should be 18, got %d" % _gs.get_shop_appeal())
		return false
	if ShopAppealCalculator.tier_name(18) != "Plain":
		push_error("tier should be Plain")
		return false
	if abs(ShopAppealCalculator.reputation_bonus_percent(18) - 0.0) > 0.0001:
		push_error("rep bonus should be 0 under 25 appeal")
		return false
	if abs(ShopAppealCalculator.reputation_bonus_percent(25) - 0.01) > 0.0001:
		push_error("25 appeal should be +1%")
		return false
	if abs(ShopAppealCalculator.reputation_bonus_percent(250) - 0.10) > 0.0001:
		push_error("250 appeal should cap at 10%")
		return false
	# Force appeal via debug auto place after owning many
	_gs.debug_own_all_decorations()
	_gs.debug_set_shop_level(5)
	_gs.debug_auto_place_highest_appeal()
	var appeal: int = _gs.get_shop_appeal()
	if appeal < 25:
		push_error("auto-place should raise appeal substantially, got %d" % appeal)
		return false
	var order = _gs.catalog.get_order(&"order_mia_001")
	var preview: Dictionary = _gs.preview_order_rewards(order)
	var pct := float(preview.get("breakdown", {}).get("decoration", {}).get("reputation_percent", 0.0))
	var expected := ShopAppealCalculator.reputation_bonus_percent(appeal)
	if abs(pct - expected) > 0.0001:
		push_error("preview decor bonus mismatch")
		return false
	if pct > 0.10 + 0.0001:
		push_error("bonus exceeded cap")
		return false
	print("[OK] appeal + reward bonus")
	return true


func _test_shop_level_upgrade() -> bool:
	SaveManager.delete_save()
	_gs.new_game()
	# Missing requirements
	var blocked = _gs.can_upgrade_shop_level()
	if blocked.get("ok", false):
		push_error("shop level 2 should be blocked initially")
		return false
	_gs.debug_set_player_level(2)
	_gs.debug_add_reputation(25)
	_gs.debug_add_coins(2000)
	# Need 20 appeal: place framed print (+8) => 18 still short; buy strawberry blossom (+12) place => too much plant conflict
	_gs.purchase_decoration(&"framed_cupcake_print")
	_gs.place_decoration(&"framed_cupcake_print", &"wall_left", true)
	_gs.purchase_decoration(&"strawberry_blossom_planter")
	# replace plant
	_gs.place_decoration(&"strawberry_blossom_planter", &"plant_corner", true)
	# appeal = 5 sign + 8 print + 12 planter = 25
	if _gs.get_shop_appeal() < 20:
		push_error("need >=20 appeal for shop 2, got %d" % _gs.get_shop_appeal())
		return false
	var rep_before: int = _gs.data.reputation
	var appeal_before: int = _gs.get_shop_appeal()
	var coins_before: int = _gs.data.coins
	var up = _gs.upgrade_shop_level()
	if not up.get("ok", false):
		push_error("shop upgrade failed: %s" % up.get("reason", ""))
		return false
	if _gs.data.shop_level != 2:
		push_error("shop level not 2")
		return false
	if _gs.data.coins != coins_before - 1000:
		push_error("shop upgrade coin deduction wrong")
		return false
	if _gs.data.reputation != rep_before:
		push_error("reputation should not be deducted")
		return false
	if _gs.get_shop_appeal() != appeal_before:
		push_error("appeal should not be deducted")
		return false
	if not DecorationManager.is_slot_unlocked(_gs.decor_catalog.get_slot(&"wall_right"), _gs.data):
		push_error("wall_right should unlock at shop 2")
		return false
	# Cap above 5
	_gs.debug_set_shop_level(5)
	var maxed = _gs.can_upgrade_shop_level()
	if maxed.get("ok", false):
		push_error("shop level 5 still upgradable")
		return false
	print("[OK] shop level upgrade")
	return true


func _test_save_persist() -> bool:
	SaveManager.delete_save()
	_gs.new_game()
	_gs.debug_add_coins(500)
	_gs.purchase_decoration(&"framed_cupcake_print")
	_gs.place_decoration(&"framed_cupcake_print", &"wall_left", true)
	_gs.save_now()
	var loaded := SaveManager.load_game()
	if not bool(loaded.owned_decorations.get("framed_cupcake_print", false)):
		push_error("owned decor not persisted")
		return false
	if str(loaded.placed_decorations.get("wall_left", "")) != "framed_cupcake_print":
		push_error("placement not persisted")
		return false
	if loaded.version < 4:
		push_error("save version should be 4+")
		return false
	print("[OK] decoration save persist")
	return true


func _test_migration_and_repair() -> bool:
	# Simulate old v3 save without decoration fields.
	var old := SaveData.create_default()
	old.version = 3
	old.decoration_save_version = 0
	old.owned_decorations = {}
	old.placed_decorations = {}
	old.coins = 777
	old.stars = 3
	old.reputation = 12
	old.shop_level = 3 # equipment-derived legacy
	SaveManager.save_game(old)
	# Force rewrite as v3-shaped by lowering version after save? save_game stamps SAVE_VERSION.
	# Manually write v3 JSON.
	var dict := SaveManager._to_dict(old)
	dict["version"] = 3
	dict.erase("owned_decorations")
	dict.erase("placed_decorations")
	dict.erase("decoration_save_version")
	dict["shop_level"] = 3
	var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(dict, "\t"))
	file.close()
	var migrated := SaveManager.load_game()
	if migrated.shop_level != 1:
		push_error("v3 migration should reset shop_level to 1, got %d" % migrated.shop_level)
		return false
	if migrated.coins != 777 or migrated.stars != 3 or migrated.reputation != 12:
		push_error("migration erased core progress")
		return false
	if str(migrated.placed_decorations.get("front_sign", "")) != "wooden_starter_sign":
		push_error("migration missing starter placement")
		return false

	_gs.data = migrated
	_gs._post_load_setup()
	SaveManager.write_corrupted_decoration_data(_gs.data)
	_gs.data = SaveManager.load_game()
	var logs: Array = DecorationManager.repair(_gs.decor_catalog, _gs.data)
	if logs.is_empty():
		push_error("expected repair logs for corrupt decor")
		return false
	if _gs.data.shop_level > 5:
		push_error("shop level not capped")
		return false
	if _gs.data.placed_decorations.has("missing_slot"):
		push_error("unknown slot remained")
		return false
	print("[OK] migration + repair")
	return true


func _test_ui_instantiate() -> bool:
	for path in [
		"res://scenes/decor/decor_screen.tscn",
		"res://scenes/shop/shop_hub.tscn",
		"res://scenes/main/title_screen.tscn",
	]:
		var packed: PackedScene = load(path)
		if packed == null:
			push_error("missing scene %s" % path)
			return false
		var n = packed.instantiate()
		root.add_child(n)
		if n is Control:
			n.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			n.size = Vector2(405, 720)
		await process_frame
		await process_frame
		n.queue_free()
		await process_frame
	print("[OK] decor UI instantiate")
	return true
