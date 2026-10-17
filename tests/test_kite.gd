extends TestCase
## The kiting army (docs/specs/field-command.md, F2): the route geometry, the one-pass enemy scan, the pure brain, and
## what the shipped riflemen, RPG soldiers, tanks and scouts do in a real battle.

const DT: float = 1.0 / 60.0
const MAP_W: float = 40.0
const MAP_H: float = 40.0

var _db: ContentDb
var _made: Array[Node] = []


func _get_db() -> ContentDb:
	if _db == null:
		_db = ContentDb.load_from()
	return _db


func _release() -> void:
	for n in _made:
		n.free()
	_made.clear()


# --- the route ------------------------------------------------------------------------------------------------------

func _route() -> Route:
	# spawn at (30, 0), corner at (30, 20), core at (10, 20): 20 tiles down, then 20 tiles across
	return Route.from_points(PackedVector2Array([Vector2(30, 0), Vector2(30, 20), Vector2(10, 20)]))


func test_route_length_and_ends() -> void:
	var r := _route()
	assert_near(r.length(), 40.0, 1e-4)
	assert_eq(r.spawn(), Vector2(30, 0))
	assert_eq(r.core(), Vector2(10, 20))


func test_route_points_are_measured_from_the_core() -> void:
	var r := _route()
	assert_vec_near(r.point_at(0.0), Vector2(10, 20), 1e-4)
	assert_vec_near(r.point_at(10.0), Vector2(20, 20), 1e-4)
	assert_vec_near(r.point_at(20.0), Vector2(30, 20), 1e-4)
	assert_vec_near(r.point_at(30.0), Vector2(30, 10), 1e-4)
	assert_vec_near(r.point_at(99.0), Vector2(30, 0), 1e-4, "clamped to the spawn")
	assert_vec_near(r.point_at(-5.0), Vector2(10, 20), 1e-4, "clamped to the core")


func test_route_progress_and_distance() -> void:
	var r := _route()
	assert_near(r.progress_of(Vector2(20, 20)), 10.0, 1e-4)
	assert_near(r.progress_of(Vector2(30, 10)), 30.0, 1e-4)
	assert_near(r.progress_of(Vector2(25, 23)), 15.0, 1e-4, "off the route: the nearest point counts")
	assert_near(r.distance_to(Vector2(25, 23)), 3.0, 1e-4)
	assert_near(r.distance_to(Vector2(30, 5)), 0.0, 1e-4)


func test_route_direction_back_runs_toward_the_core() -> void:
	var r := _route()
	assert_vec_near(r.dir_to_core(Vector2(30, 5)), Vector2(0, 1), 1e-3, "on the first leg back is down")
	assert_vec_near(r.dir_to_core(Vector2(20, 20)), Vector2(-1, 0), 1e-3, "on the second leg back is left")


func test_degenerate_routes_do_not_crash() -> void:
	var one := Route.from_points(PackedVector2Array([Vector2(1, 1)]))
	assert_true(one.is_empty())
	assert_near(one.progress_of(Vector2(5, 5)), 0.0)
	assert_eq(one.dir_to_core(Vector2(5, 5)), Vector2.ZERO)
	var dup := Route.from_points(PackedVector2Array([Vector2(1, 1), Vector2(1, 1), Vector2(4, 1)]))
	assert_near(dup.length(), 3.0, 1e-4, "repeated points are dropped")
	assert_true(Route.new().is_empty())


# --- the scan -------------------------------------------------------------------------------------------------------

func _enemy(id: String, pos: Vector2, uid: int) -> BattleEnemy:
	var e := BattleEnemy.new()
	e.uid = uid
	e.def = _get_db().enemy(id)
	e.ground_pos = pos
	_made.append(e)
	return e


