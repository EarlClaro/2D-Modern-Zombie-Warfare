extends TestCase
## The reward after a first win (docs/specs/progression.md, increment 5.3): the picker, the saved offer, claiming a card,
## the pools in the campaign data and the screens that show the choice.

const DIR: String = "user://test_rewards"
const PATH: String = "user://test_rewards/profile.json"

var _db: ContentDb


func _get_db() -> ContentDb:
	if _db == null:
		_db = ContentDb.load_from()
	return _db


func _fresh(seed_value: int = 11) -> PlayerProfile:
	return PlayerProfile.new_game(_get_db(), seed_value)


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


func _use_temp_profile(p: PlayerProfile) -> void:
	_clean()
	GameSession.profile_path = PATH
	GameSession.set_profile(p)


func _release_temp_profile() -> void:
	GameSession.profile_path = ProfileStore.PATH
	GameSession.set_profile(null)
	_clean()


# --- the picker --------------------------------------------------------------------------------------------------

func test_the_offer_is_three_distinct_cards_from_the_pool() -> void:
	var pool := PackedStringArray(["a", "b", "c", "d", "e"])
	var o := RewardPicker.offer(pool, PackedStringArray(), 5, "m1")
	assert_eq(o.size(), 3)
	for cid in o:
		assert_true(pool.has(cid))
	assert_eq(Dictionary({o[0]: 1, o[1]: 1, o[2]: 1}).size(), 3, "no card twice")


func test_the_same_seed_and_mission_give_the_same_offer() -> void:
	var pool := PackedStringArray(["a", "b", "c", "d", "e", "f"])
	var one := RewardPicker.offer(pool, PackedStringArray(), 99, "m2")
	var two := RewardPicker.offer(pool, PackedStringArray(), 99, "m2")
	assert_eq(Array(one), Array(two))
	var differs := false
	for s in range(100, 140):
		differs = differs or Array(RewardPicker.offer(pool, PackedStringArray(), s, "m2")) != Array(one)
	assert_true(differs, "another profile seed gives another offer")
	var other_mission := false
	for m in ["m3", "x1", "x2", "x3", "x4"]:
		other_mission = other_mission or Array(RewardPicker.offer(pool, PackedStringArray(), 99, m)) != Array(one)
	assert_true(other_mission, "another mission gives another offer")


func test_cards_already_owned_are_never_offered() -> void:
	var pool := PackedStringArray(["a", "b", "c", "d"])
	var o := RewardPicker.offer(pool, PackedStringArray(["a", "b"]), 3, "m1")
	assert_eq(o.size(), 2)
	assert_true(not o.has("a") and not o.has("b"))
	assert_eq(RewardPicker.offer(pool, PackedStringArray(["a", "b", "c", "d"]), 3, "m1").size(), 0)
	assert_eq(RewardPicker.offer(PackedStringArray(), PackedStringArray(), 3, "m1").size(), 0)
	assert_eq(RewardPicker.offer(PackedStringArray(["a", "a", "b"]), PackedStringArray(), 3, "m1").size(), 2, "a repeated pool entry counts once")


# --- the pools in the data -----------------------------------------------------------------------------------------

func test_every_pool_card_exists_and_none_is_a_starter_card() -> void:
	var db := _get_db()
	assert_true(db.is_valid(), "content errors: %s" % ", ".join(db.errors))
	var camp := db.main_campaign()
	var starter := db.deck(PlayerProfile.STARTER_DECK).ids()
	for mid in camp.reward_pools:
		assert_true(db.mission(mid) != null, "%s is a mission" % mid)
		for cid in camp.pool_of(mid):
			assert_true(db.card(cid) != null or db.upgrade(cid) != null, "%s exists" % cid)
			assert_true(not starter.has(cid), "%s is a starter card, there is nothing to win" % cid)
		assert_true(camp.pool_of(mid).size() >= 3, "%s offers a real choice" % mid)


func test_every_card_the_player_does_not_start_with_can_be_won_somewhere() -> void:
	var db := _get_db()
	var camp := db.main_campaign()
	var starter := db.deck(PlayerProfile.STARTER_DECK).ids()
	var reachable: Dictionary = {}
	for mid in camp.reward_pools:
		for cid in camp.pool_of(mid):
			reachable[cid] = true
	for cid: String in db.cards:
		assert_true(starter.has(cid) or reachable.has(cid), "%s can be won" % cid)


