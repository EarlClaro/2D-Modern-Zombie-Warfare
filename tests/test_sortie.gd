extends TestCase
## The helicopter sortie: route planning, the flight state machine, and the whole card -> fly in -> strafe ->
## leave chain inside a battle simulation.

const DT: float = 1.0 / 60.0
const R := CardPlayService.Reason
const TARGET := Vector2i(12, 12)

var _db: ContentDb
var _made: Array[BattleController] = []


func _get_db() -> ContentDb:
	if _db == null:
		_db = ContentDb.load_from()
	return _db


func _battle(seed_value: int = 1) -> BattleController:
	var b := BattleController.new()
	b.auto_step = false
	b.setup(_get_db(), _get_db().mission("m2_card_defense"), seed_value)
	_made.append(b)
	return b


func _release() -> void:
	for b in _made:
		b.free()
	_made.clear()


func _arm(b: BattleController, cp: float = 10.0) -> void:
	b.deck.hand = ["helicopter_support", "helicopter_support"] as Array[String]
	b.points.cp = cp


func _run_for(b: BattleController, seconds: float) -> void:
	for i in int(round(seconds / DT)):
		b.step(DT)


func _inject_enemy(b: BattleController, pos: Vector2) -> BattleEnemy:
	b._spawn_enemy(b.mission.waves[0])
	var e: BattleEnemy = b.enemies.back()
	e.ground_pos = pos
	return e


func _heli(b: BattleController) -> BattleAircraft:
	for u in b.units:
		if u is BattleAircraft:
			return u
	return null


func _has(errs: PackedStringArray, needle: String) -> bool:
	for e in errs:
		if needle in e:
			return true
	return false


# --- route planning ---------------------------------------------------------------------------------------------

func test_the_nearest_edge_is_chosen_and_the_exit_is_the_opposite_side() -> void:
	var w := 24.0
	var h := 24.0
	var left := SortiePlan.plan(w, h, Vector2(3, 10), 5.0)
	assert_eq(left.edge, SortiePlan.Edge.LEFT)
	assert_vec_near(left.entry, Vector2(-5, 10))
	assert_vec_near(left.exit, Vector2(29, 10))
	var right := SortiePlan.plan(w, h, Vector2(21, 8), 5.0)
	assert_eq(right.edge, SortiePlan.Edge.RIGHT)
	assert_vec_near(right.entry, Vector2(29, 8))
	assert_vec_near(right.exit, Vector2(-5, 8))
	var top := SortiePlan.plan(w, h, Vector2(10, 2), 5.0)
	assert_eq(top.edge, SortiePlan.Edge.TOP)
	assert_vec_near(top.entry, Vector2(10, -5))
	assert_vec_near(top.exit, Vector2(10, 29))
	var bottom := SortiePlan.plan(w, h, Vector2(9, 22), 5.0)
	assert_eq(bottom.edge, SortiePlan.Edge.BOTTOM)
	assert_vec_near(bottom.entry, Vector2(9, 29))
	assert_vec_near(bottom.exit, Vector2(9, -5))


func test_the_station_is_the_target_and_entry_and_exit_are_off_the_map() -> void:
	for target in [Vector2(0.5, 0.5), Vector2(23.5, 23.5), Vector2(12, 12), Vector2(5, 19)]:
		var p := SortiePlan.plan(24.0, 24.0, target, 4.0)
		assert_vec_near(p.station, target)
		for pt in [p.entry, p.exit]:
			assert_true(pt.x < 0.0 or pt.x > 24.0 or pt.y < 0.0 or pt.y > 24.0, "%s is outside the map" % str(pt))


func test_exact_ties_go_to_the_first_edge_in_order() -> void:
	assert_eq(SortiePlan.plan(24.0, 24.0, Vector2(12, 12), 5.0).edge, SortiePlan.Edge.LEFT, "all four equal")
	assert_eq(SortiePlan.plan(24.0, 24.0, Vector2(12, 3), 5.0).edge, SortiePlan.Edge.TOP)
	assert_eq(SortiePlan.plan(24.0, 24.0, Vector2(21, 12), 5.0).edge, SortiePlan.Edge.RIGHT, "right (3) beats top/bottom at 12")
	assert_eq(SortiePlan.plan(24.0, 24.0, Vector2(12, 21), 5.0).edge, SortiePlan.Edge.BOTTOM)


func test_a_rectangular_map_uses_both_dimensions() -> void:
	var p := SortiePlan.plan(40.0, 10.0, Vector2(20, 7), 3.0)
	assert_eq(p.edge, SortiePlan.Edge.BOTTOM, "10 - 7 = 3 is the shortest")
	assert_vec_near(p.entry, Vector2(20, 13))
	assert_vec_near(p.exit, Vector2(20, -3))


