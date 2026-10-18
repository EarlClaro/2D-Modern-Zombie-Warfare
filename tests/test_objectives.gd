extends TestCase
## Mission objectives (M3.12, horde-and-objectives spec D4/D5): the definition and its validation, the pure tracker, the rules
## built on it (primary / secondary / fail, fail wins ties, ends once) and the battle wiring. Missions without objectives keep
## the Milestone 1 rule exactly (test_mission_rules.gd runs unchanged).

const Kind := ObjectiveDefinition.Kind
const Role := ObjectiveDefinition.Role
const State := ObjectiveTracker.State
const Rules := preload("res://scripts/missions/mission_rules.gd")
const DT: float = 1.0 / 60.0

var _db: ContentDb
var _made: Array[BattleController] = []


func _get_db() -> ContentDb:
	if _db == null:
		_db = ContentDb.load_from()
	return _db


func _has(errs: PackedStringArray, needle: String) -> bool:
	for e in errs:
		if needle in e:
			return true
	return false


func _obj(id: String, kind: Kind, role: Role, seconds: float = 0.0, fraction: float = 0.0, count: int = 0) -> ObjectiveDefinition:
	var o := ObjectiveDefinition.new()
	o.id = id
	o.kind = kind
	o.role = role
	o.seconds = seconds
	o.fraction = fraction
	o.count = count
	return o


func _survive(id: String, seconds: float, role: Role = Role.PRIMARY) -> ObjectiveDefinition:
	return _obj(id, Kind.SURVIVE, role, seconds)


func _core(id: String, fraction: float, role: Role = Role.PRIMARY) -> ObjectiveDefinition:
	return _obj(id, Kind.CORE_HEALTH_AT_LEAST, role, 0.0, fraction)


func _kills(id: String, count: int, role: Role = Role.PRIMARY) -> ObjectiveDefinition:
	return _obj(id, Kind.KILL_COUNT, role, 0.0, 0.0, count)


func _clear(id: String, role: Role = Role.PRIMARY) -> ObjectiveDefinition:
	return _obj(id, Kind.CLEAR_WAVES, role)


func _list(items: Array) -> Array[ObjectiveDefinition]:
	var out: Array[ObjectiveDefinition] = []
	for o in items:
		out.append(o)
	return out


func _facts(elapsed: float = 0.0, hp: float = 100.0, kills: int = 0, alive: int = 0, spawned: int = 0, planned: int = 0, core_max: float = 100.0) -> ObjectiveTracker.Facts:
	var f := ObjectiveTracker.Facts.new()
	f.elapsed_s = elapsed
	f.core_hp = hp
	f.core_max = core_max
	f.kills = kills
	f.alive = alive
	f.spawned = spawned
	f.planned = planned
	return f


func _tracker(items: Array) -> ObjectiveTracker:
	return ObjectiveTracker.new(_list(items))


func _rules(items: Array, duration: float = 100.0) -> Rules:
	return Rules.new(duration, _list(items))


# --- ObjectiveDefinition ------------------------------------------------------------------------

func test_a_well_formed_objective_of_each_kind_validates() -> void:
	assert_eq(_survive("s", 90.0).validate().size(), 0)
	assert_eq(_core("c", 0.5).validate().size(), 0)
	assert_eq(_core("c", 1.0).validate().size(), 0, "1.0 = any damage fails it, allowed")
	assert_eq(_kills("k", 1).validate().size(), 0)
	assert_eq(_clear("w").validate().size(), 0)


func test_objective_parameters_must_be_positive() -> void:
	assert_true(_has(_survive("s", 0.0).validate(), "seconds > 0"))
	assert_true(_has(_survive("s", -5.0).validate(), "seconds > 0"))
	assert_true(_has(_core("c", 0.0).validate(), "0 < fraction <= 1"))
	assert_true(_has(_core("c", 1.5).validate(), "0 < fraction <= 1"))
	assert_true(_has(_kills("k", 0).validate(), "count >= 1"))
	assert_true(_has(_kills("k", -3).validate(), "count >= 1"))


func test_an_objective_needs_an_id() -> void:
	assert_true(_has(_survive("", 10.0).validate(), "empty id"))


