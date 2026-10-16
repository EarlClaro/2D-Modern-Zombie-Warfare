class_name HypersonicMissileScene
extends CutawayScene
## Hypersonic missile cutaway (epic): a slim missile screams across the dusk sky at extreme speed, trailing white-hot
## plasma and a shock cone, with the clouds streaking past; it pitches over in a tight arc and plunges straight down
## onto the target in a single streak, ending in a white flash and a shock ring. The missile is the generated sprite
## of tools/gen_cutaway_art.gd; the path, trail and impact are drawn here.

const MISSILE: Texture2D = preload("res://assets/cutaways/hypersonic.png")
const NOSE_X: float = 95.0  # sprite px from the left edge to the tip of the nose
const CENTER_Y: float = 7.0
const SCALE: float = 3.0
const DESIGN_H: float = 684.0

const START_U: float = 0.0  # when the missile enters from the left
const IMPACT_U: float = 0.8
const LEVEL_Y: float = 0.27  # height of the horizontal run (share of the picture height)
const TURN_X: float = 0.6  # where the run ends and the pitch-over begins (share of the width)
const TURN_R: float = 0.13  # radius of the pitch-over arc (share of the height)
const GROUND_Y: float = 0.74
const TRAIL_STEPS: int = 46
const TRAIL_SPAN: float = 0.38  # share of the path length the trail covers behind the nose

const SKY_TOP: Color = Color(0.06, 0.08, 0.2)
const SKY_LOW: Color = Color(0.9, 0.5, 0.26)
const HILL: Color = Color(0.12, 0.12, 0.17)
const GROUND_FAR: Color = Color(0.2, 0.22, 0.12)
const GROUND_NEAR: Color = Color(0.07, 0.08, 0.05)

var _sh: Vector2 = Vector2.ZERO


func shake(t: float, length: float) -> Vector2:
	var u := t / maxf(length, 0.001)
	var after := u - IMPACT_U
	if after < 0.0:
		var hum := 1.6 * clampf((u - START_U) / 0.3, 0.0, 1.0)  # the missile's passing buffets the picture
		return Vector2(sin(t * 120.0) * hum, cos(t * 97.0) * hum)
	var amp := 13.0 * exp(-after * 9.0)
	return Vector2(sin(t * 93.0) * amp, cos(t * 79.0) * amp)


func draw(ci: CanvasItem, rect: Rect2, t: float, length: float) -> void:
	var u := t / maxf(length, 0.001)
	var s := rect.size.y / DESIGN_H
	_sh = shake(t, length)
	ci.draw_set_transform(_sh, 0.0, Vector2.ONE)
	_backdrop(ci, rect, s, t)
	var path := _path(rect)
	var total: float = path["total"]
	var run := clampf((u - START_U) / (IMPACT_U - START_U), 0.0, 1.0)
	var d := total * pow(run, 1.08)  # distance flown: the missile keeps picking up speed
	var flying := u >= START_U and u < IMPACT_U
	if u >= START_U:
		_trail(ci, path, d, s)
	if flying:
		_missile(ci, path, d, s)
	if u >= IMPACT_U:
		_impact(ci, rect, path, u, length, s)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if u >= IMPACT_U:
		var f := u - IMPACT_U
		ci.draw_rect(rect, Color(1.0, 0.97, 0.9, 0.85 * exp(-f * 16.0)))


# --- path ---------------------------------------------------------------------------------------------------

## The three legs of the flight in picture px: a level run, a quarter-circle pitch-over and a vertical plunge.
func _path(rect: Rect2) -> Dictionary:
	var h := rect.size.y
	var r := TURN_R * h
	var start := Vector2(rect.position.x - rect.size.x * 0.05, rect.position.y + LEVEL_Y * h)
	var p1 := Vector2(rect.position.x + rect.size.x * TURN_X, start.y)
	var p2 := p1 + Vector2(r, r)
	var ground := rect.position.y + GROUND_Y * h
	var p3 := Vector2(p2.x, ground)
	var la := start.distance_to(p1)
	var lb := PI * 0.5 * r
	var lc := p2.distance_to(p3)
	return {"start": start, "p1": p1, "p2": p2, "p3": p3, "r": r, "la": la, "lb": lb, "lc": lc, "total": la + lb + lc}


