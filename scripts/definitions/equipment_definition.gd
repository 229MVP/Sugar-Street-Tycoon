class_name EquipmentDefinition
extends Resource
## Bakery equipment definition. Levels are mirrored from the linked
## UpgradeDefinition so the legacy RewardCalculator keeps working untouched.

enum EquipmentType { OVEN, MIXER, DISPLAY_CASE, CHECKOUT, DECOR_STATION, LIGHTING }

## Stable string id used as the save-file key. Never change once shipped.
@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var equipment_type: EquipmentType = EquipmentType.OVEN
@export var icon: Texture2D
@export var icon_path: String = ""
@export var fallback_color: Color = Color(0.62, 0.42, 0.34, 1)
@export var max_level: int = 3
@export var starting_level: int = 1
## Optional link to the UpgradeDefinition that drives this equipment's level.
@export var linked_upgrade_id: String = ""
@export var stage_labels: PackedStringArray = []
@export var benefit_description: String = ""


func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	if id.strip_edges() == "":
		errors.append("EquipmentDefinition: id is required")
	if display_name.strip_edges() == "":
		errors.append("EquipmentDefinition '%s': display_name is required" % id)
	if max_level < 1:
		errors.append("EquipmentDefinition '%s': max_level must be >= 1" % id)
	return errors


func stage_label_for(level: int) -> String:
	var idx := clampi(level - 1, 0, maxi(stage_labels.size() - 1, 0))
	if stage_labels.is_empty():
		return "%s Lv.%d" % [display_name, level]
	return stage_labels[idx]


## Bridge to the legacy EquipmentData resource used by ContentCatalog / UI.
func to_equipment_data() -> EquipmentData:
	var data := EquipmentData.new()
	data.equipment_id = StringName(id)
	data.display_name = display_name
	match equipment_type:
		EquipmentType.OVEN: data.equipment_type = EquipmentData.EquipmentType.OVEN
		EquipmentType.MIXER: data.equipment_type = EquipmentData.EquipmentType.MIXER
		EquipmentType.DISPLAY_CASE: data.equipment_type = EquipmentData.EquipmentType.DISPLAY_CASE
		_: data.equipment_type = EquipmentData.EquipmentType.CHECKOUT
	data.max_level = max_level
	data.starting_level = starting_level
	data.stage_labels.assign(Array(stage_labels))
	data.benefit_description = benefit_description
	return data
