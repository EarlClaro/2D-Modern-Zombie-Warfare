class_name BattleModifiers
extends RefCounted
## The timed and permanent modifiers acting on the player's side in one battle (orders and doctrines, ADR-013).
## Pure: time only advances through tick(). An effect is keyed by its id, so playing the same order again refreshes
## its timer instead of stacking.

## Float error from many small ticks must not keep an effect alive one tick too long.
const EPS: float = 1e-6


class Active:
	extends RefCounted
	var effect: StateEffectDefinition
	## Seconds left; negative = permanent (lasts the whole mission).
	var time_left: float = -1.0

	func _init(p_effect: StateEffectDefinition, p_time_left: float) -> void:
		effect = p_effect
		time_left = p_time_left

	func is_permanent() -> bool:
		return time_left < 0.0


var _active: Dictionary = {}  # effect id -> Active, in the order first applied


## Starts (or refreshes) a modifier effect; effects that are not modifiers (supply, draw) are ignored.
## Returns whether it is now active.
func apply(effect: StateEffectDefinition) -> bool:
	if effect == null or not effect.is_modifier():
		return false
	var left := effect.duration_s if effect.duration_s > 0.0 else -1.0
	_active[effect.id] = Active.new(effect, left)
	return true


func tick(delta: float) -> void:
	if delta <= 0.0:
		return
	for id in _active.keys():
		var a: Active = _active[id]
		if a.is_permanent():
			continue
		a.time_left -= delta
		if a.time_left <= EPS:
			_active.erase(id)


func clear() -> void:
	_active.clear()


func is_active(effect_id: String) -> bool:
	return _active.has(effect_id)


## Seconds left of an effect (0 if not active, -1 if permanent).
func time_left(effect_id: String) -> float:
	var a: Active = _active.get(effect_id)
	return 0.0 if a == null else a.time_left


## The active effects, oldest first (for the HUD).
func active() -> Array[Active]:
	var out: Array[Active] = []
	for id in _active:
		out.append(_active[id])
	return out


## Extra armour of every player ground unit right now (sum of the active orders).
func armor_bonus() -> float:
	var total := 0.0
	for id in _active:
		total += (_active[id] as Active).effect.armor_bonus
	return total


## Damage multiplier for a player weapon right now (product of the active effects that cover it).
func damage_mult(weapon_id: String) -> float:
	var m := 1.0
	for id in _active:
		var e: StateEffectDefinition = (_active[id] as Active).effect
		if is_equal_approx(e.damage_mult, 1.0):
			continue
		if e.weapon_ids.is_empty() or e.weapon_ids.has(weapon_id):
			m *= e.damage_mult
	return m
