class_name Health
extends RefCounted
## Hit points for one entity. Pure logic. `died` fires exactly once, on the lethal hit.
## There is deliberately no healing in Milestone 1.

signal changed(hp: float, max_hp: float)
signal died

var max_hp: float
var hp: float


func _init(max_value: float) -> void:
	assert(max_value > 0.0, "Health max must be > 0 (definitions are validated before use)")
	max_hp = max_value
	hp = max_value


func is_dead() -> bool:
	return hp <= 0.0


func fraction() -> float:
	return clampf(hp / max_hp, 0.0, 1.0)


## Applies damage. Returns true only for the hit that kills. Non-positive amounts and hits on the
## dead are ignored.
func take_damage(amount: float) -> bool:
	if is_dead() or amount <= 0.0:
		return false
	hp = maxf(0.0, hp - amount)
	changed.emit(hp, max_hp)
	if hp <= 0.0:
		died.emit()
		return true
	return false
