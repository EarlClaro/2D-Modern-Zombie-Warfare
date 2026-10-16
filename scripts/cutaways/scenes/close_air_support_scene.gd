class_name CloseAirSupportScene
extends CutawayScene
## Close air support cutaway: a flight of three F-15E Strike Eagles in echelon crosses a dusk plain, noses over into a
## dive and releases every missile (four each, AGM-65 Maverick-sized, hung under the conformal tanks). The jets pull up
## and sweep away to the right while the missiles, each on its own smoke trail, race down onto the enemy base and burst.
## The jet is the generated sprite of tools/gen_cutaway_art.gd (without its missiles); the plain, the targets, the
## missiles, trails and explosions are drawn here. Missiles are drawn about 1.5 times their real size so they read.

const JET: Texture2D = preload("res://assets/cutaways/f15e.png")
## Must match tools/gen_cutaway_art.gd.
const JET_CENTRE: Vector2 = Vector2(56.0, 26.0)
const NOZZLES: Vector2 = Vector2(1.0, 26.0)
const HARDPOINTS: Array[Vector2] = [Vector2(38.5, 35.8), Vector2(44.5, 35.8), Vector2(50.5, 35.8), Vector2(56.5, 35.8)]
const MISSILE_LEN: float = 18.75  # a Maverick is 2.5 m: 12.5 sprite px, drawn at 1.5 times that

## The flight: how far behind the leader each jet is on the same path (share of the clip), its altitude offset (share of
## the picture height) and its size (the leader is nearest the camera).
const LAG: Array[float] = [0.0, 0.09, 0.17]
const ALT: Array[float] = [0.0, -0.14, 0.12]
const SIZE: Array[float] = [1.0, 0.82, 0.68]
const DROP_AT: float = 0.44  # the leader's release; the others release at the same point of the path
const RIPPLE: float = 0.014  # share of the clip between one missile and the next off the same jet
const FLIGHT: float = 0.2  # a missile's flight time as a share of the clip
const DESIGN_H: float = 684.0
const SHAKE_PX: float = 7.0
const TARGETS: int = 12

const SKY_TOP: Color = Color(0.11, 0.14, 0.27)
const SKY_LOW: Color = Color(0.93, 0.62, 0.36)
const HILLS: Color = Color(0.2, 0.2, 0.26)
const GROUND_FAR: Color = Color(0.36, 0.33, 0.22)
const GROUND_NEAR: Color = Color(0.17, 0.16, 0.1)

var _shake: Vector2 = Vector2.ZERO


## Share of the clip at which missile number `k` of jet `j` is released and at which it lands.
static func release_at(j: int, k: int) -> float:
	return DROP_AT + LAG[j] + RIPPLE * float(k)


static func land_at(j: int, k: int) -> float:
	return release_at(j, k) + FLIGHT


func shake(t: float, length: float) -> Vector2:
	var u := t / maxf(length, 0.001)
	var amp := 1.2 if u > 0.2 and u < 0.9 else 0.0  # the rumble of the flight
	# every impact kicks the picture a little; they add up to at most SHAKE_PX
	for j in LAG.size():
		for k in HARDPOINTS.size():
			var d := u - land_at(j, k)
			if d >= 0.0 and d < 0.1:
				amp += SHAKE_PX * 0.22 * exp(-d * 30.0)
	amp = minf(amp, SHAKE_PX)
	return Vector2(sin(t * 97.0) * amp, cos(t * 83.0) * amp)


func draw(ci: CanvasItem, rect: Rect2, t: float, length: float) -> void:
	var u := t / maxf(length, 0.001)
	var s := rect.size.y / DESIGN_H
	_shake = shake(t, length)
	var horizon := rect.position.y + rect.size.y * 0.46
	var targets := _targets(rect, s)
	ci.draw_set_transform(_shake, 0.0, Vector2.ONE)
	_backdrop(ci, rect, horizon, s)
	_draw_targets(ci, targets, u, s)
	# the missiles' trails first, then the missiles, then the jets over them
	for j in LAG.size():
		for k in HARDPOINTS.size():
			_missile_trail(ci, rect, j, k, targets, u, s)
	for j in LAG.size():
		for k in HARDPOINTS.size():
			_missile(ci, rect, j, k, targets, u, s)
	for j in range(LAG.size() - 1, -1, -1):  # the far jets first, the leader in front
		_jet(ci, rect, j, u, t, s)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var first := land_at(0, 0)
	if u >= first:
		ci.draw_rect(rect, Color(1.0, 0.9, 0.7, 0.3 * exp(-(u - first) * 26.0)))


