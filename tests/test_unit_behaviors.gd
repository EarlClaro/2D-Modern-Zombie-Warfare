extends TestCase
## Units act on their own inside a real battle (ADR-013): no orders exist, the brain moves them.

const DT: float = 1.0 / 60.0
const MISSION_ID := "m2_card_defense"
const StartUnitRes := preload("res://scripts/missions/start_unit.gd")
const SOLDIER_CELL := Vector2i(7, 19)  # grass, a few tiles from the core

var _db: ContentDb
var _made: Array[BattleController] = []


func _get_db() -> ContentDb:
	if _db == null:
		_db = ContentDb.load_from()
	return _db


func _release() -> void:
	for b in _made:
		b.free()
	_made.clear()


## The m2 mission with these start units and no waves in the first 60 s (tests inject their own enemies).
func _battle(units: Array, seed_value: int = 1) -> BattleController:
	var m: MissionDefinition = _get_db().mission(MISSION_ID).duplicate()
	var arr: Array[StartUnit] = []
	for pair in units:
		var su := StartUnitRes.new()
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


func _enemy(b: BattleController, pos: Vector2, hp: float = -1.0) -> BattleEnemy:
	b._spawn_enemy(b.mission.waves[0])
	var e: BattleEnemy = b.enemies.back()
	e.ground_pos = pos
	if hp > 0.0:
		e.health.hp = hp
		e.health.max_hp = maxf(e.health.max_hp, hp)
	return e


func _run(b: BattleController, seconds: float) -> void:
	for i in int(round(seconds / DT)):
		b.step(DT)


func _unit(b: BattleController, unit_id: String) -> BattleUnit:
	for u in b.units:
		if u.def.id == unit_id:
			return u
	return null


func test_there_is_no_player_move_order_any_more() -> void:
	var b := _battle([["rifle_soldier", SOLDIER_CELL]])
	assert_true(not b.has_method("order_move_all"), "click-to-move was removed")
	_release()


func test_a_guard_walks_out_to_an_enemy_near_its_anchor_fights_and_walks_back() -> void:
	var b := _battle([["rifle_soldier", SOLDIER_CELL]])
	var s := _unit(b, "rifle_soldier")
	var anchor := s.anchor
	assert_vec_near(anchor, IsoProjection.cell_center(SOLDIER_CELL))
	# 13 tiles east of the anchor: out of its range (8) but inside what the leash lets it reach (6 + 0.9 * 8)
	var e := _enemy(b, anchor + Vector2(13.0, 0.0), 100000.0)
	var went_out := 0.0
	for i in 60 * 6:
		b.step(DT)
		went_out = maxf(went_out, s.ground_pos.distance_to(anchor))
	assert_true(went_out > 2.0, "it left its anchor to get in range (%.1f)" % went_out)
	assert_true(b.stats["shots"] > 0, "and fired")
	e.health.hp = 0.0
	_run(b, 12.0)
	assert_true(s.ground_pos.distance_to(anchor) < 0.2, "it came back to its anchor when nothing was left to fight")
	_release()


func test_a_guard_never_strays_farther_than_its_leash() -> void:
	var b := _battle([["rifle_soldier", SOLDIER_CELL]])
	var s := _unit(b, "rifle_soldier")
	var leash := s.def.leash
	var farthest := 0.0
	_enemy(b, s.anchor + Vector2(11.0, 3.0), 1.0e7)
	_enemy(b, s.anchor + Vector2(9.0, -2.0), 1.0e7)
	for i in 60 * 20:
		b.step(DT)
		if is_instance_valid(s) and s.is_alive():
			farthest = maxf(farthest, s.ground_pos.distance_to(s.anchor))
	assert_true(farthest <= leash + 0.05, "farthest %.2f, leash %.2f" % [farthest, leash])
	_release()


func test_a_guard_ignores_enemies_beyond_its_reach() -> void:
	var b := _battle([["rifle_soldier", SOLDIER_CELL]])
	var s := _unit(b, "rifle_soldier")
	_enemy(b, s.anchor + Vector2(26.0, -4.0), 1.0e7)  # 26 tiles away; the zone is 6 + 7.2 = 13.2
	for i in 120:
		b.step(DT)
		assert_true(not s.is_moving(), "no reason to walk")
	assert_vec_near(s.ground_pos, s.anchor, 1e-6)
	_release()


