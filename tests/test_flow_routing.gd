extends TestCase
## Flow routing in missions and battles (M3.11 part 2, ADR-012): the mission picks `routing`, content validation checks
## that every spawn can reach the core, and flow enemies walk around terrain and scenery. Waypoint missions are unchanged.

const DT: float = 1.0 / 60.0

var _db: ContentDb
var _made: Array[BattleController] = []

# A wall of rock across the middle with the only gap along the bottom; spawn top-left, core top-right.
const WALLED_ROWS: Array = [
	"..........##..........",
	"..........##..........",
	"..........##..........",
	"..........##..........",
	"..........##..........",
	"..........##..........",
	"..........##..........",
	"......................",
]


func _get_db() -> ContentDb:
	if _db == null:
		_db = ContentDb.load_from()
	return _db


func _has(errs: PackedStringArray, needle: String) -> bool:
	for e in errs:
		if needle in e:
			return true
	return false


func _map(rows: Array, scenery: Array = []) -> MapDefinition:
	var m := MapDefinition.new()
	m.id = "flow_test_map"
	m.rows = PackedStringArray(rows)
	m.scenery = PackedStringArray(scenery)
	return m


## A flow mission on `map` with one wave of `count` shamblers from the spawn cell.
func _mission(map: MapDefinition, spawn: Vector2i, core: Vector2i, count: int = 5, routing: MissionDefinition.Routing = MissionDefinition.Routing.FLOW) -> MissionDefinition:
	var m: MissionDefinition = _get_db().mission("m1_hold_the_crossing").duplicate()
	m.id = "flow_test"
	m.map = map
	m.routing = routing
	m.core_cell = core
	m.spawn_cells = [spawn] as Array[Vector2i]
	m.path_cells = [] as Array[Vector2i]
	m.start_units = [] as Array[StartUnit]
	m.core_health = 100000.0
	m.duration_s = 300.0
	var w := WaveEntry.new()
	w.start_s = 0.0
	w.enemy_id = "shambler"
	w.count = count
	w.interval_s = 1.0
	m.waves = [w] as Array[WaveEntry]
	return m


func _battle(m: MissionDefinition, seed_value: int = 1) -> BattleController:
	var b := BattleController.new()
	b.auto_step = false
	b.setup(_get_db(), m, seed_value)
	_made.append(b)
	return b


func _release() -> void:
	for b in _made:
		b.free()
	_made.clear()


func _cell_of(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x), floori(p.y))


# --- the mission's routing ---------------------------------------------------------------------------------------

func test_waypoints_are_the_default_and_no_shipped_mission_uses_flow_by_accident() -> void:
	assert_eq(MissionDefinition.new().routing, MissionDefinition.Routing.WAYPOINTS)
	var flow_missions: Array[String] = []
	for id: String in _get_db().missions.keys():
		if _get_db().mission(id).routing == MissionDefinition.Routing.FLOW:
			flow_missions.append(id)
	flow_missions.sort()
	assert_eq(flow_missions, ["dev_flow_outskirts", "dev_objectives"], "only the two dev missions (flow demo, objectives demo) opt in so far")


func test_a_flow_mission_needs_no_waypoints_but_a_waypoint_mission_still_does() -> void:
	var m := _mission(_map(WALLED_ROWS), Vector2i(0, 0), Vector2i(21, 0))
	assert_eq(m.validate().size(), 0, str(m.validate()))
	var w := _mission(_map(WALLED_ROWS), Vector2i(0, 0), Vector2i(21, 0), 5, MissionDefinition.Routing.WAYPOINTS)
	assert_true(_has(w.validate(), "path_cells is empty"))


func test_a_flow_mission_still_needs_a_walkable_core_and_spawn() -> void:
	var m := _mission(_map(WALLED_ROWS), Vector2i(10, 0), Vector2i(21, 0))
	assert_true(_has(m.validate(), "spawn cell"), "(10, 0) is rock")
	var c := _mission(_map(WALLED_ROWS), Vector2i(0, 0), Vector2i(11, 3))
	assert_true(_has(c.validate(), "core_cell"), "(11, 3) is rock")


