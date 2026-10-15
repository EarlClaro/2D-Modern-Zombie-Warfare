extends TestCase

const HealthScript := preload("res://scripts/combat/health.gd")


func test_starts_full() -> void:
	var h := HealthScript.new(50.0)
	assert_near(h.hp, 50.0)
	assert_near(h.max_hp, 50.0)
	assert_near(h.fraction(), 1.0)
	assert_true(not h.is_dead())


func test_damage_reduces_hp_and_reports_not_lethal() -> void:
	var h := HealthScript.new(50.0)
	assert_true(not h.take_damage(20.0))
	assert_near(h.hp, 30.0)
	assert_near(h.fraction(), 0.6, 1e-6)


func test_lethal_hit_returns_true_and_clamps_at_zero() -> void:
	var h := HealthScript.new(50.0)
	assert_true(h.take_damage(500.0), "overkill is lethal")
	assert_near(h.hp, 0.0)
	assert_true(h.is_dead())
	assert_near(h.fraction(), 0.0)


func test_exact_lethal_damage() -> void:
	var h := HealthScript.new(30.0)
	assert_true(h.take_damage(30.0))
	assert_true(h.is_dead())


func test_died_emitted_exactly_once() -> void:
	var h := HealthScript.new(10.0)
	var died_count := [0]
	h.died.connect(func() -> void: died_count[0] += 1)
	h.take_damage(4.0)
	assert_eq(died_count[0], 0)
	h.take_damage(6.0)
	assert_eq(died_count[0], 1)
	h.take_damage(100.0)
	h.take_damage(1.0)
	assert_eq(died_count[0], 1, "no second death event")


func test_no_damage_after_death() -> void:
	var h := HealthScript.new(10.0)
	h.take_damage(10.0)
	var changed_count := [0]
	h.changed.connect(func(_hp: float, _max: float) -> void: changed_count[0] += 1)
	assert_true(not h.take_damage(5.0), "dead targets can't be killed again")
	assert_eq(changed_count[0], 0)
	assert_near(h.hp, 0.0)


func test_non_positive_damage_is_ignored_and_never_heals() -> void:
	var h := HealthScript.new(40.0)
	h.take_damage(15.0)
	assert_true(not h.take_damage(0.0))
	assert_true(not h.take_damage(-20.0))
	assert_near(h.hp, 25.0, 1e-6, "negative damage must not heal")


func test_changed_signal_carries_values() -> void:
	var h := HealthScript.new(40.0)
	var seen := [0.0, 0.0]
	h.changed.connect(func(hp: float, max_hp: float) -> void:
		seen[0] = hp
		seen[1] = max_hp)
	h.take_damage(10.0)
	assert_near(seen[0], 30.0)
	assert_near(seen[1], 40.0)
