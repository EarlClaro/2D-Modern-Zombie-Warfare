extends SceneTree
## Dev tool (not a test). Builds the five field-command maps (F4) and their missions and decks: bridge_line (river with a
## plank bridge), dead_highway (a long road for kiting), last_airfield (runways and hangars), town_siege (a street grid
## the horde winds through) and mountain_pass (a canyon with a ridge on each side). Seeded, so the output is reproducible;
## the maps are data (data/maps/*.tres) and can be edited by hand afterwards, but running this again overwrites them.
## Run: godot --headless --path . --script tools/gen_field_maps.gd [-- --only=town_siege]
## Writes data/maps/<id>.tres, data/missions/<mission>.tres and data/decks/field_arms.tres, field_siege.tres.

const SEED := 20261017
const OPEN_BASE: Array[String] = [".", ",", "x", "g", "y", "f", "o", "v", "s", "d", "r", "q", "m", "n"]

var _rng := RandomNumberGenerator.new()
var _w: int = 0
var _h: int = 0
var _terrain: Array = []
var _lines: PackedStringArray = PackedStringArray()
var _taken: Dictionary = {}
var _defs: Dictionary = {}
var _facings: Dictionary = {}
var _segments: Array = []
var _open: Array[String] = OPEN_BASE
var _errors: int = 0
var _spawns: Array[Vector2i] = []
var _path: Array[Vector2i] = []
var _core: Vector2i = Vector2i.ZERO


func _initialize() -> void:
	_load_footprints()
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
	var builders := {
		"bridge_line": _bridge_line,
		"dead_highway": _dead_highway,
		"last_airfield": _last_airfield,
		"town_siege": _town_siege,
		"mountain_pass": _mountain_pass,
	}
	for id in builders:
		if only != "" and only != id:
			continue
		_rng.seed = SEED + id.hash() % 1000
		(builders[id] as Callable).call()
	if only == "":
		_decks()
	print("field maps: %d error(s)" % _errors)
	quit(1 if _errors > 0 else 0)


# --- shared helpers ------------------------------------------------------------------------------------------------------

func _load_footprints() -> void:
	for f in DirAccess.get_files_at("res://data/scenery"):
		if f.ends_with(".tres"):
			var d := load("res://data/scenery/" + f) as SceneryDefinition
			if d != null:
				_defs[d.id] = d.footprint
				if d.sprite != null and d.sprite.textures.has("NW"):
					_facings[d.id] = true


func _begin(w: int, h: int, fill: String) -> void:
	_w = w
	_h = h
	_terrain = []
	for y in h:
		var row: Array = []
		for x in w:
			row.append(fill)
		_terrain.append(row)
	_lines = PackedStringArray()
	_taken = {}
	_segments = []
	_open = OPEN_BASE.duplicate()


func _c(cell: Vector2i) -> Vector2:
	return IsoProjection.cell_center(cell)


func _setc(x: int, y: int, ch: String) -> void:
	if x >= 0 and y >= 0 and x < _w and y < _h:
		_terrain[y][x] = ch


func _getc(x: int, y: int) -> String:
	return _terrain[y][x] if x >= 0 and y >= 0 and x < _w and y < _h else ""


func _fill(x0: int, y0: int, x1: int, y1: int, ch: String) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			_setc(x, y, ch)


## Deterministic noise in [0, 1) from a cell.
func _noise(x: int, y: int, k: int = 0) -> float:
	return fposmod(sin(float(x) * 12.9898 + float(y) * 78.233 + float(k) * 37.719) * 43758.5453, 1.0)


func _make_routes() -> void:
	_segments.clear()
	for s in _spawns:
		_segments.append([_c(s), _c(_path[0])])
	for i in range(1, _path.size()):
		_segments.append([_c(_path[i - 1]), _c(_path[i])])


func _dist_to_routes(p: Vector2) -> float:
	var best := INF
	for s in _segments:
		var a: Vector2 = s[0]
		var b: Vector2 = s[1]
		var t := clampf((p - a).dot(b - a) / maxf((b - a).length_squared(), 0.0001), 0.0, 1.0)
		best = minf(best, p.distance_to(a.lerp(b, t)))
	return best


