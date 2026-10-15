extends TestCase

const R := CardPlayService.Reason


func _cards() -> Dictionary:
	var cheap := CardDefinition.new()
	cheap.id = "cheap"
	cheap.display_name = "Cheap"
	cheap.cost = 2
	cheap.unit_id = "u"
	var heavy := CardDefinition.new()
	heavy.id = "heavy"
	heavy.display_name = "Heavy"
	heavy.cost = 6
	heavy.lockout_s = 20.0
	heavy.unit_id = "u"
	return {"cheap": cheap, "heavy": heavy}


## A deck whose hand is exactly `hand_ids` (rest of the deck: filler).
func _setup(hand_ids: Array[String], cp: float = 5.0) -> Array:
	var rules := DeckRules.new()
	rules.id = "default"
	rules.initial_hand = 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var deck := DeckState.new(rules, hand_ids, rng)
	deck.start()
	for i in hand_ids.size():
		deck.draw_one()
	return [deck, CommandPoints.new(cp, 10.0, 1.0)]


func _snapshot(deck: DeckState, pts: CommandPoints) -> Array:
	return [deck.hand.duplicate(), deck.discard.duplicate(), deck.draw_pile.duplicate(), deck.lockouts.duplicate(), pts.cp]


func test_valid_play_spends_cp_discards_card_and_locks_out() -> void:
	var s := _setup(["heavy", "cheap"] as Array[String], 8.0)
	var deck: DeckState = s[0]
	var pts: CommandPoints = s[1]
	var res := CardPlayService.try_play(deck, pts, _cards(), deck.hand.find("heavy"))
	assert_true(res.ok)
	assert_eq(res.reason, R.OK)
	assert_eq(res.card.id, "heavy")
	assert_near(pts.cp, 2.0, 1e-9)
	assert_eq(deck.discard, ["heavy"] as Array[String])
	assert_true(deck.is_locked("heavy"))
	assert_eq(deck.hand, ["cheap"] as Array[String])


func test_insufficient_cp_leaves_everything_unchanged() -> void:
	var s := _setup(["heavy"] as Array[String], 5.0)
	var before := _snapshot(s[0], s[1])
	var res := CardPlayService.try_play(s[0], s[1], _cards(), 0)
	assert_true(not res.ok)
	assert_eq(res.reason, R.INSUFFICIENT_CP)
	assert_eq(res.card.id, "heavy", "card is reported so the UI can say which one")
	assert_eq(_snapshot(s[0], s[1]), before)


func test_exact_cost_is_playable() -> void:
	var s := _setup(["cheap"] as Array[String], 2.0)
	assert_true(CardPlayService.try_play(s[0], s[1], _cards(), 0).ok)
	assert_near((s[1] as CommandPoints).cp, 0.0, 1e-9)


func test_empty_slot_is_ignored() -> void:
	var s := _setup(["cheap"] as Array[String])
	var before := _snapshot(s[0], s[1])
	for idx in [1, 4, -1, 99]:
		var res := CardPlayService.try_play(s[0], s[1], _cards(), idx)
		assert_eq(res.reason, R.EMPTY_SLOT)
		assert_true(res.card == null)
	assert_eq(_snapshot(s[0], s[1]), before)


func test_unknown_card_id_is_an_error_result_not_a_crash() -> void:
	var s := _setup(["ghost"] as Array[String])
	var before := _snapshot(s[0], s[1])
	var res := CardPlayService.try_play(s[0], s[1], _cards(), 0)
	assert_eq(res.reason, R.UNKNOWN_CARD)
	assert_eq(_snapshot(s[0], s[1]), before)


func test_locked_out_copy_cannot_be_played_even_with_cp_then_can_after_expiry() -> void:
	var s := _setup(["heavy", "heavy"] as Array[String], 10.0)
	var deck: DeckState = s[0]
	var pts: CommandPoints = s[1]
	assert_true(CardPlayService.try_play(deck, pts, _cards(), 0).ok)
	pts.cp = 10.0
	var before := _snapshot(deck, pts)
	var res := CardPlayService.try_play(deck, pts, _cards(), 0)
	assert_eq(res.reason, R.LOCKED_OUT)
	assert_eq(_snapshot(deck, pts), before, "second copy untouched while locked")
	deck.tick(19.9)
	assert_eq(CardPlayService.check(deck, pts, _cards(), 0).reason, R.LOCKED_OUT)
	deck.tick(0.1)
	assert_true(CardPlayService.try_play(deck, pts, _cards(), 0).ok)


func test_lockout_does_not_block_other_cards() -> void:
	var s := _setup(["heavy", "cheap"] as Array[String], 10.0)
	var deck: DeckState = s[0]
	CardPlayService.try_play(deck, s[1], _cards(), deck.hand.find("heavy"))
	assert_true(CardPlayService.try_play(deck, s[1], _cards(), 0).ok, "cheap is still playable")


func test_invalid_target_leaves_card_in_hand_and_cp_unspent() -> void:
	var s := _setup(["cheap"] as Array[String])
	var before := _snapshot(s[0], s[1])
	var res := CardPlayService.try_play(s[0], s[1], _cards(), 0, false)
	assert_eq(res.reason, R.INVALID_TARGET)
	assert_eq(_snapshot(s[0], s[1]), before)
	assert_true(CardPlayService.try_play(s[0], s[1], _cards(), 0, true).ok, "same card plays once the target is valid")


func test_reason_priority_slot_then_lockout_then_cp_then_target() -> void:
	var s := _setup(["heavy", "heavy"] as Array[String], 0.0)
	var deck: DeckState = s[0]
	deck.start_lockout("heavy", 5.0)
	assert_eq(CardPlayService.check(deck, s[1], _cards(), 0, false).reason, R.LOCKED_OUT, "lockout beats cp and target")
	deck.lockouts.clear()
	assert_eq(CardPlayService.check(deck, s[1], _cards(), 0, false).reason, R.INSUFFICIENT_CP, "cp beats target")
	(s[1] as CommandPoints).cp = 10.0
	assert_eq(CardPlayService.check(deck, s[1], _cards(), 0, false).reason, R.INVALID_TARGET)


func test_check_never_mutates() -> void:
	var s := _setup(["cheap"] as Array[String])
	var before := _snapshot(s[0], s[1])
	var res := CardPlayService.check(s[0], s[1], _cards(), 0)
	assert_true(res.ok)
	assert_eq(_snapshot(s[0], s[1]), before)