## Position and heading (unit vector) at distance `d` along the flight.
func _at(path: Dictionary, d: float) -> Array:
	var la: float = path["la"]
	var lb: float = path["lb"]
	var start: Vector2 = path["start"]
	var p1: Vector2 = path["p1"]
	var p2: Vector2 = path["p2"]
	var r: float = path["r"]
	if d <= la:
		return [start.lerp(p1, d / maxf(la, 0.001)), Vector2.RIGHT]
	if d <= la + lb:
		var th := (d - la) / maxf(lb, 0.001) * PI * 0.5
		var centre := p1 + Vector2(0.0, r)
		return [centre + Vector2(sin(th), -cos(th)) * r, Vector2(cos(th), sin(th))]
	return [p2 + Vector2(0.0, d - la - lb), Vector2.DOWN]


func _missile(ci: CanvasItem, path: Dictionary, d: float, s: float) -> void:
	var at := _at(path, d)
	var nose: Vector2 = at[0]
	var dir: Vector2 = at[1]
	var sc := SCALE * s
	# the glow of air heated to plasma around the nose
	ci.draw_circle(nose, 34.0 * sc, Color(1.0, 0.6, 0.3, 0.12))
	ci.draw_circle(nose, 20.0 * sc, Color(1.0, 0.75, 0.45, 0.22))
	ci.draw_circle(nose, 9.0 * sc, Color(1.0, 0.95, 0.8, 0.75))
	ci.draw_set_transform(nose + _sh, dir.angle(), Vector2(sc, sc))
	ci.draw_texture(MISSILE, Vector2(-NOSE_X, -CENTER_Y))
	ci.draw_set_transform(_sh, 0.0, Vector2.ONE)
	# the shock cone: two faint lines sweeping back from the nose
	var side := Vector2(-dir.y, dir.x)
	for sgn in [-1.0, 1.0]:
		var tip := nose - dir * 4.0 * sc
		ci.draw_line(tip, tip - dir * 150.0 * sc + side * float(sgn) * 40.0 * sc, Color(1.0, 0.95, 0.9, 0.32), 2.0 * s)
		ci.draw_line(tip, tip - dir * 100.0 * sc + side * float(sgn) * 24.0 * sc, Color(1.0, 0.95, 0.9, 0.5), 1.4 * s)


## The plasma trail: samples back along the path, white-hot at the nose, orange, then smoky and gone.
func _trail(ci: CanvasItem, path: Dictionary, d: float, s: float) -> void:
	var total: float = path["total"]
	var span := total * TRAIL_SPAN
	var prev: Vector2 = _at(path, d)[0]
	for k in range(1, TRAIL_STEPS + 1):
		var f := float(k) / float(TRAIL_STEPS)
		var back := d - span * f
		if back < 0.0:
			break
		var pt: Vector2 = _at(path, back)[0]
		var w := (30.0 * pow(1.0 - f, 0.7) + 4.0) * s
		var a := pow(1.0 - f, 1.2)
		ci.draw_line(prev, pt, Color(1.0, 0.5, 0.2, 0.35 * a), w * 1.9)
		ci.draw_circle(pt, w * 0.95, Color(1.0, 0.5, 0.2, 0.35 * a))
		ci.draw_line(prev, pt, Color(1.0, 0.75, 0.45, 0.6 * a), w)
		ci.draw_circle(pt, w * 0.5, Color(1.0, 0.75, 0.45, 0.6 * a))
		ci.draw_line(prev, pt, Color(1.0, 0.97, 0.88, 0.95 * a), w * 0.4)
		ci.draw_circle(pt, w * 0.2, Color(1.0, 0.97, 0.88, 0.95 * a))
		prev = pt


