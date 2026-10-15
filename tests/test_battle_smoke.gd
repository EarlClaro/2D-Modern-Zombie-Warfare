extends TestCase
## Headless battle simulation tests: build the real mission, step it with a fixed delta, check outcomes.
## The controller is used as an orphan node (no scene tree, no rendering) and stepped manually.

const Rules := preload("res://scripts/missions/mission_rules.gd")
const StartUnitRes := preload("res://scripts/missions/start_unit.gd")

const DT: float = 1.0 / 60.0
const MISSION_ID := "m1_hold_the_crossing"

var _db: ContentDb
var _made: Array[BattleController] = []


func _get_db() -> ContentDb:
	if _db == null:
		_db = ContentDb.load_from()
	return _db


func _su(unit_id: String, cell: Vector2i) -> StartUnit:
	var su := StartUnitRes.new()
	su.unit_id = unit_id
	su.cell = cell
	return su


## The shipped mission with a different set of starting units.
func _variant(unit_list: Array) -> MissionDefinition:
	var m: MissionDefinition = _get_db().mission(MISSION_ID).duplicate()
	var arr: Array[StartUnit] = []
	for su in unit_list:
		arr.append(su)
	m.start_units = arr
	return m


func _battle(mission: MissionDefinition, seed_value: int = 1) -> BattleController:
	var b := BattleController.new()
	b.auto_step = false
	b.setup(_get_db(), mission, seed_value)
	_made.append(b)
	return b


func _release() -> void:
	for b in _made:
		b.free()
	_made.clear()


func _run_for(b: BattleController, seconds: float) -> void:
	for i in int(round(seconds / DT)):
		b.step(DT)


func _run_to_end(b: BattleController, cap_s: float = 200.0) -> void:
	var steps := int(cap_s / DT)
	for i in steps:
		if b.is_ended():
			return
		b.step(DT)


func _summary(b: BattleController) -> Dictionary:
	return {
		"status": b.result().status,
		"elapsed": snappedf(b.elapsed, 0.001),
		"kills": b.stats["kills"],
		"shots": b.stats["shots"],
		"spawned": b.stats["spawned"],
		"units_lost": b.stats["units_lost"],
		"core_hp": snappedf(b.core.health.hp, 0.001),
		"enemies": b.enemy_count(),
	}


## Adds one enemy (as the first wave would) and places it at `pos` on the ground plane.
func _inject_enemy(b: BattleController, pos: Vector2) -> BattleEnemy:
	b._spawn_enemy(b.mission.waves[0])
	var e: BattleEnemy = b.enemies.back()
	e.ground_pos = pos
	return e


func _count_nodes(n: Node) -> int:
	var c := 1
	for child in n.get_children():
		c += _count_nodes(child)
	return c


## Twelve MG nests on walkable cells near the chokepoint (overwhelming defence).
func _strong_defenders() -> Array:
	var m := _get_db().mission(MISSION_ID)
	var out: Array = []
	for y in range(12, 19):
		for x in range(5, 12):
			var c := Vector2i(x, y)
			if out.size() < 12 and m.map.is_walkable(c) and c != m.core_cell:
				out.append(_su("mg_nest", c))
	return out


# --- setup ---------------------------------------------------------------------------------------

func test_setup_builds_the_mission_world() -> void:
	var b := _battle(_get_db().mission(MISSION_ID))
	var m := _get_db().mission(MISSION_ID)
	assert_eq(b.units.size(), m.start_units.size())
	assert_true(b.core != null)
	assert_near(b.core.health.hp, m.core_health)
	assert_eq(b.enemy_count(), 0)
	assert_true(not b.is_ended())
	assert_near(b.time_left(), m.duration_s)
	_release()


# --- outcomes: both must be reachable ------------------------------------------------------------