func test_only_a_core_threshold_can_take_the_fail_role() -> void:
	assert_eq(_core("c", 0.3, Role.FAIL).validate().size(), 0)
	assert_true(_has(_survive("s", 10.0, Role.FAIL).validate(), "could never fail"))
	assert_true(_has(_kills("k", 5, Role.FAIL).validate(), "could never fail"))
	assert_true(_has(_clear("w", Role.FAIL).validate(), "could never fail"))


func test_the_phrases_say_what_happened() -> void:
	assert_eq(_survive("s", 90.0).met_phrase(), "core held for 90 seconds")
	assert_eq(_kills("k", 300).met_phrase(), "300 enemies destroyed")
	assert_eq(_clear("w").met_phrase(), "every wave destroyed")
	assert_eq(_core("c", 0.5).met_phrase(), "core held above 50 %")
	assert_eq(_survive("s", 90.0).tie_phrase(), "the timer expired")
	assert_eq(_kills("k", 300).tie_phrase(), "the kill target was reached")
	assert_eq(_clear("w").tie_phrase(), "the last wave was cleared")
	assert_eq(_core("c", 0.5).failed_phrase(), "core fell below 50 %")
	assert_true("'k'" in _kills("k", 3).failed_phrase())


# --- ObjectiveTracker: one kind at a time ---------------------------------------------------------

func test_survive_is_met_exactly_at_its_time() -> void:
	var t := _tracker([_survive("s", 60.0)])
	t.update(_facts(59.99))
	assert_eq(t.state(0), State.PENDING)
	t.update(_facts(60.0))
	assert_eq(t.state(0), State.MET)


func test_kill_count_is_met_at_its_count_and_stays_met() -> void:
	var t := _tracker([_kills("k", 10)])
	t.update(_facts(1.0, 100.0, 9))
	assert_eq(t.state(0), State.PENDING)
	t.update(_facts(2.0, 100.0, 10))
	assert_eq(t.state(0), State.MET)
	t.update(_facts(3.0, 100.0, 2))  # cannot happen in a battle, but a met objective never reverts
	assert_eq(t.state(0), State.MET)


func test_clear_waves_needs_everything_spawned_and_nothing_alive() -> void:
	var t := _tracker([_clear("w")])
	t.update(_facts(5.0, 100.0, 4, 0, 4, 10))
	assert_eq(t.state(0), State.PENDING, "none alive but more still to come")
	t.update(_facts(6.0, 100.0, 4, 3, 10, 10))
	assert_eq(t.state(0), State.PENDING, "all spawned but some alive")
	t.update(_facts(7.0, 100.0, 10, 0, 10, 10))
	assert_eq(t.state(0), State.MET)


func test_clear_waves_with_nothing_planned_is_never_met() -> void:
	var t := _tracker([_clear("w")])
	t.update(_facts(5.0, 100.0, 0, 0, 0, 0))
	assert_eq(t.state(0), State.PENDING)


func test_core_threshold_holds_at_the_line_and_breaks_below_it() -> void:
	var t := _tracker([_core("c", 0.5)])
	t.update(_facts(1.0, 100.0))
	assert_eq(t.state(0), State.PENDING, "pending = holding")
	t.update(_facts(2.0, 50.0))
	assert_eq(t.state(0), State.PENDING, "exactly at the threshold still holds")
	t.update(_facts(3.0, 49.0))
	assert_eq(t.state(0), State.FAILED)


func test_a_broken_core_threshold_stays_failed() -> void:
	var t := _tracker([_core("c", 0.5)])
	t.update(_facts(1.0, 10.0))
	t.update(_facts(2.0, 90.0))  # there is no healing in the game, but a broken threshold is final anyway
	assert_eq(t.state(0), State.FAILED)


func test_a_core_threshold_with_an_unknown_maximum_counts_the_core_as_whole_while_it_lives() -> void:
	var t := _tracker([_core("c", 0.9)])
	t.update(_facts(1.0, 5.0, 0, 0, 0, 0, 0.0))
	assert_eq(t.state(0), State.PENDING)
	t.update(_facts(2.0, 0.0, 0, 0, 0, 0, 0.0))
	assert_eq(t.state(0), State.FAILED)


