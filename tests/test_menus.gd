extends TestCase
## The game shell (docs/specs/menus.md): settings storage, the session hand-over and the mission listing.

const TMP: String = "user://test_settings.cfg"

var _db: ContentDb


func _get_db() -> ContentDb:
	if _db == null:
		_db = ContentDb.load_from()
	return _db


func _remove_tmp() -> void:
	if FileAccess.file_exists(TMP):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))


# --- settings -----------------------------------------------------------------------------------------------------

func test_defaults_are_sensible() -> void:
	var s := GameSettings.new()
	assert_near(s.master_volume, 0.8)
	assert_true(not s.fullscreen)
	assert_true(s.cutaways)
	assert_true(s.show_fps)
	assert_eq(s.last_mission, "")


func test_settings_survive_a_save_and_load() -> void:
	_remove_tmp()
	var s := GameSettings.new()
	s.master_volume = 0.35
	s.fullscreen = true
	s.cutaways = false
	s.show_fps = false
	s.last_mission = "x2_outskirts"
	assert_true(s.save(TMP))
	var r := GameSettings.load_from(TMP)
	assert_near(r.master_volume, 0.35)
	assert_true(r.fullscreen)
	assert_true(not r.cutaways)
	assert_true(not r.show_fps)
	assert_eq(r.last_mission, "x2_outskirts")
	_remove_tmp()


func test_a_missing_file_gives_the_defaults() -> void:
	_remove_tmp()
	var r := GameSettings.load_from(TMP)
	assert_near(r.master_volume, 0.8)
	assert_true(r.cutaways)


func test_a_corrupt_file_gives_the_defaults_without_errors() -> void:
	var f := FileAccess.open(TMP, FileAccess.WRITE)
	f.store_string("this is [[ not a config file\n=== ]] = = =\n")
	f.close()
	var r := GameSettings.load_from(TMP)
	assert_near(r.master_volume, 0.8)
	assert_true(r.show_fps)
	_remove_tmp()


func test_wrong_types_and_out_of_range_values_are_repaired() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(GameSettings.SECTION, "master_volume", 7.5)
	cfg.set_value(GameSettings.SECTION, "fullscreen", "yes")
	cfg.set_value(GameSettings.SECTION, "cutaways", 3)
	cfg.set_value(GameSettings.SECTION, "last_mission", 12)
	var s := GameSettings.new()
	s.from_config(cfg)
	assert_near(s.master_volume, 1.0, 1e-9, "clamped")
	assert_true(not s.fullscreen, "a string is not a bool: default kept")
	assert_true(s.cutaways, "an int is not a bool: default kept")
	assert_eq(s.last_mission, "", "an int is not a string: default kept")
	cfg.set_value(GameSettings.SECTION, "master_volume", -3.0)
	s.from_config(cfg)
	assert_near(s.master_volume, 0.0, 1e-9)
	cfg.set_value(GameSettings.SECTION, "master_volume", NAN)
	s.from_config(cfg)
	assert_near(s.master_volume, 0.8, 1e-9, "not a number: back to the default")


func test_reset_restores_every_default() -> void:
	var s := GameSettings.new()
	s.master_volume = 0.1
	s.fullscreen = true
	s.cutaways = false
	s.show_fps = false
	s.last_mission = "m1_hold_the_crossing"
	s.reset()
	assert_near(s.master_volume, 0.8)
	assert_true(not s.fullscreen and s.cutaways and s.show_fps)
	assert_eq(s.last_mission, "")


func test_the_volume_curve_is_silent_at_zero_loud_at_full_and_rises_in_between() -> void:
	assert_near(GameSettings.volume_to_db(1.0), 0.0, 1e-6)
	assert_true(GameSettings.volume_to_db(0.0) <= -80.0)
	var prev := GameSettings.volume_to_db(0.01)
	for i in range(2, 101):
		var db := GameSettings.volume_to_db(float(i) / 100.0)
		assert_true(db >= prev, "never gets quieter as the slider goes up (%d)" % i)
		prev = db
	assert_true(GameSettings.volume_to_db(0.5) > GameSettings.MIN_DB)


func test_applying_settings_in_a_headless_run_is_harmless_and_sets_the_bus() -> void:
	var s := GameSettings.new()
	s.master_volume = 0.5
	s.apply()
	var bus := AudioServer.get_bus_index("Master")
	assert_near(AudioServer.get_bus_volume_db(bus), GameSettings.volume_to_db(0.5), 0.01)
	GameSettings.new().apply()  # put the default level back for the other tests


# --- the session ----------------------------------------------------------------------------------------------------

func test_the_pending_mission_is_handed_over_once() -> void:
	GameSession.pending_mission = "x1_fortified_crossing"
	GameSession.pending_seed = 9
	var first := GameSession.take_pending()
	assert_eq(first["mission"], "x1_fortified_crossing")
	assert_eq(first["seed"], 9)
	var second := GameSession.take_pending()
	assert_eq(second["mission"], "")
	assert_eq(second["seed"], 0)


