class_name Tracer
extends Node2D
## Minimal hitscan tracer: a short-lived line between two world-pixel points. Presentation only
## (1.4 baseline; the full feedback pass in 1.5 extends this).

const LIFETIME_S: float = 0.07

var from_world: Vector2
var to_world: Vector2
var color: Color = Color(1.0, 0.92, 0.55)
var _age: float = 0.0


static func spawn(parent: Node, p_from: Vector2, p_to: Vector2) -> void:
	var t := Tracer.new()
	t.from_world = p_from
	t.to_world = p_to
	parent.add_child(t)


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME_S:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var a := 1.0 - _age / LIFETIME_S
	draw_line(from_world, to_world, Color(color.r, color.g, color.b, a), 2.0)
