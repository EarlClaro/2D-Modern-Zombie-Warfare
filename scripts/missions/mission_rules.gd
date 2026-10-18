class_name MissionRules
extends RefCounted
## Win/fail evaluation of a defence mission (ADR-007), driven by its objectives (M3.12). Pure logic.
##   - Call `evaluate()` once per simulation tick, AFTER all damage and deaths of that tick resolved.
##   - Fail = the core is destroyed, a FAIL objective failed, or a PRIMARY objective can no longer be met.
##     Win = every PRIMARY objective is met. A mission without objectives has the implicit one: primary SURVIVE
##     `duration_s`, which is the Milestone 1 rule (win when the time is up with the core alive).
##   - If both are true on the same tick, FAIL wins.
##   - The mission ends exactly once: after that, `evaluate()` keeps returning the first result and
##     `ended` is never emitted again, whatever the inputs.

enum Status { RUNNING, WON, FAILED }

signal ended(result: Result)


class Result:
	extends RefCounted
	var status: Status
	var reason: String
	## Id of the objective that decided the mission ("core" when the core was destroyed, "" while running).
	var deciding_id: String

	func _init(p_status: Status, p_reason: String, p_deciding_id: String = "") -> void:
		status = p_status
		reason = p_reason
		deciding_id = p_deciding_id


## Id of the implicit objective of a mission that declares none.
const IMPLICIT_ID: String = "hold"
const CORE_ID: String = "core"

var _tracker: ObjectiveTracker
var _blank: ObjectiveTracker.Facts = ObjectiveTracker.Facts.new()
var _result: Result


## `objectives` empty = the implicit survive-the-timer objective of `duration_s`.
func _init(duration_s: float, objectives: Array[ObjectiveDefinition] = []) -> void:
	assert(duration_s > 0.0, "mission duration must be > 0 (definitions are validated before use)")
	var defs: Array[ObjectiveDefinition] = objectives
	if defs.is_empty():
		var hold := ObjectiveDefinition.new()
		hold.id = IMPLICIT_ID
		hold.kind = ObjectiveDefinition.Kind.SURVIVE
		hold.role = ObjectiveDefinition.Role.PRIMARY
		hold.seconds = duration_s
		defs = [hold] as Array[ObjectiveDefinition]
	_tracker = ObjectiveTracker.new(defs)
	_result = Result.new(Status.RUNNING, "in progress")


func is_ended() -> bool:
	return _result.status != Status.RUNNING


func result() -> Result:
	return _result


## What each objective stands at (read by the HUD and the result panel).
func tracker() -> ObjectiveTracker:
	return _tracker


## `core_hp` and `elapsed_s` are always taken from the arguments. `facts` carries the rest (kills, enemies alive, core
## maximum, ...) for the objectives that need it; without it only SURVIVE and a living/dead core can be judged.
func evaluate(core_hp: float, elapsed_s: float, facts: ObjectiveTracker.Facts = null) -> Result:
	if is_ended():
		return _result
	var f := facts if facts != null else _blank
	f.core_hp = core_hp
	f.elapsed_s = elapsed_s
	_tracker.update(f)
	var would_win := _tracker.would_win()
	var broken := _tracker.failed_index()
	var lost: Result = null
	if core_hp <= 0.0:
		var reason := "core destroyed"
		var last := _tracker.last_met_primary()
		if would_win and last >= 0:
			reason += " (on the same tick %s)" % _tracker.definition(last).tie_phrase()
		lost = Result.new(Status.FAILED, reason, CORE_ID)
	elif broken >= 0:
		var d := _tracker.definition(broken)
		lost = Result.new(Status.FAILED, d.failed_phrase(), d.id)
	if lost != null:
		_result = lost
	elif would_win:
		_result = _won()
	else:
		return _result
	_tracker.finish(_result.status == Status.WON)
	ended.emit(_result)
	return _result


func _won() -> Result:
	var phrases := PackedStringArray()
	for i in _tracker.size():
		if _tracker.definition(i).role == ObjectiveDefinition.Role.PRIMARY:
			phrases.append(_tracker.definition(i).met_phrase())
	var deciding := _tracker.last_met_primary()
	var id := _tracker.definition(deciding).id if deciding >= 0 else ""
	return Result.new(Status.WON, ", ".join(phrases), id)