## Paints a strip of `ch` along a segment; over water (deep or shallow) it paints `over_water` instead (a bridge or ford), or leaves it.
func _paint(a: Vector2, b: Vector2, half_w: float, ch: String, over_water: String = "", keep_rock: bool = true) -> void:
	for y in _h:
		for x in _w:
			var p := _c(Vector2i(x, y))
			var t := clampf((p - a).dot(b - a) / maxf((b - a).length_squared(), 0.0001), 0.0, 1.0)
			if p.distance_to(a.lerp(b, t)) > half_w:
				continue
			var cur := _getc(x, y)
			if cur == "w" or cur == "~":
				if over_water != "":
					_setc(x, y, over_water)
			elif cur == "#" and keep_rock:
				continue
			else:
				_setc(x, y, ch)


func _paint_routes(half_w: float, ch: String, over_water: String = "") -> void:
	for s in _segments:
		_paint(s[0], s[1], half_w, ch, over_water, false)


func _put(id: String, x: int, y: int, strict: bool = true, margin: float = 2.2, facing: String = "") -> bool:
	if not _defs.has(id):
		push_error("unknown scenery id %s" % id)
		_errors += 1
		return false
	var fp: Vector2i = _defs[id]
	for dy in fp.y:
		for dx in fp.x:
			var cx := x + dx
			var cy := y + dy
			if cx < 0 or cy < 0 or cx >= _w or cy >= _h or _taken.has(Vector2i(cx, cy)):
				return false
			if strict and not (_getc(cx, cy) in _open):
				return false
			if _dist_to_routes(_c(Vector2i(cx, cy))) < margin:
				return false
	for dy in fp.y:
		for dx in fp.x:
			_taken[Vector2i(x + dx, y + dy)] = true
	_lines.append(("%s %d %d %s" % [id, x, y, facing]).strip_edges())
	return true


## Fixed placement: a failure is a bug in this script and is reported.
func _must(id: String, x: int, y: int, facing: String = "") -> void:
	if not _defs.has(id):
		push_error("unknown scenery id %s" % id)
		_errors += 1
		return
	var fp: Vector2i = _defs[id]
	for dy in fp.y:
		for dx in fp.x:
			var cell := Vector2i(x + dx, y + dy)
			if _taken.has(cell) or cell.x >= _w or cell.y >= _h or cell.x < 0 or cell.y < 0:
				push_error("piece %s at (%d, %d) overlaps another or leaves the map" % [id, x, y])
				_errors += 1
				return
			if _dist_to_routes(_c(cell)) < 1.4:
				push_error("piece %s at (%d, %d) stands on the enemy route" % [id, x, y])
				_errors += 1
				return
	for dy in fp.y:
		for dx in fp.x:
			_taken[Vector2i(x + dx, y + dy)] = true
	_lines.append(("%s %d %d %s" % [id, x, y, facing]).strip_edges())


## A four-facing piece: facing "se"/"nw" along ground x, "sw"/"ne" uses the `_y` definition.
func _must4(id: String, x: int, y: int, facing: String) -> void:
	if facing in ["sw", "ne"]:
		_must(id + "_y", x, y, "nw" if facing == "ne" else "")
	else:
		_must(id, x, y, "nw" if facing == "nw" else "")


func _put4(id: String, x: int, y: int, strict: bool = true, margin: float = 2.2) -> bool:
	var o := _rng.randi() % 4
	var use_y := o >= 2 and _defs.has(id + "_y")
	var face := "nw" if (o % 2 == 1 and _facings.has(id)) else ""
	return _put(id + ("_y" if use_y else ""), x, y, strict, margin, face)


## Random scatter of pieces from `ids` in a rectangle; returns how many were placed.
func _scatter(ids: Array, count: int, x0: int, x1: int, y0: int, y1: int, margin: float = 2.4, strict: bool = true) -> int:
	var placed := 0
	var attempts := count * 40
	while placed < count and attempts > 0:
		attempts -= 1
		var id: String = ids[_rng.randi() % ids.size()]
		var x := _rng.randi_range(x0, x1)
		var y := _rng.randi_range(y0, y1)
		if _facings.has(id):
			if _put4(id, x, y, strict, margin):
				placed += 1
		elif _put(id, x, y, strict, margin):
			placed += 1
	return placed


