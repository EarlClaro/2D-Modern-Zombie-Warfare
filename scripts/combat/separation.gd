class_name Separation
extends RefCounted
## Keeps a horde from stacking on one point (ADR-012): every body that overlaps another is pushed away from it. A spatial
## hash of 1-tile cells (a linked list per cell in packed arrays) is rebuilt from a snapshot of positions and radii every few
## ticks, and a push looks at the first MAX_NEIGHBOURS other bodies in the 3x3 cells around a position, so the cost per
## query is fixed however dense the crowd is. Enemies only; player units and structures are not part of it (spec D6).
## Pure and deterministic: the same snapshot and query always give the same push. Ground-plane tiles only.

## How hard the deepest overlap pushes, as a fraction of the walker's own speed (the caller multiplies).
const STRENGTH: float = 1.5
## Other bodies looked at per query.
const MAX_NEIGHBOURS: int = 8
## A push is a vector no longer than this (1 = one body overlapped completely).
const MAX_PUSH: float = 1.0

var _w: int = 1
var _h: int = 1
var _head: PackedInt32Array = PackedInt32Array()
var _next: PackedInt32Array = PackedInt32Array()
var _pos: PackedVector2Array = PackedVector2Array()
var _rad: PackedFloat32Array = PackedFloat32Array()
var queries: int = 0  # how many pushes were asked for (the stagger keeps this near bodies x ticks / 4)


## Replaces the snapshot. `positions[i]` and `radii[i]` describe body i; a position off the map counts as in the nearest
## border cell. `map_w` and `map_h` are in tiles.
func rebuild(map_w: int, map_h: int, positions: PackedVector2Array, radii: PackedFloat32Array) -> void:
	_w = maxi(map_w, 1)
	_h = maxi(map_h, 1)
	var cells := _w * _h
	if _head.size() != cells:
		_head.resize(cells)
	_head.fill(-1)
	_pos = positions
	_rad = radii
	var n := positions.size()
	_next.resize(n)
	for i in n:
		var cell := _cell_of(positions[i])
		_next[i] = _head[cell]
		_head[cell] = i


func size() -> int:
	return _pos.size()


## The push on body `index` (-1 for a body that is not in the snapshot: no push) standing at `p` with radius `radius`: the sum
## over the overlapping neighbours of the unit vector away from each, weighted by how deep the overlap is (0 touching, 1
## fully inside), clamped to MAX_PUSH. Two bodies at exactly the same spot are pushed apart along +x / -x by index, so the
## answer never depends on chance.
func push(index: int, p: Vector2, radius: float) -> Vector2:
	if index < 0 or index >= _pos.size():
		return Vector2.ZERO
	queries += 1
	var cx := clampi(floori(p.x), 0, _w - 1)
	var cy := clampi(floori(p.y), 0, _h - 1)
	var sum := Vector2.ZERO
	var seen := 0
	for oy in range(maxi(cy - 1, 0), mini(cy + 2, _h)):
		for ox in range(maxi(cx - 1, 0), mini(cx + 2, _w)):
			var j := _head[oy * _w + ox]
			while j != -1 and seen < MAX_NEIGHBOURS:
				if j != index:
					var off := p - _pos[j]
					var min_d := radius + _rad[j]
					var d2 := off.length_squared()
					if d2 < min_d * min_d:
						var d := sqrt(d2)
						var away := off / d if d > 1.0e-4 else (Vector2.RIGHT if index > j else Vector2.LEFT)
						sum += away * ((min_d - d) / min_d)
					seen += 1
				j = _next[j]
	return sum.limit_length(MAX_PUSH)


func _cell_of(p: Vector2) -> int:
	return clampi(floori(p.y), 0, _h - 1) * _w + clampi(floori(p.x), 0, _w - 1)
