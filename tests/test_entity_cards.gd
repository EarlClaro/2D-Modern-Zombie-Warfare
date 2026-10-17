extends TestCase
## The four entity cards (Minefield, Noise Lure, Barracks, Convoy) in a real battle simulation, and their content rules.

const DT: float = 1.0 / 60.0
const R := CardPlayService.Reason
const P := PlacementRules.Reason
const MISSION := "x5_field_works"
const GOOD := Vector2i(7, 19)  # grass, ~4 tiles from the core
const GOOD2 := Vector2i(7, 21)

var _db: ContentDb
var _made: Array[BattleController] = []


func _get_db() -> ContentDb:
	if _db == null:
		_db = ContentDb.load_from()
		# These tests are about what the buildings and the convoy make and where they settle: pin the rifleman to GUARD
		# (the shipped one kites away from its post since F2; see test_kite.gd). A copy, loaded resources are shared.
		var guard: UnitDefinition = _db.units["rifle_soldier"].duplicate()
		guard.behavior = UnitBrain.Behavior.GUARD
		_db.units["rifle_soldier"] = guard
	return _db


func _battle() -> BattleController:
	var b := BattleController.new()
	b.auto_step = false
	b.setup(_get_db(), _get_db().mission(MISSION), 1)
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


func _snapshot(b: BattleController) -> Array:
	return [b.units.size(), b.points.cp, b.deck.hand.duplicate(), b.deck.discard.duplicate(), b.deck.lockouts.duplicate(), b.mines.count(), b.lures.count()]


func _rock_cell(b: BattleController) -> Vector2i:
	for y in b.mission.map.height():
		for x in b.mission.map.width():
			if not b.mission.map.is_walkable(Vector2i(x, y)):
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func _one_mine() -> FieldEntityDefinition:
	var d := FieldEntityDefinition.new()
	d.id = "one_mine"
	d.display_name = "One"
	d.mine_count = 1
	d.spread_radius = 0.0
	return d


func _barracks(b: BattleController, cell: Vector2i = GOOD) -> BattleUnit:
	_hand(b, ["barracks"] as Array[String])
	b.deck.lockouts.clear()
	assert_true(b.play_card(0, cell).ok)
	return b.units.back()


func _soldiers_of(b: BattleController, maker: BattleUnit) -> Array[BattleUnit]:
	var out: Array[BattleUnit] = []
	for u in b.units:
		if u.maker_uid == maker.uid and u.is_alive():
			out.append(u)
	return out


# --- shipped content --------------------------------------------------------------------------------------------

func test_shipped_entity_cards_and_the_field_works_mission_are_valid() -> void:
	var db := _get_db()
	assert_true(db.is_valid(), "\n".join(db.errors))
	assert_eq(db.card("minefield").card_kind, CardDefinition.CardKind.TRAP)
	assert_eq(db.card("noise_lure").card_kind, CardDefinition.CardKind.INTEL)
	assert_eq(db.card("convoy").card_kind, CardDefinition.CardKind.REINFORCEMENT)
	assert_eq(db.card("barracks").card_kind, CardDefinition.CardKind.DEPLOYMENT)
	assert_eq(db.entity("minefield").entity_kind, FieldEntityDefinition.EntityKind.MINES)
	assert_eq(db.entity("noise_lure").entity_kind, FieldEntityDefinition.EntityKind.LURE)
	var barracks := db.unit("barracks")
	assert_true(barracks.is_spawner() and barracks.structure)
	assert_eq(barracks.spawns_unit_id, "rifle_soldier")
	assert_true(db.deck_rules.validate_deck(db.deck("field_works").ids(), db.cards).is_empty())


func _db_with_card(kind: CardDefinition.CardKind, effect_id: String, unit_id: String = "") -> ContentDb:
	var db := ContentDb.load_from()
	db.errors.clear()
	var c := CardDefinition.new()
	c.id = "probe"
	c.display_name = "Probe"
	c.card_kind = kind
	c.effect_id = effect_id
	c.unit_id = unit_id
	db.add_card(c)
	db.validate_references()
	return db


