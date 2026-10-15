class_name WeaponState
extends RefCounted
## Fire-rate bookkeeping for one weapon on one entity. Pure logic; the caller applies the shot.
## - Starts ready. At most one shot per tick; a delta spanning more than one interval loses the extra
##   shots instead of bursting, and the next shot is a full interval later.
## - Cooldown keeps recovering while there is no target but never banks a burst: after any idle
##   period the weapon is simply ready (one shot), not "ahead".
## - Fractional overshoot is carried over, so the long-run rate matches shots_per_second.

var _interval: float
var _cooldown: float = 0.0  # seconds until ready; may be slightly negative within a tick


func _init(fire_interval_s: float) -> void:
	assert(fire_interval_s > 0.0, "fire interval must be > 0 (definitions are validated before use)")
	_interval = fire_interval_s


static func from_definition(def: WeaponDefinition) -> WeaponState:
	return WeaponState.new(def.fire_interval_s())


## Advances time. Returns true if the weapon fires this tick (only possible with a target).
func tick(delta: float, has_target: bool) -> bool:
	if delta <= 0.0:
		return false
	_cooldown -= delta
	if not has_target:
		_cooldown = maxf(_cooldown, 0.0)
		return false
	if _cooldown > 0.0:
		return false
	# Carry the overshoot (keeps the long-run rate exact) unless a whole interval or more was owed
	# (frame hitch): then drop the backlog and wait the full interval rather than firing again at once.
	if _cooldown <= -_interval:
		_cooldown = _interval
	else:
		_cooldown += _interval
	return true


func is_ready() -> bool:
	return _cooldown <= 0.0


func cooldown_remaining() -> float:
	return maxf(_cooldown, 0.0)


func reset() -> void:
	_cooldown = 0.0
