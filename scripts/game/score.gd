class_name Score
extends Node
## Score and the combo (§8, "The combo, in full"). Each kill raises the
## multiplier and refreshes a grace window. Damage inside the window steps
## the multiplier down; damage outside it clears the combo.

signal changed(score: int, multiplier: int, best: int)
## full is true for a total reset, false for a one-tier step down.
signal combo_lost(full: bool)

var score := 0
var multiplier := 1
var best := 1
var _grace_left := 0.0


func _process(delta: float) -> void:
	_grace_left = maxf(0.0, _grace_left - delta)


func grace_fraction() -> float:
	return _grace_left / Tuning.combo_grace


func on_kill(points: int) -> void:
	score += points * multiplier
	multiplier += 1
	best = maxi(best, multiplier)
	_grace_left = Tuning.combo_grace
	changed.emit(score, multiplier, best)


func on_player_hit() -> void:
	if multiplier <= 1:
		return
	if _grace_left > 0.0:
		# Step down; taking damage does not refresh the window.
		multiplier = maxi(1, floori(multiplier * Tuning.combo_step_factor))
		combo_lost.emit(false)
	else:
		multiplier = 1
		combo_lost.emit(true)
	changed.emit(score, multiplier, best)
