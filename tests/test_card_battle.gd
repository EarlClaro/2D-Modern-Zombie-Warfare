extends TestCase
## Card plays inside a real battle simulation (orphan controller, stepped manually).

const DT: float = 1.0 / 60.0
const MISSION_ID := "m2_card_defense"
const GOOD := Vector2i(7, 19)  # grass, ~4 tiles from the core
const GOOD2 := Vector2i(7, 21)
const R := CardPlayService.Reason

var _db: ContentDb
var _made: Array[BattleController] = []


func _get_db() -> ContentDb:
	if _db == null:
		_db = ContentDb.load_from()
	return _db


func _battle(mission_id: String = MISSION_ID, seed_value: int = 1) -> BattleController:
	var b := BattleController.new()
	b.auto_step = false
	b.setup(_get_db(), _get_db().mission(mission_id), seed_value)
	_made.append(b)
	return b


func _release() -> void:
	for b in _made:
		b.free()
	_made.clear()


## Puts exact cards in the hand and plenty of CP so a test controls what it plays.
func _hand(b: BattleController, ids: Array[String], cp: float = 10.0) -> void:
	b.deck.hand = ids
	b.points.cp = cp


func _run_for(b: BattleController, seconds: float) -> void:
	for i in int(round(seconds / DT)):
		b.step(DT)


func _inject_enemy(b: BattleController, pos: Vector2) -> BattleEnemy:
	b._spawn_enemy(b.mission.waves[0])
	var e: BattleEnemy = b.enemies.back()
	e.ground_pos = pos
	return e


func _snapshot(b: BattleController) -> Array:
	return [b.units.size(), b.points.cp, b.deck.hand.duplicate(), b.deck.discard.duplicate(), b.deck.lockouts.duplicate()]


# --- setup ------------------------------------------------------------------------------------------------

func test_card_mission_has_a_deck_and_no_pre_placed_defenders() -> void:
	var b := _battle()
	assert_true(b.has_cards())
	assert_eq(b.units.size(), 0)
	assert_eq(b.deck.hand.size(), 4)
	assert_near(b.points.cp, 5.0)
	_release()


func test_missions_without_a_deck_have_no_cards() -> void:
	var b := _battle("m1_hold_the_crossing")
	assert_true(not b.has_cards())
	var res := b.play_card(0, GOOD)
	assert_eq(res.reason, R.UNAVAILABLE)
	assert_eq(b.units.size(), 2, "only the pre-placed units")
	_release()


func test_economy_ticks_with_the_simulation() -> void:
	var b := _battle()
	b.points.cp = 0.0
	_run_for(b, 3.0)
	assert_near(b.points.cp, 2.0, 0.02, "3 s at 1 CP / 1.5 s")
	assert_eq(b.deck.hand.size(), 4)
	_run_for(b, 1.0)
	assert_eq(b.deck.hand.size(), 5, "first periodic draw at 4 s")
	_release()


# --- deployment -------------------------------------------------------------------------------------------

func test_rifle_squad_spawns_three_soldiers_in_the_cell_and_spends_cp() -> void:
	var b := _battle()
	_hand(b, ["rifle_squad", "tank"] as Array[String], 5.0)
	var played: Array = []
	b.card_played.connect(func(c: CardDefinition, cell: Vector2i): played.append([c.id, cell]))
	var res := b.play_card(0, GOOD)
	assert_true(res.ok)
	assert_eq(b.units.size(), 3)
	for u in b.units:
		assert_eq(u.def.id, "rifle_soldier")
		assert_eq(IsoProjection.cell_of(u.ground_pos), GOOD, "all three stand in the chosen cell")
	assert_true(b.units[0].ground_pos != b.units[1].ground_pos and b.units[1].ground_pos != b.units[2].ground_pos and b.units[0].ground_pos != b.units[2].ground_pos, "squad members do not stack on one point")
	assert_near(b.points.cp, 3.0, 1e-9)
	assert_eq(b.deck.hand, ["tank"] as Array[String])
	assert_eq(b.deck.discard, ["rifle_squad"] as Array[String])
	assert_eq(played, [["rifle_squad", GOOD]])
	_release()


func test_gatling_and_tank_deploy_the_right_units() -> void:
	var b := _battle()
	_hand(b, ["gatling_gun", "tank"] as Array[String])
	assert_true(b.play_card(0, GOOD).ok)
	assert_true(b.play_card(0, GOOD2).ok)
	assert_eq(b.units.size(), 2)
	assert_eq(b.units[0].def.id, "gatling_gun")
	assert_true(b.units[0].def.is_fixed())
	assert_eq(b.units[1].def.id, "tank")
	assert_true(not b.units[1].def.is_fixed())
	assert_true(b.deck.is_locked("tank"), "tank lockout started")
	_release()


