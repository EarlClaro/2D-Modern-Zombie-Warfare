class_name SatelliteLaserScene
extends CutawayScene
## Satellite laser cutaway (epic): a military satellite in orbit above the curved limb of the Earth charges its
## emitter (energy converging on the lens), then a thin beam stabs down through the atmosphere onto the surface and
## sweeps across the target area, leaving a scorched, glowing track. The satellite is the generated sprite of
## tools/gen_cutaway_art.gd; the stars, the planet, the beam and the impact are drawn here.

const SAT: Texture2D = preload("res://assets/cutaways/satellite.png")
const LENS: Vector2 = Vector2(58.0, 14.0)  # the sensor block of the sprite, where the beam leaves
const SAT_CENTER: Vector2 = Vector2(48.0, 32.0)
const DESIGN_H: float = 684.0

const CHARGE_FROM: float = 0.08
const FIRE_U: float = 0.34  # the beam stabs down
const SWEEP_FROM: float = 0.42
const SWEEP_TO: float = 0.9  # the beam shuts off
const TARGET_X_FROM: float = 0.38  # where the beam lands, across the picture
const TARGET_X_TO: float = 0.9

const SPACE_TOP: Color = Color(0.01, 0.01, 0.04)
const SPACE_LOW: Color = Color(0.03, 0.05, 0.13)
const OCEAN: Color = Color(0.04, 0.12, 0.26)
const BEAM_CORE: Color = Color(1.0, 1.0, 1.0)
const BEAM_GLOW: Color = Color(0.45, 0.8, 1.0)

var _sh: Vector2 = Vector2.ZERO


func shake(t: float, length: float) -> Vector2:
	var u := t / maxf(length, 0.001)
	if u < FIRE_U or u > SWEEP_TO + 0.04:
		return Vector2.ZERO
	var amp := 3.2  # a low hum while the beam is on
	return Vector2(sin(t * 140.0) * amp, cos(t * 113.0) * amp)


func draw(ci: CanvasItem, rect: Rect2, t: float, length: float) -> void:
	var u := t / maxf(length, 0.001)
	var s := rect.size.y / DESIGN_H
	_sh = shake(t, length)
	ci.draw_set_transform(_sh, 0.0, Vector2.ONE)
	_space(ci, rect, s, t)
	var planet := _planet(rect)
	_earth(ci, rect, planet, s, u)
	var sat_pos := Vector2(rect.position.x + rect.size.x * (0.2 + 0.015 * u), rect.position.y + rect.size.y * (0.2 - 0.01 * u))
	var sc := 3.0 * s
	var lens := sat_pos + (LENS - SAT_CENTER) * sc
	# the beam is behind the satellite, in front of the planet
	var target := _target(rect, planet, u)
	_beam(ci, rect, lens, target, u, s)
	ci.draw_set_transform(sat_pos + _sh, -0.04, Vector2(sc, sc))
	ci.draw_texture(SAT, -SAT_CENTER)
	ci.draw_set_transform(_sh, 0.0, Vector2.ONE)
	_charge(ci, lens, u, s, t)
	_impact(ci, rect, planet, target, u, s, t)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# a faint whiteout at the moment the beam fires
	var f := u - FIRE_U
	if f >= 0.0 and f < 0.1:
		ci.draw_rect(rect, Color(0.8, 0.9, 1.0, 0.25 * (1.0 - f / 0.1)))


## The planet as [centre, radius]: a huge disc whose upper limb curves across the lower part of the picture.
func _planet(rect: Rect2) -> Array:
	var r := rect.size.x * 1.15
	return [Vector2(rect.position.x + rect.size.x * 0.55, rect.position.y + rect.size.y * 0.78 + r), r]


## Where the beam lands on the planet's surface at clip share `u`: sweeps across the limb.
func _target(rect: Rect2, planet: Array, u: float) -> Vector2:
	var k := smoothstep(SWEEP_FROM, SWEEP_TO, u)
	var x := rect.position.x + rect.size.x * lerpf(TARGET_X_FROM, TARGET_X_TO, k)
	var c: Vector2 = planet[0]
	var r: float = planet[1]
	var dx := x - c.x
	return Vector2(x, c.y - sqrt(maxf(r * r - dx * dx, 0.0)) + 6.0)


