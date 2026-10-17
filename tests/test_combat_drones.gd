extends TestCase
## Combat Drones (M3.7, ADR-013): the HUNT behaviour, unit lifetimes, the SUPPORT_TECH card kind, and the proof that a
## new card of an existing kind needs only data.

const DT: float = 1.0 / 60.0
const R := CardPlayService.Reason
const Brain := preload("res://scripts/combat/unit_brain.gd")
const MISSION := "x6_high_tech"

var _db: ContentDb
var _made: Array[BattleController] = []


func _get_db() -> ContentDb:
	if _db == null:
		_db = ContentDb.load_from()
	return _db


func _battle(db: ContentDb = null) -> BattleController:
	var b := BattleController.new()
	b.auto_step = false
	var use := db if db != null else _get_db()
	b.setup(use, use.mission(MISSION), 1)
	for i in b.mission.waves.size():
		b._wave_spawned[i] = b.mission.waves[i].count  # no zombies unless a test puts one there
	_made.append(b)
	return b


func _release() -> void:
	for b in _made:
		b.free()
	_made.clear()


func _hand(b: BattleController, ids: Array[String], cp: float = 10.0) -> void:
	b.deck.hand = ids
	b.points.cp = cp


func _run_for(b: BattleController, seconds: float) -> void:
	for i in int(round(seconds / DT)):
		b.step(DT)


func _enemy_at(b: BattleController, pos: Vector2) -> BattleEnemy:
	b._spawn_enemy(b.mission.waves[0])
	var e: BattleEnemy = b.enemies.back()
	e.ground_pos = pos
	return e


func _drones(b: BattleController) -> Array[BattleUnit]:
	var out: Array[BattleUnit] = []
	for u in b.units:
		if u.def.id == "combat_drone" and u.is_alive():
			out.append(u)
	return out


func _has(errs: PackedStringArray, needle: String) -> bool:
	for e in errs:
		if needle in e:
			return true
	return false


# --- the HUNT behaviour (pure) --------------------------------------------------------------------------------

func test_a_hunter_with_something_in_range_stays_put() -> void:
	var d := Brain.hunt(Vector2(5, 5), Vector2(0, 0), 5.5, true, true, Vector2(8, 5))
	assert_eq(d.action, Brain.Action.STAY)


func test_a_hunter_does_not_shuffle_closer_once_the_prey_is_in_range() -> void:
	var d := Brain.hunt(Vector2(0, 0), Vector2(0, 0), 5.5, true, true, Vector2(5.2, 0))
	assert_eq(d.action, Brain.Action.STAY, "5.2 is inside 5.5 but beyond the 90 % firing spot: it stays and fires")
	var closing := Brain.hunt(Vector2(0, 0), Vector2(0, 0), 5.5, false, true, Vector2(5.2, 0))
	assert_eq(closing.action, Brain.Action.MOVE, "told it is not in range, it closes to the firing spot")
	var edge := Brain.hunt(Vector2(0, 0), Vector2(0, 0), 5.5, false, true, Vector2(6.0, 0))
	assert_eq(edge.action, Brain.Action.MOVE, "6.0 is out of range: close in")


func test_a_hunter_flies_to_a_firing_spot_short_of_its_range() -> void:
	var d := Brain.hunt(Vector2(0, 0), Vector2(0, 0), 5.0, false, true, Vector2(20, 0))
	assert_eq(d.action, Brain.Action.MOVE)
	assert_vec_near(d.dest, Vector2(20.0 - 5.0 * Brain.RANGE_MARGIN, 0.0), 1e-6, "on the line to the prey, at 90 % of the range")


func test_a_hunter_goes_for_prey_however_far_and_returns_to_its_anchor_when_none_is_left() -> void:
	var far := Brain.hunt(Vector2(0, 0), Vector2(0, 0), 5.0, false, true, Vector2(500, 300))
	assert_eq(far.action, Brain.Action.MOVE)
	var home := Brain.hunt(Vector2(30, 30), Vector2(2, 2), 5.0, false, false, Vector2.ZERO)
	assert_eq(home.action, Brain.Action.MOVE)
	assert_vec_near(home.dest, Vector2(2, 2))
	var there := Brain.hunt(Vector2(2, 2), Vector2(2, 2), 5.0, false, false, Vector2.ZERO)
	assert_eq(there.action, Brain.Action.STAY)


