class_name BattleController
extends Node2D
## Owns one battle. `step(delta)` is the whole simulation tick (driven by _physics_process; tests call it
## directly). Fixed order, see docs/specs/combat-vertical-slice.md:
##   1 clock + card economy + spawns  2 enemies  3 player units, then projectiles  4 apply damage, remove the dead  5 mission rules
## All rules run in ground space. Presentation (tracers, HUD) only reacts to signals/state.

signal battle_started
signal battle_ended(result: MissionRules.Result)
## Presentation hooks (see BattleFeedback). Emitted by the simulation; nothing listens for rules.
signal shot_fired(shooter: BattleUnit, target: BattleEnemy)
## An effective hit (the target was alive before it). `target` is a BattleUnit, BattleEnemy or BattleCore.
signal hit_landed(target: Node, amount: float)
## Emitted after the entity left the simulation, just before its death collapse starts.
signal enemy_died(enemy: BattleEnemy)
signal unit_died(unit: BattleUnit)
signal core_damaged(amount: float)
## An enemy's attack landed on `target` (a BattleUnit or the BattleCore); used to draw spat acid and the like.
signal enemy_attacked(enemy: BattleEnemy, target: Node)
## An area weapon went off at `center` (ground position, tiles) with the given ground radius.
signal blast_landed(center: Vector2, radius: float)
## A card was played successfully (units are already in the battle).
signal card_played(card: CardDefinition, cell: Vector2i)
## A strike was called: `center` is the ground target, `reach` the outer edge of the danger zone (tiles).
signal strike_called(center: Vector2, reach: float, duration: float)
## A unit launched a projectile weapon (missile) at `target_ground`; the projectile flies and explodes later.
signal projectile_launched(shooter: BattleUnit, weapon: WeaponDefinition, from_ground: Vector2, target_ground: Vector2)
## A play was refused (no CP, locked, bad cell...). `slot` is the hand slot; the result says why.
signal card_rejected(slot: int, result: CardPlayService.Result)

const SPAWN_JITTER: float = 1.0  # tiles
const LANE_JITTER: float = 0.9
const CORE_ID: int = 0  # target id of the core; unit ids start at 1
const DEATH_COLLAPSE_S: float = 0.3
const MIN_PROJECTILE_FLIGHT_S: float = 0.1
const SORTIE_MARGIN: float = 5.0  # tiles beyond the map edge where aircraft appear and disappear


## A called-in strike's telegraph (the danger circle on the ground) while its shells are still coming.
class Strike:
	extends RefCounted
	var center: Vector2
	var reach: float
	var scatter: float
	var duration: float
	var time_left: float
	var warning_s: float

	func _init(p_center: Vector2, p_reach: float, p_scatter: float, p_duration: float, p_warning: float) -> void:
		center = p_center
		reach = p_reach
		scatter = p_scatter
		duration = p_duration
		time_left = p_duration
		warning_s = p_warning


## One aircraft on a sortie: the flight state machine, where it leaves to, and the aircraft itself.
class Sortie:
	extends RefCounted
	var unit: BattleAircraft
	var flight: SortieFlight
	var exit: Vector2

	func _init(p_unit: BattleAircraft, p_flight: SortieFlight, p_exit: Vector2) -> void:
		unit = p_unit
		flight = p_flight
		exit = p_exit


class Hit:
	extends RefCounted
	var target: Object  # BattleUnit | BattleEnemy | BattleCore
	var amount: float

	func _init(p_target: Object, p_amount: float) -> void:
		target = p_target
		amount = p_amount


@export var mission_id: String = "m1_hold_the_crossing"
@export var rng_seed: int = 1337

## Tests set this false so the controller only advances when `step` is called.
var auto_step: bool = true

var db: ContentDb
var mission: MissionDefinition
var elapsed: float = 0.0
var stats: Dictionary = {"spawned": 0, "kills": 0, "shots": 0, "units_lost": 0}
var core: BattleCore
var units: Array[BattleUnit] = []
var enemies: Array[BattleEnemy] = []
## Card economy; both null in missions without a deck_id. Ticked inside step(), mutated only by play_card().
var deck: DeckState
var points: CommandPoints
## Which hand slot is selected for placement (state only; the HUD and the world preview read it).
var targeting: CardTargeting = CardTargeting.new()
## Arcing shells in flight (artillery) and the telegraphs of strikes that are still landing.
var projectiles: ProjectileSystem = ProjectileSystem.new()
var strikes: Array[Strike] = []
## Aircraft currently flying a sortie (they are also in `units`).
var sorties: Array[Sortie] = []
## Preview of the selected card over the cell under the mouse; null when nothing is selected. Updated every frame.
var preview: CardTargeting.Preview

## Decorations of the current map (see _spawn_scenery) and the cells they occupy.
var scenery_nodes: Array[BattleScenery] = []
## The decorations' ground shadows (one node on the Shadows layer); the Atmosphere dims it with the time of day.
var scenery_shadows: SceneryShadows
var _scenery_cells: Array[Vector2i] = []
var _fade_pieces: Array[BattleScenery] = []  # the pieces that can fade
var _fade_lookup: Dictionary = {}  # cell -> Array[BattleScenery]: pieces that could hide something standing on that cell
var _fade_clock: float = 0.0

