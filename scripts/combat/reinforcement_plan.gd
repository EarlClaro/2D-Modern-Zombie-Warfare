class_name ReinforcementPlan
extends RefCounted
## Where a convoy comes in and where it settles (Convoy card, ADR-013). The squad appears on the map edge nearest its
## settling spot and walks straight to it, so the plan is only valid when that walk is clear. Pure: the caller says
## what is clear. Ground coordinates, tiles.

## Angles tried around the line from the core toward the enemy, best first (radians off that line).
const SETTLE_ANGLES: Array[float] = [0.0, 0.5236, -0.5236, 1.0472, -1.0472, 1.5708, -1.5708, 2.0944, -2.0944, 2.618, -2.618, 3.1416]
## Entry points are tried at these distances (tiles) along the edge from the spot straight out from the settling point.
const EDGE_SLIDES: Array[float] = [0.0, 2.0, -2.0, 4.0, -4.0, 6.0, -6.0, 8.0, -8.0, 10.0, -10.0]
## The entry point sits this far inside the map edge, so it is on a real cell.
const EDGE_INSET: float = 0.5

var entry: Vector2 = Vector2.ZERO
var settle: Vector2 = Vector2.ZERO


## `core` is the thing to settle around, `toward` a point in the direction the enemy comes from, `settle_dist` how far
## from the core the squad stands. `is_clear` is `func(a: Vector2, b: Vector2) -> bool`: can a unit stand on both points
## and walk the straight line between them? Returns null when no combination works.
static func plan(map_width: float, map_height: float, core: Vector2, toward: Vector2, settle_dist: float, is_clear: Callable) -> ReinforcementPlan:
	var base := toward - core
	base = base.normalized() if base.length_squared() > 0.0001 else Vector2.RIGHT
	for angle in SETTLE_ANGLES:
		var spot := core + base.rotated(angle) * settle_dist
		for entry_point in _entries(map_width, map_height, spot):
			if is_clear.call(entry_point, spot):
				var p := ReinforcementPlan.new()
				p.entry = entry_point
				p.settle = spot
				return p
	return null


## Candidate entry points for a spot, nearest edge first (ties in the order left, right, top, bottom), each edge with its slides.
static func _entries(map_width: float, map_height: float, spot: Vector2) -> Array[Vector2]:
	var dists := [spot.x, map_width - spot.x, spot.y, map_height - spot.y]
	var order := [0, 1, 2, 3]
	order.sort_custom(func(a: int, b: int) -> bool: return dists[a] < dists[b] or (dists[a] == dists[b] and a < b))
	var out: Array[Vector2] = []
	for e: int in order:
		for slide in EDGE_SLIDES:
			var p := Vector2.ZERO
			match e:
				0:
					p = Vector2(EDGE_INSET, spot.y + slide)
				1:
					p = Vector2(map_width - EDGE_INSET, spot.y + slide)
				2:
					p = Vector2(spot.x + slide, EDGE_INSET)
				3:
					p = Vector2(spot.x + slide, map_height - EDGE_INSET)
			if p.x >= 0.0 and p.x <= map_width and p.y >= 0.0 and p.y <= map_height:
				out.append(p)
	return out
