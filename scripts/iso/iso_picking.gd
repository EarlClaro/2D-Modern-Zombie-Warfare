class_name IsoPicking
extends RefCounted
## Mouse -> ground/cell. Uses the canvas (world) mouse position, so camera pan/zoom are handled by Godot.
## Card targeting and previews use these ground values, never sprite positions.


static func ground_from_world(world: Vector2) -> Vector2:
	return IsoProjection.screen_to_ground(world)


static func ground_under_mouse(node: CanvasItem) -> Vector2:
	return ground_from_world(node.get_global_mouse_position())


static func cell_under_mouse(node: CanvasItem) -> Vector2i:
	return IsoProjection.cell_of(ground_under_mouse(node))
