class_name NuclearBombScene
extends CutawayScene
## Nuclear bomb cutaway (epic): a flying-wing bomber crosses the dusk sky high above a city and lets go of a
## gravity bomb, which tips nose down and falls. A beat of silence as it drops below the roof line, then a white
## flash fills the picture; as it fades the fireball swells over the black skyline, a shock ring sweeps the ground and
## a mushroom cloud climbs on its stem. The bomb is the generated sprite of tools/gen_cutaway_art.gd; the bomber, city,
## fireball and cloud are drawn here. Photosensitivity: one flash that decays smoothly, never a strobe.

const BOMB: Texture2D = preload("res://assets/cutaways/nuke.png")
const BOMB_NOSE: Vector2 = Vector2(63.0, 8.0)  # the tip of the nose in the sprite
const BOMB_CENTER: Vector2 = Vector2(34.0, 8.0)
const DESIGN_H: float = 684.0

const RELEASE_U: float = 0.14
const FALL_END_U: float = 0.42  # the bomb reaches the burst height; a beat of stillness follows
const BURST_U: float = 0.5  # the flash
const BURST_Y: float = 0.5  # where the bomb goes off (share of the picture height)
const GROUND_Y: float = 0.82
const BOMBER_FROM: float = -0.12
const BOMBER_TO: float = 0.62

const SKY_TOP: Color = Color(0.05, 0.06, 0.16)
const SKY_LOW: Color = Color(0.82, 0.42, 0.24)
const GROUND: Color = Color(0.06, 0.06, 0.08)

var _sh: Vector2 = Vector2.ZERO


func shake(t: float, length: float) -> Vector2:
	var after := t / maxf(length, 0.001) - BURST_U
	if after < 0.0:
		return Vector2.ZERO
	var amp := 16.0 * minf(after * 18.0, 1.0) * exp(-after * 3.2)
	return Vector2(sin(t * 61.0) * amp, cos(t * 53.0) * amp)


func draw(ci: CanvasItem, rect: Rect2, t: float, length: float) -> void:
	var u := t / maxf(length, 0.001)
	var s := rect.size.y / DESIGN_H
	_sh = shake(t, length)
	var after := u - BURST_U
	var ground := rect.position.y + rect.size.y * GROUND_Y
	var burst := Vector2(rect.position.x + rect.size.x * 0.55, rect.position.y + rect.size.y * BURST_Y)
	ci.draw_set_transform(_sh, 0.0, Vector2.ONE)
	_sky(ci, rect, ground, s, after)
	if after < 0.0:
		_bomber_and_bomb(ci, rect, u, burst, s)
	_city(ci, rect, ground, s, after)
	if after >= 0.0:
		_blast(ci, rect, ground, burst, after, length, s)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if after >= 0.0:
		# the flash: pure white at the instant of the burst, then a smooth fade (no flicker)
		ci.draw_rect(rect, Color(1.0, 1.0, 1.0, clampf(exp(-after * 7.0) * 1.1, 0.0, 1.0)))


# --- before the flash ---------------------------------------------------------------------------------------

## The bomber's x on screen for clip share `u` (it is also what the bomb inherits).
func _bomber_x(rect: Rect2, u: float) -> float:
	var k := clampf(u / BURST_U, 0.0, 1.0)
	return rect.position.x + rect.size.x * lerpf(BOMBER_FROM, BOMBER_TO, k)


func _bomber_and_bomb(ci: CanvasItem, rect: Rect2, u: float, burst: Vector2, s: float) -> void:
	var by := rect.position.y + rect.size.y * 0.16
	var bx := _bomber_x(rect, u)
	_bomber(ci, Vector2(bx, by), s, u)
	if u < RELEASE_U:
		return
	# the bomb: leaves the bay with the bomber's speed, then gravity pulls it down and tips the nose over
	var rx := _bomber_x(rect, RELEASE_U)
	var fall := clampf((u - RELEASE_U) / (FALL_END_U - RELEASE_U), 0.0, 1.0)
	var pos := Vector2(lerpf(rx, burst.x, fall), lerpf(by + 14.0 * s, burst.y, fall * fall))
	var tip := clampf(fall * 2.2, 0.0, 1.0)
	var ang := lerpf(0.0, 1.35, tip)  # radians below the horizontal
	var sc := 1.5 * s
	ci.draw_set_transform(pos + _sh, ang, Vector2(sc, sc))
	ci.draw_texture(BOMB, -BOMB_CENTER)
	ci.draw_set_transform(_sh, 0.0, Vector2.ONE)


