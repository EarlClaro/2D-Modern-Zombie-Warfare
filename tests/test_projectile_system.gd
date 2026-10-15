extends TestCase

const DT: float = 1.0 / 60.0


func _tick_n(sys: ProjectileSystem, n: int, delta: float = DT) -> Array:
	var impacts: Array = []
	for i in n:
		impacts.append_array(sys.tick(delta))
	return impacts


func test_altitude_profile_is_a_parabola_between_two_ground_points() -> void:
	assert_near(ProjectileSystem.altitude_profile(0.0, 6.0), 0.0)
	assert_near(ProjectileSystem.altitude_profile(1.0, 6.0), 0.0)
	assert_near(ProjectileSystem.altitude_profile(0.5, 6.0), 6.0, 1e-9, "peak at mid-flight")
	assert_near(ProjectileSystem.altitude_profile(0.25, 6.0), ProjectileSystem.altitude_profile(0.75, 6.0), 1e-9, "symmetric")
	assert_true(ProjectileSystem.altitude_profile(0.25, 6.0) < 6.0 and ProjectileSystem.altitude_profile(0.25, 6.0) > 0.0)
	assert_near(ProjectileSystem.altitude_profile(-1.0, 6.0), 0.0, 1e-9, "clamped before launch")
	assert_near(ProjectileSystem.altitude_profile(2.0, 6.0), 0.0, 1e-9, "clamped after landing")


func test_ground_position_is_a_straight_line_independent_of_altitude() -> void:
	var sys := ProjectileSystem.new()
	assert_true(sys.spawn(Vector2(0, 0), Vector2(10, 0), 1.0, 8.0, 50.0, 2.0))
	sys.tick(0.5)
	assert_vec_near(sys.ground_pos_of(0), Vector2(5, 0))
	assert_near(sys.altitude_of(0), 8.0, 1e-9)
	# A shell with a huge arc and one with none follow the very same ground line.
	var flat := ProjectileSystem.new()
	flat.spawn(Vector2(0, 0), Vector2(10, 0), 1.0, 0.0, 50.0, 2.0)
	flat.tick(0.5)
	assert_vec_near(flat.ground_pos_of(0), sys.ground_pos_of(0), 1e-6, "altitude never moves the ground position")
	assert_near(flat.altitude_of(0), 0.0)


func test_a_shell_lands_once_at_its_target_with_its_damage_and_radius() -> void:
	var sys := ProjectileSystem.new()
	sys.spawn(Vector2(-4, 4), Vector2(7, 3), 0.9, 6.0, 60.0, 1.8)
	var impacts := _tick_n(sys, 120)
	assert_eq(impacts.size(), 1)
	assert_vec_near(impacts[0].ground_pos, Vector2(7, 3))
	assert_near(impacts[0].damage, 60.0)
	assert_near(impacts[0].radius, 1.8)
	assert_eq(sys.count(), 0, "removed after landing")


func test_landing_happens_on_the_exact_tick_not_one_late() -> void:
	# 0.9 s = 54 ticks of 1/60 s; float accumulation must not push the impact to tick 55.
	for delta in [1.0 / 60.0, 1.0 / 30.0, 1.0 / 120.0, 0.05]:
		var sys := ProjectileSystem.new()
		sys.spawn(Vector2.ZERO, Vector2(5, 5), 0.9, 4.0, 10.0, 1.0)
		var steps := int(round(0.9 / delta))
		var before := _tick_n(sys, steps - 1, delta)
		assert_eq(before.size(), 0, "not before 0.9 s (delta %s)" % str(delta))
		assert_eq(sys.tick(delta).size(), 1, "exactly at 0.9 s (delta %s)" % str(delta))


func test_a_delayed_shell_is_invisible_and_cannot_land_before_it_launches() -> void:
	var sys := ProjectileSystem.new()
	sys.spawn(Vector2.ZERO, Vector2(3, 3), 1.0, 5.0, 10.0, 1.0, 2.0)
	assert_true(not sys.is_flying(0))
	assert_near(sys.progress_of(0), 0.0)
	assert_near(sys.altitude_of(0), 0.0)
	var early := _tick_n(sys, 119)  # just under 2 s
	assert_eq(early.size(), 0)
	assert_true(not sys.is_flying(0) or sys.progress_of(0) < 0.01)
	sys.tick(DT * 2.0)
	assert_true(sys.is_flying(0))
	var landed := _tick_n(sys, 70)
	assert_eq(landed.size(), 1)
	assert_eq(sys.count(), 0)


func test_landing_time_is_delay_plus_flight() -> void:
	var sys := ProjectileSystem.new()
	sys.spawn(Vector2.ZERO, Vector2(2, 2), 0.9, 3.0, 10.0, 1.0, 1.0)
	assert_eq(_tick_n(sys, 113).size(), 0, "1.88 s: still in the air")
	assert_eq(_tick_n(sys, 1).size(), 1, "lands at 1.9 s")


