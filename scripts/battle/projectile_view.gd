class_name ProjectileView
extends Node2D
## Draws every projectile in flight from ProjectileSystem in a single node (no node per projectile).
## Artillery shells: a ground shadow, a dark round shell with a short fiery trail.
## Missiles: a small finned rocket pointing along its flight, a motor flame once it has ignited, and a long white
## smoke trail that lingers after it passes. Presentation only (its own smoke puffs never feed back into rules).

const TRAIL_STEPS: int = 4
const TRAIL_SPAN: float = 0.07  # fraction of the flight covered by a shell's trail

const BEAM_HEIGHT: float = 40.0  # altitude units a laser bolt reaches up to
const MISSILE_LEN_PX: float = 14.0
const MISSILE_IGNITION: float = 0.12  # flight fraction at which the motor lights (before that: coasting off the pylon)
const SMOKE_BACK_S: float = 0.45  # how far behind the missile the live smoke trail reaches
const SMOKE_STEPS: int = 16
const PUFF_LIFE_S: float = 1.1
const PUFF_EVERY_S: float = 0.012
const MAX_PUFFS: int = 600

var _battle: BattleController
var _had_shells: bool = false
var _puffs: Array = []  # [screen_pos: Vector2, age: float]
var _emit_clock: float = 0.0


func bind(battle: BattleController) -> void:
	_battle = battle


func _process(delta: float) -> void:
	if _battle == null:
		return
	_age_puffs(delta)
	_emit_clock += delta
	if _emit_clock >= PUFF_EVERY_S:
		_emit_clock = 0.0
		_emit_missile_smoke()
	var has := _battle.projectiles.count() > 0 or not _puffs.is_empty()
	if has or _had_shells:
		queue_redraw()
	_had_shells = has


func _age_puffs(delta: float) -> void:
	for i in range(_puffs.size() - 1, -1, -1):
		_puffs[i][1] += delta
		if _puffs[i][1] >= PUFF_LIFE_S:
			_puffs.remove_at(i)


## Leaves a puff in the air where every ignited missile currently is; the puffs then hang and fade.
func _emit_missile_smoke() -> void:
	var sys := _battle.projectiles
	for i in sys.count():
		if sys.kind_of(i) != ProjectileSystem.KIND_MISSILE or not sys.is_flying(i) or sys.progress_of(i) < MISSILE_IGNITION:
			continue
		if _puffs.size() >= MAX_PUFFS:
			_puffs.remove_at(0)
		_puffs.append([IsoProjection.ground_to_screen_z(sys.ground_pos_of(i), sys.altitude_of(i)), 0.0])


func _draw() -> void:
	if _battle == null:
		return
	for p in _puffs:
		var t: float = p[1] / PUFF_LIFE_S
		draw_circle(p[0], 3.0 + 5.0 * t, Color(0.93, 0.93, 0.93, 0.42 * (1.0 - t)))
	var sys := _battle.projectiles
	for i in sys.count():
		if not sys.is_flying(i):
			continue
		var g := sys.ground_pos_of(i)
		var head := IsoProjection.ground_to_screen_z(g, sys.altitude_of(i))
		if sys.kind_of(i) == ProjectileSystem.KIND_BEAM:
			_draw_beam(g, sys.progress_of(i))
		elif sys.kind_of(i) == ProjectileSystem.KIND_MISSILE:
			draw_circle(IsoProjection.ground_to_screen(g), 2.5, Color(0, 0, 0, 0.3))  # small ground shadow
			_draw_missile(sys, i, head)
		else:
			draw_colored_polygon(IsoProjection.ground_circle_polygon(g, 0.22, 16), Color(0, 0, 0, 0.35))
			_draw_shell(sys, i, head)


