extends TestCase
## Selection and preview state (no pixels): CardTargeting, the controller's select/confirm/cancel API,
## the hand layout maths and the player-facing refusal messages.

const DT: float = 1.0 / 60.0
const GOOD := Vector2i(7, 19)
const R := CardPlayService.Reason

var _db: ContentDb
var _made: Array[BattleController] = []


func _get_db() -> ContentDb:
	if _db == null:
		_db = ContentDb.load_from()
	return _db


func _battle(seed_value: int = 1) -> BattleController:
	var b := BattleController.new()
	b.auto_step = false
	b.setup(_get_db(), _get_db().mission("m2_card_defense"), seed_value)
	_made.append(b)
	return b


func _release() -> void:
	for b in _made:
		b.free()
	_made.clear()


func _hand(b: BattleController, ids: Array[String], cp: float = 10.0) -> void:
	b.deck.hand = ids
	b.points.cp = cp


func _deck_with(ids: Array[String]) -> DeckState:
	var rules := DeckRules.new()
	rules.id = "default"
	rules.initial_hand = 0
	var rng := RandomNumberGenerator.new()
	var d := DeckState.new(rules, ids, rng)
	d.start()
	d.hand = ids.duplicate()
	return d


# --- CardTargeting ------------------------------------------------------------------------------------------

func test_starts_with_nothing_selected() -> void:
	var t := CardTargeting.new()
	assert_true(not t.is_selecting())
	assert_eq(t.selected_slot, -1)


func test_select_then_select_again_toggles_off() -> void:
	var d := _deck_with(["a", "b", "c"] as Array[String])
	var t := CardTargeting.new()
	assert_true(t.select(d, 1))
	assert_eq(t.selected_slot, 1)
	assert_true(not t.select(d, 1), "same slot again deselects")
	assert_true(not t.is_selecting())


func test_selecting_another_slot_switches() -> void:
	var d := _deck_with(["a", "b", "c"] as Array[String])
	var t := CardTargeting.new()
	t.select(d, 0)
	assert_true(t.select(d, 2))
	assert_eq(t.selected_slot, 2)


func test_empty_or_out_of_range_slot_changes_nothing() -> void:
	var d := _deck_with(["a", "b"] as Array[String])
	var t := CardTargeting.new()
	assert_true(not t.select(d, 4))
	assert_true(not t.select(d, -1))
	t.select(d, 0)
	assert_true(t.select(d, 4), "an existing selection survives a click on an empty slot")
	assert_eq(t.selected_slot, 0)


func test_cancel_clears() -> void:
	var d := _deck_with(["a"] as Array[String])
	var t := CardTargeting.new()
	t.select(d, 0)
	t.cancel()
	assert_true(not t.is_selecting())
	t.cancel()
	assert_true(not t.is_selecting(), "cancel is idempotent")


func test_sync_drops_a_selection_whose_card_left_the_slot() -> void:
	var d := _deck_with(["a", "b", "c"] as Array[String])
	var t := CardTargeting.new()
	t.select(d, 1)
	t.sync(d)
	assert_eq(t.selected_slot, 1, "unchanged hand keeps the selection")
	d.play_from_hand(0)  # hand shifts: slot 1 now holds a different card
	t.sync(d)
	assert_true(not t.is_selecting())


func test_sync_drops_a_selection_when_the_slot_becomes_empty() -> void:
	var d := _deck_with(["a", "b"] as Array[String])
	var t := CardTargeting.new()
	t.select(d, 1)
	d.play_from_hand(1)
	t.sync(d)
	assert_true(not t.is_selecting())


# --- messages ---------------------------------------------------------------------------------------------

