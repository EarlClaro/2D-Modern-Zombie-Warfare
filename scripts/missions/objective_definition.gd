class_name ObjectiveDefinition
extends Resource
## One win/fail condition of a mission (horde-and-objectives spec, D4). Data only; `ObjectiveTracker` judges it.
##   Kinds: SURVIVE `seconds` (the clock reaches it), CORE_HEALTH_AT_LEAST `fraction` (the core never drops below it),
##   KILL_COUNT `count` (that many enemies destroyed), CLEAR_WAVES (every enemy of every wave has spawned and none is alive).
##   Roles: PRIMARY (all of them met = the mission is won; one that fails = it is lost), SECONDARY (reported, never ends the
##   mission), FAIL (the mission is lost the moment it fails; only a kind that can fail while running may take this role).
## A mission without objectives uses the implicit pair of the Milestone 1 defence: primary SURVIVE `duration_s`, and the
## core being destroyed always loses.

enum Kind { SURVIVE, CORE_HEALTH_AT_LEAST, KILL_COUNT, CLEAR_WAVES }
enum Role { PRIMARY, SECONDARY, FAIL }

## Unique within its mission; the HUD and the result panel key on it.
@export var id: String = ""
@export var kind: Kind = Kind.SURVIVE
@export var role: Role = Role.PRIMARY
## SURVIVE: seconds into the mission.
@export var seconds: float = 0.0
## CORE_HEALTH_AT_LEAST: the lowest share of the core's health the objective allows, 0 < fraction <= 1.
@export_range(0.0, 1.0) var fraction: float = 0.0
## KILL_COUNT: enemies to destroy.
@export var count: int = 0


## A standing objective is not completed, it is kept: it stays pending while it holds, fails for good the moment it is
## broken, and counts as met when the mission is won with it intact.
func is_standing() -> bool:
	return kind == Kind.CORE_HEALTH_AT_LEAST


## Only a standing objective can fail while the mission runs; the others are simply not reached yet.
func can_fail_while_running() -> bool:
	return is_standing()


func validate() -> PackedStringArray:
	var errs := PackedStringArray()
	if id.is_empty():
		errs.append("objective has an empty id")
	var who := "objective '%s'" % id
	match kind:
		Kind.SURVIVE:
			if seconds <= 0.0:
				errs.append("%s: SURVIVE needs seconds > 0" % who)
		Kind.CORE_HEALTH_AT_LEAST:
			if fraction <= 0.0 or fraction > 1.0:
				errs.append("%s: CORE_HEALTH_AT_LEAST needs 0 < fraction <= 1" % who)
		Kind.KILL_COUNT:
			if count < 1:
				errs.append("%s: KILL_COUNT needs count >= 1" % who)
		Kind.CLEAR_WAVES:
			pass
	if role == Role.FAIL and not can_fail_while_running():
		errs.append("%s: a FAIL objective of this kind could never fail (only CORE_HEALTH_AT_LEAST can)" % who)
	return errs


## Short words for the result line when this objective is what decided the mission (no punctuation, no capital).
## Won: "core held for 90 seconds", "300 enemies destroyed", "every wave destroyed"; the core threshold is never what wins.
func met_phrase() -> String:
	match kind:
		Kind.SURVIVE:
			return "core held for %.0f seconds" % seconds
		Kind.KILL_COUNT:
			return "%d enemies destroyed" % count
		Kind.CLEAR_WAVES:
			return "every wave destroyed"
		_:
			return "core held above %d %%" % roundi(fraction * 100.0)


## What happened on the tick this objective would have been met, for the line that says a loss came on the same tick.
func tie_phrase() -> String:
	match kind:
		Kind.SURVIVE:
			return "the timer expired"
		Kind.KILL_COUNT:
			return "the kill target was reached"
		Kind.CLEAR_WAVES:
			return "the last wave was cleared"
		_:
			return "the objectives were met"


## Why the mission was lost when this objective failed.
func failed_phrase() -> String:
	match kind:
		Kind.CORE_HEALTH_AT_LEAST:
			return "core fell below %d %%" % roundi(fraction * 100.0)
		_:
			return "objective '%s' was not met" % id
