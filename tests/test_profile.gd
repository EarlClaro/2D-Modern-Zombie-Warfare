extends TestCase
## The player profile and its safe save (docs/specs/progression.md, increment 5.1): the data, the file round trip, the
## backup, a damaged file, a file from a newer game, and the version steps.

const DIR: String = "user://test_profile"
const PATH: String = "user://test_profile/profile.json"

var _db: ContentDb


func _get_db() -> ContentDb:
	if _db == null:
		_db = ContentDb.load_from()
	return _db


func _clean() -> void:
	var abs_dir := ProjectSettings.globalize_path(DIR)
	if DirAccess.dir_exists_absolute(abs_dir):
		for f in DirAccess.get_files_at(abs_dir):
			DirAccess.remove_absolute(abs_dir.path_join(f))
	else:
		DirAccess.make_dir_recursive_absolute(abs_dir)


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _names() -> PackedStringArray:
	return DirAccess.get_files_at(ProjectSettings.globalize_path(DIR))


# --- the data ----------------------------------------------------------------------------------------------------

func test_a_new_game_owns_the_starter_cards_and_uses_the_starter_deck() -> void:
	var db := _get_db()
	var p := PlayerProfile.new_game(db, 1234)
	var starter := db.deck("starter")
	assert_eq(p.deck.size(), starter.card_ids.size())
	assert_eq(p.reward_seed, 1234)
	for cid in starter.card_ids:
		assert_true(p.owns(cid), "%s is owned from the start" % cid)
	assert_true(p.collection.size() < p.deck.size(), "the collection lists each card once, the deck lists its copies")
	assert_true(p.deck_is_legal(db))
	assert_true(p.missions.is_empty() and p.rewards.is_empty())


func test_the_dictionary_round_trip_keeps_everything() -> void:
	var db := _get_db()
	var p := PlayerProfile.new_game(db, 77)
	p.record_win("m1_hold_the_crossing", 0.6, "hard", 1.2)
	p.open_reward("m1_hold_the_crossing")
	p.take_reward("m1_hold_the_crossing", "tank")
	p.collection.append("ifv")
	var q := PlayerProfile.from_dict(JSON.parse_string(JSON.stringify(p.to_dict())))
	assert_eq(q.version, PlayerProfile.CURRENT_VERSION)
	assert_eq(q.reward_seed, 77)
	assert_eq(Array(q.collection), Array(p.collection))
	assert_eq(Array(q.deck), Array(p.deck))
	assert_eq(q.wins_of("m1_hold_the_crossing"), 1)
	assert_near(float(q.missions["m1_hold_the_crossing"]["best_core"]), 0.6)
	assert_eq(q.missions["m1_hold_the_crossing"]["best_difficulty"], "hard")
	assert_eq(q.rewards["m1_hold_the_crossing"], "tank")


func test_wrong_typed_fields_fall_back_to_defaults() -> void:
	var p := PlayerProfile.from_dict({
		"version": "one", "reward_seed": [1], "collection": "tank", "deck": [1, 2, "tank", null, ""],
		"doctrines": {"a": 1}, "missions": {"m1_hold_the_crossing": "won", 5: {}, "x2_outskirts": {"wins": "many", "best_core": 7.5}},
		"rewards": {"m1_hold_the_crossing": 3, "x2_outskirts": "rifle_squad"}})
	assert_eq(p.version, 0)
	assert_eq(p.reward_seed, 0)
	assert_eq(p.collection.size(), 0)
	assert_eq(Array(p.deck), ["tank"], "only the strings that are ids survive")
	assert_eq(p.doctrines.size(), 0)
	assert_true(not p.missions.has("m1_hold_the_crossing"))
	assert_eq(p.wins_of("x2_outskirts"), 0)
	assert_near(float(p.missions["x2_outskirts"]["best_core"]), 1.0, 1e-9, "a core fraction is clamped to 0..1")
	assert_true(not p.rewards.has("m1_hold_the_crossing"))
	assert_eq(p.rewards["x2_outskirts"], "rifle_squad")