func test_a_spawn_that_cannot_reach_the_core_is_a_content_error() -> void:
	var sealed := [
		"..........##..........",
		"..........##..........",
		"..........##..........",
	]
	var m := _mission(_map(sealed), Vector2i(0, 0), Vector2i(21, 0))
	var db := ContentDb.new()
	db.add_map(m.map)
	db.add_mission(m)
	db.validate_references()
	assert_true(_has(db.errors, "has no way to the core"), str(db.errors))
	var open := _mission(_map(WALLED_ROWS), Vector2i(0, 0), Vector2i(21, 0))
	var db2 := ContentDb.new()
	db2.add_map(open.map)
	db2.add_mission(open)
	db2.validate_references()
	assert_true(not _has(db2.errors, "has no way to the core"), str(db2.errors))


func test_scenery_that_seals_the_way_is_a_content_error_too() -> void:
	var tree := SceneryDefinition.new()
	tree.id = "tree"
	tree.display_name = "tree"
	tree.footprint = Vector2i.ONE
	var sheet := SpriteSheet.new()
	sheet.textures = {"SE": PlaceholderTexture2D.new()}
	tree.sprite = sheet
	var pieces: Array = []
	for y in 3:
		pieces.append("tree 5 %d" % y)
	var m := _mission(_map(["...........", "...........", "..........."], pieces), Vector2i(0, 1), Vector2i(10, 1))
	var db := ContentDb.new()
	db.add_scenery(tree)
	db.add_map(m.map)
	db.add_mission(m)
	db.validate_references()
	assert_true(_has(db.errors, "has no way to the core"), "a column of trees blocks every row: " + str(db.errors))


func _tree() -> SceneryDefinition:
	var tree := SceneryDefinition.new()
	tree.id = "tree"
	tree.display_name = "tree"
	tree.footprint = Vector2i.ONE
	var sheet := SpriteSheet.new()
	sheet.textures = {"SE": PlaceholderTexture2D.new()}
	tree.sprite = sheet
	return tree


func test_a_flow_mission_skips_the_waypoint_scenery_rule() -> void:
	var m := _mission(_map(["...........", "...........", "..........."], ["tree 5 1"]), Vector2i(0, 1), Vector2i(10, 1))
	m.path_cells = [Vector2i(10, 1)] as Array[Vector2i]  # a straight line through the tree: fine under flow, which goes round it
	var db := ContentDb.new()
	db.add_scenery(_tree())
	db.add_map(m.map)
	db.add_mission(m)
	db.validate_references()
	assert_true(not _has(db.errors, "crosses"), str(db.errors))
	var w := _mission(m.map, Vector2i(0, 1), Vector2i(10, 1), 5, MissionDefinition.Routing.WAYPOINTS)
	w.path_cells = [Vector2i(10, 1)] as Array[Vector2i]
	var db2 := ContentDb.new()
	db2.add_scenery(_tree())
	db2.add_map(w.map)
	db2.add_mission(w)
	db2.validate_references()
	assert_true(_has(db2.errors, "crosses scenery"), "the same line is an error for a waypoint mission")


func test_the_db_lists_the_cells_scenery_covers() -> void:
	var house := _tree()
	house.id = "house"
	house.footprint = Vector2i(2, 2)
	var db := ContentDb.new()
	db.add_scenery(_tree())
	db.add_scenery(house)
	var cells := db.scenery_cells(_map(["......", "......", "......", "......"], ["tree 0 0", "house 3 1", "ghost 5 3"]))
	assert_eq(cells.size(), 5, "one tree cell, four house cells, the unknown piece skipped")
	for c in [Vector2i(0, 0), Vector2i(3, 1), Vector2i(4, 1), Vector2i(3, 2), Vector2i(4, 2)]:
		assert_true(cells.has(c), str(c))


# --- battles ----------------------------------------------------------------------------------------------------

func test_flow_enemies_walk_round_the_wall_to_the_core() -> void:
	var m := _mission(_map(WALLED_ROWS), Vector2i(1, 1), Vector2i(20, 1))
	var b := _battle(m)
	assert_true(b._flow != null, "the controller built the field")
	var open := b._flow
	var through_gap := false
	var nearest := INF
	var core_c := IsoProjection.cell_center(m.core_cell)
	for i in 60 * 120:
		b.step(DT)
		for e in b.enemies:
			if not e.is_alive():
				continue
			assert_true(open.is_open(_cell_of(e.ground_pos)), "enemy %d stands on closed ground at %s (tick %d)" % [e.uid, str(e.ground_pos), i])
			nearest = minf(nearest, e.ground_pos.distance_to(core_c))
			if e.ground_pos.y > 6.5 and e.ground_pos.x > 9.0 and e.ground_pos.x < 13.0:
				through_gap = true
		if nearest < 2.0 and through_gap:
			break
	assert_true(through_gap, "they went through the gap in the bottom row")
	assert_true(nearest < 2.5, "and reached the core (closest %f)" % nearest)
	_release()


