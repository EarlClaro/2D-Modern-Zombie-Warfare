extends SceneTree
## Dev tool (not a test). Balance sweep of the M2 card loop: scripted play patterns against `m2_card_defense`
## (or any card mission), several seeds each, through the same public API a player uses (hand, CP, place on a cell).
## The bots react 4 times a second, like an attentive but not frame-perfect player.
##
## Patterns:  idle   plays nothing (must lose)
##            spam   plays the cheapest playable card as soon as it can, operations aimed at the horde's current spot
##            only=ID plays only that card (mix placement/aiming): how strong is one card on its own?
##            cheap  like spam (cheapest playable card first) but placed and aimed well (see mix)
##            mix    a decent player who saves up: tank/gatling forward on the lane, rifle squads behind them, artillery and
##                   the helicopter only when a crowd is there, artillery aimed ahead of the horde (leading it); it waits up
##                   to SAVE_PATIENCE_S for the most expensive card it could play, unless the horde is at the core
## Run:  godot --headless --path . --script tools/tune_cards.gd -- [--patterns=idle,spam,mix] [--seeds=10] [--mission=m2_card_defense]
##                                                         [--set=card.tank.cost=5 --set=op.artillery_strike.warning_s=1.0 ...]
##                                                         [--typescale=brute:3,spitter:2 (per enemy id, same wave length)] [--timescale=0.6 (wave start times)] [--wavescale=0.8] [--ratescale=2] [--core=700] [--verbose] [--trace] [--drop=card_id,card_id] [--bench] [--benchgap=0.5] [--benchenemy=shambler] [--benchcount=60] [--benchtime=60] [--card=ID]
## --bench: one card at a time against the same fixed stream (core cannot fall, CP unlimited): kills and losses per CP.
## --drop removes those cards from the deck for every pattern ("does the deck still hold without X?").
## --wavescale multiplies every wave's zombie count; --ratescale divides every wave's spawn interval (a wave's length
## stays the same only when both are given the same factor).
## --set=KIND.ID.FIELD=VALUE changes a loaded definition in this process only (KIND: card|op|weapon|unit|enemy|rules; for rules the ID is ignored, e.g. rules.x.cp_regen_interval_s=3).

const DT: float = 1.0 / 60.0
const REACT_TICKS: int = 15  # bots look at the table 4 times a second
const MAX_TICKS: int = 60 * 400
const SAVE_PATIENCE_S: float = 16.0

var _patterns: Array[String] = ["idle", "spam", "cheap", "mix"]
var _seeds: int = 10
var _mission_id: String = "m2_card_defense"
var _verbose: bool = false
var _trace: bool = false
var _bench: bool = false
var _bench_gap: float = 0.5
var _bench_enemy: String = "shambler"
var _bench_count: int = 60
var _bench_s: float = 60.0
var _card_filter: String = ""
var _drops: PackedStringArray = PackedStringArray()
var _sets: Array[String] = []
var _wavescale: float = 1.0
var _ratescale: float = 1.0
var _core_override: float = -1.0
var _timescale: float = 1.0  # multiplies every wave's start time (a long route needs the waves earlier to arrive in time)
var _typescale: Dictionary = {}  # enemy id -> count multiplier (the wave keeps its length: the interval shrinks by the same factor)


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--patterns="):
			_patterns.clear()
			for p in a.substr(11).split(","):
				_patterns.append(p)
		elif a.begins_with("--seeds="):
			_seeds = int(a.substr(8))
		elif a.begins_with("--mission="):
			_mission_id = a.substr(10)
		elif a.begins_with("--set="):
			_sets.append(a.substr(6))
		elif a.begins_with("--wavescale="):
			_wavescale = float(a.substr(12))
		elif a.begins_with("--ratescale="):
			_ratescale = float(a.substr(12))
		elif a.begins_with("--timescale="):
			_timescale = float(a.substr(12))
		elif a.begins_with("--typescale="):
			for pair in a.substr(12).split(","):
				var kv := pair.split(":")
				_typescale[kv[0]] = float(kv[1])
		elif a.begins_with("--core="):
			_core_override = float(a.substr(7))
		elif a == "--verbose":
			_verbose = true
		elif a.begins_with("--drop="):
			_drops = a.substr(7).split(",")
		elif a.begins_with("--benchgap="):
			_bench_gap = float(a.substr(11))
		elif a.begins_with("--card="):
			_card_filter = a.substr(7)
		elif a.begins_with("--benchenemy="):
			_bench_enemy = a.substr(13)
		elif a.begins_with("--benchtime="):
			_bench_s = float(a.substr(12))
		elif a.begins_with("--benchcount="):
			_bench_count = int(a.substr(13))
		elif a == "--bench":
			_bench = true
		elif a == "--trace":
			_trace = true
	var db := ContentDb.load_from()
	for s in _sets:
		if not _apply_set(db, s):
			quit(1)
			return
	var base := db.mission(_mission_id)
	var m := _variant(base)
	print("mission %s: %d zombies in %d waves, core %.0f, %.0f s | overrides: %s | wavescale %.2f, ratescale %.2f | dropped: %s" % [
		_mission_id, _total_zombies(m), m.waves.size(), m.core_health, m.duration_s, ", ".join(_sets) if not _sets.is_empty() else "none", _wavescale, _ratescale, ",".join(_drops) if not _drops.is_empty() else "none"])
	if _bench:
		_run_bench(db, m)
		quit()
		return
	for p in _patterns:
		_sweep(db, m, p)
	quit()


