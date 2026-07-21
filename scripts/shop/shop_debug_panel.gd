class_name ShopDebugPanel
extends Control
## Development-only shop debug tools. Only instantiated in debug builds.


func _ready() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(8, 8)
	panel.custom_minimum_size = Vector2(210, 0)
	add_child(panel)
	var vbox := VBoxContainer.new()
	panel.add_child(vbox)
	var title := Label.new()
	title.text = "Shop Debug"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	_btn(vbox, "+1000 Coins", func(): GameState.debug_add_coins(1000))
	_btn(vbox, "+10 Stars", func(): GameState.debug_add_stars(10))
	_btn(vbox, "+500 XP", func(): GameState.debug_add_xp(500))
	_btn(vbox, "+25 Rep", func(): GameState.debug_add_reputation(25))
	_btn(vbox, "Unlock All Recipes", func(): GameState.debug_unlock_all_recipes())
	_btn(vbox, "Complete Current Order", func(): GameState.debug_complete_current_order())
	_btn(vbox, "Reset Orders", func(): GameState.debug_reset_orders())
	_btn(vbox, "Max Equipment", func(): GameState.debug_max_equipment())
	_btn(vbox, "Print Save", func(): GameState.debug_print_save())
	_btn(vbox, "Corrupt Save Test", func(): GameState.debug_corrupt_save())
	_btn(vbox, "Reset Save", func(): GameState.reset_save())


func _btn(parent: Node, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	parent.add_child(b)
