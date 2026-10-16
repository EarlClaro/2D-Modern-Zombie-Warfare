class_name CutawayPlan
extends RefCounted
## Pure logic of the strike cutaways (docs/specs/strike-cutaways.md): which version of a clip to show (full the first
## time a support is used in a mission, short after, none when switched off), how long it runs, and where it is in
## its run. No drawing here; the presentation reads `progress()` and `current()`.

enum Mode { NONE, SHORT, FULL }

var enabled: bool = true

var _seen: Dictionary = {}  # cutaway id -> true once its full version was started this mission
var _def: CutawayDefinition
var _mode: Mode = Mode.NONE
var _duration: float = 0.0
var _time: float = 0.0
var _ended_this_tick: bool = false


## What `request` would show for `def` right now, without starting anything.
func mode_for(def: CutawayDefinition) -> Mode:
	if not enabled or def == null or is_playing():
		return Mode.NONE
	if _ended_this_tick or _seen.has(def.id):
		return Mode.SHORT  # a play in the very tick a clip ended is shown short, never stacked on a full one
	return Mode.FULL


## Starts the clip for `def` if one should play; returns the mode chosen. A full version marks the support as seen.
func request(def: CutawayDefinition) -> Mode:
	var mode := mode_for(def)
	if mode == Mode.NONE:
		return mode
	_def = def
	_mode = mode
	_duration = def.full_duration() if mode == Mode.FULL else def.short_duration()
	_time = 0.0
	_seen[def.id] = true
	return mode


func is_playing() -> bool:
	return _def != null


func current() -> CutawayDefinition:
	return _def


func mode() -> Mode:
	return _mode


func duration() -> float:
	return _duration


func elapsed() -> float:
	return _time


## 0 at the start of the clip, 1 at its end.
func progress() -> float:
	return clampf(_time / _duration, 0.0, 1.0) if _duration > 0.0 else 1.0


## Advances the clip by real time `delta`. Returns true on the call that ends it.
func tick(delta: float) -> bool:
	_ended_this_tick = false
	if _def == null:
		return false
	_time += maxf(delta, 0.0)
	if _time >= _duration:
		_finish()
		return true
	return false


## Ends the running clip at once (the player skipped it).
func skip() -> void:
	if _def != null:
		_finish()


## Forgets what was seen and drops any running clip (battle restart).
func reset() -> void:
	_seen.clear()
	_def = null
	_mode = Mode.NONE
	_duration = 0.0
	_time = 0.0
	_ended_this_tick = false


func _finish() -> void:
	_def = null
	_mode = Mode.NONE
	_duration = 0.0
	_time = 0.0
	_ended_this_tick = true
