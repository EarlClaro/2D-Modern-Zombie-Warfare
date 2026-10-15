class_name MuzzleFlash
extends Node2D
## Brief bright flare at a barrel, pointing along the shot (screen-space direction). Presentation only.

const LIFETIME_S: float = 0.05

var dir: Vector2 = Vector2.RIGHT
var _age: float = 0.0


static func spawn(parent: Node, world_pos: Vector2, shot_dir_screen: Vector2) -> void:
	var f := MuzzleFlash.new()
	f.position = world_pos
	f.dir = shot_dir_screen.normalized() if shot_dir_screen.length_squared() > 0.0001 else Vector2.RIGHT
	parent.add_child(f)


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME_S:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := 1.0 - _age / LIFETIME_S
	var perp := Vector2(-dir.y, dir.x)
	var cone := PackedVector2Array([dir * 17.0 * k, perp * 5.0 * k, -dir * 3.0, -perp * 5.0 * k])
	draw_colored_polygon(cone, Color(1.0, 0.82, 0.35, 0.95 * k))
	draw_circle(Vector2.ZERO, 4.5 * k + 1.0, Color(1.0, 1.0, 0.85, k))