func test_flow_enemies_walk_round_scenery() -> void:
	var db := _get_db()
	var piece := ""
	for id: String in db.scenery_defs.keys():
		var d: SceneryDefinition = db.scenery_defs[id]
		if d.footprint == Vector2i.ONE and not d.fades:
			piece = id
			break
	assert_true(piece != "", "the library has a 1x1 piece")
	var pieces: Array = []
	for y in range(0, 6):
		pieces.append("%s 6 %d" % [piece, y])  # a column of scenery with a gap in the bottom two rows
	var rows: Array = []
	for y in 8:
		rows.append("............")
	var m := _mission(_map(rows, pieces), Vector2i(1, 1), Vector2i(10, 1))
	assert_eq(m.validate().size(), 0)
	var b := _battle(m)
	var blocked: Dictionary = db.scenery_cells(m.map)
	assert_eq(blocked.size(), 6)
	var nearest := INF
	var core_c := IsoProjection.cell_center(m.core_cell)
	for i in 60 * 100:
		b.step(DT)
		for e in b.enemies:
			if e.is_alive():
				assert_true(not blocked.has(_cell_of(e.ground_pos)), "enemy %d walks through scenery at %s" % [e.uid, str(e.ground_pos)])
				nearest = minf(nearest, e.ground_pos.distance_to(core_c))
		if nearest < 2.0:
			break
	assert_true(nearest < 2.5, "and still reaches the core (closest %f)" % nearest)
	_release()


func test_flow_enemies_have_lanes_and_no_waypoints_and_look_up_on_a_schedule() -> void:
	var m := _mission(_map(WALLED_ROWS), Vector2i(1, 1), Vector2i(20, 1), 8)
	m.path_cells = [Vector2i(20, 1)] as Array[Vector2i]  # waypoints that a flow mission must ignore
	var b := _battle(m)
	assert_true(not b._waypoints.is_empty(), "the controller read them")
	for i in 60 * 10:
		b.step(DT)
	assert_true(b.enemies.size() >= 4)
	var lanes := {}
	for e in b.enemies:
		assert_true(e._waypoints.is_empty(), "a flow walker carries no waypoints")
		lanes[e._lane] = true
		assert_true(e.steer_lookups >= 1)
		assert_true(e.steer_lookups <= int(ceil(float(b._tick) / float(BattleEnemy.STEER_EVERY))) + 3, "enemy %d looked up %d times in %d ticks" % [e.uid, e.steer_lookups, b._tick])
	assert_true(lanes.size() >= 3, "the lanes differ")
	for lane: Vector2 in lanes.keys():
		assert_true(lane.length() <= BattleController.LANE_JITTER + 1e-6)
	_release()


func test_a_waypoint_mission_leaves_the_field_unbuilt() -> void:
	var b := _battle(_get_db().mission("m1_hold_the_crossing"))
	assert_true(b._flow == null)
	assert_true(b._routes.size() > 0)
	b.setup(_get_db(), _mission(_map(WALLED_ROWS), Vector2i(1, 1), Vector2i(20, 1)), 1)
	assert_true(b._flow != null, "a restart into a flow mission builds it")
	b.setup(_get_db(), _get_db().mission("m1_hold_the_crossing"), 1)
	assert_true(b._flow == null, "and a restart into a waypoint mission drops it again")
	_release()


func test_the_route_of_a_flow_mission_goes_round_the_wall() -> void:
	var m := _mission(_map(WALLED_ROWS), Vector2i(1, 1), Vector2i(20, 1))
	var b := _battle(m)
	assert_eq(b._routes.size(), 1)
	var r: Route = b._routes[0]
	var straight := IsoProjection.cell_center(Vector2i(1, 1)).distance_to(IsoProjection.cell_center(Vector2i(20, 1)))
	assert_true(r.length() > straight + 3.0, "the route is the long way round (%f vs %f)" % [r.length(), straight])
	assert_vec_near(r.spawn(), IsoProjection.cell_center(Vector2i(1, 1)), 1e-4)
	assert_vec_near(r.core(), IsoProjection.cell_center(Vector2i(20, 1)), 1e-4)
	_release()