# --- the flight ----------------------------------------------------------------------------------------------

## Screen position and nose-down angle (radians, positive = nose down) of jet `j` at clip share `u`.
func jet_state(rect: Rect2, j: int, u: float) -> Dictionary:
	var lu := u - LAG[j]
	var x := rect.position.x + rect.size.x * (lerpf(0.1, 1.35, pow(maxf(lu, 0.0), 1.6)) + minf(lu, 0.0) * 0.6)
	var y := rect.size.y * (lerpf(0.26, 0.42, smoothstep(0.28, 0.46, lu)) - 0.4 * smoothstep(0.55, 0.95, lu) + ALT[j])
	var angle := 0.46 * smoothstep(0.24, 0.38, lu) * (1.0 - smoothstep(0.46, 0.6, lu)) - 0.34 * smoothstep(0.52, 0.88, lu)
	return {"pos": Vector2(x, rect.position.y + y), "angle": angle}


func _jet(ci: CanvasItem, rect: Rect2, j: int, u: float, t: float, s: float) -> void:
	var st := jet_state(rect, j, u)
	var pos: Vector2 = st["pos"]
	var angle: float = st["angle"]
	var sc := 4.2 * s * SIZE[j]
	# a faint vapour trail behind the airframe, from where it was a moment ago
	var trail := PackedVector2Array()
	for i in 10:
		trail.append((jet_state(rect, j, u - 0.014 * float(i))["pos"] as Vector2) + Vector2(-JET_CENTRE.x * sc * 0.9, 4.0 * sc))
	for i in 9:
		ci.draw_line(trail[i], trail[i + 1], Color(1.0, 1.0, 1.0, 0.22 * (1.0 - float(i) / 9.0)), 3.0 * sc)
	ci.draw_set_transform(pos + _shake, angle, Vector2(sc, sc))
	# the missiles still hanging on the pylons, until each is released
	for k in HARDPOINTS.size():
		if u < release_at(j, k):
			_draw_missile_shape(ci, HARDPOINTS[k] - JET_CENTRE, MISSILE_LEN, false)
	ci.draw_texture(JET, -JET_CENTRE)
	# the afterburner flame behind the nozzles
	var flicker := 0.75 + 0.25 * sin(t * 70.0 + float(j))
	var flame := NOZZLES - JET_CENTRE + Vector2(-1.0, 0.0)
	ci.draw_colored_polygon(PackedVector2Array([flame + Vector2(0.0, -3.5), flame + Vector2(-16.0 * flicker, 0.0), flame + Vector2(0.0, 3.5)]), Color(1.0, 0.6, 0.2, 0.85))
	ci.draw_colored_polygon(PackedVector2Array([flame + Vector2(0.0, -2.0), flame + Vector2(-9.0 * flicker, 0.0), flame + Vector2(0.0, 2.0)]), Color(1.0, 0.95, 0.7, 0.95))
	ci.draw_set_transform(_shake, 0.0, Vector2.ONE)


# --- missiles ------------------------------------------------------------------------------------------------

## The point of a missile's path at share `f` (0 release .. 1 impact): a curve that carries on along the jet's heading and
## bends down onto the target.
func _path(start: Vector2, heading: float, target: Vector2, reach: float, f: float) -> Vector2:
	var ctrl := start + Vector2(cos(heading), sin(heading)) * reach
	var a := start.lerp(ctrl, f)
	var b := ctrl.lerp(target, f)
	return a.lerp(b, f)