func test_a_unit_with_hold_never_moves_even_with_enemies_in_reach() -> void:
	var b := _battle([["rifle_soldier", SOLDIER_CELL]])
	var s := _unit(b, "rifle_soldier")
	s.def = s.def.duplicate()
	s.def.behavior = UnitBrain.Behavior.HOLD
	_enemy(b, s.anchor + Vector2(12.0, 0.0), 1.0e7)
	_run(b, 5.0)
	assert_vec_near(s.ground_pos, s.anchor, 1e-6)
	_release()


func test_a_moving_unit_stops_the_moment_something_is_in_range() -> void:
	var b := _battle([["rifle_soldier", SOLDIER_CELL]])
	var s := _unit(b, "rifle_soldier")
	var e := _enemy(b, s.anchor + Vector2(13.0, 0.0), 1.0e7)
	var stopped_with_target := false
	var fired_while_moving := false
	var shots := 0
	for i in 60 * 6:
		b.step(DT)
		if b.stats["shots"] > shots and s.is_moving():
			fired_while_moving = true
		shots = b.stats["shots"]
		if not s.is_moving() and s.ground_pos.distance_to(e.ground_pos) <= s.weapon.range_tiles:
			stopped_with_target = true
	assert_true(stopped_with_target, "it stood still once the enemy was in range")
	assert_true(not fired_while_moving, "and never fired while walking")
	_release()


func test_a_unit_is_never_walking_while_an_enemy_is_in_its_range() -> void:
	var b := _battle([["rifle_soldier", SOLDIER_CELL]])
	var s := _unit(b, "rifle_soldier")
	var e := _enemy(b, s.anchor + Vector2(13.0, 0.0), 1.0e7)
	var violations := 0
	var walked := false
	for i in 60 * 6:
		b.step(DT)
		walked = walked or s.is_moving()
		if s.is_moving() and s.ground_pos.distance_to(e.ground_pos) <= s.weapon.range_tiles:
			violations += 1
	assert_true(walked, "it did walk out")
	assert_eq(violations, 0, "the tick an enemy comes into range the unit stops")
	_release()


func test_a_walking_unit_changes_course_when_the_enemy_it_chased_is_gone() -> void:
	var b := _battle([["rifle_soldier", SOLDIER_CELL]])
	var s := _unit(b, "rifle_soldier")
	var first := _enemy(b, s.anchor + Vector2(-3.0, 11.0), 1.0e7)  # south-west of the anchor, route over grass, out of range
	for i in 10:
		b.step(DT)
	assert_true(s.is_moving(), "it set off toward the first enemy")
	var first_target := s.move_target()
	first.health.hp = 0.0
	_enemy(b, s.anchor + Vector2(6.0, 10.0), 1.0e7)  # south-east instead
	for i in 6:
		b.step(DT)
	assert_true(s.is_moving(), "it is walking toward the second one")
	assert_true(s.move_target().distance_to(first_target) > 1.0, "it re-aimed instead of finishing the old walk")
	_release()


func test_a_tank_advances_toward_the_front_enemy_and_stays_within_its_limit() -> void:
	var b := _battle([["tank", SOLDIER_CELL]])
	var t := _unit(b, "tank")
	var core := b.core.ground_pos
	var e := _enemy(b, core + Vector2(14.0, -1.0), 1.0e7)
	var start_gap := t.ground_pos.distance_to(e.ground_pos)
	var farthest_from_core := 0.0
	for i in 60 * 15:
		b.step(DT)
		farthest_from_core = maxf(farthest_from_core, t.ground_pos.distance_to(core))
	assert_true(t.ground_pos.distance_to(e.ground_pos) < start_gap, "it closed in on the enemy")
	assert_true(farthest_from_core <= t.def.advance_limit + 0.1, "never beyond the advance limit (%.2f of %.2f)" % [farthest_from_core, t.def.advance_limit])
	assert_true(b.stats["shots"] > 0, "and it fired")
	_release()


func test_an_advance_unit_chooses_the_enemy_closest_to_the_core() -> void:
	var b := _battle([["tank", SOLDIER_CELL]])
	var core := b.core.ground_pos
	_enemy(b, core + Vector2(4.0, 12.0), 1.0e7)
	var near := _enemy(b, core + Vector2(10.0, 1.0), 1.0e7)
	b.step(DT)
	assert_vec_near(b._front_pos, near.ground_pos, 0.05, "the front is the one nearest the core")
	_release()