func test_values_and_targets_report_progress_in_each_kinds_own_unit() -> void:
	var t := _tracker([_survive("s", 60.0), _core("c", 0.5), _kills("k", 10), _clear("w")])
	t.update(_facts(15.0, 80.0, 4, 2, 6, 12))
	assert_near(t.value(0), 15.0)
	assert_near(t.target(0), 60.0)
	assert_near(t.progress(0), 0.25)
	assert_near(t.value(1), 0.8, 1e-5)
	assert_near(t.target(1), 0.5, 1e-5)
	assert_near(t.progress(1), 0.8, 1e-5, "a standing objective shows the core's share")
	assert_near(t.value(2), 4.0)
	assert_near(t.progress(2), 0.4, 1e-5)
	assert_near(t.value(3), 4.0, 1e-5, "enemies destroyed")
	assert_near(t.target(3), 12.0, 1e-5, "of those the mission sends")
	assert_near(t.progress(3), 1.0 / 3.0, 1e-5)


func test_clear_waves_has_no_progress_before_the_first_update() -> void:
	var t := _tracker([_clear("w")])
	assert_eq(t.progress(0), 0.0, "no division by an unknown total (that would be NaN)")


func test_values_stop_at_their_targets() -> void:
	var t := _tracker([_survive("s", 60.0), _kills("k", 10)])
	t.update(_facts(500.0, 100.0, 99))
	assert_near(t.value(0), 60.0)
	assert_near(t.value(1), 10.0)
	var c := _tracker([_clear("w")])
	c.update(_facts(5.0, 100.0, 20, 0, 12, 12))
	assert_near(c.value(0), 12.0, 1e-6, "never above the number planned")
	assert_near(t.progress(0), 1.0)


func test_index_of_finds_an_objective_by_id() -> void:
	var t := _tracker([_survive("a", 10.0), _kills("b", 3)])
	assert_eq(t.index_of("b"), 1)
	assert_eq(t.index_of("nope"), -1)


# --- ObjectiveTracker: roles --------------------------------------------------------------------

func test_would_win_needs_every_primary() -> void:
	var t := _tracker([_survive("s", 10.0), _kills("k", 5)])
	t.update(_facts(10.0, 100.0, 4))
	assert_true(not t.would_win())
	t.update(_facts(11.0, 100.0, 5))
	assert_true(t.would_win())


func test_a_secondary_objective_never_blocks_a_win_or_causes_a_loss() -> void:
	var t := _tracker([_survive("s", 10.0), _kills("k", 500, Role.SECONDARY), _core("c", 0.9, Role.SECONDARY)])
	t.update(_facts(10.0, 20.0, 3))
	assert_true(t.would_win())
	assert_eq(t.state(2), State.FAILED, "reported as failed")
	assert_eq(t.failed_index(), -1, "but it does not lose the mission")


func test_a_broken_fail_objective_is_reported_as_the_failure() -> void:
	var t := _tracker([_survive("s", 100.0), _core("danger", 0.25, Role.FAIL)])
	t.update(_facts(5.0, 30.0))
	assert_eq(t.failed_index(), -1)
	t.update(_facts(6.0, 24.0))
	assert_eq(t.failed_index(), 1)


func test_a_broken_primary_threshold_loses_the_mission_it_can_no_longer_win() -> void:
	var t := _tracker([_survive("s", 100.0), _core("c", 0.5)])
	t.update(_facts(5.0, 40.0))
	assert_eq(t.failed_index(), 1)
	assert_true(not t.would_win())
	var u := _tracker([_survive("s", 10.0), _core("c", 0.5)])
	u.update(_facts(10.0, 40.0))
	assert_eq(u.state(0), State.MET)
	assert_true(not u.would_win(), "everything else is met, but the broken threshold is not satisfied")


func test_a_standing_primary_alone_never_wins() -> void:
	var t := _tracker([_core("c", 0.5)])
	t.update(_facts(500.0, 100.0))
	assert_true(not t.would_win(), "there is nothing to complete")


func test_a_standing_primary_does_not_hold_up_a_win_while_intact() -> void:
	var t := _tracker([_survive("s", 10.0), _core("c", 0.5)])
	t.update(_facts(10.0, 70.0))
	assert_eq(t.state(1), State.PENDING)
	assert_true(t.would_win())


func test_last_met_primary_is_the_most_recent_and_ties_go_to_the_later() -> void:
	var t := _tracker([_survive("s", 10.0), _kills("k", 5), _kills("side", 1, Role.SECONDARY)])
	assert_eq(t.last_met_primary(), -1)
	t.update(_facts(2.0, 100.0, 1))
	assert_eq(t.last_met_primary(), -1, "a secondary does not count")
	t.update(_facts(3.0, 100.0, 5))
	assert_eq(t.last_met_primary(), 1)
	t.update(_facts(10.0, 100.0, 5))
	assert_eq(t.last_met_primary(), 0, "met later")
	var u := _tracker([_survive("s", 10.0), _kills("k", 5)])
	u.update(_facts(10.0, 100.0, 5))
	assert_eq(u.last_met_primary(), 1, "both on one tick: the later in the list")