func test_a_win_keeps_the_best_result_and_the_harder_level() -> void:
	var p := PlayerProfile.new()
	p.record_win("m2_card_defense", 0.5, "normal", 1.0)
	p.record_win("m2_card_defense", 0.9, "easy", 0.6)
	assert_eq(p.wins_of("m2_card_defense"), 2)
	assert_near(float(p.missions["m2_card_defense"]["best_core"]), 0.9)
	assert_eq(p.missions["m2_card_defense"]["best_difficulty"], "normal", "an easy win does not replace a normal one")
	p.record_win("m2_card_defense", 0.1, "hard", 1.2)
	assert_eq(p.missions["m2_card_defense"]["best_difficulty"], "hard")
	assert_near(float(p.missions["m2_card_defense"]["best_core"]), 0.9)
	p.record_win("m2_card_defense", NAN, "normal", 1.0)
	assert_eq(p.wins_of("m2_card_defense"), 4, "a nonsense core fraction still counts the win")
	assert_true(p.is_won("m2_card_defense") and not p.is_won("m3_combined_arms"))


func test_reward_offers_wait_until_a_card_is_taken() -> void:
	var p := PlayerProfile.new()
	p.open_reward("m1_hold_the_crossing")
	p.open_reward("m2_card_defense")
	assert_eq(Array(p.pending_rewards()), ["m1_hold_the_crossing", "m2_card_defense"])
	p.take_reward("m1_hold_the_crossing", "ifv")
	assert_true(p.owns("ifv"))
	assert_eq(Array(p.pending_rewards()), ["m2_card_defense"])
	p.open_reward("m1_hold_the_crossing")
	assert_eq(p.rewards["m1_hold_the_crossing"], "ifv", "opening an answered offer does not reset it")


# --- sanitize ---------------------------------------------------------------------------------------------------

func test_sanitize_drops_ids_the_game_no_longer_has() -> void:
	var db := _get_db()
	var p := PlayerProfile.new_game(db, 5)
	p.collection.append("laser_cat")
	p.doctrines.append("laser_cat")
	p.missions["x99_gone"] = {"wins": 1}
	p.rewards["x99_gone"] = "tank"
	p.rewards["m1_hold_the_crossing"] = "laser_cat"
	var changed := p.sanitize(db)
	assert_true(changed >= 4)
	assert_true(not p.owns("laser_cat"))
	assert_eq(p.doctrines.size(), 0)
	assert_true(not p.missions.has("x99_gone") and not p.rewards.has("x99_gone"))
	assert_true(not p.rewards.has("m1_hold_the_crossing"))
	assert_true(p.deck_is_legal(db))


func test_sanitize_replaces_an_illegal_deck_and_keeps_the_collection() -> void:
	var db := _get_db()
	var p := PlayerProfile.new_game(db, 5)
	p.collection.append("ifv")
	p.deck = PackedStringArray(["tank", "tank", "tank", "tank"])
	assert_true(not p.deck_is_legal(db))
	p.sanitize(db)
	assert_true(p.deck_is_legal(db))
	assert_eq(p.deck.size(), db.deck("starter").card_ids.size())
	assert_true(p.owns("ifv"), "the cards the player earned survive a deck repair")


func test_a_deck_with_cards_the_player_does_not_own_is_illegal() -> void:
	var db := _get_db()
	var p := PlayerProfile.new_game(db, 5)
	var ids := db.deck("starter").ids()
	ids[0] = "ifv"
	p.deck = PackedStringArray(ids)
	assert_true(not p.deck_is_legal(db))
	p.collection.append("ifv")
	assert_true(p.deck_is_legal(db), "the same deck is legal once the card is owned")


func test_sanitize_gives_an_empty_collection_the_starter_cards() -> void:
	var db := _get_db()
	var p := PlayerProfile.from_dict({"version": 1})
	p.sanitize(db)
	assert_true(p.owns("rifle_squad"))
	assert_true(p.deck_is_legal(db))


func test_a_doctrine_must_be_a_doctrine_card_and_owned() -> void:
	var db := _get_db()
	var p := PlayerProfile.new_game(db, 5)
	p.doctrines = PackedStringArray(["hollow_points", "tank"])
	p.collection.append("tank")
	p.sanitize(db)
	assert_eq(p.doctrines.size(), 0, "hollow_points is not owned yet and a tank is not a doctrine")
	p.collection.append("hollow_points")
	p.doctrines = PackedStringArray(["hollow_points"])
	p.sanitize(db)
	assert_eq(Array(p.doctrines), ["hollow_points"])


# --- the file ----------------------------------------------------------------------------------------------------

