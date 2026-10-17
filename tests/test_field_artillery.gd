extends TestCase
## Long-range artillery and the realistic roster (docs/specs/field-command.md, F3): burst fire, minimum range, spotters,
## stationary artillery brain, guns that fire on the move, and the shipped numbers.

const DT: float = 1.0 / 60.0

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


# --- burst fire ----------------------------------------------------------------------------------------------------

func _fires_at(state: WeaponState, seconds: float) -> Array[float]:
	var out: Array[float] = []
	var t := 0.0
	while t < seconds:
		if state.tick(DT, true):
			out.append(snappedf(t, 0.01))
		t += DT
	return out


func test_a_burst_weapon_fires_its_shots_one_interval_apart_and_then_reloads() -> void:
	var s := WeaponState.new(1.0, 3, 10.0)
	var shots := _fires_at(s, 13.5)
	assert_eq(shots.size(), 5, "three in the burst, then the reload, then the next burst begins")
	assert_near(shots[1] - shots[0], 1.0, 0.05)
	assert_near(shots[2] - shots[1], 1.0, 0.05)
	assert_near(shots[3] - shots[2], 10.0, 0.05, "the reload is the pause, not the interval")
	assert_near(shots[4] - shots[3], 1.0, 0.05, "and the new burst is back to the plain interval")


func test_a_weapon_without_a_burst_keeps_its_plain_cadence() -> void:
	var s := WeaponState.new(0.5)
	assert_eq(_fires_at(s, 4.9).size(), 10)
	var from_def := WeaponState.from_definition(_get_db().weapon("rifle"))
	assert_eq(_fires_at(from_def, 2.95).size(), 9, "3 shots a second for 3 seconds")


func test_resetting_a_weapon_starts_a_fresh_burst() -> void:
	var s := WeaponState.new(1.0, 3, 10.0)
	_fires_at(s, 1.5)  # two shots in
	s.reset()
	assert_eq(_fires_at(s, 2.5).size(), 3, "a whole new burst of three")


# --- the weapon definition -----------------------------------------------------------------------------------------------

func test_artillery_settings_are_validated() -> void:
	var w: WeaponDefinition = _get_db().weapon("howitzer").duplicate()
	assert_eq(w.validate().size(), 0)
	w.min_range_tiles = w.range_tiles
	assert_true(w.validate().size() > 0, "the minimum range must stay below the range")
	w = _get_db().weapon("howitzer").duplicate()
	w.min_range_tiles = -1.0
	assert_true(w.validate().size() > 0)
	w = _get_db().weapon("howitzer").duplicate()
	w.burst_size = 0
	assert_true(w.validate().size() > 0)
	w = _get_db().weapon("howitzer").duplicate()
	w.burst_pause_s = -1.0
	assert_true(w.validate().size() > 0)


# --- picking a target for the guns ----------------------------------------------------------------------------------------

func _enemy(id: int, pos: Vector2) -> BattleEnemy:
	var e := BattleEnemy.new()
	e.setup(id, _get_db().enemy("shambler"), pos, [] as Array[Vector2])
	_made.append(e)
	return e


func _index(positions: Array) -> EnemyIndex:
	var idx := EnemyIndex.new()
	idx.begin(40.0, 40.0)
	var i := 1
	for p in positions:
		idx.add(_enemy(i, p), p)
		i += 1
	return idx


func test_a_spotter_only_reports_what_it_sees_and_the_gun_can_reach() -> void:
	var idx := _index([Vector2(10, 10), Vector2(30, 10), Vector2(11, 30)])
	var gun := Vector2(10, 35)
	var e := idx.best_spotted(gun, 8.0, 40.0, Vector2(10, 12), 5.0)  # sees 5 tiles: only the first enemy
	assert_true(e != null and e.ground_pos == Vector2(10, 10))
	assert_true(idx.best_spotted(gun, 8.0, 40.0, Vector2(35, 35), 4.0) == null, "nothing seen from far away")
	assert_true(idx.best_spotted(gun, 8.0, 40.0, Vector2(11, 31), 4.0) == null, "the enemy 5 tiles from the gun is inside its minimum range")
	assert_true(idx.best_spotted(gun, 8.0, 15.0, Vector2(10, 12), 5.0) == null, "an enemy beyond the gun's reach is ignored")
	_release()


func test_the_nearest_to_the_spotter_is_picked_among_equals() -> void:
	var idx := _index([Vector2(10, 10), Vector2(12, 10), Vector2(14, 10)])
	var e := idx.best_spotted(Vector2(10, 35), 8.0, 40.0, Vector2(15, 10), 10.0)
	assert_true(e != null and e.ground_pos == Vector2(14, 10), "what is pressing the spotter")
	assert_near(idx.pick_d2, 1.0)
	_release()


# --- the stationary brain ---------------------------------------------------------------------------------------------------

