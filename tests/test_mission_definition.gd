extends TestCase

const MapDef := preload("res://scripts/missions/map_definition.gd")
const MissionDef := preload("res://scripts/missions/mission_definition.gd")
const StartUnitRes := preload("res://scripts/missions/start_unit.gd")
const WaveEntryRes := preload("res://scripts/missions/wave_entry.gd")
const Db := preload("res://scripts/core/content_db.gd")

# 8x8 open field with a rock wall on column 4 except a gap at rows 3-4.
const ROWS := [
	"....#...",
	"....#...",
	"....#...",
	"........",
	"........",
	"....#...",
	"....#...",
	"....#...",
]


func _map() -> MapDef:
	var m := MapDef.new()
	m.id = "test_field"
	m.rows = PackedStringArray(ROWS)
	return m


func _su(unit_id: String, cell: Vector2i) -> StartUnitRes:
	var su := StartUnitRes.new()
	su.unit_id = unit_id
	su.cell = cell
	return su


func _wave(start: float, count: int, interval: float, spawn_index: int = 0, enemy: String = "shambler") -> WaveEntryRes:
	var w := WaveEntryRes.new()
	w.start_s = start
	w.count = count
	w.interval_s = interval
	w.spawn_index = spawn_index
	w.enemy_id = enemy
	return w


## A valid mission on the test field: spawn east, core west, straight path through the gap.
func _mission() -> MissionDef:
	var m := MissionDef.new()
	m.id = "test_mission"
	m.display_name = "Test"
	m.map = _map()
	m.core_cell = Vector2i(1, 3)
	m.core_health = 100.0
	m.duration_s = 60.0
	m.spawn_cells = [Vector2i(6, 3)] as Array[Vector2i]
	m.path_cells = [Vector2i(1, 3)] as Array[Vector2i]
	m.start_units = [_su("mg_nest", Vector2i(2, 4))] as Array[StartUnitRes]
	m.waves = [_wave(1.0, 3, 1.0)] as Array[WaveEntryRes]
	return m


func _has(errs: PackedStringArray, needle: String) -> bool:
	for e in errs:
		if needle in e:
			return true
	return false


func test_baseline_mission_is_valid() -> void:
	var errs := _mission().validate()
	assert_eq(errs.size(), 0, "\n".join(errs))


func test_basic_field_errors() -> void:
	var m := _mission()
	m.display_name = ""
	m.core_health = 0.0
	m.duration_s = -5.0
	var errs := m.validate()
	assert_true(_has(errs, "display_name"))
	assert_true(_has(errs, "core_health must be > 0"))
	assert_true(_has(errs, "duration_s must be > 0"))


func test_null_map_is_an_error_not_a_crash() -> void:
	var m := _mission()
	m.map = null
	assert_true(_has(m.validate(), "map is not set"))


func test_invalid_map_is_reported_once_and_geometry_is_skipped() -> void:
	var m := _mission()
	m.map.rows = PackedStringArray(["..", "..."])
	var errs := m.validate()
	assert_true(_has(errs, "map 'test_field' is invalid"))
	assert_true(not _has(errs, "blocked"), "no geometry errors derived from a broken map")


func test_core_cell_errors() -> void:
	var m := _mission()
	m.core_cell = Vector2i(4, 0)  # rock
	assert_true(_has(m.validate(), "core_cell (4, 0) is out of bounds or blocked"))
	m.core_cell = Vector2i(40, 40)
	assert_true(_has(m.validate(), "core_cell (40, 40) is out of bounds or blocked"))


func test_spawn_errors() -> void:
	var m := _mission()
	m.spawn_cells = [] as Array[Vector2i]
	assert_true(_has(m.validate(), "spawn_cells is empty"))
	m.spawn_cells = [Vector2i(4, 1)] as Array[Vector2i]  # rock
	assert_true(_has(m.validate(), "spawn cell (4, 1) is out of bounds or blocked"))


func test_path_must_end_at_core() -> void:
	var m := _mission()
	m.path_cells = [Vector2i(2, 3)] as Array[Vector2i]
	assert_true(_has(m.validate(), "path_cells must end at core_cell (1, 3) (ends at (2, 3))"))
	m.path_cells = [] as Array[Vector2i]
	assert_true(_has(m.validate(), "path_cells is empty"))


func test_path_segment_through_rock_is_rejected() -> void:
	var m := _mission()
	m.spawn_cells = [Vector2i(6, 1)] as Array[Vector2i]  # straight line to (1,3) clips the wall at column 4
	assert_true(_has(m.validate(), "crosses blocked terrain"))


func test_path_through_the_gap_is_accepted() -> void:
	var m := _mission()
	m.spawn_cells = [Vector2i(6, 3)] as Array[Vector2i]
	assert_eq(m.validate().size(), 0)


func test_waypoint_path_around_the_wall_is_accepted() -> void:
	var m := _mission()
	m.spawn_cells = [Vector2i(6, 1)] as Array[Vector2i]
	m.path_cells = [Vector2i(5, 3), Vector2i(1, 3)] as Array[Vector2i]  # go down to the gap first
	var errs := m.validate()
	assert_eq(errs.size(), 0, "\n".join(errs))


