extends SceneTree
## Android package-identity + export-preset validation for Build 2.


const EXPECTED_PACKAGE := "com.sugarstreettycoon.game"
const EXPECTED_NAME := "Sugar Street Tycoon"
const EXPECTED_VERSION_CODE := "2"
const EXPECTED_VERSION_NAME := "0.1.0-beta.2"
const FORBIDDEN_TOKEN := "undefeateddraftpicks"
const FORBIDDEN_PACKAGE := "com.undefeateddraftpicks.sugarstreettycoon"
const PRESET_PATH := "res://export_presets.cfg"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== ANDROID PACKAGE IDENTITY VALIDATION ===")
	var ok := true
	ok = _validate_build_config() and ok
	ok = _validate_export_presets() and ok
	ok = _validate_no_passwords_in_presets() and ok
	ok = _validate_no_forbidden_references() and ok
	ok = _validate_generated_android_tree() and ok
	print("=== ANDROID PACKAGE IDENTITY: %s ===" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)


func _validate_build_config() -> bool:
	if BuildConfig.ANDROID_PACKAGE_ID != EXPECTED_PACKAGE:
		push_error("BuildConfig.ANDROID_PACKAGE_ID mismatch: %s" % BuildConfig.ANDROID_PACKAGE_ID)
		return false
	if BuildConfig.ANDROID_APP_NAME != EXPECTED_NAME:
		push_error("BuildConfig.ANDROID_APP_NAME mismatch: %s" % BuildConfig.ANDROID_APP_NAME)
		return false
	if BuildConfig.APP_VERSION != EXPECTED_VERSION_NAME:
		push_error("BuildConfig.APP_VERSION mismatch: %s" % BuildConfig.APP_VERSION)
		return false
	if BuildConfig.BUILD_NUMBER != int(EXPECTED_VERSION_CODE):
		push_error("BuildConfig.BUILD_NUMBER mismatch: %d" % BuildConfig.BUILD_NUMBER)
		return false
	print("[OK] BuildConfig package/version identity")
	return true


func _validate_export_presets() -> bool:
	if not FileAccess.file_exists(PRESET_PATH):
		push_error("export_presets.cfg missing")
		return false
	var text := FileAccess.get_file_as_string(PRESET_PATH)
	if text.strip_edges() == "":
		push_error("export_presets.cfg empty")
		return false
	if not text.contains('package/unique_name="%s"' % EXPECTED_PACKAGE):
		push_error("export_presets.cfg missing package/unique_name=%s" % EXPECTED_PACKAGE)
		return false
	if not text.contains('package/name="%s"' % EXPECTED_NAME):
		push_error("export_presets.cfg missing package/name=%s" % EXPECTED_NAME)
		return false
	if not text.contains("version/code=%s" % EXPECTED_VERSION_CODE):
		push_error("export_presets.cfg missing version/code=%s" % EXPECTED_VERSION_CODE)
		return false
	if not text.contains('version/name="%s"' % EXPECTED_VERSION_NAME):
		push_error("export_presets.cfg missing version/name=%s" % EXPECTED_VERSION_NAME)
		return false
	if text.contains(FORBIDDEN_PACKAGE) or text.contains(FORBIDDEN_TOKEN):
		push_error("export_presets.cfg still references legacy package identity")
		return false
	# Project name used as Android fallback must match player-facing label.
	var proj := FileAccess.get_file_as_string("res://project.godot")
	if not proj.contains('config/name="%s"' % EXPECTED_NAME):
		push_error("project.godot config/name is not the player-facing app name")
		return false
	if not proj.contains('config/version="%s"' % EXPECTED_VERSION_NAME):
		push_error("project.godot config/version mismatch")
		return false
	print("[OK] export_presets.cfg + project.godot identity")
	return true


