class_name DeckRules
extends ContentDefinition
## Tunable deck/economy numbers (data/config/deck_rules.tres; mirrored in docs/BALANCE.md) plus the
## deck-legality check. Defaults match docs/specs/deck-and-economy.md.

@export var deck_min: int = 12
@export var deck_max: int = 24
@export var initial_hand: int = 4
@export var hand_cap: int = 5
## One card is drawn this often while the hand is below the cap.
@export var draw_interval_s: float = 4.0
@export var cp_start: float = 5.0
@export var cp_cap: float = 10.0
## Seconds per +1 CP.
@export var cp_regen_interval_s: float = 1.5


func kind() -> String:
	return "deck rules"


func validate() -> PackedStringArray:
	var errs := super.validate()
	if deck_min < 1:
		errs.append(_err("deck_min must be >= 1"))
	if deck_max < deck_min:
		errs.append(_err("deck_max must be >= deck_min"))
	if hand_cap < 1:
		errs.append(_err("hand_cap must be >= 1"))
	if initial_hand < 0 or initial_hand > hand_cap:
		errs.append(_err("initial_hand must be 0..hand_cap"))
	if draw_interval_s <= 0.0:
		errs.append(_err("draw_interval_s must be > 0"))
	if cp_cap <= 0.0:
		errs.append(_err("cp_cap must be > 0"))
	if cp_start < 0.0 or cp_start > cp_cap:
		errs.append(_err("cp_start must be 0..cp_cap"))
	if cp_regen_interval_s <= 0.0:
		errs.append(_err("cp_regen_interval_s must be > 0"))
	return errs


func cp_per_second() -> float:
	return 1.0 / cp_regen_interval_s


## Returns why `card_ids` is not a legal deck (empty = legal): size window, unknown ids, copy limits.
## `cards` is id -> CardDefinition. Unknown ids are errors, never crashes.
func validate_deck(card_ids: Array[String], cards: Dictionary) -> PackedStringArray:
	var errs := PackedStringArray()
	if card_ids.size() < deck_min:
		errs.append("deck has %d cards, minimum is %d" % [card_ids.size(), deck_min])
	if card_ids.size() > deck_max:
		errs.append("deck has %d cards, maximum is %d" % [card_ids.size(), deck_max])
	var counts: Dictionary = {}
	for cid in card_ids:
		counts[cid] = int(counts.get(cid, 0)) + 1
	var ids: Array = counts.keys()
	ids.sort()
	for cid in ids:
		var def: CardDefinition = cards.get(cid)
		if def == null:
			errs.append("deck references unknown card '%s'" % cid)
		elif def.card_kind == CardDefinition.CardKind.DOCTRINE:
			errs.append("deck contains doctrine card '%s' (a mission starts with doctrines, they are not drawn)" % cid)
		elif counts[cid] > def.max_copies:
			errs.append("deck has %d copies of '%s', maximum is %d" % [counts[cid], cid, def.max_copies])
	return errs