func test_the_heaviest_strikes_come_last() -> void:
	var camp := _get_db().main_campaign()
	for cid in ["nuclear_bomb", "satellite_laser"]:
		for mid in camp.reward_pools:
			if camp.pool_of(mid).has(cid):
				assert_true(camp.index_of(mid) >= camp.mission_ids.size() - 2, "%s is offered by %s" % [cid, mid])
	assert_true(camp.pool_of("m1_hold_the_crossing").size() > 0 and not camp.pool_of("m1_hold_the_crossing").has("nuclear_bomb"))


func test_a_bad_pool_is_reported() -> void:
	var c := CampaignDefinition.new()
	c.id = "main"
	c.display_name = "Main"
	c.mission_ids = PackedStringArray(["a"])
	c.reward_pools = {"b": PackedStringArray(["x"]), "a": PackedStringArray()}
	assert_true(c.validate().size() >= 2, "a pool for a mission outside the chain and an empty pool")
	c.reward_pools = {"a": PackedStringArray(["x", "x"])}
	assert_true(c.validate().size() == 1, "a card twice in one pool")
	var db := ContentDb.new()
	var ok := CampaignDefinition.new()
	ok.id = "main"
	ok.display_name = "Main"
	ok.mission_ids = PackedStringArray(["a"])
	ok.reward_pools = {"a": PackedStringArray(["no_such_card"])}
	db.add_campaign(ok)
	db.validate_references()
	var found := false
	for e in db.errors:
		found = found or e.contains("unknown card 'no_such_card'")
	assert_true(found)


# --- the profile --------------------------------------------------------------------------------------------------

func test_a_saved_offer_limits_what_can_be_taken() -> void:
	var p := _fresh()
	p.open_reward("m1_hold_the_crossing", PackedStringArray(["ifv", "rpg_team", "sandbags"]))
	assert_true(p.has_pending_reward("m1_hold_the_crossing"))
	assert_true(not p.take_reward("m1_hold_the_crossing", "tank"), "not on the offer")
	assert_true(not p.owns("ifv"))
	assert_true(p.take_reward("m1_hold_the_crossing", "ifv"))
	assert_true(p.owns("ifv"))
	assert_true(not p.has_pending_reward("m1_hold_the_crossing"))
	assert_eq(p.offer_of("m1_hold_the_crossing").size(), 0, "the offer is gone once answered")
	assert_true(not p.take_reward("m1_hold_the_crossing", "rpg_team"), "a reward is taken once")
	assert_true(not p.owns("rpg_team"))


func test_a_waiting_offer_survives_the_dictionary_round_trip_and_stale_cards_are_dropped() -> void:
	var db := _get_db()
	var p := _fresh()
	p.open_reward("m1_hold_the_crossing", PackedStringArray(["ifv", "rpg_team", "sandbags"]))
	var q := PlayerProfile.from_dict(JSON.parse_string(JSON.stringify(p.to_dict())))
	assert_eq(Array(q.offer_of("m1_hold_the_crossing")), ["ifv", "rpg_team", "sandbags"])
	q.collection.append("rpg_team")  # won some other way meanwhile
	q.sanitize(db)
	assert_eq(Array(q.offer_of("m1_hold_the_crossing")), ["ifv", "sandbags"])
	q.offers["x99_gone"] = PackedStringArray(["tank"])
	q.rewards["x99_gone"] = ""
	q.sanitize(db)
	assert_true(not q.offers.has("x99_gone"))


# --- earning a reward --------------------------------------------------------------------------------------------

func test_a_first_win_opens_an_offer_and_a_replay_does_not() -> void:
	var db := _get_db()
	var p := _fresh()
	var r := ProgressRecorder.record(p, db, "m1_hold_the_crossing", 0.9, "normal", 1.0)
	var offer: PackedStringArray = r["offer"]
	assert_eq(offer.size(), 3)
	assert_true(p.has_pending_reward("m1_hold_the_crossing"))
	assert_eq(Array(p.offer_of("m1_hold_the_crossing")), Array(offer))
	var again := ProgressRecorder.record(p, db, "m1_hold_the_crossing", 0.9, "normal", 1.0)
	assert_eq((again["offer"] as PackedStringArray).size(), 0)
	assert_eq(Array(p.offer_of("m1_hold_the_crossing")), Array(offer), "the waiting offer is not re-rolled")


