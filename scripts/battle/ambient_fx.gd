class_name AmbientFx
extends Node2D
## Small ambient motion: smoke drifting up from burning pieces and now and then a puff of dust behind a moving unit.
## Both are soft grey-brown blobs from a few capped lists, drawn above the entities and under the lights; the world
## tint colours them (dark at night). Presentation only: it reads positions and never touches the simulation.

var _battle: BattleController
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()  # presentation only; not the simulation's generator
var _fires: Array[BattleScenery] = []
var _smoke: Array[Dictionary] = []  # {p, age, life, size, drift}
var _dust: Array[Dictionary] = []
var _smoke_clock: float = 0.0
var _dust_clock: float = 0.0
var _last_pos: Dictionary = {}  # entity instance id -> its ground position at the last sample
var _dry: bool = true  # no dust on wet ground


func bind(battle: BattleController, weather: String) -> void:
	_battle = battle
	_rng.seed = 7
	_dry = weather != "rain"
	z_index = 40
	collect_fires()
	set_process(true)


## The burning pieces of the battle (orange glows): the smoke sources.
func collect_fires() -> void:
	_fires.clear()
	for s in _battle.scenery_nodes:
		if s.def.glow_radius > 0.0 and LightField.is_fire(s.def.glow_color):
			_fires.append(s)


func fire_count() -> int:
	return _fires.size()


func puff_count() -> int:
	return _smoke.size() + _dust.size()


func _view() -> Rect2:
	if not is_inside_tree():
		return Rect2(-1e6, -1e6, 2e6, 2e6)
	return get_canvas_transform().affine_inverse() * get_viewport().get_visible_rect()


func _process(delta: float) -> void:
	var view := _view().grow(120.0)
	_age(_smoke, delta)
	_age(_dust, delta)
	_smoke_clock += delta
	if _smoke_clock >= LightingConfig.SMOKE_INTERVAL_S:
		_smoke_clock = 0.0
		_emit_smoke(view)
	_dust_clock += delta
	if _dust_clock >= LightingConfig.DUST_INTERVAL_S:
		_dust_clock = 0.0
		if _dry:
			_emit_dust(view)
	queue_redraw()


func _age(list: Array[Dictionary], delta: float) -> void:
	var i := 0
	while i < list.size():
		list[i]["age"] = float(list[i]["age"]) + delta
		if float(list[i]["age"]) >= float(list[i]["life"]):
			list.remove_at(i)
		else:
			i += 1


func _emit_smoke(view: Rect2) -> void:
	var near: Array[BattleScenery] = []
	for f in _fires:
		if is_instance_valid(f) and view.has_point(f.position):
			near.append(f)
	if near.size() > LightingConfig.SMOKE_MAX_SOURCES:
		var c := view.get_center()
		near.sort_custom(func(a: BattleScenery, b: BattleScenery) -> bool: return a.position.distance_squared_to(c) < b.position.distance_squared_to(c))
		near.resize(LightingConfig.SMOKE_MAX_SOURCES)
	for f in near:
		if _smoke.size() >= LightingConfig.SMOKE_MAX_PUFFS:
			return
		_smoke.append({"p": f.position + f.def.glow_offset + Vector2(_rng.randf_range(-5.0, 5.0), 0.0), "age": 0.0, "life": LightingConfig.SMOKE_LIFE_S * _rng.randf_range(0.8, 1.2), "size": _rng.randf_range(5.0, 8.0), "drift": _rng.randf_range(4.0, 12.0)})


func _emit_dust(view: Rect2) -> void:
	var pool: Array = _battle.units if _rng.randf() < 0.4 else _battle.enemies
	if pool.is_empty():
		return
	for k in LightingConfig.DUST_PER_TICK:
		if _dust.size() >= LightingConfig.DUST_MAX_PUFFS:
			return
		var e := pool[_rng.randi() % pool.size()] as IsoEntity
		if e == null or not is_instance_valid(e) or e.altitude > 0.1 or not view.has_point(e.position):
			continue
		var id := e.get_instance_id()
		var prev: Vector2 = _last_pos.get(id, e.ground_pos)
		_last_pos[id] = e.ground_pos
		if prev.distance_to(e.ground_pos) < LightingConfig.DUST_MIN_MOVE_TILES:
			continue
		_dust.append({"p": e.position + Vector2(_rng.randf_range(-3.0, 3.0), 1.0), "age": 0.0, "life": LightingConfig.DUST_LIFE_S * _rng.randf_range(0.7, 1.2), "size": _rng.randf_range(3.0, 5.0), "drift": _rng.randf_range(-6.0, 6.0)})
	if _last_pos.size() > 600:
		_last_pos.clear()  # entities that died: forget them


func _draw() -> void:
	var tex := LightField.glow_texture()
	for s in _smoke:
		var u := float(s["age"]) / float(s["life"])
		var p: Vector2 = s["p"]
		p += Vector2(float(s["drift"]) * float(s["age"]), -LightingConfig.SMOKE_RISE_PX * float(s["age"]))
		var r := float(s["size"]) * (1.0 + 2.2 * u)
		var a := 0.34 * sin(PI * minf(u * 1.6, 1.0)) * (1.0 - u)
		draw_texture_rect(tex, Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(0.2, 0.2, 0.22, a))
	for d in _dust:
		var u := float(d["age"]) / float(d["life"])
		var p: Vector2 = d["p"]
		p += Vector2(float(d["drift"]) * float(d["age"]), -7.0 * u)
		var r := float(d["size"]) * (1.0 + 1.6 * u)
		draw_texture_rect(tex, Rect2(p - Vector2(r, r * 0.7), Vector2(r, r * 0.7) * 2.0), false, Color(0.62, 0.55, 0.45, 0.32 * (1.0 - u)))
