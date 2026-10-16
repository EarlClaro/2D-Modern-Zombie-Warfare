extends TestCase
## The artillery strike: operation data, scatter pattern, and the whole card -> telegraph -> shells -> blasts chain
## inside a battle simulation.

const DT: float = 1.0 / 60.0
const R := CardPlayService.Reason
const TARGET := Vector2i(12, 10)  # open grass, nothing built on it

var _db: ContentDb
var _made: Array[BattleController] = []


func _get_db() -> ContentDb:
	if _db == null:
		_db = ContentDb.load_from()
	return _db


func _op() -> OperationDefinition:
	return _get_db().operation("artillery_strike")


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
	b.deck.hand = ["artillery_strike", "artillery_strike"] as Array[String]
	b.points.cp = cp


func _run_for(b: BattleController, seconds: float) -> void:
	for i in int(round(seconds / DT)):
		b.step(DT)


func _inject_enemy(b: BattleController, pos: Vector2) -> BattleEnemy:
	b._spawn_enemy(b.mission.waves[0])
	var e: BattleEnemy = b.enemies.back()
	e.ground_pos = pos
	return e


## An enemy that stands still and cannot die, so damage can be read back exactly.
func _make_static_dummy(e: BattleEnemy) -> void:
	e.def = e.def.duplicate()
	e.def.move_speed = 0.0
	e.def.max_health = 100000.0
	e.health = Health.new(100000.0)


func _has(errs: PackedStringArray, needle: String) -> bool:
	for e in errs:
		if needle in e:
			return true
	return false


# --- operation data -------------------------------------------------------------------------------------------

func test_shipped_operation_is_valid_and_the_card_points_at_it() -> void:
	var db := _get_db()
	assert_true(db.is_valid(), "\n".join(db.errors))
	assert_true(_op() != null)
	assert_eq(db.card("artillery_strike").effect_id, _op().id)
	assert_eq(_op().shell_count, 6)


func test_operation_field_validation() -> void:
	var o := OperationDefinition.new()
	o.id = "bad_op"
	o.display_name = ""
	o.shell_count = 0
	o.target_radius = -1.0
	o.warning_s = -1.0
	o.shell_interval_s = -1.0
	o.flight_time_s = 0.0
	o.arc_height = -1.0
	o.shell_damage = 0.0
	o.blast_radius = 0.0
	var errs := o.validate()
	for needle in ["display_name", "shell_count", "target_radius", "warning_s", "shell_interval_s", "flight_time_s", "arc_height", "shell_damage", "blast_radius"]:
		assert_true(_has(errs, needle), needle)


func test_operation_card_with_an_unknown_effect_is_a_reference_error() -> void:
	var db := ContentDb.load_from("res://data")
	db.errors.clear()
	var c := CardDefinition.new()
	c.id = "ghost_strike"
	c.display_name = "Ghost"
	c.card_kind = CardDefinition.CardKind.OPERATION
	c.effect_id = "no_such_effect"
	db.add_card(c)
	db.validate_references()
	assert_true(_has(db.errors, "card 'ghost_strike': unknown effect_id 'no_such_effect'"))


func test_derived_times_and_radii() -> void:
	var o := _op()
	assert_near(o.reach_radius(), o.target_radius + o.blast_radius)
	assert_near(o.total_duration_s(), o.warning_s + (o.shell_count - 1) * o.shell_interval_s + o.flight_time_s)


# --- scatter pattern ------------------------------------------------------------------------------------------

func test_shell_targets_stay_inside_the_circle_and_cover_it_evenly() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var centre := Vector2(10, 10)
	var pts := _op().shell_targets(centre, rng)
	assert_eq(pts.size(), _op().shell_count)
	for p in pts:
		assert_true(p.distance_to(centre) <= _op().target_radius + 1e-6, "inside the scatter circle")
	var min_sep := 1e9
	for i in pts.size():
		for j in range(i + 1, pts.size()):
			min_sep = minf(min_sep, pts[i].distance_to(pts[j]))
	assert_true(min_sep > 0.5, "shells do not pile onto one spot (closest pair %.2f)" % min_sep)


func test_shell_targets_are_deterministic_and_seed_dependent() -> void:
	var a := RandomNumberGenerator.new()
	a.seed = 9
	var b := RandomNumberGenerator.new()
	b.seed = 9
	var c := RandomNumberGenerator.new()
	c.seed = 10
	assert_eq(_op().shell_targets(Vector2.ZERO, a), _op().shell_targets(Vector2.ZERO, b))
	var other := _op().shell_targets(Vector2.ZERO, c)
	var again := RandomNumberGenerator.new()
	again.seed = 9
	assert_true(_op().shell_targets(Vector2.ZERO, again) != other, "a different seed gives a different barrage")