func test_a_mission_without_a_pool_gives_no_reward() -> void:
	var p := _fresh()
	var r := ProgressRecorder.record(p, _get_db(), "dev_strike_range", 1.0, "normal", 1.0)
	assert_eq((r["offer"] as PackedStringArray).size(), 0)
	assert_true(not p.rewards.has("dev_strike_range"))


func test_claiming_adds_the_card_and_saves_the_file() -> void:
	var db := _get_db()
	var p := _fresh()
	_use_temp_profile(p)
	var r := ProgressRecorder.record(p, db, "m1_hold_the_crossing", 0.9, "normal", 1.0)
	var pick: String = (r["offer"] as PackedStringArray)[1]
	assert_true(not GameSession.claim_reward(db, "m1_hold_the_crossing", "tank"), "a card that was not offered")
	assert_true(not FileAccess.file_exists(PATH), "nothing was saved by the refusal")
	assert_true(GameSession.claim_reward(db, "m1_hold_the_crossing", pick))
	assert_true(p.holdings().has(pick))
	var back := ProfileStore.load_from(db, PATH)
	assert_true(back.profile.holdings().has(pick), "it was written to disk")
	assert_true(not GameSession.claim_reward(db, "m1_hold_the_crossing", pick), "only once")
	_release_temp_profile()


func test_a_read_only_profile_cannot_claim() -> void:
	var db := _get_db()
	var p := _fresh()
	p.open_reward("m1_hold_the_crossing", PackedStringArray(["ifv"]))
	p.read_only = true
	_use_temp_profile(p)
	assert_true(not GameSession.claim_reward(db, "m1_hold_the_crossing", "ifv"))
	assert_true(not p.owns("ifv"))
	_release_temp_profile()


func test_quitting_before_choosing_keeps_the_same_offer() -> void:
	var db := _get_db()
	var p := _fresh(777)
	ProgressRecorder.record(p, db, "m2_card_defense", 0.5, "normal", 1.0)
	var before := p.offer_of("m2_card_defense")
	_clean()
	assert_true(ProfileStore.save(p, PATH))
	var after := ProfileStore.load_from(db, PATH).profile
	assert_true(after.has_pending_reward("m2_card_defense"))
	assert_eq(Array(after.offer_of("m2_card_defense")), Array(before))
	_clean()


func test_a_profile_from_before_rewards_gets_its_offers_when_loaded() -> void:
	var db := _get_db()
	var p := _fresh(555)
	p.record_win("m1_hold_the_crossing", 1.0, "normal", 1.0)
	p.record_win("dev_strike_range", 1.0, "normal", 1.0)
	_clean()
	ProfileStore.save(p, PATH)
	var loaded := ProfileStore.load_from(db, PATH).profile
	assert_true(loaded.has_pending_reward("m1_hold_the_crossing"))
	assert_eq(loaded.offer_of("m1_hold_the_crossing").size(), 3)
	assert_true(not loaded.rewards.has("dev_strike_range"))
	var again := ProfileStore.load_from(db, PATH).profile
	assert_eq(Array(again.offer_of("m1_hold_the_crossing")), Array(loaded.offer_of("m1_hold_the_crossing")), "same offer every time")
	_clean()


func test_pending_offer_is_worked_out_again_when_none_was_saved() -> void:
	var db := _get_db()
	var p := _fresh(31)
	p.rewards["m1_hold_the_crossing"] = ""  # an entry without saved cards
	_use_temp_profile(p)
	var o := GameSession.pending_offer(db, "m1_hold_the_crossing")
	assert_eq(o.size(), 3)
	assert_eq(Array(GameSession.pending_offer(db, "m1_hold_the_crossing")), Array(o))
	assert_eq(GameSession.pending_offer(db, "m2_card_defense").size(), 0, "no reward is waiting there")
	_release_temp_profile()


# --- the screens -------------------------------------------------------------------------------------------------

