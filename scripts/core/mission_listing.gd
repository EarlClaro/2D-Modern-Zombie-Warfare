class_name MissionListing
extends RefCounted
## What mission select shows (docs/specs/menus.md): every mission in the content database, grouped and ordered, and
## the facts of one mission as plain lines. Pure: it only reads the database.

const GROUP_MISSIONS: String = "Missions"
const GROUP_TESTS: String = "Test missions"


class Entry:
	extends RefCounted
	var id: String
	var name: String
	var group: String

	func _init(p_id: String, p_name: String, p_group: String) -> void:
		id = p_id
		name = p_name
		group = p_group


## The group of a mission id: campaign-style ids (m1_, x2_...) are missions, everything else is a test mission.
static func group_of(mission_id: String) -> String:
	if mission_id.length() >= 2 and (mission_id[0] == "m" or mission_id[0] == "x") and mission_id[1].is_valid_int():
		return GROUP_MISSIONS
	return GROUP_TESTS


## Id order a person expects: the number in "x10_..." counts as a number, so x10 comes after x9, not after x1.
static func id_less(a: String, b: String) -> bool:
	var ka := _sort_key(a)
	var kb := _sort_key(b)
	if ka[0] != kb[0]:
		return ka[0] < kb[0]
	if ka[1] != kb[1]:
		return ka[1] < kb[1]
	return a < b


## [letters before the first digit run, that digit run as a number] ("x10_foo" -> ["x", 10]).
static func _sort_key(id: String) -> Array:
	var i := 0
	while i < id.length() and not id[i].is_valid_int():
		i += 1
	var j := i
	while j < id.length() and id[j].is_valid_int():
		j += 1
	return [id.substr(0, i), int(id.substr(i, j - i)) if j > i else -1]


## Every mission once: Missions first, then Test missions, each in id order (numbers counted as numbers).
static func entries(db: ContentDb) -> Array[Entry]:
	var ids: Array = db.missions.keys()
	ids.sort_custom(id_less)
	var out: Array[Entry] = []
	for group in [GROUP_MISSIONS, GROUP_TESTS]:
		for id: String in ids:
			if group_of(id) == group:
				out.append(Entry.new(id, (db.missions[id] as MissionDefinition).display_name, group))
	return out


## The lines of the details panel, all taken from data.
static func facts(db: ContentDb, mission: MissionDefinition) -> PackedStringArray:
	var lines := PackedStringArray()
	if mission == null:
		return lines
	lines.append("Hold the core for %s." % format_time(mission.duration_s))
	lines.append("Core health: %d" % int(mission.core_health))
	lines.append("Enemies: %d (%s)" % [mission.total_enemies(), ", ".join(enemy_names(db, mission))])
	var deck := db.deck(mission.deck_id) if not mission.deck_id.is_empty() else null
	if deck != null:
		lines.append("Deck: %s (%d cards)" % [deck.display_name, deck.card_ids.size()])
	else:
		lines.append("No cards: the units you start with defend the core.")
	lines.append("Time: %s, weather: %s" % [time_name(mission.time_of_day), mission.weather])
	return lines


## "2:00" style.
static func format_time(seconds: float) -> String:
	var s := maxi(int(round(seconds)), 0)
	return "%d:%02d" % [s / 60, s % 60]


## The distinct enemy names of a mission in the order they first appear.
static func enemy_names(db: ContentDb, mission: MissionDefinition) -> PackedStringArray:
	var out := PackedStringArray()
	for w in mission.waves:
		if w == null:
			continue
		var def := db.enemy(w.enemy_id)
		var name := def.display_name if def != null and not def.display_name.is_empty() else w.enemy_id
		if not out.has(name):
			out.append(name)
	return out


## A word for the time of day (0 = midnight, 0.25 sunrise, 0.5 noon, 0.75 sunset).
static func time_name(t: float) -> String:
	if t < 0.125 or t >= 0.875:
		return "night"
	if t < 0.375:
		return "morning"
	if t < 0.625:
		return "day"
	return "evening"