## A line of pieces every `step` cells from a to b (both cells), skipping what does not fit.
func _line(id: String, a: Vector2i, b: Vector2i, step: int, margin: float = 2.0, strict: bool = false) -> void:
	var n := maxi(1, int(Vector2(b - a).length() / float(step)))
	for i in n + 1:
		var p := Vector2(a).lerp(Vector2(b), float(i) / float(n))
		_put(id, roundi(p.x), roundi(p.y), strict, margin)


func _rects_touch_route(x0: int, y0: int, x1: int, y1: int, margin: float) -> bool:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if _dist_to_routes(_c(Vector2i(x, y))) < margin:
				return true
	return false


func _su(unit_id: String, cell: Vector2i) -> StartUnit:
	var s := StartUnit.new()
	s.unit_id = unit_id
	s.cell = cell
	return s


func _wave(start: float, enemy: String, count: int, interval: float, spawn: int = 0) -> WaveEntry:
	var w := WaveEntry.new()
	w.start_s = start
	w.enemy_id = enemy
	w.count = count
	w.interval_s = interval
	w.spawn_index = spawn
	return w


## Cells around the core for the starting defenders: walkable, off the route, not on scenery.
func _defenders(units: Array[String]) -> Array[StartUnit]:
	var out: Array[StartUnit] = []
	var used: Dictionary = {_core: true}
	var ring: Array[Vector2i] = []
	for r in range(3, 8):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) == r:
					ring.append(_core + Vector2i(dx, dy))
	var from := Vector2(_path[maxi(_path.size() - 2, 0)])  # the defenders stand on the side the enemy comes from
	ring.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return Vector2(a).distance_to(from) < Vector2(b).distance_to(from))
	var i := 0
	for u in units:
		while i < ring.size():
			var cell := ring[i]
			i += 1
			if used.has(cell) or _taken.has(cell):
				continue
			if not (_getc(cell.x, cell.y) in _open) or _dist_to_routes(_c(cell)) < 2.0:
				continue
			used[cell] = true
			out.append(_su(u, cell))
			break
	return out


func _save_map(id: String) -> MapDefinition:
	var rows := PackedStringArray()
	for y in _h:
		rows.append("".join(_terrain[y]))
	var map := MapDefinition.new()
	map.id = id
	map.rows = rows
	map.scenery = _lines
	var errs := map.validate()
	for e in errs:
		push_error(e)
		_errors += 1
	var err := ResourceSaver.save(map, "res://data/maps/%s.tres" % id)
	if err != OK:
		push_error("saving map %s failed (%d)" % [id, err])
		_errors += 1
	return ResourceLoader.load("res://data/maps/%s.tres" % id, "", ResourceLoader.CACHE_MODE_IGNORE) as MapDefinition


func _save_mission(mission_id: String, name: String, map: MapDefinition, deck: String, health: float, duration: float, weather: String, tod: float, day_len: float, waves: Array[WaveEntry], units: Array[String]) -> void:
	var m := MissionDefinition.new()
	m.id = mission_id
	m.display_name = name
	m.map = map
	m.core_cell = _core
	m.core_health = health
	m.duration_s = duration
	m.core_scenery_id = "hq_bunker"
	m.core_radius = 1.2
	m.spawn_cells = _spawns.duplicate()
	m.path_cells = _path.duplicate()
	m.deploy_radius = 0.0
	m.deck_id = deck
	m.weather = weather
	m.time_of_day = tod
	m.day_length_s = day_len
	m.start_units = _defenders(units)
	m.waves = waves
	for e in m.validate():
		push_error(e)
		_errors += 1
	var err := ResourceSaver.save(m, "res://data/missions/%s.tres" % mission_id)
	if err != OK:
		push_error("saving mission %s failed (%d)" % [mission_id, err])
		_errors += 1
	print("%s: %dx%d, %d scenery pieces, %d enemies" % [map.id, _w, _h, _lines.size(), m.total_enemies()])


func _decks() -> void:
	_save_deck("field_arms", "Field Arms", ["rifle_squad", "rifle_squad", "rifle_squad", "marksman_team", "marksman_team", "rpg_team", "rpg_team", "gatling_gun", "gatling_gun", "tank", "tank", "ifv", "ifv", "scout_jeep", "mortar_team", "howitzer_battery", "rocket_launcher", "artillery_strike", "helicopter_support"])
	_save_deck("field_siege", "Field Siege", ["rifle_squad", "rifle_squad", "marksman_team", "marksman_team", "rpg_team", "rpg_team", "gatling_gun", "gatling_gun", "mortar_team", "mortar_team", "howitzer_battery", "howitzer_battery", "rocket_launcher", "sandbags", "sandbags", "barrier", "barrier", "crates", "fuel_drums", "fuel_drums", "artillery_strike"])