## A bolt of light from high above onto the impact point: it swells and fades over its short life, with a hot spot on the ground.
func _draw_beam(g: Vector2, progress: float) -> void:
	var a := sin(PI * clampf(progress, 0.0, 1.0))
	var base := IsoProjection.ground_to_screen(g)
	var top := IsoProjection.ground_to_screen_z(g, BEAM_HEIGHT)
	draw_line(base, top, Color(0.45, 0.8, 1.0, 0.25 * a), 16.0)
	draw_line(base, top, Color(0.75, 0.95, 1.0, 0.7 * a), 7.0)
	draw_line(base, top, Color(1.0, 1.0, 1.0, a), 2.5)
	draw_circle(base, 11.0 * a, Color(1.0, 0.9, 0.7, 0.8 * a))


func _draw_shell(sys: ProjectileSystem, i: int, head: Vector2) -> void:
	var s := sys.progress_of(i)
	var prev := head
	for k in range(1, TRAIL_STEPS + 1):
		var sk := maxf(s - TRAIL_SPAN * k / TRAIL_STEPS, 0.0)
		var pt := IsoProjection.ground_to_screen_z(sys.ground_pos_at(i, sk), sys.altitude_at(i, sk))
		draw_line(prev, pt, Color(1.0, 0.8, 0.4, 0.7 * (1.0 - float(k) / (TRAIL_STEPS + 1))), 2.5)
		prev = pt
	draw_circle(head, 4.0, Color(0.2, 0.18, 0.15))
	draw_circle(head, 2.2, Color(1.0, 0.75, 0.3))


func _draw_missile(sys: ProjectileSystem, i: int, head: Vector2) -> void:
	var s := sys.progress_of(i)
	var lit := s >= MISSILE_IGNITION
	# Live smoke trail: samples back along the actual path, wider and fainter with distance.
	if lit:
		var prev := head
		for k in range(1, SMOKE_STEPS + 1):
			var f := sys.fraction_back(i, SMOKE_BACK_S * float(k) / SMOKE_STEPS)
			var pt := IsoProjection.ground_to_screen_z(sys.ground_pos_at(i, f), sys.altitude_at(i, f))
			var t := float(k) / SMOKE_STEPS
			draw_line(prev, pt, Color(0.97, 0.97, 0.97, 0.8 * (1.0 - t * 0.65)), 3.0 + 4.0 * t)  # continuous, widening and fading
			draw_circle(pt, 1.5 + 2.0 * t, Color(0.97, 0.97, 0.97, 0.8 * (1.0 - t * 0.65)))  # rounds the joints
			prev = pt
	# Orientation: along the screen-space direction of travel.
	var behind := sys.fraction_back(i, 0.03)
	var tail_pt := IsoProjection.ground_to_screen_z(sys.ground_pos_at(i, behind), sys.altitude_at(i, behind))
	var dir := head - tail_pt
	dir = dir.normalized() if dir.length_squared() > 0.0001 else Vector2(0.7, 0.7)
	var perp := Vector2(-dir.y, dir.x)
	var nose := head + dir * MISSILE_LEN_PX * 0.5
	var tail := head - dir * MISSILE_LEN_PX * 0.5
	if lit:  # motor flame, flickering
		var flick := 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.06 + float(i))
		var flame_len := 11.0 * flick
		draw_colored_polygon(PackedVector2Array([tail + perp * 2.2, tail - dir * flame_len, tail - perp * 2.2]), Color(1.0, 0.55, 0.15, 0.95))
		draw_colored_polygon(PackedVector2Array([tail + perp * 1.1, tail - dir * flame_len * 0.55, tail - perp * 1.1]), Color(1.0, 0.95, 0.7))
	# Fins at the tail, then the body and nose cone.
	draw_colored_polygon(PackedVector2Array([tail + perp * 4.5, tail + dir * 4.0, tail - perp * 4.5]), Color(0.35, 0.37, 0.4))
	draw_line(tail, nose, Color(0.78, 0.8, 0.82), 3.2)
	draw_line(nose - dir * 3.0, nose, Color(0.8, 0.2, 0.15), 3.2)