func _total_zombies(m: MissionDefinition) -> int:
	var n := 0
	for w in m.waves:
		n += w.count
	return n


func _variant(base: MissionDefinition) -> MissionDefinition:
	var m: MissionDefinition = base.duplicate()
	var waves: Array[WaveEntry] = []
	for w in base.waves:
		var c: WaveEntry = w.duplicate()
		var k := float(_typescale.get(w.enemy_id, 1.0))
		c.count = maxi(1, int(round(float(w.count) * _wavescale * k)))
		c.interval_s = w.interval_s / (_ratescale * k)
		c.start_s = w.start_s * _timescale
		waves.append(c)
	m.waves = waves
	if _core_override > 0.0:
		m.core_health = _core_override
	return m


func _apply_set(db: ContentDb, spec: String) -> bool:
	var eq := spec.find("=")
	var parts := spec.substr(0, eq).split(".")
	if eq < 0 or parts.size() != 3:
		printerr("bad --set (want kind.id.field=value): ", spec)
		return false
	var table: Dictionary = {}
	match parts[0]:
		"card":
			table = db.cards
		"op":
			table = db.operations
		"weapon":
			table = db.weapons
		"unit":
			table = db.units
		"enemy":
			table = db.enemies
		"rules":
			table = {parts[1]: db.deck_rules}
	var def: Object = table.get(parts[1])
	if def == null or not (parts[2] in def):
		printerr("unknown target in --set: ", spec)
		return false
	var raw := spec.substr(eq + 1)
	var cur: Variant = def.get(parts[2])
	def.set(parts[2], int(raw) if typeof(cur) == TYPE_INT else float(raw))
	return true


class Result:
	var won: bool = false
	var t: float = 0.0
	var core: float = 0.0
	var lost: int = 0
	var kills: int = 0
	var spawned: int = 0
	var played: Dictionary = {}
	var cp_capped_s: float = 0.0
	var first_play_s: float = -1.0


