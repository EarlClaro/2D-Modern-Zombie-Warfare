class_name LightingConfig
extends RefCounted
## Every tunable of the lighting pass in one place (docs/specs/lighting-pass-2.md). Strengths are 0..1 unless said
## otherwise; lengths are tiles of ground, speeds tiles per second, pixels are screen pixels at zoom 1.

# --- lights (LightField) ---------------------------------------------------------------------------------------
const MAX_LIGHTS: int = 40  # static lights drawn at once (nearest to the screen centre first)
const LIGHT_CULL_MARGIN_PX: float = 120.0  # a light this far outside the screen is still drawn (its pool reaches in)
const HALO_SHARE: float = 0.3  # the bulb's halo is this share of the glow radius; the pool is POOL_SHARE of it
const POOL_SHARE: float = 1.5
const POOL_FLATTEN: float = 0.55  # a circle on the ground is an ellipse on the 2:1 screen
const POOL_ALPHA: float = 0.36
const HALO_ALPHA: float = 0.85
## The wide faint halo around a bright bulb or fire that stands in for bloom when SCREEN_PASS is off.
const BLOOM_HALO_SHARE: float = 1.0
const BLOOM_HALO_ALPHA: float = 0.2
## Flicker: a lamp wobbles a little, a fire a lot. `amount` is the peak dip of the brightness.
const FLICKER_LAMP: float = 0.06
const FLICKER_FIRE: float = 0.28
const FLICKER_SPEED: float = 9.0  # radians per second of the base wobble
## Pieces whose glow colour is this orange (lamps are white to yellow, the red traffic light has too little green)
## count as fires: they flicker strongly and make smoke.
const FIRE_MIN_GREEN: float = 0.4
const FIRE_MAX_GREEN: float = 0.62
const FIRE_MAX_BLUE: float = 0.3

# --- light shadows (LightShadows) ------------------------------------------------------------------------------
const LIGHT_SHADOWS: bool = true
const SHADOW_STRENGTH: float = 0.9  # how much of the light's own pool a wall removes behind it
const LIGHT_MIN_HEIGHT: float = 0.9  # a light is taken to be at least this many tiles above the ground (fires)
const SHADOW_MAX_CASTERS: int = 14  # nearest casters per light
const SHADOW_MIN_HEIGHT: float = 0.8  # lower pieces do not block a lamp

# --- flashes from combat (muzzle, explosion) -------------------------------------------------------------------
const FLASH_MUZZLE_RADIUS_PX: float = 70.0
const FLASH_MUZZLE_S: float = 0.09
const FLASH_MUZZLE_COLOR: Color = Color(1.0, 0.78, 0.4, 0.55)
const FLASH_BLAST_RADIUS_PER_TILE_PX: float = 56.0
const FLASH_BLAST_S: float = 0.35
const FLASH_BLAST_COLOR: Color = Color(1.0, 0.6, 0.25, 0.8)
const MAX_FLASHES: int = 24
const FLASH_MIN_DARKNESS: float = 0.0  # flashes are visible at any hour; at noon they are faint because of the base tint

# --- post pass (PostFx) ----------------------------------------------------------------------------------------
const POST_ENABLED: bool = true
## True reads the finished picture for real bloom of the brightest pixels and a luminance-keyed teal-orange grade
## (post_fx.gdshader). That copies the whole frame: 14 ms per frame on the MX330 laptop (72 -> about 25 FPS), so it is
## off. The default overlay (post_overlay.gdshader) does mist, clouds, vignette, edge fade and sun gradient for free,
## the lamps' wide halos stand in for bloom, and the grade comes from the cool ambient tint and the warm lights.
const SCREEN_PASS: bool = false
const OVERLAY_DIVISOR: float = 4.0  # the overlay is drawn at 1/4 of the screen size per axis and stretched
const BLOOM_ENABLED: bool = true
const BLOOM_THRESHOLD: float = 0.72  # only pixels brighter than this bloom
const BLOOM_STRENGTH: float = 0.55
const BLOOM_RADIUS_PX: float = 7.0  # of the inner ring; the outer ring is twice as wide
const VIGNETTE_DAY: float = 0.22
const VIGNETTE_NIGHT: float = 0.5
const VIGNETTE_START: float = 0.55  # distance from the centre (0 centre, 1 corner) where it starts
const GRADE_SATURATION: float = 1.04
const GRADE_CONTRAST: float = 1.04
## Split toning added to the shadows and highlights (rgb offsets). By day warm highlights and cool shadows,
## at night the teal and orange look.
const GRADE_SHADOW_DAY: Color = Color(-0.008, 0.0, 0.014)
const GRADE_HIGH_DAY: Color = Color(0.03, 0.014, -0.02)
const GRADE_SHADOW_NIGHT: Color = Color(-0.02, 0.02, 0.035)
const GRADE_HIGH_NIGHT: Color = Color(0.07, 0.03, -0.05)
const MIST_NIGHT: float = 0.16  # ground mist strength at night; by day a third of it
const MIST_RAIN_BONUS: float = 0.06
const MIST_COLOR: Color = Color(0.5, 0.6, 0.78)
const MIST_SCALE_TILES: float = 11.0  # size of a mist bank
const MIST_SPEED: Vector2 = Vector2(0.35, 0.12)  # tiles per second the mist drifts
const CLOUD_STRENGTH: float = 0.2  # darkest cloud shadow, by day
const CLOUD_SCALE_TILES: float = 26.0
const CLOUD_SPEED: Vector2 = Vector2(0.45, 0.2)
const SUN_GRADIENT: float = 0.07  # the sun side of the map is this much brighter, the far side this much darker
const EDGE_FADE_TILES: float = 7.0  # the map edge fades into the sky colour over this many tiles
const EDGE_FADE_STRENGTH: float = 0.88
const EDGE_OUTSIDE_TILES: float = 4.0  # beyond the edge the fade releases again so aircraft entering stay visible

