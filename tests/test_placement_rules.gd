extends TestCase
## Crossing map facts used here (x right, y down): core (3,20) is road; (7,19) and (7,21) are grass;
## (5,19) is road; (10,21) is rock; (20,12) is grass but far from the core.

var _map: MapDefinition


func _crossing() -> MapDefinition:
	if _map == null:
		_map = load("res://data/maps/crossing.tres")
	return _map


const CORE := Vector2i(3, 20)
const R := PlacementRules.Reason


func _check(cell: Vector2i, radius: float = 10.0, occupied: Array[Vector2i] = []) -> int:
	return PlacementRules.check_deploy(_crossing(), cell, CORE, radius, occupied)


func test_grass_near_the_core_is_valid() -> void:
	assert_eq(_check(Vector2i(7, 19)), R.OK)
	assert_eq(_check(Vector2i(7, 21)), R.OK)


func test_roads_are_buildable_and_rock_is_not() -> void:
	assert_eq(_check(Vector2i(5, 19)), R.OK, "road")
	assert_eq(_check(Vector2i(10, 21)), R.NOT_BUILDABLE, "rock")


func test_out_of_bounds_is_reported_not_crashed() -> void:
	for c in [Vector2i(-1, 5), Vector2i(5, -1), Vector2i(24, 5), Vector2i(5, 24), Vector2i(999, 999)]:
		assert_eq(_check(c), R.OUT_OF_BOUNDS, str(c))


func test_far_from_core_is_rejected() -> void:
	assert_eq(_check(Vector2i(20, 12)), R.TOO_FAR_FROM_CORE)


func test_radius_is_inclusive_at_the_exact_distance() -> void:
	var d := Vector2(4, -1).length()  # (7,19) -> core (3,20), centre to centre
	assert_eq(_check(Vector2i(7, 19), d), R.OK)
	assert_eq(_check(Vector2i(7, 19), d - 0.001), R.TOO_FAR_FROM_CORE)


func test_distance_is_measured_in_ground_tiles_along_either_axis() -> void:
	# (7,20) is exactly 4 tiles from the core along +x; (3,23) is exactly 3 tiles along +y.
	assert_eq(_check(Vector2i(7, 20), 4.0), R.OK)
	assert_eq(_check(Vector2i(7, 20), 3.99), R.TOO_FAR_FROM_CORE)
	assert_eq(_check(Vector2i(3, 23), 3.0), R.OK)
	assert_eq(_check(Vector2i(3, 23), 2.9), R.TOO_FAR_FROM_CORE)


func test_occupied_cells_and_the_core_cell_are_rejected() -> void:
	var occ: Array[Vector2i] = [Vector2i(7, 19)]
	assert_eq(_check(Vector2i(7, 19), 10.0, occ), R.OCCUPIED)
	assert_eq(_check(Vector2i(7, 21), 10.0, occ), R.OK, "neighbour stays free")
	assert_eq(PlacementRules.check_deploy(_crossing(), CORE, CORE, 10.0, []), R.OCCUPIED, "the core's own cell")


func test_core_cell_on_grass_is_still_occupied() -> void:
	# Independent of terrain: pretend the core stands on a grass cell.
	assert_eq(PlacementRules.check_deploy(_crossing(), Vector2i(7, 19), Vector2i(7, 19), 10.0, []), R.OCCUPIED)


func test_reason_priority_buildable_before_range_before_occupied() -> void:
	var occ: Array[Vector2i] = [Vector2i(10, 21)]
	assert_eq(_check(Vector2i(10, 21), 10.0, occ), R.NOT_BUILDABLE)


func test_every_reason_has_text() -> void:
	for r in [R.OK, R.OUT_OF_BOUNDS, R.NOT_BUILDABLE, R.TOO_FAR_FROM_CORE, R.OCCUPIED]:
		assert_true(PlacementRules.describe(r).length() > 0)


func test_formation_offsets() -> void:
	assert_eq(PlacementRules.formation_offsets(1), [Vector2.ZERO] as Array[Vector2])
	assert_eq(PlacementRules.formation_offsets(0).size(), 1, "never zero units' worth of nothing")
	var three := PlacementRules.formation_offsets(3)
	assert_eq(three.size(), 3)
	for o in three:
		assert_near(o.length(), PlacementRules.RING_RADIUS, 1e-6)
		assert_true(absf(o.x) < 0.5 and absf(o.y) < 0.5, "stays inside its cell")
	assert_true(three[0] != three[1] and three[1] != three[2] and three[0] != three[2])
	assert_near((three[0] + three[1] + three[2]).length(), 0.0, 1e-5, "evenly spread around the centre")


