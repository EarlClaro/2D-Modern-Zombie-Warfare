extends TestCase


func _rules() -> DeckRules:
	var r := DeckRules.new()
	r.id = "default"
	return r


func _ids(n: int) -> Array[String]:
	var out: Array[String] = []
	for i in n:
		out.append("c%02d" % i)
	return out


func _deck(n: int = 15, seed_value: int = 1, rules: DeckRules = null) -> DeckState:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var d := DeckState.new(rules if rules != null else _rules(), _ids(n), rng)
	d.start()
	return d


func test_start_draws_initial_hand_from_a_shuffled_deck() -> void:
	var d := _deck(15)
	assert_eq(d.hand.size(), 4)
	assert_eq(d.draw_pile.size(), 11)
	assert_eq(d.discard.size(), 0)
	assert_eq(d.total_cards(), 15)


func test_same_seed_same_draw_order_different_seed_differs() -> void:
	var a := _deck(15, 42)
	var b := _deck(15, 42)
	var c := _deck(15, 43)
	assert_eq(a.hand, b.hand)
	assert_eq(a.draw_pile, b.draw_pile)
	assert_true(a.draw_pile != c.draw_pile or a.hand != c.hand, "a different seed gives a different order")


func test_the_shuffle_does_not_use_the_global_rng() -> void:
	seed(1)
	var a := _deck(15, 7)
	seed(999)
	var b := _deck(15, 7)
	assert_eq(a.hand, b.hand, "only the injected rng matters")


func test_shuffle_keeps_every_card_exactly_once() -> void:
	var d := _deck(15, 5)
	var all: Array[String] = []
	all.append_array(d.hand)
	all.append_array(d.draw_pile)
	all.sort()
	assert_eq(all, _ids(15))


func test_periodic_draw_every_interval_while_below_cap() -> void:
	var d := _deck(15)
	d.tick(3.9)
	assert_eq(d.hand.size(), 4, "not yet")
	d.tick(0.1)
	assert_eq(d.hand.size(), 5, "one card at 4 s")


func test_draw_stops_at_cap_and_timer_pauses() -> void:
	var d := _deck(15)
	d.tick(4.0)
	assert_eq(d.hand.size(), 5)
	d.tick(100.0)
	assert_eq(d.hand.size(), 5, "never above the cap")
	assert_eq(d.draw_pile.size(), 10)
	assert_near(d.draw_timer, 0.0, 1e-9, "no time banked while full")
	# Playing a card restarts the wait from where it paused, not from a stockpile.
	d.play_from_hand(0)
	d.tick(3.9)
	assert_eq(d.hand.size(), 4)
	d.tick(0.1)
	assert_eq(d.hand.size(), 5)


func test_timer_resumes_from_its_paused_value() -> void:
	var d := _deck(15)
	d.tick(4.0)  # draws, hand full, timer at 0
	d.play_from_hand(0)
	d.tick(1.0)  # 1 s into the next wait
	d.draw_one()  # hand back to full by other means
	d.tick(50.0)
	assert_near(d.draw_timer, 1.0, 1e-9, "paused at 1 s")
	d.play_from_hand(0)
	d.tick(2.9)
	assert_eq(d.hand.size(), 4)
	d.tick(0.1)
	assert_eq(d.hand.size(), 5, "3 s remaining after resume, so 4 s total")


func test_a_long_hitch_draws_several_cards_but_never_past_the_cap() -> void:
	var rules := _rules()
	rules.initial_hand = 0
	var d := _deck(15, 1, rules)
	d.tick(100.0)
	assert_eq(d.hand.size(), 5)


func test_playing_moves_card_to_discard_and_shifts_the_hand() -> void:
	var d := _deck(15)
	var before := d.hand.duplicate()
	var cid := d.play_from_hand(1)
	assert_eq(cid, before[1])
	assert_eq(d.discard, [before[1]] as Array[String])
	assert_eq(d.hand, [before[0], before[2], before[3]] as Array[String])
	assert_eq(d.total_cards(), 15, "no card is ever created or lost")


func test_playing_an_empty_or_out_of_range_slot_changes_nothing() -> void:
	var d := _deck(15)
	var hand := d.hand.duplicate()
	assert_eq(d.play_from_hand(4), "")
	assert_eq(d.play_from_hand(-1), "")
	assert_eq(d.play_from_hand(99), "")
	assert_eq(d.hand, hand)
	assert_eq(d.discard.size(), 0)


