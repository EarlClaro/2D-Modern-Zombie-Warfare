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

var _polygons: Array[PackedVector2Array] = []
var _contact: Array[PackedVector2Array] = []  # the dark seam where a piece meets the ground (ambient occlusion)
var _pieces: Array[BattleScenery] = []
var _scale: float = 1.0


## Builds the shadow of every piece in `pieces` (BattleScenery nodes) at the sun's current shadow scale.
func build(pieces: Array[BattleScenery]) -> void:
	_pieces = pieces
	_contact.clear()
	for s in pieces:
		if casts(s.def):
			_contact.append(contact_polygon_for(s.def, s.origin_cell))
	_rebuild_shadows()


## The sun's shadow length relative to noon (DayNight.shadow_scale_at). Rebuilds only when it changed noticeably.
func set_sun_scale(sun_scale: float) -> void:
	if absf(sun_scale - _scale) >= LightingConfig.SHADOW_LENGTH_REBUILD_DELTA:
		_scale = sun_scale
		_rebuild_shadows()


func _rebuild_shadows() -> void:
	_polygons.clear()
	for s in _pieces:
		var poly := polygon_for(s.def, s.origin_cell, _scale)
		if not poly.is_empty():
			_polygons.append(poly)
	queue_redraw()


func polygon_count() -> int:
	return _polygons.size()


## False for pieces too low to cast a shadow and for wide low heaps (rubble, dunes) that only need their own shading.
static func casts(def: SceneryDefinition) -> bool:
	var h := def.shadow_height()
	return h >= MIN_HEIGHT and h / float(maxi(def.footprint.x, def.footprint.y)) >= MIN_SLOPE


## Screen-space outline of one decoration's shadow (empty when it is too low to cast one).
static func polygon_for(def: SceneryDefinition, origin: Vector2i, sun_scale: float = 1.0) -> PackedVector2Array:
	var h := def.shadow_height()
	if not casts(def):
		return PackedVector2Array()  # too low, or a wide low heap (rubble, dunes) that only needs its own shading
	# wide footprints (aircraft wings, long roofs) are mostly overhang: their shadow hugs the middle of the footprint
	var inset := Vector2(0.1 + 0.18 * float(def.footprint.x - 1), 0.1 + 0.18 * float(def.footprint.y - 1))
	var lo := Vector2(origin) + inset
	var hi := Vector2(origin + def.footprint) - inset
	var shift := FALL_DIR.normalized() * minf(h * LENGTH_PER_HEIGHT * sun_scale, MAX_LENGTH * sun_scale)
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


## Screen-space outline of the footprint grown a little: the contact shadow under a piece.
static func contact_polygon_for(def: SceneryDefinition, origin: Vector2i) -> PackedVector2Array:
	var g := LightingConfig.CONTACT_AO_GROW
	var lo := Vector2(origin) - Vector2(g, g)
	var hi := Vector2(origin + def.footprint) + Vector2(g, g)
	var out := PackedVector2Array()
	for p in [lo, Vector2(hi.x, lo.y), hi, Vector2(lo.x, hi.y)]:
		out.append(IsoProjection.ground_to_screen(p))
	return out


func _draw() -> void:
	var ao := Color(LightingConfig.SUN_SHADOW_COLOR, LightingConfig.CONTACT_AO_ALPHA)
	for poly in _contact:
		draw_colored_polygon(poly, ao)
	var col := Color(LightingConfig.SUN_SHADOW_COLOR, LightingConfig.SUN_SHADOW_ALPHA)
	for poly in _polygons:
		draw_colored_polygon(poly, col)