func _save_deck(id: String, name: String, cards: Array) -> void:
	var d := DeckDefinition.new()
	d.id = id
	d.display_name = name
	d.card_ids = PackedStringArray(cards)
	var err := ResourceSaver.save(d, "res://data/decks/%s.tres" % id)
	if err != OK:
		push_error("saving deck %s failed" % id)
		_errors += 1


# --- 1. bridge_line: a river with one plank bridge --------------------------------------------------------------------------

func _river_x(y: int) -> float:
	return 26.0 + 2.2 * sin(float(y) * 0.3)


func _bridge_line() -> void:
	_begin(56, 44, ".")
	_spawns = [Vector2i(54, 5), Vector2i(54, 38)]
	_path = [Vector2i(44, 22), Vector2i(31, 22), Vector2i(21, 22), Vector2i(14, 30), Vector2i(7, 35)]
	_core = Vector2i(7, 35)
	_make_routes()
	# east bank: meadow and fields; west bank: the village
	for y in _h:
		for x in _w:
			var east := float(x) > _river_x(y)
			var n := _noise(x, y)
			if east:
				_setc(x, y, "r" if (y > 28 and x > 36 and x < 50 and y < 42) else ("g" if n < 0.55 else "."))
			else:
				_setc(x, y, "." if n < 0.7 else "g")
	# the river: deep water with shallows on both edges
	for y in _h:
		for x in _w:
			var d := absf(float(x) - _river_x(y))
			if d < 2.3:
				_setc(x, y, "w")
			elif d < 3.4:
				_setc(x, y, "~")
	# a few rocks on the banks
	for i in 14:
		var cx := _rng.randi_range(0, _w - 1)
		var cy := _rng.randi_range(0, _h - 1)
		if _dist_to_routes(_c(Vector2i(cx, cy))) < 5.0 or _getc(cx, cy) in ["w", "~"] or Vector2(cx, cy).distance_to(Vector2(_core)) < 7.0:
			continue
		_fill(cx, cy, cx + _rng.randi_range(0, 1), cy + _rng.randi_range(0, 1), "#")
	# the road and the bridge (planks over the water); a second, broken bridge to the north
	_paint_routes(1.5, "=", "z")
	_paint(_c(Vector2i(0, 9)), _c(Vector2i(55, 9)), 1.2, "=", "z")
	for y in range(7, 12):  # the broken bridge: the middle of it is gone
		for x in range(24, 30):
			if _getc(x, y) == "z":
				_setc(x, y, "w")
	# village ground around the core and the west road
	_fill(2, 29, 14, 41, "p")
	_fill(3, 30, 13, 40, ",")
	_paint(_c(Vector2i(14, 30)), _c(Vector2i(7, 35)), 1.5, "=")
	_paint(_c(Vector2i(14, 30)), _c(Vector2i(14, 8)), 1.1, "=")
	# scenery: village, farm, trees, river reeds
	_must("base_guard_shack", 11, 36)
	_must("base_sandbag_corner", 4, 31)
	_must("base_sandbag_corner", 4, 40)
	_must("watchtower", 13, 41)
	_must("base_water_tank", 3, 36)
	_scatter(["house_small", "house_small_brick", "bld_cottage", "bld_bungalow", "house_large"], 8, 2, 20, 2, 27, 2.6)
	_scatter(["street_lamp", "wrecked_car", "bench", "mailbox", "dumpster"], 8, 2, 20, 2, 41, 2.2)
	_scatter(["oak_tree", "oak_tree_b", "bush", "birch_tree", "willow_tree"], 18, 0, 20, 0, 43, 2.4)
	_scatter(["bld_barn", "bld_farmhouse", "hay_bale", "scarecrow", "bld_silo_complex", "oak_tree", "bush"], 16, 34, 54, 2, 43, 2.6)
	_scatter(["boulder", "rock_pile", "tall_grass", "fallen_log"], 10, 28, 54, 0, 43, 2.4)
	_scatter(["reeds", "lily_pads"], 14, 20, 32, 0, 43, 1.0, false)
	_put("road_barricade", 21, 8, false, 0.5)
	_put("road_barricade", 31, 8, false, 0.5)
	var map := _save_map("bridge_line")
	var waves: Array[WaveEntry] = [
		_wave(5.0, "shambler", 110, 0.07, 0), _wave(5.0, "shambler", 80, 0.09, 1),
		_wave(24.0, "runner", 90, 0.05, 0), _wave(30.0, "spitter", 18, 0.5, 1),
		_wave(46.0, "shambler", 320, 0.03, 0), _wave(52.0, "brute", 14, 0.9, 1),
		_wave(76.0, "runner", 170, 0.03, 1), _wave(80.0, "spitter", 28, 0.45, 0),
		_wave(98.0, "shambler", 420, 0.02, 0), _wave(104.0, "brute", 32, 0.5, 1),
		_wave(122.0, "runner", 170, 0.035, 0),
	]
	_save_mission("x6_bridge_line", "Bridge Line", map, "field_arms", 950.0, 160.0, "rain", 0.45, 0.0, waves, ["mg_nest", "mg_nest", "rifle_soldier", "rifle_soldier", "jeep"])


