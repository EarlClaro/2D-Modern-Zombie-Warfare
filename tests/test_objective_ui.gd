extends TestCase
## The objective list, the result breakdown and the spawn cues (M3.13): the pure word / timing / edge maths, and the nodes that
## draw them. Looks are a manual check; these cover what is shown and when.

const Kind := ObjectiveDefinition.Kind
const Role := ObjectiveDefinition.Role
const State := ObjectiveTracker.State
const DT: float = 1.0 / 60.0

var _db: ContentDb
var _made: Array[BattleController] = []
var _nodes: Array[Node] = []


func _get_db() -> ContentDb:
	if _db == null:
		_db = ContentDb.load_from()
	return _db


func _obj(id: String, kind: Kind, role: Role, seconds: float = 0.0, fraction: float = 0.0, count: int = 0) -> ObjectiveDefinition:
	var o := ObjectiveDefinition.new()
	o.id = id
	o.kind = kind
	o.role = role
	o.seconds = seconds
	o.fraction = fraction
	o.count = count
	return o


func _list(items: Array) -> Array[ObjectiveDefinition]:
	var out: Array[ObjectiveDefinition] = []
	for o in items:
		out.append(o)
	return out


func _facts(elapsed: float = 0.0, hp: float = 100.0, kills: int = 0, alive: int = 0, spawned: int = 0, planned: int = 0) -> ObjectiveTracker.Facts:
	var f := ObjectiveTracker.Facts.new()
	f.elapsed_s = elapsed
	f.core_hp = hp
	f.core_max = 100.0
	f.kills = kills
	f.alive = alive
	f.spawned = spawned
	f.planned = planned
	return f


func _tracker(items: Array) -> ObjectiveTracker:
	return ObjectiveTracker.new(_list(items))


func _in_tree(node: Node) -> void:
	tree.root.add_child(node)
	_nodes.append(node)


func _release() -> void:
	for n in _nodes:
		n.free()
	_nodes.clear()
	for b in _made:
		b.free()
	_made.clear()


# --- ObjectiveText ----------------------------------------------------------------------------------

func test_clock_rounds_up_and_never_goes_negative() -> void:
	assert_eq(ObjectiveText.clock(0.0), "0:00")
	assert_eq(ObjectiveText.clock(83.0), "1:23")
	assert_eq(ObjectiveText.clock(83.2), "1:24", "a clock that says 1:23 still has a moment left")
	assert_eq(ObjectiveText.clock(-4.0), "0:00")
	assert_eq(ObjectiveText.clock(3600.0), "60:00")
	assert_eq(ObjectiveText.clock(9.0), "0:09")


func test_the_group_titles() -> void:
	assert_eq(ObjectiveText.role_title(Role.PRIMARY), "OBJECTIVES")
	assert_eq(ObjectiveText.role_title(Role.SECONDARY), "BONUS")
	assert_eq(ObjectiveText.role_title(Role.FAIL), "LOSE IF")


func test_the_marks_tell_pending_holding_met_and_failed_apart() -> void:
	assert_eq(ObjectiveText.mark(State.PENDING, false), "[ ]")
	assert_eq(ObjectiveText.mark(State.PENDING, true), "[=]")
	assert_eq(ObjectiveText.mark(State.MET, false), "[x]")
	assert_eq(ObjectiveText.mark(State.MET, true), "[x]")
	assert_eq(ObjectiveText.mark(State.FAILED, false), "[!]")
	assert_eq(ObjectiveText.mark(State.FAILED, true), "[!]")


func test_rows_put_primary_first_then_bonus_then_lose_if() -> void:
	var t := _tracker([
		_obj("danger", Kind.CORE_HEALTH_AT_LEAST, Role.FAIL, 0.0, 0.2),
		_obj("bonus", Kind.KILL_COUNT, Role.SECONDARY, 0.0, 0.0, 10),
		_obj("hold", Kind.SURVIVE, Role.PRIMARY, 60.0),
		_obj("clear", Kind.CLEAR_WAVES, Role.PRIMARY),
	])
	var ids: Array = []
	for r in ObjectiveText.rows(t):
		ids.append(r.id)
	assert_eq(ids, ["hold", "clear", "bonus", "danger"], "declared order kept inside a group")