func test_every_refusal_has_a_distinct_readable_message() -> void:
	var card := CardDefinition.new()
	card.id = "tank"
	card.cost = 6
	var d := _deck_with(["tank"] as Array[String])
	d.start_lockout("tank", 12.2)
	var seen: Dictionary = {}
	for reason in [R.EMPTY_SLOT, R.UNKNOWN_CARD, R.LOCKED_OUT, R.INSUFFICIENT_CP, R.INVALID_TARGET, R.UNAVAILABLE]:
		var res := CardPlayService.Result.new(reason, card)
		res.placement = PlacementRules.Reason.TOO_FAR_FROM_CORE
		var msg := CardTargeting.message_for(res, d)
		assert_true(msg.length() > 0, "message for %s" % str(reason))
		seen[msg] = true
	assert_eq(seen.size(), 6, "no two reasons share a message")
	assert_eq(CardTargeting.message_for(CardPlayService.Result.new(R.OK, card), d), "")


func test_message_details() -> void:
	var card := CardDefinition.new()
	card.id = "tank"
	card.cost = 6
	var d := _deck_with(["tank"] as Array[String])
	d.start_lockout("tank", 12.2)
	assert_eq(CardTargeting.message_for(CardPlayService.Result.new(R.INSUFFICIENT_CP, card), d), "Need 6 CP")
	assert_eq(CardTargeting.message_for(CardPlayService.Result.new(R.LOCKED_OUT, card), d), "Locked out (13s)", "seconds round up")
	var bad := CardPlayService.Result.new(R.INVALID_TARGET, card)
	bad.placement = PlacementRules.Reason.NOT_BUILDABLE
	assert_eq(CardTargeting.message_for(bad, d), PlacementRules.describe(PlacementRules.Reason.NOT_BUILDABLE))


# --- controller API ----------------------------------------------------------------------------------------

func test_select_slot_and_cancel_on_the_controller() -> void:
	var b := _battle()
	assert_true(not b.targeting.is_selecting())
	b.select_slot(2)
	assert_eq(b.targeting.selected_slot, 2)
	b.cancel_selection()
	assert_true(not b.targeting.is_selecting())
	_release()


func test_successful_confirm_plays_the_card_and_clears_the_selection() -> void:
	var b := _battle()
	_hand(b, ["rifle_squad", "tank"] as Array[String], 5.0)
	b.select_slot(0)
	var res := b.confirm_at(GOOD)
	assert_true(res.ok)
	assert_true(not b.targeting.is_selecting())
	assert_eq(b.units.size(), 3)
	_release()


func test_refused_confirm_keeps_the_selection_and_reports() -> void:
	var b := _battle()
	_hand(b, ["rifle_squad"] as Array[String])
	var rejected: Array = []
	b.card_rejected.connect(func(slot: int, r: CardPlayService.Result): rejected.append([slot, r.reason, r.placement]))
	b.select_slot(0)
	var res := b.confirm_at(Vector2i(10, 21))  # rock
	assert_true(not res.ok)
	assert_true(b.targeting.is_selecting(), "stays selected so the player can pick another cell")
	assert_eq(rejected, [[0, R.INVALID_TARGET, PlacementRules.Reason.NOT_BUILDABLE]])
	assert_eq(b.units.size(), 0)
	assert_true(b.confirm_at(GOOD).ok, "then a good cell works")
	_release()


func test_no_cp_refusal_reports_and_keeps_selection() -> void:
	var b := _battle()
	_hand(b, ["tank"] as Array[String], 1.0)
	var rejected: Array = []
	b.card_rejected.connect(func(slot: int, r: CardPlayService.Result): rejected.append(r.reason))
	b.select_slot(0)
	b.confirm_at(GOOD)
	assert_eq(rejected, [R.INSUFFICIENT_CP])
	assert_true(b.targeting.is_selecting())
	_release()


func test_confirming_on_a_slot_whose_card_just_left_the_hand_drops_the_selection() -> void:
	var b := _battle()
	_hand(b, ["rifle_squad"] as Array[String])
	b.select_slot(0)
	b.deck.hand.clear()  # the card vanished between frames (sync has not run yet)
	var res := b.confirm_at(GOOD)
	assert_eq(res.reason, R.EMPTY_SLOT)
	assert_true(not b.targeting.is_selecting(), "a stale selection is dropped, not kept")
	assert_eq(b.units.size(), 0)
	_release()