# --- 2. dead_highway: one long straight road ----------------------------------------------------------------------------------

func _dead_highway() -> void:
	_begin(72, 30, "y")
	_spawns = [Vector2i(70, 4), Vector2i(70, 25)]
	_path = [Vector2i(58, 15), Vector2i(40, 15), Vector2i(8, 15)]
	_core = Vector2i(8, 15)
	_make_routes()
	for y in _h:
		for x in _w:
			var n := _noise(x, y)
			_setc(x, y, "s" if n < 0.16 else ("d" if n < 0.34 else ("," if n < 0.4 else "y")))
	# the highway: four lanes with a median, cracked at the edges
	for y in range(11, 20):
		for x in range(0, _w):
			_setc(x, y, "a")
	for x in range(0, _w):
		_setc(x, 11, "k")
		_setc(x, 19, "k")
		_setc(x, 15, "h")
		_setc(x, 13, "l")
		_setc(x, 17, "l")
	_paint(_c(_spawns[0]), _c(_path[0]), 1.4, "=")
	_paint(_c(_spawns[1]), _c(_path[0]), 1.4, "=")
	# cracks and craters on the road
	for i in 22:
		var x := _rng.randi_range(2, _w - 3)
		var y := _rng.randi_range(12, 18)
		if y != 15 and _rng.randf() < 0.5:
			_setc(x, y, "k")
	for i in 5:
		var x := _rng.randi_range(14, 62)
		_setc(x, _rng.randi_range(12, 18), "u")
	# an overpass-side rest stop and a service road
	_fill(18, 3, 31, 9, "t")
	_paint(_c(Vector2i(24, 10)), _c(Vector2i(24, 12)), 1.2, "=")
	for i in 16:  # rocky outcrops
		var cx := _rng.randi_range(0, _w - 1)
		var cy := _rng.randi_range(0, _h - 1)
		if (cy >= 9 and cy <= 21) or (cx >= 18 and cx <= 31 and cy <= 10):
			continue
		_fill(cx, cy, cx + _rng.randi_range(0, 2), cy + _rng.randi_range(0, 1), "#")
	_must("bld_petrol_station", 19, 4)
	_must("bld_diner", 25, 4)
	_must("petrol_pump", 22, 8)
	_must("base_sandbag_corner", 4, 11)
	_must("base_sandbag_corner", 4, 20)
	_must("watchtower", 12, 9)
	_must("base_guard_shack", 12, 21)
	_line("power_pole", Vector2i(2, 8), Vector2i(70, 8), 8, 1.0)
	_line("road_sign", Vector2i(6, 21), Vector2i(66, 21), 14, 1.0)
	_scatter(["wrecked_car", "troop_truck", "ambulance", "road_barricade", "traffic_cone", "fuel_tanker", "humvee"], 20, 14, 68, 11, 19, 1.9, false)
	_scatter(["dead_tree", "dry_bush", "cactus", "boulder", "rock_pile", "sand_dune", "scrap_pile"], 28, 0, 71, 0, 29, 3.2)
	_scatter(["bld_shed", "water_well", "hay_bale", "tire_stack", "billboard"], 8, 32, 70, 0, 29, 3.2)
	var map := _save_map("dead_highway")
	var waves: Array[WaveEntry] = [
		_wave(5.0, "shambler", 120, 0.06, 0), _wave(5.0, "runner", 40, 0.1, 1),
		_wave(26.0, "runner", 140, 0.04, 0), _wave(30.0, "spitter", 14, 0.5, 1),
		_wave(48.0, "shambler", 360, 0.025, 1), _wave(54.0, "brute", 14, 0.9, 0),
		_wave(76.0, "runner", 240, 0.025, 0), _wave(82.0, "spitter", 26, 0.45, 1),
		_wave(100.0, "shambler", 450, 0.02, 1), _wave(106.0, "brute", 30, 0.5, 0),
		_wave(126.0, "runner", 220, 0.03, 1),
	]
	_save_mission("x7_dead_highway", "Dead Highway", map, "field_arms", 900.0, 170.0, "dust", 0.5, 0.0, waves, ["mg_nest", "mg_nest", "rifle_soldier", "rifle_soldier", "jeep"])


