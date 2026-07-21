class_name UiMotion
extends RefCounted
## Shared subtle UI motion helpers.


static func press_scale(node: Control) -> void:
	if node == null:
		return
	node.pivot_offset = node.size * 0.5
	var tween := node.create_tween()
	tween.tween_property(node, "scale", Vector2(0.94, 0.94), 0.06)
	tween.tween_property(node, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_BACK)


static func pulse(node: Control, amount: float = 1.06, period: float = 1.1) -> void:
	if node == null:
		return
	node.pivot_offset = node.size * 0.5
	var tween := node.create_tween().set_loops()
	tween.tween_property(node, "scale", Vector2(amount, amount), period).set_trans(Tween.TRANS_SINE)
	tween.tween_property(node, "scale", Vector2.ONE, period).set_trans(Tween.TRANS_SINE)


static func popup_in(root: Control, panel: Control) -> void:
	root.visible = true
	root.modulate.a = 0.0
	panel.scale = Vector2(0.86, 0.86)
	panel.pivot_offset = panel.size * 0.5
	var tween := root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(root, "modulate:a", 1.0, 0.18)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func badge_bounce(node: Control) -> void:
	if node == null:
		return
	node.pivot_offset = node.size * 0.5
	var tween := node.create_tween()
	tween.tween_property(node, "scale", Vector2(1.25, 1.25), 0.12)
	tween.tween_property(node, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK)
