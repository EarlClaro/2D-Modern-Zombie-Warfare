extends TestCase
## Selectable difficulty (M3.9, ADR-013): it changes only how many enemies every wave sends; normal changes nothing.

const MISSION := "m1_hold_the_crossing"

var _db: ContentDb
var _made: Array[BattleController] = []


func _get_db() -> ContentDb:
	if _db == null:
		_db = ContentDb.load_from()
	return _db


func _diff(mult: float, id: String = "d") -> DifficultyDefinition:
	var d := DifficultyDefinition.new()
	d.id = id
	d.display_name = "D"
	d.enemy_count_mult = mult
	return d


func _has(errs: PackedStringArray, needle: String) -> bool:
	for e in errs:
		if needle in e:
			return true
	return false


func _battle(level: String = "", mission_id: String = MISSION, mission: MissionDefinition = null) -> BattleController:
	var b := BattleController.new()
	b.auto_step = false
	b.difficulty_id = level
	b.setup(_get_db(), mission if mission != null else _get_db().mission(mission_id), 1)
	_made.append(b)
	return b


func _release() -> void:
	for b in _made:
		b.free()
	_made.clear()


func _in_tree(node: Node) -> void:
	tree.root.add_child(node)


# --- counts ------------------------------------------------------------------------------------------------------

func test_a_difficulty_validates_its_fields() -> void:
	assert_eq(_diff(1.0).validate().size(), 0)
	assert_true(_has(_diff(0.0).validate(), "enemy_count_mult"))
	assert_true(_has(_diff(-1.0).validate(), "enemy_count_mult"))
	assert_true(_has(_diff(99.0).validate(), "enemy_count_mult"))
	var nameless := _diff(1.0)
	nameless.display_name = ""
	assert_true(_has(nameless.validate(), "display_name"))


func test_easy_sends_fewer_and_hard_sends_more_rounded_and_never_below_one() -> void:
	var easy := _diff(0.6)
	assert_eq([easy.scaled_count(1), easy.scaled_count(2), easy.scaled_count(3), easy.scaled_count(5), easy.scaled_count(10), easy.scaled_count(30)], [1, 1, 2, 3, 6, 18])
	var hard := _diff(1.5)
	assert_eq([hard.scaled_count(1), hard.scaled_count(2), hard.scaled_count(3), hard.scaled_count(10), hard.scaled_count(220)], [2, 3, 5, 15, 330])
	assert_eq(_diff(0.1).scaled_count(1), 1, "an entry that sends enemies still sends one")
	assert_eq(_diff(0.1).scaled_count(4), 1)
	assert_eq(easy.scaled_count(0), 0, "nothing stays nothing")
	assert_eq(easy.scaled_count(-3), -3)


func test_normal_changes_no_count_and_no_interval() -> void:
	var normal := _diff(1.0)
	for n in range(0, 601):
		assert_eq(normal.scaled_count(n), n)
	for iv in [0.0, 0.05, 0.07, 0.2, 1.0, 2.5]:
		assert_eq(normal.scaled_interval(30, iv), iv, "exactly the same float")


func test_a_scaled_wave_keeps_its_first_and_last_enemy_times() -> void:
	for mult in [0.6, 1.5, 2.0, 0.25]:
		var d := _diff(mult)
		var count := 11
		var n := d.scaled_count(count)
		var gap := d.scaled_interval(count, 1.0)
		if n > 1:
			assert_near(float(n - 1) * gap, float(count - 1) * 1.0, 1e-9, "x%s: same span" % str(mult))
	assert_eq(_diff(1.5).scaled_interval(1, 2.0), 2.0, "one enemy has no span to keep")
	assert_eq(_diff(0.6).scaled_interval(30, 0.0), 0.0, "an instant wave stays instant")
	assert_eq(_diff(0.1).scaled_interval(4, 1.0), 1.0, "a wave cut to one enemy has no gap to change")


# --- content -----------------------------------------------------------------------------------------------------

