class_name DeathPuff
extends Node2D
## Dust cloud at a body's feet when something dies. Presentation only.

const LIFETIME_S: float = 0.45
const COUNT: int = 6

var _offsets: PackedVector2Array = PackedVector2Array()
var _age: float = 0.0


static func spawn(parent: Node, world_pos: Vector2) -> void:
	var p := DeathPuff.new()
	p.position = world_pos + Vector2(0, -4)
	for i in COUNT:
		p._offsets.append(Vector2(randf_range(-9.0, 9.0), randf_range(-4.0, 3.0)))
	parent.add_child(p)


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME_S:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := _age / LIFETIME_S
	var radius := lerpf(4.0, 13.0, t)
	var alpha := 0.5 * (1.0 - t)
	for i in _offsets.size():
		var o := _offsets[i] * (0.5 + t) + Vector2(0, -10.0 * t)
		draw_circle(o, radius, Color(0.58, 0.52, 0.42, alpha))