func _has(errs: PackedStringArray, needle: String) -> bool:
	for e in errs:
		if needle in e:
			return true
	return false


func test_trap_and_intel_cards_must_name_the_right_entity() -> void:
	assert_true(_has(_db_with_card(CardDefinition.CardKind.TRAP, "ghost").errors, "unknown effect_id 'ghost'"))
	assert_true(_has(_db_with_card(CardDefinition.CardKind.TRAP, "noise_lure").errors, "a trap card needs a mine entity"))
	assert_true(_has(_db_with_card(CardDefinition.CardKind.INTEL, "minefield").errors, "an intel card needs a lure entity"))
	assert_true(_db_with_card(CardDefinition.CardKind.TRAP, "minefield").errors.is_empty())
	assert_true(_db_with_card(CardDefinition.CardKind.INTEL, "noise_lure").errors.is_empty())


func test_a_convoy_needs_a_mobile_ground_unit() -> void:
	assert_true(_has(_db_with_card(CardDefinition.CardKind.REINFORCEMENT, "", "helicopter").errors, "must be a mobile ground unit"))
	assert_true(_has(_db_with_card(CardDefinition.CardKind.REINFORCEMENT, "", "gatling_gun").errors, "must be a mobile ground unit"))
	assert_true(_has(_db_with_card(CardDefinition.CardKind.REINFORCEMENT, "", "sandbag_wall").errors, "must be a mobile ground unit"))
	assert_true(_has(_db_with_card(CardDefinition.CardKind.REINFORCEMENT, "", "ghost").errors, "unknown unit_id"))
	assert_true(_db_with_card(CardDefinition.CardKind.REINFORCEMENT, "", "rifle_soldier").errors.is_empty())


func test_a_building_must_make_a_mobile_ground_unit_that_exists() -> void:
	for made in ["ghost", "helicopter", "gatling_gun", "sandbag_wall"]:
		var db := ContentDb.load_from()
		db.errors.clear()
		var u: UnitDefinition = db.unit("barracks").duplicate()
		u.id = "bad_barracks"
		u.spawns_unit_id = made
		db.add_unit(u)
		db.validate_references()
		assert_true(_has(db.errors, "unit 'bad_barracks'"), "making '%s' is an error" % made)


# --- Minefield ---------------------------------------------------------------------------------------------------

func test_minefield_lays_a_patch_spends_cp_and_starts_the_lockout() -> void:
	var b := _battle()
	_hand(b, ["minefield"] as Array[String])
	var res := b.play_card(0, GOOD)
	assert_true(res.ok)
	var ent := b.db.entity("minefield")
	assert_eq(b.mines.count(), ent.mine_count)
	assert_near(b.points.cp, 10.0 - float(b.db.card("minefield").cost))
	assert_true(b.deck.is_locked("minefield"))
	var centre := IsoProjection.cell_center(GOOD)
	for m in b.mines.mines:
		assert_true(m.pos.distance_to(centre) <= ent.spread_radius + 1e-6)
		assert_near(m.damage, ent.mine_damage)
	_release()


func test_minefield_goes_on_roads_and_far_cells_but_not_rock_or_the_core() -> void:
	var b := _battle()
	_hand(b, ["minefield"] as Array[String])
	var far := b.mission.spawn_cells[0]
	assert_true(b.check_card(0, far).ok, "the enemy's own road, far from the base")
	var rock := _rock_cell(b)
	assert_true(rock.x >= 0)
	var r1 := b.play_card(0, rock)
	assert_eq(r1.reason, R.INVALID_TARGET)
	assert_eq(r1.placement, P.NOT_WALKABLE)
	assert_eq(b.play_card(0, b.mission.core_cell).placement, P.OCCUPIED)
	assert_eq(b.play_card(0, Vector2i(-3, 4)).placement, P.OUT_OF_BOUNDS)
	assert_eq(b.mines.count(), 0, "refused plays lay nothing")
	assert_near(b.points.cp, 10.0)
	_release()


