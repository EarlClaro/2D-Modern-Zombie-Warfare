class_name PlaceholderStructure
extends IsoEntity
## Spike placeholder tall building (box). Sort anchor = footprint centre (ground space). It fades via
## IsoOcclusion when something is behind it. Light from top-left: top lightest, lower-left face
## lighter than lower-right.

var footprint: Vector2i = Vector2i.ONE
var height: float = 2.0  # altitude units
var _origin_cell: Vector2i = Vector2i.ZERO


func setup(origin_cell: Vector2i, size: Vector2i, height_units: float) -> void:
	_origin_cell = origin_cell
	footprint = size
	height = height_units
	ground_pos = Vector2(origin_cell) + Vector2(size) * 0.5
	queue_redraw()


func covered_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in footprint.y:
		for x in footprint.x:
			out.append(_origin_cell + Vector2i(x, y))
	return out


## Applies the fade rule for this frame.
func update_fade(faded: bool, delta: float) -> void:
	modulate.a = IsoOcclusion.next_alpha(modulate.a, faded, delta)


# Corner of the box; sx/sy in {-1, 1} select the footprint corner relative to the centre.
func _corner(sx: float, sy: float, z: float) -> Vector2:
	var half := Vector2(footprint) * 0.5
	return IsoProjection.ground_to_screen_z(Vector2(sx * half.x, sy * half.y), z)


func local_rect() -> Rect2:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for z in [0.0, height]:
				var p := _corner(sx, sy, z)
				lo = lo.min(p)
				hi = hi.max(p)
	return Rect2(lo, hi - lo)


func _draw() -> void:
	var outline := Color(0.08, 0.09, 0.12)
	var top := PackedVector2Array([_corner(-1, -1, height), _corner(1, -1, height), _corner(1, 1, height), _corner(-1, 1, height)])
	var left_face := PackedVector2Array([_corner(-1, 1, 0), _corner(1, 1, 0), _corner(1, 1, height), _corner(-1, 1, height)])
	var right_face := PackedVector2Array([_corner(1, -1, 0), _corner(1, 1, 0), _corner(1, 1, height), _corner(1, -1, height)])
	draw_colored_polygon(left_face, Color(0.50, 0.52, 0.58))
	draw_colored_polygon(right_face, Color(0.34, 0.36, 0.42))
	draw_colored_polygon(top, Color(0.68, 0.70, 0.75))
	for poly in [left_face, right_face, top]:
		var closed: PackedVector2Array = poly.duplicate()
		closed.append(closed[0])
		draw_polyline(closed, outline, 1.5)