func test_a_survive_row_counts_down_and_then_shows_the_time_held() -> void:
	var t := _tracker([_obj("hold", Kind.SURVIVE, Role.PRIMARY, 90.0)])
	t.update(_facts(0.0))
	assert_eq(ObjectiveText.rows(t)[0].text, "Hold 1:30 left")
	t.update(_facts(7.0))
	assert_eq(ObjectiveText.rows(t)[0].text, "Hold 1:23 left")
	t.update(_facts(90.0))
	assert_eq(ObjectiveText.rows(t)[0].text, "Hold 1:30")
	assert_eq(ObjectiveText.rows(t)[0].mark, "[x]")


func test_a_core_row_shows_the_threshold_and_the_current_share() -> void:
	var t := _tracker([_obj("keep", Kind.CORE_HEALTH_AT_LEAST, Role.SECONDARY, 0.0, 0.5)])
	t.update(_facts(1.0, 78.0))
	var r := ObjectiveText.rows(t)[0]
	assert_eq(r.text, "Core >= 50%: 78%")
	assert_eq(r.mark, "[=]")
	t.update(_facts(2.0, 49.0))
	r = ObjectiveText.rows(t)[0]
	assert_eq(r.text, "Core >= 50%: 49%")
	assert_eq(r.mark, "[!]")
	assert_eq(r.state, State.FAILED)


func test_a_core_share_is_not_rounded_up_past_the_line() -> void:
	var t := _tracker([_obj("keep", Kind.CORE_HEALTH_AT_LEAST, Role.PRIMARY, 0.0, 0.5)])
	t.update(_facts(1.0, 49.6))
	assert_eq(ObjectiveText.rows(t)[0].text, "Core >= 50%: 49%", "49.6 % is below the line and says so")


func test_a_whole_percent_is_not_lost_to_float_error() -> void:
	var t := _tracker([_obj("keep", Kind.CORE_HEALTH_AT_LEAST, Role.PRIMARY, 0.0, 0.1)])
	t.update(_facts(1.0, 29.0))
	assert_eq(ObjectiveText.rows(t)[0].text, "Core >= 10%: 29%")


func test_a_fail_threshold_reads_as_a_way_to_lose() -> void:
	var t := _tracker([_obj("danger", Kind.CORE_HEALTH_AT_LEAST, Role.FAIL, 0.0, 0.25)])
	t.update(_facts(1.0, 40.0))
	assert_eq(ObjectiveText.rows(t)[0].text, "Core below 25%: now 40%")


func test_a_kill_row_counts_up() -> void:
	var t := _tracker([_obj("k", Kind.KILL_COUNT, Role.PRIMARY, 0.0, 0.0, 300)])
	t.update(_facts(1.0, 100.0, 120))
	assert_eq(ObjectiveText.rows(t)[0].text, "Kills 120 / 300")


func test_a_clear_waves_row_shows_the_total_once_it_is_known() -> void:
	var t := _tracker([_obj("w", Kind.CLEAR_WAVES, Role.PRIMARY)])
	assert_eq(ObjectiveText.rows(t)[0].text, "Destroy every wave")
	t.update(_facts(1.0, 100.0, 4, 2, 6, 12))
	assert_eq(ObjectiveText.rows(t)[0].text, "Destroy every wave: 4 / 12")


func test_the_deciding_row_is_marked_only_when_an_id_is_given() -> void:
	var t := _tracker([_obj("a", Kind.SURVIVE, Role.PRIMARY, 10.0), _obj("b", Kind.KILL_COUNT, Role.PRIMARY, 0.0, 0.0, 3)])
	var none := ObjectiveText.rows(t)
	assert_true(not none[0].deciding and not none[1].deciding)
	var some := ObjectiveText.rows(t, "b")
	assert_true(not some[0].deciding)
	assert_true(some[1].deciding)
	assert_true(not ObjectiveText.rows(t, "nope")[0].deciding)