func test_reshuffle_when_draw_pile_runs_out() -> void:
	var rules := _rules()
	rules.hand_cap = 5
	var d := _deck(6, 3, rules)  # hand 4, draw pile 2
	d.play_from_hand(0)
	d.play_from_hand(0)
	assert_eq(d.discard.size(), 2)
	d.draw_one()
	d.draw_one()
	assert_eq(d.draw_pile.size(), 0)
	assert_eq(d.hand.size(), 4)
	assert_true(d.draw_one(), "empty draw pile pulls from a reshuffled discard")
	assert_eq(d.discard.size(), 0)
	assert_eq(d.draw_pile.size(), 1)
	assert_eq(d.total_cards(), 6)


func test_reshuffle_actually_shuffles_the_discard() -> void:
	# Without a shuffle the discard would come back in exactly the order it was played.
	var rules := _rules()
	rules.hand_cap = 15
	rules.initial_hand = 15
	var d := _deck(15, 5, rules)
	var played: Array[String] = []
	for i in 15:
		played.append(d.play_from_hand(0))
	assert_eq(d.hand.size(), 0)
	assert_eq(d.draw_pile.size(), 0)
	var redrawn: Array[String] = []
	for i in 15:
		assert_true(d.draw_one())
		redrawn.append(d.hand.back())
	var unshuffled := played.duplicate()
	unshuffled.reverse()  # cards are drawn from the end of the pile
	assert_true(redrawn != unshuffled, "reshuffled order differs from play order")
	var sorted_back := redrawn.duplicate()
	sorted_back.sort()
	assert_eq(sorted_back, _ids(15), "and it is a permutation of the same cards")


func test_reshuffle_is_deterministic_for_a_seed() -> void:
	var out: Array = []
	for run in 2:
		var d := _deck(6, 11)
		for i in 4:
			d.play_from_hand(0)
		var seq: Array[String] = []
		for i in 4:
			d.draw_one()
		for i in 6:
			if d.draw_one():
				seq.append(d.hand.back())
			else:
				d.play_from_hand(0)
		out.append(seq)
	assert_eq(out[0], out[1])


func test_no_draw_when_everything_is_empty() -> void:
	var rules := _rules()
	var d := _deck(3, 1, rules)  # deck smaller than the hand: all 3 in hand
	assert_eq(d.hand.size(), 3)
	assert_true(not d.draw_one(), "nothing left to draw")
	d.tick(60.0)
	assert_eq(d.hand.size(), 3)
	assert_eq(d.total_cards(), 3)
	# A card played afterwards becomes drawable again immediately (timer is ready, not banked beyond that).
	d.play_from_hand(0)
	d.tick(0.01)
	assert_eq(d.hand.size(), 3, "the played card is reshuffled back in")


func test_empty_deck_is_harmless() -> void:
	var d := _deck(0)
	assert_eq(d.hand.size(), 0)
	d.tick(30.0)
	assert_true(not d.draw_one())
	assert_eq(d.play_from_hand(0), "")


func test_lockout_counts_down_and_expires() -> void:
	var d := _deck(15)
	d.start_lockout("c01", 2.0)
	assert_true(d.is_locked("c01"))
	assert_near(d.lockout_remaining("c01"), 2.0)
	d.tick(1.5)
	assert_near(d.lockout_remaining("c01"), 0.5, 1e-9)
	d.tick(0.5)
	assert_true(not d.is_locked("c01"))
	assert_near(d.lockout_remaining("c01"), 0.0)


func test_zero_lockout_does_not_lock() -> void:
	var d := _deck(15)
	d.start_lockout("c01", 0.0)
	assert_true(not d.is_locked("c01"))


func test_start_resets_a_previous_battle() -> void:
	var d := _deck(15)
	d.tick(4.0)
	d.play_from_hand(0)
	d.start_lockout("c01", 9.0)
	d.start()
	assert_eq(d.hand.size(), 4)
	assert_eq(d.discard.size(), 0)
	assert_true(not d.is_locked("c01"))
	assert_eq(d.total_cards(), 15)