func test_finish_when_won_settles_the_pending() -> void:
	var t := _tracker([_survive("s", 10.0), _core("c", 0.5, Role.SECONDARY), _kills("k", 99, Role.SECONDARY)])
	t.update(_facts(10.0, 80.0, 3))
	t.finish(true)
	assert_eq(t.state(0), State.MET)
	assert_eq(t.state(1), State.MET, "held to the end")
	assert_eq(t.state(2), State.FAILED, "never reached")


func test_finish_when_lost_fails_everything_pending() -> void:
	var t := _tracker([_survive("s", 10.0), _core("c", 0.5, Role.SECONDARY), _kills("k", 2, Role.SECONDARY)])
	t.update(_facts(4.0, 80.0, 2))
	t.finish(false)
	assert_eq(t.state(0), State.FAILED)
	assert_eq(t.state(1), State.FAILED)
	assert_eq(t.state(2), State.MET, "what was achieved stays achieved")


func test_updates_after_finish_change_nothing() -> void:
	var t := _tracker([_kills("k", 5)])
	t.update(_facts(1.0, 100.0, 2))
	t.finish(false)
	t.update(_facts(9.0, 100.0, 50))
	assert_eq(t.state(0), State.FAILED)
	assert_near(t.value(0), 2.0, 1e-6, "the numbers are frozen too")


# --- MissionRules ---------------------------------------------------------------------------------

func test_a_mission_without_objectives_gets_the_implicit_survive_objective() -> void:
	var r := Rules.new(75.0)
	assert_eq(r.tracker().size(), 1)
	assert_eq(r.tracker().definition(0).id, Rules.IMPLICIT_ID)
	assert_eq(r.tracker().definition(0).kind, Kind.SURVIVE)
	assert_eq(r.tracker().definition(0).role, Role.PRIMARY)
	assert_near(r.tracker().definition(0).seconds, 75.0)
	var res := r.evaluate(10.0, 75.0)
	assert_eq(res.status, Rules.Status.WON)
	assert_eq(res.reason, "core held for 75 seconds", "the Milestone 1 wording is kept")
	assert_eq(res.deciding_id, Rules.IMPLICIT_ID)


func test_the_implicit_tie_wording_is_kept() -> void:
	var res := Rules.new(75.0).evaluate(0.0, 75.0)
	assert_eq(res.status, Rules.Status.FAILED)
	assert_eq(res.reason, "core destroyed (on the same tick the timer expired)")
	assert_eq(res.deciding_id, Rules.CORE_ID)


func test_a_core_destroyed_early_has_no_tie_note() -> void:
	assert_eq(Rules.new(75.0).evaluate(0.0, 10.0).reason, "core destroyed")


func test_a_core_destroyed_with_only_some_primaries_met_has_no_tie_note() -> void:
	var res := _rules([_survive("hold", 30.0), _kills("purge", 9)]).evaluate(0.0, 31.0, _facts(31.0, 0.0, 2))
	assert_eq(res.reason, "core destroyed", "the timer was up but the mission was not yet won")


func test_every_primary_must_be_met_to_win() -> void:
	var r := _rules([_survive("hold", 30.0), _kills("purge", 8)])
	assert_eq(r.evaluate(100.0, 30.0, _facts(30.0, 100.0, 7)).status, Rules.Status.RUNNING, "time is up but the kill target is not")
	var res := r.evaluate(100.0, 31.0, _facts(31.0, 100.0, 8))
	assert_eq(res.status, Rules.Status.WON)
	assert_eq(res.reason, "core held for 30 seconds, 8 enemies destroyed")
	assert_eq(res.deciding_id, "purge", "the last objective to be met decided it")


func test_secondary_objectives_are_not_in_the_win_reason() -> void:
	var r := _rules([_survive("hold", 30.0), _kills("bonus", 1, Role.SECONDARY)])
	assert_eq(r.evaluate(100.0, 30.0, _facts(30.0, 100.0, 5)).reason, "core held for 30 seconds")


