class_name SfxVoicePool
extends RefCounted
## Pure voice-allocation logic for sound effects (no audio engine involved, so it is unit-testable).
## Rules:
##  - every category has a cap on simultaneous voices; a new sound over the cap is dropped, EXCEPT
##    alerts, which retrigger (replace the oldest alert) so an alert is never lost to gunfire;
##  - a free voice is used if there is one; otherwise a playing voice of strictly lower priority is
##    stolen (oldest first); otherwise the sound is dropped.

const CAPS: Dictionary = {"shot": 4, "impact": 4, "death": 3, "alert": 1, "blast": 3}
const PRIORITY: Dictionary = {"shot": 1, "impact": 1, "death": 2, "alert": 3, "blast": 2}
const DEFAULT_CAP: int = 4
const DEFAULT_PRIORITY: int = 1

var _ends_at: PackedFloat64Array = PackedFloat64Array()
var _category: Array[String] = []


func _init(voice_count: int = 12) -> void:
	for i in voice_count:
		_ends_at.append(0.0)
		_category.append("")


func voice_count() -> int:
	return _ends_at.size()


func active_count(category: String, now: float) -> int:
	var n := 0
	for i in _ends_at.size():
		if _ends_at[i] > now and _category[i] == category:
			n += 1
	return n


## Asks for a voice for a sound of `duration` seconds. Returns the voice index to use, or -1 if the
## sound should be dropped.
func request(category: String, now: float, duration: float) -> int:
	var cap: int = CAPS.get(category, DEFAULT_CAP)
	var priority: int = PRIORITY.get(category, DEFAULT_PRIORITY)
	var chosen := -1
	if active_count(category, now) >= cap:
		if category != "alert":
			return -1
		chosen = _oldest_playing(now, category)  # alerts retrigger instead of dropping
	if chosen == -1:
		chosen = _free_voice(now)
	if chosen == -1:
		chosen = _steal_lower_priority(now, priority)
	if chosen == -1:
		return -1
	_ends_at[chosen] = now + maxf(duration, 0.0)
	_category[chosen] = category
	return chosen


func _free_voice(now: float) -> int:
	for i in _ends_at.size():
		if _ends_at[i] <= now:
			return i
	return -1


## Oldest (earliest-ending) playing voice, optionally limited to one category. -1 if none.
func _oldest_playing(now: float, only_category: String = "") -> int:
	var best := -1
	for i in _ends_at.size():
		if _ends_at[i] <= now:
			continue
		if only_category != "" and _category[i] != only_category:
			continue
		if best == -1 or _ends_at[i] < _ends_at[best]:
			best = i
	return best


func _steal_lower_priority(now: float, priority: int) -> int:
	var best := -1
	var best_prio := 1 << 20
	for i in _ends_at.size():
		if _ends_at[i] <= now:
			continue
		var p: int = PRIORITY.get(_category[i], DEFAULT_PRIORITY)
		if p >= priority:
			continue
		if p < best_prio or (p == best_prio and _ends_at[i] < _ends_at[best]):
			best = i
			best_prio = p
	return best
