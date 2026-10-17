class_name PlayerProfile
extends RefCounted
## What the player keeps between runs (docs/specs/progression.md): the cards they own, their deck, the missions they
## finished and the rewards they were offered. Plain data with a dictionary round trip; reading and writing the file is
## ProfileStore's job, upgrading old files is ProfileMigration's. Nothing in the battle reads this class.

const CURRENT_VERSION: int = 1
const STARTER_DECK: String = "starter"

var version: int = CURRENT_VERSION
## Drawn once when the profile is created; with a mission id it fixes the reward offer (RewardPicker).
var reward_seed: int = 0
## Ids of the owned cards (owning a card gives every copy up to its max_copies).
var collection: PackedStringArray = PackedStringArray()
## The player's deck for player-deck missions (duplicates are copies).
var deck: PackedStringArray = PackedStringArray()
## Doctrine cards picked for the next player-deck mission.
var doctrines: PackedStringArray = PackedStringArray()
## Finished missions: id -> {"wins": int, "best_core": float, "best_difficulty": String, "best_scale": float}.
var missions: Dictionary = {}
## Reward offers: mission id -> the card taken ("" while the offer waits for an answer).
var rewards: Dictionary = {}
## The cards on offer while a reward waits for an answer: mission id -> card ids. Saved with the win, so quitting and
## coming back shows the same cards.
var offers: Dictionary = {}
## Set when the file came from a newer game version: kept in memory, never written back.
var read_only: bool = false


## A new profile: the cards of the starter deck, that deck, no progress.
static func new_game(db: ContentDb, p_reward_seed: int) -> PlayerProfile:
	var p := PlayerProfile.new()
	p.reward_seed = p_reward_seed
	p._reset_to_starter(db)
	return p


func _reset_to_starter(db: ContentDb) -> void:
	collection = PackedStringArray()
	deck = PackedStringArray()
	var starter := db.deck(STARTER_DECK) if db != null else null
	if starter == null:
		return
	for cid in starter.card_ids:
		deck.append(cid)
		if not collection.has(cid):
			collection.append(cid)


# --- queries ---------------------------------------------------------------------------------------------------

func owns(card_id: String) -> bool:
	return collection.has(card_id)


func wins_of(mission_id: String) -> int:
	var m: Variant = missions.get(mission_id)
	return int((m as Dictionary).get("wins", 0)) if m is Dictionary else 0


func is_won(mission_id: String) -> bool:
	return wins_of(mission_id) >= 1


## The mission ids whose reward offer waits for an answer.
func pending_rewards() -> PackedStringArray:
	var out := PackedStringArray()
	var ids: Array = rewards.keys()
	ids.sort()
	for id: String in ids:
		if String(rewards[id]).is_empty():
			out.append(id)
	return out


# --- changes ---------------------------------------------------------------------------------------------------

## Records a won battle. `scale` is the difficulty's enemy-count multiplier (the harder win is the better one).
func record_win(mission_id: String, core_fraction: float, difficulty_id: String, scale: float) -> void:
	var m: Dictionary = missions.get(mission_id, {}) if missions.get(mission_id) is Dictionary else {}
	var core := clampf(core_fraction, 0.0, 1.0) if is_finite(core_fraction) else 0.0
	m["wins"] = int(m.get("wins", 0)) + 1
	m["best_core"] = maxf(float(m.get("best_core", 0.0)), core)
	if scale >= float(m.get("best_scale", 0.0)):
		m["best_scale"] = scale
		m["best_difficulty"] = difficulty_id
	missions[mission_id] = m


## Opens the reward offer of a mission that has none yet (it stays "" until a card is taken). `offer` is the list of
## cards shown; an empty one is kept as "no cards saved" and the picker is asked again when it is shown.
func open_reward(mission_id: String, offer: PackedStringArray = PackedStringArray()) -> void:
	if rewards.has(mission_id):
		return
	rewards[mission_id] = ""
	if not offer.is_empty():
		offers[mission_id] = offer


## The cards saved for a waiting reward (empty when none were saved or it was answered).
func offer_of(mission_id: String) -> PackedStringArray:
	var o: Variant = offers.get(mission_id)
	return o if o is PackedStringArray else PackedStringArray()


func has_pending_reward(mission_id: String) -> bool:
	return rewards.has(mission_id) and String(rewards[mission_id]).is_empty()


## Takes `card_id` as the reward of `mission_id`: the offer is answered and the card is owned. Refuses (false) a card
## that was not on the saved offer, and a reward that was already answered.
func take_reward(mission_id: String, card_id: String) -> bool:
	if rewards.has(mission_id) and not String(rewards[mission_id]).is_empty():
		return false
	var saved := offer_of(mission_id)
	if not saved.is_empty() and not saved.has(card_id):
		return false
	rewards[mission_id] = card_id
	offers.erase(mission_id)
	if not collection.has(card_id):
		collection.append(card_id)
	return true


## Opens the reward of every won mission that has a pool and no reward entry yet (a profile written before rewards
## existed, or a pool added later). Returns how many were opened.
func backfill_rewards(db: ContentDb) -> int:
	var camp := db.main_campaign()
	if camp == null:
		return 0
	var opened := 0
	for mid in camp.mission_ids:
		if is_won(mid) and not rewards.has(mid):
			var offer := RewardPicker.offer(camp.pool_of(mid), collection, reward_seed, mid)
			if not offer.is_empty():
				open_reward(mid, offer)
				opened += 1
	return opened


