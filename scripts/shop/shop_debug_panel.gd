class_name ShopDebugPanel
extends Control
## Development-only shop debug tools. Hidden outside debug builds.


func _ready() -> void:
	if not GameState.DEBUG_TOOLS_ENABLED or not OS.is_debug_build():
		visible = false
		queue_free()
		return
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
	_btn(vbox, "+500 Reputation", func(): GameState.debug_add_reputation(500))
	_btn(vbox, "Set Player Level 8", func(): GameState.debug_set_player_level(8))
	_btn(vbox, "+1,000 Coins", func(): GameState.debug_add_coins(1000))
	_btn(vbox, "+10 Stars", func(): GameState.debug_add_stars(10))
	_btn(vbox, "+500 XP", func(): GameState.debug_add_xp(500))
	_btn(vbox, "Unlock All Recipes", func(): GameState.debug_unlock_all_recipes())
	_btn(vbox, "Equipment → Lv3", func(): GameState.debug_max_equipment())
	_btn(vbox, "Unlock All Decor", func(): GameState.debug_unlock_all_decorations())
	_btn(vbox, "Own All Decor", func(): GameState.debug_own_all_decorations())
	_btn(vbox, "Clear Decor Placements", func(): GameState.debug_clear_decoration_placements())
	_btn(vbox, "Auto-Place Highest Appeal", func(): GameState.debug_auto_place_highest_appeal())
	_btn(vbox, "Set Shop Level 3", func(): GameState.debug_set_shop_level(3))
	_btn(vbox, "Set Shop Level 5", func(): GameState.debug_set_shop_level(5))
	_btn(vbox, "Print Decorations", func(): GameState.debug_print_decorations())
	_btn(vbox, "Corrupt Decor Save", func(): GameState.debug_corrupt_decoration_save())
	_btn(vbox, "Test Decor Repair", func(): GameState.debug_test_decoration_repair())
	_btn(vbox, "Reset Decor Only", func(): GameState.debug_reset_decorations_only())
	_btn(vbox, "Reset Inventory to Starter", func(): GameState.reset_inventory_to_starter())
	_btn(vbox, "Reset Orders", func(): GameState.debug_reset_orders())
	_btn(vbox, "Print GameState", func(): GameState.debug_print_gamestate())
	_btn(vbox, "Print Save", func(): GameState.debug_print_save())
	_btn(vbox, "Corrupt Save Test", func(): GameState.debug_corrupt_save())
	_btn(vbox, "Reset Save", func(): GameState.reset_save())


func _btn(parent: Node, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	parent.add_child(b)