func test_a_profile_survives_a_save_and_load() -> void:
	_clean()
	var db := _get_db()
	var p := PlayerProfile.new_game(db, 4242)
	p.record_win("m1_hold_the_crossing", 0.75, "normal", 1.0)
	p.open_reward("m1_hold_the_crossing")
	p.take_reward("m1_hold_the_crossing", "ifv")
	assert_true(ProfileStore.save(p, PATH))
	var r := ProfileStore.load_from(db, PATH)
	assert_eq(r.status, ProfileStore.Status.OK)
	assert_eq(r.profile.reward_seed, 4242)
	assert_true(r.profile.owns("ifv"))
	assert_eq(r.profile.wins_of("m1_hold_the_crossing"), 1)
	assert_eq(r.repaired, 0)
	assert_true(not _names().has("profile.json.tmp"), "no temporary file is left behind")
	_clean()


func test_a_missing_file_gives_a_new_profile() -> void:
	_clean()
	var r := ProfileStore.load_from(_get_db(), PATH, 99)
	assert_eq(r.status, ProfileStore.Status.NEW)
	assert_eq(r.profile.reward_seed, 99)
	assert_true(r.profile.deck_is_legal(_get_db()))
	assert_eq(ProfileStore.note_for(r), "")
	var r2 := ProfileStore.load_from(_get_db(), PATH)
	assert_true(r2.profile.reward_seed > 0, "a new profile draws its own seed")
	_clean()


func test_a_second_save_keeps_the_first_as_the_backup() -> void:
	_clean()
	var db := _get_db()
	var p := PlayerProfile.new_game(db, 1)
	assert_true(ProfileStore.save(p, PATH))
	assert_true(not FileAccess.file_exists(ProfileStore.backup_path(PATH)), "nothing to back up on the first save")
	p.record_win("m1_hold_the_crossing", 0.5, "normal", 1.0)
	assert_true(ProfileStore.save(p, PATH))
	assert_true(FileAccess.file_exists(ProfileStore.backup_path(PATH)))
	var bak := ProfileStore.load_from(db, ProfileStore.backup_path(PATH))
	assert_eq(bak.profile.wins_of("m1_hold_the_crossing"), 0, "the backup is the file as it was before the last save")
	_clean()


func test_a_damaged_file_falls_back_to_the_backup_and_is_kept() -> void:
	_clean()
	var db := _get_db()
	var p := PlayerProfile.new_game(db, 31)
	p.record_win("m1_hold_the_crossing", 0.5, "normal", 1.0)
	ProfileStore.save(p, PATH)
	p.record_win("m2_card_defense", 0.5, "normal", 1.0)
	ProfileStore.save(p, PATH)  # the backup now holds the m1 win only
	_write(PATH, "{ this is not json ]]")
	var r := ProfileStore.load_from(db, PATH)
	assert_eq(r.status, ProfileStore.Status.RECOVERED)
	assert_eq(r.profile.wins_of("m1_hold_the_crossing"), 1)
	assert_true(not r.kept_as.is_empty() and FileAccess.file_exists(r.kept_as), "the damaged file was set aside, not deleted")
	assert_true(ProfileStore.note_for(r).contains("backup"))
	_clean()


func test_a_damaged_file_without_a_backup_starts_a_new_profile_and_keeps_the_old_file() -> void:
	_clean()
	_write(PATH, "garbage")
	var r := ProfileStore.load_from(_get_db(), PATH, 5)
	assert_eq(r.status, ProfileStore.Status.DAMAGED)
	assert_eq(r.profile.reward_seed, 5)
	assert_true(FileAccess.file_exists(r.kept_as))
	assert_eq(FileAccess.get_file_as_string(r.kept_as), "garbage")
	assert_true(ProfileStore.note_for(r).contains("new profile"))
	_clean()


func test_json_that_is_not_an_object_counts_as_damaged() -> void:
	_clean()
	_write(PATH, "[1, 2, 3]")
	assert_eq(ProfileStore.load_from(_get_db(), PATH, 5).status, ProfileStore.Status.DAMAGED)
	_clean()
	_write(PATH, "")
	assert_eq(ProfileStore.load_from(_get_db(), PATH, 5).status, ProfileStore.Status.DAMAGED)
	_clean()


func test_a_damaged_file_never_replaces_a_good_backup() -> void:
	_clean()
	var db := _get_db()
	var p := PlayerProfile.new_game(db, 31)
	p.record_win("m1_hold_the_crossing", 0.5, "normal", 1.0)
	ProfileStore.save(p, PATH)
	ProfileStore.save(p, PATH)  # a good backup exists
	var good_backup := FileAccess.get_file_as_string(ProfileStore.backup_path(PATH))
	_write(PATH, "{ broken")
	assert_true(ProfileStore.save(p, PATH))
	assert_eq(FileAccess.get_file_as_string(ProfileStore.backup_path(PATH)), good_backup)
	_clean()


