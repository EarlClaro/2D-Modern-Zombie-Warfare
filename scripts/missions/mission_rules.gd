class_name MissionRules
extends RefCounted
## Win/fail evaluation for the Milestone 1 defence mission (ADR-007). Pure logic.
##   - Call `evaluate()` once per simulation tick, AFTER all damage and deaths of that tick resolved.
##   - Fail = core destroyed. Win = `duration_s` elapsed with the core alive.
##   - If both are true on the same tick, FAIL wins.
##   - The mission ends exactly once: after that, `evaluate()` keeps returning the first result and
##     `ended` is never emitted again, whatever the inputs.

enum Status { RUNNING, WON, FAILED }

signal ended(result: Result)


class Result:
	extends RefCounted
	var status: Status
	var reason: String

	func _init(p_status: Status, p_reason: String) -> void:
		status = p_status
		reason = p_reason


var _duration_s: float
var _result: Result


func _init(duration_s: float) -> void:
	assert(duration_s > 0.0, "mission duration must be > 0 (definitions are validated before use)")
	_duration_s = duration_s
	_result = Result.new(Status.RUNNING, "in progress")


func is_ended() -> bool:
	return _result.status != Status.RUNNING


func result() -> Result:
	return _result


func evaluate(core_hp: float, elapsed_s: float) -> Result:
	if is_ended():
		return _result
	var core_destroyed := core_hp <= 0.0
	var time_up := elapsed_s >= _duration_s
	if core_destroyed:
		var reason := "core destroyed"
		if time_up:
			reason += " (on the same tick the timer expired)"
		_result = Result.new(Status.FAILED, reason)
	elif time_up:
		_result = Result.new(Status.WON, "core held for %.0f seconds" % _duration_s)
	else:
		return _result
	ended.emit(_result)
	return _result