func _beam(ci: CanvasItem, rect: Rect2, lens: Vector2, target: Vector2, u: float, s: float) -> void:
	if u < FIRE_U or u > SWEEP_TO + 0.03:
		return
	var grow := smoothstep(FIRE_U, FIRE_U + 0.05, u)
	var fade := 1.0 - smoothstep(SWEEP_TO, SWEEP_TO + 0.03, u)
	var k := grow * fade
	# until the sweep begins the beam holds on the first point; its tip stabs down from the lens
	var tip := lens.lerp(target, smoothstep(FIRE_U, FIRE_U + 0.035, u))
	var flick := 0.9 + 0.1 * sin(u * 900.0)
	ci.draw_line(lens, tip, Color(BEAM_GLOW.r, BEAM_GLOW.g, BEAM_GLOW.b, 0.18 * k), 54.0 * s * k)
	ci.draw_line(lens, tip, Color(BEAM_GLOW.r, BEAM_GLOW.g, BEAM_GLOW.b, 0.4 * k), 26.0 * s * k * flick)
	ci.draw_line(lens, tip, Color(0.8, 0.95, 1.0, 0.85 * k), 11.0 * s * k)
	ci.draw_line(lens, tip, Color(BEAM_CORE.r, BEAM_CORE.g, BEAM_CORE.b, k), 4.5 * s * k)


## Energy gathering at the lens: a swelling glow, rings contracting onto it and sparks drawn inward.
func _charge(ci: CanvasItem, lens: Vector2, u: float, s: float, t: float) -> void:
	if u < CHARGE_FROM:
		return
	var build := clampf((u - CHARGE_FROM) / (FIRE_U - CHARGE_FROM), 0.0, 1.0)
	var on := u >= FIRE_U and u <= SWEEP_TO + 0.03
	var glow := (0.25 + 0.75 * build) if not on else 1.0
	ci.draw_circle(lens, (10.0 + 46.0 * glow) * s, Color(0.4, 0.75, 1.0, 0.16 * glow))
	ci.draw_circle(lens, (6.0 + 22.0 * glow) * s, Color(0.6, 0.9, 1.0, 0.4 * glow))
	ci.draw_circle(lens, (3.0 + 8.0 * glow) * s, Color(1.0, 1.0, 1.0, 0.9 * glow))
	if on:
		return
	for k in 3:
		var ph := fposmod(build * 3.0 + float(k) / 3.0, 1.0)
		var r := (90.0 * (1.0 - ph) + 8.0) * s
		var pts := PackedVector2Array()
		for i in 33:
			var a := TAU * float(i) / 32.0
			pts.append(lens + Vector2(cos(a), sin(a)) * r)
		ci.draw_polyline(pts, Color(0.55, 0.85, 1.0, 0.5 * ph * build), 2.0 * s)
	for k in 14:
		var a := TAU * hash01(k, 81)
		var ph := fposmod(t * 2.2 + hash01(k, 82), 1.0)
		var from := lens + Vector2(cos(a), sin(a)) * (110.0 * (1.0 - ph) + 10.0) * s
		var to := lens + Vector2(cos(a), sin(a)) * (110.0 * (1.0 - ph) * 0.8 + 6.0) * s
		ci.draw_line(from, to, Color(0.8, 0.95, 1.0, 0.8 * build), 2.0 * s)


