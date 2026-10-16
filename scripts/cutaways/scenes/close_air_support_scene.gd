class_name CloseAirSupportScene
extends CutawayScene
## Close air support cutaway: an A-10 Thunderbolt II makes a diving pass over a column of enemy vehicles. It comes in
## from the left, opens up with the 30 mm cannon (muzzle fire, a stream of tracers, dirt kicked up along the ground
## ahead of it), releases two bombs, and pulls up as they hit. The jet is the generated sprite of
## tools/gen_cutaway_art.gd; the dusk plain, the vehicles, tracers, bombs and explosions are drawn here.

const JET: Texture2D = preload("res://assets/cutaways/a10.png")
## Must match tools/gen_cutaway_art.gd.
const JET_NOSE: Vector2 = Vector2(110.0, 23.5)  # the muzzle end of the cannon, in sprite px
const JET_CENTRE: Vector2 = Vector2(56.0, 20.0)
const BOMB_BAYS: Array[Vector2] = [Vector2(42.0, 33.0), Vector2(54.0, 33.0)]  # where the two bombs hang

const GUN_FROM: float = 0.14  # the cannon fires between these shares of the clip
const GUN_TO: float = 0.5
const DROP_AT: float = 0.46
const HIT_AT: float = 0.64  # the first bomb lands; the second 0.03 later
const DESIGN_H: float = 684.0
const SHAKE_PX: float = 7.0

const SKY_TOP: Color = Color(0.11, 0.14, 0.27)
const SKY_LOW: Color = Color(0.93, 0.62, 0.36)
const HILLS: Color = Color(0.2, 0.2, 0.26)
const GROUND_FAR: Color = Color(0.36, 0.33, 0.22)
const GROUND_NEAR: Color = Color(0.17, 0.16, 0.1)

var _shake: Vector2 = Vector2.ZERO


func shake(t: float, length: float) -> Vector2:
	var u := t / maxf(length, 0.001)
	var hit := u - HIT_AT
	var amp := 0.0
	if hit >= 0.0:
		amp = SHAKE_PX * exp(-hit * 12.0)
	elif u > GUN_FROM and u < GUN_TO:
		amp = 2.0  # the cannon shakes the camera a little too
	return Vector2(sin(t * 97.0) * amp, cos(t * 83.0) * amp)


func draw(ci: CanvasItem, rect: Rect2, t: float, length: float) -> void:
	var u := t / maxf(length, 0.001)
	var s := rect.size.y / DESIGN_H
	_shake = shake(t, length)
	var horizon := rect.position.y + rect.size.y * 0.46
	var ground_y := rect.position.y + rect.size.y * 0.84
	ci.draw_set_transform(_shake, 0.0, Vector2.ONE)
	_backdrop(ci, rect, horizon, s)
	var convoy := _convoy(rect, ground_y, s)
	_draw_convoy(ci, convoy, ground_y, s, u)
	# the jet's path: in from the left, descending into the gun run, then pulling up and away to the right
	var sc := 5.2 * s
	var pos := _jet_position(rect, ground_y, u)
	var angle := _jet_angle(u)
	var nose := pos + (JET_NOSE - JET_CENTRE).rotated(angle) * sc
	# gun run: tracers and the dirt they kick up, under the jet
	if u >= GUN_FROM and u <= GUN_TO + 0.06:
		_gun_run(ci, rect, ground_y, nose, angle, t, u, s)
	ci.draw_set_transform(pos + _shake, angle, Vector2(sc, sc))
	ci.draw_texture(JET, -JET_CENTRE)
	ci.draw_set_transform(_shake, 0.0, Vector2.ONE)
	_exhaust(ci, pos, angle, sc, t)
	if u >= GUN_FROM and u <= GUN_TO:
		_muzzle_fire(ci, nose, angle, sc, t)
	_bombs(ci, pos, angle, sc, ground_y, convoy, u, s)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var hit := u - HIT_AT
	if hit >= 0.0:
		ci.draw_rect(rect, Color(1.0, 0.9, 0.7, 0.45 * exp(-hit * 26.0)))


