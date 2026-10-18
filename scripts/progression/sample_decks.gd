class_name SampleDecks
extends RefCounted
## Three example players for balancing player-deck missions (docs/specs/progression.md, increment 5.6): what a weak, an
## average and a strong player could own and run after the first nine missions of the campaign, built only from the
## reward pools of those missions (one pick per mission, in order). The balance tool plays missions with them
## (`tools/tune_cards.gd --sample=weak|balanced|strong`) and a test keeps them honest: legal decks, reachable picks.

## Missions the picks come from, in campaign order.
const PICK_MISSIONS: Array[String] = [
	"m1_hold_the_crossing", "m2_card_defense", "m3_combined_arms", "x1_fortified_crossing", "x2_outskirts",
	"x3_storm_night", "x4_field_orders", "x5_field_works", "x6_high_tech",
]

const SAMPLES: Dictionary = {
	# Props and economy tricks: the cards a player takes when they do not know what is strong.
	"weak": {
		"picks": ["sandbags", "barrier", "fortify", "crates", "quick_draw", "noise_lure", "supply_drop", "hollow_points", "convoy"],
		"deck": {"rifle_squad": 3, "gatling_gun": 2, "tank": 1, "artillery_strike": 2, "helicopter_support": 1, "sandbags": 2, "barrier": 2,
			"fortify": 1, "crates": 1, "quick_draw": 1, "supply_drop": 1, "convoy": 1},
		"equipped": [],
		"doctrines": [],
	},
	# A sensible mix of infantry, a vehicle, indirect fire and one cheap upgrade.
	"balanced": {
		"picks": ["rpg_team", "gatling_crowd_spray", "ifv", "mortar_team", "rocket_launcher", "marksman_team", "hollow_points", "barracks", "combat_drones"],
		"deck": {"rifle_squad": 2, "gatling_gun": 2, "tank": 2, "artillery_strike": 2, "helicopter_support": 1, "rpg_team": 2, "ifv": 2,
			"mortar_team": 1, "rocket_launcher": 1, "marksman_team": 2, "barracks": 1, "combat_drones": 1},
		"equipped": ["gatling_crowd_spray"],
		"doctrines": ["hollow_points"],
	},
	# Full 24 cards of the strongest picks, two upgrades and a close-air-support card.
	"strong": {
		"picks": ["marksman_team", "gatling_ap_belt", "howitzer_battery", "artillery_heavy_shells", "rocket_launcher", "ifv", "hollow_points", "convoy", "close_air_support"],
		"deck": {"rifle_squad": 2, "gatling_gun": 3, "tank": 3, "artillery_strike": 3, "helicopter_support": 1, "marksman_team": 3, "howitzer_battery": 2,
			"rocket_launcher": 2, "ifv": 3, "convoy": 1, "close_air_support": 1},
		"equipped": ["gatling_ap_belt", "artillery_heavy_shells"],
		"doctrines": ["hollow_points"],
	},
}


static func names() -> Array[String]:
	return ["weak", "balanced", "strong"]


static func has(sample: String) -> bool:
	return SAMPLES.has(sample)


## The profile of that example player: the starter cards plus their picks, their deck, upgrades and doctrine.
static func profile(db: ContentDb, sample: String) -> PlayerProfile:
	var p := PlayerProfile.new_game(db, 1)
	var s: Dictionary = SAMPLES[sample]
	for pick: String in s["picks"]:
		if db.upgrade(pick) != null:
			p.unlocked_upgrades.append(pick)
		elif not p.collection.has(pick):
			p.collection.append(pick)
	p.deck = PackedStringArray()
	var deck: Dictionary = s["deck"]
	for cid: String in deck:
		for i in int(deck[cid]):
			p.deck.append(cid)
	for uid: String in s["equipped"]:
		p.equip(db, uid)
	p.doctrines = PackedStringArray(s["doctrines"])
	return p
