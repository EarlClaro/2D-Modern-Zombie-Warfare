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
@export var start_units: Array[StartUnit] = []
@export var waves: Array[WaveEntry] = []
## Optional: the deck id the player draws from (empty = no cards, as in M1 missions).
@export var deck_id: String = ""
## Deployment cards may only be placed within this many tiles of the core.
@export var deploy_radius: float = 10.0


func kind() -> String:
	return "mission"


func total_enemies() -> int:
	var n := 0
	for w in waves:
		if w != null:
			n += maxi(w.count, 0)
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
	if deploy_radius <= 0.0:
		errs.append(_err("deploy_radius must be > 0"))
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