func test_the_chooser_shows_each_card_and_claims_the_pressed_one() -> void:
	var db := _get_db()
	var p := _fresh()
	_use_temp_profile(p)
	var offer := PackedStringArray(["ifv", "rpg_team", "sandbags"])
	p.open_reward("m1_hold_the_crossing", offer)
	var ch := RewardChooser.new()
	_in_tree(ch)
	ch.setup(db, "m1_hold_the_crossing", offer)
	var buttons := ch.find_children("Reward_*", "Button", true, false)
	assert_eq(buttons.size(), 3)
	assert_true((buttons[0] as Button).text.contains(db.card("ifv").display_name))
	var got: Array[String] = []
	ch.claimed.connect(func(cid: String) -> void: got.append(cid))
	(ch.find_child("Reward_rpg_team", true, false) as Button).pressed.emit()
	assert_eq(got, ["rpg_team"])
	assert_true(p.owns("rpg_team") and not p.owns("ifv"))
	ch.free()
	_release_temp_profile()


func test_the_offered_cards_start_face_down_and_turn_over_one_by_one() -> void:
	var db := _get_db()
	var p := _fresh()
	_use_temp_profile(p)
	var offer := PackedStringArray(["ifv", "rpg_team", "sandbags"])
	p.open_reward("m1_hold_the_crossing", offer)
	var ch := RewardChooser.new()
	_in_tree(ch)
	ch.setup(db, "m1_hold_the_crossing", offer)
	var flips := ch.find_children("Flip_*", "TextureRect", true, false)
	assert_eq(flips.size(), 3, "one picture slot per offered card")
	for f in flips:
		assert_true((f as TextureRect).texture == CardArt.back(), "face-down at first")
	assert_true(not ch.revealed())
	assert_true(ch.reveal_total_s() > 0.5 and ch.reveal_total_s() < 2.0, "the whole reveal takes about a second")
	ch.finish_reveal()
	assert_true(ch.revealed())
	assert_true((ch.find_child("Flip_ifv", true, false) as TextureRect).texture == CardArt.texture("ifv"), "the picture of the card")
	(ch.find_child("Reward_ifv", true, false) as Button).pressed.emit()
	assert_true(p.owns("ifv"), "a card can be taken before or after it has turned over")
	ch.free()
	_release_temp_profile()


func test_the_result_panel_shows_the_choice_and_then_says_what_was_added() -> void:
	var db := _get_db()
	var p := _fresh()
	_use_temp_profile(p)
	var offer := PackedStringArray(["ifv", "rpg_team", "sandbags"])
	p.open_reward("m1_hold_the_crossing", offer)
	var panel := ResultPanel.new()
	_in_tree(panel)
	panel.show_offer(db, "m1_hold_the_crossing", offer)
	var chooser: Node = panel.find_children("*", "RewardChooser", true, false)[0]
	(chooser.find_child("Reward_ifv", true, false) as Button).pressed.emit()
	assert_true(p.owns("ifv"))
	var shown := false
	for l in panel.find_children("*", "Label", true, false):
		shown = shown or ((l as Label).visible and (l as Label).text.begins_with("Added "))
	assert_true(shown, "the panel says the card was added")
	panel.free()
	_release_temp_profile()


func test_mission_select_shows_a_reward_that_is_still_waiting() -> void:
	var db := _get_db()
	var p := _fresh()
	p.record_win("m1_hold_the_crossing", 1.0, "normal", 1.0)
	p.open_reward("m1_hold_the_crossing", PackedStringArray(["ifv", "rpg_team", "sandbags"]))
	_use_temp_profile(p)
	GameSession.set_settings(GameSettings.new())
	var sel := MissionSelect.new()
	sel.bind(db)
	_in_tree(sel)
	var list: ItemList = sel.find_children("*", "ItemList", true, false)[0]
	var first_row := -1
	for i in list.item_count:
		if list.get_item_text(i).begins_with(db.mission("m1_hold_the_crossing").display_name + "   ["):
			first_row = i
	assert_true(first_row >= 0 and list.get_item_text(first_row).ends_with("[reward waiting]"), list.get_item_text(first_row))
	list.select(first_row)
	list.item_selected.emit(first_row)
	assert_true(sel.find_child("Reward_ifv", true, false) != null, "the three cards are shown under the facts")
	(sel.find_child("Reward_sandbags", true, false) as Button).pressed.emit()
	assert_true(p.owns("sandbags"))
	assert_true(not list.get_item_text(first_row).contains("reward waiting"), "the mark is gone")
	sel.free()
	GameSession.set_settings(GameSettings.new())
	_release_temp_profile()