func test_flow_battles_are_deterministic() -> void:
	var m := _mission(_map(WALLED_ROWS), Vector2i(1, 1), Vector2i(20, 1), 8)
	var a := _battle(m, 7)
	var c := _battle(m, 7)
	for i in 60 * 40:
		a.step(DT)
		c.step(DT)
	assert_eq(a.enemies.size(), c.enemies.size())
	for i in a.enemies.size():
		assert_eq(a.enemies[i].ground_pos, c.enemies[i].ground_pos)
	_release()


func test_an_enemy_without_a_field_still_follows_its_waypoints() -> void:
	var def := _get_db().enemy("shambler")
	var e := BattleEnemy.new()
	var wps: Array[Vector2] = [Vector2(5, 0.5)]
	e.setup(1, def, Vector2(0.5, 0.5), wps)
	e.advance(1.0, 0)
	assert_true(e.ground_pos.x > 0.5 and absf(e.ground_pos.y - 0.5) < 1e-6)
	e.free()


func test_an_enemy_with_a_field_steers_by_it_and_refreshes_every_few_ticks() -> void:
	var open := PackedByteArray()
	open.resize(20 * 3)
	open.fill(1)
	var field := FlowField.build(20, 3, open, Vector2i(0, 1))
	var def := _get_db().enemy("shambler")
	var e := BattleEnemy.new()
	e.setup(4, def, Vector2(10.5, 1.5), [] as Array[Vector2], field, Vector2.ZERO)
	var x0 := e.ground_pos.x
	e.advance(0.5, 0)
	assert_true(e.ground_pos.x < x0, "walked toward the goal on the left")
	# the heading is kept between refreshes: change the cached heading and see it used until the next refresh tick
	e._heading = Vector2(0, 1)
	var y0 := e.ground_pos.y
	e.advance(0.1, 1)  # (1 + 4) % 4 != 0: no refresh
	assert_true(e.ground_pos.y > y0, "kept its heading between refreshes")
	e.advance(0.1, 3)  # (3 + 4) % 4 != 0
	assert_true(e._heading == Vector2(0, 1))
	e.advance(0.1, 4)  # (4 + 4) % 4 == 0: refresh
	assert_true(e._heading.x < -0.9, "refreshed down the field again")
	e.free()


func test_an_enemy_never_enters_a_wall_even_with_a_lane_that_points_into_it() -> void:
	var rows := ["....", ".##.", "...."]
	var open := PackedByteArray([1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1])
	var field := FlowField.build(4, 3, open, Vector2i(3, 2))
	var def := _get_db().enemy("shambler")
	var e := BattleEnemy.new()
	e.setup(2, def, Vector2(0.5, 0.5), [] as Array[Vector2], field, Vector2(0.9, 0.9))
	for i in 600:
		e.advance(DT, i)
		assert_true(field.is_open(_cell_of(e.ground_pos)), "tick %d at %s" % [i, str(e.ground_pos)])
	assert_true(rows.size() == 3)
	e.free()


# --- the demo mission ---------------------------------------------------------------------------------------------

func test_the_flow_demo_mission_is_valid_and_reaches_the_core_from_both_spawns() -> void:
	var m := _get_db().mission("dev_flow_outskirts")
	assert_true(m != null)
	assert_eq(m.routing, MissionDefinition.Routing.FLOW)
	assert_eq(m.spawn_cells.size(), 2)
	assert_true(_get_db().is_valid(), "\n".join(_get_db().errors))
	var b := _battle(m)
	assert_eq(b._routes.size(), 2)
	for r in b._routes:
		assert_true(not r.is_empty() and r.length() > 20.0)
	_release()


# --- not getting stuck on a wall -----------------------------------------------------------------------------------

func _grid_field(rows: Array, goal: Vector2i) -> FlowField:
	var h := rows.size()
	var w := String(rows[0]).length()
	var open := PackedByteArray()
	open.resize(w * h)
	for y in h:
		for x in w:
			open[y * w + x] = 0 if String(rows[y])[x] == "#" else 1
	return FlowField.build(w, h, open, goal)


