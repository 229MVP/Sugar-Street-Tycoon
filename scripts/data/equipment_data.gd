class_name EquipmentData
extends Resource
## Static equipment definition. Current level is stored in save data.

enum EquipmentType { OVEN, MIXER, DISPLAY_CASE, CHECKOUT }

@export var equipment_id: StringName = &""
@export var display_name: String = ""
@export var equipment_type: EquipmentType = EquipmentType.OVEN
@export var max_level: int = 5
@export var starting_level: int = 1
@export var required_player_level_per_tier: Array[int] = [1, 1, 2, 3, 4]
@export var stage_labels: Array[String] = []
@export var benefit_description: String = ""


func stage_label_for(level: int) -> String:
	var idx := clampi(level - 1, 0, maxi(stage_labels.size() - 1, 0))
	if stage_labels.is_empty():
		return "%s Lv.%d" % [display_name, level]
	return stage_labels[idx]


func upgrade_cost_to(next_level: int) -> int:
	## Costs to reach levels 2/3/4/5 from the previous level.
	match next_level:
		2: return 500
		3: return 1000
		4: return 2000
		5: return 4000
	return 0