# --- flight state machine -----------------------------------------------------------------------------------------

func test_flight_goes_through_its_phases_in_order() -> void:
	var f := SortieFlight.new(2.0)
	assert_eq(f.phase, SortieFlight.Phase.ENTERING)
	assert_eq(f.update(0.1, true), SortieFlight.Phase.ENTERING, "still flying in")
	assert_eq(f.update(0.1, false), SortieFlight.Phase.ON_STATION, "arrived")
	assert_eq(f.update(1.0, false), SortieFlight.Phase.ON_STATION)
	assert_eq(f.update(1.0, false), SortieFlight.Phase.LEAVING, "station time used up")
	assert_eq(f.update(0.1, true), SortieFlight.Phase.LEAVING, "flying out")
	assert_eq(f.update(0.1, false), SortieFlight.Phase.DONE)
	assert_eq(f.update(5.0, false), SortieFlight.Phase.DONE, "done stays done")


func test_station_time_only_runs_while_on_station() -> void:
	var f := SortieFlight.new(1.0)
	f.update(100.0, true)  # a long approach does not eat the station time
	assert_near(f.station_left, 1.0)
	f.update(0.0, false)
	assert_eq(f.phase, SortieFlight.Phase.ON_STATION)
	assert_near(f.station_left, 1.0)


func test_station_time_ends_on_time_in_small_steps() -> void:
	for delta in [1.0 / 60.0, 1.0 / 30.0, 0.1, 1.0 / 120.0]:
		var f := SortieFlight.new(12.0)
		f.update(0.0, false)
		var steps := int(round(12.0 / delta))
		for i in steps - 1:
			f.update(delta, false)
		assert_eq(f.phase, SortieFlight.Phase.ON_STATION, "not before 12 s (delta %s)" % str(delta))
		f.update(delta, false)
		assert_eq(f.phase, SortieFlight.Phase.LEAVING, "exactly at 12 s (delta %s)" % str(delta))


func test_arriving_with_no_distance_to_fly_goes_straight_to_station() -> void:
	var f := SortieFlight.new(3.0)
	assert_eq(f.update(0.016, false), SortieFlight.Phase.ON_STATION)


# --- data ---------------------------------------------------------------------------------------------------------

func test_shipped_helicopter_data() -> void:
	var db := _get_db()
	assert_true(db.is_valid(), "\n".join(db.errors))
	var unit := db.unit("helicopter")
	assert_true(unit.is_air())
	assert_true(unit.flight_altitude() > 0.0)
	assert_near(db.unit("tank").flight_altitude(), 0.0)
	assert_true(db.card("helicopter_support").station_time_s > 0.0)
	assert_true(UnitDefinition.HIGH_AIR_ALTITUDE > UnitDefinition.LOW_AIR_ALTITUDE)


func test_a_sortie_card_needs_a_station_time() -> void:
	var c := CardDefinition.new()
	c.id = "air_card"
	c.display_name = "Air"
	c.card_kind = CardDefinition.CardKind.SORTIE
	c.unit_id = "helicopter"
	assert_true(_has(c.validate(), "station_time_s"))
	c.station_time_s = 8.0
	assert_eq(c.validate().size(), 0)


# --- in a battle ---------------------------------------------------------------------------------------------------

func test_playing_the_card_spends_cp_locks_out_and_launches_an_aircraft_from_off_the_map() -> void:
	var b := _battle()
	_arm(b)
	var res := b.play_card(0, TARGET)
	assert_true(res.ok)
	assert_near(b.points.cp, 10.0 - b.db.card("helicopter_support").cost, 1e-9)
	assert_true(b.deck.is_locked("helicopter_support"))
	var h := _heli(b)
	assert_true(h != null)
	assert_eq(b.sorties.size(), 1)
	var g := h.ground_pos
	assert_true(g.x < 0.0 or g.x > 24.0 or g.y < 0.0 or g.y > 24.0, "starts outside the map (%s)" % str(g))
	assert_near(h.altitude, b.db.unit("helicopter").flight_altitude())
	_release()


