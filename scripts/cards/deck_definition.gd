class_name DeckDefinition
extends ContentDefinition
## A named list of card ids (duplicates = copies). Legality against the rules and the card set is checked by
## DeckRules.validate_deck (ContentDb does this for every shipped deck).

@export var display_name: String = ""
@export var card_ids: PackedStringArray = PackedStringArray()


func kind() -> String:
	return "deck"


func validate() -> PackedStringArray:
	var errs := super.validate()
	if display_name.is_empty():
		errs.append(_err("display_name is empty"))
	var re := RegEx.create_from_string(ID_PATTERN)
	for cid in card_ids:
		if re.search(cid) == null:
			errs.append(_err("card id '%s' must be lowercase snake_case" % cid))
	return errs


func ids() -> Array[String]:
	var out: Array[String] = []
	for cid in card_ids:
		out.append(cid)
	return out