func _jet_position(rect: Rect2, ground_y: float, u: float) -> Vector2:
	var x := rect.position.x + rect.size.x * lerpf(-0.12, 1.15, pow(u, 1.15))
	var dive := smoothstep(0.0, 0.5, u)
	var pull := smoothstep(0.55, 0.85, u)
	var y := lerpf(rect.position.y + rect.size.y * 0.2, ground_y - rect.size.y * 0.3, dive) - pull * rect.size.y * 0.42
	return Vector2(x, y)


func _jet_angle(u: float) -> float:
	var dive := smoothstep(0.0, 0.35, u) * (1.0 - smoothstep(0.45, 0.62, u))
	var pull := smoothstep(0.55, 0.85, u)
	return 0.2 * dive - 0.3 * pull


# --- backdrop and targets -------------------------------------------------------------------------------------

func _backdrop(ci: CanvasItem, rect: Rect2, horizon: float, s: float) -> void:
	var m := 40.0
	var top := rect.position.y - m
	var bands := 28
	var sky_h := horizon - top
	for i in bands:
		var f := float(i) / float(bands - 1)
		ci.draw_rect(Rect2(rect.position.x - m, top + sky_h * float(i) / bands, rect.size.x + m * 2.0, sky_h / bands + 1.0), SKY_TOP.lerp(SKY_LOW, f * f))
	for k in 6:
		ci.draw_circle(Vector2(rect.position.x + rect.size.x * 0.82, horizon), (230.0 - 34.0 * float(k)) * s, Color(1.0, 0.75, 0.4, 0.05 + 0.03 * float(k)))
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
	# a dirt road the convoy drives along, and low scrub
	var road_y := rect.position.y + rect.size.y * 0.84
	ci.draw_rect(Rect2(rect.position.x - m, road_y - 4.0 * s, rect.size.x + m * 2.0, 16.0 * s), Color(0.28, 0.24, 0.17))
	ci.draw_rect(Rect2(rect.position.x - m, road_y - 4.0 * s, rect.size.x + m * 2.0, 2.0 * s), Color(0.4, 0.35, 0.25))
	for i in 26:
		var bx := rect.position.x + rect.size.x * hash01(i, 61)
		var by := horizon + h * (0.1 + 0.55 * hash01(i, 62))
		ci.draw_rect(Rect2(bx, by, (8.0 + 14.0 * hash01(i, 63)) * s, (3.0 + 4.0 * hash01(i, 64)) * s), Color(0.15, 0.2, 0.1, 0.85))