func test_the_aircraft_node_is_lifted_but_its_ground_position_and_shadow_are_not() -> void:
	var b := _battle()
	_arm(b)
	b.play_card(0, TARGET)
	var h := _heli(b)
	assert_vec_near(h.position, IsoProjection.ground_to_screen_z(h.ground_pos, h.altitude), 1e-4, "drawn in the air")
	assert_true(h.position.y < IsoProjection.ground_to_screen(h.ground_pos).y, "above the ground point on screen")
	_run_for(b, 0.5)
	assert_vec_near(h.position, IsoProjection.ground_to_screen_z(h.ground_pos, h.altitude), 1e-4, "still lifted after moving")
	h.shadow._process(DT)
	assert_vec_near(h.shadow.position, IsoProjection.ground_to_screen(h.ground_pos), 1e-4, "the shadow stays on the ground")
	assert_eq(h.get_parent().name, "Air", "aircraft live on the Air layer")
	_release()


func test_it_flies_in_holds_station_then_leaves_and_is_removed() -> void:
	var b := _battle()
	_arm(b)
	var station := IsoProjection.cell_center(TARGET)
	var card := b.db.card("helicopter_support")
	b.play_card(0, TARGET)
	var h := _heli(b)
	# Fly in: it must reach the station.
	var arrived_at := -1.0
	for i in 60 * 40:
		b.step(DT)
		if b.sorties.size() > 0 and b.sorties[0].flight.phase == SortieFlight.Phase.ON_STATION:
			arrived_at = b.elapsed
			break
	assert_true(arrived_at > 0.0, "it arrives")
	assert_vec_near(h.ground_pos, station, 0.01, "holds position over the target")
	# Holds for the card's station time, still there until then.
	_run_for(b, card.station_time_s - 0.3)
	assert_eq(b.sorties.size(), 1)
	assert_vec_near(h.ground_pos, station, 0.01)
	# Then it leaves and disappears.
	var gone_at := -1.0
	for i in 60 * 60:
		b.step(DT)
		if b.sorties.is_empty():
			gone_at = b.elapsed
			break
	assert_true(gone_at > 0.0, "it eventually leaves the map")
	assert_true(not is_instance_valid(h), "and is removed")
	assert_eq(_heli(b), null)
	assert_eq(b.stats["units_lost"], 0, "leaving is not a loss")
	_release()


func test_on_station_it_strafes_enemies_in_range_and_ignores_those_out_of_range() -> void:
	var b := _quiet_battle()
	_arm(b)
	var station := IsoProjection.cell_center(TARGET)
	var gun := b.db.weapon("heli_gun")
	b.play_card(0, TARGET)
	var near := _static_dummy(b, station + Vector2(gun.range_tiles - 1.0, 0.0))
	var far := _static_dummy(b, station + Vector2(0.0, -(gun.range_tiles + 9.0)))  # off to the side of the flight line, beyond even the missile range
	var h := _heli(b)
	var gun_shots := [0]
	var gun_shots_moving := [0]
	b.shot_fired.connect(func(shooter: BattleUnit, target: BattleEnemy):
		gun_shots[0] += 1
		if shooter.is_moving():
			gun_shots_moving[0] += 1)
	var arrived := false
	for i in 60 * 40:
		b.step(DT)
		if b.sorties[0].flight.phase == SortieFlight.Phase.ON_STATION:
			arrived = true
			break
	assert_true(arrived)
	assert_eq(gun_shots_moving[0], 0, "the machine gun never fires while the helicopter is flying")
	var before: int = gun_shots[0]
	_run_for(b, 2.0)
	assert_true(gun_shots[0] - before > 10, "the guns work once it hovers (%d shots)" % (gun_shots[0] - before))
	assert_true(near.health.hp < near.health.max_hp, "the near enemy is being shot")
	assert_near(far.health.hp, far.health.max_hp, 1e-9, "the far one is out of range of everything")
	_release()


func test_ground_enemies_cannot_hit_the_aircraft() -> void:
	var b := _battle()
	_arm(b)
	b.play_card(0, TARGET)
	var h := _heli(b)
	for i in 60 * 40:
		b.step(DT)
		if b.sorties[0].flight.phase == SortieFlight.Phase.ON_STATION:
			break
	# A pack of enemies right under it, in attack range.
	var e := _inject_enemy(b, h.ground_pos + Vector2(0.2, 0.0))
	e.def = e.def.duplicate()
	e.def.move_speed = 0.0
	e.def.max_health = 100000.0
	e.health = Health.new(100000.0)
	var hp := h.health.hp
	_run_for(b, 5.0)
	assert_near(h.health.hp, hp, 1e-9, "never attacked")
	_release()