var _rules: MissionRules
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _deck_rng: RandomNumberGenerator = RandomNumberGenerator.new()  # separate so playing cards never shifts spawn jitter
var _ops_rng: RandomNumberGenerator = RandomNumberGenerator.new()  # shell scatter; also separate from spawn jitter
var _seed: int = 0  # seed of the current battle; restart replays it
var _next_uid: int = 1
var _wave_spawned: Array[int] = []
var _waypoints: Array[Vector2] = []
var _pending: Array[Hit] = []
var _enemy_index: EnemyIndex = EnemyIndex.new()  # filled by the enemy phase; queried by unit targeting and blasts
var _enemy_index_valid: bool = false  # false once `enemies` changed after the index was built
var _target_pos: PackedVector2Array = PackedVector2Array()  # what enemies can hit this tick (ground units), reused
var _target_id: PackedInt32Array = PackedInt32Array()
var _target_obj: Array[BattleUnit] = []
var _front_pos: Vector2 = Vector2.ZERO  # the enemy closest to the core after this tick's movement (for ADVANCE units)
var _has_front: bool = false
var _blocked_cells: Dictionary = {}  # scenery cells (cell -> true): units do not walk through them

var _ground: TileMapLayer
var _decals: Node2D
var _shadows: Node2D
var _entities: Node2D
var _air: Node2D
var _fx: Node2D
var _preview_node: CardPreview
var _camera: IsoCamera


## Parses launch options given after `--`, e.g. `godot --path . -- --mission=s1_stress_horde --seed=5`.
## Unknown or malformed options are ignored. Returns {"mission": String?, "seed": int?} with only the keys given.
static func parse_user_args(args: PackedStringArray) -> Dictionary:
	var out: Dictionary = {}
	for a in args:
		if a.begins_with("--mission="):
			var id := a.trim_prefix("--mission=")
			if not id.is_empty():
				out["mission"] = id
		elif a.begins_with("--seed="):
			var v := a.trim_prefix("--seed=")
			if v.is_valid_int():
				out["seed"] = v.to_int()
	return out


func _ready() -> void:
	if mission != null:
		return  # already set up by a test or caller
	var cli := parse_user_args(OS.get_cmdline_user_args())
	if cli.has("mission"):
		mission_id = cli["mission"]
	if cli.has("seed"):
		rng_seed = cli["seed"]
	var loaded := ContentDb.load_from()
	if not loaded.is_valid():
		_show_fatal("Content errors:\n" + "\n".join(loaded.errors))
		return
	var m := loaded.mission(mission_id)
	if m == null:
		_show_fatal("Unknown mission id '%s'" % mission_id)
		return
	setup(loaded, m, rng_seed)
	var hud := BattleHud.new()
	add_child(hud)
	hud.bind(self)
	if has_cards():
		var hand_ui := HandUi.new()
		hand_ui.name = "HandUi"
		add_child(hand_ui)
		hand_ui.bind(self)
	var panel := ResultPanel.new()
	add_child(panel)
	panel.bind(self)
	var feedback := BattleFeedback.new()
	feedback.name = "Feedback"
	add_child(feedback)
	feedback.bind(self)
	var atmosphere := Atmosphere.new()
	atmosphere.name = "Atmosphere"
	add_child(atmosphere)
	atmosphere.bind(self)


## Builds (or rebuilds) the whole battle from validated data. Safe to call again to restart.
func setup(p_db: ContentDb, p_mission: MissionDefinition, p_seed: int) -> void:
	db = p_db
	mission = p_mission
	_ensure_layers()
	_clear_dynamic()
	_seed = p_seed
	_rng.seed = p_seed
	_deck_rng.seed = p_seed * 7919 + 13
	_ops_rng.seed = p_seed * 104729 + 7
	projectiles.clear()
	strikes.clear()
	sorties.clear()
	elapsed = 0.0
	stats = {"spawned": 0, "kills": 0, "shots": 0, "units_lost": 0}
	_next_uid = 1
	_pending.clear()
	_wave_spawned.clear()
	for i in mission.waves.size():
		_wave_spawned.append(0)
	_waypoints.clear()
	for c in mission.path_cells:
		_waypoints.append(IsoProjection.cell_center(c))
	_rules = MissionRules.new(mission.duration_s)
	_rules.ended.connect(_on_rules_ended)
	_build_map()
	_spawn_scenery()
	_spawn_core()
	for su in mission.start_units:
		_spawn_unit_at(su.unit_id, IsoProjection.cell_center(su.cell))
	_setup_cards()
	if _camera != null and is_inside_tree():
		_camera.position = IsoProjection.ground_to_screen(Vector2(mission.map.width(), mission.map.height()) * 0.5)
	battle_started.emit()


func restart() -> void:
	if db != null and mission != null:
		setup(db, mission, _seed)


# --- queries (read by HUD / tests) -------------------------------------------------------------

func is_ended() -> bool:
	return _rules != null and _rules.is_ended()


func result() -> MissionRules.Result:
	return _rules.result() if _rules != null else null


## Layer for transient effects (tracers, flashes, sparks); cleared on restart.
func fx_layer() -> Node2D:
	return _fx


## Ground layer under the shadows for permanent marks (scorch under wrecks); cleared on restart.
func decal_layer() -> Node2D:
	return _decals


func camera_node() -> IsoCamera:
	return _camera


func time_left() -> float:
	return maxf(mission.duration_s - elapsed, 0.0) if mission != null else 0.0


func enemy_count() -> int:
	return enemies.size()