func test_shells_are_fired_in_a_shuffled_order_not_spiral_order() -> void:
	# The Vogel spiral comes out ordered by distance from the centre; the firing order must not be.
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var centre := Vector2(10, 10)
	var pts := _op().shell_targets(centre, rng)
	var increasing := true
	for i in range(1, pts.size()):
		if pts[i].distance_to(centre) < pts[i - 1].distance_to(centre):
			increasing = false
	assert_true(not increasing, "firing order is shuffled")


func test_a_one_shell_operation_lands_inside_the_circle() -> void:
	var o: OperationDefinition = _op().duplicate()
	o.shell_count = 1
	var rng := RandomNumberGenerator.new()
	var pts := o.shell_targets(Vector2(5, 5), rng)
	assert_eq(pts.size(), 1)
	assert_true(pts[0].distance_to(Vector2(5, 5)) <= o.target_radius)


# --- playing the card -----------------------------------------------------------------------------------------

func test_playing_the_card_spends_cp_discards_locks_and_queues_all_shells() -> void:
	var b := _battle()
	_arm(b)
	var res := b.play_card(0, TARGET)
	assert_true(res.ok)
	assert_near(b.points.cp, 10.0 - b.db.card("artillery_strike").cost, 1e-9)
	assert_eq(b.deck.discard, ["artillery_strike"] as Array[String])
	assert_true(b.deck.is_locked("artillery_strike"))
	assert_eq(b.projectiles.count(), _op().shell_count)
	assert_eq(b.strikes.size(), 1)
	assert_vec_near(b.strikes[0].center, IsoProjection.cell_center(TARGET))
	assert_near(b.strikes[0].reach, _op().reach_radius())
	_release()


func test_strike_can_target_any_in_bounds_cell_including_rock_and_roads() -> void:
	var b := _battle()
	for cell in [Vector2i(5, 19), Vector2i(10, 21), Vector2i(0, 0), Vector2i(23, 23), Vector2i(20, 12)]:
		_arm(b)
		b.deck.lockouts.clear()
		assert_true(b.check_card(0, cell).ok, "strike on %s" % str(cell))
	_release()


func test_strike_outside_the_map_is_refused_without_spending() -> void:
	var b := _battle()
	_arm(b)
	var before := [b.points.cp, b.deck.hand.duplicate(), b.projectiles.count(), b.strikes.size()]
	for cell in [Vector2i(-1, 5), Vector2i(30, 30)]:
		var res := b.play_card(0, cell)
		assert_eq(res.reason, R.INVALID_TARGET)
		assert_eq(res.placement, PlacementRules.Reason.OUT_OF_BOUNDS)
	assert_eq([b.points.cp, b.deck.hand.duplicate(), b.projectiles.count(), b.strikes.size()], before)
	_release()


func test_a_second_strike_is_locked_out_until_the_lockout_ends() -> void:
	var b := _battle()
	_arm(b)
	assert_true(b.play_card(0, TARGET).ok)
	b.points.cp = 10.0
	assert_eq(b.play_card(0, TARGET).reason, R.LOCKED_OUT)
	assert_eq(b.projectiles.count(), _op().shell_count, "no extra shells from the refused play")
	_release()


func test_nothing_lands_during_the_warning() -> void:
	var b := _battle()
	_arm(b)
	var e := _inject_enemy(b, IsoProjection.cell_center(TARGET))
	var blasts: Array = []
	b.blast_landed.connect(func(c: Vector2, r: float): blasts.append(c))
	b.play_card(0, TARGET)
	_run_for(b, _op().warning_s + _op().flight_time_s - 0.3)
	assert_eq(blasts.size(), 0, "no shell has landed before the first one's flight is over")
	assert_near(e.health.hp, e.health.max_hp, 1e-9)
	_release()


func test_shells_land_one_after_another_with_the_configured_spacing() -> void:
	var b := _battle()
	_arm(b)
	var times: Array[float] = []
	b.blast_landed.connect(func(c: Vector2, r: float): times.append(b.elapsed))
	b.play_card(0, TARGET)
	_run_for(b, _op().total_duration_s() + 0.2)
	assert_eq(times.size(), _op().shell_count)
	assert_near(times[0], _op().warning_s + _op().flight_time_s, 0.03)
	assert_near(times[times.size() - 1] - times[0], (_op().shell_count - 1) * _op().shell_interval_s, 0.05)
	assert_eq(b.projectiles.count(), 0)
	_release()


