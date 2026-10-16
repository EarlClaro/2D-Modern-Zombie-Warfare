class_name NavalGunfireScene
extends CutawayScene
## Naval gunfire cutaway: an Iowa-class battleship at dusk, seen from the side, training its three triple 16-inch
## turrets away from us toward a shore on the horizon. The barrels rise during the first part of the clip, then all
## nine fire together: the muzzles erupt, the ship heels and shakes, smoke rolls up over the deck, the shells climb
## away toward the coast, and flashes bloom on the shore. The ship is the generated sprite of tools/gen_cutaway_art.gd
## (without barrels); the barrels, sea, sky, shore and effects are drawn here. Seen from the side the guns point away,
## so each barrel shows as a short stub rising from behind its turret roof.

const SHIP: Texture2D = preload("res://assets/cutaways/battleship.png")
## Must match tools/gen_cutaway_art.gd.
const SHIP_W: float = 384.0
const WATERLINE_Y: float = 100.0
const SHIP_PIVOT: Vector2 = Vector2(192.0, 100.0)  # the ship heels about the middle of its waterline
## Turret centres and the height of their gun ports, in ship sprite pixels (turret 2 stands on a raised barbette).
const TURRETS: Array[Vector2] = [Vector2(311.0, 69.0), Vector2(273.0, 55.0), Vector2(62.0, 69.0)]
const BARREL_SPACING: float = 9.0

const FIRE_AT: float = 0.28
const RAISE_FROM: float = 10.0  # barrel stub height (px) at the start of the clip, while the guns are still being laid
const RAISE_TO: float = 18.0
const RECOIL_PX: float = 6.0
const HEEL: float = 0.014  # radians the ship rolls over on firing
const FLASH_LEN: float = 0.12
const DESIGN_H: float = 684.0
const SHAKE_PX: float = 8.0

const SKY_TOP: Color = Color(0.08, 0.1, 0.2)
const SKY_LOW: Color = Color(0.92, 0.5, 0.26)
const SEA_FAR: Color = Color(0.36, 0.3, 0.34)
const SEA_NEAR: Color = Color(0.05, 0.1, 0.17)
const SHORE: Color = Color(0.09, 0.09, 0.13)

var _shake: Vector2 = Vector2.ZERO


func shake(t: float, length: float) -> Vector2:
	var after := t / maxf(length, 0.001) - FIRE_AT
	if after < 0.0:
		return Vector2(-t * 5.0, sin(t * 3.1) * 1.5)  # a slow pan and the ship's gentle pitch
	var decay := exp(-after * 11.0)
	return Vector2(sin(t * 83.0) * SHAKE_PX * decay, cos(t * 71.0) * SHAKE_PX * decay)


func draw(ci: CanvasItem, rect: Rect2, t: float, length: float) -> void:
	var u := t / maxf(length, 0.001)
	var after := u - FIRE_AT
	var s := rect.size.y / DESIGN_H
	_shake = shake(t, length)
	var horizon := rect.position.y + rect.size.y * 0.5
	var water_y := rect.position.y + rect.size.y * 0.82
	var sc := rect.size.x / 400.0
	ci.draw_set_transform(_shake, 0.0, Vector2.ONE)
	_sky_and_shore(ci, rect, horizon, s, u)
	_sea(ci, rect, horizon, t, s)
	# the ship: heels on the shot, with the barrels behind it so only the stubs above the roofs show
	var heel := 0.0
	if after >= 0.0:
		heel = HEEL * exp(-after * 9.0) * cos(after * 22.0)
	var pivot_screen := Vector2(rect.position.x + rect.size.x * 0.5, water_y)
	var tilt := Vector2(0.0, sin(t * 3.1) * 1.5 * s)  # pitching with the swell
	ci.draw_set_transform(pivot_screen + _shake + tilt, heel, Vector2(sc, sc))
	var raise := lerpf(RAISE_FROM, RAISE_TO, smoothstep(0.0, FIRE_AT, u))
	var recoil := _recoil(after)
	var muzzles: Array[Vector2] = []  # in ship-local px, relative to the pivot
	for tur in TURRETS:
		for b in [-1, 0, 1]:
			var base := Vector2(tur.x + float(b) * BARREL_SPACING, tur.y) - SHIP_PIVOT
			var tip := base + Vector2(4.0, -(raise - recoil))
			ci.draw_line(base, tip, Color("12140f"), 5.0)
			ci.draw_line(base, tip, Color("4a5560"), 3.0)
			ci.draw_line(base + Vector2(-0.8, 0.0), tip + Vector2(-0.8, 0.0), Color("7a8791"), 1.0)
			ci.draw_rect(Rect2(tip.x - 2.5, tip.y - 2.0, 5.0, 3.0), Color("2a3036"))  # muzzle ring
			muzzles.append(tip + Vector2(0.0, -2.0))
	ci.draw_texture(SHIP, -SHIP_PIVOT)
	ci.draw_set_transform(_shake, 0.0, Vector2.ONE)
	_wake(ci, rect, water_y, sc, t, s)
	# fire: flashes, shells, smoke, shore hits
	if after >= 0.0:
		var to_screen := func(p: Vector2) -> Vector2: return (pivot_screen + p.rotated(heel) * sc)
		for i in muzzles.size():
			var m: Vector2 = to_screen.call(muzzles[i])
			_muzzle_effects(ci, m, i, after, length, sc)
	_shore_hits(ci, rect, horizon, u, s)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if after >= 0.0:
		ci.draw_rect(rect, Color(1.0, 0.85, 0.6, 0.4 * exp(-after * 30.0)))


