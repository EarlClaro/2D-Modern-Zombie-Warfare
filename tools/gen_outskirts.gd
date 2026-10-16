extends SceneTree
## Dev tool (not a test). Builds the 64x48 map `outskirts` (terrain, river with a bridge, forest, suburb, ruined
## district, the walled base compound with its gate) and the mission `x2_outskirts`. Seeded, so the output is
## reproducible; the map is data (data/maps/outskirts.tres) and can be edited by hand afterwards.
## Run: godot --headless --path . --script tools/gen_outskirts.gd

const W := 64
const H := 48
const SEED := 20261016

# Enemy routes: two spawns merge at the bridge, cross it, then run to the base gate and the core.
const SPAWN_A := Vector2i(60, 5)
const SPAWN_B := Vector2i(61, 34)
const PATH: Array[Vector2i] = [Vector2i(45, 21), Vector2i(30, 21), Vector2i(24, 38), Vector2i(19, 38), Vector2i(11, 38)]
const CORE := Vector2i(11, 38)
# The base compound (walls on its outer ring of cells).
const BASE_MIN := Vector2i(5, 31)
const BASE_MAX := Vector2i(19, 45)

var _rng := RandomNumberGenerator.new()
var _terrain: Array = []  # [y][x] -> String (one char)
var _lines: PackedStringArray = PackedStringArray()
var _taken: Dictionary = {}  # cell -> true (scenery footprints)
var _defs: Dictionary = {}  # scenery id -> footprint Vector2i
var _segments: Array = []  # [Vector2, Vector2] route segments in ground space (cell centres)
var _errors: int = 0


func _initialize() -> void:
	_rng.seed = SEED
	_load_footprints()
	_terrain_base()
	_routes()
	_river_and_bridge()
	_roads()
	_rocks()
	_base_ground()
	_verges_and_dirt()
	_base_scenery()
	_suburb()
	_ruined_district()
	_forest()
	_street_clutter()
	_save()
	print("outskirts: %d scenery pieces, %d error(s)" % [_lines.size(), _errors])
	quit()


func _load_footprints() -> void:
	for f in DirAccess.get_files_at("res://data/scenery"):
		if f.ends_with(".tres"):
			var d := load("res://data/scenery/" + f) as SceneryDefinition
			if d != null:
				_defs[d.id] = d.footprint


func _c(cell: Vector2i) -> Vector2:
	return IsoProjection.cell_center(cell)


func _terrain_base() -> void:
	for y in H:
		var row: Array = []
		for x in W:
			row.append(".")
		_terrain.append(row)


func _routes() -> void:
	var from := _c(SPAWN_A)
	for p in PATH:
		_segments.append([from, _c(p)])
		from = _c(p)
	from = _c(SPAWN_B)
	_segments.append([from, _c(PATH[0])])


func _dist_to_routes(p: Vector2) -> float:
	var best := INF
	for s in _segments:
		var a: Vector2 = s[0]
		var b: Vector2 = s[1]
		var t := clampf((p - a).dot(b - a) / maxf((b - a).length_squared(), 0.0001), 0.0, 1.0)
		best = minf(best, p.distance_to(a.lerp(b, t)))
	return best


func _setc(x: int, y: int, ch: String) -> void:
	if x >= 0 and y >= 0 and x < W and y < H:
		_terrain[y][x] = ch


func _getc(x: int, y: int) -> String:
	return _terrain[y][x] if x >= 0 and y >= 0 and x < W and y < H else ""


func _in_base(x: int, y: int, margin: int = 0) -> bool:
	return x >= BASE_MIN.x - margin and x <= BASE_MAX.x + margin and y >= BASE_MIN.y - margin and y <= BASE_MAX.y + margin


func _river_x(y: int) -> float:
	return 40.0 + 2.2 * sin(float(y) * 0.28)


func _river_and_bridge() -> void:
	for y in H:
		for x in W:
			if absf(float(x) - _river_x(y)) < 1.9 and not _in_base(x, y, 2):
				_setc(x, y, "w")


func _roads() -> void:
	# Painted along the exact enemy segments so what walks is what looks like a road (width ~3 cells).
	for s in _segments:
		_paint_road(s[0], s[1], 1.6)
	# A few side roads for the look of a town.
	_paint_road(_c(Vector2i(45, 21)), _c(Vector2i(45, 3)), 1.4)
	_paint_road(_c(Vector2i(30, 21)), _c(Vector2i(8, 21)), 1.4)
	_paint_road(_c(Vector2i(52, 14)), _c(Vector2i(62, 18)), 1.2)
	_paint_road(_c(Vector2i(24, 38)), _c(Vector2i(24, 46)), 1.2)


