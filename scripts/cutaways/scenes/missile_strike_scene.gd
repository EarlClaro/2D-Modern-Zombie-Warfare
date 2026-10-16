class_name MissileStrikeScene
extends CutawayScene
## Missile strike cutaway: three 8x8 transporter-erector-launchers (after the Iskander-M: 13 m chassis, a ballistic
## missile 7.3 m long) stand on a dusk plain with their jacks down. Each erects its cradle to near vertical, then the
## motors light one after another: a flash and a boiling cloud of dust and smoke at the pad, the missile lifts on a
## column of fire and a smoke trail, and the picture tilts up to follow them into the sky. The trucks and the missile
## are the generated sprites of tools/gen_cutaway_art.gd; the cradle, fire, smoke and sky are drawn here.

const TRUCK: Texture2D = preload("res://assets/cutaways/launcher.png")
const MISSILE: Texture2D = preload("res://assets/cutaways/missile.png")
## Must match tools/gen_cutaway_art.gd.
const HINGE: Vector2 = Vector2(14.0, 20.0)  # where the cradle pivots on the truck sprite
const TRUCK_FEET: Vector2 = Vector2(70.0, 44.0)  # the point of the truck that stands on the ground
const MISSILE_TAIL: Vector2 = Vector2(1.0, 6.5)
const MISSILE_LEN: float = 75.0
const CRADLE_LEN: float = 84.0  # sprite px

const SCALE: Array[float] = [2.3, 3.0, 3.8]  # far .. near
const LAG: Array[float] = [0.075, 0.0, 0.15]  # share of the clip each truck fires after the first
const FOOT_X: Array[float] = [0.3, 0.55, 0.8]
const FOOT_Y: Array[float] = [0.66, 0.78, 0.9]
const ERECT_FROM: float = 0.03
const ERECT_TO: float = 0.27
const FIRE_AT: float = 0.38  # share of the clip when the first motor lights
const ELEVATION: float = 1.42  # radians the cradle stands at (about 81 degrees)
const ACCEL: float = 820.0  # sprite px per second squared once the motor is lit
const TRAIL_STEPS: int = 30
const TRAIL_DT: float = 0.028
const CAM_FOLLOW: float = 0.6  # share of the lead missile's climb the picture tilts up by
const DESIGN_H: float = 684.0
const SHAKE_PX: float = 7.0

const SKY_TOP: Color = Color(0.03, 0.04, 0.11)
const SKY_MID: Color = Color(0.2, 0.2, 0.36)
const SKY_LOW: Color = Color(0.88, 0.46, 0.24)
const HILL_FAR: Color = Color(0.2, 0.17, 0.27)
const HILL_NEAR: Color = Color(0.12, 0.12, 0.16)
const GROUND_FAR: Color = Color(0.2, 0.22, 0.12)
const GROUND_NEAR: Color = Color(0.07, 0.08, 0.05)


var _sh: Vector2 = Vector2.ZERO  # this frame's shake, folded into every transform we set


func shake(t: float, length: float) -> Vector2:
	var after := t / maxf(length, 0.001) - FIRE_AT
	if after < 0.0:
		return Vector2.ZERO
	var amp := SHAKE_PX * minf(after * 14.0, 1.0) * exp(-after * 2.2)
	return Vector2(sin(t * 83.0) * amp, cos(t * 71.0) * amp)


func draw(ci: CanvasItem, rect: Rect2, t: float, length: float) -> void:
	var u := t / maxf(length, 0.001)
	var s := rect.size.y / DESIGN_H
	_sh = shake(t, length)
	var horizon := rect.position.y + rect.size.y * 0.5
	var cam := _camera(u, length, s, rect)
	ci.draw_set_transform(_sh, 0.0, Vector2.ONE)
	_backdrop(ci, rect, horizon + cam, s)
	var trucks: Array[Dictionary] = []
	for i in SCALE.size():
		var sc := SCALE[i] * s
		var foot := Vector2(rect.position.x + rect.size.x * FOOT_X[i], rect.position.y + rect.size.y * FOOT_Y[i] + cam)
		var fire := FIRE_AT + LAG[i]
		var tau := maxf(u - fire, 0.0) * length  # seconds since this motor lit
		trucks.append({"i": i, "sc": sc, "foot": foot, "tau": tau, "lit": u >= fire, "hinge": foot + (HINGE - TRUCK_FEET) * sc})
	for g in trucks:
		_pad_cloud(ci, g)
	for g in trucks:
		_launcher(ci, g, u)
	for g in trucks:
		_flight(ci, g, length)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# the glare of the first ignition over the whole picture
	var after := u - FIRE_AT
	if after >= 0.0:
		ci.draw_rect(rect, Color(1.0, 0.8, 0.5, 0.3 * exp(-after * 22.0)))


## How far the picture has tilted up (px the world is shifted down): it follows the climbing lead missile.
func _camera(u: float, length: float, s: float, rect: Rect2) -> float:
	var tau := maxf(u - FIRE_AT, 0.0) * length
	var climb := _climb(tau) * SCALE[1] * s
	return minf(climb * CAM_FOLLOW, rect.size.y * 1.1)