func test_clear_waves_as_primary_wins_early() -> void:
	var r := _rules([_clear("assault")], 600.0)
	assert_eq(r.evaluate(100.0, 20.0, _facts(20.0, 100.0, 5, 5, 10, 10)).status, Rules.Status.RUNNING)
	var res := r.evaluate(100.0, 40.0, _facts(40.0, 100.0, 10, 0, 10, 10))
	assert_eq(res.status, Rules.Status.WON, "long before the 600 s")
	assert_eq(res.reason, "every wave destroyed")


func test_a_secondary_objective_does_not_end_the_mission() -> void:
	var r := _rules([_survive("hold", 30.0), _kills("bonus", 3, Role.SECONDARY)])
	assert_eq(r.evaluate(100.0, 10.0, _facts(10.0, 100.0, 50)).status, Rules.Status.RUNNING, "the bonus is met, nothing ends")
	assert_eq(r.tracker().state(1), State.MET)


func test_a_fail_threshold_loses_the_moment_it_breaks() -> void:
	var r := _rules([_survive("hold", 30.0), _core("danger", 0.5, Role.FAIL)])
	assert_eq(r.evaluate(60.0, 5.0, _facts(5.0, 60.0)).status, Rules.Status.RUNNING)
	var res := r.evaluate(49.0, 6.0, _facts(6.0, 49.0))
	assert_eq(res.status, Rules.Status.FAILED)
	assert_eq(res.reason, "core fell below 50 %")
	assert_eq(res.deciding_id, "danger")


func test_a_broken_primary_threshold_loses() -> void:
	var r := _rules([_survive("hold", 30.0), _core("keep", 0.8)])
	var res := r.evaluate(70.0, 5.0, _facts(5.0, 70.0))
	assert_eq(res.status, Rules.Status.FAILED)
	assert_eq(res.deciding_id, "keep")


func test_fail_wins_when_the_core_dies_on_the_tick_a_kill_target_is_met() -> void:
	var r := _rules([_kills("purge", 5)])
	var res := r.evaluate(0.0, 12.0, _facts(12.0, 0.0, 5))
	assert_eq(res.status, Rules.Status.FAILED)
	assert_eq(res.reason, "core destroyed (on the same tick the kill target was reached)")
	assert_eq(res.deciding_id, Rules.CORE_ID)


func test_fail_wins_when_a_threshold_breaks_on_the_tick_the_timer_expires() -> void:
	var r := _rules([_survive("hold", 30.0), _core("keep", 0.5)])
	var res := r.evaluate(40.0, 30.0, _facts(30.0, 40.0))
	assert_eq(res.status, Rules.Status.FAILED)
	assert_eq(res.deciding_id, "keep")


func test_a_core_that_dies_with_a_broken_threshold_is_reported_as_destroyed() -> void:
	var r := _rules([_survive("hold", 30.0), _core("danger", 0.5, Role.FAIL)])
	var res := r.evaluate(0.0, 4.0, _facts(4.0, 0.0))
	assert_eq(res.reason, "core destroyed")
	assert_eq(res.deciding_id, Rules.CORE_ID)


func test_a_fail_threshold_and_the_core_dying_after_the_win_are_ignored() -> void:
	var r := _rules([_survive("hold", 30.0), _core("danger", 0.5, Role.FAIL)])
	assert_eq(r.evaluate(80.0, 30.0, _facts(30.0, 80.0)).status, Rules.Status.WON)
	assert_eq(r.evaluate(0.0, 31.0, _facts(31.0, 0.0)).status, Rules.Status.WON)
	assert_eq(r.result().status, Rules.Status.WON)


func test_the_mission_ends_exactly_once_with_objectives() -> void:
	var r := _rules([_survive("hold", 30.0), _kills("purge", 4)])
	var count := [0]
	r.ended.connect(func(_res: Rules.Result) -> void: count[0] += 1)
	r.evaluate(100.0, 10.0, _facts(10.0, 100.0, 2))
	assert_eq(count[0], 0)
	r.evaluate(100.0, 30.0, _facts(30.0, 100.0, 4))
	assert_eq(count[0], 1)
	r.evaluate(0.0, 31.0, _facts(31.0, 0.0, 9))
	r.evaluate(100.0, 40.0, _facts(40.0, 100.0, 20))
	assert_eq(count[0], 1)
	assert_eq(r.result().status, Rules.Status.WON)