func _missile_geometry(rect: Rect2, j: int, k: int, targets: Array[Dictionary], s: float) -> Dictionary:
	var ur := release_at(j, k)
	var st := jet_state(rect, j, ur)
	var sc := 4.2 * s * SIZE[j]
	var start: Vector2 = (st["pos"] as Vector2) + (HARDPOINTS[k] - JET_CENTRE).rotated(st["angle"]) * sc
	var tg: Dictionary = targets[(j * HARDPOINTS.size() + k) % targets.size()]
	return {"start": start, "heading": st["angle"], "target": Vector2(tg["x"], tg["y"]), "reach": rect.size.x * 0.2, "size": SIZE[j]}


func _missile_at(g: Dictionary, f: float) -> Vector2:
	return _path(g["start"], g["heading"], g["target"], g["reach"], f)


func _missile_trail(ci: CanvasItem, rect: Rect2, j: int, k: int, targets: Array[Dictionary], u: float, s: float) -> void:
	var ur := release_at(j, k)
	if u < ur + 0.012 or u > land_at(j, k) + 0.12:
		return
	var g := _missile_geometry(rect, j, k, targets, s)
	var f := clampf((u - ur) / FLIGHT, 0.0, 1.0)
	var f0 := 0.06  # the motor lights a moment after release
	var steps := 14
	var fade_out := clampf(1.0 - (u - land_at(j, k)) / 0.12, 0.0, 1.0)
	for i in steps:
		var a := lerpf(f0, f, float(i) / steps)
		var b := lerpf(f0, f, float(i + 1) / steps)
		if b <= f0:
			continue
		var age := 1.0 - float(i) / steps
		var w := (5.0 + 9.0 * (1.0 - age) * (1.0 - age)) * s * SIZE[j]
		ci.draw_line(_missile_at(g, a), _missile_at(g, b), Color(0.9, 0.9, 0.92, 0.55 * (1.0 - age * 0.8) * fade_out), w)


func _missile(ci: CanvasItem, rect: Rect2, j: int, k: int, targets: Array[Dictionary], u: float, s: float) -> void:
	var ur := release_at(j, k)
	if u < ur or u >= land_at(j, k):
		return
	var g := _missile_geometry(rect, j, k, targets, s)
	var f := (u - ur) / FLIGHT
	var p := _missile_at(g, f)
	var q := _missile_at(g, minf(f + 0.01, 1.0))
	var ang := (q - p).angle()
	var size: float = 4.2 * s * float(g["size"]) * lerpf(1.0, 0.7, f)
	# the launch: a flash and a puff at the pylon in the first moments
	if f < 0.14:
		var k2 := 1.0 - f / 0.14
		ci.draw_circle(p, 16.0 * size * k2, Color(1.0, 0.75, 0.35, 0.5 * k2))
		ci.draw_circle(p + Vector2(-10.0, 0.0) * size, 12.0 * size * (1.0 - k2 * 0.5), Color(0.9, 0.9, 0.9, 0.4 * k2))
	ci.draw_set_transform(p + _shake, ang, Vector2(size, size))
	_draw_missile_shape(ci, Vector2.ZERO, MISSILE_LEN, f > 0.06)
	ci.draw_set_transform(_shake, 0.0, Vector2.ONE)


## A Maverick-like missile centred at `at`, nose to the right, `len` long: a body, a dark nose, cropped fins and (when the
## motor burns) a flame. Drawn in the current transform's units.
func _draw_missile_shape(ci: CanvasItem, at: Vector2, len: float, burning: bool) -> void:
	var r := len * 0.12
	ci.draw_rect(Rect2(at.x - len * 0.5, at.y - r, len * 0.8, r * 2.0), Color("c9ced2"))
	ci.draw_rect(Rect2(at.x - len * 0.5, at.y - r, len * 0.8, r * 0.7), Color("e6eaed"))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(at.x + len * 0.3, at.y - r), Vector2(at.x + len * 0.5, at.y), Vector2(at.x + len * 0.3, at.y + r)]), Color("3a4046"))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(at.x - len * 0.5, at.y - r), Vector2(at.x - len * 0.38, at.y - r), Vector2(at.x - len * 0.5, at.y - r * 2.4)]), Color("5a626a"))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(at.x - len * 0.5, at.y + r), Vector2(at.x - len * 0.38, at.y + r), Vector2(at.x - len * 0.5, at.y + r * 2.4)]), Color("5a626a"))
	if burning:
		ci.draw_colored_polygon(PackedVector2Array([Vector2(at.x - len * 0.5, at.y - r * 0.9), Vector2(at.x - len * 1.0, at.y), Vector2(at.x - len * 0.5, at.y + r * 0.9)]), Color(1.0, 0.7, 0.25, 0.95))
		ci.draw_colored_polygon(PackedVector2Array([Vector2(at.x - len * 0.5, at.y - r * 0.5), Vector2(at.x - len * 0.78, at.y), Vector2(at.x - len * 0.5, at.y + r * 0.5)]), Color(1.0, 0.97, 0.8, 1.0))