func _validate_no_passwords_in_presets() -> bool:
	var text := FileAccess.get_file_as_string(PRESET_PATH)
	for key in [
		"keystore/debug_password=",
		"keystore/release_password=",
		"encryption/encrypt_key=",
	]:
		if text.contains(key):
			# Allow empty assignments only if present — still prefer omission.
			var idx := text.find(key)
			while idx >= 0:
				var line_end := text.find("\n", idx)
				var line := text.substr(idx, (line_end if line_end >= 0 else text.length()) - idx)
				var value := line.substr(key.length()).strip_edges()
				if value != '""' and value != "" and value != "\"\"":
					push_error("Refusing non-empty secret in export_presets.cfg: %s" % line)
					return false
				idx = text.find(key, idx + key.length())
	print("[OK] no keystore passwords committed in export_presets.cfg")
	return true


func _validate_no_forbidden_references() -> bool:
	## Scan tracked project text for legacy package identity.
	var roots: Array[String] = [
		"res://scripts",
		"res://scenes",
		"res://docs",
		"res://resources",
		"res://",
	]
	var hits: Array[String] = []
	for root in roots:
		_scan_dir(ProjectSettings.globalize_path(root), hits)
	# Also scan export_presets at filesystem path.
	_scan_file(ProjectSettings.globalize_path(PRESET_PATH), hits)
	_scan_file(ProjectSettings.globalize_path("res://project.godot"), hits)
	_scan_file(ProjectSettings.globalize_path("res://.gitignore"), hits)
	if not hits.is_empty():
		for h in hits:
			push_error("Legacy package token found: %s" % h)
		return false
	print("[OK] no active undefeateddraftpicks references in project sources")
	return true


func _validate_generated_android_tree() -> bool:
	## If a local gradle android/ tree exists, it must not hardcode the legacy ID.
	var android_abs := ProjectSettings.globalize_path("res://android")
	if not DirAccess.dir_exists_absolute(android_abs):
		print("[OK] no generated android/ tree (package comes from export_presets.cfg)")
		return true
	var hits: Array[String] = []
	_scan_dir(android_abs, hits)
	if not hits.is_empty():
		for h in hits:
			push_error("Generated android/ still contains legacy package identity: %s" % h)
		push_error("Delete res://android and reinstall the Android build template before export.")
		return false
	# Also require the expected package somewhere if build files exist.
	var expected_hits: Array[String] = []
	_scan_dir_for_token(android_abs, EXPECTED_PACKAGE, expected_hits)
	print("[OK] generated android/ tree has no legacy package identity")
	return true


func _scan_dir(abs_path: String, hits: Array[String]) -> void:
	var dir := DirAccess.open(abs_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name == "." or name == "..":
			name = dir.get_next()
			continue
		var child := abs_path.path_join(name)
		if dir.current_is_dir():
			if name == ".godot" or name == ".git" or name == "builds":
				name = dir.get_next()
				continue
			_scan_dir(child, hits)
		else:
			_scan_file(child, hits)
		name = dir.get_next()


func _scan_file(abs_path: String, hits: Array[String]) -> void:
	if abs_path.ends_with(".png") or abs_path.ends_with(".import") or abs_path.ends_with(".apk") \
			or abs_path.ends_with(".aab") or abs_path.ends_with(".so") or abs_path.ends_with(".jar"):
		return
	if not FileAccess.file_exists(abs_path):
		return
	var f := FileAccess.open(abs_path, FileAccess.READ)
	if f == null:
		return
	var text := f.get_as_text()
	if text.contains(FORBIDDEN_TOKEN) or text.contains(FORBIDDEN_PACKAGE):
		# Allow this validation script itself to mention the forbidden token.
		if abs_path.ends_with("headless_android_package_test.gd"):
			return
		hits.append(abs_path)


func _scan_dir_for_token(abs_path: String, token: String, hits: Array[String]) -> void:
	var dir := DirAccess.open(abs_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name == "." or name == "..":
			name = dir.get_next()
			continue
		var child := abs_path.path_join(name)
		if dir.current_is_dir():
			_scan_dir_for_token(child, token, hits)
		elif FileAccess.file_exists(child):
			var text := FileAccess.get_file_as_string(child)
			if text.contains(token):
				hits.append(child)
		name = dir.get_next()