func _sweep(db: ContentDb, m: MissionDefinition, pattern: String) -> void:
	var rs: Array[Result] = []
	for s in range(1, _seeds + 1):
		var r := _run(db, m, pattern, s)
		rs.append(r)
		if _verbose:
			print("  %s seed %2d: %s at %5.1fs, core %3.0f%%, kills %d/%d, lost %d, played %s" % [
				pattern, s, "WON " if r.won else "lost", r.t, r.core * 100.0, r.kills, r.spawned, r.lost, str(r.played)])
	var wins := 0
	var core_sum := 0.0
	var lost_sum := 0
	var kill_sum := 0.0
	var capped := 0.0
	var played_total: Dictionary = {}
	var lose_t := 0.0
	var loses := 0
	for r in rs:
		wins += 1 if r.won else 0
		core_sum += r.core
		lost_sum += r.lost
		kill_sum += float(r.kills) / maxf(float(r.spawned), 1.0)
		capped += r.cp_capped_s
		if not r.won:
			lose_t += r.t
			loses += 1
		for k in r.played:
			played_total[k] = int(played_total.get(k, 0)) + int(r.played[k])
	var n := float(rs.size())
	var avg_played := {}
	for k in played_total:
		avg_played[k] = snappedf(float(played_total[k]) / n, 0.1)
	print("%-5s wins %2d/%d | core left avg %3.0f%% | zombies killed avg %3.0f%% | units lost avg %.1f | CP-at-cap %.0f s avg | falls at %s | cards/run %s" % [
		pattern, wins, rs.size(), core_sum / n * 100.0, kill_sum / n * 100.0, float(lost_sum) / n, capped / n,
		("%.0f s" % (lose_t / loses)) if loses > 0 else "-", str(avg_played)])


func _run(db: ContentDb, m: MissionDefinition, pattern: String, seed_value: int) -> Result:
	var b := BattleController.new()
	b.auto_step = false
	if pattern.begins_with("only="):  # a deck of nothing but that card, so the hand is never clogged by dead weight
		var d := DeckDefinition.new()
		d.id = "tune_only"
		d.card_ids = PackedStringArray()
		for i in 15:
			d.card_ids.append(pattern.substr(5))
		db.decks["tune_only"] = d
		m = m.duplicate()
		m.deck_id = "tune_only"
	if not _drops.is_empty() and not pattern.begins_with("only="):
		var src: DeckDefinition = db.deck(m.deck_id)
		var d2 := DeckDefinition.new()
		d2.id = "tune_drop"
		d2.card_ids = PackedStringArray()
		for cid in src.card_ids:
			if not _drops.has(cid):
				d2.card_ids.append(cid)
		db.decks["tune_drop"] = d2
		m = m.duplicate()
		m.deck_id = "tune_drop"
	b.setup(db, m, seed_value)
	var r := Result.new()
	var ticks := 0
	while not b.is_ended() and ticks < MAX_TICKS:
		if ticks % REACT_TICKS == 0 and pattern != "idle":
			_act(b, pattern, r)
		b.step(DT)
		ticks += 1
		if _trace and ticks % 600 == 0:
			print("    t=%3.0f alive=%3d units=%2d core=%3.0f kills=%3d cp=%.1f hand=%s" % [b.elapsed, b.enemy_count(), b.units.size(), b.core.health.hp, b.stats["kills"], b.points.cp, str(b.deck.hand)])
		if b.points.cp >= b.points.cap - 1e-6:
			r.cp_capped_s += DT
	r.won = b.result().status == MissionRules.Status.WON
	r.t = b.elapsed
	r.core = b.core.health.hp / b.core.health.max_hp
	r.lost = b.stats["units_lost"]
	r.kills = b.stats["kills"]
	r.spawned = b.stats["spawned"]
	b.free()
	return r


# ---- the bots ---------------------------------------------------------------------------------------------------

func _act(b: BattleController, pattern: String, r: Result) -> void:
	# Try slots in the pattern's preferred order; play at most one card per look (a human clicks one at a time).
	var order := _slot_order(b, pattern)
	for slot in order:
		var card: CardDefinition = b.cards_by_id().get(b.deck.card_at(slot))
		if card == null or b.deck.is_locked(card.id):
			continue
		var cell := _choose_cell(b, card, pattern)
		if cell.x < -999:
			continue
		if not b.points.can_afford(card.cost):
			if pattern == "mix" and _worth_waiting(b, card):
				return  # keep the CP for this one
			continue
		var res := b.play_card(slot, cell)
		if res.ok:
			r.played[card.id] = int(r.played.get(card.id, 0)) + 1
			if r.first_play_s < 0.0:
				r.first_play_s = b.elapsed
			return