func _scan(unit: Vector2, speed: float, enemies: Array, spawns: PackedVector2Array = PackedVector2Array([Vector2(30, 0)])) -> KiteScan:
	var index := EnemyIndex.new()
	index.begin(MAP_W, MAP_H)
	for e in enemies:
		index.add(e, (e as BattleEnemy).ground_pos)
	var out := KiteScan.new()
	index.scan_kite(unit, 16.0, speed, UnitBrain.KITE_MARGIN, UnitBrain.KITE_REACT_S, 6.0, spawns, out)
	return out


func test_scan_with_nobody_in_sight_is_empty() -> void:
	var s := _scan(Vector2(10, 10), 3.0, [_enemy("shambler", Vector2(38, 38), 1)])
	assert_eq(s.visible, 0)
	assert_eq(s.danger_count, 0)
	assert_true(not s.has_upstream)
	assert_true(s.worst_slack == INF)
	_release()


func test_scan_marks_enemies_whose_danger_zone_holds_the_unit() -> void:
	var sham := _get_db().enemy("shambler")
	var zone := sham.attack_range + UnitBrain.KITE_MARGIN + sham.move_speed * UnitBrain.KITE_REACT_S
	var inside := _scan(Vector2(10, 10), 3.0, [_enemy("shambler", Vector2(10, 10) + Vector2(zone - 0.3, 0), 1)])
	assert_eq(inside.danger_count, 1)
	assert_true(inside.worst_slack < 0.0)
	assert_eq(inside.danger_slower, 1, "a shambler (1.2) is slower than a soldier (3.0)")
	var outside := _scan(Vector2(10, 10), 3.0, [_enemy("shambler", Vector2(10, 10) + Vector2(zone + 0.5, 0), 2)])
	assert_eq(outside.danger_count, 0)
	assert_near(outside.worst_slack, 0.5, 1e-3)
	_release()


func test_scan_knows_which_dangerous_enemies_are_faster() -> void:
	var run := _get_db().enemy("runner")
	var near := Vector2(10, 10) + Vector2(1.5, 0)
	var s := _scan(Vector2(10, 10), 2.0, [_enemy("runner", near, 1), _enemy("shambler", Vector2(10, 11.2), 2)])
	assert_eq(s.danger_count, 2)
	assert_eq(s.danger_slower, 1, "a runner (%.1f) outpaces a unit at speed 2.0, a shambler does not" % run.move_speed)
	_release()


func test_scan_sums_the_push_away_from_the_dangerous_ones() -> void:
	var s := _scan(Vector2(10, 10), 3.0, [_enemy("shambler", Vector2(11.5, 10), 1), _enemy("shambler", Vector2(10, 11.5), 2)])
	assert_true(s.away.x < 0.0 and s.away.y < 0.0, "away from enemies to the east and south")
	_release()


func test_scan_counts_the_crowd_and_picks_the_enemy_nearest_a_spawn() -> void:
	var list: Array = []
	for i in 6:
		list.append(_enemy("shambler", Vector2(10, 10) + Vector2(5.0 + float(i) * 0.1, 0), 10 + i))
	var far_up := _enemy("brute", Vector2(18, 4), 99)
	list.append(far_up)
	var s := _scan(Vector2(10, 10), 3.0, list)
	assert_eq(s.crowd, 6, "the six shamblers are within the crowd radius, the brute is not")
	assert_eq(s.visible, 7)
	assert_true(s.has_upstream)
	assert_vec_near(s.upstream_pos, Vector2(18, 4), 1e-4, "the one nearest the spawn at (30, 0)")
	assert_near(s.upstream_reach, _get_db().enemy("brute").attack_range)
	_release()


func test_scan_ties_go_to_the_lowest_uid_whatever_the_insertion_order() -> void:
	var a := _enemy("shambler", Vector2(20, 5), 7)
	var b := _enemy("shambler", Vector2(20, 5), 3)
	var one := _scan(Vector2(10, 10), 3.0, [a, b])
	var two := _scan(Vector2(10, 10), 3.0, [b, a])
	assert_eq(one.upstream_pos, two.upstream_pos)
	assert_eq(one.visible, two.visible)
	_release()


# --- the brain -----------------------------------------------------------------------------------------------------

