extends TestCase

const WState := preload("res://scripts/combat/weapon_state.gd")
const WeaponDef := preload("res://scripts/combat/weapon_definition.gd")


func _count_shots(interval: float, seconds: float, delta: float, has_target: bool = true) -> int:
	var w := WState.new(interval)
	var shots := 0
	var steps := int(round(seconds / delta))
	for i in steps:
		if w.tick(delta, has_target):
			shots += 1
	return shots


func test_no_fire_without_target() -> void:
	assert_eq(_count_shots(0.25, 5.0, 1.0 / 60.0, false), 0)


func test_starts_ready_and_fires_on_first_tick_with_target() -> void:
	var w := WState.new(0.5)
	assert_true(w.is_ready())
	assert_true(w.tick(0.1, true))
	assert_true(not w.is_ready())


func test_exact_cadence_with_power_of_two_steps() -> void:
	# interval 0.5 s, 0.25 s ticks: shots land on ticks 1, 2, 4, 6, 8 (first shot is immediate).
	var w := WState.new(0.5)
	var fired: Array[int] = []
	for tick_no in range(1, 9):
		if w.tick(0.25, true):
			fired.append(tick_no)
	assert_eq(fired, [1, 2, 4, 6, 8] as Array[int])


func test_long_run_rate_matches_shots_per_second() -> void:
	for sps in [1.0, 3.0, 8.0]:
		for delta in [1.0 / 30.0, 1.0 / 60.0, 1.0 / 120.0]:
			var seconds := 10.0
			var shots := _count_shots(1.0 / sps, seconds, delta)
			var expected: float = sps * seconds
			assert_true(absf(shots - expected) <= 1.0, "sps %s delta %s: got %d, expected ~%s" % [sps, delta, shots, expected])


func test_cadence_is_frame_rate_independent_within_one_shot() -> void:
	var a := _count_shots(1.0 / 6.0, 20.0, 1.0 / 30.0)
	var b := _count_shots(1.0 / 6.0, 20.0, 1.0 / 144.0)
	assert_true(absi(a - b) <= 1, "30 fps: %d vs 144 fps: %d" % [a, b])


func test_cooldown_recovers_without_target_but_never_banks_a_burst() -> void:
	var w := WState.new(0.5)
	assert_true(w.tick(0.1, true), "first shot")
	for i in 200:  # 20 s with no target
		assert_true(not w.tick(0.1, false))
	assert_true(w.is_ready(), "fully recovered")
	assert_near(w.cooldown_remaining(), 0.0)
	# Target appears: exactly one shot now, then the normal interval applies (no stored burst).
	assert_true(w.tick(0.1, true))
	assert_true(not w.tick(0.1, true))
	assert_true(not w.tick(0.1, true))


func test_cooldown_continues_while_target_is_lost_mid_cooldown() -> void:
	var w := WState.new(1.0)
	assert_true(w.tick(0.1, true))
	assert_near(w.cooldown_remaining(), 0.9, 1e-6)
	w.tick(0.5, false)
	assert_near(w.cooldown_remaining(), 0.4, 1e-6, "keeps counting down without a target")
	assert_true(not w.tick(0.3, true), "still 0.1 s left")
	assert_true(w.tick(0.15, true), "ready again")


func test_at_most_one_shot_per_tick_even_with_huge_delta() -> void:
	var w := WState.new(0.1)
	assert_true(w.tick(10.0, true))
	assert_true(not w.is_ready() or w.cooldown_remaining() >= 0.0)
	# A giant tick cannot produce 100 shots; the next small tick doesn't catch up either.
	assert_true(not w.tick(0.01, true), "no catch-up burst")


func test_non_positive_delta_never_fires() -> void:
	var w := WState.new(0.5)
	assert_true(not w.tick(0.0, true))
	assert_true(not w.tick(-1.0, true))
	assert_true(w.is_ready(), "state unchanged")


func test_reset_makes_weapon_ready() -> void:
	var w := WState.new(2.0)
	w.tick(0.1, true)
	assert_true(not w.is_ready())
	w.reset()
	assert_true(w.is_ready())


func test_from_definition_uses_shots_per_second() -> void:
	var def := WeaponDef.new()
	def.id = "t"
	def.damage = 1.0
	def.range_tiles = 1.0
	def.shots_per_second = 4.0
	var w := WState.from_definition(def)
	var shots := 0
	for i in 40:  # 10 s... no: 40 ticks of 0.25 s = 10 s at 4/s => ~40
		if w.tick(0.25, true):
			shots += 1
	assert_true(absi(shots - 40) <= 1, "got %d" % shots)
