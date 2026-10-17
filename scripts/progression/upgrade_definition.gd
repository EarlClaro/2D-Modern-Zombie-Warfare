class_name UpgradeDefinition
extends ContentDefinition
## A card upgrade (docs/specs/progression.md, increment 5.5): one of two exclusive branches of a card. Earned as a reward,
## equipped in the deck editor, and applied only to the copy of the content a player-deck battle runs on. Its `patches`
## change numbers of weapons, units, operations or the card itself.

@export var display_name: String = ""
@export var description: String = ""
## The card this upgrade belongs to; a card has at most one equipped upgrade at a time.
@export var card_id: String = ""
@export var patches: Array[UpgradePatch] = []


func kind() -> String:
	return "upgrade"


func validate() -> PackedStringArray:
	var errs := super.validate()
	if display_name.is_empty():
		errs.append(_err("display_name is empty"))
	if description.is_empty():
		errs.append(_err("description is empty"))
	if card_id.is_empty():
		errs.append(_err("card_id is empty"))
	if patches.is_empty():
		errs.append(_err("an upgrade needs at least one patch"))
	for i in patches.size():
		if patches[i] == null:
			errs.append(_err("patches[%d] is null" % i))
		elif patches[i].property.is_empty() or patches[i].target_id.is_empty():
			errs.append(_err("patches[%d] needs a target_id and a property" % i))
	return errs
