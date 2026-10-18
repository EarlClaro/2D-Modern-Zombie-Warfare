class_name WeatherView
extends Control
## Rain (with now and then a flash of lightning and a bolt), snow, fog banks or dust drifting over the screen (screen space, so it does not move with the camera, apart from a
## little parallax). Rain has two layers: far drops are short, slow and faint, near drops long, fast and brighter;
## drops that pass through a light's pool or the cone under its bulb are drawn brighter. Presentation only.

const FAR: Dictionary = {"speed": 620.0, "drift": 150.0, "len": 8.0, "len_var": 6.0, "parallax": 0.05, "seed": 0}
const NEAR: Dictionary = {"speed": 1050.0, "drift": 260.0, "len": 14.0, "len_var": 14.0, "parallax": 0.2, "seed": 7}
const RAIN_COLOR: Color = Color(0.75, 0.82, 0.95)
const LIT_COLOR: Color = Color(1.0, 0.93, 0.78)
const CONE_TOP_HALF_PX: float = 5.0  # half width of the light cone at the bulb
const CONE_BOTTOM_SHARE: float = 0.45  # half width at the ground, as a share of the pool radius

## A lightning bolt has struck: `thunder_delay_s` is how long until the thunder should be heard (the sound is not made here).
signal lightning_struck(thunder_delay_s: float)

const FIRST_STRIKE_S: float = 6.0
const STRIKE_GAP_MIN_S: float = 9.0
const STRIKE_GAP_VAR_S: float = 11.0
const FLASH_S: float = 0.55  # a strike's whole flash, with two flickers in the first 0.17 s
const BOLT_S: float = 0.17  # how long the bolt itself is drawn
const SNOW_FAR: Dictionary = {"count": 260, "size": 2.0, "speed": 38.0, "sway": 10.0, "parallax": 0.05, "alpha": 0.6, "seed": 21}
const SNOW_NEAR: Dictionary = {"count": 100, "size": 4.0, "speed": 92.0, "sway": 24.0, "parallax": 0.2, "alpha": 0.9, "seed": 29}

var weather: String = "clear"
var _t: float = 0.0
var _strike_n: int = 0
var _next_strike_t: float = FIRST_STRIKE_S
var _strike_age: float = 99.0  # seconds since the last strike
var _bolt_x: float = 0.0  # 0..1 across the screen
var _lights: Array[Dictionary] = []
var _cam: Vector2 = Vector2.ZERO
var _bounds: Rect2 = Rect2()  # where any light reaches: drops outside it skip the per-light tests


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func set_weather(w: String) -> void:
	weather = w
	visible = w != "clear"
	queue_redraw()


## The lights near the screen, in screen px: `c` pool centre, `b` bulb, `r` pool radius, `k` brightness (0..1).
func set_lights(lights: Array[Dictionary]) -> void:
	_lights = lights
	_bounds = Rect2()
	for l in lights:
		var c: Vector2 = l["c"]
		var r: float = l["r"]
		var rect := Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0).merge(Rect2(l["b"] as Vector2, Vector2.ZERO))
		_bounds = rect if _bounds.size == Vector2.ZERO else _bounds.merge(rect)


func set_camera(world_pos: Vector2) -> void:
	_cam = world_pos


func _process(delta: float) -> void:
	if weather == "clear":
		return
	_t += delta
	if weather == "rain":
		_strike_age += delta
		if _t >= _next_strike_t:
			_strike()
	queue_redraw()


## The next strike of the storm: where the bolt falls, when the following one comes, and the thunder after its delay.
func _strike() -> void:
	_strike_age = 0.0
	_bolt_x = 0.1 + 0.8 * _hash(_strike_n, 33)
	var thunder_delay := 0.35 + 1.9 * _hash(_strike_n, 34)
	_strike_n += 1
	_next_strike_t = _t + STRIKE_GAP_MIN_S + STRIKE_GAP_VAR_S * _hash(_strike_n, 31)
	lightning_struck.emit(thunder_delay)


