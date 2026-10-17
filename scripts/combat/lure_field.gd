class_name LureField
extends RefCounted
## The noise lures in play (Noise Lure card, ADR-013). An enemy that has nothing in reach to attack and is within a
## lure's radius walks to the lure instead of along its path, until the lure runs out. Pure: time only advances
## through tick().

const EPS: float = 1e-6


class Lure:
	extends RefCounted
	var pos: Vector2
	var radius: float
	var time_left: float

	func _init(p_pos: Vector2, p_radius: float, p_time_left: float) -> void:
		pos = p_pos
		radius = p_radius
		time_left = p_time_left


var lures: Array[Lure] = []


func add(pos: Vector2, radius: float, duration_s: float) -> void:
	lures.append(Lure.new(pos, radius, duration_s))


func is_empty() -> bool:
	return lures.is_empty()


func count() -> int:
	return lures.size()


func clear() -> void:
	lures.clear()


func tick(delta: float) -> void:
	if delta <= 0.0:
		return
	for i in range(lures.size() - 1, -1, -1):
		lures[i].time_left -= delta
		if lures[i].time_left <= EPS:
			lures.remove_at(i)


## The position of the nearest lure whose radius covers `from` (ties go to the earlier lure), or null.
func pull_for(from: Vector2) -> Variant:
	var best: Variant = null
	var best_d2 := INF
	for l in lures:
		var d2 := from.distance_squared_to(l.pos)
		if d2 <= l.radius * l.radius and d2 < best_d2:
			best_d2 = d2
			best = l.pos
	return best