func test_confirm_without_selection_does_nothing() -> void:
	var b := _battle()
	_hand(b, ["rifle_squad"] as Array[String])
	assert_true(b.confirm_at(GOOD) == null)
	assert_eq(b.units.size(), 0)
	_release()


func test_missions_without_cards_ignore_selection() -> void:
	var b := BattleController.new()
	b.auto_step = false
	b.setup(_get_db(), _get_db().mission("m1_hold_the_crossing"), 1)
	b.select_slot(0)
	assert_true(not b.targeting.is_selecting())
	assert_true(b.confirm_at(GOOD) == null)
	b.free()


func test_selection_is_cleared_when_the_battle_ends_and_on_restart() -> void:
	var b := _battle()
	_hand(b, ["rifle_squad"] as Array[String])
	b.select_slot(0)
	b._rules.evaluate(0.0, b.elapsed)
	assert_true(not b.targeting.is_selecting(), "battle over clears the selection")
	b.restart()
	b.select_slot(0)
	assert_true(b.targeting.is_selecting())
	b.restart()
	assert_true(not b.targeting.is_selecting(), "restart starts fresh")
	_release()


func test_select_is_ignored_after_the_battle_ended() -> void:
	var b := _battle()
	b._rules.evaluate(0.0, b.elapsed)
	b.select_slot(0)
	assert_true(not b.targeting.is_selecting())
	_release()


# --- preview ----------------------------------------------------------------------------------------------

func test_preview_is_null_without_a_selection() -> void:
	var b := _battle()
	assert_true(b.targeting.preview(b, GOOD) == null)
	_release()


func test_preview_of_a_valid_squad_placement() -> void:
	var b := _battle()
	_hand(b, ["rifle_squad"] as Array[String])
	b.select_slot(0)
	var p := b.targeting.preview(b, GOOD)
	assert_true(p.valid)
	assert_eq(p.message, "")
	assert_eq(p.card.id, "rifle_squad")
	assert_eq(p.ground_points.size(), 3)
	for g in p.ground_points:
		assert_eq(IsoProjection.cell_of(g), GOOD, "the dots show where the soldiers would stand")
	assert_near(p.range_tiles, b.db.weapon("rifle").range_tiles)
	assert_near(p.blast_radius, 0.0)
	_release()


func test_preview_of_the_tank_shows_range_and_blast() -> void:
	var b := _battle()
	_hand(b, ["tank"] as Array[String])
	b.select_slot(0)
	var p := b.targeting.preview(b, GOOD)
	var cannon := b.db.weapon("tank_cannon")
	assert_near(p.range_tiles, cannon.range_tiles)
	assert_near(p.blast_radius, cannon.blast_radius)
	assert_eq(p.ground_points.size(), 1)
	_release()


func test_preview_of_an_invalid_cell_says_why() -> void:
	var b := _battle()
	_hand(b, ["rifle_squad"] as Array[String])
	b.select_slot(0)
	var rock := b.targeting.preview(b, Vector2i(10, 21))
	assert_true(not rock.valid)
	assert_eq(rock.placement, PlacementRules.Reason.NOT_BUILDABLE)
	assert_eq(rock.message, PlacementRules.describe(PlacementRules.Reason.NOT_BUILDABLE))
	var near_spawn := b.targeting.preview(b, Vector2i(20, 4))
	assert_eq(near_spawn.placement, PlacementRules.Reason.TOO_CLOSE_TO_SPAWN)
	assert_true(near_spawn.message != rock.message)
	var road := b.targeting.preview(b, Vector2i(5, 19))
	assert_true(road.valid, "roads can be built on")
	_release()


func test_preview_reports_missing_cp_before_the_cell() -> void:
	var b := _battle()
	_hand(b, ["tank"] as Array[String], 2.0)
	b.select_slot(0)
	var p := b.targeting.preview(b, Vector2i(5, 19))
	assert_eq(p.reason, R.INSUFFICIENT_CP)
	assert_eq(p.message, "Need %d CP" % b.db.card("tank").cost)
	_release()