## Sprite px a missile has travelled up its rail `tau` seconds after ignition (a slow start while the motor builds).
func _climb(tau: float) -> float:
	return 0.5 * ACCEL * tau * tau


func _erect(u: float) -> float:
	return ELEVATION * smoothstep(ERECT_FROM, ERECT_TO, u)


# --- parts -------------------------------------------------------------------------------------------------

func _backdrop(ci: CanvasItem, rect: Rect2, horizon: float, s: float) -> void:
	var m := 40.0
	var left := rect.position.x - m
	var width := rect.size.x + m * 2.0
	var top := rect.position.y - m
	# the sky from the horizon glow up through dusk blue to near black, in world space so the tilt reveals the dark
	var sky_span := rect.size.y * 2.2
	var bands := 40
	var y0 := minf(top, horizon - sky_span)
	for i in bands:
		var a := horizon - sky_span * float(i + 1) / float(bands)  # band i spans [a, a + step]
		var step := sky_span / float(bands)
		if a + step < top or a > horizon:
			continue
		var f := float(i) / float(bands - 1)  # 0 at the horizon .. 1 at the top
		var col := SKY_LOW.lerp(SKY_MID, minf(f * 2.4, 1.0)).lerp(SKY_TOP, clampf((f - 0.35) / 0.65, 0.0, 1.0))
		ci.draw_rect(Rect2(left, a, width, step + 1.0), col)
	if y0 < top:
		ci.draw_rect(Rect2(left, y0, width, top - y0 + 1.0), SKY_TOP)
	# stars, only high in the sky
	for k in 40:
		var sx := rect.position.x + rect.size.x * hash01(k, 3)
		var sy := horizon - sky_span * (0.35 + 0.65 * hash01(k, 4))
		if sy > rect.position.y - 4.0 and sy < rect.end.y:
			ci.draw_circle(Vector2(sx, sy), (1.0 + hash01(k, 5)) * s, Color(1.0, 1.0, 0.95, 0.35 + 0.4 * hash01(k, 6)))
	for k in 6:
		var r := (260.0 - 38.0 * float(k)) * s
		ci.draw_circle(Vector2(rect.position.x + rect.size.x * 0.18, horizon), r, Color(1.0, 0.7, 0.35, 0.05 + 0.03 * float(k)))
	_hills(ci, rect, horizon, HILL_FAR, 0.0, 70.0 * s, 1.7, m)
	_hills(ci, rect, horizon + 6.0 * s, HILL_NEAR, 2.3, 44.0 * s, 2.6, m)
	var ground_h := rect.end.y + rect.size.y * 1.3 - horizon
	var gb := 28
	for i in gb:
		var f := float(i) / float(gb - 1)
		ci.draw_rect(Rect2(left, horizon + ground_h * float(i) / gb, width, ground_h / gb + 1.0), GROUND_FAR.lerp(GROUND_NEAR, f))


func _hills(ci: CanvasItem, rect: Rect2, base: float, col: Color, phase: float, height: float, freq: float, m: float) -> void:
	var pts := PackedVector2Array()
	var n := 32
	for i in n + 1:
		var f := float(i) / float(n)
		var y := base - height * (0.5 + 0.28 * sin(f * freq * TAU * 0.5 + phase) + 0.22 * sin(f * freq * 2.3 * TAU * 0.5 + phase * 1.7))
		pts.append(Vector2(rect.position.x - m + f * (rect.size.x + m * 2.0), y))
	pts.append(Vector2(rect.end.x + m, base + 8.0))
	pts.append(Vector2(rect.position.x - m, base + 8.0))
	ci.draw_colored_polygon(pts, col)


## The truck, the cradle at its current elevation, and the missile sitting on it until its motor lights.
func _launcher(ci: CanvasItem, g: Dictionary, u: float) -> void:
	var sc: float = g["sc"]
	var foot: Vector2 = g["foot"]
	var hinge: Vector2 = g["hinge"]
	var tau: float = g["tau"]
	ci.draw_set_transform(foot - TRUCK_FEET * sc + _sh, 0.0, Vector2(sc, sc))
	ci.draw_texture(TRUCK, Vector2.ZERO)
	var angle := _erect(u)
	ci.draw_set_transform(hinge + _sh, -angle, Vector2(sc, sc))
	# the cradle: two rails and cross members along the missile
	var rail := Color(0.2, 0.22, 0.2)
	ci.draw_rect(Rect2(-6.0, -1.0, CRADLE_LEN, 3.4), rail)
	ci.draw_rect(Rect2(-6.0, 1.2, CRADLE_LEN, 1.2), Color(0.36, 0.4, 0.36))
	for k in 4:
		ci.draw_rect(Rect2(8.0 + 22.0 * float(k), -2.0, 2.4, 6.0), rail)
	if tau <= 0.0:
		ci.draw_texture(MISSILE, Vector2(2.0, -MISSILE_TAIL.y - 1.0))
	ci.draw_set_transform(_sh, 0.0, Vector2.ONE)


