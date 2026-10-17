extends TestCase
## The example players used to balance player-deck missions, and the first such mission (docs/specs/progression.md,
## increment 5.6): the samples must be possible for a real player, and the mission must be wired into the campaign.

var _db: ContentDb


func _get_db() -> ContentDb:
	if _db == null:
		_db = ContentDb.load_from()
	return _db


func test_the_samples_play_the_first_nine_missions_of_the_campaign() -> void:
	var camp := _get_db().main_campaign()
	assert_eq(SampleDecks.PICK_MISSIONS.size(), 9)
	for i in SampleDecks.PICK_MISSIONS.size():
		assert_eq(camp.mission_ids[i], SampleDecks.PICK_MISSIONS[i], "pick %d comes from mission %d of the chain" % [i, i])


func test_every_pick_could_really_have_been_offered_by_its_mission() -> void:
	var camp := _get_db().main_campaign()
	for name in SampleDecks.names():
		var picks: Array = SampleDecks.SAMPLES[name]["picks"]
		assert_eq(picks.size(), SampleDecks.PICK_MISSIONS.size(), "%s: one pick per mission" % name)
		var seen: Dictionary = {}
		for i in picks.size():
			var pick: String = picks[i]
			assert_true(camp.pool_of(SampleDecks.PICK_MISSIONS[i]).has(pick), "%s: %s is in the pool of %s" % [name, pick, SampleDecks.PICK_MISSIONS[i]])
			assert_true(not seen.has(pick), "%s: %s picked twice" % [name, pick])
			seen[pick] = true


func test_every_sample_deck_is_legal_for_the_player_who_owns_it() -> void:
	var db := _get_db()
	for name in SampleDecks.names():
		var p := SampleDecks.profile(db, name)
		var ids: Array[String] = []
		ids.assign(p.deck)
		assert_true(p.deck_is_legal(db), "%s: %s" % [name, ", ".join(db.deck_rules.validate_deck(ids, db.cards))])
		var lo := DeckBuilder.loadout(p, db)
		assert_eq(Array(lo["deck"]), Array(p.deck), "%s: the battle gets this deck, not the fallback" % name)
		assert_eq(Array(lo["upgrades"]), Array(p.equipped_ids()))
		for uid in p.equipped_ids():
			assert_true(p.unlocked_upgrades.has(uid))
		for d in p.doctrines:
			assert_true(p.owns(d))


func test_the_samples_get_stronger_in_cards_and_upgrades() -> void:
	var db := _get_db()
	var weak := SampleDecks.profile(db, "weak")
	var strong := SampleDecks.profile(db, "strong")
	assert_eq(weak.equipped_ids().size(), 0)
	assert_eq(strong.equipped_ids().size(), 2)
	assert_true(strong.deck.size() > weak.deck.size())


func test_the_first_player_deck_mission_is_in_the_campaign_after_the_older_missions() -> void:
	var db := _get_db()
	var m := db.mission("x12_open_orders")
	assert_true(m != null)
	assert_eq(m.deck_source, MissionDefinition.DeckSource.PLAYER)
	assert_eq(MissionListing.group_of(m.id), MissionListing.GROUP_MISSIONS)
	var camp := db.main_campaign()
	assert_eq(camp.previous_of("x12_open_orders"), "x6_high_tech")
	assert_eq(camp.previous_of("x7_bridge_line"), "x12_open_orders")
	assert_true(camp.pool_of("x12_open_orders").size() >= 3, "it rewards the first win")
	assert_eq(m.validate().size(), 0)