func test_field_cards_are_refused_on_scenery_and_the_core_walls() -> void:
	var b := _battle()
	_hand(b, ["minefield", "noise_lure"] as Array[String])
	var cell := Vector2i(10, 15)
	assert_true(b.check_card(0, cell).ok)
	b._scenery_cells.append(cell)
	var res := b.check_card(0, cell)
	assert_eq(res.placement, P.OCCUPIED, "a rock or ruin is in the way")
	assert_eq(b.check_card(1, cell).placement, P.OCCUPIED)
	_release()


func test_a_mine_blasts_the_enemy_that_steps_near_and_is_used_up() -> void:
	var b := _battle()
	var centre := IsoProjection.cell_center(GOOD)
	b.mines.add_patch(centre, _one_mine())
	var e := _enemy_at(b, centre + Vector2(0.3, 0.0))
	var hp := e.health.hp
	b.step(DT)
	assert_eq(b.mines.count(), 0)
	assert_true(not is_instance_valid(e) or e.health.hp < hp, "the blast hurt it")
	b.step(DT)
	assert_eq(b.mines.count(), 0)
	_release()


func test_a_mine_ignores_far_enemies_and_friendly_units() -> void:
	var b := _battle()
	var centre := IsoProjection.cell_center(GOOD)
	b.mines.add_patch(centre, _one_mine())
	_enemy_at(b, centre + Vector2(3.0, 0.0))
	b._spawn_unit_at("gatling_gun", centre + Vector2(0.1, 0.0))
	b.step(DT)
	assert_eq(b.mines.count(), 1)
	_release()


func test_one_blast_can_hurt_a_crowd_but_only_the_mines_that_are_stepped_on_go_off() -> void:
	var b := _battle()
	var a := IsoProjection.cell_center(GOOD)
	var far := a + Vector2(6.0, 0.0)
	b.mines.add_patch(a, _one_mine())
	b.mines.add_patch(far, _one_mine())
	var e1 := _enemy_at(b, a + Vector2(0.2, 0.0))
	var e2 := _enemy_at(b, a + Vector2(-0.2, 0.2))
	var hp1 := e1.health.hp
	var hp2 := e2.health.hp
	b.step(DT)
	assert_eq(b.mines.count(), 1, "the far mine is still there")
	assert_true(not is_instance_valid(e1) or e1.health.hp < hp1, "the first took the blast (or died of it)")
	assert_true(not is_instance_valid(e2) or e2.health.hp < hp2, "so did the second")
	_release()


func test_mines_and_lures_are_gone_after_a_restart() -> void:
	var b := _battle()
	_hand(b, ["minefield", "noise_lure"] as Array[String])
	b.play_card(0, GOOD)
	b.play_card(0, GOOD2)
	assert_true(b.mines.count() > 0 and b.lures.count() == 1)
	b.restart()
	assert_eq(b.mines.count(), 0)
	assert_eq(b.lures.count(), 0)
	_release()


func test_the_minefield_preview_shows_every_mine_and_the_lure_preview_its_reach() -> void:
	var b := _battle()
	_hand(b, ["minefield", "noise_lure"] as Array[String])
	b.select_slot(0)
	var p := b.targeting.preview(b, GOOD)
	assert_true(p.valid)
	assert_eq(p.ground_points.size(), b.db.entity("minefield").mine_count)
	assert_near(p.area_radius, b.db.entity("minefield").spread_radius + b.db.entity("minefield").mine_blast_radius)
	b.select_slot(0)
	b.select_slot(1)
	var q := b.targeting.preview(b, GOOD)
	assert_near(q.area_radius, b.db.entity("noise_lure").lure_radius)
	assert_true(b.targeting.preview(b, _rock_cell(b)).message != "")
	_release()


