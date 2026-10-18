class_name SkyLife
extends Node2D
## Life in the sky (docs/specs/art-more.md, N.7): now and then in daylight a few crows cross the view, and at night a searchlight on the
## command bunker sweeps its beam across the sky. Crows are a pixel strip (assets/fx/crow.png, two frames); the beam is three nested
## translucent wedges added to the picture. All timing comes from a hash of a counter, so it is the same every run. Presentation only: it
## reads the camera and the core's position and never touches the simulation.

const CROW_FIRST_S: float = 7.0
const CROW_GAP_MIN_S: float = 16.0
const CROW_GAP_VAR_S: float = 20.0
const CROW_SPEED: float = 90.0  # px per second across the world
const FLOCK_MIN: int = 3
const FLOCK_VAR: int = 3
const DAY_MAX_DARKNESS: float = 0.3  # crows only fly while it is brighter than this
const FLAP_FPS: float = 7.0
const BEAM_PERIOD_S: float = 10.0
const BEAM_BASE_ANGLE: float = -1.15  # radians; screen space, 0 is right and negative is up
const BEAM_HALF_ARC: float = 0.75
const BEAM_LENGTH: float = 900.0
const BEAM_FAR_HALF_WIDTH: float = 70.0
const BEAM_MIN_DARKNESS: float = 0.45
const BEAM_ORIGIN := Vector2(14.0, -66.0)  # from the core's ground point: the lamp on the roof

var _battle: BattleController
var _weather: String = "clear"
var _darkness: float = 0.0
var _t: float = 0.0
var _next_flock_t: float = CROW_FIRST_S
var _flock_n: int = 0
var _flocks: Array[Dictionary] = []  # {pos: Vector2, dir: float (1 or -1), age: float, birds: Array[Vector3] (offset x, y, phase)}
var _tex: Texture2D
var _beam: Node2D
var _beam_was_drawn: bool = false


func bind(battle: BattleController, weather: String) -> void:
	_battle = battle
	_weather = weather
	_tex = load("res://assets/fx/crow.png") as Texture2D if ResourceLoader.exists("res://assets/fx/crow.png") else null
	z_index = 45
	_beam = Node2D.new()  # the searchlight is added to the picture (light on light), the crows are drawn normally
	_beam.name = "Beam"
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_beam.material = mat
	add_child(_beam)
	_beam.draw.connect(_draw_beam)
	set_process(true)


func set_darkness(d: float) -> void:
	_darkness = d


func flock_count() -> int:
	return _flocks.size()


## True when the crows may fly: daylight and no storm or fog.
func crows_allowed() -> bool:
	return _darkness < DAY_MAX_DARKNESS and (_weather == "clear" or _weather == "dust" or _weather == "snow")


## The angle of the searchlight beam at time `t`: a slow sweep to and fro (radians, screen space).
static func beam_angle(t: float) -> float:
	return BEAM_BASE_ANGLE + sin(TAU * t / BEAM_PERIOD_S) * BEAM_HALF_ARC


## How strong the beam is for a given darkness (0 by day, up to 1 deep at night).
static func beam_strength(dark: float) -> float:
	return clampf((dark - BEAM_MIN_DARKNESS) / 0.25, 0.0, 1.0)


static func _hash(i: int, k: int) -> float:
	return fposmod(sin(float(i) * 12.9898 + float(k) * 78.233) * 43758.5453, 1.0)


func _process(delta: float) -> void:
	if _battle == null:
		return
	_t += delta
	for i in range(_flocks.size() - 1, -1, -1):
		var f := _flocks[i]
		f["age"] = float(f["age"]) + delta
		f["pos"] = (f["pos"] as Vector2) + Vector2(float(f["dir"]) * CROW_SPEED, -4.0) * delta
		if float(f["age"]) > 40.0 or not _visible_area().grow(400.0).has_point(f["pos"] as Vector2):
			if float(f["age"]) > 2.0:
				_flocks.remove_at(i)
	if _t >= _next_flock_t:
		_next_flock_t = _t + CROW_GAP_MIN_S + CROW_GAP_VAR_S * _hash(_flock_n, 41)
		if crows_allowed():
			_start_flock()
	if not _flocks.is_empty():
		queue_redraw()
	if beam_strength(_darkness) > 0.0 or _beam_was_drawn:
		_beam_was_drawn = beam_strength(_darkness) > 0.0
		_beam.queue_redraw()


func _visible_area() -> Rect2:
	if not is_inside_tree():
		return Rect2(-2000, -2000, 4000, 4000)
	return get_canvas_transform().affine_inverse() * get_viewport().get_visible_rect()


func _start_flock() -> void:
	var view := _visible_area()
	var dir := 1.0 if _hash(_flock_n, 42) < 0.5 else -1.0
	var start := Vector2(view.position.x - 60.0 if dir > 0.0 else view.end.x + 60.0, view.position.y + view.size.y * (0.12 + 0.3 * _hash(_flock_n, 43)))
	var birds: Array[Vector3] = []
	var n := FLOCK_MIN + int(_hash(_flock_n, 44) * float(FLOCK_VAR + 1))
	for b in n:
		birds.append(Vector3(-dir * float(b) * (16.0 + 8.0 * _hash(_flock_n * 7 + b, 45)), (_hash(_flock_n * 7 + b, 46) - 0.5) * 36.0, _hash(_flock_n * 7 + b, 47) * 6.0))
	_flocks.append({"pos": start, "dir": dir, "age": 0.0, "birds": birds})
	_flock_n += 1


func _draw() -> void:
	if _tex == null:
		return
	for f in _flocks:
		var dir: float = f["dir"]
		for b: Vector3 in f["birds"]:
			var frame := int(floorf((_t + b.z) * FLAP_FPS)) % 2
			var bob := sin((_t + b.z) * 3.0) * 3.0
			var p := ((f["pos"] as Vector2) + Vector2(b.x, b.y + bob)).round()
			var src := Rect2(frame * 14, 0, 14, _tex.get_height())
			draw_set_transform(p, 0.0, Vector2(dir, 1.0))  # the strip's bird flies to the right; a negative x scale turns it round
			draw_texture_rect_region(_tex, Rect2(Vector2(-7.0, -5.0), Vector2(14.0, float(_tex.get_height()))), src)
	draw_set_transform(Vector2.ZERO)


func _draw_beam() -> void:  # runs as the Beam child's draw
	var k := beam_strength(_darkness)
	if k <= 0.0 or _battle == null or _battle.core == null:
		return
	var origin := IsoProjection.ground_to_screen(_battle.core.ground_pos) + BEAM_ORIGIN
	var ang := beam_angle(_t)
	var dir := Vector2(cos(ang), sin(ang))
	var side := Vector2(-dir.y, dir.x)
	var far := origin + dir * BEAM_LENGTH
	for layer in 3:
		var w := BEAM_FAR_HALF_WIDTH * (1.0 - 0.28 * float(layer))
		var a := (0.09 + 0.07 * float(layer)) * k
		_beam.draw_colored_polygon(PackedVector2Array([origin + side * 3.0, far + side * w, far - side * w, origin - side * 3.0]), Color(0.75, 0.9, 1.0, a))
	_beam.draw_circle(origin, 4.0, Color(1.0, 1.0, 0.9, 0.9 * k))