func test_the_scene_paths_exist() -> void:
	assert_true(ResourceLoader.exists(GameSession.MENU_SCENE), GameSession.MENU_SCENE)
	assert_true(ResourceLoader.exists(GameSession.BATTLE_SCENE), GameSession.BATTLE_SCENE)


# --- mission listing --------------------------------------------------------------------------------------------------

func test_every_mission_is_listed_exactly_once() -> void:
	var db := _get_db()
	var list := MissionListing.entries(db)
	assert_eq(list.size(), db.missions.size())
	var seen: Dictionary = {}
	for e in list:
		assert_true(not seen.has(e.id), "%s listed once" % e.id)
		seen[e.id] = true
		assert_true(db.missions.has(e.id))
		assert_eq(e.name, (db.missions[e.id] as MissionDefinition).display_name)


func test_missions_come_first_then_test_missions_each_sorted() -> void:
	var list := MissionListing.entries(_get_db())
	var in_tests := false
	var prev_id := ""
	var prev_group := ""
	for e in list:
		if e.group != prev_group:
			prev_id = ""
			prev_group = e.group
		assert_true(prev_id.is_empty() or MissionListing.id_less(prev_id, e.id), "%s sorted inside %s" % [e.id, e.group])
		prev_id = e.id
		if e.group == MissionListing.GROUP_TESTS:
			in_tests = true
		else:
			assert_true(not in_tests, "no mission after the test missions begin: %s" % e.id)


func test_groups_follow_the_id_prefix() -> void:
	assert_eq(MissionListing.group_of("m2_card_defense"), MissionListing.GROUP_MISSIONS)
	assert_eq(MissionListing.group_of("x3_storm_night"), MissionListing.GROUP_MISSIONS)
	assert_eq(MissionListing.group_of("s1_stress_horde"), MissionListing.GROUP_TESTS)
	assert_eq(MissionListing.group_of("dev_showcase"), MissionListing.GROUP_TESTS)
	assert_eq(MissionListing.group_of("mission_x"), MissionListing.GROUP_TESTS, "m followed by a letter is not a campaign id")
	assert_eq(MissionListing.group_of(""), MissionListing.GROUP_TESTS)


func test_the_facts_match_the_mission_data() -> void:
	var db := _get_db()
	var m := db.mission("m2_card_defense")
	var text := "\n".join(MissionListing.facts(db, m))
	assert_true("2:00" in text, "duration")
	assert_true(str(m.total_enemies()) in text, "enemy count")
	assert_true("Starter Deck" in text and str(db.deck("starter").card_ids.size()) in text, "deck and its size")
	assert_true(str(int(m.core_health)) in text, "core health")
	var no_cards := "\n".join(MissionListing.facts(db, db.mission("m1_hold_the_crossing")))
	assert_true("No cards" in no_cards, "a mission without a deck says so")
	assert_eq(MissionListing.facts(db, null).size(), 0)


func test_time_formatting_and_names() -> void:
	assert_eq(MissionListing.format_time(120.0), "2:00")
	assert_eq(MissionListing.format_time(65.4), "1:05")
	assert_eq(MissionListing.format_time(-5.0), "0:00")
	assert_eq(MissionListing.time_name(0.0), "night")
	assert_eq(MissionListing.time_name(0.3), "morning")
	assert_eq(MissionListing.time_name(0.5), "day")
	assert_eq(MissionListing.time_name(0.75), "evening")
	assert_eq(MissionListing.time_name(0.95), "night")


func test_enemy_names_are_distinct_and_in_order_of_appearance() -> void:
	var db := _get_db()
	var names := MissionListing.enemy_names(db, db.mission("m3_combined_arms"))
	var seen: Dictionary = {}
	for n in names:
		assert_true(not seen.has(n), "%s once" % n)
		seen[n] = true
	assert_true(names.size() >= 2)


# --- the strike range ------------------------------------------------------------------------------------------------

func test_the_strike_range_deck_holds_every_new_strike_card_and_is_legal() -> void:
	var db := _get_db()
	assert_true(db.is_valid(), "content errors: %s" % ", ".join(db.errors))
	var deck := db.deck("strikes")
	assert_true(deck != null)
	for id in ["naval_gunfire", "close_air_support", "missile_strike", "hypersonic_missile", "nuclear_bomb", "satellite_laser"]:
		assert_true(deck.card_ids.has(id), "%s is in the strike deck" % id)
	var ids: Array[String] = []
	ids.assign(deck.card_ids)
	assert_eq(db.deck_rules.validate_deck(ids, db.cards).size(), 0)
	var m := db.mission("dev_strike_range")
	assert_true(m != null and m.deck_id == "strikes")
	assert_eq(MissionListing.group_of(m.id), MissionListing.GROUP_TESTS)


# --- the screens ---------------------------------------------------------------------------------------------------

func _in_tree(n: Node) -> Node:
	tree.root.add_child(n)
	return n


## A profile that has won every campaign mission, so mission select shows nothing locked.
func _all_won_profile() -> PlayerProfile:
	var p := PlayerProfile.new_game(_get_db(), 1)
	for id in _get_db().main_campaign().mission_ids:
		p.record_win(id, 1.0, "normal", 1.0)
	return p