func _impact(ci: CanvasItem, rect: Rect2, planet: Array, target: Vector2, u: float, s: float, t: float) -> void:
	if u < FIRE_U + 0.03 or u > SWEEP_TO + 0.12:
		return
	var on := clampf(1.0 - (u - SWEEP_TO) / 0.12, 0.0, 1.0)
	var k := smoothstep(FIRE_U + 0.03, FIRE_U + 0.07, u) * on
	var flick := 0.85 + 0.15 * sin(t * 61.0)
	# the scorched track the beam has drawn across the surface so far, then the glow where it is now
	var c: Vector2 = planet[0]
	var r: float = planet[1]
	var x0 := _target(rect, planet, SWEEP_FROM).x
	var pts := PackedVector2Array()
	for i in 29:
		var x := lerpf(x0, target.x, float(i) / 28.0)
		var dx := x - c.x
		pts.append(Vector2(x, c.y - sqrt(maxf(r * r - dx * dx, 0.0)) + 6.0))
	ci.draw_polyline(pts, Color(1.0, 0.5, 0.2, 0.55 * on), 7.0 * s)
	ci.draw_polyline(pts, Color(1.0, 0.85, 0.55, 0.85 * on), 2.4 * s)
	ci.draw_circle(target, 70.0 * s * k * flick, Color(1.0, 0.55, 0.25, 0.2 * k))
	ci.draw_circle(target, 38.0 * s * k, Color(1.0, 0.8, 0.5, 0.5 * k))
	ci.draw_circle(target, 16.0 * s * k, Color(1.0, 1.0, 0.95, k))
	for i in 12:  # sparks thrown off the surface
		var h1 := hash01(i + int(t * 30.0), 91)
		var h2 := hash01(i + int(t * 30.0), 92)
		var sp := target + Vector2((h1 - 0.5) * 110.0, -h2 * 70.0) * s
		ci.draw_circle(sp, (1.5 + 2.0 * h2) * s, Color(1.0, 0.85, 0.5, 0.8 * k))


# --- parts -------------------------------------------------------------------------------------------------

func _space(ci: CanvasItem, rect: Rect2, s: float, t: float) -> void:
	var m := 40.0
	var bands := 24
	for i in bands:
		var f := float(i) / float(bands - 1)
		ci.draw_rect(Rect2(rect.position.x - m, rect.position.y - m + (rect.size.y + m * 2.0) * float(i) / bands, rect.size.x + m * 2.0, (rect.size.y + m * 2.0) / bands + 1.0), SPACE_TOP.lerp(SPACE_LOW, f))
	for k in 90:
		var tw := 0.55 + 0.45 * sin(t * (2.0 + 3.0 * hash01(k, 97)) + float(k))
		var a := (0.3 + 0.6 * hash01(k, 98)) * tw
		ci.draw_circle(Vector2(rect.position.x + rect.size.x * hash01(k, 95), rect.position.y + rect.size.y * 0.75 * hash01(k, 96)), (0.8 + 1.4 * hash01(k, 99)) * s, Color(0.9, 0.95, 1.0, a))


func _earth(ci: CanvasItem, rect: Rect2, planet: Array, s: float, u: float) -> void:
	var c: Vector2 = planet[0]
	var r: float = planet[1]
	# the atmosphere: thin glowing shells outside the limb
	for k in 7:
		var gr := r + (6.0 + 20.0 * float(k)) * s
		ci.draw_circle(c, gr, Color(0.3, 0.6, 1.0, 0.035 + 0.01 * float(6 - k)))
	ci.draw_circle(c, r + 4.0 * s, Color(0.5, 0.8, 1.0, 0.55))
	ci.draw_circle(c, r, OCEAN)
	ci.draw_circle(c, r * 0.985, Color(0.05, 0.16, 0.32))
	# continents and cloud bands, only where they fall on the visible cap of the disc
	for k in 26:
		var x := rect.position.x + rect.size.x * hash01(k, 101)
		var dx := x - c.x
		if absf(dx) >= r * 0.97:
			continue
		var surf := c.y - sqrt(r * r - dx * dx)
		var y := surf + (14.0 + 150.0 * hash01(k, 102)) * s
		if y > rect.end.y + 40.0:
			continue
		var w := (40.0 + 150.0 * hash01(k, 103)) * s
		var cloud := hash01(k, 104) > 0.45
		var col := Color(0.92, 0.95, 1.0, 0.16 + 0.14 * hash01(k, 105)) if cloud else Color(0.1, 0.3, 0.2, 0.55)
		ci.draw_circle(Vector2(x, y), w * 0.5, col)
		ci.draw_circle(Vector2(x + w * 0.3, y + 4.0 * s), w * 0.34, col)
	# city lights on the dark side, clustered where the beam will land
	for k in 40:
		var x := rect.position.x + rect.size.x * lerpf(0.3, 0.95, hash01(k, 111))
		var dx := x - c.x
		if absf(dx) >= r * 0.97:
			continue
		var surf := c.y - sqrt(r * r - dx * dx)
		ci.draw_circle(Vector2(x, surf + (10.0 + 70.0 * hash01(k, 112)) * s), (1.0 + 1.6 * hash01(k, 113)) * s, Color(1.0, 0.85, 0.5, 0.7))