## How bright the sky flash is `age` seconds after a strike (0..1): a hard first flash, a dip, a second flash, then a fade.
static func flash_level(age: float) -> float:
	if age < 0.0 or age >= FLASH_S:
		return 0.0
	if age < 0.05:
		return 0.9
	if age < 0.09:
		return 0.15
	if age < 0.17:
		return 0.6
	return 0.3 * (1.0 - (age - 0.17) / (FLASH_S - 0.17))


## How strongly a drop at screen position `p` is lit (0 none, 1 in the heart of a lamp's pool): the soft pool on the
## ground and the cone of light between the bulb and the pool.
static func light_amount(p: Vector2, lights: Array[Dictionary]) -> float:
	var best := 0.0
	for l in lights:
		var c: Vector2 = l["c"]
		var r: float = l["r"]
		var k: float = l["k"]
		var b: Vector2 = l["b"]
		if absf(p.x - c.x) > r or p.y < minf(b.y, c.y - r * LightingConfig.POOL_FLATTEN) or p.y > c.y + r * LightingConfig.POOL_FLATTEN:
			continue
		var a := LightField.falloff(Vector2(p.x - c.x, (p.y - c.y) / LightingConfig.POOL_FLATTEN).length() / r)
		if p.y >= b.y and p.y <= c.y:
			var f := (p.y - b.y) / maxf(c.y - b.y, 1.0)
			var half := lerpf(CONE_TOP_HALF_PX, r * CONE_BOTTOM_SHARE, f)
			var cone := clampf(1.0 - absf(p.x - lerpf(b.x, c.x, f)) / half, 0.0, 1.0)
			a = maxf(a, cone * 0.8)
		best = maxf(best, a * k)
	return best


func _hash(i: int, k: int) -> float:
	return fposmod(sin(float(i) * 12.9898 + float(k) * 78.233) * 43758.5453, 1.0)


func _draw() -> void:
	var size := get_viewport_rect().size
	match weather:
		"rain":
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.14, 0.2, 0.05))
			_rain_layer(size, FAR, LightingConfig.RAIN_FAR_STREAKS, LightingConfig.RAIN_FAR_ALPHA)
			_rain_layer(size, NEAR, LightingConfig.RAIN_NEAR_STREAKS, LightingConfig.RAIN_NEAR_ALPHA)
			_lightning(size)
		"snow":
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.85, 0.92, 1.0, 0.07))
			_snow_layer(size, SNOW_FAR)
			_snow_layer(size, SNOW_NEAR)
		"fog":
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.78, 0.82, 0.86, 0.3))
			for i in 9:
				var cx := fposmod(_hash(i, 6) * size.x * 1.4 + _t * (6.0 + 8.0 * _hash(i, 7)), size.x * 1.4) - size.x * 0.2
				var cy := _hash(i, 8) * size.y
				for k in 4:
					draw_circle(Vector2(cx, cy), 120.0 + 70.0 * float(k) + 60.0 * _hash(i, 9), Color(0.85, 0.88, 0.92, 0.035))
		"dust":
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.75, 0.6, 0.38, 0.16))
			var streaks := PackedVector2Array()
			for i in 70:
				var x := fposmod(_hash(i, 10) * (size.x + 200.0) + _t * (240.0 + 160.0 * _hash(i, 11)), size.x + 200.0) - 100.0
				var y := _hash(i, 12) * size.y + sin(_t * 0.8 + float(i)) * 14.0
				streaks.append(Vector2(x, y))
				streaks.append(Vector2(x - 26.0 - 22.0 * _hash(i, 13), y + 2.0))
			draw_multiline(streaks, Color(0.9, 0.78, 0.55, 0.25), 1.0)