# --- Noise Lure --------------------------------------------------------------------------------------------------

func test_noise_lure_sets_up_a_decoy_on_the_aimed_cell() -> void:
	var b := _battle()
	_hand(b, ["noise_lure"] as Array[String])
	assert_true(b.play_card(0, GOOD).ok)
	assert_eq(b.lures.count(), 1)
	var l := b.lures.lures[0]
	assert_eq(l.pos, IsoProjection.cell_center(GOOD))
	assert_near(l.radius, b.db.entity("noise_lure").lure_radius)
	assert_near(l.time_left, b.db.entity("noise_lure").lure_duration_s)
	assert_near(b.points.cp, 10.0 - float(b.db.card("noise_lure").cost))
	_release()


func test_a_refused_lure_changes_nothing() -> void:
	var b := _battle()
	_hand(b, ["noise_lure"] as Array[String], 1.0)
	var before := _snapshot(b)
	assert_eq(b.play_card(0, GOOD).reason, R.INSUFFICIENT_CP)
	assert_eq(_snapshot(b), before)
	b.points.cp = 10.0
	before = _snapshot(b)
	assert_eq(b.play_card(0, _rock_cell(b)).reason, R.INVALID_TARGET)
	assert_eq(_snapshot(b), before)
	_release()


func test_enemies_with_nothing_to_attack_walk_to_the_lure_and_stand_near_it() -> void:
	var b := _battle()
	var start := IsoProjection.cell_center(Vector2i(12, 6))
	var lure := IsoProjection.cell_center(Vector2i(16, 6))  # the enemy's own path points the other way (toward the core)
	b.lures.add(lure, 9.0, 60.0)
	var e := _enemy_at(b, start)
	_run_for(b, 8.0)
	assert_true(e.ground_pos.x > start.x + 1.0, "walked east, toward the lure")
	assert_true(e.ground_pos.distance_to(lure) <= BattleController.LURE_STAND + 5.0 * 0.2 + 0.01, "and stopped near it")
	var parked := e.ground_pos
	_run_for(b, 2.0)
	assert_vec_near(e.ground_pos, parked, 0.01, "it waits there while the lure lasts")
	_release()


func test_an_enemy_does_not_walk_to_a_lure_through_blocked_ground() -> void:
	var b := _battle()
	var start := IsoProjection.cell_center(Vector2i(12, 6))
	b.lures.add(IsoProjection.cell_center(Vector2i(16, 6)), 9.0, 60.0)
	for y in range(3, 12):
		for x in [14, 15]:
			b._blocked_cells[Vector2i(x, y)] = true  # a wall of scenery between it and the lure
	var e := _enemy_at(b, start)
	_run_for(b, 3.0)
	assert_true(e.ground_pos.x < start.x, "it kept to its own way, west and south")
	assert_true(not e.lure_clear)
	_release()


func test_an_enemy_outside_the_lure_radius_is_not_steered() -> void:
	var b := _battle()
	b.lures.add(Vector2(5, 5), 9.0, 60.0)
	var e := _enemy_at(b, Vector2(20, 5))
	assert_true(not b._steer_to_lure(e, DT))
	assert_true(not e.lure_clear)
	_release()


func test_an_enemy_that_is_attacking_is_not_pulled_away() -> void:
	var b := _battle()
	var spot := IsoProjection.cell_center(Vector2i(12, 6))
	b.lures.add(IsoProjection.cell_center(Vector2i(16, 6)), 9.0, 60.0)
	b._spawn_unit_at("sandbag_wall", spot)
	var e := _enemy_at(b, spot + Vector2(0.5, 0.0))
	var at := e.ground_pos
	_run_for(b, 2.0)
	assert_vec_near(e.ground_pos, at, 1e-6, "busy with the wall")
	_release()


