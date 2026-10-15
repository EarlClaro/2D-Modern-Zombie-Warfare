class_name ProjectileSystem
extends RefCounted
## Arcing projectiles (artillery shells) as plain arrays, not nodes: one ground-plane line from `from` to `to`,
## with altitude following a parabola on top of it. Ground position is linear in time and never depends on
## altitude (ground-plane truth); altitude only affects drawing. A projectile with a launch delay has a negative
## age and is invisible until it is launched. Pure logic: time moves only through tick().

const MAX_PROJECTILES: int = 256
const EPS: float = 1e-6  # a 0.9 s flight ticked in 1/60 s steps must land on the 54th tick, not the 55th


class Impact:
	extends RefCounted
	var ground_pos: Vector2
	var damage: float
	var radius: float

	func _init(p_pos: Vector2, p_damage: float, p_radius: float) -> void:
		ground_pos = p_pos
		damage = p_damage
		radius = p_radius


var _from: PackedVector2Array = PackedVector2Array()
var _to: PackedVector2Array = PackedVector2Array()
var _age: PackedFloat64Array = PackedFloat64Array()  # negative = waiting to launch
var _flight: PackedFloat64Array = PackedFloat64Array()
var _height: PackedFloat64Array = PackedFloat64Array()
var _damage: PackedFloat64Array = PackedFloat64Array()
var _radius: PackedFloat64Array = PackedFloat64Array()


func count() -> int:
	return _age.size()


## Queues a projectile. Returns false (and adds nothing) when the cap is reached or the flight time is not positive.
func spawn(from: Vector2, to: Vector2, flight_s: float, arc_height: float, damage: float, blast_radius: float, delay_s: float = 0.0) -> bool:
	if _age.size() >= MAX_PROJECTILES or flight_s <= 0.0:
		return false
	_from.append(from)
	_to.append(to)
	_age.append(-maxf(delay_s, 0.0))
	_flight.append(flight_s)
	_height.append(maxf(arc_height, 0.0))
	_damage.append(damage)
	_radius.append(blast_radius)
	return true


## Advances time; returns the impacts that happened (earliest-queued first) and removes those projectiles.
func tick(delta: float) -> Array[Impact]:
	var impacts: Array[Impact] = []
	if delta <= 0.0:
		return impacts
	var landed: Array[int] = []
	for i in _age.size():
		_age[i] += delta
		if _age[i] + EPS >= _flight[i]:
			landed.append(i)
	for i in landed:
		impacts.append(Impact.new(_to[i], _damage[i], _radius[i]))
	for k in range(landed.size() - 1, -1, -1):
		var i := landed[k]
		_from.remove_at(i)
		_to.remove_at(i)
		_age.remove_at(i)
		_flight.remove_at(i)
		_height.remove_at(i)
		_damage.remove_at(i)
		_radius.remove_at(i)
	return impacts


func clear() -> void:
	_from.clear()
	_to.clear()
	_age.clear()
	_flight.clear()
	_height.clear()
	_damage.clear()
	_radius.clear()


## True once launched (it is in the air and should be drawn).
func is_flying(i: int) -> bool:
	return _age[i] >= 0.0


func target_of(i: int) -> Vector2:
	return _to[i]


## Fraction of the flight completed, 0..1 (0 while waiting to launch).
func progress_of(i: int) -> float:
	return clampf(_age[i] / _flight[i], 0.0, 1.0)


## Ground position: a straight line from `from` to `to`, independent of altitude.
func ground_pos_of(i: int) -> Vector2:
	return ground_pos_at(i, progress_of(i))


func altitude_of(i: int) -> float:
	return altitude_at(i, progress_of(i))


## The same two, at an arbitrary flight fraction (used for drawing trails).
func ground_pos_at(i: int, s: float) -> Vector2:
	return _from[i].lerp(_to[i], clampf(s, 0.0, 1.0))


func altitude_at(i: int, s: float) -> float:
	return altitude_profile(s, _height[i])


## Parabolic altitude for flight fraction s: 0 at launch and landing, `peak` at s = 0.5.
static func altitude_profile(s: float, peak: float) -> float:
	var t := clampf(s, 0.0, 1.0)
	return 4.0 * peak * t * (1.0 - t)