# --- SpawnCue -------------------------------------------------------------------------------------

func _wave(spawn: int, start: float, count: int, gap: float) -> WaveEntry:
	var w := WaveEntry.new()
	w.spawn_index = spawn
	w.start_s = start
	w.count = count
	w.interval_s = gap
	w.enemy_id = "shambler"
	return w


func _cue_mission(waves: Array) -> MissionDefinition:
	var m := MissionDefinition.new()
	m.spawn_cells = [Vector2i(1, 1), Vector2i(5, 5)] as Array[Vector2i]
	var ws: Array[WaveEntry] = []
	for w in waves:
		ws.append(w)
	m.waves = ws
	return m


func test_a_marker_appears_the_lead_time_before_a_wave() -> void:
	var m := _cue_mission([_wave(0, 10.0, 5, 1.0)])
	assert_eq(SpawnCue.cue(m, 0, 3.9).state, SpawnCue.State.NONE)
	var c := SpawnCue.cue(m, 0, 4.0)
	assert_eq(c.state, SpawnCue.State.SOON, "exactly 6 s ahead")
	assert_near(c.in_s, 6.0)
	assert_near(SpawnCue.cue(m, 0, 8.5).in_s, 1.5)


func test_a_marker_stays_while_the_wave_comes_out_and_a_moment_after() -> void:
	var m := _cue_mission([_wave(0, 10.0, 5, 1.0)])  # last enemy at 14 s
	assert_eq(SpawnCue.cue(m, 0, 10.0).state, SpawnCue.State.ACTIVE)
	assert_eq(SpawnCue.cue(m, 0, 13.0).state, SpawnCue.State.ACTIVE)
	assert_eq(SpawnCue.cue(m, 0, 16.0).state, SpawnCue.State.ACTIVE, "2 s after the last enemy")
	assert_eq(SpawnCue.cue(m, 0, 16.01).state, SpawnCue.State.NONE)
	assert_near(SpawnCue.cue(m, 0, 12.0).in_s, 0.0)


func test_a_wave_that_starts_at_zero_is_active_from_the_first_tick() -> void:
	var m := _cue_mission([_wave(0, 0.0, 3, 1.0)])
	assert_eq(SpawnCue.cue(m, 0, 0.0).state, SpawnCue.State.ACTIVE)


func test_a_single_enemy_wave_still_gets_a_visible_window() -> void:
	var m := _cue_mission([_wave(1, 30.0, 1, 1.0)])
	assert_eq(SpawnCue.cue(m, 1, 31.5).state, SpawnCue.State.ACTIVE)
	assert_eq(SpawnCue.cue(m, 1, 32.5).state, SpawnCue.State.NONE)


func test_each_spawn_point_has_its_own_cue() -> void:
	var m := _cue_mission([_wave(0, 10.0, 5, 1.0), _wave(1, 40.0, 5, 1.0)])
	assert_eq(SpawnCue.cue(m, 0, 11.0).state, SpawnCue.State.ACTIVE)
	assert_eq(SpawnCue.cue(m, 1, 11.0).state, SpawnCue.State.NONE)
	assert_eq(SpawnCue.cue(m, 1, 36.0).state, SpawnCue.State.SOON)
	assert_eq(SpawnCue.cue(m, 0, 36.0).state, SpawnCue.State.NONE)


func test_a_running_wave_beats_the_next_one_coming() -> void:
	var m := _cue_mission([_wave(0, 10.0, 10, 1.0), _wave(0, 17.0, 3, 1.0)])
	assert_eq(SpawnCue.cue(m, 0, 15.0).state, SpawnCue.State.ACTIVE, "wave one runs to 19 s; wave two is only 2 s away")
	var gap := _cue_mission([_wave(0, 10.0, 3, 1.0), _wave(0, 20.0, 3, 1.0)])
	assert_eq(SpawnCue.cue(gap, 0, 15.0).state, SpawnCue.State.SOON, "between the waves (the first ended at 12 s, +2): 5 s to the next")
	assert_near(SpawnCue.cue(gap, 0, 14.5).in_s, 5.5)
	assert_eq(SpawnCue.cue(gap, 0, 13.9).state, SpawnCue.State.ACTIVE, "the first wave's window runs to 14 s")