func _impact(ci: CanvasItem, rect: Rect2, path: Dictionary, u: float, length: float, s: float) -> void:
	var f := u - IMPACT_U
	var seconds := f * length
	var p: Vector2 = path["p3"]
	# the plunge's last streak fades while the blast blooms
	var bloom := 1.0 - exp(-seconds * 11.0)
	ci.draw_circle(p, (70.0 + 170.0 * bloom) * s, Color(1.0, 0.55, 0.2, 0.3 * exp(-seconds * 2.2)))
	ci.draw_circle(p, (40.0 + 90.0 * bloom) * s, Color(1.0, 0.85, 0.55, 0.65 * exp(-seconds * 2.8)))
	ci.draw_circle(p, (22.0 + 40.0 * bloom) * s, Color(1.0, 1.0, 0.95, exp(-seconds * 3.4)))
	# a column of light where the streak came down
	var col_a := exp(-seconds * 7.0)
	ci.draw_rect(Rect2(p.x - 14.0 * s, rect.position.y, 28.0 * s, p.y - rect.position.y), Color(1.0, 0.9, 0.7, 0.4 * col_a))
	ci.draw_rect(Rect2(p.x - 5.0 * s, rect.position.y, 10.0 * s, p.y - rect.position.y), Color(1.0, 1.0, 0.95, 0.85 * col_a))
	# the ground shock ring, flattened by the view
	var ring := seconds * 900.0 * s
	var ring_a := exp(-seconds * 2.4)
	var pts := PackedVector2Array()
	for i in 49:
		var a := TAU * float(i) / 48.0
		pts.append(p + Vector2(cos(a) * ring, sin(a) * ring * 0.22))
	ci.draw_polyline(pts, Color(1.0, 0.9, 0.75, 0.8 * ring_a), 4.0 * s)
	# dust and debris thrown up
	for k in 12:
		var h1 := hash01(k, 21)
		var h2 := hash01(k, 22)
		var vx := (h1 - 0.5) * 760.0 * s
		var vy := -(160.0 + 420.0 * h2) * s
		var dp := p + Vector2(vx * seconds, vy * seconds + 900.0 * s * seconds * seconds)
		ci.draw_circle(dp, (5.0 + 12.0 * h2) * s * (1.0 + seconds), Color(0.55, 0.45, 0.35, 0.6 * exp(-seconds * 1.6)))


# --- parts -------------------------------------------------------------------------------------------------

func _backdrop(ci: CanvasItem, rect: Rect2, s: float, t: float) -> void:
	var m := 40.0
	var horizon := rect.position.y + GROUND_Y * rect.size.y - 6.0 * s
	var left := rect.position.x - m
	var width := rect.size.x + m * 2.0
	var top := rect.position.y - m
	var bands := 32
	for i in bands:
		var f := float(i) / float(bands - 1)
		ci.draw_rect(Rect2(left, top + (horizon - top) * float(i) / bands, width, (horizon - top) / bands + 1.0), SKY_TOP.lerp(SKY_LOW, f * f))
	# cloud streaks racing past the missile (faster nearer the bottom), wrapping across the picture
	for k in 14:
		var h := hash01(k, 31)
		var y := rect.position.y + rect.size.y * (0.08 + 0.55 * hash01(k, 32))
		var speed := (900.0 + 1800.0 * h) * s
		var w := (120.0 + 280.0 * hash01(k, 33)) * s
		var x := fposmod(rect.position.x + rect.size.x * hash01(k, 34) - t * speed, rect.size.x + w * 2.0) - w
		var a := 0.1 + 0.16 * hash01(k, 35)
		ci.draw_rect(Rect2(x + rect.position.x, y, w, (3.0 + 6.0 * h) * s), Color(1.0, 0.85, 0.7, a))
	var pts := PackedVector2Array()
	var n := 32
	for i in n + 1:
		var f := float(i) / float(n)
		var y := horizon - 46.0 * s * (0.5 + 0.28 * sin(f * 5.4 + 1.1) + 0.22 * sin(f * 12.6 + 2.2))
		pts.append(Vector2(left + f * width, y))
	pts.append(Vector2(left + width, horizon + 8.0))
	pts.append(Vector2(left, horizon + 8.0))
	ci.draw_colored_polygon(pts, HILL)
	var ground_h := rect.end.y + m - horizon
	var gb := 20
	for i in gb:
		var f := float(i) / float(gb - 1)
		ci.draw_rect(Rect2(left, horizon + ground_h * float(i) / gb, width, ground_h / gb + 1.0), GROUND_FAR.lerp(GROUND_NEAR, f))
