class_name Atmosphere
extends Node
## Time of day and weather for a battle: tints the whole world (CanvasModulate), keeps effects bright at night,
## lights lamps and fires with soft glows, and draws rain, fog or dust over the screen. Presentation only: it
## reads `battle.elapsed` and the mission's settings and never touches the simulation.

var _battle: BattleController
var _tint: CanvasModulate
var _glow: GlowLayer
var _screen: CanvasLayer
var _weather_view: WeatherView
var _last_darkness: float = -1.0
var _last_weather: String = ""


func bind(battle: BattleController) -> void:
	_battle = battle
	_tint = CanvasModulate.new()
	_tint.name = "Tint"
	battle.add_child(_tint)
	_glow = GlowLayer.new()
	_glow.name = "Glows"
	battle.add_child(_glow)
	_screen = CanvasLayer.new()
	_screen.layer = 5
	_screen.name = "WeatherScreen"
	add_child(_screen)
	_weather_view = WeatherView.new()
	_weather_view.name = "Weather"
	_screen.add_child(_weather_view)
	set_process(true)
	_refresh(true)


func _process(_delta: float) -> void:
	_refresh(false)


func _refresh(force: bool) -> void:
	var m := _battle.mission
	if m == null:
		return
	var t := DayNight.time_at(m.time_of_day, m.day_length_s, _battle.elapsed)
	var tint := DayNight.tint_at(t) * DayNight.weather_tint(m.weather)
	tint.a = 1.0
	_tint.color = tint
	# Effects (explosions, muzzle flashes, sparks) keep their own brightness: cancel the tint on their layer.
	var fx := _battle.fx_layer()
	fx.modulate = Color(1.0 / maxf(tint.r, 0.2), 1.0 / maxf(tint.g, 0.2), 1.0 / maxf(tint.b, 0.2), 1.0)
	_glow.modulate = fx.modulate  # lamp light is not tinted blue by the night either
	var dark := DayNight.darkness_at(t)
	if force or absf(dark - _last_darkness) > 0.02 or m.weather != _last_weather:
		_last_darkness = dark
		_last_weather = m.weather
		_glow.refresh(_battle, dark)
		_weather_view.set_weather(m.weather)


## Soft additive glows at the lamps and fires of the scenery, scaled by how dark it is.
class GlowLayer:
	extends Node2D

	static var _tex: ImageTexture  # one soft round falloff shared by every glow

	var _items: Array[Dictionary] = []
	var _darkness: float = 0.0

	static func _glow_texture() -> ImageTexture:
		if _tex == null:
			var n := 64
			var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
			for y in n:
				for x in n:
					var d := Vector2(x + 0.5 - n * 0.5, y + 0.5 - n * 0.5).length() / (n * 0.5)
					var a := clampf(1.0 - d, 0.0, 1.0)
					a = a * a * (3.0 - 2.0 * a)
					img.set_pixel(x, y, Color(1, 1, 1, a))
			_tex = ImageTexture.create_from_image(img)
		return _tex

	func _init() -> void:
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = mat
		z_index = 50

	func refresh(battle: BattleController, darkness: float) -> void:
		_darkness = darkness
		_items.clear()
		for s in battle.scenery_nodes:
			if s.def.glow_radius > 0.0:
				_items.append({"pos": s.position + s.def.glow_offset, "r": s.def.glow_radius, "c": s.def.glow_color})
		visible = darkness > 0.05 and not _items.is_empty()
		queue_redraw()

	func _draw() -> void:
		var tex := _glow_texture()
		for it in _items:
			var col: Color = it["c"]
			var r: float = it["r"]
			var pos: Vector2 = it["pos"]
			draw_texture_rect(tex, Rect2(pos - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(col.r, col.g, col.b, 0.55 * _darkness * col.a))


## Rain streaks, fog banks or dust drifting over the screen (screen space, so it does not move with the camera).
class WeatherView:
	extends Control

	const STREAKS: int = 160
	var weather: String = "clear"
	var _t: float = 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func set_weather(w: String) -> void:
		weather = w
		visible = w != "clear"
		queue_redraw()

	func _process(delta: float) -> void:
		if weather == "clear":
			return
		_t += delta
		queue_redraw()

	func _hash(i: int, k: int) -> float:
		return fposmod(sin(float(i) * 12.9898 + float(k) * 78.233) * 43758.5453, 1.0)

	func _draw() -> void:
		var size := get_viewport_rect().size
		match weather:
			"rain":
				draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.14, 0.2, 0.12))
				var pts := PackedVector2Array()
				for i in STREAKS:  # one draw call for every streak
					var speed := 900.0 + 400.0 * _hash(i, 1)
					var x := fposmod(_hash(i, 2) * (size.x + 300.0) - _t * 260.0 * (0.6 + _hash(i, 3)), size.x + 300.0) - 150.0
					var y := fposmod(_hash(i, 4) * size.y + _t * speed, size.y + 60.0) - 30.0
					var len_px := 12.0 + 12.0 * _hash(i, 5)
					pts.append(Vector2(x, y))
					pts.append(Vector2(x - len_px * 0.3, y + len_px))
				draw_multiline(pts, Color(0.75, 0.82, 0.95, 0.35), 1.0)
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
