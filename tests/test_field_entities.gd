extends TestCase
## The pure pieces of the entity cards (ADR-013, M3.6): MineField, LureField, SpawnerState, ReinforcementPlan,
## FieldEntityDefinition, the building fields of UnitDefinition, PlacementRules.check_field and the new card kinds.


func _has(errs: PackedStringArray, needle: String) -> bool:
	for e in errs:
		if needle in e:
			return true
	return false


func _mines(count: int = 8, spread: float = 2.0, trigger: float = 0.7, damage: float = 70.0, blast: float = 1.3) -> FieldEntityDefinition:
	var d := FieldEntityDefinition.new()
	d.id = "mines"
	d.display_name = "Mines"
	d.entity_kind = FieldEntityDefinition.EntityKind.MINES
	d.mine_count = count
	d.spread_radius = spread
	d.trigger_radius = trigger
	d.mine_damage = damage
	d.mine_blast_radius = blast
	return d


# --- MineField --------------------------------------------------------------------------------------------------

func test_a_patch_has_the_right_number_of_mines_inside_the_spread() -> void:
	var c := Vector2(10, 10)
	var pts := MineField.patch_positions(c, 8, 2.0)
	assert_eq(pts.size(), 8)
	for p in pts:
		assert_true(p.distance_to(c) <= 2.0 + 1e-6, "inside the spread")
	assert_true(pts[0].distance_to(c) < pts[7].distance_to(c), "spread outward from the middle")


func test_a_patch_is_the_same_every_time_and_mines_do_not_stack() -> void:
	var a := MineField.patch_positions(Vector2(5, 5), 8, 2.0)
	var b := MineField.patch_positions(Vector2(5, 5), 8, 2.0)
	assert_eq(a, b)
	for i in a.size():
		for j in range(i + 1, a.size()):
			assert_true(a[i].distance_to(a[j]) > 0.3, "mines %d and %d are apart" % [i, j])


func test_mines_are_spread_evenly_over_the_area_not_bunched_in_the_middle() -> void:
	var c := Vector2(10, 10)
	var pts := MineField.patch_positions(c, 8, 2.0)
	for i in pts.size():
		assert_near(pts[i].distance_to(c), 2.0 * sqrt((float(i) + 0.5) / 8.0), 1e-6, "mine %d sits at its share of the area" % i)


func test_a_single_mine_lies_on_the_aimed_spot_and_zero_is_nothing() -> void:
	assert_eq(MineField.patch_positions(Vector2(3, 4), 1, 2.0), [Vector2(3, 4)] as Array[Vector2])
	assert_eq(MineField.patch_positions(Vector2(3, 4), 0, 2.0).size(), 0)


func test_a_mine_goes_off_once_when_an_enemy_is_near_and_is_used_up() -> void:
	var f := MineField.new()
	f.add_patch(Vector2(10, 10), _mines(1, 0.0, 0.7))
	assert_eq(f.count(), 1)
	var far := f.detonate(func(pos: Vector2, r: float) -> bool: return Vector2(13, 10).distance_to(pos) <= r)
	assert_eq(far.size(), 0, "an enemy 3 tiles away does not set it off")
	var near := f.detonate(func(pos: Vector2, r: float) -> bool: return Vector2(10.5, 10).distance_to(pos) <= r)
	assert_eq(near.size(), 1)
	assert_near(near[0].damage, 70.0)
	assert_near(near[0].blast_radius, 1.3)
	assert_eq(f.count(), 0)
	assert_eq(f.detonate(func(_p: Vector2, _r: float) -> bool: return true).size(), 0, "nothing left to go off")


func test_the_trigger_radius_is_what_the_mine_carries() -> void:
	var f := MineField.new()
	f.add_patch(Vector2(0, 0), _mines(1, 0.0, 0.7))
	var seen: Array[float] = []
	f.detonate(func(_p: Vector2, r: float) -> bool:
		seen.append(r)
		return false)
	assert_eq(seen, [0.7] as Array[float])


func test_only_the_mines_with_an_enemy_near_go_off_and_in_the_order_laid() -> void:
	var f := MineField.new()
	f.add_patch(Vector2(0, 0), _mines(1, 0.0))
	f.add_patch(Vector2(10, 0), _mines(1, 0.0))
	f.add_patch(Vector2(20, 0), _mines(1, 0.0))
	f.add_patch(Vector2(30, 0), _mines(1, 0.0))
	var hit := f.detonate(func(pos: Vector2, _r: float) -> bool: return pos.x == 10.0 or pos.x == 30.0)
	assert_eq(hit.size(), 2)
	assert_eq(hit[0].pos, Vector2(10, 0))
	assert_eq(hit[1].pos, Vector2(30, 0))
	assert_eq(f.count(), 2)
	f.clear()
	assert_eq(f.count(), 0)