# --- 3. last_airfield: runways, apron and hangars -------------------------------------------------------------------------------

func _last_airfield() -> void:
	_begin(60, 48, "y")
	_spawns = [Vector2i(58, 5), Vector2i(58, 43)]
	_path = [Vector2i(50, 24), Vector2i(26, 24), Vector2i(26, 40), Vector2i(8, 40)]
	_core = Vector2i(8, 40)
	_make_routes()
	_open = OPEN_BASE.duplicate()
	for y in _h:
		for x in _w:
			var n := _noise(x, y)
			_setc(x, y, "d" if n < 0.25 else ("," if n < 0.32 else "y"))
	# the main runway along ground x with hazard-marked ends, and a cross runway along y
	_fill(4, 13, 56, 16, "R")
	_fill(4, 12, 56, 12, "h")
	_fill(4, 17, 56, 17, "h")
	_fill(42, 28, 45, 46, "Y")
	# apron in front of the hangars (north), taxiways joining everything
	_fill(6, 2, 38, 9, "t")
	_fill(6, 10, 38, 11, "a")
	_paint_routes(1.6, "a")
	_paint(_c(Vector2i(26, 24)), _c(Vector2i(26, 17)), 1.3, "a")
	_paint(_c(Vector2i(50, 24)), _c(Vector2i(50, 17)), 1.3, "a")
	# base compound in the south-west
	_fill(2, 33, 17, 46, "t")
	_fill(3, 34, 16, 45, "p")
	_paint(_c(Vector2i(8, 40)), _c(Vector2i(26, 40)), 1.6, "a")
	_must("base_control_tower", 12, 36)
	_must("base_hangar", 12, 3)
	_must("base_hangar", 20, 3)
	_must("base_hangar", 28, 3)
	_must("base_fuel_pump", 34, 5)
	_must("fuel_tank", 36, 3)
	_must("radar_mast", 3, 36)
	_must("watchtower", 17, 34)
	_must("base_sandbag_corner", 3, 34)
	_must("base_sandbag_corner", 3, 44)
	_must("base_comms_center", 12, 43)
	_must("helipad", 6, 43)
	_must("air_parked_fighter_camo", 10, 6)
	_must("air_cargo_plane", 22, 6)
	_must("air_light_plane", 31, 7)
	_must("air_utility_heli", 16, 7)
	_must("base_warning_sign", 40, 11)
	_line("floodlight", Vector2i(6, 18), Vector2i(54, 18), 10, 1.0)
	_line("boom_gate", Vector2i(47, 21), Vector2i(47, 21), 1, 1.0)
	_scatter(["container_red", "container_blue", "container_green", "pallet_stack", "base_supply_stack", "base_ammo_pile"], 10, 28, 56, 28, 46, 2.6, false)
	_scatter(["fuel_tanker", "troop_truck", "wrecked_car", "ambulance", "recovery_truck"], 8, 4, 56, 18, 30, 2.2, false)
	_scatter(["dead_tree", "dry_bush", "boulder", "rock_pile", "tall_grass", "sand_dune", "scrap_pile"], 26, 0, 59, 0, 47, 3.0)
	_scatter(["bld_shed", "bld_water_tower", "air_crashed_jet", "air_crashed_heli"], 4, 44, 58, 28, 46, 3.0, false)
	var map := _save_map("last_airfield")
	var waves: Array[WaveEntry] = [
		_wave(5.0, "shambler", 120, 0.07, 0), _wave(5.0, "shambler", 90, 0.08, 1),
		_wave(24.0, "runner", 110, 0.045, 1), _wave(30.0, "spitter", 18, 0.5, 0),
		_wave(46.0, "shambler", 360, 0.025, 0), _wave(52.0, "brute", 16, 0.8, 1),
		_wave(76.0, "runner", 200, 0.03, 0), _wave(82.0, "spitter", 30, 0.4, 1),
		_wave(100.0, "shambler", 460, 0.02, 1), _wave(106.0, "brute", 34, 0.45, 0),
		_wave(128.0, "runner", 200, 0.03, 1), _wave(140.0, "brute", 20, 0.5, 0),
	]
	_save_mission("x8_last_airfield", "Last Airfield", map, "field_arms", 1000.0, 175.0, "clear", 0.72, 0.0, waves, ["mg_nest", "mg_nest", "gatling_gun", "rifle_soldier", "rifle_soldier", "jeep"])