func _facts(pos: Vector2, scan: KiteScan, in_range: bool = false) -> UnitBrain.KiteFacts:
	var f := UnitBrain.KiteFacts.new()
	f.pos = pos
	f.speed = 3.0
	f.weapon_range = 8.0
	f.core = Vector2(10, 20)
	f.route = _route()
	f.post_s = 28.0
	f.in_range = in_range
	f.scan = scan
	return f


func _danger(away: Vector2, slack: float = -1.0, slower: int = 1, count: int = 1) -> KiteScan:
	var s := KiteScan.new()
	s.danger_count = count
	s.danger_slower = slower
	s.away = away
	s.worst_slack = slack
	s.visible = count
	return s


func test_with_nothing_in_sight_it_scouts_to_its_post_and_waits_there() -> void:
	var d := UnitBrain.kite(_facts(Vector2(12, 20), KiteScan.new()))
	assert_eq(d.action, UnitBrain.Action.MOVE)
	assert_vec_near(d.dest, _route().point_at(28.0), 1e-3)
	var there := UnitBrain.kite(_facts(_route().point_at(28.0), KiteScan.new()))
	assert_eq(there.action, UnitBrain.Action.STAY)


func test_a_group_does_not_stack_on_one_spot_at_the_post() -> void:
	var seen: Dictionary = {}
	for side in [-1.8, -0.9, 0.0, 0.9, 1.8]:
		var f := _facts(Vector2(12, 20), KiteScan.new())
		f.post_side = side
		seen[str(UnitBrain.kite(f).dest)] = true
	assert_eq(seen.size(), 5)


func test_it_backs_off_when_a_slower_enemy_is_inside_its_zone() -> void:
	var pos := Vector2(30, 10)
	var d := UnitBrain.kite(_facts(pos, _danger(Vector2(0, 1), -1.0)))  # the enemy is above (smaller y): away is +y
	assert_eq(d.action, UnitBrain.Action.MOVE)
	assert_true(d.dest.distance_to(pos) >= UnitBrain.KITE_STEP_MIN and d.dest.distance_to(pos) <= UnitBrain.KITE_STEP_MAX + 1e-3)
	assert_true(d.dest.y > pos.y, "backs toward the core, away from the enemy")


func test_the_backward_step_is_just_long_enough() -> void:
	var pos := Vector2(30, 10)
	var small := UnitBrain.kite(_facts(pos, _danger(Vector2(0, 1), -0.1)))
	var big := UnitBrain.kite(_facts(pos, _danger(Vector2(0, 1), -2.5)))
	assert_true(small.dest.distance_to(pos) < big.dest.distance_to(pos), "a deeper intrusion takes a longer step")


func test_it_stands_and_fights_enemies_it_cannot_outrun() -> void:
	var d := UnitBrain.kite(_facts(Vector2(30, 10), _danger(Vector2(0, 1), -1.0, 0, 2)))
	assert_eq(d.action, UnitBrain.Action.STAY)
	var mixed := UnitBrain.kite(_facts(Vector2(30, 10), _danger(Vector2(0, 1), -1.0, 1, 2)))
	assert_eq(mixed.action, UnitBrain.Action.STAY, "one fast enemy among the slow ones is enough to hold")


func test_it_does_not_back_off_into_the_core() -> void:
	var near_core := Vector2(10, 20) + Vector2(1.5, 0)
	var d := UnitBrain.kite(_facts(near_core, _danger(Vector2(-1, 0), -1.0)))
	assert_eq(d.action, UnitBrain.Action.STAY, "nowhere left to go: it fights at the core")


func test_a_crowd_bigger_than_its_courage_sends_it_home_in_a_long_step() -> void:
	var s := _danger(Vector2(0, 1), -1.0)
	s.crowd = 30
	var pos := Vector2(30, 6)
	var d := UnitBrain.kite(_facts(pos, s))
	assert_eq(d.action, UnitBrain.Action.MOVE)
	assert_true(d.dest.distance_to(pos) > UnitBrain.KITE_STEP_MAX + 0.5, "the fall-back step is longer than a kiting step")
	var brave := _facts(pos, s)
	brave.courage = 50
	assert_true(UnitBrain.kite(brave).dest.distance_to(pos) <= UnitBrain.KITE_STEP_MAX + 1e-3, "enough courage and it only kites")


