extends TestCase
## UnitBrain is pure: every decision here is a function of its inputs only.

const Brain := preload("res://scripts/combat/unit_brain.gd")
const ANCHOR := Vector2(10.0, 10.0)


func _moves(d: UnitBrain.Decision) -> bool:
	return d.action == UnitBrain.Action.MOVE


# --- guard -----------------------------------------------------------------------------------------

func test_guard_with_something_in_range_stays_put() -> void:
	var d := Brain.guard(Vector2(12, 10), ANCHOR, 8.0, 6.0, true, true, Vector2(18, 10))
	assert_true(not _moves(d))


func test_guard_with_something_in_range_stays_even_if_not_at_its_ideal_distance() -> void:
	# 7.8 tiles from the enemy: in range (8) but farther than the 90 % spot (7.2); in range wins, it does not shuffle closer
	var d := Brain.guard(Vector2(10, 10), ANCHOR, 8.0, 6.0, true, true, Vector2(17.8, 10))
	assert_true(not _moves(d))
	var a := Brain.advance(Vector2(10, 10), Vector2(3, 3), 8.0, 12.0, true, true, Vector2(17.8, 10))
	assert_true(not _moves(a))


func test_guard_with_no_enemy_at_its_anchor_stays() -> void:
	assert_true(not _moves(Brain.guard(ANCHOR, ANCHOR, 8.0, 6.0, false, false, Vector2.ZERO)))
	assert_true(not _moves(Brain.guard(ANCHOR + Vector2(0.1, 0.0), ANCHOR, 8.0, 6.0, false, false, Vector2.ZERO)), "within the arrive tolerance")


func test_guard_with_no_enemy_walks_back_to_its_anchor() -> void:
	var d := Brain.guard(Vector2(14, 10), ANCHOR, 8.0, 6.0, false, false, Vector2.ZERO)
	assert_true(_moves(d))
	assert_vec_near(d.dest, ANCHOR)


func test_guard_goes_to_a_spot_at_ninety_percent_of_range_from_the_enemy() -> void:
	# anchor (10,10), enemy 11 tiles east: the spot is 7.2 from the enemy on the line toward the unit = x 13.8, inside the leash
	var d := Brain.guard(ANCHOR, ANCHOR, 8.0, 6.0, false, true, Vector2(21, 10))
	assert_true(_moves(d))
	assert_vec_near(d.dest, Vector2(13.8, 10.0), 1e-4)
	assert_near(d.dest.distance_to(Vector2(21, 10)), 8.0 * Brain.RANGE_MARGIN, 1e-4)


func test_guard_spot_is_clamped_to_the_leash() -> void:
	# the enemy is so far that the 90 % spot lies beyond the leash: it stops at the leash edge, still in range
	var d := Brain.guard(ANCHOR, ANCHOR, 8.0, 3.0, false, true, Vector2(20.5, 10))  # the 90 % spot would be 3.3 out
	assert_true(_moves(d))
	assert_near(d.dest.distance_to(ANCHOR), 3.0, 1e-4, "on the leash circle")
	assert_true(d.dest.distance_to(Vector2(20.5, 10)) <= 8.0, "and in range of the enemy")


func test_guard_ignores_an_enemy_the_leash_would_never_let_it_reach() -> void:
	var d := Brain.guard(ANCHOR, ANCHOR, 8.0, 3.0, false, true, Vector2(25, 10))
	assert_true(not _moves(d), "nearest reachable spot is still out of range")


func test_guard_keeps_the_place_it_has_when_already_inside_the_firing_distance() -> void:
	# enemy within 90 % of range yet 'in_range' false is only possible with other inputs; the spot is then the unit itself
	var d := Brain.guard(Vector2(12, 10), ANCHOR, 8.0, 6.0, false, true, Vector2(17, 10))
	assert_true(not _moves(d))


# --- advance ---------------------------------------------------------------------------------------

func test_advance_stays_with_a_target_in_range_or_without_a_front() -> void:
	assert_true(not _moves(Brain.advance(Vector2(8, 8), Vector2(3, 3), 9.0, 12.0, true, true, Vector2(20, 8))))
	assert_true(not _moves(Brain.advance(Vector2(8, 8), Vector2(3, 3), 9.0, 12.0, false, false, Vector2.ZERO)))


func test_advance_walks_to_a_firing_spot_near_the_front_enemy() -> void:
	var d := Brain.advance(Vector2(8, 8), Vector2(3, 3), 9.0, 20.0, false, true, Vector2(20, 8))
	assert_true(_moves(d))
	assert_near(d.dest.distance_to(Vector2(20, 8)), 9.0 * Brain.RANGE_MARGIN, 1e-4)
	assert_near(d.dest.y, 8.0, 1e-4, "on the straight line between the unit and the enemy")


