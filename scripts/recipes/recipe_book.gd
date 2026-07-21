extends Control
## Recipe book: browse unlock status and purchase unlocks.

@onready var list: VBoxContainer = %List
@onready var detail_label: Label = %DetailLabel
@onready var unlock_button: Button = %UnlockButton
@onready var feedback_label: Label = %FeedbackLabel
@onready var back_button: Button = %BackButton
@onready var coins_label: Label = %CoinsLabel
@onready var confirm_host: Control = %ConfirmHost

var _selected_id: StringName = &""
var _confirm: ConfirmPopup


func _ready() -> void:
	_confirm = ConfirmPopup.new()
	confirm_host.add_child(_confirm)
	back_button.pressed.connect(func():
		AudioManager.play_button()
		SceneRouter.go_shop()
	)
	unlock_button.pressed.connect(_on_unlock_pressed)
	GameState.state_changed.connect(refresh)
	refresh()


func refresh() -> void:
	coins_label.text = "Coins: %s" % RewardCalculator.format_coins(GameState.data.coins)
	for child in list.get_children():
		child.queue_free()
	for id in GameState.catalog.recipes.keys():
		var recipe: RecipeData = GameState.catalog.recipes[id]
		var btn := Button.new()
		var unlocked := GameState.is_recipe_unlocked(recipe.recipe_id)
		btn.text = "%s%s · %s" % [
			recipe.display_name,
			"" if unlocked else " (Locked)",
			recipe.rarity_label(),
		]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_select.bind(recipe.recipe_id))
		list.add_child(btn)
	if _selected_id == &"" and not GameState.catalog.recipes.is_empty():
		_select(StringName(str(GameState.catalog.recipes.keys()[0])))
	elif _selected_id != &"":
		_select(_selected_id)


func _select(recipe_id: StringName) -> void:
	_selected_id = recipe_id
	var recipe := GameState.catalog.get_recipe(recipe_id)
	if recipe == null:
		return
	var unlocked := GameState.is_recipe_unlocked(recipe_id)
	var req := "Player Lv.%d · %d stars · %s coins" % [
		recipe.required_player_level,
		recipe.required_stars,
		RewardCalculator.format_coins(recipe.unlock_coin_cost),
	]
	var ings := ""
	for k in recipe.ingredient_requirements.keys():
		ings += "\n• %s x%d" % [str(k).replace("_", " ").capitalize(), int(recipe.ingredient_requirements[k])]
	detail_label.text = "%s\n%s\nCategory: %s\nRarity: %s\nBase value: %s\n\n%s\n\nRequirements:\n%s\n\nIngredients:%s" % [
		recipe.display_name,
		"UNLOCKED" if unlocked else "LOCKED",
		recipe.category_label(),
		recipe.rarity_label(),
		RewardCalculator.format_coins(recipe.base_selling_value),
		recipe.description,
		req,
		ings if ings != "" else "\n• None listed",
	]
	if unlocked:
		unlock_button.disabled = true
		unlock_button.text = "Unlocked"
		feedback_label.text = "This recipe is already in your book."
	else:
		var check := GameState.can_unlock_recipe(recipe_id)
		unlock_button.disabled = not check.get("ok", false)
		unlock_button.text = "Unlock for %s" % RewardCalculator.format_coins(recipe.unlock_coin_cost)
		feedback_label.text = str(check.get("reason", ""))


func _on_unlock_pressed() -> void:
	if _selected_id == &"":
		return
	var recipe := GameState.catalog.get_recipe(_selected_id)
	if recipe == null:
		return
	_confirm.show_confirm(
		"Unlock Recipe?",
		"Spend %s coins to unlock %s?" % [RewardCalculator.format_coins(recipe.unlock_coin_cost), recipe.display_name],
		"Unlock",
		"Cancel"
	)
	if _confirm.confirmed.is_connected(_do_unlock):
		_confirm.confirmed.disconnect(_do_unlock)
	_confirm.confirmed.connect(_do_unlock, CONNECT_ONE_SHOT)


func _do_unlock() -> void:
	var result := GameState.unlock_recipe(_selected_id)
	if result.get("ok", false):
		AudioManager.play(AudioManager.Sfx.RECIPE_UNLOCKED)
		feedback_label.text = "Recipe unlocked!"
		# Simple unlock pulse.
		var tween := create_tween()
		tween.tween_property(detail_label, "modulate", Color(1.2, 1.1, 0.8), 0.12)
		tween.tween_property(detail_label, "modulate", Color.WHITE, 0.2)
	else:
		feedback_label.text = str(result.get("reason", "Could not unlock."))
	refresh()