func test_shells_are_fired_from_the_battery_offset_and_fly_a_straight_ground_line() -> void:
	var b := _battle()
	_arm(b)
	b.play_card(0, TARGET)
	# Just after the first launch, shell 0 is almost at its launch point: target + launch_offset.
	_run_for(b, _op().warning_s + 0.1)
	var i := -1
	for k in b.projectiles.count():
		if b.projectiles.is_flying(k):
			i = k
	assert_true(i >= 0, "a shell is in the air")
	var target := b.projectiles.target_of(i)
	var p := b.projectiles.progress_of(i)
	assert_true(p > 0.0 and p < 0.3)
	assert_vec_near(b.projectiles.ground_pos_of(i), target + _op().launch_offset * (1.0 - p), 1e-4, "on the line from the battery to the target")
	assert_true(b.projectiles.altitude_of(i) > 0.0, "and above the ground while flying")
	_release()


func test_every_shell_lands_inside_the_scatter_circle_and_blasts_there() -> void:
	var b := _battle()
	_arm(b)
	var centre := IsoProjection.cell_center(TARGET)
	var spots: Array[Vector2] = []
	var radii: Array[float] = []
	b.blast_landed.connect(func(c: Vector2, r: float):
		spots.append(c)
		radii.append(r))
	b.play_card(0, TARGET)
	_run_for(b, _op().total_duration_s() + 0.2)
	assert_eq(spots.size(), _op().shell_count)
	for i in spots.size():
		assert_true(spots[i].distance_to(centre) <= _op().target_radius + 1e-5, "impact %d inside the circle" % i)
		assert_near(radii[i], _op().blast_radius)
	_release()


func test_a_shell_hurts_enemies_with_falloff_and_spares_those_outside_the_blast() -> void:
	var original := _op()
	var o: OperationDefinition = original.duplicate()
	o.shell_count = 1
	o.target_radius = 0.0  # the single shell lands exactly on the target
	var b := _battle()
	b.db.operations["artillery_strike"] = o
	_arm(b)
	var centre := IsoProjection.cell_center(TARGET)
	var on_target := _inject_enemy(b, centre)
	var edge := _inject_enemy(b, centre + Vector2(o.blast_radius * 0.9, 0.0))
	var outside := _inject_enemy(b, centre + Vector2(o.blast_radius + 1.0, 0.0))
	for e in [on_target, edge, outside]:
		_make_static_dummy(e)
	b.play_card(0, TARGET)
	_run_for(b, o.total_duration_s() + 0.1)
	b.db.operations["artillery_strike"] = original
	var full := DamageService.compute(o.shell_damage, 0.0, 1.0)
	assert_near(on_target.health.max_hp - on_target.health.hp, full, 1e-3, "centre takes the full shell")
	var f := DamageService.blast_falloff(edge.ground_pos.distance_to(centre), o.blast_radius)
	assert_true(f > DamageService.MIN_FALLOFF and f < 1.0)
	assert_near(edge.health.hp, edge.health.max_hp - DamageService.compute(o.shell_damage, 0.0, f), 1e-3, "near the edge: falloff")
	assert_near(outside.health.hp, outside.health.max_hp, 1e-9, "outside the blast: untouched")
	_release()


func test_a_barrage_hurts_a_crowd_across_the_whole_circle_and_kills_where_it_lands() -> void:
	var b := _battle()
	_arm(b)
	var centre := IsoProjection.cell_center(TARGET)
	var crowd: Array[BattleEnemy] = []
	for i in 12:
		var e := _inject_enemy(b, centre + Vector2(cos(i * 0.9), sin(i * 0.9)) * (0.4 + 0.18 * i))
		e.def = e.def.duplicate()
		e.def.move_speed = 0.0
		crowd.append(e)
	b.play_card(0, TARGET)
	_run_for(b, _op().total_duration_s() + 0.2)
	var hurt := 0
	for e in crowd:
		if not is_instance_valid(e) or e.health.hp < e.health.max_hp:  # dead enemies are freed
			hurt += 1
	assert_true(b.stats["kills"] >= 1, "shells kill what they land on")
	assert_true(hurt >= 8, "most of a packed crowd is hurt or dead (%d of 12)" % hurt)
	_release()


func test_artillery_never_hurts_player_units() -> void:
	var b := _battle()
	_arm(b)
	b.deck.hand = ["rifle_squad", "artillery_strike"] as Array[String]
	b.points.cp = 10.0
	b.play_card(0, Vector2i(7, 19))  # squad
	var hp_before: Array[float] = []
	for u in b.units:
		hp_before.append(u.health.hp)
	b.play_card(0, Vector2i(7, 19))  # strike right on top of them
	_run_for(b, _op().total_duration_s() + 0.2)
	for i in b.units.size():
		assert_near(b.units[i].health.hp, hp_before[i], 1e-9, "no friendly fire")
	_release()


