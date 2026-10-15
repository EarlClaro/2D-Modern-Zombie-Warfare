class_name SpriteSheet
extends Resource
## Frame layout of a unit/enemy sprite set plus the draw helper. `textures` is keyed by facing name
## ("E", "SE", "S", "SW", "W", "NW", "N", "NE"), one sheet per facing, all with the same frame layout.
## A facing without its own texture mirrors its right-hand counterpart (SW/W/NW from SE/E/NE; ADR-008
## 5-mirrored fallback), and a missing direction falls back to "SE". Presentation only: no rules here.

const MIRROR_OF: Array[String] = ["E", "SE", "S", "SE", "E", "NE", "N", "NE"]  # indexed by IsoProjection.Facing

## Facing name -> Texture2D (a subset is fine, see above).
@export var textures: Dictionary = {}
@export var frame_size: Vector2i = Vector2i(32, 32)
@export var columns: int = 3
## Pixel in a frame that sits on the entity's footprint base point (feet ground contact).
@export var origin: Vector2 = Vector2(16.0, 27.0)
## Body height used for tracer origins / hit points (px above the footprint).
@export var chest_px: float = 12.0
## Art height above the footprint base point (px); places the health bar.
@export var height_px: float = 27.0
@export var idle_frame: int = 0
@export var walk_first: int = 1
@export var walk_count: int = 4
@export var walk_fps: float = 8.0
## Ground distance (tiles) covered by one full walk cycle. When > 0 the walk animation speed follows the
## entity's move speed (cycle rate = speed / stride_tiles), so feet do not slide; else `walk_fps` is used.
@export var stride_tiles: float = 0.0
## Frame shown briefly after a melee swing; -1 = none.
@export var attack_frame: int = -1
## Frame shown for a moment after each shot (recoil pose); -1 = none.
@export var fire_frame: int = -1
## Cycle the walk frames even while standing still (helicopter rotor).
@export var always_animate: bool = false
## Death animation: `death_count` frames from `death_first` play once, the last holds, then it fades.
@export var death_first: int = -1
@export var death_count: int = 0
@export var death_fps: float = 12.0
@export var death_hold_s: float = 0.5
@export var death_fade_s: float = 0.5
## Aircraft: the first N death frames play while it falls to the ground (altitude -> 0 over N/death_fps s).
@export var death_fall_frames: int = 0
## Fireball radius in px drawn at the wreck (0 = none, e.g. infantry). It goes off when the fall ends.
@export var explosion_px: float = 0.0


func frame_region(frame: int) -> Rect2:
	var col := frame % columns
	@warning_ignore("integer_division")
	var row := frame / columns
	return Rect2(Vector2(col * frame_size.x, row * frame_size.y), Vector2(frame_size))


## Walk-cycle frame for an animation clock that only advances while moving.
func walk_frame(t_s: float, move_speed: float = 0.0) -> int:
	var fps := walk_fps
	if stride_tiles > 0.0 and move_speed > 0.0:
		fps = move_speed / stride_tiles * float(walk_count)
	return walk_first + posmod(floori(t_s * fps), walk_count)


func has_death() -> bool:
	return death_first >= 0 and death_count > 0


## Seconds from the start of the death animation until the wreck hits the ground (0 for ground units).
func fall_time_s() -> float:
	return float(death_fall_frames) / death_fps if death_fps > 0.0 else 0.0


## Height of the art above the footprint base point, for health bars.
func top_px() -> float:
	return height_px


## Name of the direction whose art is drawn for `facing` when the sheet has no exact texture for it.
static func art_direction(facing: int) -> String:
	return MIRROR_OF[facing]


## True when the facing points to the screen's left, so right-facing art would be mirrored.
static func faces_left(facing: int) -> bool:
	return IsoProjection.ground_to_screen(IsoProjection.ground_dir_of_facing(facing)).x < -0.001


## An exact texture for this facing exists (no mirroring needed).
func has_exact(facing: int) -> bool:
	return textures.has(IsoProjection.facing_name(facing))


## Mirror the texture when drawing `facing`: only left-hand facings that borrow right-hand art.
func is_mirrored(facing: int) -> bool:
	return faces_left(facing) and not has_exact(facing)


## Texture drawn for `facing`: exact, else its mirror source, else "SE", else null.
func texture_for(facing: int) -> Texture2D:
	var tex: Texture2D = textures.get(IsoProjection.facing_name(facing), null)
	if tex == null:
		tex = textures.get(art_direction(facing), null)
	if tex == null:
		tex = textures.get("SE", null)
	return tex


## Draws one frame with its origin at `offset` (entity-local px). Leaves the canvas transform reset.
func draw_frame(ci: CanvasItem, frame: int, facing: int, offset: Vector2 = Vector2.ZERO) -> void:
	var tex := texture_for(facing)
	if tex == null:
		return
	ci.draw_set_transform(offset, 0.0, Vector2(-1.0 if is_mirrored(facing) else 1.0, 1.0))
	ci.draw_texture_rect_region(tex, Rect2(-origin, Vector2(frame_size)), frame_region(frame))
	ci.draw_set_transform(Vector2.ZERO)
