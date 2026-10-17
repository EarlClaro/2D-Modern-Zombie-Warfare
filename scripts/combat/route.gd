class_name Route
extends RefCounted
## The path enemies walk, as a polyline in ground space from the enemy spawn to the core. Units use it to know where
## "forward" (toward the spawn) and "back" (toward the core) lie, so they can scout up the route and fall back down it.
## Pure geometry: distances are measured along the route from the core end (0 = the core, `length()` = the spawn).

var _pts: PackedVector2Array = PackedVector2Array()  # spawn first, core last
var _from_core: PackedFloat32Array = PackedFloat32Array()  # distance from the core to each point along the route
var _length: float = 0.0


## `points` run from the spawn to the core. Repeated points are dropped.
static func from_points(points: PackedVector2Array) -> Route:
	var r := Route.new()
	for p in points:
		if r._pts.is_empty() or r._pts[r._pts.size() - 1].distance_squared_to(p) > 1e-6:
			r._pts.append(p)
	r._build()
	return r


func _build() -> void:
	_from_core.resize(_pts.size())
	var acc := 0.0
	for i in range(_pts.size() - 1, -1, -1):
		if i < _pts.size() - 1:
			acc += _pts[i].distance_to(_pts[i + 1])
		_from_core[i] = acc
	_length = acc


func is_empty() -> bool:
	return _pts.size() < 2


func length() -> float:
	return _length


func spawn() -> Vector2:
	return _pts[0] if not _pts.is_empty() else Vector2.ZERO


func core() -> Vector2:
	return _pts[_pts.size() - 1] if not _pts.is_empty() else Vector2.ZERO


## The point `s` tiles from the core along the route (clamped to the route).
func point_at(s: float) -> Vector2:
	if _pts.is_empty():
		return Vector2.ZERO
	if is_empty():
		return _pts[0]
	var t := clampf(s, 0.0, _length)
	for i in range(_pts.size() - 1, 0, -1):
		if t <= _from_core[i - 1]:
			var a := _pts[i]
			var b := _pts[i - 1]
			var seg := _from_core[i - 1] - _from_core[i]
			if seg <= 1e-6:
				return b
			return a.lerp(b, (t - _from_core[i]) / seg)
	return _pts[0]


## Distance from the core, along the route, of the point of the route nearest to `p`.
func progress_of(p: Vector2) -> float:
	if is_empty():
		return 0.0
	var best_d2 := INF
	var best_s := 0.0
	for i in _pts.size() - 1:
		var a := _pts[i]
		var b := _pts[i + 1]
		var ab := b - a
		var len2 := ab.length_squared()
		var k := clampf((p - a).dot(ab) / len2, 0.0, 1.0) if len2 > 1e-9 else 0.0
		var q := a + ab * k
		var d2 := p.distance_squared_to(q)
		if d2 < best_d2:
			best_d2 = d2
			best_s = _from_core[i] - (_from_core[i] - _from_core[i + 1]) * k
	return best_s


## Distance from `p` to the route.
func distance_to(p: Vector2) -> float:
	if is_empty():
		return INF
	var best_d2 := INF
	for i in _pts.size() - 1:
		var a := _pts[i]
		var ab := _pts[i + 1] - a
		var len2 := ab.length_squared()
		var k := clampf((p - a).dot(ab) / len2, 0.0, 1.0) if len2 > 1e-9 else 0.0
		best_d2 = minf(best_d2, p.distance_squared_to(a + ab * k))
	return sqrt(best_d2)


## Unit vector pointing from `p`'s place on the route toward the core (the way "back" runs there).
func dir_to_core(p: Vector2) -> Vector2:
	if is_empty():
		return Vector2.ZERO
	var s := progress_of(p)
	var ahead := point_at(maxf(s - 0.5, 0.0))
	var here := point_at(s)
	var d := ahead - here
	return d.normalized() if d.length_squared() > 1e-9 else Vector2.ZERO
