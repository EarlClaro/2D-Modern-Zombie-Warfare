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
static func guard(pos: Vector2, anchor: Vector2, weapon_range: float, leash: float, in_range: bool, has_enemy: bool, enemy: Vector2) -> Decision:
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
