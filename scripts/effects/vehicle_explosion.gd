class_name VehicleExplosion
extends Node2D
## Fireball, sparks and a lingering smoke column where a vehicle or emplacement blew up. Starts after
## `delay_s` (a shot-down aircraft explodes when it reaches the ground). Pixel-sized, unlike the
## ground-radius `Explosion` used for area weapons. Presentation only.

const FIRE_S: float = 0.5
const SMOKE_S: float = 2.2
const SPARKS: int = 9
const PUFFS: int = 5

var radius_px: float = 24.0
var delay_s: float = 0.0
var _age: float = 0.0
var _puff_offsets: PackedVector2Array = PackedVector2Array()
var _spark_dirs: PackedVector2Array = PackedVector2Array()


## `world_pos` is the explosion centre in world pixels.
static func spawn(parent: Node, world_pos: Vector2, radius: float, delay: float = 0.0) -> VehicleExplosion:
	var e := VehicleExplosion.new()
	e.position = world_pos
	e.radius_px = radius
	e.delay_s = delay
	for i in PUFFS:
		e._puff_offsets.append(Vector2(randf_range(-0.5, 0.5), randf_range(-0.3, 0.3)) * radius)
	for i in SPARKS:
		e._spark_dirs.append(Vector2.from_angle(randf() * TAU) * randf_range(0.8, 1.6))
	parent.add_child(e)
	return e


func lifetime_s() -> float:
	return delay_s + FIRE_S + SMOKE_S


func _process(delta: float) -> void:
	_age += delta
	if _age >= lifetime_s():
		queue_free()
		return
	if _age >= delay_s:
		queue_redraw()


func _draw() -> void:
	var t := _age - delay_s
	if t < 0.0:
		return
	var f := clampf(t / FIRE_S, 0.0, 1.0)
	if f < 1.0:
		var grow := 0.45 + 0.75 * sqrt(f)
		var fade := 1.0 - f
		if FxSheet.draw_centered(self, "explosion", FxSheet.frame_at(f, 0, 4), Vector2(0, -radius_px * 0.1 * f), radius_px * grow * 2.5, Color(1, 1, 1, clampf(fade * 1.6, 0.0, 1.0))):
			for dir in _spark_dirs:
				var from := dir * radius_px * (0.3 + 0.9 * f)
				draw_line(from, from + dir * radius_px * 0.35, Color(1.0, 0.85, 0.35, fade), 2.0)
			_draw_smoke_column(t)
			return
		draw_circle(Vector2.ZERO, radius_px * grow, Color(0.85, 0.25, 0.05, 0.75 * fade))
		draw_circle(Vector2(0, -radius_px * 0.1 * f), radius_px * grow * 0.72, Color(1.0, 0.55, 0.1, 0.9 * fade))
		draw_circle(Vector2(0, -radius_px * 0.15 * f), radius_px * grow * 0.4, Color(1.0, 0.92, 0.55, fade))
		for dir in _spark_dirs:
			var from := dir * radius_px * (0.3 + 0.9 * f)
			draw_line(from, from + dir * radius_px * 0.35, Color(1.0, 0.85, 0.35, fade), 2.0)
	_draw_smoke_column(t)


## Smoke column: dark puffs rising and thinning out.
func _draw_smoke_column(t: float) -> void:
	var s := clampf((t - 0.12) / SMOKE_S, 0.0, 1.0)
	if s > 0.0 and s < 1.0:
		if FxSheet.texture("smoke") != null:
			for i in _puff_offsets.size():
				var rise := Vector2(0, -radius_px * (0.5 + 1.4 * s) - 5.0 * i * s)
				FxSheet.draw_centered(self, "smoke", FxSheet.frame_at(s, 0, 5), _puff_offsets[i] * (0.6 + s) + rise, radius_px * (0.9 + 1.0 * s), Color(1, 1, 1, 0.8 * (1.0 - s)))
			return
		for i in _puff_offsets.size():
			var rise := Vector2(0, -radius_px * (0.5 + 1.4 * s) - 5.0 * i * s)
			var o := _puff_offsets[i] * (0.6 + s) + rise
			var shade := 0.16 + 0.04 * i
			draw_circle(o, radius_px * (0.28 + 0.38 * s), Color(shade, shade, shade, 0.55 * (1.0 - s)))