func test_the_three_shipped_levels_exist_in_menu_order() -> void:
	var db := _get_db()
	assert_true(db.is_valid(), "\n".join(db.errors))
	assert_eq(db.difficulty_ids(), ["easy", "normal", "hard"] as Array[String])
	assert_near(db.difficulty("easy").enemy_count_mult, 0.6)
	assert_near(db.difficulty("normal").enemy_count_mult, 1.0, 0.0)
	assert_near(db.difficulty("hard").enemy_count_mult, 1.5)


func test_normal_must_exist_and_must_not_change_anything() -> void:
	var db := ContentDb.load_from()
	db.errors.clear()
	db.difficulties.erase("normal")
	db.validate_references()
	assert_true(_has(db.errors, "difficulty 'normal' is missing"))
	var db2 := ContentDb.load_from()
	db2.errors.clear()
	var skewed: DifficultyDefinition = db2.difficulty("normal").duplicate()  # a copy: loaded resources are shared between databases
	skewed.enemy_count_mult = 1.2
	db2.difficulties["normal"] = skewed
	db2.validate_references()
	assert_true(_has(db2.errors, "must multiply enemy counts by exactly 1"))


func test_a_mission_can_only_name_a_known_difficulty() -> void:
	var db := ContentDb.load_from()
	db.errors.clear()
	var m: MissionDefinition = db.mission(MISSION).duplicate()
	m.id = "bad_level"
	m.difficulty_id = "nightmare"
	db.add_mission(m)
	db.validate_references()
	assert_true(_has(db.errors, "mission 'bad_level': unknown difficulty_id 'nightmare'"))


func test_the_menu_order_follows_the_order_field_then_the_id() -> void:
	var db := ContentDb.new()
	for spec in [["z", 1], ["a", 1], ["m", 0]]:
		var d := _diff(1.0, spec[0])
		d.order = spec[1]
		db.add_difficulty(d)
	assert_eq(db.difficulty_ids(), ["m", "a", "z"] as Array[String])


func test_a_mission_reports_its_enemy_total_at_a_level() -> void:
	var m := _get_db().mission("m3_combined_arms")
	var base := m.total_enemies()
	assert_eq(m.total_enemies_at(null), base)
	assert_eq(m.total_enemies_at(_get_db().difficulty("normal")), base)
	assert_true(m.total_enemies_at(_get_db().difficulty("hard")) > base)
	assert_true(m.total_enemies_at(_get_db().difficulty("easy")) < base)
	var by_hand := 0
	for w in m.waves:
		by_hand += _get_db().difficulty("hard").scaled_count(w.count, base)
	assert_eq(m.total_enemies_at(_get_db().difficulty("hard")), by_hand)


func test_mission_select_facts_show_the_count_at_the_chosen_level() -> void:
	var db := _get_db()
	var m := db.mission("m2_card_defense")
	var plain := MissionListing.facts(db, m)
	assert_eq(MissionListing.facts(db, m, "normal"), plain, "normal reads exactly like the old text")
	var hard := MissionListing.facts(db, m, "hard")
	assert_true(hard != plain)
	assert_true(("Enemies: %d" % m.total_enemies_at(db.difficulty("hard"))) in "\n".join(hard))


# --- in a battle -------------------------------------------------------------------------------------------------

func test_every_shipped_mission_is_unchanged_at_normal() -> void:
	for id in _get_db().missions:
		var b := _battle("", id)
		assert_eq(b.difficulty().id, "normal", id)
		for i in b.mission.waves.size():
			assert_eq(b._wave_count[i], b.mission.waves[i].count, "%s wave %d count" % [id, i])
			assert_eq(b._wave_gap[i], b.mission.waves[i].interval_s, "%s wave %d interval" % [id, i])
	_release()


