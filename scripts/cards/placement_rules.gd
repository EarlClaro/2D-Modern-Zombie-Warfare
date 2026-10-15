class_name PlacementRules
extends RefCounted
## Pure placement checks for cards, in ground space (no nodes). A deployment cell must be
## buildable, inside the mission's deploy radius around the core, and not already occupied by the core
## or a player unit.

enum Reason { OK, OUT_OF_BOUNDS, NOT_BUILDABLE, TOO_FAR_FROM_CORE, OCCUPIED }

## Units of a multi-unit card stand on a ring this far (tiles) from the cell centre; < 0.5 keeps them in the cell.
const RING_RADIUS: float = 0.28


static func check_deploy(map: MapDefinition, cell: Vector2i, core_cell: Vector2i, deploy_radius: float, occupied: Array[Vector2i]) -> Reason:
	if not map.in_bounds(cell):
		return Reason.OUT_OF_BOUNDS
	if not map.is_buildable(cell):
		return Reason.NOT_BUILDABLE
	if IsoProjection.cell_center(cell).distance_to(IsoProjection.cell_center(core_cell)) > deploy_radius:
		return Reason.TOO_FAR_FROM_CORE
	if cell == core_cell or occupied.has(cell):
		return Reason.OCCUPIED
	return Reason.OK


## Operations (strikes) may be aimed at any ground cell inside the map, whatever the terrain.
static func check_ground_target(map: MapDefinition, cell: Vector2i) -> Reason:
	return Reason.OK if map.in_bounds(cell) else Reason.OUT_OF_BOUNDS


static func describe(reason: Reason) -> String:
	match reason:
		Reason.OK:
			return "OK"
		Reason.OUT_OF_BOUNDS:
			return "Outside the map"
		Reason.NOT_BUILDABLE:
			return "Can't build here"
		Reason.TOO_FAR_FROM_CORE:
			return "Too far from the base"
		Reason.OCCUPIED:
			return "Cell is occupied"
	return "Invalid"


## Ground offsets from the cell centre for `count` units: one unit stands in the middle, several are
## spread evenly on a ring.
static func formation_offsets(count: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if count <= 1:
		out.append(Vector2.ZERO)
		return out
	for i in count:
		var a := TAU * i / count - PI * 0.5
		out.append(Vector2(cos(a), sin(a)) * RING_RADIUS)
	return out