# --- LureField ---------------------------------------------------------------------------------------------------

func test_a_lure_pulls_only_inside_its_radius() -> void:
	var l := LureField.new()
	assert_true(l.is_empty())
	l.add(Vector2(10, 10), 5.0, 10.0)
	assert_eq(l.pull_for(Vector2(13, 10)), Vector2(10, 10))
	assert_eq(l.pull_for(Vector2(15, 10)), Vector2(10, 10), "exactly on the edge counts")
	assert_eq(l.pull_for(Vector2(15.5, 10)), null)


func test_the_nearest_lure_wins_and_ties_go_to_the_first() -> void:
	var l := LureField.new()
	l.add(Vector2(0, 0), 10.0, 10.0)
	l.add(Vector2(6, 0), 10.0, 10.0)
	assert_eq(l.pull_for(Vector2(5, 0)), Vector2(6, 0))
	assert_eq(l.pull_for(Vector2(3, 0)), Vector2(0, 0), "equally far: the first one")


func test_a_lure_runs_out_and_many_small_ticks_end_it_on_time() -> void:
	var l := LureField.new()
	l.add(Vector2(0, 0), 5.0, 10.0)
	l.tick(9.9)
	assert_eq(l.count(), 1)
	l.tick(0.1)
	assert_eq(l.count(), 0)
	assert_eq(l.pull_for(Vector2(1, 0)), null)
	l.add(Vector2(0, 0), 5.0, 1.0)
	for i in 10:
		l.tick(0.1)  # leaves about 1.4e-16 in doubles
	assert_true(l.is_empty())


func test_lure_ticks_ignore_non_positive_time_and_clear_empties() -> void:
	var l := LureField.new()
	l.add(Vector2(0, 0), 5.0, 1.0)
	l.tick(0.0)
	l.tick(-3.0)
	assert_eq(l.count(), 1)
	assert_near(l.lures[0].time_left, 1.0)
	l.clear()
	assert_true(l.is_empty())


# --- SpawnerState ------------------------------------------------------------------------------------------------

func test_a_spawner_makes_a_unit_every_interval_while_below_the_cap() -> void:
	var s := SpawnerState.new(12.0, 3)
	assert_true(not s.tick(11.9, 0))
	assert_true(s.tick(0.1, 0), "12 s are up")
	assert_true(not s.tick(5.0, 1), "the timer restarted")
	assert_true(s.tick(7.0, 1))


func test_a_spawner_at_the_cap_makes_nothing_and_waits_a_full_interval_afterwards() -> void:
	var s := SpawnerState.new(12.0, 2)
	assert_true(not s.tick(100.0, 2))
	assert_true(not s.tick(100.0, 3), "over the cap counts as at it")
	assert_true(not s.tick(11.0, 1), "a unit was lost: the full interval starts now")
	assert_true(s.tick(1.0, 1))


func test_progress_towards_a_unit_is_lost_when_the_cap_is_reached() -> void:
	var s := SpawnerState.new(12.0, 2)
	assert_true(not s.tick(8.0, 1), "two thirds of the way")
	assert_true(not s.tick(1.0, 2), "now at the cap")
	assert_true(not s.tick(8.0, 1), "a unit was lost: the clock starts from zero again")
	assert_true(s.tick(4.0, 1))


func test_a_spawner_survives_float_error_and_negative_time() -> void:
	var s := SpawnerState.new(1.0, 5)
	var made := false
	for i in 10:
		made = s.tick(0.1, 0)  # ten ticks of 0.1 sum to just under 1.0 in doubles
	assert_true(made, "made on the tenth tick")
	assert_true(not s.tick(-5.0, 0))
	assert_near(s.timer, 0.0)


# --- ReinforcementPlan -------------------------------------------------------------------------------------------

func _always(_a: Vector2, _b: Vector2) -> bool:
	return true


func test_a_convoy_settles_toward_the_enemy_and_comes_in_from_an_edge() -> void:
	var core := Vector2(3.5, 20.5)
	var p := ReinforcementPlan.plan(24.0, 24.0, core, Vector2(20.5, 3.5), 3.5, _always)
	assert_true(p != null)
	assert_near(p.settle.distance_to(core), 3.5, 1e-6)
	var dir := (p.settle - core).normalized()
	assert_vec_near(dir, (Vector2(20.5, 3.5) - core).normalized(), 1e-6)
	var on_edge := is_equal_approx(p.entry.x, 0.5) or is_equal_approx(p.entry.x, 23.5) or is_equal_approx(p.entry.y, 0.5) or is_equal_approx(p.entry.y, 23.5)
	assert_true(on_edge, "enters on a map edge, got %s" % str(p.entry))


