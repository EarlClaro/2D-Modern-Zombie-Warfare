class_name MissionDefinition
extends ContentDefinition
## A defence mission: hold the core for `duration_s`. Everything the battle needs is data here.
## Enemies spawn at a spawn cell and walk the straight segments through `path_cells` (waypoints,
## last one = core cell). Cross-references to unit/enemy ids are verified by ContentDb.

@export var display_name: String = ""
@export var map: MapDefinition
@export var core_cell: Vector2i = Vector2i.ZERO
@export var core_health: float = 0.0
@export var duration_s: float = 0.0
@export var spawn_cells: Array[Vector2i] = []
@export var path_cells: Array[Vector2i] = []
## How enemies find their way (ADR-012). WAYPOINTS: straight segments through `path_cells`, which must be clear of scenery
## (the default, so no older mission changes). FLOW: they steer down a flow field from the core around terrain and scenery;
## `path_cells` is then optional and ignored, and every spawn must be able to reach the core.
enum Routing { WAYPOINTS, FLOW }
@export var routing: Routing = Routing.WAYPOINTS
@export var start_units: Array[StartUnit] = []
@export var waves: Array[WaveEntry] = []
## Optional: the deck id the player draws from (empty = no cards, as in M1 missions).
@export var deck_id: String = ""
## Deployment cards may only be placed within this many tiles of the core.
@export var deploy_radius: float = 0.0
## 0 = no limit: cards may be placed anywhere on the map (every shipped mission). Otherwise the limit above applies.
## Enemy spawn cells: a deployment card cannot be placed closer than this to one (tiles; 0 = no guard).
@export var spawn_guard_radius: float = 6.0
## Optional: the difficulty this mission uses when none is chosen (empty = normal).
@export var difficulty_id: String = ""
## Optional: ids of DOCTRINE cards in force for the whole mission (until the pre-mission picker exists, M5).
@export var doctrines: PackedStringArray = PackedStringArray()
## Optional: scenery id of the command-bunker art drawn for the core (empty = the plain box), and how far
## its walls reach from the core's centre in tiles (enemies attack from that far out).
@export var core_scenery_id: String = ""
@export var core_radius: float = 0.0
## Look of the battle (presentation only, see Atmosphere): time of day at the start (0 = midnight, 0.25 sunrise,
## 0.5 noon, 0.75 sunset), seconds one full day takes (0 = the time stays put) and the weather (DayNight.WEATHER).
@export_range(0.0, 1.0) var time_of_day: float = 0.5
@export var day_length_s: float = 0.0
@export var weather: String = "clear"


func kind() -> String:
	return "mission"


func total_enemies() -> int:
	var n := 0
	for w in waves:
		if w != null:
			n += maxi(w.count, 0)
	return n


## Enemies the mission sends at a difficulty (the base total when `diff` is null).
func total_enemies_at(diff: DifficultyDefinition) -> int:
	var base := total_enemies()
	var n := 0
	for w in waves:
		if w != null:
			n += diff.scaled_count(maxi(w.count, 0), base) if diff != null else maxi(w.count, 0)
	return n


func validate() -> PackedStringArray:
	var errs := super.validate()
	if display_name.is_empty():
		errs.append(_err("display_name is empty"))
	if core_health <= 0.0:
		errs.append(_err("core_health must be > 0"))
	if duration_s <= 0.0:
		errs.append(_err("duration_s must be > 0"))

	var map_ok := false
	if map == null:
		errs.append(_err("map is not set"))
	else:
		var map_errs := map.validate()
		if map_errs.is_empty():
			map_ok = true
		else:
			errs.append(_err("map '%s' is invalid (%d error(s)); fix the map first" % [map.id, map_errs.size()]))
	if map_ok:
		_validate_geometry(errs)
	if deploy_radius < 0.0:
		errs.append(_err("deploy_radius must be >= 0 (0 = the whole map)"))
	if spawn_guard_radius < 0.0:
		errs.append(_err("spawn_guard_radius must be >= 0"))
	if core_radius < 0.0:
		errs.append(_err("core_radius must be >= 0"))
	if day_length_s < 0.0:
		errs.append(_err("day_length_s must be >= 0"))
	if time_of_day < 0.0 or time_of_day > 1.0:
		errs.append(_err("time_of_day must be within 0..1"))
	if not DayNight.is_weather(weather):
		errs.append(_err("weather '%s' is unknown (%s)" % [weather, ", ".join(DayNight.WEATHER)]))
	_validate_start_units(errs, map_ok)
	_validate_waves(errs)
	return errs


