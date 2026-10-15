class_name BlastRing
extends Node2D
## Expanding ground-plane ring where an area weapon went off. The ring is a true ground circle projected
## through IsoProjection, so its on-screen ellipse matches the damage radius. Presentation only.

const LIFETIME_S: float = 0.28

var radius_tiles: float = 1.0
var color: Color = Color(1.0, 0.7, 0.3)
var _age: float = 0.0


## `ground_center` is a ground position (tiles); the node sits at its screen position.
static func spawn(parent: Node, ground_center: Vector2, radius: float, ring_color: Color) -> void:
	var r := BlastRing.new()
	r.position = IsoProjection.ground_to_screen(ground_center)
	r.radius_tiles = radius
	r.color = ring_color
	parent.add_child(r)


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME_S:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := _age / LIFETIME_S
	var poly := IsoProjection.ground_circle_polygon(Vector2.ZERO, radius_tiles * (0.35 + 0.65 * t))
	poly.append(poly[0])
	draw_polyline(poly, Color(color.r, color.g, color.b, 1.0 - t), 3.0)
	var fill := IsoProjection.ground_circle_polygon(Vector2.ZERO, radius_tiles * t)
	draw_colored_polygon(fill, Color(color.r, color.g, color.b, 0.18 * (1.0 - t)))