func test_units_do_not_walk_through_rock_or_off_the_map() -> void:
	var b := _battle([["rifle_soldier", SOLDIER_CELL]])
	assert_true(not b._walk_is_clear(Vector2(8.5, 10.5), Vector2(12.5, 10.5)), "the rock wall at (10, 10)")
	assert_true(not b._walk_is_clear(Vector2(8.5, 20.5), Vector2(8.5, 80.5)), "off the map")
	assert_true(b._walk_is_clear(Vector2(5.5, 18.5), Vector2(8.5, 18.5)), "plain grass")
	assert_true(not b._walk_is_clear(Vector2(5.5, 18.5), b.core.ground_pos), "the core's own cell")
	_release()


func test_units_do_not_walk_through_scenery() -> void:
	var b := _battle([["rifle_soldier", SOLDIER_CELL]])
	assert_true(b._walk_is_clear(Vector2(5.5, 18.5), Vector2(8.5, 18.5)))
	b._blocked_cells[Vector2i(7, 18)] = true  # what a scenery piece on that cell does
	assert_true(not b._walk_is_clear(Vector2(5.5, 18.5), Vector2(8.5, 18.5)))
	_release()


func test_a_support_unit_follows_the_nearest_friend() -> void:
	var b := _battle([["rifle_soldier", Vector2i(7, 19)], ["rifle_soldier", Vector2i(7, 24)], ["rpg_soldier", Vector2i(7, 21)]])
	var sup := _unit(b, "rpg_soldier")
	sup.def = sup.def.duplicate()
	sup.def.behavior = UnitBrain.Behavior.SUPPORT
	var near: BattleUnit
	for u in b.units:
		if u.def.id == "rifle_soldier" and u.ground_pos.distance_to(sup.ground_pos) < 2.9:
			near = u
	var found := b._nearest_friend(sup)
	assert_true(near != null and found == near, "the friend 2 tiles away, not the one 3 tiles away")
	_release()


func test_a_support_unit_follows_a_friendly_fighter() -> void:
	var b := _battle([["rifle_soldier", SOLDIER_CELL], ["rpg_soldier", Vector2i(7, 22)]])
	var friend := _unit(b, "rifle_soldier")
	var sup := _unit(b, "rpg_soldier")
	sup.def = sup.def.duplicate()
	sup.def.behavior = UnitBrain.Behavior.SUPPORT
	_run(b, 4.0)
	assert_true(sup.ground_pos.distance_to(friend.ground_pos) <= UnitBrain.FOLLOW_GAP + 0.1, "it walked up to its friend")
	friend.ground_pos = friend.ground_pos + Vector2(0.0, -6.0)
	_run(b, 5.0)
	assert_true(sup.ground_pos.distance_to(friend.ground_pos) <= UnitBrain.FOLLOW_GAP + 0.1, "and follows it when it moves away")
	_release()


func test_a_support_unit_does_not_follow_another_support_unit() -> void:
	var b := _battle([["rifle_soldier", Vector2i(7, 19)], ["rpg_soldier", Vector2i(7, 22)]])
	for u in b.units:
		u.def = u.def.duplicate()
		u.def.behavior = UnitBrain.Behavior.SUPPORT
	assert_true(b._nearest_friend(b.units[0]) == null)
	_release()


func test_the_same_seed_and_the_same_enemies_give_the_same_battle() -> void:
	var results: Array = []
	for run in 2:
		var b := _battle([["rifle_soldier", SOLDIER_CELL], ["tank", Vector2i(7, 21)]], 5)
		_enemy(b, Vector2(21.5, 19.5), 600.0)
		_enemy(b, Vector2(23.5, 22.5), 600.0)
		_run(b, 20.0)
		var snap: Array = []
		for u in b.units:
			snap.append([u.ground_pos, u.health.hp])
		for e in b.enemies:
			snap.append([e.ground_pos, e.health.hp])
		results.append([snap, b.stats["shots"], b.stats["kills"]])
	assert_eq(results[0], results[1])
	_release()


func test_a_card_squad_acts_on_its_own_with_no_further_input() -> void:
	var m: MissionDefinition = _get_db().mission(MISSION_ID)
	var b := BattleController.new()
	b.auto_step = false
	b.setup(_get_db(), m, 3)
	_made.append(b)
	b.deck.hand = ["rifle_squad"] as Array[String]
	b.points.cp = 10.0
	assert_true(b.play_card(0, SOLDIER_CELL).ok)
	_run(b, 40.0)  # the first wave (from 4 s) walks into the squad
	assert_true(b.stats["shots"] > 0, "the squad fired with no orders")
	assert_true(b.stats["kills"] > 0, "and killed something")
	_release()