func test_hard_and_easy_scale_every_wave() -> void:
	var m := _get_db().mission("m3_combined_arms")
	var base := m.total_enemies()
	var hard := _battle("hard", "m3_combined_arms")
	var easy := _battle("easy", "m3_combined_arms")
	for i in m.waves.size():
		assert_eq(hard._wave_count[i], _get_db().difficulty("hard").scaled_count(m.waves[i].count, base))
		assert_eq(easy._wave_count[i], _get_db().difficulty("easy").scaled_count(m.waves[i].count, base))
		assert_true(hard._wave_count[i] >= m.waves[i].count and easy._wave_count[i] <= m.waves[i].count, "wave %d" % i)
		if m.waves[i].count >= 4:
			assert_true(hard._wave_count[i] > m.waves[i].count and easy._wave_count[i] < m.waves[i].count, "a real wave %d scales" % i)
	_release()


func test_a_scaled_wave_really_spawns_that_many_with_the_same_first_and_last_time() -> void:
	var m: MissionDefinition = _get_db().mission(MISSION).duplicate()
	var w := WaveEntry.new()
	w.start_s = 5.0
	w.enemy_id = "shambler"
	w.count = 11
	w.interval_s = 1.0
	m.waves = [w] as Array[WaveEntry]
	for level in ["normal", "easy", "hard"]:
		var b := _battle(level, MISSION, m)
		var want := _get_db().difficulty(level).scaled_count(11)
		var first := -1.0
		var last := -1.0
		var t := 0.0
		while t < 20.0:
			b.elapsed = t
			var before := b.enemies.size()
			b._spawn_due_enemies()
			if b.enemies.size() > before:
				if first < 0.0:
					first = t
				last = t
			t += 0.01
		assert_eq(b.enemies.size(), want, "%s sends %d" % [level, want])
		assert_near(first, 5.0, 0.011, "%s: the first enemy comes at the start time" % level)
		assert_near(last, 15.0, 0.011, "%s: the last enemy comes at the same time as before" % level)
	_release()


func test_a_wave_with_no_gap_sends_the_scaled_count_all_at_once() -> void:
	var m: MissionDefinition = _get_db().mission(MISSION).duplicate()
	var w := WaveEntry.new()
	w.start_s = 2.0
	w.enemy_id = "shambler"
	w.count = 10
	w.interval_s = 0.0
	m.waves = [w] as Array[WaveEntry]
	for level in ["normal", "easy", "hard"]:
		var b := _battle(level, MISSION, m)
		b.elapsed = 1.0
		b._spawn_due_enemies()
		assert_eq(b.enemies.size(), 0, "%s: nothing before the start time" % level)
		b.elapsed = 2.0
		b._spawn_due_enemies()
		assert_eq(b.enemies.size(), _get_db().difficulty(level).scaled_count(10), "%s sends its count at once" % level)
	_release()


# --- the cap on a bigger level ------------------------------------------------------------------------------------

func _capped(mult: float, cap: int) -> DifficultyDefinition:
	var d := _diff(mult)
	d.max_total_enemies = cap
	return d


func test_a_cap_stops_a_bigger_level_at_the_limit_but_never_below_normal() -> void:
	var d := _capped(1.5, 2000)
	assert_near(d.effective_mult(1000), 1.5, 1e-9, "well under the cap: the full multiplier")
	assert_near(d.effective_mult(1600), 1.25, 1e-9, "the cap divided by the base total")
	assert_near(d.effective_mult(2000), 1.0, 1e-9, "already at the cap: no growth")
	assert_near(d.effective_mult(3000), 1.0, 1e-9, "above the cap: never smaller than normal")
	assert_near(d.effective_mult(0), 1.5, 1e-9, "no base total means no cap")
	assert_near(_capped(1.5, 0).effective_mult(5000), 1.5, 1e-9, "a cap of 0 means no limit")
	assert_near(_capped(0.6, 100).effective_mult(5000), 0.6, 1e-9, "a smaller level is never capped")
	assert_near(_capped(1.0, 100).effective_mult(5000), 1.0, 1e-9, "normal stays exactly 1")


