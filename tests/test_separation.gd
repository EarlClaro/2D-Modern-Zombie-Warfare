extends TestCase
## Separation (M3.11 part 3, ADR-012): overlapping enemies push each other apart; the cost per query is fixed. The pure class
## first, then a flow battle with a crowd.

const DT: float = 1.0 / 60.0

var _db: ContentDb
var _made: Array[BattleController] = []


func _get_db() -> ContentDb:
	if _db == null:
		_db = ContentDb.load_from()
	return _db


func _sep(points: Array, radius: float = 0.3, map_w: int = 20, map_h: int = 20) -> Separation:
	var pos := PackedVector2Array()
	var rad := PackedFloat32Array()
	for p in points:
		pos.append(p)
		rad.append(radius)
	var s := Separation.new()
	s.rebuild(map_w, map_h, pos, rad)
	return s


# --- the pure class -------------------------------------------------------------------------------------------------

func test_two_overlapping_bodies_are_pushed_apart() -> void:
	var s := _sep([Vector2(5.0, 5.0), Vector2(5.3, 5.0)])
	var a := s.push(0, Vector2(5.0, 5.0), 0.3)
	var b := s.push(1, Vector2(5.3, 5.0), 0.3)
	assert_true(a.x < 0.0 and absf(a.y) < 1e-6, "the left one is pushed left: %s" % str(a))
	assert_true(b.x > 0.0 and absf(b.y) < 1e-6, "the right one is pushed right: %s" % str(b))
	assert_near(a.x, -b.x, 1e-6, "equal and opposite")
	assert_near(a.length(), (0.6 - 0.3) / 0.6, 1e-5, "weighted by the overlap depth")


func test_bodies_that_do_not_touch_do_not_push() -> void:
	var s := _sep([Vector2(5.0, 5.0), Vector2(5.7, 5.0)])
	assert_eq(s.push(0, Vector2(5.0, 5.0), 0.3), Vector2.ZERO, "0.7 apart with radii summing to 0.6")
	var s2 := _sep([Vector2(5.0, 5.0), Vector2(5.61, 5.0)])
	assert_eq(s2.push(0, Vector2(5.0, 5.0), 0.3), Vector2.ZERO, "just clear of touching")


func test_the_radius_of_each_body_counts() -> void:
	var pos := PackedVector2Array([Vector2(5.0, 5.0), Vector2(5.65, 5.0)])
	var rad := PackedFloat32Array([0.3, 0.45])
	var s := Separation.new()
	s.rebuild(20, 20, pos, rad)
	assert_true(s.push(0, Vector2(5.0, 5.0), 0.3).x < 0.0, "0.65 apart overlaps radii 0.3 + 0.45 (0.75) but not two of 0.3")
	var small := _sep([Vector2(5.0, 5.0), Vector2(5.65, 5.0)])
	assert_eq(small.push(0, Vector2(5.0, 5.0), 0.3), Vector2.ZERO, "while two small bodies 0.65 apart are clear")


func test_a_body_is_not_pushed_by_itself_or_by_a_body_not_in_the_snapshot() -> void:
	var s := _sep([Vector2(5.0, 5.0)])
	assert_eq(s.push(0, Vector2(5.0, 5.0), 0.3), Vector2.ZERO)
	assert_eq(s.push(-1, Vector2(5.0, 5.0), 0.3), Vector2.ZERO, "a body that is not in the snapshot gets no push")
	assert_eq(s.push(7, Vector2(5.0, 5.0), 0.3), Vector2.ZERO, "nor an index past the end")


func test_two_bodies_at_exactly_the_same_spot_are_split_by_index() -> void:
	var s := _sep([Vector2(5.5, 5.5), Vector2(5.5, 5.5)])
	var a := s.push(0, Vector2(5.5, 5.5), 0.3)
	var b := s.push(1, Vector2(5.5, 5.5), 0.3)
	assert_true(a.length() > 0.5 and b.length() > 0.5)
	assert_near(a.x, -b.x, 1e-6)
	assert_true(a.x != b.x, "they go opposite ways")


func test_bodies_in_neighbouring_cells_still_push() -> void:
	var s := _sep([Vector2(4.95, 5.0), Vector2(5.05, 5.0)])  # a cell border between them
	assert_true(s.push(0, Vector2(4.95, 5.0), 0.3).x < 0.0)
	assert_true(s.push(1, Vector2(5.05, 5.0), 0.3).x > 0.0)


func test_bodies_in_the_cell_above_and_below_push_too() -> void:
	var s := _sep([Vector2(5.5, 4.95), Vector2(5.5, 5.05)])  # a cell border in y
	assert_true(s.push(0, Vector2(5.5, 4.95), 0.3).y < 0.0)
	assert_true(s.push(1, Vector2(5.5, 5.05), 0.3).y > 0.0)