func test_enemies_still_attack_ground_units_when_an_aircraft_is_nearer() -> void:
	var b := _battle()
	_arm(b)
	b.deck.hand = ["helicopter_support", "rifle_squad"] as Array[String]
	b.play_card(1, Vector2i(7, 19))  # squad
	var soldier := b.units[0]
	b.play_card(0, Vector2i(7, 19))
	var h := _heli(b)
	for i in 60 * 40:
		b.step(DT)
		if b.sorties[0].flight.phase == SortieFlight.Phase.ON_STATION:
			break
	var e := _inject_enemy(b, soldier.ground_pos + Vector2(0.4, 0.0))
	e.def = e.def.duplicate()
	e.def.move_speed = 0.0
	e.def.max_health = 100000.0
	e.health = Health.new(100000.0)
	var hp := soldier.health.hp
	b.step(DT)
	assert_true(soldier.health.hp < hp, "the ground unit is the target")
	assert_true(h != null)
	_release()


func test_move_orders_and_building_ignore_aircraft() -> void:
	var b := _battle()
	_arm(b)
	b.play_card(0, TARGET)
	var h := _heli(b)
	var before := h.ground_pos
	assert_eq(b.order_move_all(Vector2i(5, 5)), 0, "no ground unit to order")
	b.step(DT)
	assert_true(h.ground_pos != before, "it is flying its own route")
	assert_true(not b.occupied_cells().has(IsoProjection.cell_of(h.ground_pos)) or IsoProjection.cell_of(h.ground_pos) == b.mission.core_cell, "an aircraft never blocks a build cell")
	_release()


func test_a_cell_under_the_aircraft_can_still_be_built_on() -> void:
	var b := _battle()
	_arm(b)
	b.play_card(0, Vector2i(7, 19))
	for i in 60 * 40:
		b.step(DT)
		if b.sorties[0].flight.phase == SortieFlight.Phase.ON_STATION:
			break
	b.deck.hand = ["rifle_squad"] as Array[String]
	b.points.cp = 10.0
	assert_true(b.check_card(0, Vector2i(7, 19)).ok, "the helicopter hovering over the cell does not occupy it")
	_release()


func test_a_sortie_can_target_any_in_bounds_cell_and_never_outside() -> void:
	var b := _battle()
	for cell in [Vector2i(5, 19), Vector2i(10, 21), Vector2i(0, 0), Vector2i(23, 23), Vector2i(20, 12)]:
		_arm(b)
		b.deck.lockouts.clear()
		assert_true(b.check_card(0, cell).ok, str(cell))
	_arm(b)
	var before := [b.points.cp, b.deck.hand.duplicate(), b.units.size(), b.sorties.size()]
	var res := b.play_card(0, Vector2i(-3, 4))
	assert_eq(res.reason, R.INVALID_TARGET)
	assert_eq(res.placement, PlacementRules.Reason.OUT_OF_BOUNDS)
	assert_eq([b.points.cp, b.deck.hand.duplicate(), b.units.size(), b.sorties.size()], before)
	_release()


func test_lockout_blocks_a_second_helicopter() -> void:
	var b := _battle()
	_arm(b)
	assert_true(b.play_card(0, TARGET).ok)
	b.points.cp = 10.0
	assert_eq(b.play_card(0, TARGET).reason, R.LOCKED_OUT)
	assert_eq(b.sorties.size(), 1)
	_release()


func test_a_flight_of_several_aircraft_fans_out_sideways() -> void:
	var original := _get_db().card("helicopter_support")
	var card: CardDefinition = original.duplicate()
	card.unit_count = 3
	var b := _battle()
	b.db.cards["helicopter_support"] = card
	_arm(b)
	b.play_card(0, TARGET)
	b.db.cards["helicopter_support"] = original
	assert_eq(b.sorties.size(), 3)
	var ys: Array[float] = []
	for s in b.sorties:
		ys.append(s.unit.ground_pos.y)
	ys.sort()
	assert_true(ys[1] - ys[0] > 1.0 and ys[2] - ys[1] > 1.0, "spread across the approach line")
	_release()


func test_restart_removes_aircraft_and_keeps_the_shell_view() -> void:
	var b := _battle()
	_arm(b)
	b.play_card(0, TARGET)
	_run_for(b, 1.0)
	var air := b.get_node("Air")
	b.restart()
	assert_eq(_heli(b), null)
	assert_eq(b.sorties.size(), 0)
	var kinds := 0
	for child in air.get_children():
		if child is BattleAircraft:
			kinds += 1
	assert_eq(kinds, 0, "no aircraft left on the Air layer")
	assert_true(air.get_node_or_null("Shells") != null, "the persistent shell view survives a restart")
	_release()


func test_the_battle_ending_freezes_the_sortie() -> void:
	var b := _battle()
	_arm(b)
	b.play_card(0, TARGET)
	b._rules.evaluate(0.0, b.elapsed)
	var pos := _heli(b).ground_pos
	_run_for(b, 3.0)
	assert_vec_near(_heli(b).ground_pos, pos, 1e-9)
	_release()