func test_a_negative_cap_is_invalid() -> void:
	assert_true(_has(_capped(1.5, -1).validate(), "max_total_enemies"))
	assert_eq(_capped(1.5, 2000).validate().size(), 0)


func test_the_capped_scaling_keeps_the_first_and_last_time_of_a_wave() -> void:
	var d := _capped(1.5, 1200)
	# base total 1000 -> multiplier 1.2: 10 enemies become 12 over the same 9 s span
	assert_eq(d.scaled_count(10, 1000), 12)
	assert_near(d.scaled_interval(10, 1.0, 1000) * float(d.scaled_count(10, 1000) - 1), 9.0, 1e-9)


func test_hard_never_sends_more_than_its_cap_and_never_less_than_normal() -> void:
	var db := _get_db()
	var hard := db.difficulty("hard")
	assert_true(hard.max_total_enemies > 0, "hard is capped")
	for id: String in db.missions.keys():
		var m: MissionDefinition = db.missions[id]
		var base := m.total_enemies()
		var got := m.total_enemies_at(hard)
		assert_true(got >= base, "%s: hard is not easier than normal (%d vs %d)" % [id, got, base])
		# rounding each entry can add or lose up to half an enemy
		assert_true(got <= maxi(base, hard.max_total_enemies) + m.waves.size(), "%s: hard stays inside the cap (%d)" % [id, got])


func test_a_mission_already_past_the_cap_is_the_same_on_hard_and_normal() -> void:
	var m := _get_db().mission("x2_outskirts")
	assert_true(m.total_enemies() > _get_db().difficulty("hard").max_total_enemies, "x2 is past the cap at normal")
	assert_eq(m.total_enemies_at(_get_db().difficulty("hard")), m.total_enemies())


func test_a_capped_battle_spawns_what_the_listing_says() -> void:
	var m := _get_db().mission("m2_card_defense")
	var hard := _get_db().difficulty("hard")
	var b := _battle("hard", "m2_card_defense")
	var sum := 0
	for n in b._wave_count:
		sum += n
	assert_eq(sum, m.total_enemies_at(hard))
	assert_true(sum > m.total_enemies(), "m2 still grows on hard")
	assert_true(sum <= hard.max_total_enemies + m.waves.size(), "and stays inside the cap")
	_release()


func test_the_level_changes_nothing_but_enemy_counts() -> void:
	var easy := _battle("easy", "m2_card_defense")
	var hard := _battle("hard", "m2_card_defense")
	assert_near(easy.core.health.max_hp, hard.core.health.max_hp, 0.0)
	assert_near(easy.points.cap, hard.points.cap, 0.0)
	assert_near(easy.points.cp, hard.points.cp, 0.0)
	assert_near(easy.points.regen_per_s, hard.points.regen_per_s, 0.0)
	assert_eq(easy.deck.hand.size(), hard.deck.hand.size())
	assert_eq(easy.deck.draw_pile.size(), hard.deck.draw_pile.size())
	assert_near(easy.mission.duration_s, hard.mission.duration_s, 0.0)
	assert_eq(easy.db.enemy("shambler"), hard.db.enemy("shambler"), "the same enemy definition")
	assert_eq(easy.deck.hand, hard.deck.hand, "same seed, same opening hand")
	_release()


func test_the_chosen_level_beats_the_mission_default_and_unknown_ids_fall_back_to_normal() -> void:
	var m: MissionDefinition = _get_db().mission(MISSION).duplicate()
	m.id = "defaulted"
	m.difficulty_id = "hard"
	assert_eq(_battle("", MISSION, m).difficulty().id, "hard", "nothing chosen: the mission's own")
	assert_eq(_battle("easy", MISSION, m).difficulty().id, "easy", "chosen: wins")
	assert_eq(_battle("nightmare", MISSION).difficulty().id, "normal", "unknown: normal")
	_release()