func test_shell_armor_applies() -> void:
	var original := _op()
	var o: OperationDefinition = original.duplicate()
	o.shell_count = 1
	o.target_radius = 0.0
	var b := _battle()
	b.db.operations["artillery_strike"] = o
	_arm(b)
	var centre := IsoProjection.cell_center(TARGET)
	var e := _inject_enemy(b, centre)
	_make_static_dummy(e)
	e.def.armor = 25.0
	b.play_card(0, TARGET)
	_run_for(b, o.total_duration_s() + 0.1)
	b.db.operations["artillery_strike"] = original
	assert_near(e.health.max_hp - e.health.hp, DamageService.compute(o.shell_damage, 25.0), 1e-3)
	_release()


func test_telegraph_lasts_until_the_last_shell_lands() -> void:
	var b := _battle()
	_arm(b)
	b.play_card(0, TARGET)
	_run_for(b, _op().total_duration_s() - 0.2)
	assert_eq(b.strikes.size(), 1, "still shown while shells are coming")
	_run_for(b, 0.4)
	assert_eq(b.strikes.size(), 0, "gone once it is over")
	_release()


func test_strike_called_signal_carries_the_zone() -> void:
	var b := _battle()
	_arm(b)
	var got: Array = []
	b.strike_called.connect(func(c: Vector2, reach: float, dur: float): got.append([c, reach, dur]))
	b.play_card(0, TARGET)
	assert_eq(got.size(), 1)
	assert_vec_near(got[0][0], IsoProjection.cell_center(TARGET))
	assert_near(got[0][1], _op().reach_radius())
	assert_near(got[0][2], _op().total_duration_s())
	_release()


# --- determinism, restart, interplay ------------------------------------------------------------------------

func test_same_seed_same_barrage() -> void:
	var c := _battle(21)
	var d := _battle(21)
	var e := _battle(22)
	for b in [c, d, e]:
		_arm(b)
		b.play_card(0, TARGET)
	var differs := false
	for i in c.projectiles.count():
		assert_vec_near(c.projectiles.target_of(i), d.projectiles.target_of(i), 1e-9, "same seed, same impact points")
		if c.projectiles.target_of(i).distance_to(e.projectiles.target_of(i)) > 1e-6:
			differs = true
	assert_true(differs, "a different seed gives a different barrage")
	_release()


func test_a_strike_does_not_disturb_where_enemies_spawn() -> void:
	var a := _battle(21)
	var c := _battle(21)
	_arm(c)
	c.play_card(0, TARGET)
	for b in [a, c]:
		while b.enemy_count() == 0:
			b.step(DT)
	assert_vec_near(a.enemies[0].ground_pos, c.enemies[0].ground_pos, 1e-6, "the strike has its own random stream")
	_release()


func test_restart_clears_shells_and_telegraphs() -> void:
	var b := _battle()
	_arm(b)
	b.play_card(0, TARGET)
	_run_for(b, 1.0)
	b.restart()
	assert_eq(b.projectiles.count(), 0)
	assert_eq(b.strikes.size(), 0)
	_release()


func test_a_finished_battle_stops_the_barrage() -> void:
	var b := _battle()
	_arm(b)
	b.play_card(0, TARGET)
	b._rules.evaluate(0.0, b.elapsed)  # defeat
	var count := b.projectiles.count()
	_run_for(b, 5.0)
	assert_eq(b.projectiles.count(), count, "the sim is frozen after the end")
	_release()


# --- preview and sound -----------------------------------------------------------------------------------------

func test_preview_of_the_strike_shows_the_danger_zone() -> void:
	var b := _battle()
	_arm(b)
	b.select_slot(0)
	var p := b.targeting.preview(b, TARGET)
	assert_true(p.valid)
	assert_near(p.area_radius, _op().reach_radius())
	assert_near(p.scatter_radius, _op().target_radius)
	assert_eq(p.ground_points.size(), 0)
	assert_near(p.range_tiles, 0.0)
	var rock := b.targeting.preview(b, Vector2i(10, 21))
	assert_true(rock.valid, "a strike can hit rock")
	var out := b.targeting.preview(b, Vector2i(-2, 3))
	assert_true(not out.valid)
	assert_eq(out.placement, PlacementRules.Reason.OUT_OF_BOUNDS)
	_release()


func test_blast_sound_exists_has_its_own_voice_cap_and_is_not_a_shot() -> void:
	var lib := SfxFactory.build_library()
	assert_true(lib.has("blast"))
	assert_eq(SfxFactory.SETTINGS["blast"]["category"], "blast")
	assert_true(SfxVoicePool.CAPS.has("blast"))
	assert_true(not SfxFactory.is_shot_sound("blast"), "weapons cannot use it as a shot sound")
	assert_true(lib["blast"].data.size() > lib["shot_mg"].data.size(), "a blast rumbles longer than a machine-gun shot")
