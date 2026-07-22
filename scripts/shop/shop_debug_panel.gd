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
	_btn(vbox, "+1,000 Coins", func(): GameState.debug_add_coins(1000))
	_btn(vbox, "+10 Stars", func(): GameState.debug_add_stars(10))
	_btn(vbox, "+500 XP", func(): GameState.debug_add_xp(500))
	_btn(vbox, "+25 Rep", func(): GameState.debug_add_reputation(25))
	_btn(vbox, "Complete Current Objective", func(): GameState.debug_complete_current_order())
	_btn(vbox, "Win Current Level", func(): GameState.debug_win_current_level())
	_btn(vbox, "Lose Current Level", func(): GameState.debug_lose_current_level())
	_btn(vbox, "Set Moves = 5", func(): GameState.debug_set_moves_remaining(5))
	_btn(vbox, "Unlock All Recipes", func(): GameState.debug_unlock_all_recipes())
	_btn(vbox, "Equipment → Lv3", func(): GameState.debug_max_equipment())
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
