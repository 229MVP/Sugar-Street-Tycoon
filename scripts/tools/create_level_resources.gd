extends SceneTree
## Optional helper — levels are also built in ContentCatalog at runtime.


func _init() -> void:
	print("Levels are defined in ContentCatalog._build_levels().")
	quit()