func test_mission_select_lists_every_mission_with_headings_and_selects_one() -> void:
	var s := GameSettings.new()
	s.show_test_missions = true
	GameSession.set_settings(s)
	GameSession.set_profile(_all_won_profile())
	var sel := MissionSelect.new()
	sel.bind(_get_db())
	_in_tree(sel)
	var list: ItemList = sel.find_children("*", "ItemList", true, false)[0]
	var missions := 0
	var headings := 0
	for i in list.item_count:
		if list.is_item_disabled(i):
			headings += 1
		else:
			missions += 1
	assert_eq(missions, _get_db().missions.size())
	assert_eq(headings, 2, "Missions and Test missions")
	assert_true(not sel.selected_id().is_empty(), "something is pre-selected")
	assert_eq(MissionListing.group_of(sel.selected_id()), MissionListing.GROUP_MISSIONS, "a real mission, not a test one")
	var ids: Array[String] = []
	sel.start_requested.connect(func(id: String) -> void: ids.append(id))
	sel.find_child("Start", true, false).pressed.emit()
	assert_eq(ids.size(), 1)
	assert_eq(ids[0], sel.selected_id())
	sel.free()
	GameSession.set_profile(null)


func test_mission_select_preselects_the_last_mission_played() -> void:
	var s := GameSettings.new()
	s.last_mission = "x2_outskirts"
	GameSession.set_settings(s)
	GameSession.set_profile(_all_won_profile())
	var sel := MissionSelect.new()
	sel.bind(_get_db())
	_in_tree(sel)
	assert_eq(sel.selected_id(), "x2_outskirts")
	sel.free()
	GameSession.set_settings(GameSettings.new())
	GameSession.set_profile(null)


func test_the_settings_screen_shows_the_values_and_writes_changes_back() -> void:
	var s := GameSettings.new()
	s.master_volume = 0.4
	s.show_fps = false
	GameSession.set_settings(s)
	var scr := SettingsScreen.new()
	_in_tree(scr)
	var slider: HSlider = scr.find_children("*", "HSlider", true, false)[0]
	assert_near(slider.value, 40.0)
	var toggles := scr.find_children("*", "CheckButton", true, false)
	assert_eq(toggles.size(), 4)  # fullscreen, clips, FPS, test missions
	assert_true(not (toggles[2] as CheckButton).button_pressed, "FPS counter is off")
	(toggles[1] as CheckButton).button_pressed = false  # strike clips off
	assert_true(not s.cutaways)
	(toggles[2] as CheckButton).button_pressed = true
	assert_true(s.show_fps)
	slider.value = 75.0
	assert_near(s.master_volume, 0.75)
	scr.free()
	GameSession.set_settings(GameSettings.new())
	GameSettings.new().apply()


func test_reset_in_the_settings_screen_keeps_the_last_mission() -> void:
	var s := GameSettings.new()
	s.master_volume = 0.1
	s.last_mission = "m3_combined_arms"
	GameSession.set_settings(s)
	var scr := SettingsScreen.new()
	_in_tree(scr)
	for b in scr.find_children("*", "Button", true, false):
		if (b as Button).text == "Reset to defaults":
			(b as Button).pressed.emit()
	assert_near(s.master_volume, 0.8)
	assert_eq(s.last_mission, "m3_combined_arms")
	scr.free()
	GameSession.set_settings(GameSettings.new())
	GameSettings.new().apply()


func test_pausing_stops_the_tree_and_resuming_starts_it_again() -> void:
	var b := BattleController.new()
	b.auto_step = false
	b.setup(_get_db(), _get_db().mission("m2_card_defense"), 1)
	tree.root.add_child(b)
	var pm := PauseMenu.new()
	_in_tree(pm)
	pm.bind(b)
	assert_true(not pm.is_open())
	b.pause_requested.emit()
	assert_true(pm.is_open() and tree.paused, "Esc opens the menu and pauses")
	b.pause_requested.emit()
	assert_true(not pm.is_open() and not tree.paused, "a second Esc resumes")
	pm.pause()
	pm.resume()
	assert_true(not tree.paused)
	pm.free()
	b.free()
	tree.paused = false


func test_the_pause_menu_does_not_open_over_a_finished_battle() -> void:
	var b := BattleController.new()
	b.auto_step = false
	b.setup(_get_db(), _get_db().mission("m1_hold_the_crossing"), 1)
	tree.root.add_child(b)
	var pm := PauseMenu.new()
	_in_tree(pm)
	pm.bind(b)
	b.core.health.hp = 0.0
	b.step(1.0 / 60.0)
	assert_true(b.is_ended())
	pm.pause()
	assert_true(not pm.is_open() and not tree.paused)
	pm.free()
	b.free()
	tree.paused = false


func test_the_battle_takes_its_mission_from_the_session_once() -> void:
	GameSession.pending_mission = "m2_card_defense"
	var b := BattleController.new()
	b.auto_step = false
	tree.root.add_child(b)  # _ready reads the session
	assert_eq(b.mission.id, "m2_card_defense")
	assert_eq(GameSession.pending_mission, "", "handed over and cleared")
	b.free()
