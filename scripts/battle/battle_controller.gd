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

const TERRAIN_BY_CHAR: Dictionary = {
	MapDefinition.GRASS: IsoTileSet.TERRAIN_GRASS,
	MapDefinition.ROAD: IsoTileSet.TERRAIN_ROAD,
	MapDefinition.ROCK: IsoTileSet.TERRAIN_ROCK,
}


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

var _rules: MissionRules
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _deck_rng: RandomNumberGenerator = RandomNumberGenerator.new()  # separate so playing cards never shifts spawn jitter
var _ops_rng: RandomNumberGenerator = RandomNumberGenerator.new()  # shell scatter; also separate from spawn jitter
var _seed: int = 0  # seed of the current battle; restart replays it
var _next_uid: int = 1
var _wave_spawned: Array[int] = []
var _waypoints: Array[Vector2] = []
var _pending: Array[Hit] = []

var _ground: TileMapLayer
var _decals: Node2D
var _shadows: Node2D
var _entities: Node2D
var _air: Node2D
var _fx: Node2D
var _highlight: IsoCellHighlight
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


func _enemy_phase(delta: float) -> void:
	var candidates: Array[TargetCandidate] = []
	var by_id: Dictionary = {}  # target id -> entity
	if core.is_alive():
		candidates.append(TargetCandidate.new(CORE_ID, core.ground_pos))
		by_id[CORE_ID] = core
	for u in units:
		if u.is_alive() and not u.def.is_air():  # ground enemies cannot hit aircraft
			candidates.append(TargetCandidate.new(u.uid, u.ground_pos))
			by_id[u.uid] = u
	for e in enemies:
		if not e.is_alive():
			continue
		var tid := TargetingService.pick(e.ground_pos, e.def.attack_range, candidates)
		if tid != TargetingService.NO_TARGET:
			var target: Object = by_id[tid]
			e.face_toward((target as IsoEntity).ground_pos)
			if e.attack_state.tick(delta, true):
				var armor: float = (target as BattleUnit).def.armor if target is BattleUnit else 0.0
				_pending.append(Hit.new(target, DamageService.compute(e.def.attack_damage, armor)))
		else:
			e.attack_state.tick(delta, false)
			e.advance_path(delta)


func _unit_phase(delta: float) -> void:
	var candidates: Array[TargetCandidate] = []
	var by_id: Dictionary = {}
	for e in enemies:
		if e.is_alive():
			candidates.append(TargetCandidate.new(e.uid, e.ground_pos))
			by_id[e.uid] = e
	for u in units:
		if not u.is_alive():
			continue
		if u.weapon == null:  # a structure: nothing to move or fire
			continue
		u.advance_move(delta)
		var tid := TargetingService.NO_TARGET
		if not u.is_moving():  # units must stand still to fire
			tid = TargetingService.pick(u.ground_pos, u.weapon.range_tiles, candidates)
		if u.weapon_state.tick(delta, tid != TargetingService.NO_TARGET):
			_fire(u, u.weapon, by_id[tid])
		if u is BattleAircraft:
			_fire_secondary(u as BattleAircraft, delta, candidates, by_id)


## The aircraft's second weapon (missiles): own range, cooldown and limited ammo. It may fire on the move, so the
## gunship empties its missiles on the way in and then hovers to use its guns.
func _fire_secondary(u: BattleAircraft, delta: float, candidates: Array[TargetCandidate], by_id: Dictionary) -> void:
	if not u.secondary_ready_to_fire():
		return
	var tid := TargetingService.NO_TARGET
	if not u.is_moving() or u.secondary.can_fire_moving:
		tid = TargetingService.pick(u.ground_pos, u.secondary.range_tiles, candidates)
	if u.secondary_state.tick(delta, tid != TargetingService.NO_TARGET):
		if u.secondary_ammo > 0:
			u.secondary_ammo -= 1
		_fire(u, u.secondary, by_id[tid])


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
	for e in enemies:
		if not e.is_alive():
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
		if not e.is_alive():
			enemies.remove_at(i)
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


# --- player input / orders -----------------------------------------------------------------------

## Orders every mobile unit to walk to the centre of `cell`. Returns how many accepted the order.
func order_move_all(cell: Vector2i) -> int:
	if mission == null or not mission.map.is_walkable(cell) or cell == mission.core_cell:
		return 0
	var n := 0
	for u in units:
		if u.def.is_air():
			continue  # sortie aircraft follow their own flight plan
		if u.order_move(IsoProjection.cell_center(cell)):
			n += 1
	return n


func _unhandled_input(event: InputEvent) -> void:
	if mission == null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not is_ended():
		if targeting.is_selecting():
			confirm_at(IsoPicking.cell_under_mouse(self))
		else:
			order_move_all(IsoPicking.cell_under_mouse(self))
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
	_highlight.visible = preview == null and mission.map.is_walkable(cell) and not is_ended()
	_highlight.cell = cell
	_preview_node.show_preview(preview, IsoProjection.cell_center(mission.core_cell), mission.deploy_radius)
	_update_core_fade(delta)


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


## Cells holding the core or a living player unit (deployments cannot be placed there).
func occupied_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = [mission.core_cell]
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
	_highlight = IsoCellHighlight.new()
	_highlight.name = "HoverHighlight"
	_decals.add_child(_highlight)
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
	core = null
	_ground.clear()


func _build_map() -> void:
	var map := mission.map
	for y in map.height():
		for x in map.width():
			var cell := Vector2i(x, y)
			_ground.set_cell(cell, IsoTileSet.SOURCE_ID, TERRAIN_BY_CHAR[map.terrain_char(cell)])


func _spawn_core() -> void:
	core = BattleCore.new()
	core.name = "Core"
	core.setup_core(mission.core_cell, mission.core_health)
	_entities.add_child(core)


func _spawn_unit_at(unit_id: String, ground: Vector2) -> BattleUnit:
	var def := db.unit(unit_id)
	var u: BattleUnit = BattleAircraft.new() if def.is_air() else BattleUnit.new()
	if u is BattleAircraft and not def.secondary_weapon_id.is_empty():
		(u as BattleAircraft).setup_secondary(db.weapon(def.secondary_weapon_id))
	u.name = "Unit%d" % _next_uid
	u.setup(_next_uid, def, db.weapon(def.weapon_id), IsoProjection.cell_of(ground))
	u.ground_pos = ground
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