func _recoil(after: float) -> float:
	if after < 0.0:
		return 0.0
	if after < 0.04:
		return RECOIL_PX * after / 0.04
	return RECOIL_PX * clampf(1.0 - (after - 0.04) / 0.3, 0.0, 1.0)


# --- backdrop ----------------------------------------------------------------------------------------------

func _sky_and_shore(ci: CanvasItem, rect: Rect2, horizon: float, s: float, u: float) -> void:
	var m := 40.0
	var top := rect.position.y - m
	var bands := 28
	var sky_h := horizon - top
	for i in bands:
		var f := float(i) / float(bands - 1)
		ci.draw_rect(Rect2(rect.position.x - m, top + sky_h * float(i) / bands, rect.size.x + m * 2.0, sky_h / bands + 1.0), SKY_TOP.lerp(SKY_LOW, f * f))
	for k in 6:
		ci.draw_circle(Vector2(rect.position.x + rect.size.x * 0.12, horizon), (240.0 - 35.0 * float(k)) * s, Color(1.0, 0.72, 0.38, 0.05 + 0.03 * float(k)))
	# the coast on the right, low hills with a few lights
	var pts := PackedVector2Array()
	var n := 24
	var x0 := rect.position.x + rect.size.x * 0.52
	for i in n + 1:
		var f := float(i) / float(n)
		var x := x0 + (rect.end.x + m - x0) * f
		var h := (20.0 + 46.0 * sin(f * 3.4 + 0.6) * sin(f * 3.4 + 0.6) + 12.0 * sin(f * 9.0)) * s * smoothstep(0.0, 0.18, f)
		pts.append(Vector2(x, horizon - h))
	pts.append(Vector2(rect.end.x + m, horizon + 4.0))
	pts.append(Vector2(x0, horizon + 4.0))
	ci.draw_colored_polygon(pts, SHORE)
	for i in 9:
		var lx := x0 + (rect.end.x - x0) * (0.15 + 0.8 * hash01(i, 11))
		ci.draw_rect(Rect2(lx, horizon - (4.0 + 10.0 * hash01(i, 12)) * s, 2.0 * s + 1.0, 2.0 * s + 1.0), Color(1.0, 0.78, 0.4, 0.8))


func _sea(ci: CanvasItem, rect: Rect2, horizon: float, t: float, s: float) -> void:
	var m := 40.0
	var h := rect.end.y + m - horizon
	var bands := 30
	for i in bands:
		var f := float(i) / float(bands - 1)
		ci.draw_rect(Rect2(rect.position.x - m, horizon + h * float(i) / bands, rect.size.x + m * 2.0, h / bands + 1.0), SEA_FAR.lerp(SEA_NEAR, pow(f, 0.7)))
	# the sun's glitter path and the swell lines rolling toward us
	for i in 46:
		var f := hash01(i, 21)
		var y := horizon + h * (0.03 + 0.95 * f)
		var depth := (y - horizon) / h
		var x := rect.position.x + fposmod(hash01(i, 22) * rect.size.x * 1.2 + t * (14.0 + 40.0 * depth), rect.size.x * 1.2) - rect.size.x * 0.1
		var w := (30.0 + 120.0 * depth) * s * (0.5 + hash01(i, 23))
		var glit := clampf(1.0 - absf(x - rect.position.x - rect.size.x * 0.15) / (rect.size.x * 0.4), 0.0, 1.0)
		ci.draw_rect(Rect2(x, y, w, maxf(1.0, 2.0 * depth * s * 2.0)), Color(1.0, 0.8, 0.55, 0.12 + 0.35 * glit * hash01(i, 24)))


