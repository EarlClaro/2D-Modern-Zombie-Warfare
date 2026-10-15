class_name TargetingService
extends RefCounted
## Pure target selection. Distances are ground-plane (tiles), centre to centre; never screen distance.

const NO_TARGET: int = -1


## Returns the id of the nearest alive candidate within `range_tiles` (inclusive), or NO_TARGET.
## Ties (exactly equal distance) go to the lowest id, so the result does not depend on list order.
static func pick(origin: Vector2, range_tiles: float, candidates: Array[TargetCandidate]) -> int:
	if range_tiles <= 0.0:
		return NO_TARGET
	var best_id := NO_TARGET
	var best_d2 := range_tiles * range_tiles
	var found := false
	for c in candidates:
		if not c.alive:
			continue
		var d2 := origin.distance_squared_to(c.pos)
		if d2 > range_tiles * range_tiles:
			continue
		if not found or d2 < best_d2 or (d2 == best_d2 and c.id < best_id):
			best_id = c.id
			best_d2 = d2
			found = true
	return best_id