func test_a_file_without_a_version_is_migrated_and_the_old_file_is_kept() -> void:
	_clean()
	var db := _get_db()
	_write(PATH, JSON.stringify({"reward_seed": 8, "collection": ["tank"], "missions": {"m1_hold_the_crossing": {"wins": 2}}}))
	var r := ProfileStore.load_from(db, PATH)
	assert_eq(r.status, ProfileStore.Status.MIGRATED)
	assert_eq(r.profile.version, PlayerProfile.CURRENT_VERSION)
	assert_eq(r.profile.wins_of("m1_hold_the_crossing"), 2)
	assert_true(r.profile.deck_is_legal(db), "missing fields were filled in")
	assert_true(_names().has("profile.v0.bak"), "the pre-migration file was copied aside")
	_clean()


func test_a_file_from_a_newer_game_is_read_only_and_never_written() -> void:
	_clean()
	var db := _get_db()
	var text := JSON.stringify({"version": 99, "reward_seed": 3, "collection": ["tank", "future_card"], "new_field": {"a": 1}})
	_write(PATH, text)
	var r := ProfileStore.load_from(db, PATH)
	assert_eq(r.status, ProfileStore.Status.FUTURE)
	assert_true(r.profile.read_only)
	assert_true(r.profile.owns("tank"))
	assert_true(not ProfileStore.save(r.profile, PATH), "a read-only profile is not written")
	assert_eq(FileAccess.get_file_as_string(PATH), text, "the newer file is untouched")
	assert_true(ProfileStore.note_for(r).contains("newer"))
	_clean()


func test_unknown_content_in_a_saved_profile_is_repaired_on_load() -> void:
	_clean()
	var db := _get_db()
	var p := PlayerProfile.new_game(db, 31)
	p.collection.append("laser_cat")
	p.missions["x99_gone"] = {"wins": 1}
	ProfileStore.save(p, PATH)
	var r := ProfileStore.load_from(db, PATH)
	assert_eq(r.status, ProfileStore.Status.OK)
	assert_true(r.repaired >= 2)
	assert_true(not r.profile.owns("laser_cat") and not r.profile.missions.has("x99_gone"))
	_clean()


# --- the version steps ------------------------------------------------------------------------------------------

var _log: Array[String] = []


func _step_a(d: Dictionary) -> Dictionary:
	_log.append("0to1")
	d["a"] = 1
	return d


func _step_b(d: Dictionary) -> Dictionary:
	_log.append("1to2")
	d["b"] = int(d["a"]) + 1
	return d


func test_steps_run_in_order_and_stamp_each_version() -> void:
	_log.clear()
	var steps: Array[Callable] = [_step_a, _step_b]
	var out := ProfileMigration.upgrade({"version": 0}, 2, steps)
	assert_eq(_log, ["0to1", "1to2"])
	assert_eq(out.to_version, 2)
	assert_eq(out.data["version"], 2)
	assert_eq(out.data["b"], 2)
	assert_true(out.migrated())
	var again := ProfileMigration.upgrade(out.data, 2, steps)
	assert_true(not again.migrated(), "a current file is left alone")
	assert_eq(_log.size(), 2)


func test_a_gap_in_the_chain_stops_at_the_last_version_reached() -> void:
	var steps: Array[Callable] = [_step_a]
	var out := ProfileMigration.upgrade({"version": 0}, 3, steps)
	assert_eq(out.to_version, 1)
	assert_eq(out.data["version"], 1)


func test_a_newer_file_comes_back_untouched() -> void:
	var src := {"version": 7, "x": [1, 2]}
	var out := ProfileMigration.upgrade(src, 2)
	assert_true(out.too_new and not out.migrated())
	assert_eq(out.data, src)
	assert_eq(ProfileMigration.version_of({"version": "two"}), 0)
	assert_eq(ProfileMigration.version_of({"version": 2.0}), 2)
	assert_eq(ProfileMigration.version_of({"version": -4}), 0)


func test_the_session_hands_out_one_shared_profile() -> void:
	var p := PlayerProfile.new_game(_get_db(), 3)
	GameSession.set_profile(p)
	assert_true(GameSession.profile() == p)
	GameSession.set_profile(null)
