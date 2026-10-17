class_name FlowField
extends RefCounted
## A distance map over the ground grid and the direction to walk down it (ADR-012). Built once from the goal (the core)
## over the cells that are open, 8-neighbour, with no cutting of a corner: a diagonal step needs both side cells open.
## Pure: no nodes, no projection (cells are ground cells; positions are ground-plane tiles, cell (x, y) covers
## [x, x + 1) x [y, y + 1)). The same inputs always give the same field.

const UNREACHABLE: float = 1.0e9
const DIAGONAL: float = 1.41421356
const NEIGHBOURS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]

var width: int = 0
var height: int = 0
var goal: Vector2i = Vector2i.ZERO
var _open: PackedByteArray = PackedByteArray()
var _dist: PackedFloat32Array = PackedFloat32Array()
var _dir: PackedVector2Array = PackedVector2Array()
var _heap_key: PackedFloat32Array = PackedFloat32Array()
var _heap_val: PackedInt32Array = PackedInt32Array()


## `open` holds one byte per cell (row by row, 1 = an enemy may walk there). The goal cell counts as open even if it is
## not (the core stands on it).
static func build(p_width: int, p_height: int, open: PackedByteArray, p_goal: Vector2i) -> FlowField:
	var f := FlowField.new()
	f.width = maxi(p_width, 0)
	f.height = maxi(p_height, 0)
	f.goal = p_goal
	f._open = open.duplicate()
	if f._open.size() != f.width * f.height:
		f._open.resize(f.width * f.height)
	f._dist.resize(f.width * f.height)
	f._dist.fill(UNREACHABLE)
	f._dir.resize(f.width * f.height)
	if not f._in_bounds(p_goal.x, p_goal.y):
		return f
	f._open[p_goal.y * f.width + p_goal.x] = 1
	f._flood()
	f._steer()
	return f


## The open cells of a map: walkable terrain that is not in `blocked` (a dictionary cell -> true, e.g. scenery footprints).
static func open_grid(map: MapDefinition, blocked: Dictionary = {}) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(map.width() * map.height())
	for y in map.height():
		for x in map.width():
			var cell := Vector2i(x, y)
			out[y * map.width() + x] = 1 if map.is_walkable(cell) and not blocked.has(cell) else 0
	return out


func is_open(cell: Vector2i) -> bool:
	return _in_bounds(cell.x, cell.y) and _open[cell.y * width + cell.x] == 1


## True if the ground position `p` lies on an open cell.
func open_at(p: Vector2) -> bool:
	return is_open(Vector2i(floori(p.x), floori(p.y)))


## True if an enemy standing in `cell` has a way to the goal.
func reachable(cell: Vector2i) -> bool:
	return _in_bounds(cell.x, cell.y) and _dist[cell.y * width + cell.x] < UNREACHABLE * 0.5


## Walking distance in tiles from the middle of `cell` to the goal along the field (INF if there is none).
func distance(cell: Vector2i) -> float:
	return _dist[cell.y * width + cell.x] if reachable(cell) else INF


## The direction (unit vector, or zero if there is none) to walk from ground position `p`: a blend of the four nearest
## cell centres, so the heading changes smoothly instead of jumping at a cell border.
func direction_at(p: Vector2) -> Vector2:
	var gx := p.x - 0.5
	var gy := p.y - 0.5
	var ix := floori(gx)
	var iy := floori(gy)
	var tx := gx - float(ix)
	var ty := gy - float(iy)
	var acc := Vector2.ZERO
	for dy in 2:
		for dx in 2:
			var cx := ix + dx
			var cy := iy + dy
			if reachable(Vector2i(cx, cy)):
				acc += _dir[cy * width + cx] * ((tx if dx == 1 else 1.0 - tx) * (ty if dy == 1 else 1.0 - ty))
	if acc.length_squared() < 1.0e-6:
		var c := Vector2i(floori(p.x), floori(p.y))
		return _dir[c.y * width + c.x] if reachable(c) else Vector2.ZERO
	return acc.normalized()


## Moves `p` by `delta` (a step of well under a tile) but never into a closed cell: it slides along the obstacle instead,
## and stays put if both axes are blocked. A blended heading can point at the corner of a wall; this keeps the walker
## outside it.
func slide(p: Vector2, delta: Vector2) -> Vector2:
	var to := p + delta
	if is_open(Vector2i(floori(to.x), floori(to.y))):
		return to
	var along_x := Vector2(to.x, p.y)
	if is_open(Vector2i(floori(along_x.x), floori(along_x.y))):
		return along_x
	var along_y := Vector2(p.x, to.y)
	if is_open(Vector2i(floori(along_y.x), floori(along_y.y))):
		return along_y
	return p


