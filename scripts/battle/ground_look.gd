class_name GroundLook
extends Node
## Puts the ground shader (assets/shaders/ground.gdshader) on the terrain layer: which terrains get wet in the rain
## and reflect the nearest lights, which are water, and the lights themselves. Presentation only.

const SHADER: Shader = preload("res://assets/shaders/ground.gdshader")
const MAX_ROWS: int = 64  # size of the shader's per-row tables
const MAX_LIGHTS: int = 4  # size of the shader's light arrays
## How wettable each terrain is (0 = soaks it up, 1 = a mirror): what rain does to it.
const WETTABLE: Dictionary = {
	"road": LightingConfig.WET_DAMP, "paved": LightingConfig.WET_DAMP, "asphalt": LightingConfig.WET_SLICK,
	"lane_x": LightingConfig.WET_SLICK, "lane_y": LightingConfig.WET_SLICK, "cracked_asphalt": LightingConfig.WET_SLICK,
	"cobble": LightingConfig.WET_DAMP, "brick": LightingConfig.WET_DAMP, "concrete_tile": LightingConfig.WET_DAMP,
	"hazard": LightingConfig.WET_DAMP, "steel_deck": LightingConfig.WET_SLICK, "runway_x": LightingConfig.WET_SLICK,
	"runway_y": LightingConfig.WET_SLICK, "ice": LightingConfig.WET_DAMP, "mud": LightingConfig.WET_DAMP,
}
const WATER: Array[String] = ["water", "shallows"]

var _mat: ShaderMaterial


## Wettability by atlas row (padded to MAX_ROWS).
static func wet_table() -> PackedFloat32Array:
	var t := PackedFloat32Array()
	t.resize(MAX_ROWS)
	for row in TerrainCatalog.count():
		t[row] = float(WETTABLE.get(TerrainCatalog.ALL[row]["id"], LightingConfig.WET_DRY))
	return t


## 1.0 for the atlas rows that are water.
static func water_table() -> PackedFloat32Array:
	var t := PackedFloat32Array()
	t.resize(MAX_ROWS)
	for row in TerrainCatalog.count():
		t[row] = 1.0 if WATER.has(TerrainCatalog.ALL[row]["id"]) else 0.0
	return t


## The nearest `n` of `lights` to world point `centre`, packed for the shader: `a` = (x, y, radius, brightness) of the
## pool, `b` = colour. Lights that are off are skipped.
static func pack_lights(lights: Array[Dictionary], centre: Vector2, n: int) -> Dictionary:
	var live: Array[Dictionary] = []
	for it in lights:
		if float(it["k"]) > 0.02:
			live.append(it)
	live.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a["ground"] as Vector2).distance_squared_to(centre) < (b["ground"] as Vector2).distance_squared_to(centre))
	var a := PackedVector4Array()
	var b := PackedVector4Array()
	for i in mini(mini(n, MAX_LIGHTS), live.size()):
		var it: Dictionary = live[i]
		var g: Vector2 = it["ground"]
		var c: Color = it["c"]
		a.append(Vector4(g.x, g.y, float(it["pr"]), float(it["k"])))
		b.append(Vector4(c.r, c.g, c.b, 1.0))
	var count := a.size()
	while a.size() < MAX_LIGHTS:
		a.append(Vector4.ZERO)
		b.append(Vector4.ZERO)
	return {"a": a, "b": b, "count": count}


func bind(ground: TileMapLayer) -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("noise_tex", LightingNoise.texture())
	_mat.set_shader_parameter("row_count", float(TerrainCatalog.count()))
	_mat.set_shader_parameter("wet", wet_table())
	_mat.set_shader_parameter("water", water_table())
	_mat.set_shader_parameter("variation", LightingConfig.GROUND_VARIATION)
	_mat.set_shader_parameter("variation_px", LightingConfig.GROUND_VARIATION_TILES * IsoProjection.TILE_W * 0.75)
	_mat.set_shader_parameter("reflection_strength", LightingConfig.REFLECTION_STRENGTH)
	_mat.set_shader_parameter("reflection_streak", LightingConfig.REFLECTION_STREAK)
	_mat.set_shader_parameter("ripple_cell", LightingConfig.RIPPLE_CELL_PX)
	_mat.set_shader_parameter("ripple_period", LightingConfig.RIPPLE_PERIOD_S)
	_mat.set_shader_parameter("ripple_strength", LightingConfig.RIPPLE_STRENGTH)
	_mat.set_shader_parameter("shimmer", LightingConfig.WATER_SHIMMER)
	_mat.set_shader_parameter("sparkle", LightingConfig.WATER_SPARKLE)
	_mat.set_shader_parameter("scroll", LightingConfig.WATER_SCROLL)
	ground.material = _mat


func set_look(dark: float, sky: Color, weather: String) -> void:
	_mat.set_shader_parameter("darkness", dark)
	_mat.set_shader_parameter("sky_color", sky)
	_mat.set_shader_parameter("rain", LightingConfig.RAIN_LEVEL if weather == "rain" else 0.0)


func set_lights(lights: Array[Dictionary], centre: Vector2) -> void:
	var p := pack_lights(lights, centre, LightingConfig.GROUND_LIGHTS)
	_mat.set_shader_parameter("light_a", p["a"])
	_mat.set_shader_parameter("light_b", p["b"])
	_mat.set_shader_parameter("light_count", p["count"])