## A flying-wing bomber in plan-ish profile, a dark silhouette against the dusk with its lights.
func _bomber(ci: CanvasItem, c: Vector2, s: float, u: float) -> void:
	var k := 6.0 * s
	var body := PackedVector2Array([
		c + Vector2(24, 0) * k, c + Vector2(8, -3) * k, c + Vector2(-6, -9) * k, c + Vector2(-12, -3) * k,
		c + Vector2(-9, 0) * k, c + Vector2(-12, 3) * k, c + Vector2(-6, 9) * k, c + Vector2(8, 3) * k,
	])
	ci.draw_colored_polygon(body, Color(0.07, 0.07, 0.1))
	ci.draw_polyline(PackedVector2Array([c + Vector2(24, 0) * k, c + Vector2(8, -3) * k, c + Vector2(-6, -9) * k]), Color(0.3, 0.3, 0.38), 1.6 * s)
	ci.draw_circle(c + Vector2(15, -0.4) * k, 1.1 * k * 0.5, Color(0.2, 0.35, 0.45))
	ci.draw_circle(c + Vector2(-11, 0) * k, 0.8 * k * 0.5, Color(1.0, 0.6, 0.3, 0.8))  # an exhaust glow
	var blink := 0.5 + 0.5 * sin(u * 120.0)
	ci.draw_circle(c + Vector2(-5, -8) * k, 1.4 * s, Color(1.0, 0.2, 0.2, 0.4 + 0.6 * blink))
	# the bay doors opening for the release
	if u > RELEASE_U - 0.03 and u < RELEASE_U + 0.08:
		ci.draw_rect(Rect2(c + Vector2(-3, 1) * k, Vector2(7, 1.4) * k), Color(0.02, 0.02, 0.03))


func _sky(ci: CanvasItem, rect: Rect2, ground: float, s: float, after: float) -> void:
	var m := 40.0
	var left := rect.position.x - m
	var width := rect.size.x + m * 2.0
	var top := rect.position.y - m
	var bands := 36
	# after the burst the whole sky is lit from below by the fireball: warmer and brighter
	var lit := 0.0 if after < 0.0 else clampf(1.0 - after * 1.8, 0.0, 1.0) * 0.5 + 0.18
	for i in bands:
		var f := float(i) / float(bands - 1)
		var c := SKY_TOP.lerp(SKY_LOW, f * f)
		if after >= 0.0:
			c = c.lerp(Color(1.0, 0.6, 0.25), lit * (0.35 + 0.65 * f))
		ci.draw_rect(Rect2(left, top + (ground - top) * float(i) / bands, width, (ground - top) / bands + 1.0), c)
	for k in 30:
		if after >= 0.0:
			break
		var y := rect.position.y + (ground - rect.position.y) * 0.45 * hash01(k, 41)
		ci.draw_circle(Vector2(rect.position.x + rect.size.x * hash01(k, 42), y), (0.8 + hash01(k, 43)) * s, Color(1.0, 1.0, 0.95, 0.5 * (1.0 - y / ground)))


## The city: a black skyline of towers with lit windows, and the dark plain in front. Black against the glare.
func _city(ci: CanvasItem, rect: Rect2, ground: float, s: float, after: float) -> void:
	var m := 40.0
	var n := 46
	var x := rect.position.x - m
	var i := 0
	while x < rect.end.x + m:
		var w := (14.0 + 26.0 * hash01(i, 51)) * s
		var h := (14.0 + 90.0 * pow(hash01(i, 52), 2.0) * (1.0 - absf(x - rect.position.x - rect.size.x * 0.55) / rect.size.x * 0.9)) * s
		ci.draw_rect(Rect2(x, ground - h, w, h + 4.0), Color(0.03, 0.03, 0.05))
		if after < 0.0:  # lit windows before the flash
			for wy in range(int(4.0 * s), int(h) - 3, int(8.0 * s)):
				if hash01(i * 17 + wy, 53) > 0.55:
					ci.draw_rect(Rect2(x + 3.0 * s, ground - h + float(wy), 3.0 * s, 4.0 * s), Color(1.0, 0.82, 0.45, 0.85))
		x += w + 2.0 * s
		i += 1
		if i > n * 3:
			break
	ci.draw_rect(Rect2(rect.position.x - m, ground, rect.size.x + m * 2.0, rect.end.y - ground + m), GROUND)


# --- the blast ----------------------------------------------------------------------------------------------