func test_when_the_lure_runs_out_enemies_go_back_to_their_path() -> void:
	var b := _battle()
	var start := IsoProjection.cell_center(Vector2i(12, 6))
	b.lures.add(IsoProjection.cell_center(Vector2i(16, 6)), 9.0, 5.0)
	var e := _enemy_at(b, start)
	_run_for(b, 5.5)
	assert_true(b.lures.is_empty())
	var at := e.ground_pos
	_run_for(b, 3.0)
	assert_true(e.ground_pos.distance_to(at) > 1.0, "walking again")
	assert_true(not e.lure_clear)
	assert_true(e.ground_pos.x < at.x, "toward the core, which lies west of it")
	_release()


# --- Barracks ----------------------------------------------------------------------------------------------------

func test_a_barracks_makes_a_rifle_soldier_every_twelve_seconds() -> void:
	var b := _battle()
	var br := _barracks(b)
	assert_true(br.spawner != null)
	_run_for(b, 11.5)
	assert_eq(_soldiers_of(b, br).size(), 0)
	_run_for(b, 1.0)
	var made := _soldiers_of(b, br)
	assert_eq(made.size(), 1)
	assert_eq(made[0].def.id, "rifle_soldier")
	assert_true(made[0].ground_pos.distance_to(br.ground_pos) < 2.5, "beside the building")
	assert_vec_near(made[0].anchor, made[0].ground_pos, 1e-6, "it guards where it appeared")
	_run_for(b, 12.0)
	assert_eq(_soldiers_of(b, br).size(), 2)
	_release()


func test_a_barracks_stops_at_its_cap_and_replaces_a_loss_after_a_full_interval() -> void:
	var b := _battle()
	var br := _barracks(b)
	_run_for(b, 40.0)
	var made := _soldiers_of(b, br)
	assert_eq(made.size(), 3)
	_run_for(b, 30.0)
	assert_eq(_soldiers_of(b, br).size(), 3, "capped")
	made[0].health.take_damage(1e9)
	b.step(DT)
	assert_eq(_soldiers_of(b, br).size(), 2)
	_run_for(b, 11.0)
	assert_eq(_soldiers_of(b, br).size(), 2, "not yet: a full interval from the loss")
	_run_for(b, 1.5)
	assert_eq(_soldiers_of(b, br).size(), 3)
	_release()


func test_each_barracks_counts_only_its_own_soldiers() -> void:
	var b := _battle()
	var a := _barracks(b, GOOD)
	var c := _barracks(b, GOOD2)
	_run_for(b, 40.0)
	assert_eq(_soldiers_of(b, a).size(), 3)
	assert_eq(_soldiers_of(b, c).size(), 3)
	_release()


func test_a_destroyed_barracks_makes_nothing_more_but_its_soldiers_stay() -> void:
	var b := _battle()
	var br := _barracks(b)
	_run_for(b, 13.0)
	var made := _soldiers_of(b, br)
	assert_eq(made.size(), 1)
	br.health.take_damage(1e9)
	b.step(DT)
	assert_true(not is_instance_valid(br) or not br.is_alive(), "the building is gone")
	_run_for(b, 30.0)
	var alive := 0
	for u in b.units:
		if u.def.id == "rifle_soldier" and u.is_alive():
			alive += 1
	assert_eq(alive, 1, "the one it made is still there and no more came")
	_release()


func test_a_boxed_in_barracks_waits_without_error() -> void:
	var b := _battle()
	var br := _barracks(b)
	for y in b.mission.map.height():
		for x in b.mission.map.width():
			b._blocked_cells[Vector2i(x, y)] = true
	_run_for(b, 13.0)
	assert_eq(_soldiers_of(b, br).size(), 0)
	_release()