func test_safe_with_a_target_in_range_it_stands_and_fires() -> void:
	assert_eq(UnitBrain.kite(_facts(Vector2(25, 12), KiteScan.new(), true)).action, UnitBrain.Action.STAY)


func test_it_walks_up_to_the_edge_of_range_of_the_enemy_nearest_the_spawn() -> void:
	var s := KiteScan.new()
	s.visible = 3
	s.has_upstream = true
	s.upstream_pos = Vector2(30, 2)
	s.upstream_reach = 0.8
	s.upstream_speed = 1.2
	var d := UnitBrain.kite(_facts(Vector2(30, 16), s))
	assert_eq(d.action, UnitBrain.Action.MOVE)
	assert_near(d.dest.distance_to(Vector2(30, 2)), 8.0 * UnitBrain.RANGE_MARGIN, 1e-3)


func test_it_will_not_chase_an_enemy_it_could_only_hit_from_inside_its_reach() -> void:
	var s := KiteScan.new()
	s.has_upstream = true
	s.visible = 1
	s.upstream_pos = Vector2(30, 2)
	s.upstream_reach = 7.5  # a long-armed enemy: its zone is wider than this unit's weapon range
	s.upstream_speed = 1.0
	assert_eq(UnitBrain.kite(_facts(Vector2(30, 16), s)).action, UnitBrain.Action.STAY)


func test_a_blocked_step_is_tried_at_other_angles_and_given_up_when_all_are_blocked() -> void:
	var f := _facts(Vector2(30, 10), _danger(Vector2(0, 1), -1.0))
	var calls := [0]
	f.clear = func(_a: Vector2, _b: Vector2) -> bool:
		calls[0] += 1
		return calls[0] > 2  # the first two angles are blocked
	var d := UnitBrain.kite(f)
	assert_eq(d.action, UnitBrain.Action.MOVE)
	assert_true(calls[0] >= 3)
	var walled := _facts(Vector2(30, 10), _danger(Vector2(0, 1), -1.0))
	walled.clear = func(_a: Vector2, _b: Vector2) -> bool: return false
	assert_eq(UnitBrain.kite(walled).action, UnitBrain.Action.STAY)


func test_two_friends_on_top_of_each_other_step_apart() -> void:
	var f := _facts(Vector2(25, 12), KiteScan.new(), true)
	f.nearest_friend = Vector2(25.2, 12)
	var d := UnitBrain.kite(f)
	assert_eq(d.action, UnitBrain.Action.MOVE)
	assert_true(d.dest.x < 25.0, "away from the friend")
	f.nearest_friend = Vector2(27, 12)
	assert_eq(UnitBrain.kite(f).action, UnitBrain.Action.STAY, "a friend at a normal distance is no problem")


func test_the_brain_is_deterministic() -> void:
	var a := UnitBrain.kite(_facts(Vector2(30, 10), _danger(Vector2(0.3, 1), -1.4)))
	var b := UnitBrain.kite(_facts(Vector2(30, 10), _danger(Vector2(0.3, 1), -1.4)))
	assert_eq(a.dest, b.dest)
	assert_eq(a.action, b.action)


# --- the definitions ---------------------------------------------------------------------------------------------------

