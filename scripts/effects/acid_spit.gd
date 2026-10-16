class_name AcidSpit
extends Node2D
## A glob of acid arcing from a spitter's mouth to its target (world pixels), with a short trail and a splash.
## Presentation only: the damage is applied by the simulation on the swing.

const FLIGHT_S: float = 0.2
const SPLASH_S: float = 0.15
const ARC_PX: float = 14.0
const BODY := Color(0.62, 0.86, 0.12)
const SHINE := Color(0.88, 1.0, 0.45)

var from_world: Vector2
var to_world: Vector2
var _age: float = 0.0


static func spawn(parent: Node, p_from: Vector2, p_to: Vector2) -> AcidSpit:
	var s := AcidSpit.new()
	s.from_world = p_from
	s.to_world = p_to
	parent.add_child(s)
	return s


func lifetime_s() -> float:
	return FLIGHT_S + SPLASH_S


## Glob position at flight fraction `t` (0..1): straight line plus an upward arc.
func glob_at(t: float) -> Vector2:
	return from_world.lerp(to_world, t) + Vector2(0.0, -4.0 * ARC_PX * t * (1.0 - t))


func _process(delta: float) -> void:
	_age += delta
	if _age >= lifetime_s():
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	if _age < FLIGHT_S:
		var t := _age / FLIGHT_S
		for k in 3:  # trail
			var tt := maxf(0.0, t - 0.08 * float(k + 1))
			draw_circle(glob_at(tt), 2.4 - 0.5 * float(k), Color(BODY.r, BODY.g, BODY.b, 0.6 - 0.18 * float(k)))
		var p := glob_at(t)
		draw_circle(p, 3.6, BODY)
		draw_circle(p + Vector2(-0.8, -0.8), 1.4, SHINE)
	else:
		var f := (_age - FLIGHT_S) / SPLASH_S
		var fade := 1.0 - f
		for k in 5:
			var a := TAU * float(k) / 5.0 + 0.4
			draw_circle(to_world + Vector2(cos(a), sin(a) * 0.6) * (3.0 + 6.0 * f), 2.0 * fade + 0.4, Color(BODY.r, BODY.g, BODY.b, fade))
		draw_circle(to_world, 4.0 * fade, Color(SHINE.r, SHINE.g, SHINE.b, 0.7 * fade))
