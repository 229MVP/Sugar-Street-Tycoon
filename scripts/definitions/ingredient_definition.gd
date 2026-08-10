class_name IngredientDefinition
extends Resource
## Data-driven ingredient / tool / décor-material definition.
## Artwork is fully swappable: UI reads `icon` when set, otherwise falls back
## to `fallback_color` + a text glyph, so gameplay never depends on final art.

enum Category { FRUIT, BAKING, FLAVORING, SUPPLIES, TOOLS, DECOR }

## Stable string id used as the save-file key. Never change once shipped.
@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var category: Category = Category.BAKING
## Optional final artwork. Leave null while using placeholder visuals.
@export var icon: Texture2D
@export var icon_path: String = ""
## Placeholder color used by UI when `icon` is not assigned.
@export var fallback_color: Color = Color(0.85, 0.7, 0.55, 1)
@export var starting_amount: int = 0
@export var max_stack: int = 9999
## Tools/decor materials are tracked separately from consumable ingredients.
@export var is_tool: bool = false
@export var sell_value: int = 0


func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	if id.strip_edges() == "":
		errors.append("IngredientDefinition: id is required")
	if display_name.strip_edges() == "":
		errors.append("IngredientDefinition '%s': display_name is required" % id)
	if starting_amount < 0:
		errors.append("IngredientDefinition '%s': starting_amount cannot be negative" % id)
	if max_stack < 1:
		errors.append("IngredientDefinition '%s': max_stack must be >= 1" % id)
	return errors


func category_label() -> String:
	match category:
		Category.FRUIT: return "Fruit"
		Category.BAKING: return "Baking"
		Category.FLAVORING: return "Flavoring"
		Category.SUPPLIES: return "Supplies"
		Category.TOOLS: return "Tools"
		Category.DECOR: return "Decor"
	return "Ingredient"


## Bridge to the legacy IngredientData resource used by existing UI/catalog code.
func to_ingredient_data() -> IngredientData:
	var data := IngredientData.new()
	data.ingredient_id = StringName(id)
	data.display_name = display_name
	data.icon = icon
	data.color = fallback_color
	data.starting_amount = starting_amount
	return data