func test_start_unit_errors() -> void:
	var m := _mission()
	m.start_units = [_su("mg_nest", Vector2i(4, 0))] as Array[StartUnitRes]
	assert_true(_has(m.validate(), "start unit 'mg_nest' at (4, 0) is out of bounds or blocked"))
	m.start_units = [_su("mg_nest", Vector2i(2, 4)), _su("rifle_soldier", Vector2i(2, 4))] as Array[StartUnitRes]
	assert_true(_has(m.validate(), "start units overlap at (2, 4)"))
	m.start_units = [_su("mg_nest", Vector2i(1, 3))] as Array[StartUnitRes]
	assert_true(_has(m.validate(), "placed on the core cell"))
	m.start_units = [_su("", Vector2i(2, 4))] as Array[StartUnitRes]
	assert_true(_has(m.validate(), "empty unit_id"))
	m.start_units = [null] as Array[StartUnitRes]
	assert_true(_has(m.validate(), "start_units[0] is null"))


func test_wave_errors() -> void:
	var m := _mission()
	m.waves = [] as Array[WaveEntryRes]
	assert_true(_has(m.validate(), "waves is empty"))
	m.waves = [_wave(1.0, 0, 1.0)] as Array[WaveEntryRes]
	assert_true(_has(m.validate(), "count must be >= 1"))
	m.waves = [_wave(-1.0, 2, 1.0)] as Array[WaveEntryRes]
	assert_true(_has(m.validate(), "start_s must be >= 0"))
	m.waves = [_wave(1.0, 2, -0.5)] as Array[WaveEntryRes]
	assert_true(_has(m.validate(), "interval_s must be >= 0"))
	m.waves = [_wave(1.0, 2, 1.0, 3)] as Array[WaveEntryRes]
	assert_true(_has(m.validate(), "spawn_index 3 is out of range (1 spawn cells)"))
	m.waves = [_wave(1.0, 2, 1.0, 0, "")] as Array[WaveEntryRes]
	assert_true(_has(m.validate(), "empty enemy_id"))
	m.waves = [null] as Array[WaveEntryRes]
	assert_true(_has(m.validate(), "waves[0] is null"))


func test_wave_that_ends_after_the_mission_is_rejected() -> void:
	var m := _mission()
	m.duration_s = 10.0
	m.waves = [_wave(5.0, 10, 1.0)] as Array[WaveEntryRes]  # last enemy at 14 s
	assert_true(_has(m.validate(), "after the mission ends"))
	m.waves = [_wave(5.0, 6, 1.0)] as Array[WaveEntryRes]  # last enemy at exactly 10 s
	assert_eq(m.validate().size(), 0, "last spawn exactly at the end is allowed")


func test_total_enemies() -> void:
	var m := _mission()
	m.waves = [_wave(1.0, 3, 1.0), _wave(10.0, 4, 0.5)] as Array[WaveEntryRes]
	assert_eq(m.total_enemies(), 7)


# --- cross-references via ContentDb ---------------------------------------------------------------

func test_db_reports_unknown_unit_and_enemy_ids_in_missions() -> void:
	var db := Db.new()
	var m := _mission()
	m.start_units = [_su("ghost_unit", Vector2i(2, 4))] as Array[StartUnitRes]
	m.waves = [_wave(1.0, 2, 1.0, 0, "ghost_enemy")] as Array[WaveEntryRes]
	assert_true(db.add_mission(m), "structurally valid")
	db.validate_references()
	assert_true(_has(db.errors, "mission 'test_mission': start unit references unknown unit_id 'ghost_unit'"))
	assert_true(_has(db.errors, "mission 'test_mission': wave references unknown enemy_id 'ghost_enemy'"))


func test_db_rejects_invalid_mission_and_duplicate_ids() -> void:
	var db := Db.new()
	var bad := _mission()
	bad.core_health = 0.0
	assert_true(not db.add_mission(bad))
	assert_true(db.mission("test_mission") == null)
	assert_true(db.add_mission(_mission()))
	assert_true(not db.add_mission(_mission()))
	assert_true(_has(db.errors, "mission 'test_mission': duplicate id"))


# --- shipped mission -----------------------------------------------------------------------------

func test_shipped_mission_loads_and_cross_references_resolve() -> void:
	var db := Db.load_from("res://data")
	assert_true(db.is_valid(), "\n".join(db.errors))
	var m := db.mission("m1_hold_the_crossing")
	assert_true(m != null, "mission present")
	assert_true(db.map("crossing") != null, "map present")
	for su in m.start_units:
		assert_true(db.unit(su.unit_id) != null, "start unit " + su.unit_id)
	for w in m.waves:
		assert_true(db.enemy(w.enemy_id) != null, "wave enemy " + w.enemy_id)
	assert_true(m.total_enemies() > 0)
	assert_true(m.map.is_walkable(m.core_cell))


func test_shipped_mission_geometry_properties() -> void:
	# Relations that must hold regardless of tuning: enemies reach the core without crossing rock, and
	# the route passes through a chokepoint (rock exists on both sides of the path).
	var db := Db.load_from("res://data")
	var m := db.mission("m1_hold_the_crossing")
	assert_true(m != null)
	assert_eq(m.path_cells.back(), m.core_cell)
	var rocks := 0
	for y in m.map.height():
		for x in m.map.width():
			if m.map.terrain_char(Vector2i(x, y)) == MapDef.ROCK:
				rocks += 1
	assert_true(rocks > 0, "map has blocking terrain")
	# Mission is winnable only if defenders exist; make sure at least one unit starts on the map.
	assert_true(m.start_units.size() >= 1)
