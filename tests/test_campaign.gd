extends TestCase
## The campaign chain, locks and progress records (docs/specs/progression.md, increment 5.2).

const DIR: String = "user://test_campaign"
const PATH: String = "user://test_campaign/profile.json"

var _db: ContentDb


func _get_db() -> ContentDb:
	if _db == null:
		_db = ContentDb.load_from()
	return _db


func _camp() -> CampaignDefinition:
	return _get_db().main_campaign()


func _fresh() -> PlayerProfile:
	return PlayerProfile.new_game(_get_db(), 1)


func _clean() -> void:
	var abs_dir := ProjectSettings.globalize_path(DIR)
	if DirAccess.dir_exists_absolute(abs_dir):
		for f in DirAccess.get_files_at(abs_dir):
			DirAccess.remove_absolute(abs_dir.path_join(f))
	else:
		DirAccess.make_dir_recursive_absolute(abs_dir)


func _in_tree(n: Node) -> Node:
	tree.root.add_child(n)
	return n


# --- the data ----------------------------------------------------------------------------------------------------

func test_the_campaign_lists_exactly_the_real_missions_once() -> void:
	var db := _get_db()
	assert_true(db.is_valid(), "content errors: %s" % ", ".join(db.errors))
	var camp := _camp()
	assert_true(camp != null)
	var real: Array[String] = []
	for id: String in db.missions:
		if MissionListing.group_of(id) == MissionListing.GROUP_MISSIONS:
			real.append(id)
	assert_eq(camp.mission_ids.size(), real.size(), "every real mission is in the chain, no test mission is")
	for id in real:
		assert_true(camp.contains(id), "%s is in the campaign" % id)
	assert_eq(camp.validate().size(), 0)


func test_a_campaign_with_a_repeated_or_missing_mission_is_invalid() -> void:
	var c := CampaignDefinition.new()
	c.id = "bad"
	c.display_name = "Bad"
	assert_true(c.validate().size() > 0, "empty chain")
	c.mission_ids = PackedStringArray(["a", "b", "a"])
	assert_true(c.validate().size() > 0, "repeated mission")
	var db := ContentDb.new()
	db.add_campaign(c)
	var d2 := CampaignDefinition.new()
	d2.id = "main"
	d2.display_name = "Main"
	d2.mission_ids = PackedStringArray(["nowhere"])
	db.add_campaign(d2)
	db.validate_references()
	var found := false
	for e in db.errors:
		found = found or e.contains("unknown mission 'nowhere'")
	assert_true(found, "an unknown mission in the chain is reported")


# --- the rules ---------------------------------------------------------------------------------------------------

func test_only_the_first_mission_is_open_at_the_start() -> void:
	var camp := _camp()
	var p := _fresh()
	assert_true(camp.is_unlocked(p, camp.mission_ids[0]))
	for i in range(1, camp.mission_ids.size()):
		assert_true(not camp.is_unlocked(p, camp.mission_ids[i]), "%s is locked" % camp.mission_ids[i])
	assert_eq(camp.next_up(p), camp.mission_ids[0])


func test_winning_a_mission_opens_the_next_and_only_the_next() -> void:
	var camp := _camp()
	var p := _fresh()
	p.record_win(camp.mission_ids[0], 0.5, "normal", 1.0)
	assert_true(camp.is_unlocked(p, camp.mission_ids[1]))
	assert_true(not camp.is_unlocked(p, camp.mission_ids[2]))
	assert_eq(camp.next_up(p), camp.mission_ids[1])
	assert_eq(camp.unlocked_by(p, camp.mission_ids[0]), camp.mission_ids[1])


func test_winning_out_of_order_does_not_skip_the_chain() -> void:
	var camp := _camp()
	var p := _fresh()
	p.record_win(camp.mission_ids[3], 0.5, "normal", 1.0)  # e.g. a hand-edited or imported profile
	assert_true(not camp.is_unlocked(p, camp.mission_ids[3]), "the chain still asks for the missions before it")
	assert_true(camp.is_unlocked(p, camp.mission_ids[4]), "but the one after a won mission is open")
	assert_eq(camp.next_up(p), camp.mission_ids[0])


func test_missions_outside_the_chain_are_never_locked() -> void:
	assert_true(_camp().is_unlocked(_fresh(), "dev_strike_range"))
	assert_true(_camp().is_unlocked(_fresh(), "s1_stress_horde"))
	assert_eq(_camp().previous_of("dev_strike_range"), "")


func test_next_up_is_empty_when_everything_is_won() -> void:
	var camp := _camp()
	var p := _fresh()
	for id in camp.mission_ids:
		p.record_win(id, 1.0, "normal", 1.0)
	assert_eq(camp.next_up(p), "")
	assert_eq(camp.unlocked_by(p, camp.mission_ids[camp.mission_ids.size() - 1]), "")