## Saving for `card` is worth it when it is within reach soon and the horde is not already at the core.
func _worth_waiting(b: BattleController, card: CardDefinition) -> bool:
	var core_c := IsoProjection.cell_center(b.mission.core_cell)
	for e in b.enemies:
		if e.is_alive() and e.ground_pos.distance_to(core_c) < 6.0:
			return false
	return (float(card.cost) - b.points.cp) / b.points.regen_per_s <= SAVE_PATIENCE_S


func _slot_order(b: BattleController, pattern: String) -> Array[int]:
	var slots: Array[int] = []
	for i in b.deck.hand.size():
		if pattern.begins_with("only=") and b.deck.card_at(i) != pattern.substr(5):
			continue
		slots.append(i)
	var costs: Dictionary = {}
	for i in slots:
		var c: CardDefinition = b.cards_by_id().get(b.deck.card_at(i))
		costs[i] = c.cost if c != null else 99
	if pattern == "spam" or pattern == "cheap":
		slots.sort_custom(func(x: int, y: int) -> bool: return costs[x] < costs[y])
	else:  # mix: the big guns first, cheap fill last
		slots.sort_custom(func(x: int, y: int) -> bool: return costs[x] > costs[y])
	return slots


## The cell this bot would play `card` on, or (-1000, -1000) for "not now".
func _choose_cell(b: BattleController, card: CardDefinition, pattern: String) -> Vector2i:
	var none := Vector2i(-1000, -1000)
	var lead := pattern != "spam"
	match card.card_kind:
		CardDefinition.CardKind.DEPLOYMENT:
			return _deploy_cell(b, card, pattern)
		CardDefinition.CardKind.OPERATION:
			var op: OperationDefinition = b.db.operation(card.effect_id)
			var need := 1 if pattern == "spam" else 8
			var lead_s := op.warning_s + op.flight_time_s if lead else 0.0
			return _crowd_cell(b, op.target_radius, need, lead_s)
		CardDefinition.CardKind.SORTIE:
			var need_s := 1 if pattern == "spam" else 7
			return _crowd_cell(b, 6.0, need_s, 0.0)
		CardDefinition.CardKind.ORDER, CardDefinition.CardKind.SUPPLY, CardDefinition.CardKind.DECK, CardDefinition.CardKind.REINFORCEMENT, CardDefinition.CardKind.SUPPORT_TECH:
			return Vector2i.ZERO if _instant_is_worth_it(b, card, pattern) else none  # these take no cell: any cell will do
		CardDefinition.CardKind.TRAP:  # a minefield on the route, a good way out from the core
			return _route_cell(b, 15.0)
		CardDefinition.CardKind.INTEL:  # a lure where the crowd is thickest, or further up the route
			var crowd := _crowd_cell(b, 6.0, 8, 0.0)
			return crowd if crowd.x > -999 else none
	return none


## When a bot plays a card that needs no target. `spam` plays them as soon as they are playable; the others wait for a reason.
func _instant_is_worth_it(b: BattleController, card: CardDefinition, pattern: String) -> bool:
	if pattern == "spam":
		return true
	var core_c := IsoProjection.cell_center(b.mission.core_cell)
	var near_core := 0
	var alive := 0
	var near_units := 0
	for e in b.enemies:
		if not e.is_alive():
			continue
		alive += 1
		if e.ground_pos.distance_to(core_c) < 10.0:
			near_core += 1
		for u in b.units:
			if u.is_alive() and not u.def.is_air() and u.ground_pos.distance_to(e.ground_pos) < 6.0:
				near_units += 1
				break
	match card.card_kind:
		CardDefinition.CardKind.ORDER:  # an order that protects the troops: when they are in a fight
			return near_units >= 8
		CardDefinition.CardKind.SUPPLY:  # command points: when the bank is low
			return b.points.cp <= b.points.cap - 3.0 and b.points.cp < 4.0
		CardDefinition.CardKind.DECK:  # draw: when the hand has room for two
			return b.deck.hand.size() <= b.db.deck_rules.hand_cap - 2
		CardDefinition.CardKind.REINFORCEMENT:  # reinforcements: when the base is under pressure or the army is thin
			return near_core >= 10 or (b.units.size() < 4 and alive >= 20)
		CardDefinition.CardKind.SUPPORT_TECH:  # drones: when there is something worth hunting
			return alive >= 15
	return false