# --- simulation ----------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if auto_step:
		step(delta)


func step(delta: float) -> void:
	if _rules == null or _rules.is_ended() or delta <= 0.0:
		return
	# 1. clock + card economy + spawns
	elapsed += delta
	if deck != null:
		deck.tick(delta)
		points.tick(delta)
	_spawn_due_enemies()
	_pending.clear()
	# 2. enemies, 3. player units (both only *queue* damage)
	_enemy_phase(delta)
	_unit_phase(delta)
	_sortie_phase(delta)
	_projectile_phase(delta)
	# 4. apply all damage, then remove the dead
	_apply_damage()
	# 5. mission rules, after all damage and deaths of this tick
	_rules.evaluate(core.health.hp, elapsed)


func _spawn_due_enemies() -> void:
	for i in mission.waves.size():
		var w := mission.waves[i]
		if elapsed < w.start_s:
			continue
		var due := w.count
		if w.interval_s > 0.0:
			due = mini(w.count, int(floor((elapsed - w.start_s) / w.interval_s)) + 1)
		while _wave_spawned[i] < due:
			_spawn_enemy(w)
			_wave_spawned[i] += 1


## Each enemy attacks the nearest thing in its attack range (smallest ground distance, ties to the lowest target id; the
## core is id 0) or else walks on. The same rule as TargetingService.pick, but without building a candidate object per
## target per tick and with cheap rejects: an enemy outside the box around all targets (grown by its range) cannot hit
## anything. Also fills the enemy index (after the enemy moved) that unit targeting and blasts use later in the tick.
func _enemy_phase(delta: float) -> void:
	_target_pos.clear()
	_target_id.clear()
	_target_obj.clear()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for u in units:
		if u.is_alive() and not u.def.is_air():  # ground enemies cannot hit aircraft
			var up := u.ground_pos
			_target_pos.append(up)
			_target_id.append(u.uid)
			_target_obj.append(u)
			lo = lo.min(up)
			hi = hi.max(up)
	var unit_targets := _target_pos.size()
	var core_alive := core.is_alive()
	var core_pos := core.ground_pos
	var core_radius := core.radius
	_enemy_index.begin(float(mission.map.width()), float(mission.map.height()))
	_has_front = false
	var front_d2 := INF
	for e in enemies:
		if e.health.hp <= 0.0:
			continue
		var ep := e.ground_pos
		var reach := e.def.attack_range
		var reach2 := reach * reach
		var target: Object = null
		var best_id := TargetingService.NO_TARGET
		var best_d2 := reach2
		if core_alive:
			var to_core := ep - core_pos
			var margin := reach + core_radius + 0.001
			if to_core.length_squared() <= margin * margin:
				# the core's walls reach `radius` out: aim at the nearest point of them
				var aim := core_pos + to_core.limit_length(core_radius) if core_radius > 0.0 else core_pos
				var d2 := ep.distance_squared_to(aim)
				if d2 <= reach2:
					target = core
					best_id = CORE_ID
					best_d2 = d2
		if unit_targets > 0 and ep.x >= lo.x - reach - 0.001 and ep.x <= hi.x + reach + 0.001 and ep.y >= lo.y - reach - 0.001 and ep.y <= hi.y + reach + 0.001:
			for k in unit_targets:
				var du2 := ep.distance_squared_to(_target_pos[k])
				if du2 > reach2:
					continue
				if target == null or du2 < best_d2 or (du2 == best_d2 and _target_id[k] < best_id):
					target = _target_obj[k]
					best_id = _target_id[k]
					best_d2 = du2
		if target != null:
			e.face_toward((target as IsoEntity).ground_pos)
			if e.attack_state.tick(delta, true):
				var armor: float = (target as BattleUnit).def.armor if target is BattleUnit else 0.0
				_pending.append(Hit.new(target, DamageService.compute(e.def.attack_damage, armor)))
				enemy_attacked.emit(e, target)
		else:
			e.attack_state.tick(delta, false)
			e.advance_path(delta)
		_enemy_index.add(e, e.ground_pos)
		var core_d2 := e.ground_pos.distance_squared_to(core_pos)
		if core_d2 < front_d2:
			front_d2 = core_d2
			_front_pos = e.ground_pos
			_has_front = true
	_enemy_index_valid = true


func _unit_phase(delta: float) -> void:
	for u in units:
		if not u.is_alive():
			continue
		if u.weapon == null:  # a structure: nothing to move or fire
			continue
		var target: BattleEnemy = null
		if u.def.is_air():  # sortie aircraft follow their flight plan, not the unit brain
			u.advance_move(delta)
			if not u.is_moving():  # units must stand still to fire
				target = _nearest_enemy(u.ground_pos, u.weapon.range_tiles)
		else:
			target = _think_and_move(u, delta)
		if u.weapon_state.tick(delta, target != null):
			_fire(u, u.weapon, target)
		if u is BattleAircraft:
			_fire_secondary(u as BattleAircraft, delta)


