class_name SortiePlan
extends RefCounted
## Where a sortie aircraft comes from and goes to, in ground space (tiles). It enters over the map edge nearest
## the target, flies to the target, and leaves toward the opposite edge on the same lateral line. Entry and exit
## points lie `margin` tiles beyond the map edge so the aircraft flies in from off-screen. Pure.

enum Edge { LEFT, RIGHT, TOP, BOTTOM }  # x = 0, x = width, y = 0, y = height

var edge: Edge = Edge.LEFT
var entry: Vector2 = Vector2.ZERO
var station: Vector2 = Vector2.ZERO
var exit: Vector2 = Vector2.ZERO


## Nearest edge wins; exact ties go to the first of LEFT, RIGHT, TOP, BOTTOM.
static func plan(map_width: float, map_height: float, target: Vector2, margin: float) -> SortiePlan:
	var p := SortiePlan.new()
	p.station = target
	var dist := [target.x, map_width - target.x, target.y, map_height - target.y]
	var best := 0
	for i in range(1, 4):
		if dist[i] < dist[best]:
			best = i
	p.edge = best as Edge
	match p.edge:
		Edge.LEFT:
			p.entry = Vector2(-margin, target.y)
			p.exit = Vector2(map_width + margin, target.y)
		Edge.RIGHT:
			p.entry = Vector2(map_width + margin, target.y)
			p.exit = Vector2(-margin, target.y)
		Edge.TOP:
			p.entry = Vector2(target.x, -margin)
			p.exit = Vector2(target.x, map_height + margin)
		Edge.BOTTOM:
			p.entry = Vector2(target.x, map_height + margin)
			p.exit = Vector2(target.x, -margin)
	return p
