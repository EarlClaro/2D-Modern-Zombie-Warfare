class_name RewardPicker
extends RefCounted
## The reward offer after a mission's first win (docs/specs/progression.md): up to three cards from the mission's pool
## that the player does not own yet. Pure and deterministic: the same seed, mission and collection always give the same
## offer, so reloading the game never re-rolls it.

const OFFER_SIZE: int = 3


## The pool entries that can be offered to this player: a card always, an upgrade only for a card they own.
static func usable_pool(db: ContentDb, profile: PlayerProfile, pool: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	for id in pool:
		var up := db.upgrade(id)
		if up == null or profile.owns(up.card_id):
			out.append(id)
	return out


static func offer(pool: PackedStringArray, owned: PackedStringArray, reward_seed: int, mission_id: String, count: int = OFFER_SIZE) -> PackedStringArray:
	var candidates: Array[String] = []
	for cid in pool:
		if not owned.has(cid) and not candidates.has(cid):
			candidates.append(cid)
	var rng := RandomNumberGenerator.new()
	rng.seed = ("%d:%s" % [reward_seed, mission_id]).hash()
	var i := candidates.size() - 1
	while i > 0:  # Fisher-Yates
		var j := rng.randi_range(0, i)
		var tmp := candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = tmp
		i -= 1
	var out := PackedStringArray()
	for k in mini(count, candidates.size()):
		out.append(candidates[k])
	return out