func test_a_convoy_takes_the_nearest_edge() -> void:
	var p := ReinforcementPlan.plan(40.0, 40.0, Vector2(30, 20), Vector2(10, 20), 3.5, _always)
	assert_near(p.settle.x, 26.5, 1e-6)
	assert_near(p.entry.x, 39.5, 1e-6)
	assert_near(p.entry.y, p.settle.y, 1e-6, "straight out from the spot")


func test_a_convoy_tries_the_next_settling_spot_when_the_first_is_not_clear() -> void:
	var core := Vector2(10, 10)
	var first := core + Vector2.RIGHT * 3.5
	var p := ReinforcementPlan.plan(30.0, 30.0, core, Vector2(20, 10), 3.5, func(_a: Vector2, b: Vector2) -> bool: return b.distance_to(first) > 0.1)
	assert_true(p != null)
	assert_true(p.settle.distance_to(first) > 0.1)
	assert_near(p.settle.distance_to(core), 3.5, 1e-6)


func test_a_convoy_slides_along_the_edge_or_changes_edge_when_the_entry_is_blocked() -> void:
	var core := Vector2(10, 10)
	var all := ReinforcementPlan.plan(30.0, 30.0, core, Vector2(20, 10), 3.5, _always)
	var p := ReinforcementPlan.plan(30.0, 30.0, core, Vector2(20, 10), 3.5, func(a: Vector2, _b: Vector2) -> bool: return a.distance_to(all.entry) > 0.1)
	assert_true(p != null)
	assert_vec_near(p.settle, all.settle, 1e-6, "same spot, different way in")
	assert_true(p.entry.distance_to(all.entry) > 0.1)


func test_no_plan_when_nothing_is_clear_and_entries_stay_on_the_map() -> void:
	assert_eq(ReinforcementPlan.plan(24.0, 24.0, Vector2(3.5, 20.5), Vector2(20.5, 3.5), 3.5, func(_a: Vector2, _b: Vector2) -> bool: return false), null)
	var seen: Array[Vector2] = []
	ReinforcementPlan.plan(24.0, 24.0, Vector2(3.5, 20.5), Vector2(20.5, 3.5), 3.5, func(a: Vector2, _b: Vector2) -> bool:
		seen.append(a)
		return false)
	assert_true(seen.size() > 0)
	for a in seen:
		assert_true(a.x >= 0.0 and a.x <= 24.0 and a.y >= 0.0 and a.y <= 24.0, "entry %s on the map" % str(a))


func test_a_convoy_plan_is_deterministic_and_handles_toward_equal_to_core() -> void:
	var a := ReinforcementPlan.plan(24.0, 24.0, Vector2(5, 5), Vector2(20, 20), 3.5, _always)
	var b := ReinforcementPlan.plan(24.0, 24.0, Vector2(5, 5), Vector2(20, 20), 3.5, _always)
	assert_eq(a.entry, b.entry)
	assert_eq(a.settle, b.settle)
	var c := ReinforcementPlan.plan(24.0, 24.0, Vector2(5, 5), Vector2(5, 5), 3.5, _always)
	assert_true(c != null, "no direction to the enemy: any side will do")


# --- definitions -------------------------------------------------------------------------------------------------

func test_a_mine_entity_validates_its_fields() -> void:
	assert_eq(_mines().validate().size(), 0)
	var bad := _mines(0, -1.0, 0.0, 0.0, 0.0)
	bad.display_name = ""
	var errs := bad.validate()
	for needle in ["display_name", "mine_count", "spread_radius", "trigger_radius", "mine_damage", "mine_blast_radius"]:
		assert_true(_has(errs, needle), needle)


func test_a_lure_entity_validates_its_fields() -> void:
	var d := FieldEntityDefinition.new()
	d.id = "lure"
	d.display_name = "Lure"
	d.entity_kind = FieldEntityDefinition.EntityKind.LURE
	assert_eq(d.validate().size(), 0)
	d.lure_radius = 0.0
	d.lure_duration_s = 0.0
	var errs := d.validate()
	assert_true(_has(errs, "lure_radius"))
	assert_true(_has(errs, "lure_duration_s"))
	d.entity_kind = FieldEntityDefinition.EntityKind.MINES
	d.mine_count = 1
	assert_true(not _has(d.validate(), "lure_radius"), "a mine entity does not care about lure fields")


func _structure(id: String = "barracks") -> UnitDefinition:
	var u := UnitDefinition.new()
	u.id = id
	u.display_name = "Barracks"
	u.max_health = 300.0
	u.structure = true
	return u


