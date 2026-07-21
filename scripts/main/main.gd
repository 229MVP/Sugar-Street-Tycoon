extends Control
## Legacy boot scene. Prefer scenes/main/title_screen.tscn (project main scene).
## Kept as a redirect so old shortcuts still work.


func _ready() -> void:
	SceneRouter.go_title()
