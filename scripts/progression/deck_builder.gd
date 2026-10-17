class_name DeckBuilder
extends RefCounted
## Editing the player's deck (docs/specs/progression.md): which cards can be added or removed and why not, the doctrine
## choice, and the deck and doctrines a battle receives. Pure logic over a PlayerProfile and the content database; the
## deck screen only presents it. Every change is checked with the shipped DeckRules, so an illegal deck cannot be built.


## Copies of each card in the deck: card id -> count.
static func counts(deck: PackedStringArray) -> Dictionary:
	var out: Dictionary = {}
	for cid in deck:
		out[cid] = int(out.get(cid, 0)) + 1
	return out


## The owned cards that can go into a deck (doctrine cards cannot), cheapest first, then by name.
static func deckable_cards(profile: PlayerProfile, db: ContentDb) -> Array[String]:
	return _owned_where(profile, db, false)


## The owned doctrine cards.
static func doctrine_cards(profile: PlayerProfile, db: ContentDb) -> Array[String]:
	return _owned_where(profile, db, true)


static func _owned_where(profile: PlayerProfile, db: ContentDb, doctrine: bool) -> Array[String]:
	var out: Array[String] = []
	for cid in profile.collection:
		var c := db.card(cid)
		if c != null and (c.card_kind == CardDefinition.CardKind.DOCTRINE) == doctrine:
			out.append(cid)
	out.sort_custom(func(a: String, b: String) -> bool:
		var ca := db.card(a)
		var cb := db.card(b)
		if ca.cost != cb.cost:
			return ca.cost < cb.cost
		return ca.display_name < cb.display_name)
	return out


## "" when a copy of `card_id` can be added, otherwise the reason it cannot.
static func why_not_add(profile: PlayerProfile, db: ContentDb, card_id: String) -> String:
	if profile.read_only:
		return "This progress file comes from a newer game and cannot be changed."
	var c := db.card(card_id)
	if c == null or not profile.owns(card_id):
		return "You do not own that card."
	if c.card_kind == CardDefinition.CardKind.DOCTRINE:
		return "A doctrine is chosen before a mission, it is not part of the deck."
	var have := int(counts(profile.deck).get(card_id, 0))
	if have >= c.max_copies:
		return "%s: at most %d cop%s in a deck." % [c.display_name, c.max_copies, "y" if c.max_copies == 1 else "ies"]
	if profile.deck.size() >= db.deck_rules.deck_max:
		return "The deck is full (%d cards). Remove a card first." % db.deck_rules.deck_max
	return ""


## "" when a copy of `card_id` can be removed, otherwise the reason it cannot.
static func why_not_remove(profile: PlayerProfile, db: ContentDb, card_id: String) -> String:
	if profile.read_only:
		return "This progress file comes from a newer game and cannot be changed."
	if not profile.deck.has(card_id):
		return "That card is not in the deck."
	if profile.deck.size() <= db.deck_rules.deck_min:
		return "A deck needs at least %d cards. Add another card before removing this one." % db.deck_rules.deck_min
	return ""


## Adds a copy; returns "" or the reason it was refused (the deck is left as it was then).
static func add(profile: PlayerProfile, db: ContentDb, card_id: String) -> String:
	var why := why_not_add(profile, db, card_id)
	if why.is_empty():
		profile.deck.append(card_id)
	return why


## Removes a copy; returns "" or the reason it was refused.
static func remove(profile: PlayerProfile, db: ContentDb, card_id: String) -> String:
	var why := why_not_remove(profile, db, card_id)
	if why.is_empty():
		profile.deck.remove_at(profile.deck.rfind(card_id))
	return why


## Puts the starter deck back (the collection is kept). Returns "" or why it could not.
static func reset(profile: PlayerProfile, db: ContentDb) -> String:
	if profile.read_only:
		return "This progress file comes from a newer game and cannot be changed."
	var starter := db.deck(PlayerProfile.STARTER_DECK)
	if starter == null:
		return "There is no starter deck."
	profile.deck = PackedStringArray(starter.ids())
	return ""


## Chooses `card_id` as the doctrine for the next player-deck mission, or drops it when it is the chosen one already.
## One doctrine at a time for now. Returns "" or why it was refused.
static func toggle_doctrine(profile: PlayerProfile, db: ContentDb, card_id: String) -> String:
	if profile.read_only:
		return "This progress file comes from a newer game and cannot be changed."
	var c := db.card(card_id)
	if c == null or c.card_kind != CardDefinition.CardKind.DOCTRINE or not profile.owns(card_id):
		return "That is not a doctrine you own."
	profile.doctrines = PackedStringArray() if profile.doctrines.has(card_id) else PackedStringArray([card_id])
	return ""


## "15 cards (12 to 24)" and whether the deck is playable.
static func summary(profile: PlayerProfile, db: ContentDb) -> String:
	return "%d cards (%d to %d)" % [profile.deck.size(), db.deck_rules.deck_min, db.deck_rules.deck_max]


## What a battle on a player-deck mission is given: {"deck": PackedStringArray, "doctrines": PackedStringArray}. A deck that
## is not legal (or uses cards that are not owned) is replaced by the starter deck rather than failing the mission.
static func loadout(profile: PlayerProfile, db: ContentDb) -> Dictionary:
	var deck := profile.deck
	if not profile.deck_is_legal(db):
		var starter := db.deck(PlayerProfile.STARTER_DECK)
		deck = PackedStringArray(starter.ids()) if starter != null else PackedStringArray()
	var doctrines := PackedStringArray()
	for cid in profile.doctrines:
		var c := db.card(cid)
		if c != null and c.card_kind == CardDefinition.CardKind.DOCTRINE and profile.owns(cid):
			doctrines.append(cid)
	return {"deck": deck, "doctrines": doctrines}
