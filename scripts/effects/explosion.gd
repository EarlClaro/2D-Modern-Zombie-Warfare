class_name Explosion
extends Node2D
## A proper explosion at a ground point: white flash, rising fireball (white-yellow core, orange, red, dark edge),
## a shockwave that expands to the true damage radius along the ground, a scorch mark that lingers, and smoke that
## rises afterwards. Everything scales with the blast radius, so the visible blast matches the area that was hurt.
## Presentation only (cosmetic randomness uses the global RNG).

const LIFE_S: float = 0.8
const FLASH_S: float = 0.07
const SHOCK_S: float = 0.38
const FIREBALL_S: float = 0.55
const LOBES: int = 5

var radius_tiles: float = 1.5
var _age: float = 0.0
var _lobe_angle: PackedFloat32Array = PackedFloat32Array()
var _lobe_dist: PackedFloat32Array = PackedFloat32Array()
var _smoke_angle: PackedFloat32Array = PackedFloat32Array()


## `ground_center` is a ground position (tiles); the node sits at its screen position.
static func spawn(parent: Node, ground_center: Vector2, radius: float) -> void:
	var e := Explosion.new()
	e.position = IsoProjection.ground_to_screen(ground_center)
	e.radius_tiles = maxf(radius, 0.3)
	for i in LOBES:
		e._lobe_angle.append(randf() * TAU)
		e._lobe_dist.append(randf_range(0.2, 0.6))
	for i in 4:
		e._smoke_angle.append(randf() * TAU)
	parent.add_child(e)


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFE_S:
		queue_free()
		return
	queue_redraw()


## 0..1 progress of a phase that lasts `duration` seconds.
static func phase(age: float, duration: float) -> float:
	return clampf(age / duration, 0.0, 1.0)


## Fireball size factor over its life: swells quickly, then shrinks away.
static func fireball_size(t: float) -> float:
	var x := clampf(t, 0.0, 1.0)
	return sin(minf(x * 1.15, 1.0) * PI * 0.62) * (1.0 - x * 0.45)


func _draw() -> void:
	var rpx := IsoProjection.ellipse_radii(radius_tiles).x  # on-screen half-width of the ground circle
	_draw_scorch()
	_draw_shockwave()
	var f_t := phase(_age, FIREBALL_S)
	if f_t < 1.0:
		_draw_fireball(rpx, f_t)
	if _age > 0.18:
		_draw_smoke(rpx)
	if _age < FLASH_S:
		var k := 1.0 - _age / FLASH_S
		draw_circle(Vector2(0, -rpx * 0.15), rpx * (0.45 + 0.25 * (1.0 - k)), Color(1.0, 1.0, 0.9, 0.9 * k))


func _draw_scorch() -> void:
	var fade := 1.0 - phase(_age, LIFE_S)
	var poly := IsoProjection.ground_circle_polygon(Vector2.ZERO, radius_tiles * 0.7, 32)
	draw_colored_polygon(poly, Color(0.05, 0.04, 0.03, 0.4 * fade))


func _draw_shockwave() -> void:
	var t := phase(_age, SHOCK_S)
	if t >= 1.0:
		return
	var eased := 1.0 - (1.0 - t) * (1.0 - t)
	var poly := IsoProjection.ground_circle_polygon(Vector2.ZERO, radius_tiles * eased, 48)
	draw_colored_polygon(poly, Color(1.0, 0.6, 0.2, 0.22 * (1.0 - t)))
	poly.append(poly[0])
	draw_polyline(poly, Color(1.0, 0.85, 0.5, 0.95 * (1.0 - t)), 3.0)


func _draw_fireball(rpx: float, t: float) -> void:
	var size := fireball_size(t) * rpx * 0.85
	var rise := Vector2(0, -rpx * 0.28 * t - rpx * 0.12)
	var fade := 1.0 - t * t
	# Lumpy body: a few offset lobes per colour layer, bigger layers first.
	var layers := [
		[1.0, Color(0.45, 0.1, 0.05, 0.75 * fade)],
		[0.82, Color(0.95, 0.28, 0.08, 0.9 * fade)],
		[0.6, Color(1.0, 0.62, 0.15, 0.95 * fade)],
		[0.36, Color(1.0, 0.92, 0.55, fade)],
	]
	for layer in layers:
		var scale: float = layer[0]
		var col: Color = layer[1]
		draw_circle(rise, size * scale, col)
		for i in LOBES:
			var off := Vector2(cos(_lobe_angle[i]), sin(_lobe_angle[i]) * 0.7) * size * _lobe_dist[i]
			draw_circle(rise + off, size * scale * 0.62, col)


func _draw_smoke(rpx: float) -> void:
	var t := phase(_age - 0.18, LIFE_S - 0.18)
	for i in _smoke_angle.size():
		var base := Vector2(cos(_smoke_angle[i]) * rpx * 0.3, sin(_smoke_angle[i]) * rpx * 0.15)
		var pos := base + Vector2(0, -rpx * (0.25 + 0.55 * t))
		draw_circle(pos, rpx * (0.16 + 0.22 * t), Color(0.25, 0.24, 0.23, 0.5 * (1.0 - t)))
