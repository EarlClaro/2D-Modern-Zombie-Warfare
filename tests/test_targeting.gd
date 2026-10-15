extends TestCase

const Targeting := preload("res://scripts/combat/targeting_service.gd")
const Candidate := preload("res://scripts/combat/target_candidate.gd")
const Iso := preload("res://scripts/iso/iso_projection.gd")


func _list(items: Array) -> Array[TargetCandidate]:
	var out: Array[TargetCandidate] = []
	for it in items:
		out.append(it)
	return out


func test_empty_list_returns_no_target() -> void:
	assert_eq(Targeting.pick(Vector2.ZERO, 10.0, _list([])), Targeting.NO_TARGET)


func test_nearest_wins() -> void:
	var cs := _list([Candidate.new(1, Vector2(5, 0)), Candidate.new(2, Vector2(2, 0)), Candidate.new(3, Vector2(4, 0))])
	assert_eq(Targeting.pick(Vector2.ZERO, 10.0, cs), 2)


func test_origin_offset_is_respected() -> void:
	var cs := _list([Candidate.new(1, Vector2(10, 10)), Candidate.new(2, Vector2(0, 0))])
	assert_eq(Targeting.pick(Vector2(9, 9), 5.0, cs), 1)


func test_out_of_range_is_ignored() -> void:
	var cs := _list([Candidate.new(1, Vector2(8.5, 0)), Candidate.new(2, Vector2(20, 0))])
	assert_eq(Targeting.pick(Vector2.ZERO, 8.0, cs), Targeting.NO_TARGET)


func test_range_is_inclusive_at_exact_distance() -> void:
	var cs := _list([Candidate.new(4, Vector2(8, 0))])
	assert_eq(Targeting.pick(Vector2.ZERO, 8.0, cs), 4, "exactly at range is a valid target")
	var just_out := _list([Candidate.new(4, Vector2(8.001, 0))])
	assert_eq(Targeting.pick(Vector2.ZERO, 8.0, just_out), Targeting.NO_TARGET)


func test_dead_candidates_are_ignored() -> void:
	var cs := _list([Candidate.new(1, Vector2(1, 0), false), Candidate.new(2, Vector2(6, 0), true)])
	assert_eq(Targeting.pick(Vector2.ZERO, 10.0, cs), 2, "nearer dead one skipped")
	var all_dead := _list([Candidate.new(1, Vector2(1, 0), false), Candidate.new(2, Vector2(2, 0), false)])
	assert_eq(Targeting.pick(Vector2.ZERO, 10.0, all_dead), Targeting.NO_TARGET)


func test_tie_goes_to_lowest_id_regardless_of_order() -> void:
	# (3,0), (0,3) and (-3,0) are all exactly 3 tiles away.
	var a := _list([Candidate.new(7, Vector2(3, 0)), Candidate.new(3, Vector2(0, 3)), Candidate.new(5, Vector2(-3, 0))])
	var b := _list([Candidate.new(5, Vector2(-3, 0)), Candidate.new(3, Vector2(0, 3)), Candidate.new(7, Vector2(3, 0))])
	assert_eq(Targeting.pick(Vector2.ZERO, 10.0, a), 3)
	assert_eq(Targeting.pick(Vector2.ZERO, 10.0, b), 3)


func test_distance_is_ground_not_screen() -> void:
	var a := Candidate.new(1, Vector2(3, 0))    # ground distance 3.0
	var d := Candidate.new(2, Vector2(2, -2))   # ground distance 2.83 (nearer)
	# On screen the order is the opposite: D is farther from the origin than A.
	assert_true(Iso.ground_to_screen(d.pos).length() > Iso.ground_to_screen(a.pos).length(), "screen order differs")
	assert_eq(Targeting.pick(Vector2.ZERO, 10.0, _list([a, d])), 2, "ground-nearest wins")


func test_equal_ground_distance_in_different_directions_is_a_tie() -> void:
	# Same ground distance, very different screen distances -> still treated as equal (lowest id).
	var east := Candidate.new(9, Vector2(4, -4).normalized() * 4.0)  # screen-right
	var south := Candidate.new(2, Vector2(4, 4).normalized() * 4.0)  # screen-down
	var got := Targeting.pick(Vector2.ZERO, 10.0, _list([east, south]))
	var d_east := east.pos.length()
	var d_south := south.pos.length()
	if is_equal_approx(d_east, d_south) and d_east == d_south:
		assert_eq(got, 2)
	else:
		# Float noise broke the exact tie; the nearer ground distance must still win.
		assert_eq(got, 9 if d_east < d_south else 2)


func test_non_positive_range_returns_no_target() -> void:
	var cs := _list([Candidate.new(1, Vector2.ZERO)])
	assert_eq(Targeting.pick(Vector2.ZERO, 0.0, cs), Targeting.NO_TARGET)
	assert_eq(Targeting.pick(Vector2.ZERO, -3.0, cs), Targeting.NO_TARGET)


func test_candidate_on_top_of_origin_is_valid() -> void:
	assert_eq(Targeting.pick(Vector2(2, 2), 1.0, _list([Candidate.new(5, Vector2(2, 2))])), 5)


func test_large_list_picks_true_minimum_and_does_not_mutate() -> void:
	var cs: Array[TargetCandidate] = []
	for i in 100:
		cs.append(Candidate.new(i + 1, Vector2(float(i % 10) * 1.3 + 1.0, float(i / 10) * 0.9 - 4.0)))
	var best_id := -1
	var best := INF
	for c in cs:
		var d := c.pos.length()
		if d <= 12.0 and d < best:
			best = d
			best_id = c.id
	assert_eq(Targeting.pick(Vector2.ZERO, 12.0, cs), best_id)
	assert_eq(cs.size(), 100, "input untouched")