func test_the_barracks_card_is_a_normal_placed_structure() -> void:
	var b := _battle()
	_hand(b, ["barracks"] as Array[String])
	assert_true(not b.play_card(0, b.mission.core_cell).ok, "not on the core")
	assert_true(b.play_card(0, GOOD).ok)
	assert_near(b.points.cp, 10.0 - float(b.db.card("barracks").cost))
	var far := _battle()
	_hand(far, ["barracks"] as Array[String])
	assert_true(far.play_card(0, Vector2i(14, 8)).ok, "anywhere on the map (F1: no deploy circle)")
	_release()


# --- Convoy ------------------------------------------------------------------------------------------------------

func test_a_convoy_plays_on_the_click_and_arrives_at_a_map_edge() -> void:
	var b := _battle()
	_hand(b, ["convoy"] as Array[String])
	b.select_slot(0)
	assert_true(not b.targeting.is_selecting(), "no cell to aim")
	assert_eq(b.units.size(), 4)
	assert_near(b.points.cp, 10.0 - float(b.db.card("convoy").cost))
	assert_true(b.deck.is_locked("convoy"))
	var w := float(b.mission.map.width())
	var h := float(b.mission.map.height())
	for u in b.units:
		assert_eq(u.def.id, "rifle_soldier")
		var on_edge := u.ground_pos.x < 1.5 or u.ground_pos.y < 1.5 or u.ground_pos.x > w - 1.5 or u.ground_pos.y > h - 1.5
		assert_true(on_edge, "at %s" % str(u.ground_pos))
	_release()


func test_a_convoy_walks_to_its_spot_near_the_base_by_itself() -> void:
	var b := _battle()
	_hand(b, ["convoy"] as Array[String])
	b.play_card(0, Vector2i.ZERO)
	var core := b.core.ground_pos
	var toward_enemy := (IsoProjection.cell_center(b.mission.spawn_cells[0]) - core).normalized()
	for u in b.units:
		assert_true((u.anchor - core).normalized().dot(toward_enemy) > 0.9, "settles on the enemy's side of the base")
	for u in b.units:
		var d := u.anchor.distance_to(core)
		assert_true(d > 3.0 and d < 4.2, "settles about %s tiles from the core (%s)" % [str(BattleController.CONVOY_SETTLE_DIST), str(d)])
	_run_for(b, 45.0)
	for u in b.units:
		assert_true(u.ground_pos.distance_to(u.anchor) < 0.4, "arrived: %s vs %s" % [str(u.ground_pos), str(u.anchor)])
	_release()


func test_a_convoy_with_no_clear_route_is_refused_and_changes_nothing() -> void:
	var b := _battle()
	_hand(b, ["convoy"] as Array[String])
	for y in b.mission.map.height():
		for x in b.mission.map.width():
			b._blocked_cells[Vector2i(x, y)] = true
	var before := _snapshot(b)
	var res := b.play_card(0, Vector2i.ZERO)
	assert_eq(res.reason, R.INVALID_TARGET)
	assert_eq(res.placement, P.NO_ROUTE)
	assert_eq(_snapshot(b), before)
	assert_eq(CardTargeting.message_for(res), PlacementRules.describe(P.NO_ROUTE))
	var rejected: Array = []
	b.card_rejected.connect(func(slot: int, r: CardPlayService.Result) -> void: rejected.append([slot, r.placement]))
	b.select_slot(0)
	assert_eq(rejected, [[0, P.NO_ROUTE]])
	_release()


func test_a_convoy_squad_fights_when_the_enemy_comes() -> void:
	var b := _battle()
	_hand(b, ["convoy"] as Array[String])
	b.play_card(0, Vector2i.ZERO)
	_run_for(b, 45.0)
	var e := _enemy_at(b, b.units[0].ground_pos + Vector2(4.0, 0.0))
	var hp := e.health.hp
	_run_for(b, 2.0)
	assert_true(not is_instance_valid(e) or e.health.hp < hp, "they shot at it")
	_release()
