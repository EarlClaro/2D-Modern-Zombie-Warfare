class_name UpgradeApplier
extends RefCounted
## Builds the content a player-deck battle runs on: the shared database with the equipped upgrades applied to copies of the
## definitions they change. The shared definitions are never touched (definitions are immutable at runtime), so the next
## battle, the tools and the tests see the original numbers.


## A copy of `db` whose tables are copied (the definitions are shared) except the ones an upgrade in `upgrade_ids`
## changes: those are duplicated first and then patched. Unknown upgrade ids are skipped.
static func patched_db(db: ContentDb, upgrade_ids: PackedStringArray) -> ContentDb:
	var out := ContentDb.new()
	out.weapons = db.weapons.duplicate()
	out.units = db.units.duplicate()
	out.enemies = db.enemies.duplicate()
	out.maps = db.maps.duplicate()
	out.missions = db.missions.duplicate()
	out.cards = db.cards.duplicate()
	out.decks = db.decks.duplicate()
	out.operations = db.operations.duplicate()
	out.effects = db.effects.duplicate()
	out.cutaways = db.cutaways.duplicate()
	out.entities = db.entities.duplicate()
	out.difficulties = db.difficulties.duplicate()
	out.campaigns = db.campaigns.duplicate()
	out.upgrades = db.upgrades.duplicate()
	out.scenery_defs = db.scenery_defs.duplicate()
	out.deck_rules = db.deck_rules
	out.errors = db.errors.duplicate()
	var copied: Dictionary = {}
	for uid in upgrade_ids:
		var up := db.upgrade(uid)
		if up == null:
			continue
		for patch in up.patches:
			var table := patch.table_of(out)
			var key := "%d:%s" % [patch.target, patch.target_id]
			if not table.has(patch.target_id):
				continue
			if not copied.has(key):
				table[patch.target_id] = (table[patch.target_id] as Resource).duplicate()
				copied[key] = true
			patch.apply_to(table[patch.target_id])
	return out
