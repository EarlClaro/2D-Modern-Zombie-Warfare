class_name SpawnCue
extends RefCounted
## When a spawn point should show its marker (horde-and-objectives spec, "spawn cue"): shortly before a wave starts there,
## while a wave is coming out of it, and for a moment after. Pure, read from the mission's wave data; the clock is the
## battle's own. Difficulty changes how many enemies a wave sends, never when it starts or ends, so it is not an input.

enum State { NONE, SOON, ACTIVE }

## How far ahead of a wave the marker appears, and how long it stays after the last enemy of a wave came out.
const LEAD_S: float = 6.0
const AFTER_S: float = 2.0


class Cue:
	extends RefCounted
	var state: State = State.NONE
	## SOON: seconds until the wave starts. Otherwise 0.
	var in_s: float = 0.0


static func cue(mission: MissionDefinition, spawn_index: int, elapsed: float, lead_s: float = LEAD_S) -> Cue:
	var out := Cue.new()
	var soonest := INF
	for w in mission.waves:
		if w == null or w.spawn_index != spawn_index:
			continue
		if elapsed >= w.start_s and elapsed <= w.last_spawn_s() + AFTER_S:
			out.state = State.ACTIVE
			out.in_s = 0.0
			return out
		if w.start_s > elapsed:
			soonest = minf(soonest, w.start_s - elapsed)
	if soonest <= lead_s:
		out.state = State.SOON
		out.in_s = soonest
	return out