## One ground unit's tick: the brain decides (stay, or walk to a spot), the unit walks, and the enemy it may shoot at
## afterwards is returned (null while it is still walking: units must stand still to fire).
func _think_and_move(u: BattleUnit, delta: float) -> BattleEnemy:
	var weapon_range := u.weapon.range_tiles
	var target := _pick_target(u)
	var decision: UnitBrain.Decision = null
	if _should_retreat(u):
		decision = UnitBrain.retreat(u.ground_pos, core.ground_pos, _nearest_enemy(u.ground_pos, UnitBrain.RETREAT_DANGER) != null)
	else:
		match u.def.effective_behavior():
			UnitBrain.Behavior.GUARD:
				var engage := _nearest_enemy(u.anchor, u.def.leash + weapon_range * UnitBrain.RANGE_MARGIN)
				var cover := _structure_positions() if u.def.seeks_cover and engage != null else PackedVector2Array()
				var threatened := not cover.is_empty() and _nearest_enemy(u.ground_pos, UnitBrain.COVER_ABORT) != null
				decision = UnitBrain.guard(u.ground_pos, u.anchor, weapon_range, u.def.leash, target != null, engage != null, engage.ground_pos if engage != null else Vector2.ZERO, cover, threatened)
			UnitBrain.Behavior.ADVANCE:
				decision = UnitBrain.advance(u.ground_pos, core.ground_pos, weapon_range, u.def.advance_limit, target != null, _has_front, _front_pos)
			UnitBrain.Behavior.SUPPORT:
				var friend := _nearest_friend(u)
				decision = UnitBrain.support(u.ground_pos, friend != null, friend.ground_pos if friend != null else Vector2.ZERO)
	if decision != null:
		_carry_out(u, decision)
	var before := u.ground_pos
	u.advance_move(delta)
	if u.is_moving():
		return null
	if u.ground_pos != before:  # it arrived this tick: the target may have changed
		target = _pick_target(u)
	return target


## Focus fire (when the unit has the habit): the most dangerous enemy in range, else the nearest.
func _pick_target(u: BattleUnit) -> BattleEnemy:
	if u.def.focus_fire:
		return _index_ready().best_in_range(u.ground_pos, u.weapon.range_tiles, u.weapon.anti_armor)
	return _nearest_enemy(u.ground_pos, u.weapon.range_tiles)


## True for a mobile unit with the retreat habit whose health fraction is below its threshold.
func _should_retreat(u: BattleUnit) -> bool:
	return u.def.retreats and not u.def.is_fixed() and u.health.fraction() < u.def.retreat_below


## Positions of the living friendly structures (what a unit may take cover behind).
func _structure_positions() -> PackedVector2Array:
	var out := PackedVector2Array()
	for o in units:
		if o.def.structure and o.is_alive():
			out.append(o.ground_pos)
	return out


func _carry_out(u: BattleUnit, d: UnitBrain.Decision) -> void:
	if d.action == UnitBrain.Action.STAY:
		if u.is_moving():
			u.stop()
		return
	if u.is_moving() and u.move_target().distance_squared_to(d.dest) < 0.0625:
		return  # already walking to (about) there
	if not _walk_is_clear(u.ground_pos, d.dest):
		if u.is_moving():
			u.stop()
		return
	u.order_move(d.dest)


## True if the straight walk from `a` to `b` stays on walkable ground, off scenery and off the core's cell.
func _walk_is_clear(a: Vector2, b: Vector2) -> bool:
	var n := maxi(1, ceili(a.distance_to(b) / 0.25))
	for i in n + 1:
		var cell := IsoProjection.cell_of(a.lerp(b, float(i) / n))
		if not mission.map.is_walkable(cell) or cell == mission.core_cell or _blocked_cells.has(cell):
			return false
	return true


## The nearest living friendly ground fighter (not a support unit itself) within the unit's follow range, or null.
func _nearest_friend(u: BattleUnit) -> BattleUnit:
	var best: BattleUnit = null
	var best_d2 := u.def.follow_range * u.def.follow_range
	for o in units:
		if o == u or not o.is_alive() or o.weapon == null or o.def.is_air() or o.def.effective_behavior() == UnitBrain.Behavior.SUPPORT:
			continue
		var d2 := u.ground_pos.distance_squared_to(o.ground_pos)
		if d2 < best_d2 or (d2 == best_d2 and best != null and o.uid < best.uid):
			best = o
			best_d2 = d2
	return best


## The aircraft's second weapon (missiles): own range, cooldown and limited ammo. It may fire on the move, so the
## gunship empties its missiles on the way in and then hovers to use its guns.
func _fire_secondary(u: BattleAircraft, delta: float) -> void:
	if not u.secondary_ready_to_fire():
		return
	var target: BattleEnemy = null
	if not u.is_moving() or u.secondary.can_fire_moving:
		target = _nearest_enemy(u.ground_pos, u.secondary.range_tiles)
	if u.secondary_state.tick(delta, target != null):
		if u.secondary_ammo > 0:
			u.secondary_ammo -= 1
		_fire(u, u.secondary, target)


## The nearest living enemy within `range_tiles` of `origin` (ties to the lowest uid), or null.
func _nearest_enemy(origin: Vector2, range_tiles: float) -> BattleEnemy:
	return _index_ready().nearest(origin, range_tiles)


## The enemy index, rebuilt from `enemies` only if it is stale (normally the enemy phase just filled it).
func _index_ready() -> EnemyIndex:
	if not _enemy_index_valid:
		_enemy_index.begin(float(mission.map.width()), float(mission.map.height()))
		for e in enemies:
			if e.health.hp > 0.0:
				_enemy_index.add(e, e.ground_pos)
		_enemy_index_valid = true
	return _enemy_index