func test_invalid_cells_reject_without_any_change() -> void:
	var b := _battle()
	var cases: Array = [
		[Vector2i(5, 19), PlacementRules.Reason.NOT_BUILDABLE],
		[Vector2i(10, 21), PlacementRules.Reason.NOT_BUILDABLE],
		[Vector2i(20, 12), PlacementRules.Reason.TOO_FAR_FROM_CORE],
		[Vector2i(-3, 4), PlacementRules.Reason.OUT_OF_BOUNDS],
		[b.mission.core_cell, PlacementRules.Reason.NOT_BUILDABLE],
	]
	for case in cases:
		_hand(b, ["rifle_squad"] as Array[String])
		var before := _snapshot(b)
		var res := b.play_card(0, case[0])
		assert_eq(res.reason, R.INVALID_TARGET, str(case[0]))
		assert_eq(res.placement, case[1], str(case[0]))
		assert_eq(_snapshot(b), before, "state unchanged for %s" % str(case[0]))
	_release()


func test_occupied_cell_is_rejected_then_a_neighbour_works() -> void:
	var b := _battle()
	_hand(b, ["rifle_squad", "rifle_squad", "rifle_squad"] as Array[String])
	assert_true(b.play_card(0, GOOD).ok)
	var before := _snapshot(b)
	var res := b.play_card(0, GOOD)
	assert_eq(res.placement, PlacementRules.Reason.OCCUPIED)
	assert_eq(_snapshot(b), before)
	assert_true(b.play_card(0, GOOD2).ok)
	_release()


func test_a_unit_that_walked_away_frees_its_cell() -> void:
	var b := _battle()
	_hand(b, ["rifle_squad", "rifle_squad"] as Array[String])
	b.play_card(0, GOOD)
	for u in b.units:
		u.ground_pos = Vector2(12.5, 12.5)
	assert_true(b.play_card(0, GOOD).ok, "occupancy follows where units are now")
	_release()


func test_not_enough_cp_keeps_the_card() -> void:
	var b := _battle()
	_hand(b, ["tank"] as Array[String], 5.0)
	var before := _snapshot(b)
	var res := b.play_card(0, GOOD)
	assert_eq(res.reason, R.INSUFFICIENT_CP)
	assert_eq(_snapshot(b), before)
	_release()


func test_lockout_blocks_a_second_tank_until_it_expires() -> void:
	var b := _battle()
	_hand(b, ["tank", "tank"] as Array[String])
	assert_true(b.play_card(0, GOOD).ok)
	b.points.cp = 10.0
	assert_eq(b.play_card(0, GOOD2).reason, R.LOCKED_OUT)
	b.deck.tick(20.0)
	b.points.cp = 10.0
	assert_true(b.play_card(0, GOOD2).ok)
	_release()


func test_empty_slot_is_ignored() -> void:
	var b := _battle()
	_hand(b, ["rifle_squad"] as Array[String])
	var before := _snapshot(b)
	assert_eq(b.play_card(3, GOOD).reason, R.EMPTY_SLOT)
	assert_eq(b.play_card(-1, GOOD).reason, R.EMPTY_SLOT)
	assert_eq(_snapshot(b), before)
	_release()


func test_operation_and_sortie_cards_are_refused_without_spending_until_they_exist() -> void:
	# Interim (M2.2): artillery arrives in 2.4 and the helicopter in 2.5; this test changes then.
	var b := _battle()
	_hand(b, ["artillery_strike", "helicopter_support"] as Array[String])
	var before := _snapshot(b)
	assert_eq(b.play_card(0, GOOD).reason, R.UNAVAILABLE)
	assert_eq(b.play_card(1, GOOD).reason, R.UNAVAILABLE)
	assert_eq(_snapshot(b), before)
	_release()


func test_no_plays_after_the_battle_ended() -> void:
	var b := _battle()
	_hand(b, ["rifle_squad"] as Array[String])
	b._rules.evaluate(0.0, b.elapsed)  # core destroyed -> defeat
	assert_true(b.is_ended())
	var before := _snapshot(b)
	assert_eq(b.play_card(0, GOOD).reason, R.UNAVAILABLE)
	assert_eq(_snapshot(b), before)
	_release()


func test_check_card_never_changes_state() -> void:
	var b := _battle()
	_hand(b, ["rifle_squad"] as Array[String])
	var before := _snapshot(b)
	assert_true(b.check_card(0, GOOD).ok)
	assert_eq(b.check_card(0, Vector2i(5, 19)).placement, PlacementRules.Reason.NOT_BUILDABLE)
	assert_eq(_snapshot(b), before)
	_release()


# --- combat of the new units -----------------------------------------------------------------------------

