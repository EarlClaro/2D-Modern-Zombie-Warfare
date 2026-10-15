class_name BattleController
extends Node2D
## Owns one battle. `step(delta)` is the whole simulation tick (driven by _physics_process; tests call it
## directly). Fixed order, see docs/specs/combat-vertical-slice.md:
##   1 clock + spawns  2 enemies  3 player units  4 apply damage, remove the dead  5 mission rules
## All rules run in ground space. Presentation (tracers, HUD) only reacts to signals/state.

signal battle_started
signal battle_ended(result: MissionRules.Result)
signal shot_fired(from_world: Vector2, to_world: Vector2, weapon_id: String)
signal enemy_died(ground_pos: Vector2)
signal unit_died(ground_pos: Vector2)
signal core_damaged(amount: float)

const SPAWN_JITTER: float = 0.35  # tiles
const LANE_JITTER: float = 0.35
const CORE_ID: int = 0  # target id of the core; unit ids start at 1

const TERRAIN_BY_CHAR: Dictionary = {
	MapDefinition.GRASS: IsoTileSet.TERRAIN_GRASS,
	MapDefinition.ROAD: IsoTileSet.TERRAIN_ROAD,
	MapDefinition.ROCK: IsoTileSet.TERRAIN_ROCK,
}


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

var _rules: MissionRules
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _seed: int = 0  # seed of the current battle; restart replays it
var _next_uid: int = 1
var _wave_spawned: Array[int] = []
var _waypoints: Array[Vector2] = []
var _pending: Array[Hit] = []

var _ground: TileMapLayer
var _decals: Node2D
var _shadows: Node2D
var _entities: Node2D
var _fx: Node2D
var _highlight: IsoCellHighlight
var _camera: IsoCamera


func _ready() -> void:
	if mission != null:
		return  # already set up by a test or caller
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
	var panel := ResultPanel.new()
	add_child(panel)
	panel.bind(self)


## Builds (or rebuilds) the whole battle from validated data. Safe to call again to restart.
func setup(p_db: ContentDb, p_mission: MissionDefinition, p_seed: int) -> void:
	db = p_db
	mission = p_mission
	_ensure_layers()
	_clear_dynamic()
	_seed = p_seed
	_rng.seed = p_seed
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
		_spawn_unit(su)
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
	# 1. clock + spawns
	elapsed += delta
	_spawn_due_enemies()
	_pending.clear()
	# 2. enemies, 3. player units (both only *queue* damage)
	_enemy_phase(delta)
	_unit_phase(delta)
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
		if u.is_alive():
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
				_pending.append(Hit.new(target, DamageService.compute(e.def.attack_damage, 0.0)))
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
		u.advance_move(delta)
		var tid := TargetingService.NO_TARGET
		if not u.is_moving():  # units must stand still to fire
			tid = TargetingService.pick(u.ground_pos, u.weapon.range_tiles, candidates)
		if u.weapon_state.tick(delta, tid != TargetingService.NO_TARGET):
			var target: BattleEnemy = by_id[tid]
			u.face_toward(target.ground_pos)
			_pending.append(Hit.new(target, DamageService.compute(u.weapon.damage, target.def.armor)))
			stats["shots"] += 1
			shot_fired.emit(u.muzzle_world(), target.chest_world(), u.weapon.id)


func _apply_damage() -> void:
	for h in _pending:
		var target: Object = h.target
		var health: Health = target.health
		health.take_damage(h.amount)
		if target is BattleCore:
			core_damaged.emit(h.amount)
	_pending.clear()
	# Remove the dead only after every hit this tick has landed.
	for i in range(enemies.size() - 1, -1, -1):
		var e := enemies[i]
		if not e.is_alive():
			enemies.remove_at(i)
			stats["kills"] += 1
			enemy_died.emit(e.ground_pos)
			_dispose(e, e.shadow)
	for i in range(units.size() - 1, -1, -1):
		var u := units[i]
		if not u.is_alive():
			units.remove_at(i)
			stats["units_lost"] += 1
			unit_died.emit(u.ground_pos)
			_dispose(u, u.shadow)


func _on_rules_ended(res: MissionRules.Result) -> void:
	battle_ended.emit(res)


# --- player input / orders -----------------------------------------------------------------------

## Orders every mobile unit to walk to the centre of `cell`. Returns how many accepted the order.
func order_move_all(cell: Vector2i) -> int:
	if mission == null or not mission.map.is_walkable(cell) or cell == mission.core_cell:
		return 0
	var n := 0
	for u in units:
		if u.order_move(IsoProjection.cell_center(cell)):
			n += 1
	return n


func _unhandled_input(event: InputEvent) -> void:
	if mission == null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not is_ended():
		order_move_all(IsoPicking.cell_under_mouse(self))
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		restart()


func _process(delta: float) -> void:
	if mission == null or not is_inside_tree():
		return
	var cell := IsoPicking.cell_under_mouse(self)
	_highlight.visible = mission.map.is_walkable(cell) and not is_ended()
	_highlight.cell = cell
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
	_fx = _add_layer("Fx", false)
	_highlight = IsoCellHighlight.new()
	_highlight.name = "HoverHighlight"
	_decals.add_child(_highlight)
	_camera = IsoCamera.new()
	_camera.name = "Camera"
	add_child(_camera)
	if is_inside_tree():
		_camera.make_current()
	connect("shot_fired", _on_shot_fired)


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


func _spawn_unit(su: StartUnit) -> void:
	var def := db.unit(su.unit_id)
	var u := BattleUnit.new()
	u.name = "Unit%d" % _next_uid
	u.setup(_next_uid, def, db.weapon(def.weapon_id), su.cell)
	_next_uid += 1
	_entities.add_child(u)
	u.shadow = _add_shadow(u, def.footprint_radius + 0.1)
	units.append(u)


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


## Removes a dead entity (and its shadow) from the scene immediately.
func _dispose(entity: Node, shadow: Node) -> void:
	for item in [entity, shadow]:
		if item == null:
			continue
		var n: Node = item
		var p: Node = n.get_parent()
		if p != null:
			p.remove_child(n)
		if is_inside_tree():
			n.queue_free()
		else:
			n.free()


func _on_shot_fired(from_world: Vector2, to_world: Vector2, _weapon_id: String) -> void:
	if is_inside_tree():
		Tracer.spawn(_fx, from_world, to_world)


func _show_fatal(message: String) -> void:
	push_error(message)
	var layer := CanvasLayer.new()
	var label := Label.new()
	label.text = message
	label.position = Vector2(24, 24)
	label.add_theme_color_override("font_color", Color(1, 0.5, 0.5))
	layer.add_child(label)
	add_child(layer)
