class_name CardDefinition
extends ContentDefinition
## A playable card. Immutable data; what a card *does* at play time lives in the battle (keyed by
## `card_kind` + `unit_id` / `effect_id`), never in the definition.

enum CardKind { DEPLOYMENT, OPERATION, SORTIE }

const MAX_COPIES_LIMIT: int = 3  # hard ceiling from the deck rules; Legendary cards set max_copies = 1

@export var display_name: String = ""
@export var description: String = ""
@export var card_kind: CardKind = CardKind.DEPLOYMENT
## Command Points spent on a valid play.
@export var cost: int = 1
## After any copy is played, other copies of this id cannot be played for this long (0 = none).
@export var lockout_s: float = 0.0
@export var max_copies: int = MAX_COPIES_LIMIT
## DEPLOYMENT / SORTIE: the unit that is spawned, and how many.
@export var unit_id: String = ""
@export var unit_count: int = 1
## SORTIE: how long the aircraft holds station over the target before leaving.
@export var station_time_s: float = 0.0
## OPERATION: the battle effect to run (e.g. "artillery_strike").
@export var effect_id: String = ""


func kind() -> String:
	return "card"


func validate() -> PackedStringArray:
	var errs := super.validate()
	if display_name.is_empty():
		errs.append(_err("display_name is empty"))
	if cost < 0:
		errs.append(_err("cost must be >= 0"))
	if lockout_s < 0.0:
		errs.append(_err("lockout_s must be >= 0"))
	if max_copies < 1 or max_copies > MAX_COPIES_LIMIT:
		errs.append(_err("max_copies must be 1..%d" % MAX_COPIES_LIMIT))
	match card_kind:
		CardKind.DEPLOYMENT, CardKind.SORTIE:
			if unit_id.is_empty():
				errs.append(_err("unit_id is required for deployment/sortie cards"))
			if unit_count < 1:
				errs.append(_err("unit_count must be >= 1"))
			if card_kind == CardKind.SORTIE and station_time_s <= 0.0:
				errs.append(_err("station_time_s must be > 0 for sortie cards"))
		CardKind.OPERATION:
			if effect_id.is_empty():
				errs.append(_err("effect_id is required for operation cards"))
	return errs