# --- ground (ground.gdshader) ----------------------------------------------------------------------------------
const GROUND_LIGHTS: int = 4  # nearest lights that reflect in wet ground (each is a loop pass per pixel: 5 ms for 8)
const WET_DRY: float = 0.0
const WET_DAMP: float = 0.35  # concrete, paving
const WET_SLICK: float = 0.7  # asphalt, runway, steel deck
const RAIN_LEVEL: float = 1.0  # how hard it rains, for the ground (wetness is the terrain's wettability times this)
const REFLECTION_STRENGTH: float = 0.8
const REFLECTION_STREAK: float = 3.2  # how much taller than wide a lamp's reflection is
const RIPPLE_CELL_PX: float = 26.0  # puddle ripples: one ring per cell of this size
const RIPPLE_PERIOD_S: float = 1.3
const RIPPLE_STRENGTH: float = 0.5
const GROUND_VARIATION: float = 0.07  # low-frequency brightness variation that breaks up the tile checker
const GROUND_VARIATION_TILES: float = 5.0
const WATER_SHIMMER: float = 0.12
const WATER_SPARKLE: float = 0.7
const WATER_SCROLL: Vector2 = Vector2(0.06, 0.03)  # tiles per second
const FOAM_ALPHA: float = 0.55
const FOAM_WIDTH_PX: float = 2.0

# --- rain (WeatherView) ----------------------------------------------------------------------------------------
const RAIN_FAR_STREAKS: int = 120
const RAIN_NEAR_STREAKS: int = 70
const RAIN_FAR_ALPHA: float = 0.18
const RAIN_NEAR_ALPHA: float = 0.34
const RAIN_LIT_BOOST: float = 2.4  # brightness multiplier of a drop inside a light's radius
const RAIN_LIGHTS: int = 12  # nearest lights that can brighten drops

# --- day (sun, shadows, ambient motion) ------------------------------------------------------------------------
const SUN_SHADOW_COLOR: Color = Color(0.03, 0.06, 0.16, 1.0)  # shadows are a dark blue, not black
const SUN_SHADOW_ALPHA: float = 0.24
const SHADOW_LENGTH_REBUILD_DELTA: float = 0.08  # rebuild the scenery shadows when the sun's scale changed this much
const CONTACT_AO_ALPHA: float = 0.2  # the dark seam where an object meets the ground
const CONTACT_AO_GROW: float = 0.12  # tiles the seam reaches beyond the footprint
const UNIT_SHADOW_COLOR: Color = Color(0.02, 0.05, 0.14, 1.0)
const SWAY_AMPLITUDE_PX: float = 1.6  # at the top of a tree
const SWAY_SPEED: float = 1.3
const SMOKE_MAX_PUFFS: int = 70
const SMOKE_INTERVAL_S: float = 0.45  # per burning piece
const SMOKE_RISE_PX: float = 34.0  # per second
const SMOKE_LIFE_S: float = 3.4
const SMOKE_MAX_SOURCES: int = 8  # nearest burning pieces that smoke
const DUST_MAX_PUFFS: int = 40
const DUST_INTERVAL_S: float = 0.22  # how often moving units are sampled
const DUST_PER_TICK: int = 3
const DUST_MIN_MOVE_TILES: float = 0.04  # a unit must have moved this far since the last sample to kick up dust
const DUST_LIFE_S: float = 0.9