func _facts(scan: KiteScan) -> UnitBrain.KiteFacts:
	var f := UnitBrain.KiteFacts.new()
	f.pos = Vector2(10, 20)
	f.speed = 1.6
	f.weapon_range = 20.0
	f.core = Vector2(2, 20)
	f.route = Route.from_points(PackedVector2Array([Vector2(30, 0), Vector2(30, 20), Vector2(2, 20)]))
	f.post_s = 40.0
	f.scan = scan
	f.stationary = true
	return f


func test_stationary_artillery_does_not_scout_or_walk_toward_the_enemy() -> void:
	var scan := KiteScan.new()
	var f := _facts(scan)
	assert_eq(UnitBrain.kite(f).action, UnitBrain.Action.STAY, "nothing in sight: it stays where it was put")
	scan.has_upstream = true
	scan.upstream_pos = Vector2(30, 5)
	scan.upstream_reach = 0.8
	scan.upstream_speed = 1.2
	assert_eq(UnitBrain.kite(f).action, UnitBrain.Action.STAY, "an enemy far away: still stays (a skirmisher would walk up)")
	f.stationary = false
	assert_eq(UnitBrain.kite(f).action, UnitBrain.Action.MOVE, "the same facts move a skirmisher")


func test_stationary_artillery_still_backs_away_from_a_close_enemy() -> void:
	var scan := KiteScan.new()
	scan.danger_count = 1
	scan.danger_slower = 1
	scan.worst_slack = -3.0
	scan.away = Vector2(-1, 0)  # the enemy stands on the far side, away from the core is the other way
	var f := _facts(scan)
	f.pos = Vector2(14, 20)
	var d := UnitBrain.kite(f)
	assert_eq(d.action, UnitBrain.Action.MOVE)
	assert_true(d.dest.distance_to(f.core) < f.pos.distance_to(f.core), "toward the core")


# --- in a battle -----------------------------------------------------------------------------------------------------------

const GUN_CELL := Vector2i(7, 19)
const NEST_CELL := Vector2i(9, 13)


func _battle(units: Array) -> BattleController:
	var m: MissionDefinition = _get_db().mission("m2_card_defense").duplicate()
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
	b.setup(_get_db(), m, 1)
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
	b._enemy_index_valid = false
	return e


func test_the_howitzer_does_not_fire_at_an_enemy_nobody_can_see() -> void:
	var b := _battle([["howitzer", GUN_CELL]])
	_inject(b, "shambler", Vector2(20.5, 4.5))
	_inject(b, "shambler", Vector2(19.5, 19.5))  # 12 tiles from the gun: it would see this itself, but a gun never spots for itself
	var shells: Array = []
	b.projectile_launched.connect(func(s: BattleUnit, w: WeaponDefinition, f: Vector2, t: Vector2): shells.append(w.id))
	_run(b, 0.5)
	assert_eq(shells.size(), 0, "the gun is blind: no friend and not the core can see them")
	_release()


func test_the_howitzer_fires_once_a_friendly_unit_sees_the_target() -> void:
	var b := _battle([["howitzer", GUN_CELL], ["mg_nest", NEST_CELL]])
	_inject(b, "shambler", Vector2(20.5, 4.5))  # about 14 from the nest: seen (vision 16), out of the nest's own reach
	var shells: Array = []
	b.projectile_launched.connect(func(s: BattleUnit, w: WeaponDefinition, f: Vector2, t: Vector2): shells.append(s.def.id))
	_run(b, 1.5)
	assert_true(shells.size() >= 1 and shells[0] == "howitzer", "the nest spotted it for the gun")
	_release()


func test_the_howitzer_fires_a_burst_of_three_and_then_reloads() -> void:
	var b := _battle([["howitzer", GUN_CELL], ["mg_nest", NEST_CELL]])
	for i in 24:  # a long line of targets so there is always something to shell
		_inject(b, "shambler", Vector2(8.5 + float(i % 6) * 2.5, 2.5 + float(i / 6) * 2.5))
	var shells: Array = []
	b.projectile_launched.connect(func(s: BattleUnit, w: WeaponDefinition, f: Vector2, t: Vector2): shells.append(w.id))
	_run(b, 5.0)
	assert_eq(shells.size(), 3, "a burst of three")
	_run(b, 5.0)
	assert_eq(shells.size(), 3, "and nothing while it reloads")
	_run(b, 9.0)
	assert_true(shells.size() >= 4, "then the next burst starts")
	_release()


func test_a_target_inside_the_minimum_range_cannot_be_shelled() -> void:
	var b := _battle([["howitzer", GUN_CELL]])
	var gun: BattleUnit = b.units[0]
	_inject(b, "shambler", gun.ground_pos + Vector2(0.0, -5.0))  # the core sees it, but it is inside 8 tiles
	assert_true(b._artillery_target(gun) == null, "too close")
	_inject(b, "shambler", gun.ground_pos + Vector2(0.0, -10.0))
	var far := b._artillery_target(gun)
	assert_true(far != null and far.ground_pos.distance_to(gun.ground_pos) > 9.0, "the farther one is fair game")
	_release()


