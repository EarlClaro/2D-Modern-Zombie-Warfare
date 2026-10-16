class_name LightShadows
extends RefCounted
## Pure geometry of the shadows that walls, buildings and towers throw away from a light (lamp, floodlight, fire).
## All in ground space (tiles). The result is the area behind the caster that the light does not reach; LightField
## draws it with the SUB blend so it cancels exactly that light's pool. Presentation only.

const MIN_CELLS: int = 2  # pieces on a single cell (poles, lamps, trees, signs) let the light past


## True for pieces that block a lamp: tall enough, solid enough, and at least two cells big.
static func blocks_light(def: SceneryDefinition) -> bool:
	if def == null or def.sprite == null:
		return false
	return def.shadow_height() >= LightingConfig.SHADOW_MIN_HEIGHT and def.footprint.x * def.footprint.y >= MIN_CELLS and SceneryShadows.casts(def)


## Footprint rectangle of a piece in ground space, shrunk a little so neighbours do not touch.
static func box_of(def: SceneryDefinition, origin: Vector2i) -> Rect2:
	return Rect2(Vector2(origin) + Vector2(0.08, 0.08), Vector2(def.footprint) - Vector2(0.16, 0.16))


## The shadow of a prism (footprint `box`, height `height`) cast by a light at ground position `light`, `light_height`
## tiles up, within `reach` tiles of the light. Empty when the light is inside the box, the box is out of reach, or the
## prism is so low that its shadow would be shorter than a tile corner.
static func volume(box: Rect2, height: float, light: Vector2, light_height: float, reach: float) -> PackedVector2Array:
	if box.has_point(light) or not box.grow(reach).has_point(light):
		return PackedVector2Array()
	var corners := PackedVector2Array([box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)])
	var all := PackedVector2Array(corners)
	var any_reach := false
	for c in corners:
		var away := c - light
		var d := away.length()
		if d < 0.0001 or d >= reach:
			continue
		var length := reach - d  # a caster as tall as the light shadows everything behind it
		if height < light_height:
			length = minf(length, d * height / (light_height - height))
		if length > 0.05:
			any_reach = true
		all.append(c + away / d * length)
	if not any_reach:
		return PackedVector2Array()
	var hull := Geometry2D.convex_hull(all)
	if hull.size() > 1 and hull[0] == hull[hull.size() - 1]:
		hull.remove_at(hull.size() - 1)
	return hull if hull.size() >= 3 else PackedVector2Array()


## Shadow volumes (ground space) of the nearest light-blocking pieces around a light, at most `cap` of them.
## `skip` is the piece that carries the light.
static func around(light: Vector2, light_height: float, reach: float, pieces: Array[BattleScenery], skip: BattleScenery, cap: int) -> Array[PackedVector2Array]:
	var near: Array[Dictionary] = []
	for p in pieces:
		if p == skip or not blocks_light(p.def):
			continue
		var box := box_of(p.def, p.origin_cell)
		var d := (box.get_center() - light).length() - maxf(box.size.x, box.size.y)
		if d < reach:
			near.append({"d": d, "p": p, "box": box})
	near.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["d"]) < float(b["d"]))
	var out: Array[PackedVector2Array] = []
	for n in near:
		var poly := volume(n["box"] as Rect2, (n["p"] as BattleScenery).def.shadow_height(), light, light_height, reach)
		if not poly.is_empty():
			out.append(poly)
			if out.size() >= cap:
				break
	return out
