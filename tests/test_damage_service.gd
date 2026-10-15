extends TestCase

const Dmg := preload("res://scripts/combat/damage_service.gd")


func test_no_armor_full_damage() -> void:
	assert_near(Dmg.compute(12.0), 12.0)
	assert_near(Dmg.compute(12.0, 0.0, 1.0), 12.0)


func test_armor_reduces_flat() -> void:
	assert_near(Dmg.compute(12.0, 5.0), 7.0)


func test_minimum_damage_floor() -> void:
	# armor >= base: floor is 10% of base
	assert_near(Dmg.compute(8.0, 8.0), 0.8, 1e-6)
	assert_near(Dmg.compute(8.0, 100.0), 0.8, 1e-6)
	# armor just below the floor threshold still follows the formula
	assert_near(Dmg.compute(10.0, 8.5), 1.5, 1e-6)
	assert_near(Dmg.compute(10.0, 9.5), 1.0, 1e-6, "floor kicks in")


func test_zero_and_negative_base_do_nothing() -> void:
	assert_near(Dmg.compute(0.0, 3.0), 0.0)
	assert_near(Dmg.compute(-5.0), 0.0)


func test_negative_armor_is_ignored() -> void:
	assert_near(Dmg.compute(10.0, -4.0), 10.0, 1e-6, "armor can't amplify damage")


func test_falloff_multiplies_after_armor() -> void:
	assert_near(Dmg.compute(20.0, 5.0, 0.5), 7.5, 1e-6)
	assert_near(Dmg.compute(20.0, 0.0, 0.0), 0.0)


func test_falloff_is_clamped() -> void:
	assert_near(Dmg.compute(10.0, 0.0, 2.0), 10.0, 1e-6)
	assert_near(Dmg.compute(10.0, 0.0, -1.0), 0.0, 1e-6)


func test_result_never_negative() -> void:
	for base in [0.0, 0.5, 1.0, 10.0, 1000.0]:
		for armor in [0.0, 1.0, 50.0, 5000.0]:
			for f in [0.0, 0.3, 1.0]:
				assert_true(Dmg.compute(base, armor, f) >= 0.0, "base %s armor %s falloff %s" % [base, armor, f])


func test_blast_falloff_centre_edge_outside() -> void:
	assert_near(Dmg.blast_falloff(0.0, 3.0), 1.0)
	assert_near(Dmg.blast_falloff(3.0, 3.0), Dmg.MIN_FALLOFF, 1e-6, "edge is inclusive")
	assert_near(Dmg.blast_falloff(1.5, 3.0), (1.0 + Dmg.MIN_FALLOFF) * 0.5, 1e-6, "linear midpoint")
	assert_near(Dmg.blast_falloff(3.001, 3.0), 0.0)
	assert_near(Dmg.blast_falloff(100.0, 3.0), 0.0)


func test_blast_falloff_is_monotonic_and_bounded() -> void:
	var prev := 2.0
	for i in 41:
		var f := Dmg.blast_falloff(i * 0.1, 4.0)
		assert_true(f >= 0.0 and f <= 1.0, "bounded at %d" % i)
		assert_true(f <= prev + 1e-9, "non-increasing at %d" % i)
		prev = f


func test_blast_falloff_degenerate_radius() -> void:
	assert_near(Dmg.blast_falloff(0.0, 0.0), 1.0)
	assert_near(Dmg.blast_falloff(0.1, 0.0), 0.0)
	assert_near(Dmg.blast_falloff(-1.0, 2.0), 1.0, 1e-6, "negative distance treated as centre")


func test_blast_with_armor_end_to_end() -> void:
	# 40 dmg shell, brute armor 10, target 2 tiles from centre of a 4-tile blast.
	var falloff := Dmg.blast_falloff(2.0, 4.0)
	assert_near(Dmg.compute(40.0, 10.0, falloff), 30.0 * falloff, 1e-6)