func test_hunting_is_deterministic() -> void:
	var a := Brain.hunt(Vector2(1, 2), Vector2(0, 0), 5.5, false, true, Vector2(14, 9))
	var b := Brain.hunt(Vector2(1, 2), Vector2(0, 0), 5.5, false, true, Vector2(14, 9))
	assert_eq(a.dest, b.dest)
	assert_eq(a.action, b.action)


# --- definitions --------------------------------------------------------------------------------------------------

func _unit() -> UnitDefinition:
	var u := UnitDefinition.new()
	u.id = "probe"
	u.display_name = "Probe"
	u.max_health = 10.0
	u.weapon_id = "drone_gun"
	u.move_speed = 4.0
	u.height_class = UnitDefinition.HeightClass.LOW_AIR
	u.behavior = Brain.Behavior.HUNT
	return u


func test_a_hunting_aircraft_validates_and_a_lifetime_may_not_be_negative() -> void:
	assert_eq(_unit().validate().size(), 0)
	var u := _unit()
	u.lifetime_s = -1.0
	assert_true(_has(u.validate(), "lifetime_s"))


func test_only_armed_mobile_aircraft_may_hunt() -> void:
	var ground := _unit()
	ground.height_class = UnitDefinition.HeightClass.GROUND
	assert_true(_has(ground.validate(), "HUNT is for armed, mobile aircraft"))
	var fixed := _unit()
	fixed.move_speed = 0.0
	assert_true(_has(fixed.validate(), "HUNT is for armed, mobile aircraft"))
	var unarmed := _unit()
	unarmed.weapon_id = ""
	assert_true(_has(unarmed.validate(), "weapon_id"))


func test_helicopters_fly_a_plan_and_drones_do_not() -> void:
	var db := _get_db()
	assert_true(db.unit("helicopter").flies_a_plan())
	assert_true(not db.unit("combat_drone").flies_a_plan())
	assert_true(not db.unit("rifle_soldier").flies_a_plan())


func test_the_support_tech_card_kind_is_instant_and_needs_a_unit() -> void:
	var c := CardDefinition.new()
	c.id = "probe"
	c.display_name = "Probe"
	c.card_kind = CardDefinition.CardKind.SUPPORT_TECH
	assert_true(c.is_instant())
	assert_true(not c.uses_state_effect() and not c.uses_field_entity())
	assert_true(_has(c.validate(), "unit_id"))
	c.unit_id = "combat_drone"
	c.unit_count = 0
	assert_true(_has(c.validate(), "unit_count"))
	c.unit_count = 3
	assert_eq(c.validate().size(), 0)


func _db_with_tech_card(unit_id: String) -> ContentDb:
	var db := ContentDb.load_from()
	db.errors.clear()
	var c := CardDefinition.new()
	c.id = "probe"
	c.display_name = "Probe"
	c.card_kind = CardDefinition.CardKind.SUPPORT_TECH
	c.unit_id = unit_id
	db.add_card(c)
	db.validate_references()
	return db


func test_a_tech_card_must_name_an_aircraft_that_hunts_and_leaves() -> void:
	assert_true(_has(_db_with_tech_card("helicopter").errors, "must be an aircraft that hunts"), "a helicopter flies a plan")
	var db2 := ContentDb.load_from()
	db2.errors.clear()
	var timed_heli: UnitDefinition = db2.unit("helicopter").duplicate()
	timed_heli.id = "timed_heli"
	timed_heli.lifetime_s = 20.0
	db2.add_unit(timed_heli)
	var c2 := CardDefinition.new()
	c2.id = "timed_heli_card"
	c2.display_name = "Timed"
	c2.card_kind = CardDefinition.CardKind.SUPPORT_TECH
	c2.unit_id = "timed_heli"
	db2.add_card(c2)
	db2.validate_references()
	assert_true(_has(db2.errors, "must be an aircraft that hunts"), "with a lifetime the helicopter still flies a plan, not a hunt")
	assert_true(_has(_db_with_tech_card("rifle_soldier").errors, "must be an aircraft that hunts"))
	assert_true(_has(_db_with_tech_card("ghost").errors, "unknown unit_id"))
	assert_true(_db_with_tech_card("combat_drone").errors.is_empty())
	var db := ContentDb.load_from()
	db.errors.clear()
	var forever: UnitDefinition = db.unit("combat_drone").duplicate()
	forever.id = "forever_drone"
	forever.lifetime_s = 0.0
	db.add_unit(forever)
	var c := CardDefinition.new()
	c.id = "forever_card"
	c.display_name = "Forever"
	c.card_kind = CardDefinition.CardKind.SUPPORT_TECH
	c.unit_id = "forever_drone"
	db.add_card(c)
	db.validate_references()
	assert_true(_has(db.errors, "must be an aircraft that hunts and leaves after a lifetime"), "no lifetime means it would never leave")