## One shot: hitscan weapons queue their damage now (area damage if they have a blast radius); projectile
## weapons launch a projectile that explodes where the target stood when it was fired.
func _fire(u: BattleUnit, weapon: WeaponDefinition, target: BattleEnemy) -> void:
	if not u.is_moving():
		u.face_toward(target.ground_pos)  # a moving unit keeps facing its direction of travel
	stats["shots"] += 1
	if weapon.delivery == WeaponDefinition.Delivery.PROJECTILE:
		var to := target.ground_pos
		var from := u.ground_pos
		if u is BattleAircraft:
			from = (u as BattleAircraft).next_pylon_ground()  # missiles hang under the wings, not the fuselage
		var flight := maxf(from.distance_to(to) / weapon.projectile_speed, MIN_PROJECTILE_FLIGHT_S)
		projectiles.spawn(from, to, flight, weapon.projectile_arc, weapon.damage, weapon.blast_radius, 0.0, u.altitude, ProjectileSystem.KIND_MISSILE, weapon.projectile_accel, weapon.projectile_drop)
		projectile_launched.emit(u, weapon, from, to)
		return
	if weapon.blast_radius > 0.0:
		_queue_blast(target.ground_pos, weapon.damage, weapon.blast_radius)
	else:
		_pending.append(Hit.new(target, DamageService.compute(weapon.damage, target.def.armor)))
	shot_fired.emit(u, target)


## Area damage on the ground plane: every living enemy within the radius takes the weapon's damage
## with armor, then distance falloff. Friendly fire is off (only enemies are hit).
func _queue_blast(center: Vector2, damage: float, radius: float) -> void:
	var index := _index_ready()
	for i in index.box_candidates(center, radius):  # only enemies in the cells around the blast, in `enemies` order
		var e := index.enemy_at(i)
		if e.health.hp <= 0.0:
			continue
		var falloff := DamageService.blast_falloff(e.ground_pos.distance_to(center), radius)
		if falloff > 0.0:
			_pending.append(Hit.new(e, DamageService.compute(damage, e.def.armor, falloff)))
	blast_landed.emit(center, radius)


## Drives every sortie aircraft through enter -> hold station -> leave -> gone. Leaving the map is not a loss:
## the aircraft is simply removed (no death signal, no units_lost).
func _sortie_phase(delta: float) -> void:
	for i in range(sorties.size() - 1, -1, -1):
		var s := sorties[i]
		var before := s.flight.phase
		var after := s.flight.update(delta, s.unit.is_moving())
		if after == before:
			continue
		if after == SortieFlight.Phase.LEAVING:
			s.unit.order_move(s.exit)
		elif after == SortieFlight.Phase.DONE:
			sorties.remove_at(i)
			_retire_aircraft(s.unit)


func _retire_aircraft(u: BattleAircraft) -> void:
	units.erase(u)
	for item in [u.shadow, u]:
		if item != null and is_instance_valid(item):
			var n: Node = item
			var p: Node = n.get_parent()
			if p != null:
				p.remove_child(n)
			n.free()


## Moves the shells in flight; each one that lands queues an area hit like any other blast. Strike telegraphs
## expire once their last shell has landed.
func _projectile_phase(delta: float) -> void:
	for imp in projectiles.tick(delta):
		_queue_blast(imp.ground_pos, imp.damage, imp.radius)
	for i in range(strikes.size() - 1, -1, -1):
		strikes[i].time_left -= delta
		if strikes[i].time_left <= 0.0:
			strikes.remove_at(i)


func _apply_damage() -> void:
	for h in _pending:
		var target: Object = h.target
		var health: Health = target.health
		var was_alive := not health.is_dead()
		health.take_damage(h.amount)
		if was_alive:
			hit_landed.emit(target, h.amount)
			if target is BattleCore:
				core_damaged.emit(h.amount)
	_pending.clear()
	# Remove the dead only after every hit this tick has landed.
	for i in range(enemies.size() - 1, -1, -1):
		var e := enemies[i]
		if e.health.hp <= 0.0:
			enemies.remove_at(i)
			_enemy_index_valid = false
			stats["kills"] += 1
			enemy_died.emit(e)
			_dispose(e, e.shadow)
	var blasts: Array[Array] = []  # volatile structures that just died: [ground_pos, damage, radius]
	for i in range(units.size() - 1, -1, -1):
		var u := units[i]
		if not u.is_alive():
			units.remove_at(i)
			stats["units_lost"] += 1
			if u.def.has_death_blast():
				blasts.append([u.ground_pos, u.def.death_blast_damage, u.def.death_blast_radius])
			unit_died.emit(u)
			_dispose(u, u.shadow)
	for b in blasts:
		_queue_blast(b[0], b[1], b[2])
	if not _pending.is_empty():  # the blasts' hits (they may kill more enemies, or are not applied until now)
		_apply_damage()


func _on_rules_ended(res: MissionRules.Result) -> void:
	targeting.cancel()
	battle_ended.emit(res)


# --- player input -------------------------------------------------------------------------------

## The player gives no move orders: placed units act on their own (ADR-013, UnitBrain). Input here is cards only.
func _unhandled_input(event: InputEvent) -> void:
	if mission == null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not is_ended():
		if targeting.is_selecting():
			confirm_at(IsoPicking.cell_under_mouse(self))
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		cancel_selection()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		cancel_selection()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		restart()
	elif event is InputEventKey and event.pressed and not event.echo and deck != null and not is_ended():
		var slot: int = event.keycode - KEY_1  # 1..9 select hand slots 0..8
		if slot >= 0 and slot < 9:
			select_slot(slot)


