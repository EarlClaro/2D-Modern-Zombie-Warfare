class_name SpawnerState
extends RefCounted
## The production timer of a building (Barracks, ADR-013): one unit every `interval_s` while fewer than `cap` of its
## units are alive. At the cap the timer sits at zero, so a replacement always takes a full interval. Pure.

const EPS: float = 1e-6

var interval_s: float
var cap: int
var timer: float = 0.0


func _init(p_interval_s: float, p_cap: int) -> void:
	interval_s = p_interval_s
	cap = p_cap


## Advances the timer; true when a unit should be made now. `alive` is how many units of this building are alive.
func tick(delta: float, alive: int) -> bool:
	if alive >= cap:
		timer = 0.0
		return false
	timer += maxf(delta, 0.0)
	if timer + EPS >= interval_s:
		timer = 0.0
		return true
	return false