func _rain_layer(size: Vector2, layer: Dictionary, count: int, alpha: float) -> void:
	var dry := PackedVector2Array()
	var soft := PackedVector2Array()
	var bright := PackedVector2Array()
	var sd: int = layer["seed"]
	var pad := 160.0
	var par: float = layer["parallax"]
	var shift := Vector2(-_cam.x * par, -_cam.y * par)
	for i in count:
		var speed: float = float(layer["speed"]) * (0.85 + 0.3 * _hash(i, 1 + sd))
		var x := fposmod(_hash(i, 2 + sd) * (size.x + pad * 2.0) - _t * float(layer["drift"]) * (0.8 + 0.4 * _hash(i, 3 + sd)) + shift.x, size.x + pad * 2.0) - pad
		var y := fposmod(_hash(i, 4 + sd) * (size.y + 80.0) + _t * speed + shift.y, size.y + 80.0) - 40.0
		var len_px: float = float(layer["len"]) + float(layer["len_var"]) * _hash(i, 5 + sd)
		var a := Vector2(x, y)
		var b := Vector2(x - len_px * 0.3, y + len_px)
		var mid := a + (b - a) * 0.5
		var lit := light_amount(mid, _lights) if not _lights.is_empty() and _bounds.has_point(mid) else 0.0
		if lit > 0.45:
			bright.append(a)
			bright.append(b)
		elif lit > 0.12:
			soft.append(a)
			soft.append(b)
		else:
			dry.append(a)
			dry.append(b)
	if not dry.is_empty():
		draw_multiline(dry, Color(RAIN_COLOR, alpha), 1.0)
	if not soft.is_empty():
		draw_multiline(soft, Color(LIT_COLOR, minf(alpha * (1.0 + (LightingConfig.RAIN_LIT_BOOST - 1.0) * 0.5), 1.0)), 1.0)
	if not bright.is_empty():
		draw_multiline(bright, Color(LIT_COLOR, minf(alpha * LightingConfig.RAIN_LIT_BOOST, 1.0)), 1.0)


## Flakes as whole-pixel squares (snapped to the 2 px UI grid) that fall and sway; two layers, far small and slow, near big.
func _snow_layer(size: Vector2, layer: Dictionary) -> void:
	var sd: int = layer["seed"]
	var par: float = layer["parallax"]
	var px: float = layer["size"]
	var col := Color(0.93, 0.97, 1.0, float(layer["alpha"]))
	for i in int(layer["count"]):
		var speed: float = float(layer["speed"]) * (0.8 + 0.4 * _hash(i, 1 + sd))
		var sway: float = float(layer["sway"]) * sin(_t * (0.6 + 0.5 * _hash(i, 2 + sd)) + float(i))
		var x := fposmod(_hash(i, 3 + sd) * (size.x + 80.0) + sway - _cam.x * par, size.x + 80.0) - 40.0
		var y := fposmod(_hash(i, 4 + sd) * (size.y + 60.0) + _t * speed - _cam.y * par, size.y + 60.0) - 30.0
		draw_rect(Rect2(Vector2(floorf(x * 0.5) * 2.0, floorf(y * 0.5) * 2.0), Vector2(px, px)), col)


## The flash over the whole screen and, for a moment, the bolt: a jagged line from the top, a fork, drawn on whole pixels.
func _lightning(size: Vector2) -> void:
	var f := flash_level(_strike_age)
	if f <= 0.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.82, 0.88, 1.0, f * 0.45))
	if _strike_age >= BOLT_S:
		return
	var pts := PackedVector2Array()
	var x := _bolt_x * size.x
	var y := 0.0
	var steps := 9
	var length := size.y * (0.5 + 0.2 * _hash(_strike_n, 35))
	var fork_from := Vector2.ZERO
	for i in steps + 1:
		pts.append(Vector2(floorf(x / 2.0) * 2.0, floorf(y / 2.0) * 2.0))
		if i == 4:
			fork_from = pts[pts.size() - 1]
		x += (_hash(_strike_n * 17 + i, 36) - 0.5) * 70.0
		y += length / float(steps)
	var bright := Color(0.97, 0.98, 1.0)
	draw_polyline(pts, Color(0.7, 0.8, 1.0, 0.35), 9.0)
	draw_polyline(pts, bright, 3.0)
	var fork := PackedVector2Array([fork_from])
	var fx := fork_from.x
	var fy := fork_from.y
	for i in 4:
		fx += 22.0 * (1.0 if _hash(_strike_n, 37) > 0.5 else -1.0) * (0.6 + _hash(_strike_n * 5 + i, 38))
		fy += length * 0.07
		fork.append(Vector2(floorf(fx / 2.0) * 2.0, floorf(fy / 2.0) * 2.0))
	draw_polyline(fork, Color(0.7, 0.8, 1.0, 0.3), 6.0)
	draw_polyline(fork, bright, 2.0)