# --- the listing -------------------------------------------------------------------------------------------------

func test_the_missions_are_listed_in_campaign_order() -> void:
	var db := _get_db()
	var camp := _camp()
	var ids: Array[String] = []
	for e in MissionListing.entries(db, false):
		ids.append(e.id)
	assert_eq(ids.size(), camp.mission_ids.size(), "test missions are left out when asked")
	for i in ids.size():
		assert_eq(ids[i], camp.mission_ids[i])
	var with_tests := MissionListing.entries(db, true)
	assert_eq(with_tests.size(), db.missions.size())
	assert_eq(with_tests[with_tests.size() - 1].group, MissionListing.GROUP_TESTS)


func test_tags_and_progress_lines_say_what_the_player_needs_to_know() -> void:
	var db := _get_db()
	var camp := _camp()
	var p := _fresh()
	var first := camp.mission_ids[0]
	var second := camp.mission_ids[1]
	assert_eq(MissionListing.tag_for(db, p, first), "")
	assert_eq(MissionListing.tag_for(db, p, second), "locked")
	assert_true(MissionListing.progress_lines(db, p, second)[0].contains(db.mission(first).display_name))
	p.record_win(first, 0.75, "hard", 1.2)
	assert_eq(MissionListing.tag_for(db, p, first), "won")
	assert_eq(MissionListing.tag_for(db, p, second), "")
	var line := MissionListing.progress_lines(db, p, first)[0]
	assert_true(line.contains("Won 1 time.") and line.contains("75%") and line.contains("Hard"), line)
	assert_eq(MissionListing.progress_lines(db, p, "dev_strike_range").size(), 0)


# --- recording a battle -------------------------------------------------------------------------------------------

func test_the_first_win_records_and_says_what_it_unlocked() -> void:
	var db := _get_db()
	var camp := _camp()
	var p := _fresh()
	var r := ProgressRecorder.record(p, db, camp.mission_ids[0], 0.8, "normal", 1.0)
	assert_eq(r["unlocked"], camp.mission_ids[1])
	assert_true(String(r["text"]).begins_with("Unlocked: "))
	assert_eq(p.wins_of(camp.mission_ids[0]), 1)
	var again := ProgressRecorder.record(p, db, camp.mission_ids[0], 0.9, "normal", 1.0)
	assert_eq(again["unlocked"], "", "a replay opens nothing new")
	assert_eq(p.wins_of(camp.mission_ids[0]), 2)


func test_a_read_only_profile_is_not_changed() -> void:
	var p := _fresh()
	p.read_only = true
	var r := ProgressRecorder.record(p, _get_db(), "m1_hold_the_crossing", 1.0, "normal", 1.0)
	assert_eq(r["unlocked"], "")
	assert_true(String(r["text"]).contains("not saved"))
	assert_eq(p.wins_of("m1_hold_the_crossing"), 0)


func _battle_for(mission_id: String) -> BattleController:
	var b := BattleController.new()
	b.auto_step = false
	b.setup(_get_db(), _get_db().mission(mission_id), 1)
	return b


func test_the_recorder_writes_a_win_and_ignores_a_defeat() -> void:
	var b := _battle_for("m1_hold_the_crossing")
	var rec := ProgressRecorder.new()
	rec.persist = false
	rec.bind(b)
	var p := _fresh()
	GameSession.set_profile(p)
	var notes: Array[String] = []
	rec.recorded.connect(func(_u: String, note: String) -> void: notes.append(note))
	b.battle_ended.emit(MissionRules.Result.new(MissionRules.Status.FAILED, "core destroyed"))
	assert_eq(p.wins_of("m1_hold_the_crossing"), 0)
	assert_eq(notes.size(), 0)
	b.battle_ended.emit(MissionRules.Result.new(MissionRules.Status.WON, "held"))
	assert_eq(p.wins_of("m1_hold_the_crossing"), 1)
	assert_eq(notes.size(), 1)
	assert_true(notes[0].begins_with("Unlocked: "))
	rec.free()
	b.free()
	GameSession.set_profile(null)


func test_a_battle_started_from_the_menu_gets_a_recorder_and_a_command_line_one_does_not() -> void:
	GameSession.pending_mission = "m1_hold_the_crossing"
	var b := BattleController.new()
	b.auto_step = false
	tree.root.add_child(b)
	assert_true(b.get_node_or_null("ProgressRecorder") != null, "started from the menu")
	b.free()
	GameSession.pending_mission = ""
	var b2 := BattleController.new()
	b2.auto_step = false
	b2.mission_id = "m1_hold_the_crossing"
	tree.root.add_child(b2)
	assert_true(b2.get_node_or_null("ProgressRecorder") == null, "a plain launch records nothing")
	b2.free()