func _paint_road(a: Vector2, b: Vector2, half_w: float) -> void:
	for y in H:
		for x in W:
			var p := _c(Vector2i(x, y))
			var t := clampf((p - a).dot(b - a) / maxf((b - a).length_squared(), 0.0001), 0.0, 1.0)
			if p.distance_to(a.lerp(b, t)) <= half_w and not _in_base(x, y):
				_setc(x, y, "=")


func _rocks() -> void:
	for i in 26:
		var cx := _rng.randi_range(0, W - 1)
		var cy := _rng.randi_range(0, H - 1)
		var r := _rng.randf_range(1.0, 2.6)
		if _dist_to_routes(_c(Vector2i(cx, cy))) < 6.0 or _in_base(cx, cy, 4):
			continue
		for y in range(cy - 3, cy + 4):
			for x in range(cx - 3, cx + 4):
				if Vector2(x - cx, y - cy).length() <= r and _getc(x, y) in [".", ","]:
					_setc(x, y, "#")


func _base_ground() -> void:
	for y in range(BASE_MIN.y - 2, BASE_MAX.y + 3):
		for x in range(BASE_MIN.x - 2, BASE_MAX.x + 3):
			if x < 0 or y < 0 or x >= W or y >= H:
				continue
			if _in_base(x, y):
				_setc(x, y, "p")
			elif _getc(x, y) != "=":
				_setc(x, y, ",")  # trodden dirt around the walls
	# the gate road runs through the wall as paving
	for x in range(BASE_MAX.x - 1, BASE_MAX.x + 3):
		for y in range(37, 40):
			_setc(x, y, "p")


func _verges_and_dirt() -> void:
	for y in H:
		for x in W:
			var ch := _getc(x, y)
			if ch != ".":
				continue
			var d := _dist_to_routes(_c(Vector2i(x, y)))
			var patch := sin(float(x) * 0.31 + 1.7) * sin(float(y) * 0.27 + 0.4)
			if (d < 3.4 and _rng.randf() < 0.55) or patch > 0.72:
				_setc(x, y, ",")


# ---- scenery ----------------------------------------------------------------------------------------------

## Tries to place `id` at `cell`. Returns true when it fit (terrain, overlap, route corridor, bounds).
func _put(id: String, x: int, y: int, strict: bool = true, margin: float = 2.2) -> bool:
	var fp: Vector2i = _defs.get(id, Vector2i.ZERO)
	if fp == Vector2i.ZERO:
		push_error("unknown scenery id %s" % id)
		_errors += 1
		return false
	for dy in fp.y:
		for dx in fp.x:
			var cx := x + dx
			var cy := y + dy
			if cx < 0 or cy < 0 or cx >= W or cy >= H or _taken.has(Vector2i(cx, cy)):
				return false
			var ch := _getc(cx, cy)
			if strict and not (ch in [".", ",", "x"]):
				return false
			if _dist_to_routes(_c(Vector2i(cx, cy))) < margin:
				return false
	for dy in fp.y:
		for dx in fp.x:
			_taken[Vector2i(x + dx, y + dy)] = true
	_lines.append("%s %d %d" % [id, x, y])
	return true


## Manual placement inside the base: a failure is a bug in this script, so it is reported loudly.
func _must(id: String, x: int, y: int) -> void:
	var fp: Vector2i = _defs.get(id, Vector2i.ZERO)
	for dy in fp.y:
		for dx in fp.x:
			if _taken.has(Vector2i(x + dx, y + dy)):
				push_error("base piece %s at (%d, %d) overlaps another" % [id, x, y])
				_errors += 1
				return
	for dy in fp.y:
		for dx in fp.x:
			_taken[Vector2i(x + dx, y + dy)] = true
	_lines.append("%s %d %d" % [id, x, y])