func test_without_defenders_the_mission_is_lost() -> void:
	var b := _battle(_variant([]))
	_run_to_end(b)
	assert_true(b.is_ended(), "mission ended")
	assert_eq(b.result().status, Rules.Status.FAILED)
	assert_true(b.core.health.hp <= 0.0, "core destroyed")
	assert_true(b.elapsed < b.mission.duration_s, "lost before the timer")
	assert_eq(b.stats["kills"], 0, "nobody to kill anything")
	assert_true(b.stats["spawned"] > 0)
	_release()


func test_with_overwhelming_defenders_the_mission_is_won() -> void:
	var b := _battle(_variant(_strong_defenders()))
	_run_to_end(b)
	assert_eq(b.result().status, Rules.Status.WON, "reason: " + b.result().reason)
	assert_true(b.elapsed >= b.mission.duration_s)
	assert_true(b.core.health.hp > 0.0)
	assert_eq(b.stats["spawned"], b.mission.total_enemies(), "every wave spawned before the end")
	assert_eq(b.stats["kills"] + b.enemy_count(), b.stats["spawned"], "every enemy is dead or still alive")
	assert_true(b.stats["shots"] > 0)
	_release()


func test_default_mission_ends_and_is_deterministic() -> void:
	var a := _battle(_get_db().mission(MISSION_ID), 77)
	_run_to_end(a)
	var b := _battle(_get_db().mission(MISSION_ID), 77)
	_run_to_end(b)
	assert_true(a.is_ended() and b.is_ended())
	assert_eq(_summary(a), _summary(b), "same seed -> identical outcome")
	assert_true(a.elapsed <= a.mission.duration_s + 0.1)
	_release()


func test_mission_ends_once_and_freezes() -> void:
	var b := _battle(_variant([]))
	var ended_count := [0]
	b.battle_ended.connect(func(_r: Rules.Result) -> void: ended_count[0] += 1)
	_run_to_end(b)
	var frozen := _summary(b)
	_run_for(b, 5.0)
	assert_eq(_summary(b), frozen, "stepping after the end changes nothing")
	assert_eq(ended_count[0], 1)
	_release()


# --- restart -------------------------------------------------------------------------------------

func test_restart_resets_state_and_node_count() -> void:
	var b := _battle(_variant(_strong_defenders()))
	var baseline := _count_nodes(b)
	_run_for(b, 30.0)
	assert_true(b.stats["spawned"] > 0)
	assert_true(_count_nodes(b) > baseline, "enemies and shadows exist mid-battle")
	b.restart()
	assert_eq(_count_nodes(b), baseline, "no leaked nodes after restart")
	assert_near(b.elapsed, 0.0)
	assert_eq(b.stats["spawned"], 0)
	assert_eq(b.stats["kills"], 0)
	assert_eq(b.enemy_count(), 0)
	assert_true(not b.is_ended())
	assert_near(b.core.health.hp, b.mission.core_health)
	_release()


func test_restart_after_the_end_replays_the_same_battle() -> void:
	var b := _battle(_variant([]), 5)
	_run_to_end(b)
	var first := _summary(b)
	b.restart()
	_run_to_end(b)
	assert_eq(_summary(b), first, "same seed -> same replay")
	_release()


# --- spawning & movement -------------------------------------------------------------------------

func _run_until(b: BattleController, t: float) -> void:
	while b.elapsed < t and not b.is_ended():
		b.step(DT)


func test_waves_spawn_on_schedule() -> void:
	# Derived from the mission data (not hard-coded) and sampled mid-interval, away from float boundaries.
	var b := _battle(_variant([]))
	var w := b.mission.waves[0]
	for other in b.mission.waves:
		assert_true(other == w or other.start_s > w.last_spawn_s() + 1.0, "precondition: later waves start after wave 0 finishes")
	assert_true(w.count >= 4 and w.interval_s > 0.0, "precondition: wave 0 has several spaced enemies")
	_run_until(b, w.start_s - 0.5)
	assert_eq(b.stats["spawned"], 0, "nothing before the first wave starts")
	for k in [0, 1, 3]:
		_run_until(b, w.start_s + (k + 0.5) * w.interval_s)
		assert_eq(b.stats["spawned"], k + 1, "after %d full intervals" % k)
	_run_until(b, w.last_spawn_s() + 0.5 * w.interval_s)
	assert_eq(b.stats["spawned"], w.count, "wave 0 fully spawned, no more than its count")
	_release()