func test_advance_never_goes_beyond_the_limit_from_the_core() -> void:
	var core := Vector2(3, 3)
	var d := Brain.advance(Vector2(6, 3), core, 9.0, 2.5, false, true, Vector2(14, 3))  # the 90 % spot would be 2.9 out
	assert_true(_moves(d))
	assert_near(d.dest.distance_to(core), 2.5, 1e-4, "clamped to the limit circle")
	assert_true(d.dest.distance_to(Vector2(14, 3)) <= 9.0, "still in range of the enemy")


func test_advance_stays_when_the_limit_keeps_it_out_of_range() -> void:
	assert_true(not _moves(Brain.advance(Vector2(6, 3), Vector2(3, 3), 9.0, 4.0, false, true, Vector2(30, 3))))


# --- support ---------------------------------------------------------------------------------------

func test_support_without_a_friend_or_close_enough_stays() -> void:
	assert_true(not _moves(Brain.support(Vector2(5, 5), false, Vector2.ZERO)))
	assert_true(not _moves(Brain.support(Vector2(5, 5), true, Vector2(5 + Brain.FOLLOW_GAP - 0.1, 5))))


func test_support_walks_to_stand_next_to_a_far_friend() -> void:
	var d := Brain.support(Vector2(5, 5), true, Vector2(11, 5))
	assert_true(_moves(d))
	assert_vec_near(d.dest, Vector2(11.0 - Brain.FOLLOW_STAND, 5.0), 1e-4)


# --- determinism and definition rules ----------------------------------------------------------------

func test_the_same_inputs_always_give_the_same_decision() -> void:
	var a := Brain.guard(Vector2(11, 9), ANCHOR, 8.0, 6.0, false, true, Vector2(22, 12))
	var b := Brain.guard(Vector2(11, 9), ANCHOR, 8.0, 6.0, false, true, Vector2(22, 12))
	assert_eq(a.action, b.action)
	assert_vec_near(a.dest, b.dest, 0.0)


func test_fixed_units_and_structures_always_hold_whatever_their_data_says() -> void:
	var db := ContentDb.load_from()
	var nest := db.unit("mg_nest").duplicate()
	nest.behavior = UnitBrain.Behavior.ADVANCE
	assert_eq(nest.effective_behavior(), UnitBrain.Behavior.HOLD)
	var wall := db.unit("sandbag_wall").duplicate()
	wall.behavior = UnitBrain.Behavior.GUARD
	assert_eq(wall.effective_behavior(), UnitBrain.Behavior.HOLD)


func test_mobile_units_use_their_own_behaviour() -> void:
	var db := ContentDb.load_from()
	assert_eq(db.unit("rifle_soldier").effective_behavior(), UnitBrain.Behavior.KITE)
	assert_eq(db.unit("rpg_soldier").effective_behavior(), UnitBrain.Behavior.KITE)
	assert_eq(db.unit("tank").effective_behavior(), UnitBrain.Behavior.KITE)
	assert_eq(db.unit("scout").effective_behavior(), UnitBrain.Behavior.KITE)


func test_behaviour_distances_must_be_positive() -> void:
	var u := ContentDb.load_from().unit("rifle_soldier").duplicate()
	assert_true(u.validate().is_empty())
	u.leash = 0.0
	assert_true(not u.validate().is_empty(), "leash")
	u.leash = 6.0
	u.advance_limit = -1.0
	assert_true(not u.validate().is_empty(), "advance_limit")
	u.advance_limit = 12.0
	u.follow_range = 0.0
	assert_true(not u.validate().is_empty(), "follow_range")


# --- cover -----------------------------------------------------------------------------------------

func test_cover_spot_is_behind_the_structure_as_seen_from_the_enemy() -> void:
	var c: Variant = Brain.cover_spot(ANCHOR, Vector2(20, 10), 8.0, ANCHOR, 6.0, PackedVector2Array([Vector2(14, 10)]))
	assert_true(c != null)
	assert_vec_near(c, Vector2(14.0 - Brain.COVER_BEHIND, 10.0), 1e-4)