func _base_scenery() -> void:
	var x0 := BASE_MIN.x
	var y0 := BASE_MIN.y
	var x1 := BASE_MAX.x
	var y1 := BASE_MAX.y
	# corner towers
	for c in [Vector2i(x0, y0), Vector2i(x1, y0), Vector2i(x0, y1), Vector2i(x1, y1)]:
		_must("watchtower", c.x, c.y)
	# north and south walls (along x), concrete on the front half, fence behind
	for x in range(x0 + 1, x1 - 1, 2):
		_must("concrete_wall" if x > 10 else "chain_fence", x, y0)
		_must("chain_fence", x, y1)
	_must("floodlight", x1 - 1, y0)
	_must("floodlight", x1 - 1, y1)
	# west wall (along y)
	for y in range(y0 + 1, y1 - 1, 2):
		_must("chain_fence_y", x0, y)
	_must("floodlight", x0, y1 - 1)
	# east (front) wall with the gate: gap on rows 37..39
	for y in [32, 34]:
		_must("concrete_wall_y", x1, y)
	_must("gate_post", x1, 36)
	_must("gate_post", x1, 40)
	for y in [41, 43]:
		_must("concrete_wall_y", x1, y)
	_must("boom_gate_y", x1 + 1, 36)
	_must("sandbag_line_y", x1 - 2, 35)
	_must("sandbag_line_y", x1 - 2, 41)
	# command bunker area stays clear; the buildings and equipment around it
	_must("tent", 6, 32)
	_must("tent", 10, 32)
	_must("tent", 14, 32)
	_must("barracks", 6, 35)
	_must("generator", 6, 38)
	_must("fuel_tank", 6, 39)
	_must("radar_mast", 8, 38)
	_must("flag_pole", 8, 40)
	_must("helipad", 13, 40)
	_must("container_red", 16, 43)
	_must("container_blue_y", 6, 41)
	_must("container_green", 9, 43)
	_must("floodlight", 12, 36)
	_must("trash_pile", 12, 44)
	_must("dumpster", 11, 42)
	_must("bench", 10, 35)
	_must("tire_stack", 17, 33)


func _zone_try(ids: Array, count: int, x_min: int, x_max: int, y_min: int, y_max: int, margin: float = 2.4, strict: bool = true) -> int:
	var placed := 0
	var attempts := count * 40
	while placed < count and attempts > 0:
		attempts -= 1
		var id: String = ids[_rng.randi() % ids.size()]
		var x := _rng.randi_range(x_min, x_max)
		var y := _rng.randi_range(y_min, y_max)
		if _in_base(x, y, 4):
			continue
		if _put(id, x, y, strict, margin):
			placed += 1
	return placed


func _suburb() -> void:
	var houses := ["house_small", "house_small_brick", "house_large", "house_large_y", "shop", "shop_y"]
	_zone_try(houses, 14, 46, 61, 2, 31, 2.6)
	_zone_try(["apartment"], 2, 47, 58, 6, 30, 3.0)
	_zone_try(["warehouse", "warehouse_y"], 1, 48, 58, 22, 30, 3.0)
	_zone_try(["bush", "bush", "oak_tree", "oak_tree_b", "pine_tree"], 16, 44, 62, 2, 36, 2.2)


func _ruined_district() -> void:
	var ruins := ["house_ruin", "house_burnt", "shop_ruin", "shop_ruin_y", "warehouse_ruin", "barracks_ruin", "apartment_ruin", "apartment_burnt"]
	var made := _zone_try(ruins, 11, 22, 37, 2, 18, 2.6)
	made += _zone_try(ruins, 7, 22, 34, 24, 44, 2.6)
	var bits := ["wall_ruin", "wall_ruin_y", "rubble_heap", "rubble_field", "wrecked_car", "scrap_pile"]
	_zone_try(bits, 22, 14, 38, 2, 46, 2.3)
	# rubble ground around every ruined piece
	for line in _lines:
		var parts := line.split(" ")
		if parts[0].contains("ruin") or parts[0].contains("burnt") or parts[0].contains("rubble"):
			var fp: Vector2i = _defs[parts[0]]
			var ox := int(parts[1])
			var oy := int(parts[2])
			for y in range(oy - 1, oy + fp.y + 1):
				for x in range(ox - 1, ox + fp.x + 1):
					if _getc(x, y) in [".", ","] and _rng.randf() < 0.7 and _dist_to_routes(_c(Vector2i(x, y))) > 1.8:
						_setc(x, y, "x")


func _forest() -> void:
	var count := 0
	for y in range(1, H - 1):
		for x in range(1, W - 1):
			if _in_base(x, y, 3) or _taken.has(Vector2i(x, y)):
				continue
			var density := (sin(float(x) * 0.21 + 0.9) * sin(float(y) * 0.19 + 2.1) + 1.0) * 0.5
			density = density * density
			if density > 0.55 and _rng.randf() < density * 0.55:
				var pick := _rng.randf()
				var id := "pine_tree" if pick < 0.4 else ("oak_tree" if pick < 0.7 else ("oak_tree_b" if pick < 0.85 else ("dead_tree" if pick < 0.93 else "bush")))
				if _put(id, x, y, true, 2.0):
					count += 1
	for i in 40:
		_put(["boulder", "rock_pile", "fallen_log", "bush"][_rng.randi() % 4], _rng.randi_range(1, W - 3), _rng.randi_range(1, H - 3), true, 2.0)


