class_name PostFx
extends CanvasLayer
## The battle's finishing pass: one full-screen shader (assets/shaders/post_fx.gdshader) with bloom of the brightest
## pixels, ground mist, cloud shadows, a sun gradient, the map-edge fade, a teal-and-orange or warm-and-cool grade
## and a vignette. Sits above the world and the weather and below the HUD. Presentation only; every value comes
## from LightingConfig and the time of day.

const OVERLAY: Shader = preload("res://assets/shaders/post_overlay.gdshader")
const SCREEN: Shader = preload("res://assets/shaders/post_fx.gdshader")

var _rect: Control  # what the player sees: the full-screen pass (SCREEN_PASS) or the upscaled overlay
var _sub: SubViewport  # the overlay is drawn small (it is all soft gradients) and stretched over the screen
var _mat: ShaderMaterial
var _battle: BattleController


func bind(battle: BattleController) -> void:
	_battle = battle
	layer = 4
	name = "PostFx"
	_mat = ShaderMaterial.new()
	_mat.shader = SCREEN if LightingConfig.SCREEN_PASS else OVERLAY
	var pass_rect := ColorRect.new()
	pass_rect.name = "Pass"
	pass_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pass_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	pass_rect.material = _mat
	if LightingConfig.SCREEN_PASS:
		_rect = pass_rect
		add_child(_rect)
	else:
		_sub = SubViewport.new()
		_sub.name = "Small"
		_sub.transparent_bg = true
		_sub.disable_3d = true
		_sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		_sub.size = Vector2i(480, 270)
		_sub.add_child(pass_rect)
		add_child(_sub)
		var show := TextureRect.new()
		show.name = "Overlay"
		show.mouse_filter = Control.MOUSE_FILTER_IGNORE
		show.set_anchors_preset(Control.PRESET_FULL_RECT)
		show.stretch_mode = TextureRect.STRETCH_SCALE
		show.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		show.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		show.texture = _sub.get_texture()
		var blend := CanvasItemMaterial.new()
		blend.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
		show.material = blend
		_rect = show
		add_child(_rect)
	var gx := IsoProjection.screen_to_ground(Vector2(1.0, 0.0))
	var gy := IsoProjection.screen_to_ground(Vector2(0.0, 1.0))
	_mat.set_shader_parameter("noise_tex", LightingNoise.texture())
	_mat.set_shader_parameter("world_to_ground", Vector4(gx.x, gy.x, gx.y, gy.y))
	var map := battle.mission.map if battle.mission != null else null
	if map != null:
		_mat.set_shader_parameter("map_size", Vector2(map.width(), map.height()))
	if LightingConfig.SCREEN_PASS:
		_mat.set_shader_parameter("bloom_threshold", LightingConfig.BLOOM_THRESHOLD)
		_mat.set_shader_parameter("bloom_radius", LightingConfig.BLOOM_RADIUS_PX)
		_mat.set_shader_parameter("saturation", LightingConfig.GRADE_SATURATION)
		_mat.set_shader_parameter("contrast", LightingConfig.GRADE_CONTRAST)
	_mat.set_shader_parameter("vignette_start", LightingConfig.VIGNETTE_START)
	_mat.set_shader_parameter("mist_color", LightingConfig.MIST_COLOR)
	_mat.set_shader_parameter("mist_scale", LightingConfig.MIST_SCALE_TILES)
	_mat.set_shader_parameter("mist_velocity", LightingConfig.MIST_SPEED)
	_mat.set_shader_parameter("cloud_scale", LightingConfig.CLOUD_SCALE_TILES)
	_mat.set_shader_parameter("cloud_velocity", LightingConfig.CLOUD_SPEED)
	_mat.set_shader_parameter("sun_gradient", LightingConfig.SUN_GRADIENT)
	_mat.set_shader_parameter("edge_fade", LightingConfig.EDGE_FADE_TILES)
	_mat.set_shader_parameter("edge_strength", LightingConfig.EDGE_FADE_STRENGTH)
	_mat.set_shader_parameter("edge_outside", LightingConfig.EDGE_OUTSIDE_TILES)
	_rect.visible = LightingConfig.POST_ENABLED


## The look for a time of day: `dark` is DayNight.darkness_at, `sky` its sky colour, `weather` the mission's.
func set_look(dark: float, sky: Color, weather: String) -> void:
	_mat.set_shader_parameter("darkness", dark)
	_mat.set_shader_parameter("sky_color", sky)
	if LightingConfig.SCREEN_PASS:
		_mat.set_shader_parameter("bloom_strength", LightingConfig.BLOOM_STRENGTH if LightingConfig.BLOOM_ENABLED else 0.0)
		_mat.set_shader_parameter("high_tone", _vec(LightingConfig.GRADE_HIGH_DAY.lerp(LightingConfig.GRADE_HIGH_NIGHT, dark)))
	_mat.set_shader_parameter("vignette", lerpf(LightingConfig.VIGNETTE_DAY, LightingConfig.VIGNETTE_NIGHT, dark))
	_mat.set_shader_parameter("shadow_tone", _vec(LightingConfig.GRADE_SHADOW_DAY.lerp(LightingConfig.GRADE_SHADOW_NIGHT, dark)))
	_mat.set_shader_parameter("mist_strength", mist_for(dark, weather))
	_mat.set_shader_parameter("cloud_strength", cloud_for(weather))


## Mist strength: a third of the night's by day, more in rain, none in fog (the fog overlay is the mist then).
static func mist_for(dark: float, weather: String) -> float:
	var s := lerpf(LightingConfig.MIST_NIGHT / 3.0, LightingConfig.MIST_NIGHT, dark)
	if weather == "rain":
		s += LightingConfig.MIST_RAIN_BONUS
	elif weather == "fog":
		s *= 0.4
	return s


## Cloud shadows: full strength in clear weather, faint under an overcast sky.
static func cloud_for(weather: String) -> float:
	return LightingConfig.CLOUD_STRENGTH * (1.0 if weather == "clear" else 0.35)


func _process(_delta: float) -> void:
	if _battle == null or not _rect.visible:
		return
	var inv := _battle.get_canvas_transform().affine_inverse()
	var view := get_viewport().get_visible_rect().size
	if _sub != null:
		var want := Vector2i((view / LightingConfig.OVERLAY_DIVISOR).ceil())
		if _sub.size != want and want.x > 0 and want.y > 0:
			_sub.size = want
	_mat.set_shader_parameter("view_size", view)
	_mat.set_shader_parameter("world_origin", inv * Vector2.ZERO)
	_mat.set_shader_parameter("world_per_px", inv.x.length())


static func _vec(c: Color) -> Vector3:
	return Vector3(c.r, c.g, c.b)
