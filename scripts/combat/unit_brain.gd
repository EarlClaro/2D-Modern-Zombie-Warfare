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
##   ARTILLERY stays where it was put (it does not scout) but keeps out of enemies' reach like KITE: backs away when
##            something gets close, falls back when overwhelmed.
##   KITE     a skirmisher: scouts up the enemy route toward the spawn, fights the enemies nearest the spawn from the edge of
##            its weapon range, keeps out of every enemy's danger zone (backing away along the route when something gets
##            close, one short step at a time so it can fire in between), and falls back toward the core when the crowd
##            is bigger than it can handle. Against enemies it cannot outrun it holds its ground instead.
##   HUNT     (aircraft only, e.g. combat drones) flies at the nearest enemy anywhere until it has something in range;
##            goes back to where it was launched when nothing is left.
## All behaviours stop as soon as something is in weapon range (units must stand still to fire).

enum Behavior { HOLD, GUARD, ADVANCE, SUPPORT, KITE, ARTILLERY, HUNT }
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
## Kiting. The safety margin added to an enemy's reach, the time (s) an enemy is assumed to close in while the unit reacts,
## the shortest and longest backward step, and the radius around a unit that counts for "crowded".
const KITE_MARGIN: float = 1.2
const KITE_REACT_S: float = 0.7
const KITE_STEP_MIN: float = 1.0
const KITE_STEP_MAX: float = 3.0
const KITE_CROWD_EXTRA: float = 3.0
## ...but a long-range weapon does not make the crowd radius long: the range is capped here before the extra is added.
const KITE_CROWD_MAX: float = 10.0
## Two friends closer than this nudge each other apart so nobody stands in another's way.
const FRIEND_SPACE: float = 0.7
## A retreating unit leans this much on "away from the enemies" versus "back along the route".
const KITE_AWAY_WEIGHT: float = 0.6


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


## Everything the kiting brain needs for one unit (the battle fills it; nothing here touches nodes).
class KiteFacts:
	extends RefCounted
	var pos: Vector2 = Vector2.ZERO
	var speed: float = 3.0
	var weapon_range: float = 8.0
	var danger_margin: float = 1.0  # multiplies KITE_MARGIN (a heavy tank is bolder than a rifleman)
	var courage: int = 14  # enemies within the crowd radius it will fight alone before falling back
	var core: Vector2 = Vector2.ZERO
	var route: Route = null
	var post_s: float = 0.0  # distance from the core along the route where it waits when nothing is in sight
	var post_side: float = 0.0  # sideways offset of its waiting spot (so a group does not stack up)
	var in_range: bool = false  # something is already in weapon range
	var stationary: bool = false  # artillery: never walks toward the enemy or out to a scouting post
	var scan: KiteScan = null
	var nearest_friend: Vector2 = Vector2(INF, INF)  # a friendly unit's position, if one is close
	## Optional: `clear(a, b) -> bool`, true if the walk from a to b is open ground. Without it every walk counts as open.
	var clear: Callable = Callable()