func test_a_lane_that_points_into_a_wall_does_not_trap_the_walker() -> void:
	# the walker stands just past the end of a wall; its lane offset reaches into the wall cells, where the open cells beyond
	# point straight along the corridor: the heading it would take leads into the wall with no sideways part to slide along
	var field := _grid_field([
		"..........",
		"..........",
		"#######...",
	], Vector2i(0, 1))
	var e := BattleEnemy.new()
	e.setup(3, _get_db().enemy("shambler"), Vector2(7.02, 2.19), [] as Array[Vector2], field, Vector2(-0.9, 0.0))
	for i in 60 * 40:
		e.advance(DT, i)
		assert_true(field.is_open(_cell_of(e.ground_pos)), "tick %d at %s" % [i, str(e.ground_pos)])
		if e.ground_pos.distance_to(Vector2(0.5, 1.5)) < 1.0:
			break
	assert_true(e.ground_pos.distance_to(Vector2(0.5, 1.5)) < 1.0, "it got to the goal instead of standing at the wall (ended at %s)" % str(e.ground_pos))
	e.free()


func test_every_lane_reaches_the_goal_round_a_block() -> void:
	var field := _grid_field([
		"............",
		"............",
		"..########..",
		"..########..",
		"............",
		"............",
	], Vector2i(11, 5))
	var lanes: Array[Vector2] = []
	for dx in [-0.9, -0.45, 0.0, 0.45, 0.9]:
		for dy in [-0.9, -0.45, 0.0, 0.45, 0.9]:
			lanes.append(Vector2(dx, dy))
	for lane in lanes:
		var e := BattleEnemy.new()
		e.setup(5, _get_db().enemy("shambler"), Vector2(0.6, 0.6), [] as Array[Vector2], field, lane)
		var arrived := false
		for i in 60 * 80:
			e.advance(DT, i)
			if e.ground_pos.distance_to(Vector2(11.5, 5.5)) < 1.2:
				arrived = true
				break
		assert_true(arrived, "lane %s ended at %s" % [str(lane), str(e.ground_pos)])
		e.free()


func _wall_field() -> FlowField:
	return _grid_field([
		"..........",
		"..........",
		"#######...",
	], Vector2i(0, 1))


func test_a_lane_into_a_wall_is_dropped_when_looking_up_the_heading() -> void:
	var field := _wall_field()
	var e := BattleEnemy.new()
	e.setup(3, _get_db().enemy("shambler"), Vector2(7.02, 2.19), [] as Array[Vector2], field, Vector2(-0.9, 0.0))
	var lane_point := e.ground_pos + Vector2(-0.9, 0.0)
	assert_true(not field.open_at(lane_point), "the lane point is inside the wall")
	assert_vec_near(e._look_up_heading(), field.direction_at(e.ground_pos), 1e-6, "so the heading is the one at its own position")
	assert_true(field.direction_at(lane_point).distance_to(field.direction_at(e.ground_pos)) > 0.05, "which differs from the one at the lane point")
	e.free()


func test_a_lane_on_open_ground_is_used() -> void:
	var open := PackedByteArray()
	open.resize(30 * 30)
	open.fill(1)
	var field := FlowField.build(30, 30, open, Vector2i(0, 0))
	var plain := BattleEnemy.new()
	plain.setup(1, _get_db().enemy("shambler"), Vector2(12.5, 12.5), [] as Array[Vector2], field, Vector2.ZERO)
	var laned := BattleEnemy.new()
	laned.setup(2, _get_db().enemy("shambler"), Vector2(12.5, 12.5), [] as Array[Vector2], field, Vector2(0.9, -0.5))
	assert_true(plain._look_up_heading().distance_to(laned._look_up_heading()) > 0.01, "the lane changes where it samples")
	plain.free()
	laned.free()


func test_a_blocked_step_is_retried_with_the_heading_of_the_cell() -> void:
	var field := _wall_field()
	var e := BattleEnemy.new()
	e.setup(3, _get_db().enemy("shambler"), Vector2(7.02, 2.19), [] as Array[Vector2], field, Vector2.ZERO)
	e._heading = Vector2(-1, 0)  # straight into the wall
	var start := e.ground_pos
	e.advance(0.1, 0)  # (0 + 3) % 4 != 0: no refresh is due on this tick, so only the blocked-step rule can help
	assert_true(e.ground_pos.distance_to(start) > 0.05, "it moved off instead of pushing at the wall (%s)" % str(e.ground_pos))
	assert_true(e._heading != Vector2(-1, 0), "and re-aimed")
	e.free()