func test_the_soonest_of_several_coming_waves_gives_the_countdown() -> void:
	var m := _cue_mission([_wave(0, 50.0, 2, 1.0), _wave(0, 46.0, 2, 1.0)])
	assert_near(SpawnCue.cue(m, 0, 42.0).in_s, 4.0)


func test_the_lead_time_can_be_changed() -> void:
	var m := _cue_mission([_wave(0, 10.0, 5, 1.0)])
	assert_eq(SpawnCue.cue(m, 0, 2.0, 10.0).state, SpawnCue.State.SOON)
	assert_eq(SpawnCue.cue(m, 0, 2.0, 5.0).state, SpawnCue.State.NONE)


func test_a_spawn_point_without_waves_never_shows_a_marker() -> void:
	var m := _cue_mission([_wave(0, 10.0, 5, 1.0)])
	assert_eq(SpawnCue.cue(m, 1, 10.0).state, SpawnCue.State.NONE)


# --- EdgeArrow ------------------------------------------------------------------------------------

const VIEW := Rect2(0.0, 0.0, 1920.0, 1080.0)


func test_a_point_on_screen_needs_no_arrow() -> void:
	var p := EdgeArrow.place(Vector2(900.0, 500.0), VIEW, 50.0)
	assert_true(p.on_screen)
	assert_eq(p.pos, Vector2(900.0, 500.0))


func test_a_point_inside_the_margin_band_counts_as_off_screen() -> void:
	var p := EdgeArrow.place(Vector2(20.0, 500.0), VIEW, 50.0)
	assert_true(not p.on_screen)
	assert_near(p.pos.x, 50.0, 1e-4, "pulled in to the margin")


func test_an_arrow_to_the_left_sits_on_the_left_edge_pointing_left() -> void:
	var p := EdgeArrow.place(Vector2(-500.0, 540.0), VIEW, 50.0)
	assert_true(not p.on_screen)
	assert_vec_near(p.pos, Vector2(50.0, 540.0))
	assert_near(absf(p.angle), PI, 1e-4)


func test_an_arrow_above_sits_on_the_top_edge_pointing_up() -> void:
	var p := EdgeArrow.place(Vector2(960.0, -3000.0), VIEW, 50.0)
	assert_vec_near(p.pos, Vector2(960.0, 50.0))
	assert_near(p.angle, -PI * 0.5, 1e-4)


func test_a_diagonal_target_gives_the_edge_the_line_crosses_first() -> void:
	var p := EdgeArrow.place(Vector2(3000.0, -1000.0), VIEW, 50.0)
	assert_near(p.pos.y, 50.0, 1e-3, "hits the top before the right edge")
	assert_true(p.pos.x > 960.0 and p.pos.x < 1870.0)
	var back := (Vector2(3000.0, -1000.0) - Vector2(960.0, 540.0)).normalized()
	assert_vec_near((p.pos - Vector2(960.0, 540.0)).normalized(), back, 1e-4)
	assert_near(p.angle, back.angle(), 1e-4)


func test_every_arrow_lands_on_the_margin_rectangle_and_points_at_its_target() -> void:
	var inner := VIEW.grow(-50.0)
	for k in 36:
		var a := TAU * k / 36.0 + 0.01
		var target := Vector2(960.0, 540.0) + Vector2.from_angle(a) * 4000.0
		var p := EdgeArrow.place(target, VIEW, 50.0)
		assert_true(not p.on_screen)
		var on_x := absf(p.pos.x - inner.position.x) < 1e-2 or absf(p.pos.x - inner.end.x) < 1e-2
		var on_y := absf(p.pos.y - inner.position.y) < 1e-2 or absf(p.pos.y - inner.end.y) < 1e-2
		assert_true(on_x or on_y, "on the border at angle %d" % k)
		assert_true(p.pos.x >= inner.position.x - 1e-2 and p.pos.x <= inner.end.x + 1e-2 and p.pos.y >= inner.position.y - 1e-2 and p.pos.y <= inner.end.y + 1e-2)
		assert_near(p.angle, wrapf(a, -PI, PI), 1e-3)


