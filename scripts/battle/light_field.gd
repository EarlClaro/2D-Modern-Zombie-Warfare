class_name LightField
extends Node2D
## The night's lights: a soft warm pool on the ground (flattened to the 2:1 view) and a bright halo at the bulb for
## every lamp, floodlight, tower lamp and fire of the scenery, plus short flashes from muzzles and explosions.
## They flicker, are culled to the screen and capped, and walls, buildings and towers block them (shadow volumes from
## LightShadows, drawn with the SUB blend by `Cuts` so they cancel exactly that light's pool). Everything is additive
## on the finished picture, which costs a few draw calls where real PointLight2D lights cost 5 to 10 times the frame
## time on the big map (every sprite is redrawn once per light). Presentation only: reads the scenery and the clock.

static var _tex: ImageTexture  # one soft round falloff shared by every glow

var _items: Array[Dictionary] = []
var _visible: Array[Dictionary] = []
var _flashes: Array[Dictionary] = []
var _darkness: float = 0.0
var _t: float = 0.0
var _cuts: Cuts
var _source_key: int = 0


static func glow_texture() -> ImageTexture:
	if _tex == null:
		var n := 64
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		for y in n:
			for x in n:
				var d := Vector2(x + 0.5 - n * 0.5, y + 0.5 - n * 0.5).length() / (n * 0.5)
				img.set_pixel(x, y, Color(1, 1, 1, falloff(d)))
		_tex = ImageTexture.create_from_image(img)
	return _tex


## Brightness profile of a glow at distance `d` (0 at the centre, 1 at the rim).
static func falloff(d: float) -> float:
	var a := clampf(1.0 - d, 0.0, 1.0)
	return a * a * (3.0 - 2.0 * a)


## True for the orange of fires (campfire, burning houses, crashed aircraft); lamps are white to yellow.
static func is_fire(c: Color) -> bool:
	return c.g >= LightingConfig.FIRE_MIN_GREEN and c.g <= LightingConfig.FIRE_MAX_GREEN and c.b <= LightingConfig.FIRE_MAX_BLUE


## Brightness multiplier of a light at time `t` seconds: 1 is full. A lamp wobbles a little, a fire a lot; `phase` is
## the light's own offset so neighbours do not pulse together. Always within 1 - amount .. 1.
static func flicker_at(fire: bool, phase: float, t: float) -> float:
	var w := t * LightingConfig.FLICKER_SPEED
	var s: float
	if fire:
		s = 0.5 + 0.5 * (0.55 * sin(w + phase) + 0.3 * sin(w * 2.7 + phase * 1.7) + 0.15 * sin(w * 6.1 + phase * 3.1))
	else:
		s = 0.5 + 0.5 * sin(w * 0.35 + phase)
	return 1.0 - (LightingConfig.FLICKER_FIRE if fire else LightingConfig.FLICKER_LAMP) * s


## Lights worth drawing: those whose reach touches `view` (world px), the nearest `cap` to `centre` first.
static func pick(items: Array[Dictionary], view: Rect2, centre: Vector2, cap: int) -> Array[Dictionary]:
	var near: Array[Dictionary] = []
	var area := view.grow(LightingConfig.LIGHT_CULL_MARGIN_PX)
	for it in items:
		if area.intersects(it["bounds"] as Rect2):
			near.append(it)
	if near.size() > cap:
		near.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return (a["ground"] as Vector2).distance_squared_to(centre) < (b["ground"] as Vector2).distance_squared_to(centre))
		near.resize(cap)
	return near


func _init() -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	z_index = 50
	_cuts = Cuts.new()
	_cuts.name = "Cuts"
	add_child(_cuts)


## Collects the lights of the battle's scenery (and their shadow volumes). Cheap to call again: it only rebuilds when
## the scenery changed; the darkness (0 day, 1 night) decides whether anything shows.
func refresh(battle: BattleController, darkness: float) -> void:
	_darkness = darkness
	var key := battle.scenery_nodes.size() * 31 + (battle.scenery_nodes[0].get_instance_id() if not battle.scenery_nodes.is_empty() else 0)
	if key != _source_key or _items.is_empty():
		_source_key = key
		_rebuild(battle)
	_sync_visibility()


func _rebuild(battle: BattleController) -> void:
	_items.clear()
	var reach_per_px := 1.0 / IsoProjection.ellipse_radii(1.0).x
	var i := 0
	for s in battle.scenery_nodes:
		if s.def.glow_radius <= 0.0:
			continue
		i += 1
		var col := s.def.glow_color
		var r := s.def.glow_radius
		var ground := s.position + Vector2(0.0, -4.0)
		var pos := s.position + s.def.glow_offset
		var pr := r * LightingConfig.POOL_SHARE
		var item := {
			"pos": pos, "ground": ground, "r": r, "pr": pr, "c": col, "fire": is_fire(col), "phase": float(i) * 2.399,
			"bounds": Rect2(ground - Vector2(pr, pr * LightingConfig.POOL_FLATTEN), Vector2(pr, pr * LightingConfig.POOL_FLATTEN) * 2.0).merge(Rect2(pos - Vector2(r, r) * LightingConfig.HALO_SHARE, Vector2(r, r) * LightingConfig.HALO_SHARE * 2.0)),
			"shadows": [] as Array[PackedVector2Array], "falloffs": [] as Array[PackedFloat32Array], "k": 1.0,
		}
		if LightingConfig.LIGHT_SHADOWS:
			var light_ground := s.ground_pos
			var lh := maxf(-s.def.glow_offset.y / IsoProjection.Z_PX_PER_UNIT, LightingConfig.LIGHT_MIN_HEIGHT)
			for g in LightShadows.around(light_ground, lh, pr * reach_per_px, battle.scenery_nodes, s, LightingConfig.SHADOW_MAX_CASTERS):
				var poly := PackedVector2Array()
				var fall := PackedFloat32Array()
				for gp in g:
					var sp := IsoProjection.ground_to_screen(gp)
					poly.append(sp)
					var d := Vector2(sp.x - ground.x, (sp.y - ground.y) / LightingConfig.POOL_FLATTEN).length() / pr
					fall.append(falloff(d))
				(item["shadows"] as Array[PackedVector2Array]).append(poly)
				(item["falloffs"] as Array[PackedFloat32Array]).append(fall)
		_items.append(item)


