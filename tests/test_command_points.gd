extends TestCase


func _rules() -> DeckRules:
	var r := DeckRules.new()
	r.id = "default"
	return r


func test_starts_at_rules_value() -> void:
	var cp := CommandPoints.from_rules(_rules())
	assert_near(cp.cp, 5.0)
	assert_eq(cp.whole(), 5)


func test_regen_is_one_per_interval_over_simulated_time() -> void:
	var r := _rules()
	r.cp_start = 0.0
	r.cp_regen_interval_s = 1.5
	for delta in [1.0 / 30.0, 1.0 / 60.0, 1.0 / 120.0]:
		var cp := CommandPoints.from_rules(r)
		var steps := int(round(6.0 / delta))
		for i in steps:
			cp.tick(delta)
		assert_near(cp.cp, 4.0, 1e-3, "6 s at 1 CP / 1.5 s = 4 CP (delta %s)" % str(delta))


func test_exactly_one_interval_makes_one_point_affordable() -> void:
	# 90 ticks of 1/60 s is 1.5 s; float error must not leave the player 1e-15 short of a 1-cost card.
	var r := _rules()
	r.cp_start = 0.0
	var cp := CommandPoints.from_rules(r)
	for i in 90:
		cp.tick(1.0 / 60.0)
	assert_true(cp.can_afford(1))
	assert_eq(cp.whole(), 1)


func test_caps_at_cap() -> void:
	var cp := CommandPoints.from_rules(_rules())
	cp.tick(1000.0)
	assert_near(cp.cp, 10.0)
	cp.tick(5.0)
	assert_near(cp.cp, 10.0)


func test_spend_succeeds_exactly_at_cost_and_fails_below_without_change() -> void:
	var cp := CommandPoints.new(3.0, 10.0, 1.0)
	assert_true(cp.can_afford(3))
	assert_true(not cp.can_afford(4))
	assert_true(not cp.spend(4), "cannot overspend")
	assert_near(cp.cp, 3.0, 1e-9, "failed spend changes nothing")
	assert_true(cp.spend(3))
	assert_near(cp.cp, 0.0, 1e-9)


func test_zero_cost_is_always_affordable_and_negative_delta_is_ignored() -> void:
	var cp := CommandPoints.new(0.0, 10.0, 1.0)
	assert_true(cp.spend(0))
	cp.tick(-5.0)
	assert_near(cp.cp, 0.0, 1e-9, "time never runs backwards")


func test_start_above_cap_is_clamped() -> void:
	var cp := CommandPoints.new(50.0, 10.0, 1.0)
	assert_near(cp.cp, 10.0)
