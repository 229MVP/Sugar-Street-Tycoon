class_name ScoreTracker
extends RefCounted
## Tracks score and cascade multiplier.

signal score_changed(new_score: int, delta: int)

var score: int = 0
var cascade_multiplier: int = 1


func reset() -> void:
	score = 0
	cascade_multiplier = 1
	score_changed.emit(score, 0)


func add_clear_score(base_points: int, cascade_index: int) -> int:
	## cascade_index 0 = first clear of a move (x1), then x2, x3, ...
	cascade_multiplier = cascade_index + 1
	var delta := base_points # board already multiplies; accept as final delta
	score += delta
	score_changed.emit(score, delta)
	return delta


func reset_cascade_multiplier() -> void:
	cascade_multiplier = 1