func _sync_visibility() -> void:
	visible = (_darkness > 0.05 and not _items.is_empty()) or not _flashes.is_empty()
	set_process(visible)
	queue_redraw()


func item_count() -> int:
	return _items.size()


## Number of shadow volumes of all lights (for tests and the report).
func shadow_count() -> int:
	var n := 0
	for it in _items:
		n += (it["shadows"] as Array).size()
	return n


## The lights drawn this frame (dictionaries with world-px `pos`, `ground`, `r`, colour `c` and the current
## brightness `k`); the ground shader and the rain read them.
func visible_lights() -> Array[Dictionary]:
	return _visible


## A short bright flash (muzzle, explosion) at world position `at`.
func add_flash(at: Vector2, radius_px: float, life_s: float, col: Color) -> void:
	if not _view_rect().grow(radius_px).has_point(at):
		return  # off screen: nobody sees it
	if _flashes.size() >= LightingConfig.MAX_FLASHES:
		_flashes.remove_at(0)
	_flashes.append({"at": at, "r": radius_px, "life": life_s, "age": 0.0, "c": col})
	_sync_visibility()


func flash_count() -> int:
	return _flashes.size()


func _view_rect() -> Rect2:
	if not is_inside_tree():
		return Rect2(-1e6, -1e6, 2e6, 2e6)
	return get_canvas_transform().affine_inverse() * get_viewport().get_visible_rect()


func _process(delta: float) -> void:
	_t += delta
	var i := 0
	while i < _flashes.size():
		_flashes[i]["age"] = float(_flashes[i]["age"]) + delta
		if float(_flashes[i]["age"]) >= float(_flashes[i]["life"]):
			_flashes.remove_at(i)
		else:
			i += 1
	var view := _view_rect()
	_visible = pick(_items, view, view.get_center(), LightingConfig.MAX_LIGHTS)
	for it in _visible:
		it["k"] = _darkness * flicker_at(bool(it["fire"]), float(it["phase"]), _t)
	if _flashes.is_empty() and _darkness <= 0.05:
		_sync_visibility()
		return
	queue_redraw()
	_cuts.show_lights(_visible)


func _draw() -> void:
	var tex := glow_texture()
	for it in _visible:
		var col: Color = it["c"]
		var k: float = it["k"]
		var pr: float = it["pr"]
		var ground: Vector2 = it["ground"]
		draw_set_transform(ground, 0.0, Vector2(1.0, LightingConfig.POOL_FLATTEN))
		draw_texture_rect(tex, Rect2(Vector2(-pr, -pr), Vector2(pr, pr) * 2.0), false, Color(col.r, col.g, col.b, LightingConfig.POOL_ALPHA * k * col.a))
		draw_set_transform(Vector2.ZERO)
		var hr: float = float(it["r"]) * LightingConfig.HALO_SHARE
		var pos: Vector2 = it["pos"]
		draw_texture_rect(tex, Rect2(pos - Vector2(hr, hr), Vector2(hr, hr) * 2.0), false, Color(col.r, col.g, col.b, LightingConfig.HALO_ALPHA * k * col.a))
		if not LightingConfig.SCREEN_PASS:  # bloom: a wide faint halo around every bright source
			var br: float = float(it["r"]) * LightingConfig.BLOOM_HALO_SHARE
			draw_texture_rect(tex, Rect2(pos - Vector2(br, br), Vector2(br, br) * 2.0), false, Color(col.r, col.g, col.b, LightingConfig.BLOOM_HALO_ALPHA * k * col.a))
	var by_day := 0.35 + 0.65 * _darkness
	for f in _flashes:
		var life := float(f["life"])
		var left := 1.0 - float(f["age"]) / life
		var r := float(f["r"]) * (0.55 + 0.45 * left)
		var c: Color = f["c"]
		draw_set_transform(f["at"], 0.0, Vector2(1.0, 0.8))
		draw_texture_rect(tex, Rect2(Vector2(-r, -r), Vector2(r, r) * 2.0), false, Color(c.r, c.g, c.b, c.a * left * left * by_day))
		draw_set_transform(Vector2.ZERO)


## The shadow volumes of the visible lights, drawn on top of the pools with the SUB blend.
class Cuts:
	extends Node2D

	var _lights: Array[Dictionary] = []

	func _init() -> void:
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_SUB
		material = mat

	func show_lights(lights: Array[Dictionary]) -> void:
		_lights = lights
		queue_redraw()

	func _draw() -> void:
		for it in _lights:
			var col: Color = it["c"]
			var base := LightingConfig.POOL_ALPHA * float(it["k"]) * col.a * LightingConfig.SHADOW_STRENGTH
			var polys: Array = it["shadows"]
			var falls: Array = it["falloffs"]
			for j in polys.size():
				var poly: PackedVector2Array = polys[j]
				var fall: PackedFloat32Array = falls[j]
				var colors := PackedColorArray()
				for v in fall.size():
					colors.append(Color(col.r, col.g, col.b, base * fall[v]))
				draw_polygon(poly, colors)
