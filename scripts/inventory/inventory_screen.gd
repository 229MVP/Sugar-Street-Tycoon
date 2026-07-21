extends Control
## Ingredient inventory display (no purchasing/consumption in this phase).

@onready var list: VBoxContainer = %List
@onready var back_button: Button = %BackButton
@onready var info_label: Label = %InfoLabel


func _ready() -> void:
	back_button.pressed.connect(func():
		AudioManager.play_button()
		SceneRouter.go_shop()
	)
	GameState.state_changed.connect(refresh)
	info_label.text = "Ingredients are earned from completed orders. Consumption and shopping come later."
	refresh()


func refresh() -> void:
	for child in list.get_children():
		child.queue_free()
	for id in GameState.catalog.ingredients.keys():
		var item: IngredientData = GameState.catalog.ingredients[id]
		var row := HBoxContainer.new()
		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(28, 28)
		swatch.color = item.color
		row.add_child(swatch)
		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.text = "%s" % item.display_name
		row.add_child(label)
		var amount := Label.new()
		amount.text = "x%d" % GameState.get_ingredient_amount(item.ingredient_id)
		amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(amount)
		list.add_child(row)