# --- the screens -------------------------------------------------------------------------------------------------

func test_mission_select_greys_locked_missions_and_will_not_start_them() -> void:
	var db := _get_db()
	var camp := _camp()
	GameSession.set_settings(GameSettings.new())
	GameSession.set_profile(_fresh())
	var sel := MissionSelect.new()
	sel.bind(db)
	_in_tree(sel)
	assert_eq(sel.selected_id(), camp.mission_ids[0], "the first unwon mission is pre-selected")
	var list: ItemList = sel.find_children("*", "ItemList", true, false)[0]
	var headings := 0
	var locked := 0
	for i in list.item_count:
		if list.is_item_disabled(i):
			headings += 1
		elif list.get_item_text(i).ends_with("[locked]"):
			locked += 1
	assert_eq(headings, 1, "test missions are hidden by default")
	assert_eq(locked, camp.mission_ids.size() - 1)
	var started: Array[String] = []
	sel.start_requested.connect(func(id: String) -> void: started.append(id))
	var start: Button = sel.find_child("Start", true, false)
	assert_true(not start.disabled)
	list.select(2)
	list.item_selected.emit(2)
	assert_true(start.disabled, "a locked mission cannot be started")
	start.pressed.emit()
	list.item_activated.emit(2)
	assert_eq(started.size(), 0)
	sel.free()
	GameSession.set_profile(null)


func test_a_won_mission_opens_the_next_one_in_mission_select() -> void:
	var db := _get_db()
	var camp := _camp()
	var p := _fresh()
	p.record_win(camp.mission_ids[0], 1.0, "normal", 1.0)
	GameSession.set_settings(GameSettings.new())
	GameSession.set_profile(p)
	var sel := MissionSelect.new()
	sel.bind(db)
	_in_tree(sel)
	assert_eq(sel.selected_id(), camp.mission_ids[1], "the next mission to play is pre-selected")
	assert_true(not (sel.find_child("Start", true, false) as Button).disabled)
	sel.free()
	GameSession.set_profile(null)


func test_test_missions_appear_when_the_setting_is_on() -> void:
	var s := GameSettings.new()
	s.show_test_missions = true
	GameSession.set_settings(s)
	GameSession.set_profile(_fresh())
	var sel := MissionSelect.new()
	sel.bind(_get_db())
	_in_tree(sel)
	var list: ItemList = sel.find_children("*", "ItemList", true, false)[0]
	var found := false
	for i in list.item_count:
		found = found or list.get_item_text(i) == _get_db().mission("dev_strike_range").display_name
	assert_true(found, "dev_strike_range is listed and not marked locked")
	sel.free()
	GameSession.set_settings(GameSettings.new())
	GameSession.set_profile(null)


func test_the_test_missions_setting_survives_a_save_and_reads_back_safely() -> void:
	var s := GameSettings.new()
	assert_true(not s.show_test_missions)
	s.show_test_missions = true
	var cfg := s.to_config()
	var r := GameSettings.new()
	r.from_config(cfg)
	assert_true(r.show_test_missions)
	cfg.set_value(GameSettings.SECTION, "show_test_missions", "yes")
	var bad := GameSettings.new()
	bad.from_config(cfg)
	assert_true(not bad.show_test_missions, "a wrong-typed value keeps the default")
	r.reset()
	assert_true(not r.show_test_missions)


func test_resetting_progress_asks_twice_and_the_pause_menu_has_no_such_button() -> void:
	_clean()
	GameSession.profile_path = PATH
	GameSession.set_settings(GameSettings.new())
	var p := _fresh()
	p.record_win("m1_hold_the_crossing", 1.0, "normal", 1.0)
	p.reward_seed = 4242
	GameSession.set_profile(p)
	var screen := SettingsScreen.new()
	_in_tree(screen)
	var btn: Button = screen.find_child("ResetProgress", true, false)
	assert_true(btn != null)
	btn.pressed.emit()
	assert_true(GameSession.profile().is_won("m1_hold_the_crossing"), "one click only asks")
	btn.pressed.emit()
	assert_true(not GameSession.profile().is_won("m1_hold_the_crossing"), "the second click erases")
	assert_true(GameSession.profile().reward_seed != 4242, "with a new reward seed")
	assert_true(FileAccess.file_exists(PATH), "and writes the new profile")
	screen.free()
	var calm := SettingsScreen.new()
	calm.allow_progress_reset = false
	_in_tree(calm)
	assert_true(calm.find_child("ResetProgress", true, false) == null)
	calm.free()
	GameSession.profile_path = ProfileStore.PATH
	GameSession.set_profile(null)
	_clean()
