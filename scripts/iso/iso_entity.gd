class_name IsoEntity
extends Node2D
## Base for anything placed on the battlefield. Authoritative position is `ground_pos` (tiles) plus
## `altitude` (z). The node's own `position` is the projected footprint base point = the y-sort anchor,
## so aircraft sort by their ground position and only their *drawing* is lifted by altitude.

var ground_pos: Vector2 = Vector2.ZERO:
	set(v):
		ground_pos = v
		position = IsoProjection.ground_to_screen(v)

var altitude: float = 0.0:
	set(v):
		altitude = v
		queue_redraw()


func sort_key() -> float:
	return IsoProjection.sort_key(ground_pos)


## Bounding box of what this entity draws, in entity-local px. Override.
func local_rect() -> Rect2:
	return Rect2()


## Same box in world px (used for occlusion tests).
func world_rect() -> Rect2:
	var r := local_rect()
	r.position += position
	return r