func test_a_building_needs_all_three_spawner_fields_and_must_be_a_structure() -> void:
	var u := _structure()
	assert_eq(u.validate().size(), 0)
	assert_true(not u.is_spawner())
	u.spawns_unit_id = "rifle_soldier"
	assert_true(_has(u.validate(), "must be set together"))
	u.spawn_interval_s = 12.0
	u.spawn_cap = 3
	assert_eq(u.validate().size(), 0)
	assert_true(u.is_spawner())
	u.spawn_cap = 0
	assert_true(_has(u.validate(), "spawn_cap"))
	u.spawn_cap = 3
	u.spawn_interval_s = 0.0
	assert_true(_has(u.validate(), "spawn_interval_s"))
	var soldier := UnitDefinition.new()
	soldier.id = "rifle_x"
	soldier.display_name = "X"
	soldier.max_health = 10.0
	soldier.weapon_id = "rifle"
	soldier.move_speed = 2.0
	soldier.spawns_unit_id = "rifle_soldier"
	soldier.spawn_interval_s = 5.0
	soldier.spawn_cap = 2
	assert_true(_has(soldier.validate(), "only a structure"))


func test_field_placement_allows_roads_but_not_rock_the_core_or_blocked_cells() -> void:
	var map := MapDefinition.new()
	map.id = "t"
	map.rows = PackedStringArray(["..=#", "....", "...."])
	var core := Vector2i(1, 1)
	var none: Array[Vector2i] = []
	assert_eq(PlacementRules.check_field(map, Vector2i(0, 0), core, none), PlacementRules.Reason.OK)
	assert_eq(PlacementRules.check_field(map, Vector2i(5, 5), core, none), PlacementRules.Reason.OUT_OF_BOUNDS)
	assert_eq(PlacementRules.check_field(map, Vector2i(-1, 0), core, none), PlacementRules.Reason.OUT_OF_BOUNDS)
	assert_true(map.is_walkable(Vector2i(2, 0)), "the road is walkable")
	assert_eq(PlacementRules.check_field(map, Vector2i(2, 0), core, none), PlacementRules.Reason.OK, "roads take mines (that is where they walk)")
	assert_true(not map.is_walkable(Vector2i(3, 0)))
	assert_eq(PlacementRules.check_field(map, Vector2i(3, 0), core, none), PlacementRules.Reason.NOT_WALKABLE)
	assert_eq(PlacementRules.check_field(map, core, core, none), PlacementRules.Reason.OCCUPIED)
	var blocked: Array[Vector2i] = [Vector2i(0, 2)]
	assert_eq(PlacementRules.check_field(map, Vector2i(0, 2), core, blocked), PlacementRules.Reason.OCCUPIED)
	assert_true(PlacementRules.describe(PlacementRules.Reason.NOT_WALKABLE) != "Invalid")
	assert_true(PlacementRules.describe(PlacementRules.Reason.NO_ROUTE) != "Invalid")


func _card(kind: CardDefinition.CardKind) -> CardDefinition:
	var c := CardDefinition.new()
	c.id = "probe"
	c.display_name = "Probe"
	c.card_kind = kind
	return c


func test_card_kinds_say_whether_they_are_instant_and_what_their_effect_id_names() -> void:
	for k in [CardDefinition.CardKind.ORDER, CardDefinition.CardKind.SUPPLY, CardDefinition.CardKind.DECK, CardDefinition.CardKind.REINFORCEMENT]:
		assert_true(_card(k).is_instant(), str(k))
	for k in [CardDefinition.CardKind.TRAP, CardDefinition.CardKind.INTEL, CardDefinition.CardKind.DEPLOYMENT, CardDefinition.CardKind.DOCTRINE]:
		assert_true(not _card(k).is_instant(), str(k))
	assert_true(_card(CardDefinition.CardKind.TRAP).uses_field_entity())
	assert_true(_card(CardDefinition.CardKind.INTEL).uses_field_entity())
	assert_true(not _card(CardDefinition.CardKind.REINFORCEMENT).uses_field_entity())
	assert_true(not _card(CardDefinition.CardKind.REINFORCEMENT).uses_state_effect(), "a convoy names a unit, not a state effect")
	assert_true(_card(CardDefinition.CardKind.ORDER).uses_state_effect())


func test_trap_and_intel_cards_need_an_effect_id_and_a_convoy_needs_a_unit() -> void:
	assert_true(_has(_card(CardDefinition.CardKind.TRAP).validate(), "effect_id"))
	assert_true(_has(_card(CardDefinition.CardKind.INTEL).validate(), "effect_id"))
	var convoy := _card(CardDefinition.CardKind.REINFORCEMENT)
	assert_true(_has(convoy.validate(), "unit_id"))
	convoy.unit_id = "rifle_soldier"
	convoy.unit_count = 0
	assert_true(_has(convoy.validate(), "unit_count"))
	convoy.unit_count = 4
	assert_eq(convoy.validate().size(), 0)