func _process(delta: float) -> void:
	if mission == null or not is_inside_tree():
		return
	var cell := IsoPicking.cell_under_mouse(self)
	if deck != null:
		targeting.sync(deck)
	preview = targeting.preview(self, cell) if not is_ended() else null
	_preview_node.show_preview(preview, IsoProjection.cell_center(mission.core_cell), mission.deploy_radius)
	_update_core_fade(delta)
	update_scenery_fade(delta)


## The core is tall: fade it when a unit or enemy is behind it (ADR-005).
func _update_core_fade(delta: float) -> void:
	var faded := false
	var rect := core.world_rect()
	for u in units:
		if IsoOcclusion.is_occluding(core.ground_pos, rect, u.ground_pos, u.world_rect()):
			faded = true
			break
	if not faded:
		for e in enemies:
			if IsoOcclusion.is_occluding(core.ground_pos, rect, e.ground_pos, e.world_rect()):
				faded = true
				break
	core.update_fade(faded, delta)


# --- cards ---------------------------------------------------------------------------------------

func has_cards() -> bool:
	return deck != null


## Cells under the core's walls (its radius), other than the core cell itself; nothing can be built there.
func _core_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if core == null or core.radius <= 0.0:
		return out
	var r := int(ceil(core.radius + 0.5))
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var c := mission.core_cell + Vector2i(dx, dy)
			if c != mission.core_cell and IsoProjection.cell_center(c).distance_to(core.ground_pos) <= core.radius + 0.5:
				out.append(c)
	return out


## Cells holding the core or a living player unit (deployments cannot be placed there).
func occupied_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = [mission.core_cell]
	out.append_array(_core_cells())
	out.append_array(_scenery_cells)
	for u in units:
		if u.is_alive() and not u.def.is_air():
			out.append(IsoProjection.cell_of(u.ground_pos))
	return out


## Would the card in hand slot `hand_index` be accepted on `cell`? Never changes state.
func check_card(hand_index: int, cell: Vector2i) -> CardPlayService.Result:
	if deck == null or is_ended():
		return CardPlayService.Result.new(CardPlayService.Reason.UNAVAILABLE)
	var def: CardDefinition = cards_by_id().get(deck.card_at(hand_index))
	var placement := PlacementRules.Reason.OK
	if def != null:
		match def.card_kind:
			CardDefinition.CardKind.DEPLOYMENT:
				placement = PlacementRules.check_deploy(mission.map, cell, mission.core_cell, mission.deploy_radius, occupied_cells())
			CardDefinition.CardKind.OPERATION, CardDefinition.CardKind.SORTIE:
				placement = PlacementRules.check_ground_target(mission.map, cell)
	var res := CardPlayService.check(deck, points, cards_by_id(), hand_index, placement == PlacementRules.Reason.OK)
	res.placement = placement
	return res


## Plays the card in hand slot `hand_index` on `cell`: validates, then spends CP, discards the card, starts its
## lockout and spawns the units. A rejected play changes nothing.
func play_card(hand_index: int, cell: Vector2i) -> CardPlayService.Result:
	var check := check_card(hand_index, cell)
	if not check.ok:
		return check
	var res := CardPlayService.try_play(deck, points, cards_by_id(), hand_index, true)
	res.placement = PlacementRules.Reason.OK
	var card := res.card
	var centre := IsoProjection.cell_center(cell)
	if card.card_kind == CardDefinition.CardKind.OPERATION:
		_start_strike(db.operation(card.effect_id), centre)
	elif card.card_kind == CardDefinition.CardKind.SORTIE:
		_launch_sortie(card, centre)
	else:
		for off in PlacementRules.formation_offsets(card.unit_count):
			_spawn_unit_at(card.unit_id, centre + off)
	card_played.emit(card, cell)
	return res


## Sends the card's aircraft in from the nearest map edge to hold station over `center`, then out the other side.
func _launch_sortie(card: CardDefinition, center: Vector2) -> void:
	var plan := SortiePlan.plan(float(mission.map.width()), float(mission.map.height()), center, SORTIE_MARGIN)
	for k in card.unit_count:
		var lateral := (float(k) - float(card.unit_count - 1) * 0.5) * 1.5  # a flight of several fans out sideways
		var side := Vector2(0.0, lateral) if plan.edge == SortiePlan.Edge.LEFT or plan.edge == SortiePlan.Edge.RIGHT else Vector2(lateral, 0.0)
		var u := _spawn_unit_at(card.unit_id, plan.entry + side) as BattleAircraft
		u.order_move(plan.station + side)
		sorties.append(Sortie.new(u, SortieFlight.new(card.station_time_s), plan.exit + side))


## Calls in a barrage: picks the impact points now (seeded) and queues every shell with its launch delay.
func _start_strike(op: OperationDefinition, center: Vector2) -> void:
	var targets := op.shell_targets(center, _ops_rng)
	for i in targets.size():
		var delay := op.warning_s + float(i) * op.shell_interval_s
		projectiles.spawn(targets[i] + op.launch_offset, targets[i], op.flight_time_s, op.arc_height, op.shell_damage, op.blast_radius, delay)
	var duration := op.total_duration_s()
	strikes.append(Strike.new(center, op.reach_radius(), op.target_radius, duration, op.warning_s))
	strike_called.emit(center, op.reach_radius(), duration)


