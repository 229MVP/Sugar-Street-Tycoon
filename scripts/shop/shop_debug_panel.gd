class_name ShopDebugPanel
extends Control
## Development-only shop + worker debug tools.


func _ready() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(8, 8)
	panel.custom_minimum_size = Vector2(220, 0)
	add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(220, 360)
	panel.add_child(scroll)
	var vbox := VBoxContainer.new()
	scroll.add_child(vbox)
	var title := Label.new()
	title.text = "Shop Debug"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	_btn(vbox, "+10,000 Coins", func(): GameState.debug_add_coins(10000))
	_btn(vbox, "+10 Stars", func(): GameState.debug_add_stars(10))
	_btn(vbox, "+500 XP", func(): GameState.debug_add_xp(500))
	_btn(vbox, "+25 Rep", func(): GameState.debug_add_reputation(25))
	_btn(vbox, "Unlock All Recipes", func(): GameState.debug_unlock_all_recipes())
	_btn(vbox, "Unlock All Workers", func(): GameState.debug_unlock_all_workers())
	_btn(vbox, "Hire All Workers", func(): GameState.debug_hire_all_workers())
	_btn(vbox, "Assign All Workers", func(): GameState.debug_assign_all_workers())
	_btn(vbox, "Clear Assignments", func(): GameState.debug_clear_assignments())
	_btn(vbox, "Ava → Lv10", func(): GameState.debug_set_worker_level(&"ava", 10))
	_btn(vbox, "Simulate 1h Offline", func(): GameState.debug_simulate_offline_hour())
	_btn(vbox, "Fill Passive Storage", func(): GameState.debug_fill_passive_storage())
	_btn(vbox, "Clear Passive Storage", func(): GameState.debug_clear_passive_storage())
	_btn(vbox, "Print Workers", func(): GameState.debug_print_workers())
	_btn(vbox, "Corrupt Worker Save", func(): GameState.debug_corrupt_worker_save())
	_btn(vbox, "Reset Workers Only", func(): GameState.debug_reset_workers_only())
	_btn(vbox, "Complete Current Order", func(): GameState.debug_complete_current_order())
	_btn(vbox, "Max Equipment", func(): GameState.debug_max_equipment())
	_btn(vbox, "Print Save", func(): GameState.debug_print_save())
	_btn(vbox, "Corrupt Save Test", func(): GameState.debug_corrupt_save())
	_btn(vbox, "Reset Save", func(): GameState.reset_save())


func _btn(parent: Node, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	parent.add_child(b)
