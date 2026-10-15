class_name IsoProjection
extends RefCounted
## The only place that contains isometric projection math (ADR-002/003).
## Ground space: Vector2 in tiles. +X = screen down-right, +Y = screen down-left. Altitude z is separate.
## See docs/specs/isometric-view.md.

const TILE_W: float = 64.0
const TILE_H: float = 32.0
## Screen pixels of upward offset per 1.0 altitude unit.
const Z_PX_PER_UNIT: float = 32.0

## Sprite facings in screen terms. Each corresponds to one of the 8 principal ground directions.
enum Facing { E, SE, S, SW, W, NW, N, NE }


static func ground_to_screen(g: Vector2) -> Vector2:
	return Vector2((g.x - g.y) * TILE_W * 0.5, (g.x + g.y) * TILE_H * 0.5)


static func screen_to_ground(s: Vector2) -> Vector2:
	return Vector2(s.x / TILE_W + s.y / TILE_H, s.y / TILE_H - s.x / TILE_W)


## Screen position of a point at altitude z above ground position g.
static func ground_to_screen_z(g: Vector2, z: float) -> Vector2:
	var s := ground_to_screen(g)
	s.y -= z * Z_PX_PER_UNIT
	return s


static func cell_of(g: Vector2) -> Vector2i:
	return Vector2i(floori(g.x), floori(g.y))


static func cell_center(c: Vector2i) -> Vector2:
	return Vector2(c.x + 0.5, c.y + 0.5)


## Semi-axes (screen px) of the axis-aligned ellipse that a ground circle of radius r (tiles) projects to.
static func ellipse_radii(r: float) -> Vector2:
	return Vector2(r * TILE_W / sqrt(2.0), r * TILE_H / sqrt(2.0))


## Quantize a ground-space direction to one of 8 facings (45° ground sectors).
## Returns -1 for a (near-)zero vector; callers should keep their previous facing.
static func facing_from_ground_dir(dir: Vector2) -> int:
	if dir.length_squared() < 1e-12:
		return -1
	# Ground angle 0 = +X = SE; increasing angle goes toward +Y (SW side).
	var idx := posmod(roundi(atan2(dir.y, dir.x) / (PI / 4.0)), 8)
	const BY_SECTOR: Array[int] = [
		Facing.SE, Facing.S, Facing.SW, Facing.W, Facing.NW, Facing.N, Facing.NE, Facing.E,
	]
	return BY_SECTOR[idx]


## Draw-order key: larger = nearer the camera = drawn in front.
static func sort_key(g: Vector2) -> float:
	return g.x + g.y
