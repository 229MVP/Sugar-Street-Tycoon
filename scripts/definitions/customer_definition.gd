class_name CustomerDefinition
extends Resource
## Data-driven customer definition used by OrderDefinition / legacy OrderTemplate.
## Purely presentational + preference metadata; no gameplay math lives here.

## Stable string id used as the save-file key. Never change once shipped.
@export var id: String = ""
@export var display_name: String = ""
@export_multiline var greeting: String = ""
@export var portrait: Texture2D
@export var portrait_path: String = ""
@export var fallback_color: Color = Color(0.9, 0.6, 0.7, 1)
## Recipe ids this customer tends to order (used to build seed OrderDefinitions).
@export var favorite_recipe_ids: PackedStringArray = []


func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	if id.strip_edges() == "":
		errors.append("CustomerDefinition: id is required")
	if display_name.strip_edges() == "":
		errors.append("CustomerDefinition '%s': display_name is required" % id)
	return errors
