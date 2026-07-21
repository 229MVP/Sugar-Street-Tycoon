extends Control
## Legacy title path. Redirects to the canonical main title screen.


func _ready() -> void:
	SceneRouter.go_title()
