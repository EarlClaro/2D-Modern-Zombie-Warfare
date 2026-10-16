class_name EnemyIndex
extends RefCounted
## Spatial index of the living enemies for one tick: a uniform grid of 2-tile cells built with linked lists in packed
## arrays (no per-enemy objects). Answers "nearest enemy within range" and "which enemies could a blast reach" without
## looking at every enemy, and gives exactly the answers a full scan would:
##   - `nearest` picks the smallest squared ground distance within range (inclusive); an exact tie goes to the lowest uid,
##     so the result never depends on insertion order (same rule as TargetingService.pick).
##   - `box_candidates` returns, in insertion order, a superset of the enemies within `radius`; the caller applies the exact
##     falloff rule to each.
## Ground-plane only (tiles). Positions outside the map are clamped into the border cells, which keeps every bound below valid.
## Built by BattleController during the enemy phase; see docs/BALANCE.md (M3.2) for why it exists.

const CELL_TILES: float = 2.0

var _inv: float = 1.0 / CELL_TILES
var _cw: int = 1
var _ch: int = 1
var _head: PackedInt32Array = PackedInt32Array()
var _next: PackedInt32Array = PackedInt32Array()
var _pos: PackedVector2Array = PackedVector2Array()
var _uid: PackedInt32Array = PackedInt32Array()
var _who: Array[BattleEnemy] = []
var _count: int = 0
var _best: int = -1  # scratch state of the ring search in `nearest`
var _best_d2: float = 0.0
var _best_uid: int = 0


## Starts a new tick for a map of the given size in tiles. Forgets every enemy added before.
func begin(map_w_tiles: float, map_h_tiles: float) -> void:
	_cw = maxi(1, ceili(map_w_tiles * _inv))
	_ch = maxi(1, ceili(map_h_tiles * _inv))
	var cells := _cw * _ch
	if _head.size() != cells:
		_head.resize(cells)
	_head.fill(-1)
	_next.clear()
	_pos.clear()
	_uid.clear()
	_who.clear()
	_count = 0


## Adds a living enemy at ground position `p` (the caller passes `e.ground_pos`).
func add(e: BattleEnemy, p: Vector2) -> void:
	var cell := clampi(int(p.y * _inv), 0, _ch - 1) * _cw + clampi(int(p.x * _inv), 0, _cw - 1)
	_next.append(_head[cell])
	_head[cell] = _count
	_pos.append(p)
	_uid.append(e.uid)
	_who.append(e)
	_count += 1


func size() -> int:
	return _count


func enemy_at(i: int) -> BattleEnemy:
	return _who[i]


## The nearest enemy within `range_tiles` of `origin` (inclusive), or null. Ties go to the lowest uid.
func nearest(origin: Vector2, range_tiles: float) -> BattleEnemy:
	if range_tiles <= 0.0 or _count == 0:
		return null
	var r2 := range_tiles * range_tiles
	var max_ring := ceili(range_tiles * _inv) + 1
	var side := 2 * max_ring + 1
	var best := -1
	var best_d2 := r2
	var best_uid := 0
	if side * side > _count:  # fewer enemies than cells to visit: a plain scan of the packed positions is cheaper
		for i in _count:
			var d2 := origin.distance_squared_to(_pos[i])
			if d2 > r2:
				continue
			if best == -1 or d2 < best_d2 or (d2 == best_d2 and _uid[i] < best_uid):
				best = i
				best_d2 = d2
				best_uid = _uid[i]
		return _who[best] if best != -1 else null
	var ocx := clampi(int(origin.x * _inv), 0, _cw - 1)
	var ocy := clampi(int(origin.y * _inv), 0, _ch - 1)
	_best = -1
	_best_d2 = r2
	_best_uid = 0
	for r in max_ring + 1:
		var y0 := ocy - r
		var y1 := ocy + r
		var x0 := ocx - r
		var x1 := ocx + r
		for cy in range(maxi(y0, 0), mini(y1, _ch - 1) + 1):
			if cy == y0 or cy == y1:  # top and bottom rows of the ring
				for cx in range(maxi(x0, 0), mini(x1, _cw - 1) + 1):
					_scan(cx, cy, origin, r2)
			else:  # only the two side cells
				if x0 >= 0:
					_scan(x0, cy, origin, r2)
				if x1 < _cw:
					_scan(x1, cy, origin, r2)
		# Anything in ring r + 1 or beyond is at least r cells away from the origin: nothing there can beat the best.
		if _best != -1 and _best_d2 < (float(r) * CELL_TILES) * (float(r) * CELL_TILES):
			break
	return _who[_best] if _best != -1 else null


func _scan(cx: int, cy: int, origin: Vector2, r2: float) -> void:
	var j := _head[cy * _cw + cx]
	while j != -1:
		var d2 := origin.distance_squared_to(_pos[j])
		if d2 <= r2 and (_best == -1 or d2 < _best_d2 or (d2 == _best_d2 and _uid[j] < _best_uid)):
			_best = j
			_best_d2 = d2
			_best_uid = _uid[j]
		j = _next[j]


## Indices (into insertion order, ascending) of every enemy in the cells overlapping the square around `center`
## with half-side `radius`: a superset of the enemies within `radius`.
func box_candidates(center: Vector2, radius: float) -> PackedInt32Array:
	var out := PackedInt32Array()
	var r := maxf(radius, 0.0)
	var x0 := clampi(int((center.x - r) * _inv), 0, _cw - 1)
	var x1 := clampi(int((center.x + r) * _inv), 0, _cw - 1)
	var y0 := clampi(int((center.y - r) * _inv), 0, _ch - 1)
	var y1 := clampi(int((center.y + r) * _inv), 0, _ch - 1)
	if (x1 - x0 + 1) * (y1 - y0 + 1) > _count:
		for i in _count:
			out.append(i)
		return out
	for cy in range(y0, y1 + 1):
		for cx in range(x0, x1 + 1):
			var j := _head[cy * _cw + cx]
			while j != -1:
				out.append(j)
				j = _next[j]
	out.sort()
	return out
