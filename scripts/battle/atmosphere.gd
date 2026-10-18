class_name Atmosphere
extends Node
## Time of day and weather for a battle: tints the whole world (CanvasModulate), keeps effects bright at night, lights
## lamps and fires (LightField), draws rain, fog or dust (WeatherView) and finishes the picture with bloom, mist,
## grade and vignette (PostFx). Presentation only: it reads `battle.elapsed` and the mission's settings and never
## touches the simulation. Every tunable is in LightingConfig (docs/specs/lighting-pass-2.md).

## Thunder after a lightning strike: `delay_s` is how long after the flash it should be heard (BattleFeedback plays it).
signal thunder(delay_s: float)

var _battle: BattleController
var _tint: CanvasModulate
var _glow: LightField
var _screen: CanvasLayer
var _sky: SkyLife
var _weather_view: WeatherView
var _post: PostFx
var _ground_look: GroundLook
var _foam: ShoreFoam
var _ambient: AmbientFx
var _last_t: float = -1.0
var _clear_before: Color = Color(0.3, 0.3, 0.3)
var _last_darkness: float = -1.0
var _last_weather: String = ""


func bind(battle: BattleController) -> void:
	_battle = battle
	_tint = CanvasModulate.new()
	_tint.name = "Tint"
	battle.add_child(_tint)
	_glow = LightField.new()
	_glow.name = "Glows"
	battle.add_child(_glow)
	_screen = CanvasLayer.new()
	_screen.layer = 3  # under the finishing pass, so the rain is graded with the rest of the picture
	_screen.name = "WeatherScreen"
	add_child(_screen)
	_weather_view = WeatherView.new()
	_weather_view.name = "Weather"
	_screen.add_child(_weather_view)
	_weather_view.lightning_struck.connect(func(delay_s: float) -> void: thunder.emit(delay_s))
	_post = PostFx.new()
	add_child(_post)
	_post.bind(battle)
	_clear_before = RenderingServer.get_default_clear_color()
	var ground := battle.get_node_or_null("Ground") as TileMapLayer
	if ground != null:
		_ground_look = GroundLook.new()
		_ground_look.name = "GroundLook"
		add_child(_ground_look)
		_ground_look.bind(ground)
	if battle.mission != null and battle.mission.map != null:
		_foam = ShoreFoam.new()
		_foam.name = "ShoreFoam"
		battle.decal_layer().add_child(_foam)
		_foam.build(battle.mission.map)
	_ambient = AmbientFx.new()
	_ambient.name = "Ambient"
	battle.add_child(_ambient)
	_ambient.bind(battle, battle.mission.weather if battle.mission != null else "clear")
	_sky = SkyLife.new()
	_sky.name = "Sky"
	battle.add_child(_sky)
	_sky.bind(battle, battle.mission.weather if battle.mission != null else "clear")
	battle.shot_fired.connect(_on_shot)
	battle.blast_landed.connect(_on_blast)
	battle.projectile_launched.connect(_on_launch)
	set_process(true)
	_refresh(true)


func _process(_delta: float) -> void:
	_refresh(false)
	_feed_weather()
	_feed_ground()


func _exit_tree() -> void:
	RenderingServer.set_default_clear_color(_clear_before)


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
	_sky.set_darkness(dark)
	if force or absf(t - _last_t) > 0.0005 or m.weather != _last_weather:
		_last_t = t
		var sky := DayNight.sky_at(t)
		_post.set_look(dark, sky, m.weather)
		if _ground_look != null:
			_ground_look.set_look(dark, sky, m.weather)
		RenderingServer.set_default_clear_color(sky)  # nothing outside the map is grey
	if force or absf(dark - _last_darkness) > 0.02 or m.weather != _last_weather:
		_last_darkness = dark
		_last_weather = m.weather
		_glow.refresh(_battle, dark)
		_ambient.collect_fires()
		_weather_view.set_weather(m.weather)
	# Shadows are crisp in the sun and soften into the dark.
	if is_instance_valid(_battle.scenery_shadows):
		_battle.scenery_shadows.set_sun_scale(DayNight.shadow_scale_at(t))
		_battle.scenery_shadows.modulate.a = lerpf(1.0, 0.55, dark)


## Gives the rain the lights near the screen (in screen px) so drops passing through them are drawn brighter.
func _feed_weather() -> void:
	if not _battle.is_inside_tree():
		return
	if _weather_view.weather == "snow":  # snow has no lights to pick up, only the camera for its parallax
		_weather_view.set_camera(_battle.camera_node().position)
		return
	if _weather_view.weather != "rain":
		return
	var ct := _battle.get_canvas_transform()
	var zoom := ct.x.length()
	var centre := get_viewport().get_visible_rect().size * 0.5
	var lights: Array[Dictionary] = []
	for it in _glow.visible_lights():
		if float(it["k"]) < 0.05:
			continue
		lights.append({"c": ct * (it["ground"] as Vector2), "b": ct * (it["pos"] as Vector2), "r": float(it["pr"]) * zoom, "k": float(it["k"])})
	if lights.size() > LightingConfig.RAIN_LIGHTS:
		lights.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return (a["c"] as Vector2).distance_squared_to(centre) < (b["c"] as Vector2).distance_squared_to(centre))
		lights.resize(LightingConfig.RAIN_LIGHTS)
	_weather_view.set_lights(lights)
	_weather_view.set_camera(_battle.camera_node().position)


## Gives the wet ground the nearest lights to reflect (only while it rains).
func _feed_ground() -> void:
	if _ground_look == null or _weather_view.weather != "rain" or not _battle.is_inside_tree():
		return
	var centre := (_battle.get_canvas_transform().affine_inverse() * (get_viewport().get_visible_rect().size * 0.5))
	_ground_look.set_lights(_glow.visible_lights(), centre)


func _on_shot(shooter: BattleUnit, _target: BattleEnemy) -> void:
	if is_instance_valid(shooter):
		_glow.add_flash(shooter.muzzle_world(), LightingConfig.FLASH_MUZZLE_RADIUS_PX, LightingConfig.FLASH_MUZZLE_S, LightingConfig.FLASH_MUZZLE_COLOR)


func _on_blast(center: Vector2, radius: float) -> void:
	_glow.add_flash(IsoProjection.ground_to_screen(center), radius * LightingConfig.FLASH_BLAST_RADIUS_PER_TILE_PX, LightingConfig.FLASH_BLAST_S, LightingConfig.FLASH_BLAST_COLOR)


func _on_launch(shooter: BattleUnit, _weapon: WeaponDefinition, from_ground: Vector2, _target: Vector2) -> void:
	if is_instance_valid(shooter):
		_glow.add_flash(IsoProjection.ground_to_screen_z(from_ground, shooter.altitude), LightingConfig.FLASH_MUZZLE_RADIUS_PX * 1.4, LightingConfig.FLASH_MUZZLE_S * 2.0, LightingConfig.FLASH_MUZZLE_COLOR)