# --- 4. town_siege: a street grid the horde winds through ----------------------------------------------------------------------------

func _town_siege() -> void:
	_begin(52, 52, "g")
	_spawns = [Vector2i(50, 8), Vector2i(44, 1)]
	_path = [Vector2i(44, 8), Vector2i(44, 20), Vector2i(32, 20), Vector2i(32, 32), Vector2i(20, 32), Vector2i(20, 44), Vector2i(8, 44)]
	_core = Vector2i(8, 44)
	_make_routes()
	var streets := [8, 20, 32, 44]
	for y in _h:
		for x in _w:
			_setc(x, y, "g" if _noise(x, y) < 0.8 else ".")
	for s in streets:  # asphalt streets with paved verges
		for t in range(0, 52):
			for off in range(-1, 2):
				_setc(t, s + off, "a")
				_setc(s + off, t, "a")
			_setc(t, s - 2, "p")
			_setc(t, s + 2, "p")
			_setc(s - 2, t, "p")
			_setc(s + 2, t, "p")
	for sx in streets:  # crossings: cobbles at every junction
		for sy in streets:
			_fill(sx - 1, sy - 1, sx + 1, sy + 1, "c")
	_paint_routes(1.4, "a")
	_fill(2, 38, 14, 50, "c")  # the square around the core
	for i in 20:  # cracks in the asphalt
		var s: int = streets[_rng.randi() % 4]
		var t := _rng.randi_range(0, 51)
		if _rng.randf() < 0.5:
			_setc(t, s + _rng.randi_range(-1, 1), "k")
		else:
			_setc(s + _rng.randi_range(-1, 1), t, "k")
	_must("bld_church", 3, 40)
	_must("fountain", 9, 41)
	_must("base_sandbag_corner", 12, 47)
	_must("base_sandbag_corner", 4, 47)
	_must("base_guard_shack", 12, 40)
	# blocks: houses, shops, offices
	var blocks := [[10, 18], [22, 30], [34, 42], [46, 50]]
	for bx in blocks:
		for by in blocks:
			var x0: int = bx[0] + 1
			var x1: int = bx[1] - 1
			var y0: int = by[0] + 1
			var y1: int = by[1] - 1
			var pool := ["house_small", "house_small_brick", "house_large", "bld_cottage", "shop", "bld_garage_shop", "bld_townhouse_row", "apartment", "bld_office_block", "bld_supermarket"]
			_scatter(pool, 3, x0, x1, y0, y1, 2.4)
			_scatter(["oak_tree", "birch_tree", "bush", "street_lamp", "dumpster", "wheelie_bin", "wrecked_car"], 3, x0, x1, y0, y1, 2.2)
	_scatter(["street_lamp", "traffic_light", "fire_hydrant", "bus_stop", "mailbox", "vending_machine"], 14, 0, 51, 0, 51, 1.8, false)
	_scatter(["wrecked_car", "road_barricade", "traffic_cone", "ambulance", "shopping_cart"], 14, 0, 51, 0, 51, 1.8, false)
	var map := _save_map("town_siege")
	var waves: Array[WaveEntry] = [
		_wave(5.0, "shambler", 120, 0.07, 0), _wave(8.0, "shambler", 80, 0.1, 1),
		_wave(24.0, "runner", 120, 0.04, 1), _wave(30.0, "spitter", 22, 0.5, 0),
		_wave(46.0, "shambler", 380, 0.025, 0), _wave(52.0, "brute", 18, 0.8, 1),
		_wave(74.0, "runner", 220, 0.03, 0), _wave(80.0, "spitter", 34, 0.4, 1),
		_wave(98.0, "shambler", 480, 0.02, 1), _wave(104.0, "brute", 36, 0.45, 0),
		_wave(124.0, "runner", 220, 0.03, 1), _wave(138.0, "spitter", 30, 0.4, 0),
	]
	_save_mission("x9_town_siege", "Town Siege", map, "field_siege", 1000.0, 180.0, "fog", 0.12, 0.0, waves, ["mg_nest", "mg_nest", "rifle_soldier", "rifle_soldier", "gatling_gun"])


