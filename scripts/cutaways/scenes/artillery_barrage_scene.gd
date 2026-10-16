class_name ArtilleryBarrageScene
extends CutawayScene
## Artillery barrage cutaway: a battery of howitzers lined up on a ridge at dusk, all laid on the target. At one
## instant every gun fires together: barrels recoil, muzzle flashes, shells streak away, smoke and dust roll across the
## ground, the picture shakes. The guns are the generated sprites of tools/gen_cutaway_art.gd (a body and a separate
## barrel so the barrel can slide back); everything else is drawn here.

const BODY: Texture2D = preload("res://assets/cutaways/howitzer_body.png")
const BARREL: Texture2D = preload("res://assets/cutaways/howitzer_barrel.png")
## Must match tools/gen_cutaway_art.gd.
const BODY_PIVOT: Vector2 = Vector2(40.0, 15.0)
const BARREL_PIVOT: Vector2 = Vector2(5.0, 5.0)
const MUZZLE_X: float = 58.0
const BODY_FEET: Vector2 = Vector2(28.0, 43.0)  # the point of the body that stands on the ground

const GUNS: int = 6
const FIRE_AT: float = 0.32  # share of the clip at which the whole battery fires
const ELEVATION: float = 0.42  # radians the barrels point up
const RECOIL_PX: float = 9.0  # sprite pixels the barrel slides back
const RECOIL_OUT: float = 0.05
const RECOIL_BACK: float = 0.35
const FLASH_LEN: float = 0.14  # share of the clip the muzzle flash lasts
const DESIGN_H: float = 684.0  # picture height the sizes below are tuned for
const SHAKE_PX: float = 9.0
const SMOKE_PUFFS: int = 6

const SKY_TOP: Color = Color(0.09, 0.11, 0.21)
const SKY_LOW: Color = Color(0.88, 0.46, 0.24)
const HILL_FAR: Color = Color(0.2, 0.17, 0.27)
const HILL_NEAR: Color = Color(0.12, 0.12, 0.16)
const GROUND_FAR: Color = Color(0.2, 0.22, 0.12)
const GROUND_NEAR: Color = Color(0.07, 0.08, 0.05)

var _shake: Vector2 = Vector2.ZERO


func shake(t: float, length: float) -> Vector2:
	var after := t / maxf(length, 0.001) - FIRE_AT
	if after < 0.0:
		return Vector2(-t * 6.0, 0.0)  # a slow pan before the volley
	var decay := exp(-after * 14.0)
	return Vector2(sin(t * 91.0) * SHAKE_PX * decay, cos(t * 77.0) * SHAKE_PX * decay)


func draw(ci: CanvasItem, rect: Rect2, t: float, length: float) -> void:
	var u := t / maxf(length, 0.001)
	var after := u - FIRE_AT  # share of the clip since the volley (negative before it)
	_shake = shake(t, length)
	var s := rect.size.y / DESIGN_H
	var horizon := rect.position.y + rect.size.y * 0.5
	ci.draw_set_transform(_shake, 0.0, Vector2.ONE)
	_backdrop(ci, rect, horizon, s)
	var dir := Vector2(cos(ELEVATION), -sin(ELEVATION))
	var recoil := _recoil(after)
	var guns: Array[Dictionary] = []
	for i in GUNS:
		var near := float(i) / float(GUNS - 1)  # 0 far .. 1 near
		var sc := lerpf(2.4, 5.2, near) * s
		var foot := Vector2(rect.position.x + rect.size.x * lerpf(0.12, 0.52, near), rect.position.y + rect.size.y * lerpf(0.58, 0.88, near))
		guns.append({"near": near, "sc": sc, "foot": foot, "pivot": foot + (BODY_PIVOT - BODY_FEET) * sc})
	# ground dust first, under the guns
	if after >= 0.0:
		for g in guns:
			_dust(ci, g, after * length)
	for g in guns:
		_gun(ci, g, dir, recoil)
	for g in guns:
		_volley_effects(ci, g, dir, recoil, after, length)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if after >= 0.0:
		var flash := exp(-after * 34.0)
		ci.draw_rect(rect, Color(1.0, 0.92, 0.75, 0.42 * flash))


# --- parts -------------------------------------------------------------------------------------------------

func _backdrop(ci: CanvasItem, rect: Rect2, horizon: float, s: float) -> void:
	var m := 40.0  # drawn past the edges so the shake never shows a border
	var top := rect.position.y - m
	var bands := 28
	var sky_h := horizon - top
	for i in bands:
		var f := float(i) / float(bands - 1)
		ci.draw_rect(Rect2(rect.position.x - m, top + sky_h * float(i) / bands, rect.size.x + m * 2.0, sky_h / bands + 1.0), SKY_TOP.lerp(SKY_LOW, f * f))
	# the low sun, a soft glow on the horizon at the left
	for k in 6:
		var r := (260.0 - 38.0 * float(k)) * s
		ci.draw_circle(Vector2(rect.position.x + rect.size.x * 0.18, horizon), r, Color(1.0, 0.7, 0.35, 0.05 + 0.03 * float(k)))
	_hills(ci, rect, horizon, HILL_FAR, 0.0, 70.0 * s, 1.7, m)
	_hills(ci, rect, horizon + 6.0 * s, HILL_NEAR, 2.3, 44.0 * s, 2.6, m)
	var ground_h := rect.end.y + m - horizon
	for i in bands:
		var f := float(i) / float(bands - 1)
		ci.draw_rect(Rect2(rect.position.x - m, horizon + ground_h * float(i) / bands, rect.size.x + m * 2.0, ground_h / bands + 1.0), GROUND_FAR.lerp(GROUND_NEAR, f))


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


