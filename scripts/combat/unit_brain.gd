class_name UnitBrain
extends RefCounted
## What a player unit decides on its own each tick (ADR-013). Pure and random-free: the same inputs always give the same
## decision. The battle supplies the facts (is something already in weapon range, the enemy to deal with, the friend to
## follow) and carries the decision out; the brain never touches nodes or the map.
##   HOLD     never moves.
##   GUARD    stays at its anchor; goes after an enemy that is near the anchor, but never farther than `leash` from it; walks
##            back when nothing is left to fight.
##   ADVANCE  walks toward the enemy closest to the core until it has something in range; never farther than
##            `advance_limit` from the core.
##   SUPPORT  follows the nearest friendly fighting unit.
## All behaviours stop as soon as something is in weapon range (units must stand still to fire).

enum Behavior { HOLD, GUARD, ADVANCE, SUPPORT }
enum Action { STAY, MOVE }

## A unit takes up its firing spot at this fraction of its weapon range from the enemy, so a small step by the enemy does
## not immediately put it out of range again.
const RANGE_MARGIN: float = 0.9
## Closer than this to where it wants to be counts as there.
const ARRIVE_EPS: float = 0.15
## A support unit stands this far from the unit it follows, and starts walking when it is farther than FOLLOW_GAP.
const FOLLOW_STAND: float = 1.2
const FOLLOW_GAP: float = 2.2
## Habit constants. A hurt unit runs when an enemy is within RETREAT_DANGER and stops RETREAT_STAND tiles from the core.
const RETREAT_DANGER: float = 7.0
const RETREAT_STAND: float = 2.5
## Cover: the spot is this far behind the structure (seen from the enemy); structures farther than COVER_MAX_WALK away are ignored.
const COVER_BEHIND: float = 0.9
const COVER_MAX_WALK: float = 6.0
## A unit within COVER_OK of a structure that is nearer the enemy counts as in cover and stays put; with an enemy
## within COVER_ABORT it fights where it stands instead of walking to cover.
const COVER_OK: float = 1.5
const COVER_ABORT: float = 3.0


class Decision:
	extends RefCounted
	var action: Action = Action.STAY
	var dest: Vector2 = Vector2.ZERO

	static func stay() -> Decision:
		return Decision.new()

	static func move(to: Vector2) -> Decision:
		var d := Decision.new()
		d.action = Action.MOVE
		d.dest = to
		return d


## Guard: `enemy` is the enemy to deal with (the nearest one near the anchor) if `has_enemy`.
## `structures` are the positions of friendly structures (empty = the cover habit is off or none exist): a unit that is
## not yet in cover walks to a spot behind one, even if it could already fire from where it stands, unless an enemy is
## already `threatened`-close. Once in cover it stays (so a moving enemy does not make it shuffle).
static func guard(pos: Vector2, anchor: Vector2, weapon_range: float, leash: float, in_range: bool, has_enemy: bool, enemy: Vector2, structures: PackedVector2Array = PackedVector2Array(), threatened: bool = false) -> Decision:
	if has_enemy and not threatened and not structures.is_empty() and not in_cover(pos, enemy, structures):
		var behind: Variant = cover_spot(pos, enemy, weapon_range, anchor, leash, structures)
		if behind != null:
			return _go_or_stay(pos, behind)
	if in_range:
		return Decision.stay()
	if has_enemy:
		var spot := _firing_spot(pos, enemy, weapon_range)
		var off := spot - anchor
		if off.length() > leash:
			spot = anchor + off.normalized() * leash
		if spot.distance_to(enemy) > weapon_range:
			return Decision.stay()  # the leash keeps it too far away to ever reach this one
		return _go_or_stay(pos, spot)
	return _go_or_stay(pos, anchor)


## True if a friendly structure is close to `pos` and nearer the enemy than `pos` is.
static func in_cover(pos: Vector2, enemy: Vector2, structures: PackedVector2Array) -> bool:
	var own := pos.distance_to(enemy)
	for st in structures:
		if pos.distance_to(st) <= COVER_OK and st.distance_to(enemy) < own - 0.2:
			return true
	return false


## A spot just behind the nearest suitable friendly structure as seen from the enemy: in weapon range of the enemy,
## within the leash of the anchor and a short walk away. Enemies go for the nearest thing, so the structure takes the
## blows first. Returns null when no structure qualifies.
static func cover_spot(pos: Vector2, enemy: Vector2, weapon_range: float, anchor: Vector2, leash: float, structures: PackedVector2Array) -> Variant:
	var best: Variant = null
	var best_walk := INF
	for st in structures:
		var from_enemy := st - enemy
		var d := from_enemy.length()
		if d < 0.5:
			continue
		var spot := st + from_enemy / d * COVER_BEHIND
		if spot.distance_to(enemy) > weapon_range or spot.distance_to(anchor) > leash:
			continue
		var walk := pos.distance_to(spot)
		if walk > COVER_MAX_WALK:
			continue
		if walk < best_walk:
			best_walk = walk
			best = spot
	return best


## Retreat (a hurt, mobile unit): with an enemy near, walk back toward the core and stand RETREAT_STAND out from it;
## with none near, stay where it is.
static func retreat(pos: Vector2, core: Vector2, danger: bool) -> Decision:
	if not danger:
		return Decision.stay()
	var out := pos - core
	if out.length() <= RETREAT_STAND + ARRIVE_EPS:
		return Decision.stay()
	return _go_or_stay(pos, core + out.normalized() * RETREAT_STAND)


## Advance: `front` is the enemy closest to the core, if `has_front`.
static func advance(pos: Vector2, core: Vector2, weapon_range: float, advance_limit: float, in_range: bool, has_front: bool, front: Vector2) -> Decision:
	if in_range or not has_front:
		return Decision.stay()
	var spot := _firing_spot(pos, front, weapon_range)
	var off := spot - core
	if off.length() > advance_limit:
		spot = core + off.normalized() * advance_limit
	if spot.distance_to(front) > weapon_range:
		return Decision.stay()
	return _go_or_stay(pos, spot)


## Support: `friend` is the unit to follow, if `has_friend`.
static func support(pos: Vector2, has_friend: bool, friend: Vector2) -> Decision:
	if not has_friend or pos.distance_to(friend) <= FOLLOW_GAP:
		return Decision.stay()
	var away := pos - friend
	return Decision.move(friend + away.normalized() * FOLLOW_STAND)


## The point on the line from `enemy` toward `pos` that is RANGE_MARGIN of the range from the enemy; a unit already
## closer than that keeps its place.
static func _firing_spot(pos: Vector2, enemy: Vector2, weapon_range: float) -> Vector2:
	var want := weapon_range * RANGE_MARGIN
	var to_unit := pos - enemy
	var d := to_unit.length()
	if d <= want:
		return pos
	return enemy + to_unit / d * want


static func _go_or_stay(pos: Vector2, spot: Vector2) -> Decision:
	return Decision.move(spot) if pos.distance_to(spot) > ARRIVE_EPS else Decision.stay()
