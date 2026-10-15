class_name IsoCellHighlight
extends Node2D
## Draws a diamond over one grid cell, derived from IsoProjection (not from the TileMap), so a
## visual mismatch with the tiles exposes a projection/layout error.

@export var cell: Vector2i = Vector2i.ZERO:
	set(v):
		cell = v
		queue_redraw()
@export var fill_color: Color = Color(1, 1, 1, 0.25)
@export var edge_color: Color = Color(1, 1, 1, 0.95)


func _draw() -> void:
	var c := Vector2(cell)
	var pts := PackedVector2Array([
		IsoProjection.ground_to_screen(c),
		IsoProjection.ground_to_screen(c + Vector2(1, 0)),
		IsoProjection.ground_to_screen(c + Vector2(1, 1)),
		IsoProjection.ground_to_screen(c + Vector2(0, 1)),
	])
	draw_colored_polygon(pts, fill_color)
	pts.append(pts[0])
	draw_polyline(pts, edge_color, 2.0)
