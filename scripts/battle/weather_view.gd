class_name WeatherView
extends Control
## Rain, fog banks or dust drifting over the screen (screen space, so it does not move with the camera, apart from a
## little parallax). Rain has two layers: far drops are short, slow and faint, near drops long, fast and brighter;
## drops that pass through a light's pool or the cone under its bulb are drawn brighter. Presentation only.

const FAR: Dictionary = {"speed": 620.0, "drift": 150.0, "len": 8.0, "len_var": 6.0, "parallax": 0.05, "seed": 0}
const NEAR: Dictionary = {"speed": 1050.0, "drift": 260.0, "len": 14.0, "len_var": 14.0, "parallax": 0.2, "seed": 7}
const RAIN_COLOR: Color = Color(0.75, 0.82, 0.95)
const LIT_COLOR: Color = Color(1.0, 0.93, 0.78)
const CONE_TOP_HALF_PX: float = 5.0  # half width of the light cone at the bulb
const CONE_BOTTOM_SHARE: float = 0.45  # half width at the ground, as a share of the pool radius

var weather: String = "clear"
var _t: float = 0.0
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
	queue_redraw()


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
