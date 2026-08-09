class_name FeatureTipPresenter
extends RefCounted
## Shows a one-shot contextual TutorialOverlay for a feature id.


static func maybe_show(parent: Node, feature_id: String) -> void:
	if parent == null:
		return
	var gs := parent.get_node_or_null("/root/GameState")
	if gs == null or gs.get("data") == null:
		return
	var data: SaveData = gs.data
	if not TutorialManager.should_show_feature_tip(data, feature_id):
		return
	var tip := TutorialManager.feature_tip(feature_id)
	if tip.is_empty():
		return
	var overlay := TutorialOverlay.new()
	parent.add_child(overlay)
	overlay.next_pressed.connect(func():
		TutorialManager.mark_feature_seen(data, feature_id)
		gs.save_now()
		if is_instance_valid(overlay):
			overlay.queue_free()
	)
	overlay.skip_pressed.connect(func():
		TutorialManager.mark_feature_seen(data, feature_id)
		gs.save_now()
		if is_instance_valid(overlay):
			overlay.queue_free()
	)
	# Feature tips are short one-shots — hide the linear "Skip Tutorial" path.
	overlay.show_step(str(tip.get("title", "")), str(tip.get("body", "")), false)