func _wake(ci: CanvasItem, rect: Rect2, water_y: float, sc: float, t: float, s: float) -> void:
	# the water in front of the hull: a dark translucent band with foam along the ship's side and a bow wave
	var x0 := rect.position.x + (rect.size.x - SHIP_W * sc) * 0.5
	var band_h := 12.0 * sc
	ci.draw_rect(Rect2(rect.position.x - 40.0, water_y - 1.0 * sc, rect.size.x + 80.0, band_h), Color(0.05, 0.1, 0.17, 0.82))
	for i in 60:
		var fx := x0 + SHIP_W * sc * hash01(i, 31) + sin(t * 2.0 + float(i)) * 3.0 * s
		var fy := water_y - 1.0 * sc + band_h * (0.1 + 0.8 * hash01(i, 32))
		ci.draw_rect(Rect2(fx, fy, (14.0 + 26.0 * hash01(i, 33)) * s, 2.0 * s), Color(0.9, 0.95, 1.0, 0.25 + 0.3 * hash01(i, 34)))
	var bow := Vector2(x0 + (SHIP_W - 6.0) * sc, water_y)
	for i in 8:
		var f := float(i) / 7.0
		ci.draw_circle(bow + Vector2(f * 26.0 * sc + sin(t * 4.0 + f * 6.0) * 2.0 * s, -f * 6.0 * sc + 4.0 * sc), (4.5 - f * 2.5) * sc, Color(0.92, 0.96, 1.0, 0.5 * (1.0 - f * 0.7)))


# --- the volley ---------------------------------------------------------------------------------------------

func _muzzle_effects(ci: CanvasItem, m: Vector2, i: int, after: float, length: float, sc: float) -> void:
	var seconds := after * length
	var fx := sc * 1.6
	var h1 := hash01(i, 41)
	if after < FLASH_LEN:
		var k := 1.0 - after / FLASH_LEN
		ci.draw_circle(m, 16.0 * fx * k, Color(1.0, 0.5, 0.15, 0.3 * k))
		ci.draw_circle(m, 9.0 * fx * k, Color(1.0, 0.75, 0.35, 0.7 * k))
		var jet := PackedVector2Array([m + Vector2(0.0, -34.0) * fx * k, m + Vector2(7.0, 0.0) * fx * k, m + Vector2(0.0, 6.0) * fx, m + Vector2(-7.0, 0.0) * fx * k])
		ci.draw_colored_polygon(jet, Color(1.0, 0.9, 0.55, 0.95 * k))
		ci.draw_circle(m, 4.5 * fx * k, Color(1.0, 1.0, 0.9, k))
	# the shell climbs away from the muzzle, shrinking as it recedes toward the coast
	var shell_a := clampf(1.0 - seconds / 0.35, 0.0, 1.0)
	if shell_a > 0.0:
		var rise := (1.0 - exp(-seconds * 7.0)) * 150.0 * sc
		var head := m + Vector2(14.0 * sc * (seconds * 3.0), -rise)
		var tail := m + Vector2(14.0 * sc * (seconds * 3.0) * 0.8, -rise * 0.55)
		ci.draw_line(tail, head, Color(1.0, 0.8, 0.5, 0.55 * shell_a), maxf(1.0, 4.0 * sc * (1.0 - seconds * 1.6)))
		ci.draw_circle(head, maxf(1.0, 2.6 * sc * (1.0 - seconds * 2.0)), Color(1.0, 0.97, 0.85, shell_a))
	# smoke and fire gas: a dirty brown cloud that billows up and drifts off with the wind
	var life := 1.6
	if seconds < life:
		var age := seconds / life
		for p in 3:
			var hp := hash01(i * 7 + p, 43)
			var pos := m + Vector2((hp - 0.3) * 40.0 * sc * age + 12.0 * sc * age, -60.0 * sc * age * (0.4 + hp) - 5.0 * sc)
			var r := (4.0 + 42.0 * age * (0.6 + hp) + 5.0 * h1) * sc
			var a := 0.42 * pow(1.0 - age, 1.5)
			ci.draw_circle(pos, r, Color(0.46, 0.4, 0.36, a))
			ci.draw_circle(pos + Vector2(-r * 0.25, -r * 0.25), r * 0.6, Color(0.66, 0.6, 0.54, a * 0.7))


func _shore_hits(ci: CanvasItem, rect: Rect2, horizon: float, u: float, s: float) -> void:
	# a few seconds later the shells arrive: flashes and rising smoke along the coast
	for i in 6:
		var start := 0.62 + 0.3 * hash01(i, 51)
		var age := (u - start) / 0.22
		if age < 0.0 or age > 1.0:
			continue
		var x := rect.position.x + rect.size.x * (0.6 + 0.36 * hash01(i, 52))
		var y := horizon - (6.0 + 30.0 * hash01(i, 53)) * s
		var k := 1.0 - age
		ci.draw_circle(Vector2(x, y), (18.0 + 26.0 * age) * s, Color(1.0, 0.55, 0.2, 0.55 * k * k))
		ci.draw_circle(Vector2(x, y), 9.0 * s * k, Color(1.0, 0.92, 0.65, k))
		ci.draw_circle(Vector2(x + 6.0 * age * s, y - 30.0 * age * s), (10.0 + 22.0 * age) * s, Color(0.16, 0.14, 0.15, 0.5 * k))
