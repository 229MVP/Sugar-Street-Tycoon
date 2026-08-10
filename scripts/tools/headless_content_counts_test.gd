extends SceneTree
## Verifies Beta 0.1 seed-content counts and basic cross-reference integrity
## (Phase 10 requirements). Also doubles as the data half of the Beta
## Diagnostics one-button smoke test (see scripts/tools/beta_smoke_test.gd).


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Content counts test ===")
	await process_frame
	var db := DefinitionDatabase.new()
	db.build()

	var ok := true
	ok = _expect(db.ingredient_sequence.size(), 12, "ingredients") and ok
	ok = _expect(db.recipe_sequence.size(), 8, "recipes") and ok
	ok = _expect(db.upgrade_sequence.size(), 6, "upgrades") and ok
	ok = _expect(db.worker_sequence.size(), 6, "workers") and ok
	ok = _expect(db.customer_sequence.size(), 6, "customers") and ok
	ok = _expect_at_least(db.order_sequence.size(), 10, "order templates") and ok
	ok = _expect_at_least(db.levels.size(), 10, "puzzle levels") and ok

	ok = BetaSmokeTest.validate_content(db).ok and ok

	print("=== RESULT: %s ===" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)


func _expect(actual: int, expected: int, label: String) -> bool:
	if actual != expected:
		push_error("expected %d %s, got %d" % [expected, label, actual])
		return false
	print("[OK] %d %s" % [actual, label])
	return true


func _expect_at_least(actual: int, minimum: int, label: String) -> bool:
	if actual < minimum:
		push_error("expected at least %d %s, got %d" % [minimum, label, actual])
		return false
	print("[OK] %d %s (>= %d)" % [actual, label, minimum])
	return true