func test_the_shipped_mobile_units_kite_and_the_vehicles_are_fast() -> void:
	var db := _get_db()
	assert_true(db.is_valid(), "content errors: %s" % ", ".join(db.errors))
	for id in ["rifle_soldier", "rpg_soldier", "tank", "scout"]:
		assert_eq(db.unit(id).effective_behavior(), UnitBrain.Behavior.KITE, id)
	assert_true(db.unit("tank").move_speed >= 3.5, "a tank is mobile")
	assert_true(db.unit("tank").move_speed > db.unit("rifle_soldier").move_speed, "and quicker than a soldier on foot")
	assert_true(db.unit("scout").move_speed > db.unit("tank").move_speed, "a scout jeep is the quickest")
	assert_true(db.unit("tank").danger_margin < db.unit("rifle_soldier").danger_margin, "armour makes the tank bolder")
	assert_eq(db.unit("mg_nest").effective_behavior(), UnitBrain.Behavior.HOLD, "fixed things still hold")


func test_kite_settings_are_validated() -> void:
	var u: UnitDefinition = _get_db().unit("rifle_soldier").duplicate()
	u.vision = 0.0
	assert_true(u.validate().size() > 0)
	u = _get_db().unit("rifle_soldier").duplicate()
	u.courage = 0
	assert_true(u.validate().size() > 0)
	u = _get_db().unit("rifle_soldier").duplicate()
	u.danger_margin = -1.0
	assert_true(u.validate().size() > 0)


# --- in a battle -----------------------------------------------------------------------------------------------------

const MISSION_ID := "m2_card_defense"


## The m2 mission with these start units, waves pushed far into the future (tests inject their own enemies).
func _battle(units: Array, seed_value: int = 1) -> BattleController:
	var m: MissionDefinition = _get_db().mission(MISSION_ID).duplicate()
	var arr: Array[StartUnit] = []
	for pair in units:
		var su := StartUnit.new()
		su.unit_id = pair[0]
		su.cell = pair[1]
		arr.append(su)
	m.start_units = arr
	var waves: Array[WaveEntry] = []
	for w in m.waves:
		var late: WaveEntry = w.duplicate()
		late.start_s += 600.0
		waves.append(late)
	m.waves = waves
	m.duration_s = 2000.0
	var b := BattleController.new()
	b.auto_step = false
	b.setup(_get_db(), m, seed_value)
	_made.append(b)
	return b


func _run(b: BattleController, seconds: float) -> void:
	for i in int(round(seconds / DT)):
		b.step(DT)


func _inject(b: BattleController, id: String, pos: Vector2) -> BattleEnemy:
	var w: WaveEntry = b.mission.waves[0].duplicate()
	w.enemy_id = id
	b._spawn_enemy(w)
	var e: BattleEnemy = b.enemies.back()
	e.ground_pos = pos
	return e


func test_a_rifleman_scouts_up_the_route_toward_the_spawn_when_nothing_is_in_sight() -> void:
	var b := _battle([["rifle_soldier", Vector2i(5, 19)]])
	var u: BattleUnit = b.units[0]
	var start := u.ground_pos
	_run(b, 25.0)
	var route := b._route_for(u.ground_pos)
	var post := route.point_at(maxf(route.length() - u.def.scout_post, 0.0))
	assert_true(u.ground_pos.distance_to(start) > 8.0, "it walked a long way from where it was placed")
	assert_true(u.ground_pos.distance_to(post) < 2.5, "and stands near its post %.1f tiles from the spawn" % u.def.scout_post)
	_release()


func test_a_scouting_tank_gets_to_its_post_much_sooner_than_a_rifleman() -> void:
	var tank_b := _battle([["tank", Vector2i(5, 19)]])
	var rifle_b := _battle([["rifle_soldier", Vector2i(5, 19)]])
	_run(tank_b, 4.0)
	_run(rifle_b, 4.0)
	var tank_walked: float = tank_b.units[0].ground_pos.distance_to(IsoProjection.cell_center(Vector2i(5, 19)))
	var rifle_walked: float = rifle_b.units[0].ground_pos.distance_to(IsoProjection.cell_center(Vector2i(5, 19)))
	assert_true(tank_walked > rifle_walked, "the tank is quicker (%.1f against %.1f tiles)" % [tank_walked, rifle_walked])
	assert_true(tank_walked > 12.0, "four seconds at tank speed is a long way (%.1f)" % tank_walked)
	_release()


