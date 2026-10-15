class_name IsoAoeIndicator
extends Node2D
## Blast/range indicator: a ground-plane circle drawn as its projected 2:1 ellipse. Dots mark the
## centres of grid cells whose centre lies within `radius` (ground distance), so the ellipse can be
## checked against the cells it claims to cover.

var ground_pos: Vector2 = Vector2.ZERO:
	set(v):
		ground_pos = v
		position = IsoProjection.ground_to_screen(v)

var radius: float = 3.0:
	set(v):
		radius = v
		queue_redraw()

@export var fill_color: Color = Color(1.0, 0.25, 0.2, 0.16)
@export var edge_color: Color = Color(1.0, 0.35, 0.3, 0.95)
@export var dot_color: Color = Color(1.0, 0.95, 0.4, 0.95)


func _draw() -> void:
	var poly := IsoProjection.ground_circle_polygon(Vector2.ZERO, radius, 64)
	draw_colored_polygon(poly, fill_color)
	var closed := poly.duplicate()
	closed.append(closed[0])
	draw_polyline(closed, edge_color, 2.0)
	for c in cells_in_radius(ground_pos, radius):
		draw_circle(IsoProjection.ground_to_screen(IsoProjection.cell_center(c) - ground_pos), 2.5, dot_color)


## Cells whose centre is within `r` of `center` (ground distance).
static func cells_in_radius(center: Vector2, r: float) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cy in range(floori(center.y - r) - 1, ceili(center.y + r) + 2):
		for cx in range(floori(center.x - r) - 1, ceili(center.x + r) + 2):
			var c := Vector2i(cx, cy)
			if IsoProjection.cell_center(c).distance_to(center) <= r:
				out.append(c)
	return out