func test_a_margin_larger_than_the_view_does_not_break() -> void:
	var p := EdgeArrow.place(Vector2(900.0, 40.0), Rect2(0.0, 0.0, 100.0, 100.0), 80.0)
	assert_true(not p.on_screen)
	assert_true(Rect2(0.0, 0.0, 100.0, 100.0).has_point(p.pos), "still a point on the screen")


# --- the nodes ------------------------------------------------------------------------------------

func _battle(m: MissionDefinition) -> BattleController:
	var b := BattleController.new()
	b.auto_step = false
	b.setup(_get_db(), m, 1)
	_made.append(b)
	return b


func _objective_mission(items: Array) -> MissionDefinition:
	var m: MissionDefinition = _get_db().mission("m1_hold_the_crossing").duplicate()
	m.id = "objective_ui_test"
	m.start_units = [] as Array[StartUnit]
	m.core_health = 100.0
	m.duration_s = 300.0
	var w := WaveEntry.new()
	w.start_s = 0.0
	w.enemy_id = "shambler"
	w.count = 5
	w.interval_s = 1.0
	m.waves = [w] as Array[WaveEntry]
	m.objectives = _list(items)
	return m


func _run(b: BattleController, seconds: float) -> void:
	for i in roundi(seconds / DT):
		b.step(DT)


func test_the_battle_scene_builds_the_list_and_the_cue_overlay() -> void:
	GameSession.pending_mission = "dev_objectives"
	var b := BattleController.new()
	b.auto_step = false
	tree.root.add_child(b)
	_made.append(b)
	assert_true(b.get_node_or_null("ObjectiveList") is ObjectiveList)
	assert_true(b.get_node_or_null("SpawnCues") is SpawnCueOverlay)
	assert_true(b.get_node_or_null("ObjectiveList").get_node_or_null("../ObjectiveList") != null)
	b.get_node("ObjectiveList")._process(0.0)
	assert_true(b.get_node("ObjectiveList").visible, "the mission declares objectives")
	_release()


func test_the_dev_mission_declares_all_four_kinds_and_validates() -> void:
	var m := _get_db().mission("dev_objectives")
	assert_true(m != null)
	assert_eq(m.validate().size(), 0, "\n".join(m.validate()))
	var kinds: Array = []
	for o in m.objectives:
		kinds.append(o.kind)
	for k in [Kind.SURVIVE, Kind.CORE_HEALTH_AT_LEAST, Kind.KILL_COUNT, Kind.CLEAR_WAVES]:
		assert_true(k in kinds, "kind %d" % k)


func test_the_list_shows_every_objective_grouped_with_live_numbers() -> void:
	var b := _battle(_objective_mission([
		_obj("hold", Kind.SURVIVE, Role.PRIMARY, 100.0),
		_obj("kills", Kind.KILL_COUNT, Role.SECONDARY, 0.0, 0.0, 20),
		_obj("keep", Kind.CORE_HEALTH_AT_LEAST, Role.SECONDARY, 0.0, 0.6),
		_obj("danger", Kind.CORE_HEALTH_AT_LEAST, Role.FAIL, 0.0, 0.15),
	]))
	var list := ObjectiveList.new()
	list.bind(b)
	_in_tree(list)
	b.step(DT)
	list._process(0.0)
	assert_true(list.visible)
	assert_eq(list.texts(), PackedStringArray([
		"OBJECTIVES", "[ ] Hold 1:40 left",
		"BONUS", "[ ] Kills 0 / 20", "[=] Core >= 60%: 100%",
		"LOSE IF", "[=] Core below 15%: now 100%"]))
	b.core.health.take_damage(50.0)
	b.step(DT)
	list._process(0.0)
	assert_eq(list.texts()[4], "[!] Core >= 60%: 50%")
	assert_eq(list.texts()[6], "[=] Core below 15%: now 50%")
	_release()


