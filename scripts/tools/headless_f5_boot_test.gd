extends SceneTree
## Confirms F5 main scene boots into TitleScreen (not gameplay board).


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	await process_frame
	# Change to the configured main scene the same way the editor does on F5.
	var main_path := str(ProjectSettings.get_setting("application/run/main_scene", ""))
	var err := change_scene_to_file(main_path)
	if err != OK:
		push_error("failed to change to main scene")
		quit(1)
		return
	for _i in 60:
		await process_frame
		var current := root.get_child(root.get_child_count() - 1)
		# Autoloads are also root children; find TitleScreen
		var title := root.find_child("TitleScreen", true, false)
		var board := root.get_tree().get_first_node_in_group("match_board")
		if title != null:
			print("[OK] F5 boot landed on TitleScreen")
			if board != null:
				push_error("match board present on title boot")
				quit(1)
				return
			print("=== RESULT: PASS ===")
			quit(0)
			return
	push_error("TitleScreen not found after main scene load")
	quit(1)