# --- habits ------------------------------------------------------------------------------------------

func _enemy_of(b: BattleController, kind: String, pos: Vector2, hp: float = 1.0e7, speed: float = -1.0) -> BattleEnemy:
	var w := WaveEntry.new()
	w.enemy_id = kind
	b._spawn_enemy(w)
	var e: BattleEnemy = b.enemies.back()
	e.ground_pos = pos
	e.health.hp = hp
	e.health.max_hp = maxf(e.health.max_hp, hp)
	if speed >= 0.0:
		e.def = e.def.duplicate()
		e.def.move_speed = maxf(speed, 0.0001)
	return e


## The first target each unit shoots at, by shooter id.
func _first_targets(b: BattleController) -> Dictionary:
	var seen: Dictionary = {}
	b.shot_fired.connect(func(shooter: BattleUnit, target: BattleEnemy) -> void:
		if not seen.has(shooter.def.id):
			seen[shooter.def.id] = target.def.id)
	b.projectile_launched.connect(func(shooter: BattleUnit, _w: WeaponDefinition, _f: Vector2, _t: Vector2) -> void:
		if not seen.has(shooter.def.id):
			seen[shooter.def.id] = "(projectile)")
	return seen


func test_a_hurt_soldier_with_enemies_near_falls_back_toward_the_core() -> void:
	var b := _battle([["rifle_soldier", SOLDIER_CELL]])
	var s := _unit(b, "rifle_soldier")
	s.health.hp = s.health.max_hp * 0.2
	_enemy_of(b, "shambler", s.anchor + Vector2(0.0, -6.0), 1.0e7, 0.0)
	var start := s.ground_pos.distance_to(b.core.ground_pos)
	_run(b, 4.0)
	var now := s.ground_pos.distance_to(b.core.ground_pos)
	assert_true(now < start - 0.8, "it moved toward the core (%.2f -> %.2f)" % [start, now])
	assert_true(now <= UnitBrain.RETREAT_STAND + 0.3, "and stands close to it (%.2f)" % now)
	_release()


func test_a_healthy_soldier_does_not_fall_back() -> void:
	var b := _battle([["rifle_soldier", SOLDIER_CELL]])
	var s := _unit(b, "rifle_soldier")
	_enemy_of(b, "shambler", s.anchor + Vector2(0.0, -6.0), 1.0e7, 0.0)
	_run(b, 4.0)
	assert_true(s.ground_pos.distance_to(s.anchor) < 1.0)
	_release()


func test_a_hurt_soldier_with_nothing_near_stays_put() -> void:
	var b := _battle([["rifle_soldier", SOLDIER_CELL]])
	var s := _unit(b, "rifle_soldier")
	s.health.hp = s.health.max_hp * 0.2
	_enemy_of(b, "shambler", s.anchor + Vector2(0.0, -15.0), 1.0e7, 0.0)
	_run(b, 3.0)
	assert_vec_near(s.ground_pos, s.anchor, 1e-6)
	_release()


func test_the_retreat_habit_can_be_switched_off_and_fixed_units_never_retreat() -> void:
	var b := _battle([["rifle_soldier", SOLDIER_CELL], ["mg_nest", Vector2i(9, 22)]])
	var s := _unit(b, "rifle_soldier")
	var nest := _unit(b, "mg_nest")
	s.def = s.def.duplicate()
	s.def.retreats = false
	s.health.hp = s.health.max_hp * 0.2
	nest.health.hp = nest.health.max_hp * 0.2
	_enemy_of(b, "shambler", s.anchor + Vector2(0.0, -6.0), 1.0e7, 0.0)
	var nest_start := nest.ground_pos
	_run(b, 3.0)
	assert_true(s.ground_pos.distance_to(b.core.ground_pos) > UnitBrain.RETREAT_STAND + 1.0, "no retreat with the habit off")
	assert_vec_near(nest.ground_pos, nest_start, 1e-6)
	_release()


