class_name CardPlayService
extends RefCounted
## Decides whether a hand card can be played and commits the play. A failed check or play changes nothing.
## Check order (the first failing reason is reported): empty slot, unknown card, locked out, not enough CP,
## invalid target. `target_ok` is the caller's placement verdict (PlacementRules, M2.2); pass true when the
## card has not been aimed yet, to ask "is this card playable at all right now?".

enum Reason { OK, EMPTY_SLOT, UNKNOWN_CARD, LOCKED_OUT, INSUFFICIENT_CP, INVALID_TARGET }


class Result:
	extends RefCounted
	var ok: bool = false
	var reason: Reason = Reason.EMPTY_SLOT
	var card: CardDefinition = null  # set whenever the card id is known, even on failure

	func _init(p_reason: Reason, p_card: CardDefinition = null) -> void:
		reason = p_reason
		ok = p_reason == Reason.OK
		card = p_card


static func check(deck: DeckState, points: CommandPoints, cards: Dictionary, hand_index: int, target_ok: bool = true) -> Result:
	var cid := deck.card_at(hand_index)
	if cid.is_empty():
		return Result.new(Reason.EMPTY_SLOT)
	var def: CardDefinition = cards.get(cid)
	if def == null:
		return Result.new(Reason.UNKNOWN_CARD)
	if deck.is_locked(cid):
		return Result.new(Reason.LOCKED_OUT, def)
	if not points.can_afford(def.cost):
		return Result.new(Reason.INSUFFICIENT_CP, def)
	if not target_ok:
		return Result.new(Reason.INVALID_TARGET, def)
	return Result.new(Reason.OK, def)


## Validates, then spends CP, moves the card to the discard pile and starts its lockout.
static func try_play(deck: DeckState, points: CommandPoints, cards: Dictionary, hand_index: int, target_ok: bool = true) -> Result:
	var res := check(deck, points, cards, hand_index, target_ok)
	if not res.ok:
		return res
	points.spend(res.card.cost)
	deck.play_from_hand(hand_index)
	deck.start_lockout(res.card.id, res.card.lockout_s)
	return res