func test_the_listener_sees_the_final_states() -> void:
	var r := _rules([_survive("hold", 30.0), _core("keep", 0.5, Role.SECONDARY), _kills("bonus", 99, Role.SECONDARY)])
	var seen: Array = []
	var t := r.tracker()  # not `r` itself: a lambda holding the object whose signal it is connected to would never be freed
	r.ended.connect(func(_res: Rules.Result) -> void:
		for i in t.size():
			seen.append(t.state(i)))
	r.evaluate(100.0, 30.0, _facts(30.0, 100.0, 2))
	assert_eq(seen, [State.MET, State.MET, State.FAILED])


func test_the_states_are_settled_on_a_loss() -> void:
	var r := _rules([_survive("hold", 30.0), _kills("bonus", 3, Role.SECONDARY), _kills("more", 30, Role.SECONDARY)])
	r.evaluate(0.0, 9.0, _facts(9.0, 0.0, 3))
	assert_eq(r.tracker().state(0), State.FAILED)
	assert_eq(r.tracker().state(1), State.MET)
	assert_eq(r.tracker().state(2), State.FAILED)


func test_a_threshold_still_holding_on_a_lost_mission_is_not_counted_as_held() -> void:
	var r := _rules([_survive("hold", 30.0), _core("danger", 0.5, Role.FAIL), _core("deep", 0.1, Role.SECONDARY)])
	assert_eq(r.evaluate(40.0, 5.0, _facts(5.0, 40.0)).status, Rules.Status.FAILED)
	assert_eq(r.tracker().state(2), State.FAILED, "lost mission: nothing left pending counts as met")


func test_evaluate_without_facts_still_judges_the_clock_and_the_core() -> void:
	var r := _rules([_survive("hold", 30.0)])
	assert_eq(r.evaluate(10.0, 29.0).status, Rules.Status.RUNNING)
	assert_eq(r.evaluate(10.0, 30.0).status, Rules.Status.WON)


func test_the_arguments_win_over_stale_values_in_the_facts() -> void:
	var r := _rules([_survive("hold", 30.0)])
	var stale := _facts(0.0, 100.0)
	assert_eq(r.evaluate(0.0, 30.0, stale).status, Rules.Status.FAILED)


# --- MissionDefinition and ContentDb validation ---------------------------------------------------

func _mission(items: Array) -> MissionDefinition:
	var m: MissionDefinition = _get_db().mission("m1_hold_the_crossing").duplicate()
	m.objectives = _list(items)
	return m


func test_a_mission_with_sound_objectives_validates() -> void:
	var m := _mission([_survive("hold", 60.0), _core("keep", 0.5, Role.SECONDARY), _kills("bonus", 10, Role.SECONDARY), _core("danger", 0.2, Role.FAIL)])
	assert_eq(m.validate().size(), 0, "\n".join(m.validate()))


func test_objective_errors_are_reported_on_the_mission() -> void:
	var m := _mission([_survive("hold", 0.0)])
	assert_true(_has(m.validate(), "seconds > 0"))


func test_a_null_objective_is_an_error() -> void:
	var m := _mission([_survive("hold", 60.0)])
	m.objectives.append(null)
	assert_true(_has(m.validate(), "objectives[1] is null"))


func test_two_objectives_may_not_share_an_id() -> void:
	var m := _mission([_survive("hold", 60.0), _kills("hold", 4, Role.SECONDARY)])
	assert_true(_has(m.validate(), "share the id 'hold'"))


func test_a_mission_with_objectives_needs_a_primary_that_can_be_completed() -> void:
	assert_true(_has(_mission([_kills("k", 3, Role.SECONDARY)]).validate(), "PRIMARY"))
	assert_true(_has(_mission([_core("c", 0.5)]).validate(), "PRIMARY"), "a threshold cannot be completed")
	assert_eq(_mission([_core("c", 0.5), _clear("w")]).validate().size(), 0)


func test_a_kill_target_above_everything_the_mission_sends_is_an_error() -> void:
	var m := _mission([_kills("k", 1)])
	var sent := m.total_enemies()
	m.objectives[0].count = sent
	assert_eq(m.validate().size(), 0, "exactly all of them is possible")
	m.objectives[0].count = sent + 1
	assert_true(_has(m.validate(), "needs %d kills but the mission sends only %d" % [sent + 1, sent]))