## Kite: see the class comment. Returns where to stand or walk.
static func kite(f: KiteFacts) -> Decision:
	var scan := f.scan
	# 1. Overwhelmed: fall back toward the core and fight with the rest of the army there.
	if scan.crowd > f.courage and f.pos.distance_to(f.core) > RETREAT_STAND * 2.0 + ARRIVE_EPS:
		var back: Variant = _step_back(f, -1.0, true)
		if back != null:
			return Decision.move(back)
		return Decision.stay()
	# 2. Something can reach it soon: back off if it can outrun them, otherwise stand and fight.
	if scan.danger_count > 0:
		if scan.danger_slower < scan.danger_count:
			return Decision.stay()  # a faster enemy would catch it from behind: face it instead
		if f.pos.distance_to(f.core) <= RETREAT_STAND + ARRIVE_EPS:
			return Decision.stay()  # nowhere left to go
		var step: Variant = _step_back(f, scan.worst_slack, false)
		return Decision.move(step) if step != null else Decision.stay()
	# 3. Safe and something to shoot: stand and fire.
	if f.in_range:
		return _unstack(f)
	if f.stationary:
		return _unstack(f)
	# 4. Enemies in sight: go for the one nearest the spawn, stopping at the edge of weapon range and outside its zone.
	if scan.has_upstream:
		var zone := scan.upstream_reach + KITE_MARGIN * f.danger_margin + scan.upstream_speed * KITE_REACT_S
		var want := maxf(f.weapon_range * RANGE_MARGIN, zone + 0.6)
		if want > f.weapon_range:
			return _unstack(f)  # it could never be shot from outside its own reach: leave it to the others
		var off := f.pos - scan.upstream_pos
		if off.length() <= want + ARRIVE_EPS:
			return _unstack(f)
		var spot: Vector2 = scan.upstream_pos + off.normalized() * want
		if f.pos.distance_to(spot) <= ARRIVE_EPS:
			return _unstack(f)
		if f.clear.is_valid() and not f.clear.call(f.pos, spot):
			return _unstack(f)
		return Decision.move(spot)
	# 5. Nothing in sight: scout up the route to the waiting post.
	if f.route != null and not f.route.is_empty():
		var post := f.route.point_at(f.post_s)
		var along := f.route.dir_to_core(post)
		post += Vector2(-along.y, along.x) * f.post_side
		if f.pos.distance_to(post) > ARRIVE_EPS * 3.0 and (not f.clear.is_valid() or f.clear.call(f.pos, post)):
			return Decision.move(post)
	return _unstack(f)


## A step back from the enemies: along the route toward the core, pushed away from whatever is close. `slack` is how far
## outside the worst danger zone the unit stands (negative = inside); the step is just long enough to get clear again.
## `far` asks for the long fall-back to the core instead. Returns null when no open step exists.
static func _step_back(f: KiteFacts, slack: float, far: bool) -> Variant:
	var scan := f.scan
	var back := Vector2.ZERO
	if f.route != null and not f.route.is_empty():
		back = f.route.dir_to_core(f.pos)
	if back == Vector2.ZERO:
		back = (f.core - f.pos).normalized()
	var away := scan.away.normalized() if scan.away.length_squared() > 1e-9 else back
	var dir := (away * KITE_AWAY_WEIGHT + back * (1.0 - KITE_AWAY_WEIGHT)).normalized()
	var to_core := f.pos.distance_to(f.core)
	var step := clampf(-slack + 0.8, KITE_STEP_MIN, KITE_STEP_MAX)
	if far:
		step = KITE_STEP_MAX * 2.0
	step = minf(step, maxf(to_core - RETREAT_STAND, 0.0))
	if step < ARRIVE_EPS:
		return null
	for turn in [0.0, 0.5, -0.5, 1.0, -1.0]:
		var spot: Vector2 = f.pos + dir.rotated(turn) * step
		if not f.clear.is_valid() or f.clear.call(f.pos, spot):
			return spot
	return null


## Standing still: but a unit that has a friend almost on top of it steps aside so they do not block each other.
static func _unstack(f: KiteFacts) -> Decision:
	if f.nearest_friend.x < INF and f.pos.distance_to(f.nearest_friend) < FRIEND_SPACE:
		var out := f.pos - f.nearest_friend
		var dir := out.normalized() if out.length_squared() > 1e-6 else Vector2(1, 0)
		var spot := f.pos + dir * (FRIEND_SPACE - out.length() + 0.15)
		if not f.clear.is_valid() or f.clear.call(f.pos, spot):
			return Decision.move(spot)
	return Decision.stay()


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


## Hunt: `prey` is the enemy to go after (the nearest one, wherever it is) if `has_prey`; `anchor` is where to wait.
static func hunt(pos: Vector2, anchor: Vector2, weapon_range: float, in_range: bool, has_prey: bool, prey: Vector2) -> Decision:
	if in_range:
		return Decision.stay()
	if has_prey:
		return _go_or_stay(pos, _firing_spot(pos, prey, weapon_range))
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
