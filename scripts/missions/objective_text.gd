class_name ObjectiveText
extends RefCounted
## The words for the objective list on the HUD and on the result panel (horde-and-objectives spec, UI). Pure: it maps an
## `ObjectiveTracker` to rows of text, a mark and a state, and the UI only draws them. Plain text, no icons.
##   Hold 1:23 left            Core >= 50%: 78%            Kills 120 / 300            Destroy every wave: 20 / 50

const State := ObjectiveTracker.State
const Role := ObjectiveDefinition.Role
const Kind := ObjectiveDefinition.Kind


class Row:
	extends RefCounted
	var text: String = ""
	## "[ ]" pending, "[=]" holding (a threshold that has not been broken), "[x]" met, "[!]" failed.
	var mark: String = ""
	var state: State = State.PENDING
	var role: Role = Role.PRIMARY
	## True for the objective that decided the mission (only set when the result is known).
	var deciding: bool = false
	var id: String = ""


## Seconds as m:ss, rounded up (a clock that says 0:00 has run out).
static func clock(seconds: float) -> String:
	var s := maxi(ceili(seconds), 0)
	return "%d:%02d" % [floori(s / 60.0), s % 60]


static func role_title(role: Role) -> String:
	match role:
		Role.PRIMARY:
			return "OBJECTIVES"
		Role.SECONDARY:
			return "BONUS"
		_:
			return "LOSE IF"


static func mark(state: State, standing: bool) -> String:
	match state:
		State.MET:
			return "[x]"
		State.FAILED:
			return "[!]"
		_:
			return "[=]" if standing else "[ ]"


## One row per objective, primary first, then bonus, then lose-if; the declared order is kept inside each group.
## `deciding_id` (the result's `deciding_id`, or "") marks the row that decided the mission.
static func rows(tracker: ObjectiveTracker, deciding_id: String = "") -> Array[Row]:
	var out: Array[Row] = []
	for role: Role in [Role.PRIMARY, Role.SECONDARY, Role.FAIL]:
		for i in tracker.size():
			var d := tracker.definition(i)
			if d.role != role:
				continue
			var r := Row.new()
			r.id = d.id
			r.role = role
			r.state = tracker.state(i)
			r.mark = mark(r.state, d.is_standing())
			r.text = describe(tracker, i)
			r.deciding = not deciding_id.is_empty() and d.id == deciding_id
			out.append(r)
	return out


## The line for objective `i` with its current numbers.
static func describe(tracker: ObjectiveTracker, i: int) -> String:
	var d := tracker.definition(i)
	match d.kind:
		Kind.SURVIVE:
			if tracker.state(i) == State.MET:
				return "Hold %s" % clock(d.seconds)
			return "Hold %s left" % clock(d.seconds - tracker.value(i))
		Kind.CORE_HEALTH_AT_LEAST:
			var now := floori(tracker.value(i) * 100.0 + 1.0e-4)
			var line := roundi(d.fraction * 100.0)
			if d.role == Role.FAIL:
				return "Core below %d%%: now %d%%" % [line, now]
			return "Core >= %d%%: %d%%" % [line, now]
		Kind.KILL_COUNT:
			return "Kills %d / %d" % [roundi(tracker.value(i)), d.count]
		_:
			if tracker.target(i) <= 0.0:
				return "Destroy every wave"
			return "Destroy every wave: %d / %d" % [roundi(tracker.value(i)), roundi(tracker.target(i))]