func test_the_list_follows_the_battle_to_a_win() -> void:
	var b := _battle(_objective_mission([_obj("purge", Kind.KILL_COUNT, Role.PRIMARY, 0.0, 0.0, 2)]))
	var list := ObjectiveList.new()
	list.bind(b)
	_in_tree(list)
	_run(b, 1.5)
	for e in b.enemies:
		e.health.take_damage(1.0e9)
	b.step(DT)
	list._process(0.0)
	assert_eq(list.texts(), PackedStringArray(["OBJECTIVES", "[x] Kills 2 / 2"]))
	assert_true(not list.visible, "the result panel takes over once the battle is over")
	_release()


func test_the_list_is_hidden_for_a_mission_without_objectives() -> void:
	var b := _battle(_objective_mission([]))
	var list := ObjectiveList.new()
	list.bind(b)
	_in_tree(list)
	b.step(DT)
	list._process(0.0)
	assert_true(not list.visible)
	_release()


func test_the_list_colours_follow_the_state() -> void:
	var t := _tracker([_obj("a", Kind.SURVIVE, Role.PRIMARY, 10.0), _obj("b", Kind.CORE_HEALTH_AT_LEAST, Role.SECONDARY, 0.0, 0.5), _obj("c", Kind.KILL_COUNT, Role.SECONDARY, 0.0, 0.0, 1)])
	t.update(_facts(10.0, 30.0, 0))
	var rows := ObjectiveText.rows(t)  # a met, c pending, b failed
	assert_eq(ObjectiveList.color_of(rows[0]), ObjectiveList.COLOR_MET)
	assert_eq(ObjectiveList.color_of(rows[1]), ObjectiveList.COLOR_FAILED)
	assert_eq(ObjectiveList.color_of(rows[2]), ObjectiveList.COLOR_PENDING)
	var h := _tracker([_obj("b", Kind.CORE_HEALTH_AT_LEAST, Role.SECONDARY, 0.0, 0.5)])
	h.update(_facts(1.0, 90.0))
	assert_eq(ObjectiveList.color_of(ObjectiveText.rows(h)[0]), ObjectiveList.COLOR_HOLDING)


func test_the_hud_clock_gives_way_to_the_list_only_when_objectives_are_declared() -> void:
	var plain := _battle(_objective_mission([]))
	var hud := BattleHud.new()
	hud.bind(plain)
	_in_tree(hud)
	hud._process(0.0)
	assert_true(hud._time_label.visible)
	var rich := _battle(_objective_mission([_obj("hold", Kind.SURVIVE, Role.PRIMARY, 60.0)]))
	var hud2 := BattleHud.new()
	hud2.bind(rich)
	_in_tree(hud2)
	hud2._process(0.0)
	assert_true(not hud2._time_label.visible)
	_release()


func test_the_result_panel_lists_every_objective_and_the_one_that_decided() -> void:
	var b := _battle(_objective_mission([
		_obj("purge", Kind.KILL_COUNT, Role.PRIMARY, 0.0, 0.0, 2),
		_obj("keep", Kind.CORE_HEALTH_AT_LEAST, Role.SECONDARY, 0.0, 0.5),
		_obj("extra", Kind.KILL_COUNT, Role.SECONDARY, 0.0, 0.0, 99),
	]))
	var panel := ResultPanel.new()
	panel.bind(b)
	_in_tree(panel)
	_run(b, 1.5)
	for e in b.enemies:
		e.health.take_damage(1.0e9)
	b.step(DT)
	assert_true(b.is_ended())
	assert_eq(panel.objective_texts(), PackedStringArray([
		"OBJECTIVES", "[x] Kills 2 / 2   <- decided it",
		"BONUS", "[x] Core >= 50%: 100%", "[!] Kills 2 / 99"]))
	_release()