func test_a_secondary_kill_target_that_cannot_be_reached_is_not_an_error() -> void:
	var m := _mission([_survive("hold", 60.0)])
	m.objectives.append(_kills("k", m.total_enemies() + 100, Role.SECONDARY))
	assert_eq(m.validate().size(), 0, "a secondary never decides anything")


func test_content_db_checks_a_kill_target_against_every_difficulty() -> void:
	var db := ContentDb.load_from()
	var base: MissionDefinition = db.mission("m1_hold_the_crossing").duplicate()
	base.id = "kills_test"
	base.objectives = _list([_kills("k", base.total_enemies())])
	assert_true(db.add_mission(base))
	db.errors.clear()
	db.validate_references()
	assert_true(_has(db.errors, "difficulty 'easy' sends only"), "\n".join(db.errors))
	assert_true(not _has(db.errors, "difficulty 'normal' sends only"))
	assert_true(not _has(db.errors, "difficulty 'hard' sends only"))


func test_content_db_accepts_a_kill_target_every_difficulty_can_reach() -> void:
	var db := ContentDb.load_from()
	var easy := db.difficulty("easy")
	var base: MissionDefinition = db.mission("m1_hold_the_crossing").duplicate()
	base.id = "kills_ok"
	base.objectives = _list([_kills("k", base.total_enemies_at(easy))])
	assert_true(db.add_mission(base))
	db.errors.clear()
	db.validate_references()
	assert_true(not _has(db.errors, "kills_ok"), "\n".join(db.errors))