func test_shipped_drone_content_is_valid() -> void:
	var db := _get_db()
	assert_true(db.is_valid(), "\n".join(db.errors))
	assert_eq(db.card("combat_drones").card_kind, CardDefinition.CardKind.SUPPORT_TECH)
	assert_true(db.unit("combat_drone").lifetime_s > 0.0)
	assert_true(db.deck_rules.validate_deck(db.deck("high_tech").ids(), db.cards).is_empty())


# --- in a battle ---------------------------------------------------------------------------------------------------

func test_combat_drones_launch_from_the_base_on_the_click() -> void:
	var b := _battle()
	_hand(b, ["combat_drones"] as Array[String])
	b.select_slot(0)
	assert_true(not b.targeting.is_selecting(), "nothing to aim")
	var drones := _drones(b)
	assert_eq(drones.size(), b.db.card("combat_drones").unit_count)
	assert_near(b.points.cp, 10.0 - float(b.db.card("combat_drones").cost))
	assert_true(b.deck.is_locked("combat_drones"))
	for i in drones.size():
		for j in range(i + 1, drones.size()):
			assert_true(drones[i].ground_pos.distance_to(drones[j].ground_pos) > 1.0, "launched apart, not stacked")
	for d in drones:
		assert_true(d is BattleAircraft)
		assert_near(d.altitude, UnitDefinition.LOW_AIR_ALTITUDE)
		assert_true(d.ground_pos.distance_to(b.core.ground_pos) <= BattleController.DRONE_RING + 0.01)
	_release()


func test_a_refused_drone_play_changes_nothing() -> void:
	var b := _battle()
	_hand(b, ["combat_drones"] as Array[String], 1.0)
	var before := [b.units.size(), b.points.cp, b.deck.hand.duplicate(), b.deck.lockouts.duplicate()]
	assert_eq(b.play_card(0, Vector2i.ZERO).reason, R.INSUFFICIENT_CP)
	assert_eq([b.units.size(), b.points.cp, b.deck.hand, b.deck.lockouts], before)
	_release()


func test_drones_fly_to_the_nearest_enemy_and_kill_it_by_themselves() -> void:
	var b := _battle()
	_hand(b, ["combat_drones"] as Array[String])
	b.play_card(0, Vector2i.ZERO)
	var e := _enemy_at(b, IsoProjection.cell_center(Vector2i(12, 12)))
	e.health = Health.new(200.0)
	_run_for(b, 12.0)
	assert_eq(b.stats["kills"], 1, "the drones killed it")
	assert_true(not is_instance_valid(e) or not b.enemies.has(e))
	_release()


func test_drones_cross_water_and_rock_that_stop_walkers() -> void:
	var b := _battle()
	var rock := Vector2i(-1, -1)
	for y in b.mission.map.height():
		for x in b.mission.map.width():
			if rock.x < 0 and not b.mission.map.is_walkable(Vector2i(x, y)) and Vector2i(x, y).distance_to(b.mission.core_cell) > 8.0:
				rock = Vector2i(x, y)
	assert_true(rock.x >= 0)
	_hand(b, ["combat_drones"] as Array[String])
	b.play_card(0, Vector2i.ZERO)
	var e := _enemy_at(b, IsoProjection.cell_center(rock))
	e.health = Health.new(5000.0)
	var hp := e.health.hp
	_run_for(b, 10.0)
	assert_true(e.health.hp < hp, "they flew over the rock and shot it")
	_release()


func test_drones_fly_over_a_wall_between_the_base_and_the_enemy() -> void:
	var b := _battle()
	for y in b.mission.map.height():
		for x in [6, 7]:
			b._blocked_cells[Vector2i(x, y)] = true  # a wall of scenery all the way across: a walker could not follow
	_hand(b, ["combat_drones"] as Array[String])
	b.play_card(0, Vector2i.ZERO)
	var e := _enemy_at(b, IsoProjection.cell_center(Vector2i(12, 12)))
	e.health = Health.new(200.0)
	e._waypoints = [e.ground_pos] as Array[Vector2]  # it stands where it is, so only flying over the wall can reach it
	_run_for(b, 15.0)
	assert_eq(b.stats["kills"], 1, "the drones went over the wall and killed it")
	_release()