## The route a walker would take from `from` to the goal, as points `step` tiles apart (the goal's centre last). Empty if
## `from` cannot reach the goal. `max_points` stops a runaway walk.
func trace(from: Vector2, step: float = 1.0, max_points: int = 4000) -> PackedVector2Array:
	var out := PackedVector2Array()
	if not reachable(Vector2i(floori(from.x), floori(from.y))):
		return out
	var goal_c := Vector2(float(goal.x) + 0.5, float(goal.y) + 0.5)
	var p := from
	out.append(p)
	while out.size() < max_points and p.distance_to(goal_c) > step:
		var d := direction_at(p)
		if d == Vector2.ZERO:
			break
		var moved := slide(p, d * step)
		if moved == p:
			break
		p = moved
		out.append(p)
	out.append(goal_c)
	return out


func _in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < width and y < height


func _is_open_xy(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < width and y < height and _open[y * width + x] == 1


## A step from (x, y) by `d` is allowed when the target is open and, for a diagonal, both side cells are open too.
func _can_step(x: int, y: int, d: Vector2i) -> bool:
	if not _is_open_xy(x + d.x, y + d.y):
		return false
	if d.x != 0 and d.y != 0:
		return _is_open_xy(x + d.x, y) and _is_open_xy(x, y + d.y)
	return true


func _flood() -> void:
	_heap_key.clear()
	_heap_val.clear()
	var start := goal.y * width + goal.x
	_dist[start] = 0.0
	_push(0.0, start)
	while not _heap_val.is_empty():
		var top_d := _heap_key[0]
		var cur := _pop()
		if top_d > _dist[cur]:
			continue
		var cx := cur % width
		var cy := cur / width
		for d in NEIGHBOURS:
			if not _can_step(cx, cy, d):
				continue
			var nd := top_d + (DIAGONAL if d.x != 0 and d.y != 0 else 1.0)
			var ni := (cy + d.y) * width + cx + d.x
			if nd < _dist[ni]:
				_dist[ni] = nd
				_push(nd, ni)


## The heading of a cell: the mean of the steps onto its shortest-path parents (the neighbours that lie exactly one step
## closer along a shortest way), so a cell between two equal ways round an obstacle picks one of them, never the cancelled
## sum of both.
func _steer() -> void:
	for y in height:
		for x in width:
			var i := y * width + x
			if _dist[i] >= UNREACHABLE * 0.5:
				continue
			var sum := Vector2.ZERO
			var first := Vector2.ZERO
			for d in NEIGHBOURS:
				if not _can_step(x, y, d):
					continue
				var cost := DIAGONAL if d.x != 0 and d.y != 0 else 1.0
				if absf(_dist[i] - (_dist[(y + d.y) * width + x + d.x] + cost)) <= 1.0e-3:
					var unit := Vector2(d).normalized()
					if first == Vector2.ZERO:
						first = unit
					sum += unit
			_dir[i] = sum.normalized() if sum.length_squared() > 1.0e-6 else first


func _push(key: float, val: int) -> void:
	_heap_key.append(key)
	_heap_val.append(val)
	var i := _heap_key.size() - 1
	while i > 0:
		var parent := (i - 1) / 2
		if _heap_key[parent] <= _heap_key[i]:
			break
		_swap(parent, i)
		i = parent


func _pop() -> int:
	var out := _heap_val[0]
	var last := _heap_key.size() - 1
	_heap_key[0] = _heap_key[last]
	_heap_val[0] = _heap_val[last]
	_heap_key.resize(last)
	_heap_val.resize(last)
	var i := 0
	while true:
		var l := 2 * i + 1
		var r := l + 1
		var m := i
		if l < last and _heap_key[l] < _heap_key[m]:
			m = l
		if r < last and _heap_key[r] < _heap_key[m]:
			m = r
		if m == i:
			break
		_swap(m, i)
		i = m
	return out


func _swap(a: int, b: int) -> void:
	var tk := _heap_key[a]
	var tv := _heap_val[a]
	_heap_key[a] = _heap_key[b]
	_heap_val[a] = _heap_val[b]
	_heap_key[b] = tk
	_heap_val[b] = tv