func test_a_helicopter_over_the_core_does_not_fade_it_but_a_ground_unit_behind_it_does() -> void:
	var behind := Vector2(2.5, 19.5)  # one step back in x and y = straight up the screen from the core: where a unit hides behind it
	# Control: a ground unit there makes the core fade.
	var ground := _battle()
	ground.deck.hand = ["rifle_squad"] as Array[String]
	ground.points.cp = 10.0
	assert_true(ground.play_card(0, Vector2i(2, 19)).ok)
	for u in ground.units:
		u.ground_pos = behind
	for i in 5:
		ground._update_core_fade(0.2)
	assert_true(ground.core.modulate.a < 1.0, "a soldier behind the core fades it")
	# An aircraft in the very same place does not.
	var air := _battle()
	_arm(air)
	air.play_card(0, air.mission.core_cell)
	var h := _heli(air)
	h.ground_pos = behind
	h.lift()
	for i in 5:
		air._update_core_fade(0.2)
	assert_near(air.core.modulate.a, 1.0, 1e-9, "aircraft never hide the core")
	_release()


func test_preview_shows_the_route_and_weapon_range() -> void:
	var b := _battle()
	_arm(b)
	b.select_slot(0)
	var p := b.targeting.preview(b, TARGET)
	assert_true(p.valid)
	assert_eq(p.path_points.size(), 3)
	assert_vec_near(p.path_points[1], IsoProjection.cell_center(TARGET))
	assert_near(p.range_tiles, maxf(b.db.weapon("heli_gun").range_tiles, b.db.weapon("heli_missile").range_tiles), 1e-4, "the ring shows the longest weapon")
	var plan := SortiePlan.plan(24.0, 24.0, IsoProjection.cell_center(TARGET), BattleController.SORTIE_MARGIN)
	assert_vec_near(p.path_points[0], plan.entry)
	assert_vec_near(p.path_points[2], plan.exit)
	_release()


# --- missiles -----------------------------------------------------------------------------------------------------

## A battle whose waves never start, so only the enemies a test injects exist.
func _quiet_battle() -> BattleController:
	var m: MissionDefinition = _get_db().mission("m2_card_defense").duplicate()
	var w: WaveEntry = m.waves[0].duplicate()
	w.start_s = 99999.0
	var waves: Array[WaveEntry] = [w]
	m.waves = waves
	var b := BattleController.new()
	b.auto_step = false
	b.setup(_get_db(), m, 1)
	_made.append(b)
	return b


func _to_station(b: BattleController) -> void:
	for i in 60 * 40:
		b.step(DT)
		if b.sorties[0].flight.phase == SortieFlight.Phase.ON_STATION:
			return


func _static_dummy(b: BattleController, pos: Vector2) -> BattleEnemy:
	var e := _inject_enemy(b, pos)
	e.def = e.def.duplicate()
	e.def.move_speed = 0.0
	e.def.max_health = 100000.0
	e.health = Health.new(100000.0)
	return e


## Runs the battle up to the moment the helicopter reaches its station; returns the launches seen on the way:
## [{"moving": bool, "from": Vector2, "to": Vector2, "t": float}].
func _fly_in(b: BattleController) -> Array:
	var h := _heli(b)
	var launches: Array = []
	b.projectile_launched.connect(func(s: BattleUnit, w: WeaponDefinition, from_g: Vector2, to: Vector2):
		launches.append({"moving": s.is_moving(), "from": from_g, "to": to, "t": b.elapsed, "body": s.ground_pos}))
	for i in 60 * 40:
		b.step(DT)
		if b.sorties[0].flight.phase == SortieFlight.Phase.ON_STATION:
			break
	assert_true(h != null)
	return launches


func test_the_helicopter_carries_limited_missiles_that_can_fire_on_the_move() -> void:
	var b := _battle()
	_arm(b)
	b.play_card(0, TARGET)
	var h := _heli(b)
	var rocket := b.db.weapon("heli_missile")
	assert_true(h.secondary != null)
	assert_eq(h.secondary.id, "heli_missile")
	assert_eq(h.secondary.delivery, WeaponDefinition.Delivery.PROJECTILE)
	assert_true(rocket.can_fire_moving)
	assert_true(rocket.ammo >= 4, "a limited load of at least 4 missiles (%d)" % rocket.ammo)
	assert_eq(h.secondary_ammo, rocket.ammo)
	assert_true(h.secondary_ready_to_fire())
	assert_true(not b.db.weapon("heli_gun").can_fire_moving, "the guns still need a hover")
	assert_eq(b.db.weapon("heli_gun").ammo, 0, "guns never run dry")
	_release()