func test_zombies_cannot_hurt_drones() -> void:
	var b := _battle()
	_hand(b, ["combat_drones"] as Array[String])
	b.play_card(0, Vector2i.ZERO)
	var d := _drones(b)[0]
	var e := _enemy_at(b, d.ground_pos + Vector2(0.3, 0.0))
	e.health = Health.new(1.0e6)
	_run_for(b, 2.0)
	for dr in _drones(b):
		assert_near(dr.health.hp, dr.health.max_hp, 1e-9)
	assert_eq(b.stats["units_lost"], 0)
	_release()


func test_drones_go_on_to_the_next_enemy_after_a_kill() -> void:
	var b := _battle()
	_hand(b, ["combat_drones"] as Array[String])
	b.play_card(0, Vector2i.ZERO)
	_enemy_at(b, IsoProjection.cell_center(Vector2i(12, 12)))
	_enemy_at(b, IsoProjection.cell_center(Vector2i(14, 3)))
	_run_for(b, 18.0)
	assert_eq(b.stats["kills"], 2)
	_release()


func test_drones_fly_home_when_the_hunt_is_over() -> void:
	var b := _battle()
	_hand(b, ["combat_drones"] as Array[String])
	b.play_card(0, Vector2i.ZERO)
	var anchors: Dictionary = {}
	for d in _drones(b):
		anchors[d.uid] = d.anchor
	_enemy_at(b, IsoProjection.cell_center(Vector2i(13, 8)))
	_run_for(b, 14.0)
	assert_eq(b.stats["kills"], 1)
	for d in _drones(b):
		assert_true(d.ground_pos.distance_to(anchors[d.uid]) < 0.3, "back at its launch spot")
	_release()


func test_drones_leave_when_their_time_is_up_and_that_is_not_a_loss() -> void:
	var b := _battle()
	_hand(b, ["combat_drones"] as Array[String])
	b.play_card(0, Vector2i.ZERO)
	var life := b.db.unit("combat_drone").lifetime_s
	_run_for(b, life - 0.5)
	assert_eq(_drones(b).size(), 3, "still on station")
	_run_for(b, 1.0)
	assert_eq(_drones(b).size(), 0)
	assert_eq(b.stats["units_lost"], 0)
	assert_eq(b.units.size(), 0)
	_release()


func test_a_lifetime_works_for_any_unit_and_a_new_drone_card_needs_only_data() -> void:
	var db := ContentDb.load_from()
	var swarm: UnitDefinition = db.unit("combat_drone").duplicate()
	swarm.id = "swarm_drone"
	swarm.lifetime_s = 5.0
	assert_true(db.add_unit(swarm))
	var card: CardDefinition = db.card("combat_drones").duplicate()
	card.id = "swarm_drones"
	card.display_name = "Swarm Drones"
	card.unit_id = "swarm_drone"
	card.unit_count = 5
	assert_true(db.add_card(card))
	var short: UnitDefinition = db.unit("rifle_soldier").duplicate()
	short.id = "short_soldier"
	short.lifetime_s = 4.0
	assert_true(db.add_unit(short))
	db.validate_references()
	assert_true(db.is_valid(), "\n".join(db.errors))
	var b := _battle(db)
	_hand(b, ["swarm_drones"] as Array[String])
	assert_true(b.play_card(0, Vector2i.ZERO).ok)
	var count := 0
	for u in b.units:
		if u.def.id == "swarm_drone":
			count += 1
	assert_eq(count, 5)
	var s := b._spawn_unit_at("short_soldier", IsoProjection.cell_center(Vector2i(7, 19)))
	_run_for(b, 3.5)
	assert_true(b.units.has(s))
	_run_for(b, 1.0)
	assert_true(not is_instance_valid(s), "the soldier left after 4 s")
	_run_for(b, 1.0)
	assert_eq(b.units.size(), 0, "and the swarm after 5 s")
	_release()


func test_units_without_a_lifetime_never_expire() -> void:
	var b := _battle()
	var s := b._spawn_unit_at("rifle_soldier", IsoProjection.cell_center(Vector2i(7, 19)))
	_run_for(b, 30.0)
	assert_true(b.units.has(s))
	_release()