func test_tank_blast_hits_a_cluster_with_falloff_and_spares_the_rest() -> void:
	var b := _battle()
	_hand(b, ["tank"] as Array[String])
	b.play_card(0, GOOD)
	var tank_pos := IsoProjection.cell_center(GOOD)
	var near := _inject_enemy(b, tank_pos + Vector2(3.0, 0.0))
	var side := _inject_enemy(b, tank_pos + Vector2(3.6, 0.0))
	var far := _inject_enemy(b, tank_pos + Vector2(5.5, 0.0))
	var cannon := b.db.weapon("tank_cannon")
	var blasts: Array = []
	b.blast_landed.connect(func(c: Vector2, r: float): blasts.append([c, r]))
	b.step(DT)
	# Enemies move only in the enemy phase, before the units fire, so end-of-tick positions are the firing positions.
	var center := near.ground_pos
	assert_eq(blasts.size(), 1)
	assert_vec_near(blasts[0][0], center)
	assert_near(blasts[0][1], cannon.blast_radius)
	assert_near(near.health.hp, 60.0 - DamageService.compute(cannon.damage, 0.0, 1.0), 1e-3, "centre takes full damage")
	var f := DamageService.blast_falloff(side.ground_pos.distance_to(center), cannon.blast_radius)
	assert_true(f > 0.25 and f < 1.0, "the neighbour is inside the radius")
	assert_near(side.health.hp, 60.0 - DamageService.compute(cannon.damage, 0.0, f), 1e-3, "neighbour takes falloff damage")
	assert_near(far.health.hp, 60.0, 1e-9, "outside the radius takes nothing")
	_release()


func test_blast_never_hurts_player_units() -> void:
	var b := _battle()
	_hand(b, ["tank", "rifle_squad"] as Array[String])
	b.play_card(0, GOOD)
	b.play_card(0, GOOD2)
	var tank_pos := IsoProjection.cell_center(GOOD)
	_inject_enemy(b, tank_pos + Vector2(2.0, 0.3))
	var hp_before: Array[float] = []
	for u in b.units:
		hp_before.append(u.health.hp)
	b.step(DT)
	for i in b.units.size():
		assert_near(b.units[i].health.hp, hp_before[i], 1e-9, "no friendly fire")
	_release()


func test_tank_armor_reduces_enemy_hits_but_soldiers_have_none() -> void:
	var b := _battle()
	_hand(b, ["tank", "rifle_squad"] as Array[String])
	b.play_card(0, GOOD)
	b.points.cp = 10.0
	b.play_card(0, GOOD2)
	var tank: BattleUnit = b.units[0]
	var soldier: BattleUnit = b.units[1]
	assert_eq(tank.def.id, "tank")
	var dmg := b.db.enemy("shambler").attack_damage
	_inject_enemy(b, tank.ground_pos + Vector2(0.4, 0.0))
	_inject_enemy(b, soldier.ground_pos + Vector2(0.4, 0.0))
	# The enemy phase runs before the units shoot, so each enemy lands its first attack this tick.
	var tank_hp := tank.health.hp
	var soldier_hp := soldier.health.hp
	b.step(DT)
	assert_near(tank_hp - tank.health.hp, DamageService.compute(dmg, tank.def.armor), 1e-6)
	assert_near(soldier_hp - soldier.health.hp, dmg, 1e-6)
	assert_true(tank_hp - tank.health.hp < dmg, "armor helps")
	_release()


# --- determinism and restart -----------------------------------------------------------------------------

func test_playing_cards_does_not_change_where_enemies_spawn() -> void:
	# The deck has its own RNG, so a card play never shifts the spawn jitter stream.
	var a := _battle(MISSION_ID, 7)
	var c := _battle(MISSION_ID, 7)
	_hand(c, ["rifle_squad"] as Array[String])
	c.play_card(0, GOOD)
	# Force a reshuffle too: that is the one deck action that consumes random numbers mid-battle.
	c.deck.discard.append_array(c.deck.draw_pile)
	c.deck.draw_pile.clear()
	assert_true(c.deck.draw_one())
	for b in [a, c]:
		while b.enemy_count() == 0:
			b.step(DT)
	assert_vec_near(a.enemies[0].ground_pos, c.enemies[0].ground_pos, 1e-6)
	_release()


func test_same_seed_same_opening_hand_different_seed_differs() -> void:
	var a := _battle(MISSION_ID, 11)
	var b := _battle(MISSION_ID, 11)
	var c := _battle(MISSION_ID, 12)
	assert_eq(a.deck.hand, b.deck.hand)
	assert_eq(a.deck.draw_pile, b.deck.draw_pile)
	assert_true(a.deck.hand != c.deck.hand or a.deck.draw_pile != c.deck.draw_pile)
	_release()


func test_restart_rebuilds_the_deck_and_removes_deployed_units() -> void:
	var b := _battle(MISSION_ID, 5)
	var opening: Array[String] = b.deck.hand.duplicate()
	_hand(b, ["rifle_squad"] as Array[String])
	b.play_card(0, GOOD)
	_run_for(b, 2.0)
	b.restart()
	assert_eq(b.units.size(), 0)
	assert_eq(b.deck.hand, opening, "same seed -> same opening hand")
	assert_eq(b.deck.discard.size(), 0)
	assert_near(b.points.cp, 5.0)
	assert_true(not b.deck.is_locked("rifle_squad"))
	_release()


func test_deployed_squad_fights_and_kills() -> void:
	# End-to-end: cards -> units -> targeting -> damage -> kills.
	var b := _battle()
	_hand(b, ["rifle_squad"] as Array[String])
	b.play_card(0, GOOD)
	_inject_enemy(b, IsoProjection.cell_center(GOOD) + Vector2(4.0, 0.0))
	_run_for(b, 4.0)
	assert_true(b.stats["kills"] >= 1)
	assert_true(b.stats["shots"] > 0)
	_release()