func test_a_crowd_pushes_from_all_sides_and_the_total_is_clamped() -> void:
	var pts: Array = [Vector2(5.5, 5.5)]
	for k in 8:
		var a := TAU * float(k) / 8.0
		pts.append(Vector2(5.5, 5.5) + Vector2(cos(a), sin(a)) * 0.1)
	var s := _sep(pts)
	var p := s.push(0, Vector2(5.5, 5.5), 0.3)
	assert_true(p.length() <= Separation.MAX_PUSH + 1e-6, "clamped: %f" % p.length())
	assert_true(p.length() < 0.2, "a ring all round cancels out: %s" % str(p))
	var one_side: Array = [Vector2(5.5, 5.5)]
	for k in 8:
		one_side.append(Vector2(5.55, 5.5))
	var t := _sep(one_side)
	assert_near(t.push(0, Vector2(5.5, 5.5), 0.3).length(), Separation.MAX_PUSH, 1e-6, "eight bodies on one side push as hard as the clamp allows")


func test_only_a_fixed_number_of_neighbours_are_looked_at() -> void:
	var pts: Array = [Vector2(5.5, 5.5)]
	for k in 30:
		pts.append(Vector2(5.55 + 0.001 * k, 5.5))  # thirty overlapping bodies on one side
	var s := _sep(pts)
	var one := s.push(0, Vector2(5.5, 5.5), 0.3)
	var few: Array = [Vector2(5.5, 5.5)]
	for k in Separation.MAX_NEIGHBOURS:
		few.append(Vector2(5.55 + 0.001 * k, 5.5))
	var capped := _sep(few).push(0, Vector2(5.5, 5.5), 0.3)
	assert_near(one.length(), capped.length(), 1e-6, "30 neighbours give what 8 give")


func test_the_neighbour_cap_limits_the_sum_below_the_clamp() -> void:
	# each neighbour overlaps by a twelfth, so eight of them push 8/12 and thirty would push 30/12 before the clamp
	var pts: Array = [Vector2(5.5, 5.5)]
	for k in 30:
		pts.append(Vector2(6.05, 5.5))
	var s := _sep(pts)
	var p := s.push(0, Vector2(5.5, 5.5), 0.3)
	assert_near(p.length(), float(Separation.MAX_NEIGHBOURS) * (0.05 / 0.6), 1e-4, "only the first 8 neighbours count")


func test_a_new_snapshot_forgets_the_old_one() -> void:
	var s := _sep([Vector2(5.0, 5.0), Vector2(5.2, 5.0)])
	assert_true(s.push(0, Vector2(5.0, 5.0), 0.3).length() > 0.0)
	s.rebuild(20, 20, PackedVector2Array([Vector2(5.0, 5.0), Vector2(9.0, 9.0)]), PackedFloat32Array([0.3, 0.3]))
	assert_eq(s.push(0, Vector2(5.0, 5.0), 0.3), Vector2.ZERO)
	assert_eq(s.size(), 2)


func test_positions_off_the_map_are_clamped_not_a_crash() -> void:
	var s := _sep([Vector2(-3.0, -3.0), Vector2(-3.0, -2.9), Vector2(99.0, 99.0)])
	assert_true(s.push(0, Vector2(-3.0, -3.0), 0.3).length() > 0.0, "two bodies in the corner cell, off the map")
	assert_eq(s.push(2, Vector2(99.0, 99.0), 0.3), Vector2.ZERO)


func test_the_push_is_deterministic() -> void:
	var pts: Array = []
	for k in 40:
		pts.append(Vector2(5.0 + 0.07 * float(k % 7), 5.0 + 0.05 * float(k / 7)))
	var a := _sep(pts)
	var b := _sep(pts)
	for k in pts.size():
		assert_eq(a.push(k, pts[k], 0.3), b.push(k, pts[k], 0.3))


# --- in a battle ---------------------------------------------------------------------------------------------------

func _mission(separation: bool, count: int, interval_s: float = 0.125) -> MissionDefinition:
	var m: MissionDefinition = _get_db().mission("dev_flow_outskirts").duplicate()
	m.separation = separation
	var w := WaveEntry.new()
	w.start_s = 0.0
	w.enemy_id = "shambler"
	w.count = count
	w.interval_s = interval_s
	m.waves = [w] as Array[WaveEntry]
	m.start_units = [] as Array[StartUnit]
	m.core_health = 1.0e9
	m.duration_s = 300.0
	return m


func _battle(m: MissionDefinition) -> BattleController:
	var b := BattleController.new()
	b.auto_step = false
	b.setup(_get_db(), m, 3)
	_made.append(b)
	return b


func _release() -> void:
	for b in _made:
		b.free()
	_made.clear()


