class_name SceneryShadows
extends Node2D
## The ground shadows of the map's decorations, drawn once as one node on the Shadows layer: every piece that stands
## higher than MIN_HEIGHT casts a soft quadrilateral from its footprint toward the screen's bottom-right (light from
## the top-left, as for the unit shadows). Presentation only; the Atmosphere dims or deepens it with the time of day.

const FALL_DIR: Vector2 = Vector2(1.0, 0.3)  # ground direction the shadows fall
const MIN_HEIGHT: float = 0.35  # lower pieces (runway, helipad) cast nothing
const MIN_SLOPE: float = 0.25  # height per tile of footprint below which a piece is a flat heap, not a shadow caster
const LENGTH_PER_HEIGHT: float = 0.5  # tiles of shadow per tile of height
const MAX_LENGTH: float = 2.0
const ALPHA: float = 0.2

var _polygons: Array[PackedVector2Array] = []


## Builds the shadow of every piece in `pieces` (BattleScenery nodes).
func build(pieces: Array[BattleScenery]) -> void:
	_polygons.clear()
	for s in pieces:
		var poly := polygon_for(s.def, s.origin_cell)
		if not poly.is_empty():
			_polygons.append(poly)
	queue_redraw()


func polygon_count() -> int:
	return _polygons.size()


## Screen-space outline of one decoration's shadow (empty when it is too low to cast one).
static func polygon_for(def: SceneryDefinition, origin: Vector2i) -> PackedVector2Array:
	var h := def.shadow_height()
	if h < MIN_HEIGHT or h / float(maxi(def.footprint.x, def.footprint.y)) < MIN_SLOPE:
		return PackedVector2Array()  # too low, or a wide low heap (rubble, dunes) that only needs its own shading
	# wide footprints (aircraft wings, long roofs) are mostly overhang: their shadow hugs the middle of the footprint
	var inset := Vector2(0.1 + 0.18 * float(def.footprint.x - 1), 0.1 + 0.18 * float(def.footprint.y - 1))
	var lo := Vector2(origin) + inset
	var hi := Vector2(origin + def.footprint) - inset
	var shift := FALL_DIR.normalized() * minf(h * LENGTH_PER_HEIGHT, MAX_LENGTH)
	var ground := PackedVector2Array([lo, Vector2(hi.x, lo.y), hi, Vector2(lo.x, hi.y)])
	var all := PackedVector2Array(ground)
	for p in ground:
		all.append(p + shift)
	var hull := Geometry2D.convex_hull(all)
	if hull.size() > 1 and hull[0] == hull[hull.size() - 1]:
		hull.remove_at(hull.size() - 1)  # the hull is returned closed
	var out := PackedVector2Array()
	for g in hull:
		out.append(IsoProjection.ground_to_screen(g))
	return out if out.size() >= 3 else PackedVector2Array()


func _draw() -> void:
	for poly in _polygons:
		draw_colored_polygon(poly, Color(0.0, 0.0, 0.05, ALPHA))
