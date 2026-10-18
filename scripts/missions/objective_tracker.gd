class_name ObjectiveTracker
extends RefCounted
## Judges a mission's objectives from plain numbers (horde-and-objectives spec, D4/D5). Pure logic, no nodes.
##   - Call `update(facts)` once per simulation tick, AFTER all damage and deaths of that tick resolved (ADR-007).
##   - Each objective is PENDING, MET or FAILED. MET and FAILED are final: a kill count never "un-kills", and a core that
##     dropped below its threshold stays below it for the result (there is no healing).
##   - A standing objective (CORE_HEALTH_AT_LEAST) is PENDING while it holds, FAILED once broken, and MET only when the
##     mission is won with it intact (`finish`).
##   - `MissionRules` turns this into the mission result; this class only answers what each objective's state is.

enum State { PENDING, MET, FAILED }


## What the tracker needs to know about the battle on one tick. The caller owns one and refreshes it each tick.
class Facts:
	extends RefCounted
	var elapsed_s: float = 0.0
	var core_hp: float = 0.0
	## 0 = unknown: the core then counts as whole while it lives and as gone when it does not.
	var core_max: float = 0.0
	var kills: int = 0
	var alive: int = 0
	## Enemies spawned so far, and the number the mission sends in all (difficulty applied).
	var spawned: int = 0
	var planned: int = 0

	func core_fraction() -> float:
		if core_max > 0.0:
			return clampf(core_hp / core_max, 0.0, 1.0)
		return 1.0 if core_hp > 0.0 else 0.0


var _defs: Array[ObjectiveDefinition] = []
var _state: Array[State] = []
var _value: PackedFloat32Array = PackedFloat32Array()
var _target: PackedFloat32Array = PackedFloat32Array()
var _met_seq: PackedInt32Array = PackedInt32Array()  # 0 = not met; otherwise the order objectives became met in
var _seq: int = 0
var _finished: bool = false


func _init(defs: Array[ObjectiveDefinition]) -> void:
	_defs = defs.duplicate()
	for d in _defs:
		_state.append(State.PENDING)
		_value.append(0.0)
		_target.append(_target_of(d))
		_met_seq.append(0)


func size() -> int:
	return _defs.size()


func definition(i: int) -> ObjectiveDefinition:
	return _defs[i]


func state(i: int) -> State:
	return _state[i]


func index_of(id: String) -> int:
	for i in _defs.size():
		if _defs[i].id == id:
			return i
	return -1


## How far along objective `i` is, in its own unit (seconds held, share of core health, enemies destroyed) and what it
## needs; for CORE_HEALTH_AT_LEAST the value is the core's current share and the target the threshold.
func value(i: int) -> float:
	return _value[i]


func target(i: int) -> float:
	return _target[i]


## Value over target, 0..1 (a standing objective shows its current share of the core instead).
func progress(i: int) -> float:
	if _defs[i].is_standing():
		return clampf(_value[i], 0.0, 1.0)
	return clampf(_value[i] / _target[i], 0.0, 1.0) if _target[i] > 0.0 else 0.0


func update(f: Facts) -> void:
	if _finished:
		return
	for i in _defs.size():
		var d := _defs[i]
		match d.kind:
			ObjectiveDefinition.Kind.SURVIVE:
				_value[i] = minf(f.elapsed_s, d.seconds)
			ObjectiveDefinition.Kind.CORE_HEALTH_AT_LEAST:
				_value[i] = f.core_fraction()
			ObjectiveDefinition.Kind.KILL_COUNT:
				_value[i] = minf(float(f.kills), float(d.count))
			ObjectiveDefinition.Kind.CLEAR_WAVES:
				_target[i] = float(f.planned)
				_value[i] = minf(float(f.kills), float(f.planned))
		if _state[i] != State.PENDING:
			continue
		match d.kind:
			ObjectiveDefinition.Kind.SURVIVE:
				if f.elapsed_s >= d.seconds:
					_meet(i)
			ObjectiveDefinition.Kind.CORE_HEALTH_AT_LEAST:
				if f.core_fraction() < d.fraction:
					_state[i] = State.FAILED
			ObjectiveDefinition.Kind.KILL_COUNT:
				if f.kills >= d.count:
					_meet(i)
			ObjectiveDefinition.Kind.CLEAR_WAVES:
				if f.planned > 0 and f.spawned >= f.planned and f.alive == 0:
					_meet(i)


## True when there is at least one primary objective that can be completed and every primary is satisfied: completed (MET),
## or for a standing one not broken. (Standing primaries alone never win: there would be nothing to wait for.)
func would_win() -> bool:
	var completes := false
	for i in _defs.size():
		if _defs[i].role != ObjectiveDefinition.Role.PRIMARY:
			continue
		if not _defs[i].is_standing():
			completes = true
		if not _satisfied(i):
			return false
	return completes


## The first objective that loses the mission by failing (a FAIL objective, or a primary that can no longer be met); -1 if none.
func failed_index() -> int:
	for i in _defs.size():
		if _state[i] == State.FAILED and _defs[i].role != ObjectiveDefinition.Role.SECONDARY:
			return i
	return -1


## The primary objective that became met most recently (ties on one tick go to the later in the list); -1 if none has.
func last_met_primary() -> int:
	var best := -1
	for i in _defs.size():
		if _defs[i].role == ObjectiveDefinition.Role.PRIMARY and _met_seq[i] > 0 and (best < 0 or _met_seq[i] > _met_seq[best]):
			best = i
	return best


## Settles every objective that is still pending when the mission ends: standing ones are met if the mission was won (they held
## to the end), everything else was not reached. Updates stop after this.
func finish(won: bool) -> void:
	for i in _defs.size():
		if _state[i] != State.PENDING:
			continue
		_state[i] = State.MET if won and _defs[i].is_standing() else State.FAILED
	_finished = true


func _satisfied(i: int) -> bool:
	if _defs[i].is_standing():
		return _state[i] != State.FAILED
	return _state[i] == State.MET


func _meet(i: int) -> void:
	_state[i] = State.MET
	_seq += 1
	_met_seq[i] = _seq


func _target_of(d: ObjectiveDefinition) -> float:
	match d.kind:
		ObjectiveDefinition.Kind.SURVIVE:
			return d.seconds
		ObjectiveDefinition.Kind.CORE_HEALTH_AT_LEAST:
			return d.fraction
		ObjectiveDefinition.Kind.KILL_COUNT:
			return float(d.count)
		_:
			return 0.0  # CLEAR_WAVES: the number of enemies the mission sends, known from the first update