func test_a_restart_keeps_the_level() -> void:
	var b := _battle("hard", "m2_card_defense")
	var counts := b._wave_count.duplicate()
	b.restart()
	assert_eq(b.difficulty().id, "hard")
	assert_eq(b._wave_count, counts)
	_release()


func test_the_difficulty_option_is_parsed_and_applied() -> void:
	var r := BattleController.parse_user_args(PackedStringArray(["--difficulty=hard", "--mission=m2_card_defense"]))
	assert_eq(r["difficulty"], "hard")
	assert_true(not BattleController.parse_user_args(PackedStringArray(["--difficulty="])).has("difficulty"))
	assert_true(not BattleController.parse_user_args(PackedStringArray(["--difficulty"])).has("difficulty"))
	var b := BattleController.new()
	b.apply_launch_options(r)
	assert_eq(b.difficulty_id, "hard")
	b.free()


func test_the_battle_takes_the_menu_level_from_the_session_once() -> void:
	GameSession.pending_mission = "m2_card_defense"
	GameSession.pending_difficulty = "hard"
	var b := BattleController.new()
	b.auto_step = false
	tree.root.add_child(b)
	assert_eq(b.difficulty().id, "hard")
	assert_eq(GameSession.pending_difficulty, "", "handed over and cleared")
	b.free()


func test_the_hud_names_the_level_unless_it_is_normal() -> void:
	var hard := _battle("hard")
	var hud := BattleHud.new()
	hud.bind(hard)
	_in_tree(hud)
	hud._process(0.0)
	assert_true("Difficulty: Hard" in hud._info_label.text)
	hud.free()
	var normal := _battle("normal")
	var hud2 := BattleHud.new()
	hud2.bind(normal)
	_in_tree(hud2)
	hud2._process(0.0)
	assert_true(not ("Difficulty" in hud2._info_label.text))
	hud2.free()
	_release()


# --- the menu and the settings ------------------------------------------------------------------------------------

func test_the_session_hands_over_the_difficulty_with_the_mission() -> void:
	GameSession.pending_mission = "x1_fortified_crossing"
	GameSession.pending_difficulty = "easy"
	var first := GameSession.take_pending()
	assert_eq(first["difficulty"], "easy")
	assert_eq(GameSession.take_pending()["difficulty"], "")


func test_starting_a_battle_hands_over_the_menu_level_and_remembers_the_mission() -> void:
	var s := GameSettings.new()
	s.difficulty = "easy"
	GameSession.set_settings(s)
	GameSession.prepare_battle("x2_outskirts", false)
	assert_eq(GameSession.pending_mission, "x2_outskirts")
	assert_eq(GameSession.pending_difficulty, "easy")
	assert_eq(s.last_mission, "x2_outskirts")
	GameSession.take_pending()
	GameSession.set_settings(GameSettings.new())


func test_settings_remember_the_level_and_repair_bad_values() -> void:
	var s := GameSettings.new()
	assert_eq(s.difficulty, "normal")
	s.difficulty = "  HARD "
	s.clamp_all()
	assert_eq(s.difficulty, "hard")
	s.difficulty = ""
	s.clamp_all()
	assert_eq(s.difficulty, "normal")
	var cfg := ConfigFile.new()
	cfg.set_value(GameSettings.SECTION, "difficulty", "easy")
	var t := GameSettings.new()
	t.from_config(cfg)
	assert_eq(t.difficulty, "easy")
	var bad := ConfigFile.new()
	bad.set_value(GameSettings.SECTION, "difficulty", 7)
	var u := GameSettings.new()
	u.from_config(bad)
	assert_eq(u.difficulty, "normal", "a wrong type keeps the default")
	var round_trip := GameSettings.new()
	round_trip.difficulty = "hard"
	var loaded := GameSettings.new()
	loaded.from_config(round_trip.to_config())
	assert_eq(loaded.difficulty, "hard", "what is saved is what a fresh settings object loads")
	round_trip.reset()
	assert_eq(round_trip.difficulty, "normal")