func test_content_db_does_not_check_a_secondary_kill_target() -> void:
	var db := ContentDb.load_from()
	var base: MissionDefinition = db.mission("m1_hold_the_crossing").duplicate()
	base.id = "kills_side"
	base.objectives = _list([_survive("hold", 60.0), _kills("side", base.total_enemies(), Role.SECONDARY)])
	assert_true(db.add_mission(base))
	db.errors.clear()
	db.validate_references()
	assert_true(not _has(db.errors, "kills_side"), "
".join(db.errors))


# --- the battle -----------------------------------------------------------------------------------

func _battle_mission(items: Array, count: int = 5, core_health: float = 100.0) -> MissionDefinition:
	var m: MissionDefinition = _get_db().mission("m1_hold_the_crossing").duplicate()
	m.id = "objective_test"
	m.start_units = [] as Array[StartUnit]
	m.core_health = core_health
	m.duration_s = 300.0
	var w := WaveEntry.new()
	w.start_s = 0.0
	w.enemy_id = "shambler"
	w.count = count
	w.interval_s = 1.0
	m.waves = [w] as Array[WaveEntry]
	m.objectives = _list(items)
	return m


func _battle(m: MissionDefinition, level: String = "") -> BattleController:
	var b := BattleController.new()
	b.auto_step = false
	b.difficulty_id = level
	b.setup(_get_db(), m, 1)
	_made.append(b)
	return b


func _run(b: BattleController, seconds: float) -> void:
	for i in roundi(seconds / DT):
		b.step(DT)


## Destroys every enemy that is alive (the next step removes them and counts the kills).
func _wipe(b: BattleController) -> void:
	for e in b.enemies:
		e.health.take_damage(1.0e9)


func _release() -> void:
	for b in _made:
		b.free()
	_made.clear()


func test_a_battle_without_objectives_has_the_implicit_one() -> void:
	var b := _battle(_battle_mission([]))
	assert_eq(b.objectives().size(), 1)
	assert_eq(b.objectives().definition(0).id, Rules.IMPLICIT_ID)
	_release()


func test_the_objective_state_is_unavailable_before_setup() -> void:
	var b := BattleController.new()
	assert_eq(b.objectives(), null)
	b.free()


func test_a_kill_count_primary_wins_the_battle_when_enough_enemies_die() -> void:
	var b := _battle(_battle_mission([_kills("purge", 3)], 5))
	_run(b, 3.5)  # four spawned
	assert_eq(b.is_ended(), false)
	var dead := 0
	for e in b.enemies:
		if dead < 2:
			e.health.take_damage(1.0e9)
			dead += 1
	b.step(DT)
	assert_eq(b.is_ended(), false, "two kills of three")
	b.enemies[0].health.take_damage(1.0e9)
	b.step(DT)
	assert_eq(b.result().status, Rules.Status.WON)
	assert_eq(b.result().reason, "3 enemies destroyed")
	assert_eq(b.result().deciding_id, "purge")
	assert_eq(b.stats["kills"], 3)
	_release()


func test_clear_waves_as_primary_ends_the_battle_when_the_last_enemy_falls() -> void:
	var b := _battle(_battle_mission([_clear("assault")], 5))
	_run(b, 3.5)
	_wipe(b)
	b.step(DT)
	assert_eq(b.is_ended(), false, "more are still to come")
	_run(b, 2.0)  # the last one spawns at 4 s
	assert_eq(b.stats["spawned"], 5)
	assert_eq(b.is_ended(), false, "all spawned but they are still alive")
	_wipe(b)
	b.step(DT)
	assert_eq(b.result().status, Rules.Status.WON)
	assert_eq(b.result().reason, "every wave destroyed")
	assert_true(b.elapsed < 10.0, "long before the 300 s")
	_release()


func test_clear_waves_counts_the_difficulty_scaled_enemies() -> void:
	var b := _battle(_battle_mission([_clear("assault")], 10), "easy")
	b.step(DT)
	assert_eq(int(b.objectives().target(0)), 6, "easy sends 0.6 x 10")
	_run(b, 10.0)  # the 6 are spread over the same 9 s the 10 had
	assert_eq(b.stats["spawned"], 6)
	_wipe(b)
	b.step(DT)
	assert_eq(b.result().status, Rules.Status.WON)
	_release()


func test_a_core_threshold_fail_ends_the_battle_when_the_core_is_hurt_enough() -> void:
	var b := _battle(_battle_mission([_survive("hold", 200.0), _core("danger", 0.5, Role.FAIL)]))
	_run(b, 2.0)
	assert_eq(b.is_ended(), false)
	b.core.health.take_damage(40.0)
	b.step(DT)
	assert_eq(b.is_ended(), false, "60 % left")
	b.core.health.take_damage(20.0)
	b.step(DT)
	assert_eq(b.result().status, Rules.Status.FAILED)
	assert_eq(b.result().reason, "core fell below 50 %")
	assert_true(b.core.is_alive(), "the core still stands: the mission was lost on the threshold")
	_release()


func test_the_mission_timer_alone_does_not_win_a_mission_that_asks_for_kills() -> void:
	var m := _battle_mission([_kills("purge", 5)], 5, 100000.0)
	m.duration_s = 6.0
	var b := _battle(m)
	_run(b, 8.0)
	assert_eq(b.is_ended(), false, "the clock is not an objective here")
	_release()


func test_restarting_resets_the_objectives() -> void:
	var m := _battle_mission([_kills("purge", 5), _core("keep", 0.9, Role.SECONDARY)])
	var b := _battle(m)
	_run(b, 2.5)
	b.core.health.take_damage(50.0)
	_wipe(b)
	b.step(DT)
	assert_eq(b.objectives().state(1), State.FAILED)
	assert_near(b.objectives().value(0), 3.0)
	assert_eq(b.is_ended(), false)
	b.setup(_get_db(), m, 1)
	assert_eq(b.objectives().state(0), State.PENDING)
	assert_eq(b.objectives().state(1), State.PENDING)
	assert_near(b.objectives().value(0), 0.0)
	assert_eq(b.is_ended(), false)
	_run(b, 1.5)
	b.step(DT)
	assert_eq(b.objectives().state(0), State.PENDING, "no kills carried over")
	_release()


func test_restarting_does_not_add_up_the_planned_enemies() -> void:
	var m := _battle_mission([_clear("assault")], 5)
	var b := _battle(m)
	b.step(DT)
	assert_eq(int(b.objectives().target(0)), 5)
	b.setup(_get_db(), m, 1)
	b.step(DT)
	assert_eq(int(b.objectives().target(0)), 5)
	_release()


func test_an_ended_battle_stops_updating_the_objectives() -> void:
	var b := _battle(_battle_mission([_kills("purge", 1), _kills("later", 3, Role.SECONDARY)]))
	_run(b, 1.5)  # two spawned
	_wipe(b)
	b.step(DT)
	assert_eq(b.is_ended(), true)
	assert_eq(b.objectives().state(1), State.FAILED, "the bonus was not reached")
	var states_then := [b.objectives().state(0), b.objectives().state(1)]
	_wipe(b)
	b.step(DT)
	assert_eq([b.objectives().state(0), b.objectives().state(1)], states_then)
	_release()
