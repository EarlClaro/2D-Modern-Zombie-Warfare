class_name EdgeArrow
extends RefCounted
## Where an arrow for something off-screen sits: on the edge of the screen (inside a margin), on the line from the middle of
## the screen towards it. Pure 2D screen geometry; the caller turns a ground point into a screen point (IsoProjection and the
## camera) before asking.


class Placement:
	extends RefCounted
	## True when the point is inside the margin rectangle: no arrow is needed, mark the point itself.
	var on_screen: bool = true
	## The point itself when on screen, else the spot on the margin rectangle.
	var pos: Vector2 = Vector2.ZERO
	## Direction from the middle of the screen to the point, in radians (0 = right, y down). 0 when on screen.
	var angle: float = 0.0


static func place(target: Vector2, view: Rect2, margin: float) -> Placement:
	var out := Placement.new()
	out.pos = target
	var inner := view.grow(-minf(margin, minf(view.size.x, view.size.y) * 0.49))
	if inner.has_point(target):
		return out
	out.on_screen = false
	var centre := inner.get_center()
	var d := target - centre
	var half := inner.size * 0.5
	var sx := half.x / absf(d.x) if absf(d.x) > 1.0e-6 else INF
	var sy := half.y / absf(d.y) if absf(d.y) > 1.0e-6 else INF
	out.pos = centre + d * minf(sx, sy)
	out.angle = d.angle()
	return out