func _recoil(after: float) -> float:
	if after < 0.0:
		return 0.0
	if after < RECOIL_OUT:
		return RECOIL_PX * (after / RECOIL_OUT)
	return RECOIL_PX * clampf(1.0 - (after - RECOIL_OUT) / RECOIL_BACK, 0.0, 1.0)


func _gun(ci: CanvasItem, g: Dictionary, dir: Vector2, recoil: float) -> void:
	var sc: float = g["sc"]
	var foot: Vector2 = g["foot"]
	var pivot: Vector2 = g["pivot"]
	# the barrel first, so the housing and shield sit in front of the breech
	ci.draw_set_transform(pivot + _shake, -ELEVATION, Vector2(sc, sc))
	ci.draw_texture(BARREL, -BARREL_PIVOT + Vector2(-recoil, 0.0))
	ci.draw_set_transform(foot - BODY_FEET * sc + _shake, 0.0, Vector2(sc, sc))
	ci.draw_texture(BODY, Vector2.ZERO)
	ci.draw_set_transform(_shake, 0.0, Vector2.ONE)


func _muzzle(g: Dictionary, dir: Vector2, recoil: float) -> Vector2:
	return (g["pivot"] as Vector2) + dir * (MUZZLE_X - BARREL_PIVOT.x - recoil) * float(g["sc"])


func _volley_effects(ci: CanvasItem, g: Dictionary, dir: Vector2, recoil: float, after: float, length: float) -> void:
	if after < 0.0:
		return
	var sc: float = g["sc"]
	var seconds := after * length
	var m0 := _muzzle(g, dir, 0.0)
	var side := Vector2(-dir.y, dir.x)
	# the muzzle flash: a hot core, a cone along the shot and a glow
	if after < FLASH_LEN:
		var k := 1.0 - after / FLASH_LEN
		var mz := _muzzle(g, dir, recoil)
		ci.draw_circle(mz, 21.0 * sc * k, Color(1.0, 0.55, 0.2, 0.28 * k))
		ci.draw_circle(mz, 11.0 * sc * k, Color(1.0, 0.8, 0.4, 0.6 * k))
		var cone := PackedVector2Array([mz + dir * 46.0 * sc * k, mz + side * 11.0 * sc * k, mz - dir * 6.0 * sc, mz - side * 11.0 * sc * k])
		ci.draw_colored_polygon(cone, Color(1.0, 0.92, 0.6, 0.95 * k))
		var up := PackedVector2Array([mz + side.rotated(0.5) * 30.0 * sc * k, mz + dir * 6.0 * sc, mz - side.rotated(0.5) * 30.0 * sc * k, mz - dir * 4.0 * sc])
		ci.draw_colored_polygon(up, Color(1.0, 0.7, 0.3, 0.6 * k))
		ci.draw_circle(mz, 6.0 * sc * k, Color(1.0, 1.0, 0.92, k))
	# the shell, a bright streak that races away along the barrel
	var travel := seconds * 3200.0 * sc
	var head := m0 + dir * travel
	var tail := m0 + dir * maxf(travel - 70.0 * sc, 0.0)
	var shell_a := clampf(1.0 - seconds / 0.22, 0.0, 1.0)
	if shell_a > 0.0:
		ci.draw_line(tail, head, Color(1.0, 0.85, 0.55, 0.5 * shell_a), 5.0 * sc)
		ci.draw_line(tail.lerp(head, 0.4), head, Color(1.0, 0.97, 0.85, shell_a), 2.4 * sc)
	# smoke rolling off the muzzle: puffs drift forward and up, swell and thin out
	var life := 1.3
	if seconds < life:
		for p in SMOKE_PUFFS:
			var h1 := hash01(p + int(float(g["near"]) * 97.0), 1)
			var h2 := hash01(p + int(float(g["near"]) * 97.0), 2)
			var age := seconds / life
			var spread := 0.4 + 0.9 * h1
			var pos := m0 + dir * (30.0 + 110.0 * h1) * sc * (1.0 - exp(-age * 1.6)) + Vector2(18.0 * h2 * sc * age, -70.0 * sc * age * (0.5 + h2))
			var r := (6.0 + 22.0 * age * spread + 6.0 * h2) * sc
			var a := 0.5 * pow(1.0 - age, 1.6)
			ci.draw_circle(pos, r, Color(0.78, 0.74, 0.68, a))
			ci.draw_circle(pos + Vector2(-r * 0.25, -r * 0.2), r * 0.62, Color(0.9, 0.86, 0.8, a * 0.6))


## Dust kicked up around a gun's carriage and spade, rolling out along the ground.
func _dust(ci: CanvasItem, g: Dictionary, seconds: float) -> void:
	var sc: float = g["sc"]
	var foot: Vector2 = g["foot"]
	var life := 1.1
	if seconds >= life:
		return
	var age := seconds / life
	for p in 7:
		var h := hash01(p + int(float(g["near"]) * 53.0), 7)
		var dx := (h - 0.35) * 140.0 * sc * (1.0 - exp(-age * 2.6))
		var pos := foot + Vector2(dx - 16.0 * sc, -3.0 * sc - 20.0 * sc * age * (0.4 + h))
		var r := (6.0 + 16.0 * age + 6.0 * h) * sc
		ci.draw_circle(pos, r, Color(0.6, 0.5, 0.38, 0.3 * pow(1.0 - age, 1.4)))