func _street_clutter() -> void:
	# lamps and signs beside the roads, bins and tyres where people used to live
	for t in range(0, 20):
		var a := _c(SPAWN_A).lerp(_c(PATH[0]), float(t) / 20.0)
		var off := Vector2(1.0, 1.0).normalized() * 2.6
		var cell := IsoProjection.cell_of(a + off)
		_put("street_lamp" if t % 4 == 0 else "road_sign", cell.x, cell.y, true, 2.0)
	_zone_try(["trash_pile", "dumpster", "tire_stack", "bench", "street_lamp"], 24, 44, 62, 2, 36, 2.2)
	_zone_try(["trash_pile", "scrap_pile", "tire_stack"], 10, 20, 36, 22, 44, 2.2)
	# bridge rails: low walls along both sides of the bridge on the water
	for x in range(37, 43, 2):
		_put("concrete_wall", x, 19, false, 0.9)
		_put("concrete_wall", x, 23, false, 0.9)


func _save() -> void:
	var rows := PackedStringArray()
	for y in H:
		rows.append("".join(_terrain[y]))
	var map := MapDefinition.new()
	map.id = "outskirts"
	map.rows = rows
	map.scenery = _lines
	var err := ResourceSaver.save(map, "res://data/maps/outskirts.tres")
	if err != OK:
		push_error("saving the map failed (%d)" % err)
		_errors += 1
		return
	var saved := load("res://data/maps/outskirts.tres") as MapDefinition
	var m := MissionDefinition.new()
	m.id = "x2_outskirts"
	m.display_name = "Hold the Outskirts"
	m.map = saved
	m.core_cell = CORE
	m.core_health = 900.0
	m.duration_s = 150.0
	m.core_scenery_id = "hq_bunker"
	m.core_radius = 1.2
	m.spawn_cells = [SPAWN_A, SPAWN_B]
	m.path_cells = PATH.duplicate()
	m.deploy_radius = 17.0
	m.deck_id = "fortified"
	m.time_of_day = 0.4  # late morning; the day runs 300 s, so the 150 s battle ends at dusk
	m.day_length_s = 300.0
	m.start_units = [_su("mg_nest", Vector2i(16, 36)), _su("mg_nest", Vector2i(16, 40)), _su("rifle_soldier", Vector2i(15, 38)), _su("jeep", Vector2i(16, 34))]
	var waves: Array[WaveEntry] = []
	waves.append(_wave(5.0, "shambler", 100, 0.08, 0))
	waves.append(_wave(5.0, "shambler", 75, 0.1, 1))
	waves.append(_wave(26.0, "runner", 100, 0.05, 0))
	waves.append(_wave(30.0, "spitter", 15, 0.6, 1))
	waves.append(_wave(48.0, "shambler", 300, 0.03, 0))
	waves.append(_wave(52.0, "brute", 12, 1.0, 1))
	waves.append(_wave(78.0, "runner", 175, 0.032, 1))
	waves.append(_wave(80.0, "spitter", 25, 0.5, 0))
	waves.append(_wave(100.0, "shambler", 400, 0.02, 0))
	waves.append(_wave(104.0, "brute", 30, 0.6, 1))
	waves.append(_wave(120.0, "runner", 150, 0.04, 0))
	m.waves = waves
	err = ResourceSaver.save(m, "res://data/missions/x2_outskirts.tres")
	if err != OK:
		push_error("saving the mission failed (%d)" % err)
		_errors += 1
	# the same battle at midnight in the rain
	m.id = "x3_storm_night"
	m.display_name = "Hold the Outskirts (Night Storm)"
	m.time_of_day = 0.0
	m.day_length_s = 0.0
	m.weather = "rain"
	err = ResourceSaver.save(m, "res://data/missions/x3_storm_night.tres")
	if err != OK:
		push_error("saving the night mission failed (%d)" % err)
		_errors += 1


func _su(unit_id: String, cell: Vector2i) -> StartUnit:
	var s := StartUnit.new()
	s.unit_id = unit_id
	s.cell = cell
	return s


func _wave(start: float, enemy: String, count: int, interval: float, spawn: int) -> WaveEntry:
	var w := WaveEntry.new()
	w.start_s = start
	w.enemy_id = enemy
	w.count = count
	w.interval_s = interval
	w.spawn_index = spawn
	return w