# --- dictionary round trip --------------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"version": version,
		"reward_seed": reward_seed,
		"collection": Array(collection),
		"deck": Array(deck),
		"doctrines": Array(doctrines),
		"missions": missions.duplicate(true),
		"rewards": rewards.duplicate(true),
		"offers": _offers_to_json(),
	}


## Reads what it understands; a missing or wrong-typed field keeps its default. Never fails. Run `sanitize` after it
## to drop ids the game no longer knows.
static func from_dict(d: Dictionary) -> PlayerProfile:
	var p := PlayerProfile.new()
	p.version = _int_of(d.get("version"), 0)
	p.reward_seed = _int_of(d.get("reward_seed"), 0)
	p.collection = _ids_of(d.get("collection"))
	p.deck = _ids_of(d.get("deck"), true)
	p.doctrines = _ids_of(d.get("doctrines"))
	var ms: Variant = d.get("missions")
	if ms is Dictionary:
		for id: Variant in ms:
			if id is String and ms[id] is Dictionary:
				var src: Dictionary = ms[id]
				p.missions[id] = {
					"wins": maxi(_int_of(src.get("wins"), 0), 0),
					"best_core": clampf(_float_of(src.get("best_core"), 0.0), 0.0, 1.0),
					"best_difficulty": String(src.get("best_difficulty")) if src.get("best_difficulty") is String else "",
					"best_scale": maxf(_float_of(src.get("best_scale"), 0.0), 0.0),
				}
	var rs: Variant = d.get("rewards")
	if rs is Dictionary:
		for id: Variant in rs:
			if id is String and rs[id] is String:
				p.rewards[id] = rs[id]
	var os: Variant = d.get("offers")
	if os is Dictionary:
		for id: Variant in os:
			if id is String:
				var list := _ids_of(os[id])
				if not list.is_empty():
					p.offers[id] = list
	return p


## Brings the profile in line with the content the game has now: unknown cards and missions are dropped, a deck that is
## no longer legal (or uses cards the player does not own) goes back to the starter deck, an empty collection gets the
## starter cards. Returns the number of things it had to change.
func sanitize(db: ContentDb) -> int:
	var changes := 0
	changes += _keep_known_cards(collection, db)
	changes += _keep_known_cards(doctrines, db)
	for cid in doctrines.duplicate():
		var c := db.card(cid)
		if c.card_kind != CardDefinition.CardKind.DOCTRINE or not collection.has(cid):
			doctrines.remove_at(doctrines.find(cid))
			changes += 1
	for id in missions.keys():
		if db.mission(id) == null:
			missions.erase(id)
			changes += 1
	for id in rewards.keys():
		var taken := String(rewards[id])
		if db.mission(id) == null or (not taken.is_empty() and db.card(taken) == null):
			rewards.erase(id)
			changes += 1
		elif not taken.is_empty() and not collection.has(taken):
			collection.append(taken)  # a taken reward is always owned
	for id in offers.keys():
		if db.mission(id) == null or not rewards.has(id) or not String(rewards[id]).is_empty():
			offers.erase(id)
			changes += 1
			continue
		var kept := PackedStringArray()
		for cid in offers[id]:
			if db.card(cid) != null and not collection.has(cid):
				kept.append(cid)
		if kept.size() != (offers[id] as PackedStringArray).size():
			changes += 1
			if kept.is_empty():
				offers.erase(id)
			else:
				offers[id] = kept
	if collection.is_empty() and db.deck(STARTER_DECK) != null:
		var keep := deck
		_reset_to_starter(db)
		deck = keep
		changes += 1
	if not deck_is_legal(db):
		var keep_collection := collection
		_reset_to_starter(db)
		for cid in keep_collection:
			if not collection.has(cid):
				collection.append(cid)
		changes += 1
	return changes


## Whether `deck` obeys the deck rules and only uses owned cards.
func deck_is_legal(db: ContentDb) -> bool:
	if db.deck_rules == null:
		return false
	for cid in deck:
		if not collection.has(cid):
			return false
	var ids: Array[String] = []
	for cid in deck:
		ids.append(cid)
	return db.deck_rules.validate_deck(ids, db.cards).is_empty()


func _offers_to_json() -> Dictionary:
	var out: Dictionary = {}
	for id: String in offers:
		out[id] = Array(offers[id] as PackedStringArray)
	return out


## Removes ids the database has no card for; returns how many were removed.
func _keep_known_cards(list: PackedStringArray, db: ContentDb) -> int:
	var removed := 0
	var i := list.size() - 1
	while i >= 0:
		if db.card(list[i]) == null:
			list.remove_at(i)
			removed += 1
		i -= 1
	return removed


static func _int_of(v: Variant, fallback: int) -> int:
	if (v is int) or (v is float and is_finite(v)):
		return int(v)
	return fallback


static func _float_of(v: Variant, fallback: float) -> float:
	if (v is int) or (v is float and is_finite(v)):
		return float(v)
	return fallback


## Strings only; `keep_duplicates` keeps repeated ids (a deck), otherwise each id once (a collection).
static func _ids_of(v: Variant, keep_duplicates: bool = false) -> PackedStringArray:
	var out := PackedStringArray()
	if v is Array:
		for x: Variant in v:
			if x is String and not (x as String).is_empty() and (keep_duplicates or not out.has(x)):
				out.append(x)
	return out