func test_previewing_never_changes_battle_state() -> void:
	var b := _battle()
	_hand(b, ["rifle_squad"] as Array[String])
	b.select_slot(0)
	var cp := b.points.cp
	var hand := b.deck.hand.duplicate()
	for c in [GOOD, Vector2i(5, 19), Vector2i(-4, 2), Vector2i(20, 12)]:
		b.targeting.preview(b, c)
	assert_near(b.points.cp, cp, 1e-9)
	assert_eq(b.deck.hand, hand)
	assert_eq(b.units.size(), 0)
	_release()


func test_preview_follows_the_cell_and_ends_with_the_selection() -> void:
	var b := _battle()
	_hand(b, ["rifle_squad"] as Array[String])
	b.select_slot(0)
	assert_eq(b.targeting.preview(b, GOOD).cell, GOOD)
	assert_eq(b.targeting.preview(b, Vector2i(8, 20)).cell, Vector2i(8, 20))
	b.cancel_selection()
	assert_true(b.targeting.preview(b, GOOD) == null)
	_release()


# --- hand layout --------------------------------------------------------------------------------------------

func test_hand_slots_are_inside_the_screen_and_do_not_overlap() -> void:
	var screen := Rect2(Vector2.ZERO, HandUi.BASE_SIZE)
	for i in HandUi.SLOT_COUNT:
		var r := HandUi.slot_rect(i)
		assert_true(screen.encloses(r), "slot %d on screen" % i)
		for j in range(i + 1, HandUi.SLOT_COUNT):
			assert_true(not r.intersects(HandUi.slot_rect(j)), "slots %d and %d overlap" % [i, j])


func test_hand_is_centred_and_leaves_the_play_area_free() -> void:
	var first := HandUi.slot_rect(0)
	var last := HandUi.slot_rect(HandUi.SLOT_COUNT - 1)
	assert_near(first.position.x, HandUi.BASE_SIZE.x - last.end.x, 0.01, "centred horizontally")
	var capture := HandUi.capture_rect()
	assert_true(capture.position.y > HandUi.BASE_SIZE.y * 0.7, "the click-capturing area stays at the bottom")
	assert_true(capture.size.x < HandUi.BASE_SIZE.x * 0.6, "and does not span the whole screen")
	for i in HandUi.SLOT_COUNT:
		assert_true(capture.encloses(HandUi.slot_rect(i)))


func test_slot_at_finds_each_slot_and_ignores_gaps_and_the_field() -> void:
	for i in HandUi.SLOT_COUNT:
		assert_eq(HandUi.slot_at(HandUi.slot_rect(i).get_center()), i)
	var gap := Vector2(HandUi.slot_rect(0).end.x + HandUi.SLOT_GAP * 0.5, HandUi.slot_rect(0).get_center().y)
	assert_eq(HandUi.slot_at(gap), -1, "gap between cards")
	assert_eq(HandUi.slot_at(Vector2(960, 300)), -1, "the battlefield")
	assert_eq(HandUi.slot_at(Vector2(-5, -5)), -1)


func test_card_names_wrap_to_at_most_two_short_lines() -> void:
	assert_eq(HandUi._wrap("Tank"), ["Tank"] as Array[String])
	assert_eq(HandUi._wrap("Helicopter Support"), ["Helicopter", "Support"] as Array[String])
	assert_eq(HandUi._wrap("Artillery Strike"), ["Artillery", "Strike"] as Array[String])
	assert_eq(HandUi._wrap("Supercalifragilistic").size(), 1, "no space, no split")
	for id in _get_db().cards:
		for line in HandUi._wrap(_get_db().card(id).display_name):
			assert_true(line.length() <= 11, "%s fits a card" % line)


func test_world_preview_hides_with_no_selection() -> void:
	var node := CardPreview.new()
	var b := _battle()
	_hand(b, ["rifle_squad"] as Array[String])
	b.select_slot(0)
	node.show_preview(b.targeting.preview(b, GOOD), Vector2.ZERO, 10.0)
	assert_true(node.visible)
	node.show_preview(null, Vector2.ZERO, 10.0)
	assert_true(not node.visible)
	node.free()
	_release()