func test_shells_land_in_launch_order_and_each_exactly_once() -> void:
	var sys := ProjectileSystem.new()
	for i in 5:
		sys.spawn(Vector2.ZERO, Vector2(float(i), 0.0), 0.5, 2.0, 10.0 + i, 1.0, 0.35 * i)
	var impacts := _tick_n(sys, 600)
	assert_eq(impacts.size(), 5)
	for i in 5:
		assert_vec_near(impacts[i].ground_pos, Vector2(float(i), 0.0))
		assert_near(impacts[i].damage, 10.0 + i)
	assert_eq(sys.count(), 0)


func test_removal_keeps_the_remaining_shells_intact() -> void:
	var sys := ProjectileSystem.new()
	sys.spawn(Vector2.ZERO, Vector2(1, 0), 0.5, 1.0, 1.0, 1.0)  # lands first
	sys.spawn(Vector2.ZERO, Vector2(2, 0), 2.0, 1.0, 2.0, 1.0)
	sys.spawn(Vector2.ZERO, Vector2(3, 0), 0.5, 1.0, 3.0, 1.0)  # lands first
	var first := _tick_n(sys, 31)
	assert_eq(first.size(), 2)
	assert_eq(sys.count(), 1)
	assert_vec_near(sys.target_of(0), Vector2(2, 0), 1e-6, "the long flight is still the one in the air")
	assert_near(sys.progress_of(0), 31.0 / 120.0, 1e-3)


func test_a_huge_hitch_lands_everything_without_overshoot_artifacts() -> void:
	var sys := ProjectileSystem.new()
	for i in 4:
		sys.spawn(Vector2.ZERO, Vector2(float(i), 1.0), 0.9, 4.0, 10.0, 1.0, 0.3 * i)
	var impacts := sys.tick(60.0)
	assert_eq(impacts.size(), 4)
	assert_eq(sys.count(), 0)


func test_non_positive_delta_changes_nothing() -> void:
	var sys := ProjectileSystem.new()
	sys.spawn(Vector2.ZERO, Vector2(4, 4), 1.0, 4.0, 10.0, 1.0)
	sys.tick(0.4)
	var p := sys.progress_of(0)
	assert_eq(sys.tick(0.0).size(), 0)
	assert_eq(sys.tick(-5.0).size(), 0)
	assert_near(sys.progress_of(0), p, 1e-12)


func test_invalid_flight_time_is_rejected() -> void:
	var sys := ProjectileSystem.new()
	assert_true(not sys.spawn(Vector2.ZERO, Vector2.ONE, 0.0, 1.0, 1.0, 1.0))
	assert_true(not sys.spawn(Vector2.ZERO, Vector2.ONE, -1.0, 1.0, 1.0, 1.0))
	assert_eq(sys.count(), 0)


func test_the_cap_refuses_extra_projectiles_and_frees_up_after_landing() -> void:
	var sys := ProjectileSystem.new()
	for i in ProjectileSystem.MAX_PROJECTILES:
		assert_true(sys.spawn(Vector2.ZERO, Vector2(1, 1), 0.5, 1.0, 1.0, 1.0))
	assert_eq(sys.count(), ProjectileSystem.MAX_PROJECTILES)
	assert_true(not sys.spawn(Vector2.ZERO, Vector2(1, 1), 0.5, 1.0, 1.0, 1.0), "full")
	assert_eq(sys.count(), ProjectileSystem.MAX_PROJECTILES, "a refused spawn adds nothing")
	var impacts := sys.tick(0.6)
	assert_eq(impacts.size(), ProjectileSystem.MAX_PROJECTILES)
	assert_true(sys.spawn(Vector2.ZERO, Vector2(1, 1), 0.5, 1.0, 1.0, 1.0), "room again")


func test_clear_removes_everything() -> void:
	var sys := ProjectileSystem.new()
	sys.spawn(Vector2.ZERO, Vector2(3, 3), 1.0, 1.0, 1.0, 1.0)
	sys.spawn(Vector2.ZERO, Vector2(4, 4), 1.0, 1.0, 1.0, 1.0, 5.0)
	sys.clear()
	assert_eq(sys.count(), 0)
	assert_eq(sys.tick(10.0).size(), 0)


func test_a_full_cap_ticks_fast_enough_for_a_frame() -> void:
	# Cost check behind the cap: 256 shells in flight for a second of simulation must stay far below a frame budget.
	var sys := ProjectileSystem.new()
	for i in ProjectileSystem.MAX_PROJECTILES:
		sys.spawn(Vector2.ZERO, Vector2(float(i % 20), float(i % 7)), 10.0, 6.0, 1.0, 1.0)
	var t0 := Time.get_ticks_usec()
	for i in 60:
		sys.tick(DT)
		for k in sys.count():
			sys.ground_pos_of(k)
			sys.altitude_of(k)
	var per_tick_ms := (Time.get_ticks_usec() - t0) / 1000.0 / 60.0
	assert_true(per_tick_ms < 4.0, "256 shells tick + query in %.2f ms (budget 4 ms)" % per_tick_ms)