func test_a_lost_mission_names_the_objective_that_failed() -> void:
	var b := _battle(_objective_mission([
		_obj("hold", Kind.SURVIVE, Role.PRIMARY, 200.0),
		_obj("danger", Kind.CORE_HEALTH_AT_LEAST, Role.FAIL, 0.0, 0.5),
	]))
	var panel := ResultPanel.new()
	panel.bind(b)
	_in_tree(panel)
	b.step(DT)
	b.core.health.take_damage(60.0)
	b.step(DT)
	assert_eq(panel.objective_texts(), PackedStringArray([
		"OBJECTIVES", "[!] Hold 3:20 left",
		"LOSE IF", "[!] Core below 50%: now 40%   <- decided it"]))
	_release()


func test_the_result_panel_shows_no_breakdown_for_a_mission_without_objectives() -> void:
	var b := _battle(_objective_mission([]))
	var panel := ResultPanel.new()
	panel.bind(b)
	_in_tree(panel)
	b.step(DT)
	b.core.health.take_damage(500.0)
	b.step(DT)
	assert_true(b.is_ended())
	assert_eq(panel.objective_texts().size(), 0)
	_release()


func test_a_restart_clears_the_breakdown() -> void:
	var m := _objective_mission([_obj("hold", Kind.SURVIVE, Role.PRIMARY, 200.0), _obj("danger", Kind.CORE_HEALTH_AT_LEAST, Role.FAIL, 0.0, 0.5)])
	var b := _battle(m)
	var panel := ResultPanel.new()
	panel.bind(b)
	_in_tree(panel)
	b.step(DT)
	b.core.health.take_damage(60.0)
	b.step(DT)
	assert_true(panel.objective_texts().size() > 0)
	b.setup(_get_db(), m, 1)
	assert_eq(panel.objective_texts().size(), 0)
	_release()


func test_the_overlay_reports_the_spawns_with_a_cue_on_the_battle_clock() -> void:
	var m := _get_db().mission("dev_objectives")  # both spawns send their first wave at 5 s
	var b := _battle(m)
	var overlay := SpawnCueOverlay.new()
	overlay.bind(b)
	_in_tree(overlay)
	var at_start := overlay.active_cues()
	assert_eq(at_start.size(), 2, "5 s away is inside the 6 s lead")
	assert_eq(at_start[0][1].state, SpawnCue.State.SOON)
	_run(b, 1.5)
	assert_eq(overlay.active_cues().size(), 2)
	_run(b, 4.0)
	assert_eq((overlay.active_cues()[0][1] as SpawnCue.Cue).state, SpawnCue.State.ACTIVE)
	_release()


func test_the_overlay_names_which_spawn_has_the_cue() -> void:
	var m := _get_db().mission("dev_objectives").duplicate()
	m.waves = [_wave(1, 3.0, 4, 1.0)] as Array[WaveEntry]  # only the second spawn point sends anything, 3 s in
	var b := _battle(m)
	var overlay := SpawnCueOverlay.new()
	overlay.bind(b)
	_in_tree(overlay)
	var cues := overlay.active_cues()
	assert_eq(cues.size(), 1)
	assert_eq(cues[0][0], 1, "the second spawn point")
	_release()


func test_the_overlay_shows_nothing_before_the_lead_and_after_the_battle() -> void:
	var m := _objective_mission([])
	m.waves[0].start_s = 30.0
	var b := _battle(m)
	var overlay := SpawnCueOverlay.new()
	overlay.bind(b)
	_in_tree(overlay)
	assert_eq(overlay.active_cues().size(), 0, "30 s away")
	b.core.health.take_damage(500.0)
	b.step(DT)
	assert_true(b.is_ended())
	b.elapsed = 29.0
	assert_eq(overlay.active_cues().size(), 0, "never once the battle is over")
	_release()