## Where a missile is on screen `tau` seconds after its motor lit, and the unit vector it climbs along.
func _missile_pos(g: Dictionary, tau: float) -> Vector2:
	var sc: float = g["sc"]
	var hinge: Vector2 = g["hinge"]
	var dir := Vector2(cos(ELEVATION), -sin(ELEVATION))
	# on the cradle the tail starts 2 px along the rail; after that it just keeps climbing the same line
	return hinge + dir * (2.0 + _climb(tau)) * sc


func _flight(ci: CanvasItem, g: Dictionary, length: float) -> void:
	if not g["lit"]:
		return
	var sc: float = g["sc"]
	var tau: float = g["tau"]
	var dir := Vector2(cos(ELEVATION), -sin(ELEVATION))
	var tail := _missile_pos(g, tau)
	var i: int = g["i"]
	# the smoke trail: puffs left where the missile has been, swelling, drifting and thinning
	for k in range(TRAIL_STEPS, 0, -1):
		var back := float(k) * TRAIL_DT
		if back > tau:
			continue
		var age := back / (float(TRAIL_STEPS) * TRAIL_DT)
		var p := _missile_pos(g, tau - back) + Vector2((hash01(k + i * 40, 2) - 0.3) * 14.0 * sc * age, 4.0 * sc * age * age * 6.0)
		var r := (5.0 + 20.0 * age) * sc
		var a := 0.55 * pow(1.0 - age, 1.3)
		ci.draw_circle(p, r, Color(0.8, 0.78, 0.74, a))
		ci.draw_circle(p + Vector2(-r * 0.2, -r * 0.2), r * 0.6, Color(0.95, 0.92, 0.88, a * 0.55))
	# the missile itself, nose first up its rail
	ci.draw_set_transform(tail + _sh, -ELEVATION, Vector2(sc, sc))
	# the exhaust column: a long white-hot flame with a glow, flickering
	var flick := 0.85 + 0.15 * sin(tau * 90.0 + float(i))
	var burn := minf(tau * 10.0, 1.0)
	var flame_len := (30.0 + 60.0 * burn) * flick
	var flame := PackedVector2Array([Vector2(0.0, -4.5), Vector2(-flame_len, 0.0), Vector2(0.0, 4.5)])
	ci.draw_colored_polygon(flame, Color(1.0, 0.5, 0.12, 0.85))
	var core := PackedVector2Array([Vector2(0.0, -2.8), Vector2(-flame_len * 0.62, 0.0), Vector2(0.0, 2.8)])
	ci.draw_colored_polygon(core, Color(1.0, 0.92, 0.6, 0.95))
	ci.draw_circle(Vector2(-4.0, 0.0), 11.0, Color(1.0, 0.65, 0.25, 0.3))
	ci.draw_circle(Vector2(-2.0, 0.0), 5.5, Color(1.0, 0.95, 0.8, 0.8))
	ci.draw_texture(MISSILE, Vector2(-MISSILE_TAIL.x, -MISSILE_TAIL.y))
	ci.draw_set_transform(_sh, 0.0, Vector2.ONE)
	# a glow on the ground and around the missile while the motor is low and hot
	ci.draw_circle(tail, 46.0 * sc * burn * (1.0 - clampf(tau / (length * 0.5), 0.0, 0.8)), Color(1.0, 0.6, 0.25, 0.1))


## The cloud of dust and smoke that boils out of the pad at ignition and rolls along the ground.
func _pad_cloud(ci: CanvasItem, g: Dictionary) -> void:
	if not g["lit"]:
		return
	var sc: float = g["sc"]
	var tau: float = g["tau"]
	var life := 1.6
	if tau >= life:
		return
	var age := tau / life
	var foot: Vector2 = g["foot"]
	var i: int = g["i"]
	for p in 14:
		var h1 := hash01(p + i * 31, 11)
		var h2 := hash01(p + i * 31, 12)
		var dir_x := -1.0 if h1 < 0.5 else 1.0
		var spread := (20.0 + 130.0 * h2) * sc * (1.0 - exp(-age * 2.4))
		var pos := foot + Vector2(dir_x * spread - 30.0 * sc, -6.0 * sc - (10.0 + 36.0 * h1) * sc * age * (0.4 + h2))
		var r := (9.0 + 26.0 * age + 10.0 * h2) * sc
		var a := 0.55 * pow(1.0 - age, 1.4)
		ci.draw_circle(pos, r, Color(0.62, 0.52, 0.4, a))
		ci.draw_circle(pos + Vector2(-r * 0.22, -r * 0.2), r * 0.6, Color(0.82, 0.74, 0.62, a * 0.6))
	# a first flash at the base
	if tau < 0.18:
		var k := 1.0 - tau / 0.18
		ci.draw_circle(foot + Vector2(-28.0 * sc, -6.0 * sc), 60.0 * sc * k, Color(1.0, 0.7, 0.3, 0.5 * k))