# --- 5. mountain_pass: a winding canyon with ridges --------------------------------------------------------------------------------------------

func _mountain_pass() -> void:
	_begin(44, 64, "n")
	_spawns = [Vector2i(20, 2), Vector2i(28, 2)]
	_path = [Vector2i(24, 10), Vector2i(14, 22), Vector2i(30, 34), Vector2i(16, 46), Vector2i(22, 57)]
	_core = Vector2i(22, 57)
	_make_routes()
	_open = OPEN_BASE.duplicate()
	for y in _h:
		for x in _w:
			var d := _dist_to_routes(_c(Vector2i(x, y)))
			var n := _noise(x, y)
			if d <= 4.6:
				_setc(x, y, "i" if n < 0.05 else ("v" if n < 0.09 else "n"))
			elif d <= 6.2 + n * 1.2:
				_setc(x, y, "#" if _noise(x, y, 5) > 0.06 else "n")  # the ridge, with a few gaps
			else:
				_setc(x, y, "v" if n < 0.07 else ("," if n < 0.09 else "n"))
	# the pass opens out at both ends (snow shelf at the spawn, flat ground at the base)
	_fill(14, 0, 34, 5, "n")
	_fill(14, 52, 32, 62, "n")
	_paint_routes(1.2, "v")
	# a few boulders scattered on the highlands (blocking, so they matter little)
	for i in 16:
		var cx := _rng.randi_range(0, _w - 1)
		var cy := _rng.randi_range(0, _h - 1)
		if _dist_to_routes(_c(Vector2i(cx, cy))) < 10.0:
			continue
		_fill(cx, cy, cx + _rng.randi_range(0, 2), cy + _rng.randi_range(0, 1), "#")
	_must("watchtower", 15, 55)
	_must("watchtower", 30, 55)
	_must("base_sandbag_corner", 16, 58)
	_must("base_sandbag_corner", 28, 58)
	_must("emp_pillbox", 18, 54)
	_must("emp_pillbox", 26, 54)
	_must("base_command_tent", 20, 60)
	_must("base_supply_stack", 25, 60)
	_scatter(["snow_pine", "snow_pine", "dead_pine", "snow_mound", "ice_chunk", "rock_spire", "slate_outcrop", "cliff_chunk", "boulder_pair"], 60, 0, 43, 0, 63, 2.4)
	_scatter(["campfire", "tent", "tarp_pile", "air_crashed_cargo", "wrecked_car"], 4, 8, 36, 4, 62, 3.0, false)
	var map := _save_map("mountain_pass")
	var waves: Array[WaveEntry] = [
		_wave(5.0, "shambler", 130, 0.06, 0), _wave(6.0, "shambler", 100, 0.08, 1),
		_wave(26.0, "runner", 110, 0.045, 1), _wave(32.0, "spitter", 22, 0.5, 0),
		_wave(48.0, "shambler", 400, 0.025, 1), _wave(54.0, "brute", 20, 0.8, 0),
		_wave(78.0, "runner", 200, 0.03, 0), _wave(84.0, "spitter", 34, 0.4, 1),
		_wave(102.0, "shambler", 500, 0.02, 0), _wave(108.0, "brute", 40, 0.45, 1),
		_wave(130.0, "runner", 230, 0.03, 1), _wave(145.0, "brute", 24, 0.5, 0),
	]
	_save_mission("x10_mountain_pass", "Mountain Pass", map, "field_siege", 1000.0, 185.0, "fog", 0.28, 0.0, waves, ["mg_nest", "mg_nest", "gatling_gun", "rifle_soldier", "rifle_soldier"])
