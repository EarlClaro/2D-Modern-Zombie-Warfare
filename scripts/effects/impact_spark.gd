class_name ImpactSpark
extends Node2D
## Short burst of radiating sparks where a bullet lands. Presentation only (global RNG is fine here).

const LIFETIME_S: float = 0.14
const COUNT: int = 6

var color: Color = Color(1.0, 0.9, 0.5)
var _angles: PackedFloat32Array = PackedFloat32Array()
var _speeds: PackedFloat32Array = PackedFloat32Array()
var _age: float = 0.0


static func spawn(parent: Node, world_pos: Vector2, spark_color: Color) -> void:
	var s := ImpactSpark.new()
	s.position = world_pos
	s.color = spark_color
	for i in COUNT:
		s._angles.append(randf() * TAU)
		s._speeds.append(randf_range(18.0, 34.0))
	parent.add_child(s)


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME_S:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := _age / LIFETIME_S
	var a := 1.0 - t
	for i in _angles.size():
		var d := Vector2(cos(_angles[i]), sin(_angles[i]) * 0.6)  # squashed: sparks fly over the ground plane
		var r0 := _speeds[i] * t * 0.7
		var r1 := _speeds[i] * t + 3.0
		draw_line(d * r0, d * r1, Color(color.r, color.g, color.b, a), 2.0)