func test_reset_in_the_settings_screen_keeps_the_level() -> void:
	var s := GameSettings.new()
	s.master_volume = 0.1
	s.difficulty = "hard"
	GameSession.set_settings(s)
	var scr := SettingsScreen.new()
	_in_tree(scr)
	for b in scr.find_children("*", "Button", true, false):
		if (b as Button).text == "Reset to defaults":
			(b as Button).pressed.emit()
	assert_near(s.master_volume, 0.8)
	assert_eq(s.difficulty, "hard", "the level is chosen in mission select, not reset with the options")
	scr.free()
	GameSession.set_settings(GameSettings.new())
	GameSettings.new().apply()


func _select() -> MissionSelect:
	var sel := MissionSelect.new()
	sel.bind(_get_db())
	_in_tree(sel)
	return sel


func test_mission_select_offers_the_three_levels_with_the_saved_one_chosen() -> void:
	var s := GameSettings.new()
	s.difficulty = "hard"
	GameSession.set_settings(s)
	var sel := _select()
	for id in ["easy", "normal", "hard"]:
		assert_true(sel.find_child("Difficulty_%s" % id, true, false) != null, id)
	assert_eq(sel.level(), "hard")
	assert_true((sel.find_child("Difficulty_hard", true, false) as Button).button_pressed)
	assert_true(not (sel.find_child("Difficulty_normal", true, false) as Button).button_pressed)
	sel.free()
	GameSession.set_settings(GameSettings.new())


func test_an_unknown_saved_level_shows_as_normal() -> void:
	var s := GameSettings.new()
	s.difficulty = "nightmare"
	GameSession.set_settings(s)
	var sel := _select()
	assert_eq(sel.level(), "normal")
	sel.free()
	GameSession.set_settings(GameSettings.new())


func test_choosing_a_level_updates_the_facts_and_the_settings() -> void:
	var s := GameSettings.new()
	GameSession.set_settings(s)
	var sel := _select()
	var facts: Label = sel.find_children("*", "Label", true, false).filter(func(l: Label) -> bool: return l.text.begins_with("Hold the core"))[0]
	var normal_text := facts.text
	(sel.find_child("Difficulty_hard", true, false) as Button).pressed.emit()
	assert_eq(sel.level(), "hard")
	assert_eq(s.difficulty, "hard", "remembered for the next battle")
	assert_true(facts.text != normal_text, "the enemy count changed")
	assert_true((sel.find_child("Difficulty_hard", true, false) as Button).button_pressed)
	assert_true(not (sel.find_child("Difficulty_normal", true, false) as Button).button_pressed)
	sel.set_level("nightmare")
	assert_eq(sel.level(), "hard", "an unknown level is ignored")
	sel.free()
	GameSession.set_settings(GameSettings.new())


func _key(action: String) -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	return ev


func test_the_arrow_keys_change_the_level() -> void:
	GameSession.set_settings(GameSettings.new())
	var sel := _select()
	sel._unhandled_input(_key("ui_right"))
	assert_eq(sel.level(), "hard")
	sel._unhandled_input(_key("ui_left"))
	sel._unhandled_input(_key("ui_left"))
	assert_eq(sel.level(), "easy")
	sel.free()
	GameSession.set_settings(GameSettings.new())


func test_left_and_right_step_through_the_levels_and_stop_at_the_ends() -> void:
	GameSession.set_settings(GameSettings.new())
	var sel := _select()
	assert_eq(sel.level(), "normal")
	sel.cycle_level(1)
	assert_eq(sel.level(), "hard")
	sel.cycle_level(1)
	assert_eq(sel.level(), "hard", "stops at the hardest")
	sel.cycle_level(-1)
	sel.cycle_level(-1)
	assert_eq(sel.level(), "easy")
	sel.cycle_level(-1)
	assert_eq(sel.level(), "easy", "stops at the easiest")
	sel.free()
	GameSession.set_settings(GameSettings.new())