func test_a_rifle_shoots_the_spitter_first_and_an_rpg_the_brute() -> void:
	for armed in [["rifle_soldier", "spitter"], ["rpg_soldier", "brute"]]:
		var b := _battle([[armed[0], SOLDIER_CELL]])
		var seen := _first_targets(b)
		var s := _unit(b, armed[0])
		_enemy_of(b, "shambler", s.anchor + Vector2(0.0, -3.0), 1.0e7, 0.0)
		_enemy_of(b, "spitter", s.anchor + Vector2(0.0, -6.0), 1.0e7, 0.0)
		_enemy_of(b, "brute", s.anchor + Vector2(0.0, -5.0), 1.0e7, 0.0)
		_run(b, 1.0)
		if armed[0] == "rifle_soldier":
			assert_eq(seen.get("rifle_soldier", ""), "spitter", "rifle: spitter before the nearer shambler and brute")
		else:
			assert_true(seen.has("rpg_soldier"), "the rocket launcher fired")
			assert_eq(b.enemies.filter(func(e: BattleEnemy) -> bool: return e.def.id == "brute")[0].health.hp < 1.0e7, true, "and hit the brute")
	_release()


func test_focus_fire_can_be_switched_off() -> void:
	var b := _battle([["rifle_soldier", SOLDIER_CELL]])
	var seen := _first_targets(b)
	var s := _unit(b, "rifle_soldier")
	s.def = s.def.duplicate()
	s.def.focus_fire = false
	_enemy_of(b, "shambler", s.anchor + Vector2(0.0, -3.0), 1.0e7, 0.0)
	_enemy_of(b, "spitter", s.anchor + Vector2(0.0, -6.0), 1.0e7, 0.0)
	_run(b, 1.0)
	assert_eq(seen.get("rifle_soldier", ""), "shambler", "nearest first without the habit")
	_release()


func test_a_guard_takes_cover_behind_a_friendly_wall_and_fights_from_there() -> void:
	var b := _battle([["rifle_soldier", SOLDIER_CELL], ["sandbag_wall", Vector2i(7, 15)]])
	var s := _unit(b, "rifle_soldier")
	var wall := _unit(b, "sandbag_wall")
	_enemy_of(b, "shambler", Vector2(7.5, 10.0), 1.0e7, 0.0)
	_run(b, 5.0)
	assert_true(s.ground_pos.distance_to(wall.ground_pos) <= UnitBrain.COVER_OK, "it stands right behind the wall (%.2f)" % s.ground_pos.distance_to(wall.ground_pos))
	assert_true(wall.ground_pos.distance_to(Vector2(7.5, 10.0)) < s.ground_pos.distance_to(Vector2(7.5, 10.0)), "with the wall nearer the enemy")
	assert_true(b.stats["shots"] > 0, "and it fires from there")
	_release()


func test_a_guard_with_an_enemy_on_top_of_it_fights_instead_of_walking_to_cover() -> void:
	var b := _battle([["rifle_soldier", SOLDIER_CELL], ["sandbag_wall", Vector2i(7, 15)]])
	var s := _unit(b, "rifle_soldier")
	_enemy_of(b, "shambler", s.anchor + Vector2(0.0, -2.5), 1.0e7, 0.0)  # 2.5 tiles away: inside the 3-tile alarm
	_run(b, 1.0)
	assert_vec_near(s.ground_pos, s.anchor, 1e-6)
	assert_true(b.stats["shots"] > 0, "it shot from where it stood")
	_release()


func test_without_the_cover_habit_the_guard_stops_as_soon_as_it_is_in_range() -> void:
	var b := _battle([["rifle_soldier", SOLDIER_CELL], ["sandbag_wall", Vector2i(7, 15)]])
	var s := _unit(b, "rifle_soldier")
	s.def = s.def.duplicate()
	s.def.seeks_cover = false
	var wall := _unit(b, "sandbag_wall")
	_enemy_of(b, "shambler", Vector2(7.5, 10.0), 1.0e7, 0.0)
	_run(b, 5.0)
	assert_true(s.ground_pos.distance_to(wall.ground_pos) > 2.0, "it did not go to the wall (%.2f)" % s.ground_pos.distance_to(wall.ground_pos))
	_release()


func test_a_guard_in_cover_does_not_shuffle_while_the_enemy_creeps_along() -> void:
	var b := _battle([["rifle_soldier", SOLDIER_CELL], ["sandbag_wall", Vector2i(7, 15)]])
	var s := _unit(b, "rifle_soldier")
	_enemy_of(b, "shambler", Vector2(7.5, 10.0), 1.0e7, 0.05)
	_run(b, 4.0)
	var settled := s.ground_pos
	var moves := 0
	for i in 60 * 6:
		b.step(DT)
		if s.is_moving():
			moves += 1
	assert_true(moves < 10, "it stood still and shot (%d ticks of walking)" % moves)
	assert_true(s.ground_pos.distance_to(settled) < 0.6)
	_release()