func test_a_mortar_sees_for_itself_but_not_inside_its_minimum_range() -> void:
	var b := _battle([["mortar_team", GUN_CELL]])
	var m: BattleUnit = b.units[0]
	_inject(b, "shambler", m.ground_pos + Vector2(2.0, 0.0))
	assert_true(b._artillery_target(m) == null, "2 tiles is inside the 3 tile minimum")
	var e := _inject(b, "shambler", m.ground_pos + Vector2(0.0, -9.0))
	assert_true(b._artillery_target(m) == e, "9 tiles: in its own sight and in its band")
	_release()


func test_a_tank_fires_while_it_backs_away() -> void:
	var b := _battle([["tank", Vector2i(9, 17)]])
	var tank: BattleUnit = b.units[0]
	_inject(b, "runner", tank.ground_pos + Vector2(2.2, -1.0))
	var moving_shots := [0]
	b.shot_fired.connect(func(u: BattleUnit, t: BattleEnemy): moving_shots[0] += 1 if u.is_moving() else 0)
	_run(b, 1.5)
	assert_true(b.stats["shots"] >= 1, "it fired")
	assert_true(moving_shots[0] >= 1, "at least one of those shots left the gun while the tank was moving")
	_release()


func test_a_rifleman_still_has_to_stand_still_to_fire() -> void:
	var b := _battle([["rifle_soldier", Vector2i(9, 17)]])
	var u: BattleUnit = b.units[0]
	_inject(b, "runner", u.ground_pos + Vector2(2.2, -1.0))
	var moving_shots := [0]
	b.shot_fired.connect(func(s: BattleUnit, t: BattleEnemy): moving_shots[0] += 1 if s.is_moving() else 0)
	_run(b, 1.5)
	assert_eq(moving_shots[0], 0)
	_release()


# --- the shipped numbers ------------------------------------------------------------------------------------------------------

func test_the_shipped_roster_follows_the_realistic_ratios() -> void:
	var db := _get_db()
	assert_true(db.is_valid(), "content errors: %s" % ", ".join(db.errors))
	var rifle := db.weapon("rifle")
	var how := db.weapon("howitzer")
	var mortar := db.weapon("mortar")
	var rocket := db.weapon("rocket_salvo")
	assert_true(how.range_tiles >= 35.0 and how.min_range_tiles >= 6.0 and how.needs_spotter and how.burst_size == 3)
	assert_true(mortar.range_tiles < how.range_tiles / 2.0 and mortar.range_tiles > rifle.range_tiles and not mortar.needs_spotter)
	assert_true(rocket.range_tiles >= 35.0 and rocket.burst_size >= 6 and rocket.burst_pause_s > how.burst_pause_s)
	assert_true(db.weapon("tank_cannon").range_tiles >= rifle.range_tiles * 2.0 and db.weapon("tank_cannon").can_fire_moving)
	assert_true(db.weapon("marksman_rifle").range_tiles > rifle.range_tiles * 1.5 and db.weapon("marksman_rifle").damage > rifle.damage * 4.0)
	assert_true(db.weapon("heli_missile").range_tiles >= 20.0 and db.weapon("heli_gun").range_tiles > rifle.range_tiles)
	assert_true(db.weapon("mg").range_tiles > rifle.range_tiles, "a machine gun out-ranges a rifle")
	assert_true(db.unit("helicopter").move_speed > db.unit("tank").move_speed)
	for id in ["howitzer", "mortar_team", "rocket_launcher"]:
		assert_eq(db.unit(id).effective_behavior(), UnitBrain.Behavior.ARTILLERY, id)
	for id in ["marksman", "ifv", "scout"]:
		assert_eq(db.unit(id).effective_behavior(), UnitBrain.Behavior.KITE, id)
	assert_true(db.unit("ifv").move_speed > db.unit("tank").move_speed and db.unit("ifv").armor < db.unit("tank").armor)


func test_every_new_unit_has_a_card_and_art() -> void:
	var db := _get_db()
	for pair in [["scout_jeep", "scout"], ["marksman_team", "marksman"], ["ifv", "ifv"], ["mortar_team", "mortar_team"], ["rocket_launcher", "rocket_launcher"]]:
		var card := db.card(pair[0])
		assert_true(card != null, pair[0])
		assert_eq(card.unit_id, pair[1])
		assert_true(db.unit(pair[1]).sprite != null, "%s has a sprite sheet" % pair[1])


func test_the_roster_test_mission_and_deck_are_valid_and_hold_every_new_card() -> void:
	var db := _get_db()
	var deck := db.deck("roster")
	assert_true(deck != null)
	for id in ["scout_jeep", "marksman_team", "ifv", "mortar_team", "rocket_launcher", "howitzer_battery", "tank"]:
		assert_true(deck.card_ids.has(id), "%s is in the roster deck" % id)
	var ids: Array[String] = []
	ids.assign(deck.card_ids)
	assert_eq(db.deck_rules.validate_deck(ids, db.cards).size(), 0)
	var m := db.mission("dev_roster_range")
	assert_true(m != null and m.deck_id == "roster")
	assert_eq(MissionListing.group_of(m.id), MissionListing.GROUP_TESTS)