## The cell on the first enemy route `dist` tiles from the core along it.
func _route_cell(b: BattleController, dist: float) -> Vector2i:
	if b._routes.is_empty() or b._routes[0].is_empty():
		return Vector2i(-1000, -1000)
	return IsoProjection.cell_of(b._routes[0].point_at(dist))


## Where along the lane (spawn -> core) a card wants to stand, as a distance from the core.
func _preferred_distance(card: CardDefinition, pattern: String) -> float:
	if pattern == "spam":
		return 6.0
	match card.unit_id:
		"tank", "ifv":
			return 8.0
		"scout":
			return 11.0
		"gatling_gun":
			return 6.5
		"marksman", "rpg_soldier":
			return 5.5
		"mortar_team":
			return 3.5
		"howitzer", "rocket_launcher":
			return 2.5  # artillery stays back (it does not need to be near the horde, only near a spotter)
		_:
			return 4.5  # riflemen behind the heavy stuff


func _lane_dir(b: BattleController) -> Vector2:
	var core_c := IsoProjection.cell_center(b.mission.core_cell)
	var spawn_c := IsoProjection.cell_center(b.mission.spawn_cells[0])
	return (spawn_c - core_c).normalized()


func _deploy_cell(b: BattleController, card: CardDefinition, pattern: String) -> Vector2i:
	var core_c := IsoProjection.cell_center(b.mission.core_cell)
	var dir := _lane_dir(b)
	var perp := Vector2(-dir.y, dir.x)
	var want := _preferred_distance(card, pattern)
	var route: Route = b._routes[0] if not b._routes.is_empty() else null  # the enemy route: "along" is measured on it, so winding maps work
	var occupied := b.occupied_cells()
	var best := Vector2i(-1000, -1000)
	var best_score := INF
	var rad := int(ceil(b.mission.deploy_radius)) if b.mission.deploy_radius > 0.0 else maxi(b.mission.map.width(), b.mission.map.height())
	for dx in range(-rad, rad + 1):
		for dy in range(-rad, rad + 1):
			var cell := b.mission.core_cell + Vector2i(dx, dy)
			if PlacementRules.check_deploy(b.mission.map, cell, b.mission.core_cell, b.mission.deploy_radius, occupied, b.mission.spawn_cells, b.mission.spawn_guard_radius) != PlacementRules.Reason.OK:
				continue
			var rel := IsoProjection.cell_center(cell) - core_c
			var along := rel.dot(dir)
			var side := absf(rel.dot(perp))
			if route != null and not route.is_empty():
				along = route.progress_of(IsoProjection.cell_center(cell))
				side = route.distance_to(IsoProjection.cell_center(cell))
			var score := absf(along - want) + side * 0.7
			# stay off cells next to a friend (they would all die to one bite anyway; spreads the fire)
			for u in b.units:
				if u.is_alive() and not u.def.is_air() and IsoProjection.cell_center(cell).distance_to(u.ground_pos) < 1.6:
					score += 2.5
			if score < best_score:
				best_score = score
				best = cell
	return best


