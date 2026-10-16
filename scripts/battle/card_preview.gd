class_name CardPreview
extends Node2D
## World-space placement preview for the selected card: the target cell (green = valid, red = refused), the
## weapon range / blast radius as ground circles (drawn through IsoProjection, so the on-screen ellipse is
## the true ground circle), the spots where units would stand, and the deploy zone around the core.
## Presentation only; everything it shows comes from CardTargeting.Preview.

const VALID := Color(0.35, 1.0, 0.45)
const INVALID := Color(1.0, 0.35, 0.3)
const BLAST := Color(1.0, 0.65, 0.25)
const ZONE := Color(0.9, 0.95, 1.0)

var _info: CardTargeting.Preview
var _zone_center: Vector2 = Vector2.ZERO
var _zone_radius: float = 0.0
var _last_key: String = ""


## `info` null hides the preview. Redraws only when what is shown changes.
func show_preview(info: CardTargeting.Preview, zone_center: Vector2, zone_radius: float) -> void:
	var key := _key(info, zone_radius)
	if key == _last_key:
		return
	_last_key = key
	_info = info
	_zone_center = zone_center
	_zone_radius = zone_radius
	visible = info != null
	queue_redraw()


static func _key(info: CardTargeting.Preview, zone_radius: float) -> String:
	if info == null:
		return ""
	return "%d|%s|%s|%s|%s" % [info.slot, str(info.cell), str(info.valid), str(info.reason), str(zone_radius)]


func _draw() -> void:
	if _info == null:
		return
	var col := VALID if _info.valid else INVALID
	var centre := IsoProjection.cell_center(_info.cell)
	var is_deploy := _info.card != null and _info.card.card_kind == CardDefinition.CardKind.DEPLOYMENT
	if is_deploy and _zone_radius > 0.0:
		_ring(_zone_center, _zone_radius, ZONE, 0.08, 0.35)
	if _info.line_half_len > 0.0:
		var blast := _info.area_radius - Vector2(_info.line_half_len, _info.scatter_radius).length()
		_strip(centre, _info.line_dir, _info.line_half_len + blast, _info.scatter_radius + blast, BLAST, 0.12, 0.8)
		_strip(centre, _info.line_dir, _info.line_half_len, _info.scatter_radius, ZONE, 0.0, 0.5)
	elif _info.area_radius > 0.0:
		_ring(centre, _info.area_radius, BLAST, 0.12, 0.8)
		_ring(centre, _info.scatter_radius, ZONE, 0.0, 0.5)
	if _info.range_tiles > 0.0:
		_ring(centre, _info.range_tiles, col, 0.07, 0.45)
	if _info.blast_radius > 0.0 and _info.area_radius <= 0.0:
		_ring(centre, _info.blast_radius, BLAST, 0.12, 0.8)
	var c := Vector2(_info.cell)
	var pts := PackedVector2Array([
		IsoProjection.ground_to_screen(c),
		IsoProjection.ground_to_screen(c + Vector2(1, 0)),
		IsoProjection.ground_to_screen(c + Vector2(1, 1)),
		IsoProjection.ground_to_screen(c + Vector2(0, 1)),
	])
	draw_colored_polygon(pts, Color(col.r, col.g, col.b, 0.32))
	pts.append(pts[0])
	draw_polyline(pts, Color(col.r, col.g, col.b, 0.95), 2.5)
	if _info.path_points.size() >= 2:
		var route := PackedVector2Array()
		for g in _info.path_points:
			route.append(IsoProjection.ground_to_screen_z(g, UnitDefinition.LOW_AIR_ALTITUDE))
		draw_polyline(route, Color(col.r, col.g, col.b, 0.55), 2.0)
		var from := route[0]
		var to := route[1]
		var dir := (to - from).normalized()
		var mid := route[1] - dir * 40.0
		var side := Vector2(-dir.y, dir.x) * 8.0
		draw_colored_polygon(PackedVector2Array([mid + dir * 14.0, mid - dir * 4.0 + side, mid - dir * 4.0 - side]), Color(col.r, col.g, col.b, 0.8))  # arrowhead: direction of arrival
	for g in _info.ground_points:
		var s := IsoProjection.ground_to_screen(g)
		draw_circle(s, 4.0, Color(col.r, col.g, col.b, 0.9))
		draw_arc(s, 4.0, 0.0, TAU, 12, Color(0, 0, 0, 0.7), 1.0)


func _ring(ground_center: Vector2, radius: float, col: Color, fill_alpha: float, edge_alpha: float) -> void:
	var poly := IsoProjection.ground_circle_polygon(ground_center, radius, 64)
	draw_colored_polygon(poly, Color(col.r, col.g, col.b, fill_alpha))
	poly.append(poly[0])
	draw_polyline(poly, Color(col.r, col.g, col.b, edge_alpha), 2.0)


func _strip(ground_center: Vector2, dir: Vector2, half_len: float, half_width: float, col: Color, fill_alpha: float, edge_alpha: float) -> void:
	var poly := IsoProjection.ground_strip_polygon(ground_center, dir, half_len, half_width)
	draw_colored_polygon(poly, Color(col.r, col.g, col.b, fill_alpha))
	poly.append(poly[0])
	draw_polyline(poly, Color(col.r, col.g, col.b, edge_alpha), 2.0)