## The share of living enemies that overlap another by more than half their combined radii.
func _overlap_share(b: BattleController) -> float:
	var near := 0
	var alive := 0
	for i in b.enemies.size():
		var e: BattleEnemy = b.enemies[i]
		if not e.is_alive():
			continue
		alive += 1
		for j in b.enemies.size():
			if i == j or not b.enemies[j].is_alive():
				continue
			var o: BattleEnemy = b.enemies[j]
			if e.ground_pos.distance_to(o.ground_pos) < 0.5 * (e.def.footprint_radius + o.def.footprint_radius):
				near += 1
				break
	return float(near) / maxf(float(alive), 1.0)


func test_a_flow_horde_spreads_out_with_separation_and_stacks_without() -> void:
	var with_sep := _battle(_mission(true, 80))  # 8 a second, like the shipped waves
	var without := _battle(_mission(false, 80))
	assert_true(with_sep._sep != null and without._sep == null)
	for i in 60 * 12:
		with_sep.step(DT)
		without.step(DT)
	var a := _overlap_share(with_sep)
	var c := _overlap_share(without)
	assert_true(c > 0.3, "without it a fast-spawning horde piles up (%f)" % c)
	assert_true(a < c * 0.5, "with it far fewer overlap (%f against %f)" % [a, c])
	_release()


func test_separation_never_pushes_an_enemy_into_a_wall() -> void:
	var b := _battle(_mission(true, 120))
	for i in 60 * 30:
		b.step(DT)
		for e in b.enemies:
			if e.is_alive():
				assert_true(b._flow.open_at(e.ground_pos), "enemy %d on closed ground at %s (tick %d)" % [e.uid, str(e.ground_pos), i])
	_release()


func test_separated_battles_are_deterministic() -> void:
	var a := _battle(_mission(true, 60))
	var c := _battle(_mission(true, 60))
	for i in 60 * 10:
		a.step(DT)
		c.step(DT)
	assert_eq(a.enemies.size(), c.enemies.size())
	for i in a.enemies.size():
		assert_eq(a.enemies[i].ground_pos, c.enemies[i].ground_pos)
	_release()


func test_waypoint_missions_have_no_separation() -> void:
	var b := BattleController.new()
	b.auto_step = false
	b.setup(_get_db(), _get_db().mission("m1_hold_the_crossing"), 1)
	assert_true(b._sep == null)
	b.free()


func test_a_restart_into_a_waypoint_mission_drops_the_separation() -> void:
	var b := _battle(_mission(true, 10))
	assert_true(b._sep != null)
	b.setup(_get_db(), _get_db().mission("m1_hold_the_crossing"), 1)
	assert_true(b._sep == null)
	_release()


func test_pushes_are_refreshed_on_the_steering_schedule() -> void:
	var b := _battle(_mission(true, 60))
	for i in 60 * 6:
		b.step(DT)
	var pushed := 0
	for e in b.enemies:
		if e.push != Vector2.ZERO:
			pushed += 1
	assert_true(pushed > 5, "a crowd has been pushed (%d)" % pushed)
	_release()


func test_pushes_are_asked_for_on_the_stagger_not_every_tick() -> void:
	var b := _battle(_mission(true, 60))
	var ticks := 60 * 6
	for i in ticks:
		b.step(DT)
	var bodies: int = b.stats["spawned"]
	assert_true(b._sep.queries > 0)
	assert_true(b._sep.queries <= bodies * ticks / BattleEnemy.STEER_EVERY + bodies, "%d queries for %d bodies over %d ticks" % [b._sep.queries, bodies, ticks])
	_release()


func test_the_snapshot_records_each_enemys_own_radius() -> void:
	var m := _mission(true, 6)
	m.waves[0].enemy_id = "brute"
	var b := _battle(m)
	for i in 60 * 3:
		b.step(DT)
	var radius := _get_db().enemy("brute").footprint_radius
	assert_true(radius != _get_db().enemy("shambler").footprint_radius, "a brute is not the size of a shambler")
	assert_true(b._sep.size() > 0)
	for k in b._sep.size():
		assert_near(b._sep._rad[k], radius, 1e-6)
	_release()


func test_a_retried_step_still_carries_the_push() -> void:
	var rows := ["..........", "..........", "#######..."]
	var open := PackedByteArray()
	open.resize(30)
	for y in 3:
		for x in 10:
			open[y * 10 + x] = 0 if String(rows[y])[x] == "#" else 1
	var field := FlowField.build(10, 3, open, Vector2i(0, 1))
	var def := _get_db().enemy("shambler")
	var e := BattleEnemy.new()
	e.setup(3, def, Vector2(7.02, 2.19), [] as Array[Vector2], field, Vector2.ZERO)
	e._heading = Vector2(-1, 0)  # into the wall
	e.push = Vector2(-5.0, -0.1)  # and the push leans into it too: the first step is almost fully blocked
	var y0 := e.ground_pos.y
	var h := field.direction_at(Vector2(7.5, 2.5))  # what the retry aims with
	e.advance(0.1, 0)
	var want := y0 + (h.y * def.move_speed + e.push.y) * 0.1
	assert_near(e.ground_pos.y, want, 2e-3, "the retry adds the push to the new heading")
	e.free()