## The cell holding the thickest crowd: the zombie whose surroundings (radius `radius`, after walking `lead_s` toward
## the core) contain the most zombies, provided at least `need` are in there.
func _crowd_cell(b: BattleController, radius: float, need: int, lead_s: float) -> Vector2i:
	var none := Vector2i(-1000, -1000)
	var core_c := IsoProjection.cell_center(b.mission.core_cell)
	var spots: Array[Vector2] = []
	for e in b.enemies:
		if not e.is_alive():
			continue
		var p := e.ground_pos
		if lead_s > 0.0:
			var to := core_c - p
			var step := minf(e.def.move_speed * lead_s, to.length())
			p += to.normalized() * step
		spots.append(p)
	var best_n := 0
	var best_p := Vector2.ZERO
	for p in spots:
		var n := 0
		for q in spots:
			if p.distance_to(q) <= radius:
				n += 1
		if n > best_n:
			best_n = n
			best_p = p
	if best_n < need:
		return none
	return IsoProjection.cell_of(best_p)


# ---- one card at a time -----------------------------------------------------------------------------------------




## The same stream every time: 60 shamblers, one every 0.5 s from t = 2 s. The core is made unbreakable, so what
## counts is how many zombies the single card played at the right moment kills within 60 s, and what it loses.
func _run_bench(db: ContentDb, base: MissionDefinition) -> void:
	var m: MissionDefinition = base.duplicate()
	var w := WaveEntry.new()
	w.start_s = 2.0
	w.enemy_id = _bench_enemy
	w.count = _bench_count
	w.interval_s = _bench_gap
	w.spawn_index = 0
	m.waves = [w] as Array[WaveEntry]
	m.core_health = 1.0e7
	m.duration_s = _bench_s
	print("bench: %d x %s, one every %.2f s from 2 s; one card played once, at the best moment it can find; %d seeds" % [_bench_count, _bench_enemy, _bench_gap, _seeds])
	print("%-20s %4s | %-30s | kills of %d (avg) | units lost | kills per CP" % ["card", "cost", "when played", _bench_count])
	var ids: Array[String] = []
	for id in db.cards:
		if _card_filter.is_empty() or id == _card_filter:
			ids.append(id)
	ids.sort()
	var none_kills: float = float(_bench_one(db, m, "", 1)[0])
	for id in ids:
		var card: CardDefinition = db.cards[id]
		var kills := 0.0
		var lost := 0.0
		var when := 0.0
		var played := 0
		for sd in range(1, _seeds + 1):
			var r: Array = _bench_one(db, m, id, sd)
			kills += float(r[0])
			lost += float(r[1])
			if float(r[2]) >= 0.0:
				when += float(r[2])
				played += 1
		var n := float(_seeds)
		print("%-20s %4d | %-30s | %5.1f | %.1f | %.1f" % [
			id, card.cost, ("t = %.0f s" % (when / played)) if played > 0 else "never (no crowd)", kills / n, lost / n, (kills / n - none_kills) / float(card.cost)])
	quit()


## Returns [kills, units lost, time the card was played (-1 = never)].
func _bench_one(db: ContentDb, m: MissionDefinition, card_id: String, seed_value: int) -> Array:
	var d := DeckDefinition.new()
	d.id = "tune_bench"
	d.card_ids = PackedStringArray()
	for i in 15:
		d.card_ids.append(card_id if not card_id.is_empty() else "rifle_squad")
	db.decks["tune_bench"] = d
	var mm: MissionDefinition = m.duplicate()
	mm.deck_id = "tune_bench"
	var b := BattleController.new()
	b.auto_step = false
	b.setup(db, mm, seed_value)
	b.points.cp = 99.0
	b.points.cap = 99.0
	var played_at := -1.0
	var ticks := 0
	while not b.is_ended():
		if played_at < 0.0 and not card_id.is_empty() and ticks % REACT_TICKS == 0:
			var card: CardDefinition = db.cards[card_id]
			var cell := _choose_cell(b, card, "mix")
			if cell.x > -999 and b.play_card(0, cell).ok:
				played_at = b.elapsed
		b.step(DT)
		ticks += 1
		b.points.cp = 99.0
	var out: Array = [b.stats["kills"], b.stats["units_lost"], played_at]
	b.free()
	return out