## Selects (or deselects, if already selected) a hand slot for placement.
func select_slot(slot: int) -> void:
	if deck == null or is_ended():
		return
	targeting.select(deck, slot)


func cancel_selection() -> void:
	targeting.cancel()


## Plays the selected card on `cell`. A success clears the selection; a refusal keeps it (so the player can try
## another cell) and emits `card_rejected`. Returns null when no card is selected.
func confirm_at(cell: Vector2i) -> CardPlayService.Result:
	if deck == null or not targeting.is_selecting():
		return null
	var slot := targeting.selected_slot
	var res := play_card(slot, cell)
	if res.ok:
		targeting.cancel()
	else:
		card_rejected.emit(slot, res)
		if res.reason == CardPlayService.Reason.EMPTY_SLOT or res.reason == CardPlayService.Reason.UNKNOWN_CARD:
			targeting.cancel()
	return res


func cards_by_id() -> Dictionary:
	return db.cards if db != null else {}


func _setup_cards() -> void:
	deck = null
	points = null
	targeting = CardTargeting.new()
	preview = null
	if mission.deck_id.is_empty() or db.deck_rules == null:
		return
	var d := db.deck(mission.deck_id)
	if d == null:
		return
	deck = DeckState.new(db.deck_rules, d.ids(), _deck_rng)
	deck.start()
	points = CommandPoints.from_rules(db.deck_rules)


# --- building the world --------------------------------------------------------------------------

func _ensure_layers() -> void:
	if _ground != null:
		return
	_ground = TileMapLayer.new()
	_ground.name = "Ground"
	_ground.tile_set = IsoTileSet.build()
	_ground.position = IsoProjection.TILEMAP_LAYER_OFFSET
	add_child(_ground)
	_decals = _add_layer("Decals", false)
	_shadows = _add_layer("Shadows", false)
	_entities = _add_layer("Entities", true)
	_air = _add_layer("Air", false)
	_fx = _add_layer("Fx", false)
	var telegraph := StrikeTelegraph.new()
	telegraph.name = "StrikeTelegraph"
	telegraph.bind(self)
	_decals.add_child(telegraph)
	_preview_node = CardPreview.new()
	_preview_node.name = "CardPreview"
	_decals.add_child(_preview_node)
	var shells := ProjectileView.new()
	shells.name = "Shells"
	shells.bind(self)
	_air.add_child(shells)
	_camera = IsoCamera.new()
	_camera.name = "Camera"
	add_child(_camera)
	if is_inside_tree():
		_camera.make_current()


func _add_layer(layer_name: String, y_sorted: bool) -> Node2D:
	var layer := Node2D.new()
	layer.name = layer_name
	layer.y_sort_enabled = y_sorted
	add_child(layer)
	return layer


func _clear_dynamic() -> void:
	for layer in [_entities, _shadows, _fx]:
		for child in layer.get_children():
			layer.remove_child(child)
			child.free()
	for child in _decals.get_children():  # the Decals layer also holds the persistent highlight/preview nodes
		if child is ScorchMark:
			_decals.remove_child(child)
			child.free()
	for child in _air.get_children():  # the Air layer also holds the persistent shell view; only aircraft go
		if child is BattleAircraft:
			_air.remove_child(child)
			child.free()
	units.clear()
	enemies.clear()
	_enemy_index_valid = false
	scenery_nodes.clear()
	scenery_shadows = null
	_scenery_cells.clear()
	_blocked_cells.clear()
	_fade_pieces.clear()
	_fade_lookup.clear()
	core = null
	_ground.clear()


func _build_map() -> void:
	var map := mission.map
	for y in map.height():
		for x in map.width():
			var cell := Vector2i(x, y)
			_ground.set_cell(cell, IsoTileSet.SOURCE_ID, IsoTileSet.coords_for(map.terrain_char(cell), cell))


## Places the map's decorations on the entity layer and remembers their cells and which of them can fade.
func _spawn_scenery() -> void:
	scenery_nodes.clear()
	_scenery_cells.clear()
	_blocked_cells.clear()
	_fade_pieces.clear()
	_fade_lookup.clear()
	for p in mission.map.placements():
		var def := db.scenery(p.scenery_id)
		if def == null:
			continue
		var node := BattleScenery.new()
		node.name = "Scenery%d" % scenery_nodes.size()
		node.setup_scenery(def, p.cell, p.facing)
		_entities.add_child(node)
		scenery_nodes.append(node)
		_scenery_cells.append_array(def.cells_at(p.cell))
		for c in def.cells_at(p.cell):
			_blocked_cells[c] = true
		if def.fades:
			_fade_pieces.append(node)
			_register_fade_cells(node)
	scenery_shadows = SceneryShadows.new()
	scenery_shadows.name = "SceneryShadows"
	_shadows.add_child(scenery_shadows)
	scenery_shadows.build(scenery_nodes)


const FADE_PERIOD_S: float = 0.1
const FADE_MARGIN_PX: float = 26.0  # slack around a piece's art when deciding which cells it can hide
const FADE_CELLS_BEHIND: int = 13  # a tall piece can hide cells this far behind it (smaller x + y)