func test_a_rifleman_kites_a_slow_horde_without_being_touched() -> void:
	var b := _battle([["rifle_soldier", Vector2i(12, 14)]])
	var u: BattleUnit = b.units[0]
	var route := b._route_for(u.ground_pos)
	var at := route.point_at(18.0)
	for i in 5:
		_inject(b, "shambler", at + Vector2(float(i) * 0.6, -float(i) * 0.6) - Vector2(2.0, 2.0))
	var closest := INF
	var t := 0.0
	while t < 40.0 and not b.enemies.is_empty():
		b.step(DT)
		t += DT
		for e in b.enemies:
			if e.is_alive():
				closest = minf(closest, e.ground_pos.distance_to(u.ground_pos))
	assert_true(b.stats["kills"] >= 4, "it killed the horde (%d kills)" % b.stats["kills"])
	assert_near(u.health.hp, u.health.max_hp, 1e-6, "and took no damage (closest approach %.2f tiles)" % closest)
	_release()


func test_the_kiting_rifleman_beats_the_old_standing_guard_against_the_same_horde() -> void:
	var kite_hp := 0.0
	var guard_hp := 0.0
	for pass_no in 2:
		var b := _battle([["rifle_soldier", Vector2i(11, 11)]], 3)  # right on the enemy route
		var u: BattleUnit = b.units[0]
		if pass_no == 1:
			u.def = u.def.duplicate()
			u.def.behavior = UnitBrain.Behavior.GUARD
		var route := b._route_for(u.ground_pos)
		for i in 16:
			_inject(b, "shambler", route.point_at(20.0 + float(i / 6) * 1.2) + Vector2(float(i % 6) * 0.5, 0.0))
		_run(b, 40.0)
		var hp := u.health.hp if is_instance_valid(u) and u.is_alive() else 0.0
		if pass_no == 0:
			kite_hp = hp
		else:
			guard_hp = hp
	assert_true(kite_hp > guard_hp, "kiting keeps more health (%.0f) than standing guard (%.0f)" % [kite_hp, guard_hp])
	_release()


func test_a_unit_that_cannot_outrun_the_enemy_turns_and_fights() -> void:
	var b := _battle([["rpg_soldier", Vector2i(12, 14)]])
	var u: BattleUnit = b.units[0]
	var pos := u.ground_pos
	_inject(b, "runner", pos + Vector2(1.8, 0.0))  # faster than the RPG soldier (2.6 against 2.6 * 0.95 threshold)
	b.step(DT)
	assert_true(not u.is_moving() or u.ground_pos.distance_to(pos) < 0.2, "it does not run from something as fast as itself")
	_release()


func test_a_battle_with_kiting_units_is_deterministic() -> void:
	var digests: Array[String] = []
	for k in 2:
		var b := _battle([["rifle_soldier", Vector2i(10, 15)], ["tank", Vector2i(8, 17)]], 7)
		var route := b._route_for(b.units[0].ground_pos)
		for i in 6:
			_inject(b, "shambler", route.point_at(22.0) + Vector2(float(i) * 0.7, 0.0))
		_run(b, 20.0)
		var parts: Array[String] = []
		for u in b.units:
			parts.append("%.4f,%.4f,%.2f" % [u.ground_pos.x, u.ground_pos.y, u.health.hp])
		parts.append(str(b.stats["kills"]))
		digests.append("|".join(parts))
		_release()
	assert_eq(digests[0], digests[1])


func test_units_in_a_group_do_not_end_up_on_the_same_spot() -> void:
	var b := _battle([["rifle_soldier", Vector2i(5, 19)], ["rifle_soldier", Vector2i(5, 20)], ["rifle_soldier", Vector2i(6, 19)], ["rifle_soldier", Vector2i(6, 20)]])
	_run(b, 30.0)
	for i in b.units.size():
		for j in range(i + 1, b.units.size()):
			assert_true(b.units[i].ground_pos.distance_to(b.units[j].ground_pos) > 0.5, "units %d and %d are not stacked" % [i, j])
	_release()