func test_units_without_a_second_weapon_have_none() -> void:
	var b := _battle()
	b.deck.hand = ["rifle_squad"] as Array[String]
	b.points.cp = 10.0
	b.play_card(0, Vector2i(7, 19))
	assert_true(not (b.units[0] is BattleAircraft))
	_release()


func test_missiles_are_fired_while_flying_in_and_the_guns_stay_silent() -> void:
	var b := _quiet_battle()
	_arm(b)
	var station := IsoProjection.cell_center(TARGET)
	b.play_card(0, TARGET)
	var e := _static_dummy(b, station + Vector2(3.0, 0.0))
	var gun_shots_moving := [0]
	b.shot_fired.connect(func(shooter: BattleUnit, target: BattleEnemy):
		if shooter.is_moving():
			gun_shots_moving[0] += 1)
	var launches := _fly_in(b)
	var moving := 0
	for l in launches:
		if l["moving"]:
			moving += 1
		assert_vec_near(l["to"], station + Vector2(3.0, 0.0), 1e-3, "aimed at the enemy")
	assert_true(moving >= 1, "missiles leave on the way in (%d)" % moving)
	assert_eq(gun_shots_moving[0], 0, "while the machine guns wait for the hover")
	assert_true(e.health.hp < e.health.max_hp, "and they land")
	_release()


func test_the_missile_load_is_emptied_on_the_way_in_and_never_refilled() -> void:
	var b := _quiet_battle()
	_arm(b)
	var station := IsoProjection.cell_center(TARGET)
	var rocket := b.db.weapon("heli_missile")
	b.play_card(0, TARGET)
	_static_dummy(b, station + Vector2(2.0, 0.0))
	var launches := _fly_in(b)
	var h := _heli(b)
	assert_eq(launches.size(), rocket.ammo, "every missile was used before it arrived")
	assert_eq(h.secondary_ammo, 0)
	assert_true(not h.secondary_ready_to_fire())
	var count: int = launches.size()
	_run_for(b, 12.0)  # the whole stay on station
	assert_eq(launches.size(), count, "no more missiles once the load is gone")
	_release()


func test_missiles_are_spaced_by_their_cooldown() -> void:
	var b := _quiet_battle()
	_arm(b)
	var rocket := b.db.weapon("heli_missile")
	b.play_card(0, TARGET)
	_static_dummy(b, IsoProjection.cell_center(TARGET) + Vector2(2.0, 0.0))
	var launches := _fly_in(b)
	assert_true(launches.size() >= 3)
	for k in range(1, launches.size()):
		assert_near(launches[k]["t"] - launches[k - 1]["t"], rocket.fire_interval_s(), 0.03, "one missile every %.2f s" % rocket.fire_interval_s())
	_release()


func test_with_nothing_in_missile_range_none_are_wasted_and_they_wait_for_a_target() -> void:
	var b := _quiet_battle()
	_arm(b)
	var rocket := b.db.weapon("heli_missile")
	b.play_card(0, TARGET)
	var launches := _fly_in(b)
	var h := _heli(b)
	assert_eq(launches.size(), 0, "no enemies, no launches")
	assert_eq(h.secondary_ammo, rocket.ammo, "nothing was spent")
	_static_dummy(b, IsoProjection.cell_center(TARGET) + Vector2(5.0, 0.0))
	_run_for(b, 4.0)
	assert_eq(h.secondary_ammo, 0, "a target appears on station: the missiles go then")
	_release()


func test_once_the_missiles_are_gone_the_guns_carry_on_from_the_hover() -> void:
	var b := _quiet_battle()
	_arm(b)
	var station := IsoProjection.cell_center(TARGET)
	b.play_card(0, TARGET)
	var e := _static_dummy(b, station + Vector2(2.0, 0.0))
	var gun_shots := [0]
	b.shot_fired.connect(func(shooter: BattleUnit, target: BattleEnemy): gun_shots[0] += 1)
	_fly_in(b)
	assert_eq(_heli(b).secondary_ammo, 0)
	var hp := e.health.hp
	_run_for(b, 3.0)
	assert_true(gun_shots[0] > 10, "machine guns fire on station (%d)" % gun_shots[0])
	assert_true(e.health.hp < hp, "and keep hurting the enemy")
	_release()