func test_enemies_walk_toward_the_core_at_their_speed() -> void:
	var b := _battle(_variant([]), 3)
	_run_for(b, 2.2)  # first enemy exists
	assert_eq(b.enemies.size(), 1)
	var e := b.enemies[0]
	var start := e.ground_pos
	var core_pos := b.core.ground_pos
	_run_for(b, 3.0)
	var moved := e.ground_pos.distance_to(start)
	assert_near(moved, e.def.move_speed * 3.0, 0.05, "ground speed")
	assert_true(e.ground_pos.distance_to(core_pos) < start.distance_to(core_pos), "closer to the core")
	_release()


func test_enemy_spawn_jitter_follows_the_seed() -> void:
	var a := _battle(_variant([]), 11)
	var b := _battle(_variant([]), 11)
	var c := _battle(_variant([]), 12)
	for x in [a, b, c]:
		_run_for(x, 2.2)
	assert_eq(a.enemies[0].ground_pos, b.enemies[0].ground_pos, "same seed same position")
	assert_true(a.enemies[0].ground_pos != c.enemies[0].ground_pos, "different seed different position")
	_release()


# --- orders and firing rules ---------------------------------------------------------------------

func test_move_orders_affect_only_mobile_units_and_valid_cells() -> void:
	var b := _battle(_get_db().mission(MISSION_ID))
	var soldier: BattleUnit
	var nest: BattleUnit
	for u in b.units:
		if u.def.is_fixed():
			nest = u
		else:
			soldier = u
	var nest_start := nest.ground_pos
	var soldier_start := soldier.ground_pos
	assert_eq(b.order_move_all(Vector2i(7, 20)), 1, "only the soldier accepts")
	_run_for(b, 1.0)
	assert_near(soldier.ground_pos.distance_to(soldier_start), soldier.def.move_speed, 0.01, "moved 1 s at its speed")
	assert_vec_near(nest.ground_pos, nest_start, 1e-6, "fixed unit never moves")
	assert_eq(b.order_move_all(b.mission.core_cell), 0, "can't order onto the core")
	assert_eq(b.order_move_all(Vector2i(10, 10)), 0, "rock wall cell")
	assert_eq(b.order_move_all(Vector2i(99, 99)), 0, "outside the map")
	_release()


func test_soldier_does_not_fire_while_moving() -> void:
	var soldier_only := _variant([_su("rifle_soldier", Vector2i(18, 5))])
	# Control: standing soldier with an enemy in range fires on the first tick.
	var control := _battle(soldier_only)
	_inject_enemy(control, control.units[0].ground_pos + Vector2(2.0, 0.0))
	control.step(DT)
	assert_true(control.stats["shots"] >= 1, "standing unit fires")
	# Same setup, but the soldier is ordered to move: no shots while moving.
	var moving := _battle(soldier_only)
	_inject_enemy(moving, moving.units[0].ground_pos + Vector2(2.0, 0.0))
	assert_eq(moving.order_move_all(Vector2i(18, 12)), 1)
	for i in 5:
		moving.step(DT)
	assert_true(moving.units[0].is_moving())
	assert_eq(moving.stats["shots"], 0, "moving unit holds fire")
	_release()


func test_simultaneous_kills_are_counted_once_and_both_shots_land() -> void:
	var two_nests := _variant([_su("mg_nest", Vector2i(8, 14)), _su("mg_nest", Vector2i(9, 14))])
	var b := _battle(two_nests)
	var e := _inject_enemy(b, Vector2(10.5, 13.5))
	e.health.hp = 1.0  # one hit kills; both nests are ready on the first tick
	b.step(DT)
	assert_eq(b.stats["shots"], 2, "both nests fired at the same enemy this tick")
	assert_eq(b.stats["kills"], 1, "the enemy died exactly once")
	assert_eq(b.enemy_count(), 0, "removed after all damage resolved")
	_release()