## Remembers, for every cell behind the piece whose screen position lies under its art, that the piece can hide
## something standing there. Built once at setup so the per-frame test is one lookup per entity.
func _register_fade_cells(piece: BattleScenery) -> void:
	var rect := piece.world_rect().grow(FADE_MARGIN_PX)
	var anchor := IsoProjection.cell_of(piece.ground_pos)
	var key := IsoProjection.sort_key(piece.ground_pos)
	for dy in range(-FADE_CELLS_BEHIND, 2):
		for dx in range(-FADE_CELLS_BEHIND, 2):
			var c := anchor + Vector2i(dx, dy)
			var centre := IsoProjection.cell_center(c)
			if IsoProjection.sort_key(centre) > key + 0.001:
				continue
			if rect.has_point(IsoProjection.ground_to_screen(centre) + Vector2(0.0, -12.0)):
				if not _fade_lookup.has(c):
					_fade_lookup[c] = []
				_fade_lookup[c].append(piece)


## Fades the tall decorations that have a unit or enemy behind them (ADR-005). The occlusion test runs every
## FADE_PERIOD_S and only against the pieces registered for the cell each entity stands on; the alpha moves every frame.
func update_scenery_fade(delta: float) -> void:
	if _fade_pieces.is_empty():
		return
	_fade_clock += delta
	if _fade_clock >= FADE_PERIOD_S:
		_fade_clock = 0.0
		for piece in _fade_pieces:
			piece.faded = false
		for u in units:
			_mark_fading_over(u)
		for e in enemies:
			_mark_fading_over(e)
	for piece in _fade_pieces:
		piece.update_fade(delta)


func _mark_fading_over(subject: IsoEntity) -> void:
	var candidates: Array = _fade_lookup.get(IsoProjection.cell_of(subject.ground_pos), [])
	if candidates.is_empty():
		return
	var rect := subject.world_rect()
	for p in candidates:
		var piece := p as BattleScenery
		if not piece.faded and IsoOcclusion.is_occluding(piece.ground_pos, piece.world_rect(), subject.ground_pos, rect):
			piece.faded = true


func _spawn_core() -> void:
	core = BattleCore.new()
	core.name = "Core"
	core.setup_core(mission.core_cell, mission.core_health, db.scenery(mission.core_scenery_id) if not mission.core_scenery_id.is_empty() else null, mission.core_radius)
	_entities.add_child(core)


func _spawn_unit_at(unit_id: String, ground: Vector2) -> BattleUnit:
	var def := db.unit(unit_id)
	var u: BattleUnit = BattleAircraft.new() if def.is_air() else BattleUnit.new()
	if u is BattleAircraft and not def.secondary_weapon_id.is_empty():
		(u as BattleAircraft).setup_secondary(db.weapon(def.secondary_weapon_id))
	u.name = "Unit%d" % _next_uid
	u.setup(_next_uid, def, db.weapon(def.weapon_id), IsoProjection.cell_of(ground))
	u.ground_pos = ground
	u.anchor = ground
	if def.structure and not mission.spawn_cells.is_empty():
		u.face_toward(IsoProjection.cell_center(mission.spawn_cells[0]))  # its long side lies across the approach
	if u is BattleAircraft:
		(u as BattleAircraft).lift()
	_next_uid += 1
	(_air if u is BattleAircraft else _entities).add_child(u)  # aircraft are drawn above everything, unsorted
	u.shadow = _add_shadow(u, def.footprint_radius + 0.1)
	units.append(u)
	return u


func _spawn_enemy(w: WaveEntry) -> void:
	var def := db.enemy(w.enemy_id)
	var start := IsoProjection.cell_center(mission.spawn_cells[w.spawn_index]) + _jitter(SPAWN_JITTER)
	var lane := _jitter(LANE_JITTER)
	var path: Array[Vector2] = []
	for wp in _waypoints:
		path.append(wp + lane)
	var e := BattleEnemy.new()
	e.name = "Enemy%d" % _next_uid
	e.setup(_next_uid, def, start, path)
	_next_uid += 1
	_entities.add_child(e)
	e.shadow = _add_shadow(e, def.footprint_radius + 0.1)
	enemies.append(e)
	_enemy_index_valid = false
	stats["spawned"] += 1


func _jitter(radius: float) -> Vector2:
	var a := _rng.randf() * TAU
	var r := sqrt(_rng.randf()) * radius
	return Vector2(cos(a), sin(a)) * r


func _add_shadow(target: IsoEntity, radius_tiles: float) -> IsoShadow:
	var s := IsoShadow.new()
	s.target = target
	s.radius_tiles = radius_tiles
	_shadows.add_child(s)
	return s


## Retires an entity that already left the simulation. In the scene tree it plays its death collapse and
## frees itself; without a tree (tests) it is removed and freed immediately.
func _dispose(entity: IsoEntity, shadow: Node) -> void:
	if is_inside_tree():
		entity.play_death(DEATH_COLLAPSE_S, shadow)
		return
	for item in [entity, shadow]:
		if item == null:
			continue
		var n: Node = item
		var p: Node = n.get_parent()
		if p != null:
			p.remove_child(n)
		n.free()


func _show_fatal(message: String) -> void:
	push_error(message)
	var layer := CanvasLayer.new()
	var label := Label.new()
	label.text = message
	label.position = Vector2(24, 24)
	label.add_theme_color_override("font_color", Color(1, 0.5, 0.5))
	layer.add_child(label)
	add_child(layer)