func test_a_missile_flies_down_from_the_aircraft_altitude_and_explodes_on_arrival() -> void:
	var b := _quiet_battle()
	_arm(b)
	var station := IsoProjection.cell_center(TARGET)
	var rocket := b.db.weapon("heli_missile")
	b.play_card(0, TARGET)
	_static_dummy(b, station + Vector2(6.0, 0.0))
	var alt := b.db.unit("helicopter").flight_altitude()
	var blasts: Array = []
	b.blast_landed.connect(func(c: Vector2, r: float): blasts.append([c, r]))
	var seen := false
	for i in 60 * 20:
		b.step(DT)
		for k in b.projectiles.count():
			if b.projectiles.kind_of(k) == ProjectileSystem.KIND_MISSILE and b.projectiles.is_flying(k):
				seen = true
				var s := b.projectiles.progress_of(k)
				var z := b.projectiles.altitude_of(k)
				assert_true(z <= alt + 1e-6, "never above the launch altitude")
				var p := ProjectileSystem.eased(s, rocket.projectile_accel)
				var dip := rocket.projectile_drop * sin(PI * clampf(s / ProjectileSystem.DROP_SPAN, 0.0, 1.0))
				assert_near(z, maxf(alt * (1.0 - p) - dip, 0.0), 1e-6, "descends along the eased line, with the launch dip")
		if seen and blasts.size() > 0:
			break
	assert_true(seen, "a missile was seen in flight")
	assert_true(blasts.size() >= 1)
	assert_near(blasts[0][1], rocket.blast_radius)
	_release()


func test_missile_flight_time_follows_distance_and_speed() -> void:
	var b := _quiet_battle()
	_arm(b)
	var station := IsoProjection.cell_center(TARGET)
	var rocket := b.db.weapon("heli_missile")
	b.play_card(0, TARGET)
	_static_dummy(b, station + Vector2(8.0, 0.0))
	var first := {}
	var landed_at := [-1.0]
	b.projectile_launched.connect(func(s: BattleUnit, w: WeaponDefinition, from_g: Vector2, to: Vector2):
		if first.is_empty():
			first["t"] = b.elapsed
			first["dist"] = from_g.distance_to(to))
	b.blast_landed.connect(func(c: Vector2, r: float):
		if landed_at[0] < 0.0 and is_equal_approx(r, rocket.blast_radius):
			landed_at[0] = b.elapsed)
	for i in 60 * 60:
		b.step(DT)
		if landed_at[0] > 0.0:
			break
	assert_true(not first.is_empty() and landed_at[0] > first["t"])
	assert_near(landed_at[0] - first["t"], first["dist"] / rocket.projectile_speed, 0.05, "pylon-to-target distance at the missile speed")
	_release()


func test_a_missile_explosion_hurts_everything_in_its_radius_with_falloff_and_nothing_outside() -> void:
	var b := _quiet_battle()
	_arm(b)
	var rocket := b.db.weapon("heli_missile")
	var centre := IsoProjection.cell_center(TARGET)
	var middle := _static_dummy(b, centre)
	var edge := _static_dummy(b, centre + Vector2(rocket.blast_radius * 0.8, 0.0))
	var other_side := _static_dummy(b, centre + Vector2(0.0, -rocket.blast_radius * 0.5))
	var outside := _static_dummy(b, centre + Vector2(rocket.blast_radius + 0.8, 0.0))
	b.projectiles.spawn(centre + Vector2(-6, 0), centre, 0.5, 0.0, rocket.damage, rocket.blast_radius, 0.0, 3.0, ProjectileSystem.KIND_MISSILE, rocket.projectile_accel, rocket.projectile_drop)
	var blasts: Array = []
	b.blast_landed.connect(func(c: Vector2, r: float): blasts.append(c))
	_run_for(b, 0.7)
	assert_eq(blasts.size(), 1, "one explosion")
	assert_vec_near(blasts[0], centre, 1e-4)
	var full := DamageService.compute(rocket.damage, 0.0, 1.0)
	assert_near(middle.health.max_hp - middle.health.hp, full, 1e-3, "full damage at the centre")
	var f_edge := DamageService.blast_falloff(edge.ground_pos.distance_to(centre), rocket.blast_radius)
	assert_true(f_edge < 1.0 and f_edge > DamageService.MIN_FALLOFF)
	assert_near(edge.health.max_hp - edge.health.hp, DamageService.compute(rocket.damage, 0.0, f_edge), 1e-3, "less near the edge")
	assert_true(other_side.health.hp < other_side.health.max_hp, "it is an area: all around the point of impact")
	assert_near(outside.health.hp, outside.health.max_hp, 1e-9, "nothing outside the blast")
	_release()