# --- build anywhere and the spawn guard ---------------------------------------------------------------------------------

func test_a_zero_radius_means_the_whole_map() -> void:
	assert_eq(_check(Vector2i(20, 12), 0.0), R.OK, "far from the core, but there is no limit")
	assert_eq(_check(Vector2i(20, 12), 10.0), R.TOO_FAR_FROM_CORE, "a positive radius still limits")


func test_the_spawn_guard_refuses_cells_around_a_spawn_and_nothing_else() -> void:
	var spawns: Array[Vector2i] = [Vector2i(20, 3)]
	var none: Array[Vector2i] = []
	assert_eq(PlacementRules.check_deploy(_crossing(), Vector2i(20, 4), CORE, 0.0, none, spawns, 6.0), R.TOO_CLOSE_TO_SPAWN)
	assert_eq(PlacementRules.check_deploy(_crossing(), Vector2i(20, 12), CORE, 0.0, none, spawns, 6.0), R.OK, "nine cells away is out of the guard")
	assert_eq(PlacementRules.check_deploy(_crossing(), Vector2i(20, 4), CORE, 0.0, none, spawns, 0.0), R.OK, "a zero guard turns it off")
	assert_eq(PlacementRules.check_deploy(_crossing(), Vector2i(20, 4), CORE, 0.0, none, none, 6.0), R.OK, "no spawns, nothing to guard")


func test_the_guard_is_measured_to_the_cell_centre_and_is_exclusive_at_the_edge() -> void:
	var spawns: Array[Vector2i] = [Vector2i(12, 12)]
	var none: Array[Vector2i] = []
	assert_eq(PlacementRules.check_deploy(_crossing(), Vector2i(12, 17), CORE, 0.0, none, spawns, 5.0), R.OK, "exactly 5 tiles away is allowed")
	assert_eq(PlacementRules.check_deploy(_crossing(), Vector2i(12, 16), CORE, 0.0, none, spawns, 5.0), R.TOO_CLOSE_TO_SPAWN)


func test_the_new_reason_has_its_own_message() -> void:
	var seen: Dictionary = {}
	for reason in [R.OK, R.OUT_OF_BOUNDS, R.NOT_BUILDABLE, R.TOO_FAR_FROM_CORE, R.OCCUPIED, R.TOO_CLOSE_TO_SPAWN]:
		seen[PlacementRules.describe(reason)] = true
	assert_eq(seen.size(), 6)


func test_every_shipped_mission_can_be_built_on_anywhere_except_the_spawn_zone() -> void:
	var db := ContentDb.load_from("res://data")
	for id in db.missions:
		var m: MissionDefinition = db.missions[id]
		assert_near(m.deploy_radius, 0.0, 1e-9, "%s has no deploy limit" % id)
		assert_true(m.spawn_guard_radius > 0.0, "%s guards its spawns" % id)
		var buildable := 0
		var refused_by_guard := 0
		for y in m.map.height():
			for x in m.map.width():
				var cell := Vector2i(x, y)
				if not m.map.is_buildable(cell) or cell == m.core_cell:
					continue
				var r := PlacementRules.check_deploy(m.map, cell, m.core_cell, m.deploy_radius, [], m.spawn_cells, m.spawn_guard_radius)
				assert_true(r == R.OK or r == R.TOO_CLOSE_TO_SPAWN, "%s %s -> %s" % [id, str(cell), str(r)])
				buildable += 1
				if r == R.TOO_CLOSE_TO_SPAWN:
					refused_by_guard += 1
		assert_true(buildable > 0 and refused_by_guard < buildable / 4, "%s: the guard takes only a corner of the map" % id)


func test_roads_in_the_shipped_maps_are_buildable() -> void:
	var db := ContentDb.load_from("res://data")
	var m: MissionDefinition = db.mission("m2_card_defense")
	var roads := 0
	for y in m.map.height():
		for x in m.map.width():
			if m.map.terrain_char(Vector2i(x, y)) == "=":
				roads += 1
				assert_true(m.map.is_buildable(Vector2i(x, y)))
	assert_true(roads > 10, "the crossing map has a road")