func test_cover_spot_needs_range_leash_and_a_short_walk() -> void:
	var wall := PackedVector2Array([Vector2(14, 10)])
	assert_true(Brain.cover_spot(ANCHOR, Vector2(23, 10), 8.0, ANCHOR, 6.0, wall) == null, "the spot would be out of weapon range")
	assert_true(Brain.cover_spot(ANCHOR, Vector2(20, 10), 8.0, ANCHOR, 2.0, wall) == null, "the spot would be outside the leash")
	assert_true(Brain.cover_spot(Vector2(2, 10), Vector2(20, 10), 8.0, Vector2(2, 10), 20.0, wall) == null, "too long a walk")
	assert_true(Brain.cover_spot(ANCHOR, Vector2(14.2, 10), 8.0, ANCHOR, 6.0, wall) == null, "a structure on top of the enemy is no cover")
	assert_true(Brain.cover_spot(ANCHOR, Vector2(20, 10), 8.0, ANCHOR, 6.0, PackedVector2Array()) == null, "no structures")


func test_cover_spot_takes_the_shorter_walk() -> void:
	var walls := PackedVector2Array([Vector2(14, 10), Vector2(14, 12)])
	var near_first: Variant = Brain.cover_spot(Vector2(10, 10), Vector2(20, 10), 8.0, ANCHOR, 6.0, walls)
	assert_vec_near(near_first, Vector2(13.1, 10.0), 1e-3)
	var near_second: Variant = Brain.cover_spot(Vector2(10, 13), Vector2(20, 10), 8.0, ANCHOR, 6.0, walls)
	assert_true(near_second.y > 12.0, "from the south the second wall is the shorter walk")


func test_in_cover_needs_a_close_structure_that_is_nearer_the_enemy() -> void:
	var wall := PackedVector2Array([Vector2(14, 10)])
	assert_true(Brain.in_cover(Vector2(13.5, 10), Vector2(20, 10), wall))
	assert_true(not Brain.in_cover(Vector2(10, 10), Vector2(20, 10), wall), "too far from the wall")
	assert_true(not Brain.in_cover(Vector2(14.5, 10), Vector2(20, 10), wall), "in front of the wall, not behind it")


func test_guard_walks_to_cover_even_when_it_could_already_fire() -> void:
	var wall := PackedVector2Array([Vector2(14, 10)])
	var d := Brain.guard(ANCHOR, ANCHOR, 8.0, 6.0, true, true, Vector2(17.5, 10), wall)
	assert_true(_moves(d), "in range, but not in cover")
	assert_vec_near(d.dest, Vector2(13.1, 10.0), 1e-3)


func test_guard_fights_where_it_stands_when_an_enemy_is_already_on_it() -> void:
	var wall := PackedVector2Array([Vector2(14, 10)])
	assert_true(not _moves(Brain.guard(ANCHOR, ANCHOR, 8.0, 6.0, true, true, Vector2(17.5, 10), wall, true)))


func test_guard_in_cover_with_a_target_stays() -> void:
	var wall := PackedVector2Array([Vector2(14, 10)])
	assert_true(not _moves(Brain.guard(Vector2(13.1, 10), ANCHOR, 8.0, 6.0, true, true, Vector2(17.5, 10), wall)))


func test_guard_without_structures_ignores_the_cover_habit() -> void:
	assert_true(not _moves(Brain.guard(ANCHOR, ANCHOR, 8.0, 6.0, true, true, Vector2(17.5, 10))))


# --- retreat ---------------------------------------------------------------------------------------

func test_retreat_stays_when_no_enemy_is_near() -> void:
	assert_true(not _moves(Brain.retreat(Vector2(12, 10), Vector2(3, 10), false)))


func test_retreat_walks_toward_the_core_and_stops_a_short_way_out() -> void:
	var d := Brain.retreat(Vector2(12, 10), Vector2(3, 10), true)
	assert_true(_moves(d))
	assert_vec_near(d.dest, Vector2(3.0 + Brain.RETREAT_STAND, 10.0), 1e-4)
	assert_true(not _moves(Brain.retreat(Vector2(3.0 + Brain.RETREAT_STAND + 0.1, 10), Vector2(3, 10), true)), "already as close as it goes")
	assert_true(not _moves(Brain.retreat(Vector2(3, 10), Vector2(3, 10), true)), "standing on the core")
	assert_true(not _moves(Brain.retreat(Vector2(4, 10), Vector2(3, 10), true)), "closer than the stand-off already: it does not back away from the core")


func test_habits_are_on_by_default_and_checked() -> void:
	var u := ContentDb.load_from().unit("rifle_soldier").duplicate()
	assert_true(u.seeks_cover and u.retreats and u.focus_fire)
	assert_true(u.retreat_below > 0.0 and u.retreat_below < 1.0)
	u.retreat_below = 1.0
	assert_true(not u.validate().is_empty(), "retreat_below of 1 would make a full-health unit run")
	u.retreat_below = -0.1
	assert_true(not u.validate().is_empty())

