class_name CampaignDefinition
extends ContentDefinition
## The campaign chain (docs/specs/progression.md): the missions in the order they unlock. The first is open from the
## start, every other one opens when the one before it has been won. Missions not in the list (test missions) are
## never locked. Pure data and rules; the profile is only read.

@export var display_name: String = ""
@export var mission_ids: PackedStringArray = PackedStringArray()


func kind() -> String:
	return "campaign"


func validate() -> PackedStringArray:
	var errs := super.validate()
	if display_name.is_empty():
		errs.append(_err("display_name is empty"))
	if mission_ids.is_empty():
		errs.append(_err("mission_ids is empty"))
	var seen: Dictionary = {}
	for mid in mission_ids:
		if seen.has(mid):
			errs.append(_err("mission '%s' is listed twice" % mid))
		seen[mid] = true
	return errs


func contains(mission_id: String) -> bool:
	return mission_ids.has(mission_id)


func index_of(mission_id: String) -> int:
	return mission_ids.find(mission_id)


## The mission that must be won before `mission_id` opens ("" for the first mission and for ids not in the chain).
func previous_of(mission_id: String) -> String:
	var i := index_of(mission_id)
	return mission_ids[i - 1] if i > 0 else ""


func is_unlocked(profile: PlayerProfile, mission_id: String) -> bool:
	var prev := previous_of(mission_id)
	return prev.is_empty() or profile.is_won(prev)


## The first mission of the chain that is open and not won yet ("" when every mission has been won).
func next_up(profile: PlayerProfile) -> String:
	for mid in mission_ids:
		if not profile.is_won(mid):
			return mid if is_unlocked(profile, mid) else ""
	return ""


## The mission that a win of `mission_id` opens ("" if it opens none or was already open).
func unlocked_by(profile: PlayerProfile, mission_id: String) -> String:
	var i := index_of(mission_id)
	if i < 0 or i + 1 >= mission_ids.size():
		return ""
	var nxt := mission_ids[i + 1]
	return nxt if profile.is_won(mission_id) and not profile.is_won(nxt) else ""