## The enemy column on the road: x positions (screen px) and sizes of the vehicles.
func _convoy(rect: Rect2, _ground_y: float, s: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in 4:
		out.append({"x": rect.position.x + rect.size.x * (0.58 + 0.095 * float(i)), "w": (74.0 - 6.0 * float(i % 2)) * s * 1.6, "h": 34.0 * s * 1.6, "kind": i % 2})
	return out


func _draw_convoy(ci: CanvasItem, convoy: Array[Dictionary], ground_y: float, s: float, u: float) -> void:
	for i in convoy.size():
		var v: Dictionary = convoy[i]
		var x: float = v["x"]
		var w: float = v["w"]
		var h: float = v["h"]
		var destroyed := u >= HIT_AT + 0.015 * float(i % 2) + (0.03 if i >= 2 else 0.0)
		var base := Vector2(x, ground_y + 6.0 * s)
		if destroyed:
			# a burnt-out hulk with flames
			ci.draw_rect(Rect2(base.x, base.y - h * 0.6, w, h * 0.6), Color(0.07, 0.07, 0.07))
			var flick := 0.7 + 0.3 * sin(u * 90.0 + float(i))
			ci.draw_circle(base + Vector2(w * 0.5, -h * 0.7), h * 0.5 * flick, Color(1.0, 0.5, 0.15, 0.55))
			ci.draw_circle(base + Vector2(w * 0.5, -h * 0.75), h * 0.28 * flick, Color(1.0, 0.85, 0.4, 0.8))
			continue
		var body := Color(0.2, 0.25, 0.14)
		ci.draw_rect(Rect2(base.x, base.y - h * 0.7, w, h * 0.5), body)  # the hull / box
		if int(v["kind"]) == 0:
			ci.draw_rect(Rect2(base.x + w * 0.62, base.y - h, w * 0.38, h * 0.5), Color(0.17, 0.21, 0.12))  # a truck cab
		else:
			ci.draw_rect(Rect2(base.x + w * 0.2, base.y - h * 0.98, w * 0.5, h * 0.3), Color(0.17, 0.21, 0.12))  # a turret
			ci.draw_rect(Rect2(base.x + w * 0.65, base.y - h * 0.9, w * 0.4, 3.0 * s), Color(0.12, 0.15, 0.09))  # a gun
		for k in 3:
			ci.draw_circle(Vector2(base.x + w * (0.18 + 0.32 * float(k)), base.y - h * 0.14), h * 0.19, Color(0.06, 0.06, 0.06))


# --- the jet and its weapons --------------------------------------------------------------------------------

func _exhaust(ci: CanvasItem, pos: Vector2, angle: float, sc: float, t: float) -> void:
	var back := pos + (Vector2(62.0, 12.0) - JET_CENTRE).rotated(angle) * sc
	for i in 5:
		var k := float(i)
		var wob := sin(t * 40.0 + k) * 1.5 * sc
		ci.draw_circle(back + Vector2(-k * 7.0 * sc, wob).rotated(angle), (3.2 + k * 1.2) * sc * 0.6, Color(1.0, 0.7, 0.35, 0.28 - k * 0.05))


func _muzzle_fire(ci: CanvasItem, nose: Vector2, angle: float, sc: float, t: float) -> void:
	var dir := Vector2.RIGHT.rotated(angle)
	var side := Vector2(-dir.y, dir.x)
	var pulse := 0.55 + 0.45 * sin(t * 190.0)
	ci.draw_circle(nose, 9.0 * sc * pulse, Color(1.0, 0.6, 0.2, 0.4))
	var tip := nose + dir * 16.0 * sc * pulse
	ci.draw_colored_polygon(PackedVector2Array([tip, nose + side * 4.0 * sc, nose - dir * 2.0 * sc]), Color(1.0, 0.92, 0.6, 0.95))
	ci.draw_colored_polygon(PackedVector2Array([tip, nose - dir * 2.0 * sc, nose - side * 4.0 * sc]), Color(1.0, 0.92, 0.6, 0.95))
	# gun smoke streaming back along the airframe
	for i in 6:
		var k := float(i) / 5.0
		ci.draw_circle(nose - dir * (14.0 + 40.0 * k) * sc + side * sin(t * 30.0 + float(i)) * 2.0 * sc, (4.0 + 7.0 * k) * sc, Color(0.78, 0.74, 0.7, 0.3 * (1.0 - k * 0.6)))


func _gun_run(ci: CanvasItem, rect: Rect2, ground_y: float, nose: Vector2, angle: float, t: float, u: float, s: float) -> void:
	# a stream of tracers from the nose to a point on the ground that sweeps toward the convoy
	var f := clampf((u - GUN_FROM) / (GUN_TO - GUN_FROM), 0.0, 1.0)
	var aim_x := lerpf(nose.x + rect.size.x * 0.22, rect.position.x + rect.size.x * 0.86, f)
	var aim := Vector2(aim_x, ground_y + 4.0 * s)
	var firing := u <= GUN_TO
	if firing:
		for i in 14:
			var k := fposmod(float(i) / 14.0 + t * 7.0, 1.0)
			var p0 := nose.lerp(aim, k)
			var p1 := nose.lerp(aim, minf(k + 0.035, 1.0))
			ci.draw_line(p0, p1, Color(1.0, 0.75, 0.35, 0.9 * (1.0 - k * 0.4)), 5.0 * s + 1.0)
			ci.draw_line(p0, p1, Color(1.0, 0.97, 0.85, 0.95), 2.0)
	# the strike on the ground: dirt thrown up in a line that trails behind the aim point
	var trail := 7
	for i in trail:
		var k := float(i) / float(trail)
		var x := aim_x - k * rect.size.x * 0.2 * minf(f * 3.0, 1.0)
		var age := k
		var fade := (1.0 - age) * (1.0 if firing else clampf(1.0 - (u - GUN_TO) / 0.06, 0.0, 1.0))
		ci.draw_circle(Vector2(x, ground_y + 2.0 * s - 12.0 * s * age), (7.0 + 14.0 * age) * s, Color(0.55, 0.45, 0.3, 0.55 * fade))
		ci.draw_circle(Vector2(x, ground_y - 4.0 * s - 18.0 * s * age), (4.0 + 7.0 * age) * s, Color(1.0, 0.8, 0.45, 0.5 * fade * (1.0 - age)))


func _bombs(ci: CanvasItem, jet_pos: Vector2, angle: float, sc: float, ground_y: float, convoy: Array[Dictionary], u: float, s: float) -> void:
	if u < DROP_AT:  # still hanging under the wing, nose forward
		for i in BOMB_BAYS.size():
			ci.draw_set_transform(jet_pos + (BOMB_BAYS[i] + Vector2(1.0, 0.0) - JET_CENTRE).rotated(angle) * sc + _shake, angle, Vector2(sc * 0.9, sc * 0.9))
			ci.draw_rect(Rect2(-6.0, -2.5, 13.0, 5.0), Color("4a5a32"))
			ci.draw_rect(Rect2(-9.0, -3.0, 4.0, 6.0), Color("2a3036"))
		ci.draw_set_transform(_shake, 0.0, Vector2.ONE)
		return
	for i in BOMB_BAYS.size():
		var land_at := HIT_AT + 0.03 * float(i)
		var target_x: float = convoy[i * 2]["x"] + float(convoy[i * 2]["w"]) * 0.5
		if u < land_at:
			# falls from where it was released to the target, a little ahead of the jet
			var f := (u - DROP_AT) / (land_at - DROP_AT)
			var start := jet_pos + (BOMB_BAYS[i] - JET_CENTRE).rotated(0.2) * sc
			var p := Vector2(lerpf(start.x, target_x, f), lerpf(start.y, ground_y + 4.0 * s, f * f))
			var tilt := lerpf(0.1, 1.2, f)
			ci.draw_set_transform(p + _shake, tilt, Vector2(sc * 0.9, sc * 0.9))
			ci.draw_rect(Rect2(-7.0, -2.5, 14.0, 5.0), Color("4a5a32"))
			ci.draw_rect(Rect2(-10.0, -3.0, 4.0, 6.0), Color("2a3036"))
			ci.draw_set_transform(_shake, 0.0, Vector2.ONE)
		else:
			_explosion(ci, Vector2(target_x, ground_y + 2.0 * s), (u - land_at) / 0.3, s, i)


func _explosion(ci: CanvasItem, at: Vector2, age: float, s: float, seed_i: int) -> void:
	if age > 1.0:
		return
	var k := 1.0 - age
	ci.draw_circle(at + Vector2(0.0, -16.0 * s * age), (54.0 + 90.0 * age) * s, Color(1.0, 0.45, 0.12, 0.5 * k * k))
	ci.draw_circle(at + Vector2(0.0, -26.0 * s * age), (36.0 + 54.0 * age) * s, Color(1.0, 0.75, 0.3, 0.75 * k))
	if age < 0.25:
		ci.draw_circle(at + Vector2(0.0, -10.0 * s), (46.0 + 60.0 * age) * s, Color(1.0, 0.97, 0.85, 1.0 - age * 3.0))
	# the column of smoke and the flying debris
	for i in 6:
		var h := hash01(i + seed_i * 9, 71)
		ci.draw_circle(at + Vector2((h - 0.5) * 60.0 * s * age, -(40.0 + 120.0 * age * (0.5 + h)) * s), (18.0 + 36.0 * age * (0.6 + h)) * s, Color(0.14, 0.12, 0.12, 0.6 * k))
	for i in 8:
		var h := hash01(i + seed_i * 5, 72)
		var d := (h - 0.5) * 200.0 * s * age
		ci.draw_circle(at + Vector2(d, -(90.0 * h * age - 120.0 * age * age) * s), 2.5 * s, Color(1.0, 0.8, 0.4, k))