func _cell_name(c: Vector2i) -> String:
	return "(%d, %d)" % [c.x, c.y]


func _validate_geometry(errs: PackedStringArray) -> void:
	if not map.is_walkable(core_cell):
		errs.append(_err("core_cell %s is out of bounds or blocked" % _cell_name(core_cell)))
	if spawn_cells.is_empty():
		errs.append(_err("spawn_cells is empty"))
	for s in spawn_cells:
		if not map.is_walkable(s):
			errs.append(_err("spawn cell %s is out of bounds or blocked" % _cell_name(s)))
	if routing == Routing.FLOW:
		return  # the flow field finds the way; whether every spawn can reach the core is checked by ContentDb (it needs the scenery)
	if path_cells.is_empty():
		errs.append(_err("path_cells is empty"))
		return
	for p in path_cells:
		if not map.is_walkable(p):
			errs.append(_err("path cell %s is out of bounds or blocked" % _cell_name(p)))
	if path_cells.back() != core_cell:
		errs.append(_err("path_cells must end at core_cell %s (ends at %s)" % [_cell_name(core_cell), _cell_name(path_cells.back())]))
	# Enemies walk straight lines, so every segment from each spawn must stay on walkable ground.
	for s in spawn_cells:
		var from := IsoProjection.cell_center(s)
		for p in path_cells:
			var to := IsoProjection.cell_center(p)
			if not map.segment_is_walkable(from, to):
				errs.append(_err("path segment %s -> %s crosses blocked terrain" % [_cell_name(Vector2i(from)), _cell_name(p)]))
			from = to


func _validate_start_units(errs: PackedStringArray, map_ok: bool) -> void:
	var seen: Dictionary = {}
	for i in start_units.size():
		var su := start_units[i]
		if su == null:
			errs.append(_err("start_units[%d] is null" % i))
			continue
		if su.unit_id.is_empty():
			errs.append(_err("start_units[%d] has an empty unit_id" % i))
		if seen.has(su.cell):
			errs.append(_err("start units overlap at %s" % _cell_name(su.cell)))
		seen[su.cell] = true
		if su.cell == core_cell:
			errs.append(_err("start unit '%s' is placed on the core cell" % su.unit_id))
		if map_ok and not map.is_walkable(su.cell):
			errs.append(_err("start unit '%s' at %s is out of bounds or blocked" % [su.unit_id, _cell_name(su.cell)]))


func _validate_waves(errs: PackedStringArray) -> void:
	if waves.is_empty():
		errs.append(_err("waves is empty"))
	for i in waves.size():
		var w := waves[i]
		if w == null:
			errs.append(_err("waves[%d] is null" % i))
			continue
		if w.enemy_id.is_empty():
			errs.append(_err("waves[%d] has an empty enemy_id" % i))
		if w.count < 1:
			errs.append(_err("waves[%d] count must be >= 1" % i))
		if w.start_s < 0.0:
			errs.append(_err("waves[%d] start_s must be >= 0" % i))
		if w.interval_s < 0.0:
			errs.append(_err("waves[%d] interval_s must be >= 0" % i))
		if w.spawn_index < 0 or w.spawn_index >= spawn_cells.size():
			errs.append(_err("waves[%d] spawn_index %d is out of range (%d spawn cells)" % [i, w.spawn_index, spawn_cells.size()]))
		if duration_s > 0.0 and w.last_spawn_s() > duration_s:
			errs.append(_err("waves[%d] spawns its last enemy at %.1fs, after the mission ends (%.1fs)" % [i, w.last_spawn_s(), duration_s]))
