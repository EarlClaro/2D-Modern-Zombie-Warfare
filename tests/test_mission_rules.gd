extends TestCase

const Rules := preload("res://scripts/missions/mission_rules.gd")


func test_running_at_start_and_before_time_with_core_alive() -> void:
	var r := Rules.new(90.0)
	assert_true(not r.is_ended())
	assert_eq(r.evaluate(500.0, 0.0).status, Rules.Status.RUNNING)
	assert_eq(r.evaluate(120.0, 89.99).status, Rules.Status.RUNNING)
	assert_true(not r.is_ended())


func test_win_when_time_is_up_with_core_alive() -> void:
	var r := Rules.new(90.0)
	var res := r.evaluate(1.0, 90.0)
	assert_eq(res.status, Rules.Status.WON)
	assert_true(res.reason.length() > 0)
	assert_true(r.is_ended())


func test_win_when_elapsed_overshoots_duration() -> void:
	var r := Rules.new(90.0)
	assert_eq(r.evaluate(200.0, 93.5).status, Rules.Status.WON)


func test_fail_when_core_destroyed_before_time() -> void:
	var r := Rules.new(90.0)
	var res := r.evaluate(0.0, 12.0)
	assert_eq(res.status, Rules.Status.FAILED)
	assert_true("core" in res.reason)
	assert_true(r.is_ended())


func test_negative_core_hp_counts_as_destroyed() -> void:
	var r := Rules.new(90.0)
	assert_eq(r.evaluate(-30.0, 5.0).status, Rules.Status.FAILED)


func test_same_tick_win_and_fail_resolves_to_fail() -> void:
	var r := Rules.new(90.0)
	var res := r.evaluate(0.0, 90.0)
	assert_eq(res.status, Rules.Status.FAILED, "ADR-007: fail wins")
	assert_true("same tick" in res.reason, "reason explains the tie: " + res.reason)


func test_same_tick_with_overshoot_still_fails() -> void:
	var r := Rules.new(90.0)
	assert_eq(r.evaluate(-1.0, 95.0).status, Rules.Status.FAILED)


func test_ends_exactly_once_signal() -> void:
	var r := Rules.new(10.0)
	var count := [0]
	r.ended.connect(func(_res: Rules.Result) -> void: count[0] += 1)
	r.evaluate(100.0, 3.0)
	assert_eq(count[0], 0)
	r.evaluate(100.0, 10.0)
	assert_eq(count[0], 1)
	r.evaluate(0.0, 11.0)
	r.evaluate(100.0, 12.0)
	assert_eq(count[0], 1, "never emitted again")


func test_first_result_is_final_after_fail() -> void:
	var r := Rules.new(10.0)
	r.evaluate(0.0, 4.0)
	# Later "good" inputs cannot revive or win the mission.
	assert_eq(r.evaluate(500.0, 50.0).status, Rules.Status.FAILED)
	assert_eq(r.result().status, Rules.Status.FAILED)


func test_first_result_is_final_after_win() -> void:
	var r := Rules.new(10.0)
	r.evaluate(100.0, 10.0)
	# Core dying after the win is ignored (later events are ignored).
	assert_eq(r.evaluate(0.0, 11.0).status, Rules.Status.WON)
	assert_eq(r.result().status, Rules.Status.WON)


func test_result_object_is_stable_once_ended() -> void:
	var r := Rules.new(10.0)
	var first := r.evaluate(0.0, 1.0)
	var second := r.evaluate(0.0, 2.0)
	assert_true(first == second, "same Result instance returned")


func test_running_result_has_reason() -> void:
	var r := Rules.new(10.0)
	var res := r.evaluate(50.0, 1.0)
	assert_true(res.reason.length() > 0)
	assert_true(not r.is_ended())