func _blast(ci: CanvasItem, rect: Rect2, ground: float, burst: Vector2, after: float, length: float, s: float) -> void:
	var seconds := after * length
	var rise := clampf(after / (1.0 - BURST_U), 0.0, 1.0)  # 0 at the burst .. 1 at the end of the clip
	# the shock ring racing out along the ground
	var ring := seconds * 1500.0 * s
	var ring_a := exp(-seconds * 1.8)
	var gp := Vector2(burst.x, ground)
	var pts := PackedVector2Array()
	for k in 65:
		var a := TAU * float(k) / 64.0
		pts.append(gp + Vector2(cos(a) * ring, sin(a) * ring * 0.1))
	ci.draw_polyline(pts, Color(1.0, 0.92, 0.8, 0.7 * ring_a), 5.0 * s)
	# the base surge, a wide low cloud rolling over the city
	for k in 16:
		var h1 := hash01(k, 61)
		var dx := (h1 - 0.5) * 2.0 * (180.0 + 520.0 * (1.0 - exp(-seconds * 1.6))) * s
		var y := ground - (6.0 + 26.0 * hash01(k, 62)) * s * (0.4 + rise * 1.4)
		ci.draw_circle(Vector2(burst.x + dx, y), (20.0 + 34.0 * hash01(k, 63)) * s * (0.5 + rise), Color(0.32, 0.2, 0.14, 0.7))
		ci.draw_circle(Vector2(burst.x + dx * 0.95, y - 6.0 * s), (12.0 + 24.0 * hash01(k, 64)) * s * (0.5 + rise), Color(0.6, 0.35, 0.18, 0.55))
	# the stem: a tapering column from the ground up to the cap
	var cap_y := lerpf(burst.y, rect.position.y + rect.size.y * 0.2, rise)
	var cap_r := (36.0 + 130.0 * (1.0 - exp(-after * 6.0))) * s
	var stem_top := cap_y + cap_r * 0.5
	var stem_w := (14.0 + 26.0 * rise) * s
	var stem := PackedVector2Array([
		Vector2(burst.x - stem_w * 1.7, ground), Vector2(burst.x - stem_w * 0.55, stem_top),
		Vector2(burst.x + stem_w * 0.55, stem_top), Vector2(burst.x + stem_w * 1.7, ground),
	])
	ci.draw_colored_polygon(stem, Color(0.34, 0.2, 0.13, 0.92))
	var core := PackedVector2Array([
		Vector2(burst.x - stem_w * 0.7, ground), Vector2(burst.x - stem_w * 0.25, stem_top),
		Vector2(burst.x + stem_w * 0.25, stem_top), Vector2(burst.x + stem_w * 0.7, ground),
	])
	ci.draw_colored_polygon(core, Color(0.95, 0.5, 0.15, 0.55 * (1.0 - rise * 0.6)))
	# the cap: a rolling mass of cloud, dark grey-brown outside and a glowing core that cools as it climbs
	var cooling := rise
	for k in 22:
		var a := TAU * float(k) / 22.0
		var wob := 0.75 + 0.5 * hash01(k, 71)
		var p := Vector2(burst.x + cos(a) * cap_r * 0.95 * wob, cap_y + sin(a) * cap_r * 0.62 * wob)
		var r := cap_r * (0.34 + 0.12 * hash01(k, 72))
		ci.draw_circle(p, r, Color(0.3, 0.2, 0.16, 0.95))
	for k in 16:
		var a := TAU * float(k) / 16.0 + 0.2
		var p := Vector2(burst.x + cos(a) * cap_r * 0.62, cap_y + sin(a) * cap_r * 0.42)
		ci.draw_circle(p, cap_r * 0.32, Color(0.7, 0.34, 0.14, 0.9).lerp(Color(0.5, 0.3, 0.22, 0.9), cooling))
	ci.draw_circle(Vector2(burst.x, cap_y), cap_r * 0.62, Color(1.0, 0.62, 0.2, 0.95).lerp(Color(0.72, 0.38, 0.16, 0.9), cooling))
	ci.draw_circle(Vector2(burst.x, cap_y - cap_r * 0.04), cap_r * 0.36, Color(1.0, 0.92, 0.6, 0.95).lerp(Color(0.95, 0.6, 0.25, 0.9), cooling))
	# the fireball's bright halo in the first moments
	var halo := exp(-seconds * 2.6)
	ci.draw_circle(burst, cap_r * (1.4 + 1.0 * (1.0 - halo)), Color(1.0, 0.7, 0.3, 0.2 * halo))
	ci.draw_circle(burst, cap_r * 1.1, Color(1.0, 0.9, 0.6, 0.45 * halo))