# --- the enemy base --------------------------------------------------------------------------------------------

func _targets(rect: Rect2, s: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in TARGETS:
		var f := float(i) / float(TARGETS - 1)
		var row := i % 2
		out.append({
			"x": rect.position.x + rect.size.x * (0.66 + 0.31 * f) + (hash01(i, 5) - 0.5) * 20.0 * s,
			"y": rect.position.y + rect.size.y * lerpf(0.79, 0.9, float(row)),
			"kind": 2 if i % 4 == 3 else (i % 2),
			"w": (70.0 if i % 4 != 3 else 64.0) * s * lerpf(1.0, 1.35, float(row)),
			"h": (30.0 if i % 4 != 3 else 40.0) * s * lerpf(1.0, 1.35, float(row)),
		})
	return out


func _draw_targets(ci: CanvasItem, targets: Array[Dictionary], u: float, s: float) -> void:
	for i in targets.size():
		var tg: Dictionary = targets[i]
		var j := (i / HARDPOINTS.size()) % LAG.size()
		var k := i % HARDPOINTS.size()
		var x: float = tg["x"]
		var w: float = tg["w"]
		var h: float = tg["h"]
		var base := Vector2(x - w * 0.5, float(tg["y"]) + 6.0 * s)
		var land := land_at(j, k)
		if u >= land:
			var flick := 0.7 + 0.3 * sin(u * 90.0 + float(i))
			ci.draw_rect(Rect2(base.x, base.y - h * 0.45, w, h * 0.45), Color(0.07, 0.07, 0.07))
			ci.draw_circle(base + Vector2(w * 0.5, -h * 0.6), h * 0.55 * flick, Color(1.0, 0.5, 0.15, 0.5))
			ci.draw_circle(base + Vector2(w * 0.5, -h * 0.65), h * 0.3 * flick, Color(1.0, 0.85, 0.4, 0.75))
			_explosion(ci, Vector2(x, float(tg["y"]) + 2.0 * s), (u - land) / 0.26, s, i)
			continue
		var body := Color(0.2, 0.25, 0.14)
		var dark := Color(0.15, 0.19, 0.1)
		match int(tg["kind"]):
			0:  # a truck
				ci.draw_rect(Rect2(base.x, base.y - h * 0.7, w, h * 0.5), body)
				ci.draw_rect(Rect2(base.x + w * 0.62, base.y - h, w * 0.38, h * 0.5), dark)
			1:  # a tank
				ci.draw_rect(Rect2(base.x, base.y - h * 0.6, w, h * 0.4), body)
				ci.draw_rect(Rect2(base.x + w * 0.2, base.y - h * 0.95, w * 0.5, h * 0.38), dark)
				ci.draw_rect(Rect2(base.x + w * 0.65, base.y - h * 0.85, w * 0.45, 3.0 * s), Color(0.12, 0.15, 0.09))
			_:  # a bunker
				ci.draw_rect(Rect2(base.x, base.y - h, w, h), Color(0.3, 0.3, 0.27))
				ci.draw_rect(Rect2(base.x, base.y - h, w, h * 0.2), Color(0.38, 0.38, 0.34))
				ci.draw_rect(Rect2(base.x + w * 0.15, base.y - h * 0.62, w * 0.7, h * 0.14), Color(0.07, 0.07, 0.07))
		if int(tg["kind"]) != 2:
			for q in 3:
				ci.draw_circle(Vector2(base.x + w * (0.18 + 0.32 * float(q)), base.y - h * 0.14), h * 0.19, Color(0.06, 0.06, 0.06))


func _explosion(ci: CanvasItem, at: Vector2, age: float, s: float, seed_i: int) -> void:
	if age > 1.0:
		return
	var k := 1.0 - age
	ci.draw_circle(at + Vector2(0.0, -16.0 * s * age), (26.0 + 46.0 * age) * s, Color(1.0, 0.45, 0.12, 0.5 * k * k))
	ci.draw_circle(at + Vector2(0.0, -26.0 * s * age), (18.0 + 28.0 * age) * s, Color(1.0, 0.75, 0.3, 0.75 * k))
	if age < 0.25:
		ci.draw_circle(at + Vector2(0.0, -10.0 * s), (24.0 + 34.0 * age) * s, Color(1.0, 0.97, 0.85, 1.0 - age * 3.0))
	for i in 5:
		var h := hash01(i + seed_i * 9, 71)
		ci.draw_circle(at + Vector2((h - 0.5) * 60.0 * s * age, -(24.0 + 90.0 * age * (0.5 + h)) * s), (10.0 + 22.0 * age * (0.6 + h)) * s, Color(0.14, 0.12, 0.12, 0.55 * k))
	for i in 6:
		var h := hash01(i + seed_i * 5, 72)
		var d := (h - 0.5) * 170.0 * s * age
		ci.draw_circle(at + Vector2(d, -(80.0 * h * age - 110.0 * age * age) * s), 2.2 * s, Color(1.0, 0.8, 0.4, k))


# --- backdrop ----------------------------------------------------------------------------------------------------

func _backdrop(ci: CanvasItem, rect: Rect2, horizon: float, s: float) -> void:
	var m := 40.0
	var top := rect.position.y - m
	var bands := 28
	var sky_h := horizon - top
	for i in bands:
		var f := float(i) / float(bands - 1)
		ci.draw_rect(Rect2(rect.position.x - m, top + sky_h * float(i) / bands, rect.size.x + m * 2.0, sky_h / bands + 1.0), SKY_TOP.lerp(SKY_LOW, f * f))
	for q in 6:
		ci.draw_circle(Vector2(rect.position.x + rect.size.x * 0.82, horizon), (230.0 - 34.0 * float(q)) * s, Color(1.0, 0.75, 0.4, 0.05 + 0.03 * float(q)))
	var pts := PackedVector2Array()
	var n := 30
	for i in n + 1:
		var f := float(i) / float(n)
		pts.append(Vector2(rect.position.x - m + f * (rect.size.x + m * 2.0), horizon - maxf(10.0, 30.0 + 40.0 * sin(f * 5.0 + 1.0) * sin(f * 3.0) + 14.0 * sin(f * 13.0)) * s))
	pts.append(Vector2(rect.end.x + m, horizon + 6.0))
	pts.append(Vector2(rect.position.x - m, horizon + 6.0))
	ci.draw_colored_polygon(pts, HILLS)
	var h := rect.end.y + m - horizon
	for i in bands:
		var f := float(i) / float(bands - 1)
		ci.draw_rect(Rect2(rect.position.x - m, horizon + h * float(i) / bands, rect.size.x + m * 2.0, h / bands + 1.0), GROUND_FAR.lerp(GROUND_NEAR, f))
	var road_y := rect.position.y + rect.size.y * 0.86
	ci.draw_rect(Rect2(rect.position.x - m, road_y - 4.0 * s, rect.size.x + m * 2.0, 22.0 * s), Color(0.28, 0.24, 0.17))
	ci.draw_rect(Rect2(rect.position.x - m, road_y - 4.0 * s, rect.size.x + m * 2.0, 2.0 * s), Color(0.4, 0.35, 0.25))
	for i in 26:
		var bx := rect.position.x + rect.size.x * hash01(i, 61)
		var by := horizon + h * (0.1 + 0.55 * hash01(i, 62))
		ci.draw_rect(Rect2(bx, by, (8.0 + 14.0 * hash01(i, 63)) * s, (3.0 + 4.0 * hash01(i, 64)) * s), Color(0.15, 0.2, 0.1, 0.85))