func test_missiles_leave_from_alternating_wing_pylons_not_the_fuselage() -> void:
	var b := _quiet_battle()
	_arm(b)
	b.play_card(0, TARGET)
	_static_dummy(b, IsoProjection.cell_center(TARGET) + Vector2(2.0, 0.0))
	var launches := _fly_in(b)
	var h := _heli(b)
	assert_true(launches.size() >= 3, "several missiles fired (%d)" % launches.size())
	var dir := IsoProjection.ground_dir_of_facing(h.facing)
	var perp := Vector2(-dir.y, dir.x)
	var sides: Array[float] = []
	for l in launches:
		var off: Vector2 = l["from"] - l["body"]
		assert_near(off.length(), BattleAircraft.PYLON_OFFSET, 1e-4, "a fixed distance out on the wing")
		assert_near(off.dot(dir), 0.0, 1e-4, "straight out sideways, not forward or back")
		sides.append(signf(off.dot(perp)))
	for i in range(1, sides.size()):
		assert_true(sides[i] != sides[i - 1], "left, right, left...")
	_release()


func test_a_moving_helicopter_keeps_facing_its_flight_direction_while_firing() -> void:
	var b := _quiet_battle()
	_arm(b)
	b.play_card(0, TARGET)
	_static_dummy(b, IsoProjection.cell_center(TARGET) + Vector2(8.0, 8.0))  # well off to the side of the flight line
	var h := _heli(b)
	var facings := {}
	var fired := [0]
	b.projectile_launched.connect(func(s: BattleUnit, w: WeaponDefinition, from_g: Vector2, to: Vector2):
		fired[0] += 1
		facings[s.facing] = true)
	for i in 60 * 40:
		b.step(DT)
		if b.sorties[0].flight.phase == SortieFlight.Phase.ON_STATION:
			break
	assert_true(fired[0] >= 1)
	assert_eq(facings.size(), 1, "the nose stayed on the flight line for every launch")
	_release()


func test_a_missile_weapon_that_cannot_fire_on_the_move_waits_for_the_hover() -> void:
	var b := _quiet_battle()
	var original := b.db.weapon("heli_missile")
	var fixed: WeaponDefinition = original.duplicate()
	fixed.can_fire_moving = false
	b.db.weapons["heli_missile"] = fixed
	_arm(b)
	b.play_card(0, TARGET)
	b.db.weapons["heli_missile"] = original
	_static_dummy(b, IsoProjection.cell_center(TARGET) + Vector2(2.0, 0.0))
	var launches := _fly_in(b)
	var moving := 0
	for l in launches:
		if l["moving"]:
			moving += 1
	assert_eq(moving, 0, "the data flag decides: no launches while flying")
	assert_true(launches.size() <= 1, "at most the arrival tick itself, once it has stopped (%d)" % launches.size())
	_release()


func test_missiles_never_hurt_player_units_and_apply_armor() -> void:
	var b := _quiet_battle()
	b.deck.hand = ["rifle_squad", "helicopter_support"] as Array[String]
	b.points.cp = 10.0
	var target := Vector2i(9, 17)
	var station := IsoProjection.cell_center(target)
	assert_true(b.play_card(0, Vector2i(9, 18)).ok, "squad standing next to the target")
	assert_true(b.play_card(0, target).ok)
	var e := _static_dummy(b, station + Vector2(1.0, 0.0))
	e.def.armor = 20.0
	var hp: Array[float] = []
	for u in b.units:
		if not (u is BattleAircraft):
			hp.append(u.health.hp)
	_to_station(b)
	_run_for(b, 8.0)
	var i := 0
	for u in b.units:
		if not (u is BattleAircraft):
			assert_near(u.health.hp, hp[i], 1e-9, "no friendly fire from missiles")
			i += 1
	var taken := e.health.max_hp - e.health.hp
	assert_true(taken > 0.0)
	var rocket := b.db.weapon("heli_missile")
	var gun := b.db.weapon("heli_gun")
	var max_unarmored: float = float(rocket.ammo) * rocket.damage + float(b.stats["shots"]) * gun.damage
	assert_true(taken < max_unarmored, "armor reduced the damage")
	_release()


func test_the_missile_sound_is_a_valid_weapon_sound() -> void:
	assert_true(SfxFactory.is_shot_sound("missile"))
	assert_true(SfxFactory.build_library().has("missile"))


func test_ammo_and_firing_on_the_move_are_validated_data() -> void:
	var w := WeaponDefinition.new()
	w.id = "bad_ammo"
	w.damage = 1.0
	w.shots_per_second = 1.0
	w.range_tiles = 1.0
	w.ammo = -1
	var found := false
	for e in w.validate():
		if "ammo" in e:
			found = true
	assert_true(found)
	w.ammo = 0
	assert_eq(w.validate().size(), 0, "0 = unlimited is valid")
