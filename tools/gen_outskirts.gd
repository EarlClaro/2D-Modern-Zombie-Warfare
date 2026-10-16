extends SceneTree
## Dev tool (not a test). Builds the 64x48 map `outskirts` (terrain, river with a bridge, farmland, forest, suburb
## with a town square, ruined district, an airstrip, the walled base compound with its gate) and, with `--missions`,
## the missions x2_outskirts and x3_storm_night. Seeded, so the output is reproducible; the map is data
## (data/maps/outskirts.tres) and can be edited by hand afterwards.
## Run: godot --headless --path . --script tools/gen_outskirts.gd [-- --missions]
## Only the map is written unless `--missions` is given (it then also rewrites x2_outskirts and x3_storm_night with
## the waves below, which overwrites any hand edits to those two missions).

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
# Ground that random scenery may stand on (not roads, tarmac, water, ice or paving).
const OPEN: Array[String] = [".", ",", "x", "g", "y", "f", "o", "v", "s", "d", "r", "q", "m"]
const FARM_MAX := Vector2i(21, 17)  # the farm fills the north-west corner up to here
# The airstrip north of the base: concrete apron with a hazard-marked edge, then the runway along ground x.
const APRON_MIN := Vector2i(2, 22)
const APRON_MAX := Vector2i(21, 26)
const RUNWAY_Y := 27
# The town square in the north: cobbles inside a brick border.
const SQUARE := Rect2i(47, 4, 6, 5)

var _rng := RandomNumberGenerator.new()
var _terrain: Array = []  # [y][x] -> String (one char)
var _lines: PackedStringArray = PackedStringArray()
var _taken: Dictionary = {}  # cell -> true (scenery footprints)
var _defs: Dictionary = {}  # scenery id -> footprint Vector2i
var _facings: Dictionary = {}  # scenery id -> true when its art was rendered with nw/ne too
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
	_biomes()
	_road_surface()
	_airstrip_ground()
	_town_square_ground()
	_farm_ground()
	_base_scenery()
	_airstrip_scenery()
	_town_square_scenery()
	_farm_scenery()
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
				if d.sprite != null and d.sprite.textures.has("NW"):
					_facings[d.id] = true


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


func _fill(x0: int, y0: int, x1: int, y1: int, ch: String) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			_setc(x, y, ch)


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
	# moss creeps over the grass around every rock
	for y in H:
		for x in W:
			if _getc(x, y) == "." and _next_to_any(x, y, ["#"]) and _rng.randf() < 0.7:
				_setc(x, y, "o")


func _next_to_any(x: int, y: int, chars: Array) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if (dx != 0 or dy != 0) and _getc(x + dx, y + dy) in chars:
				return true
	return false


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
	# the parade ground round the command bunker, hazard-marked aprons in front of the motor pool and the gate
	_fill(CORE.x - 3, CORE.y - 3, CORE.x + 3, CORE.y + 3, "t")
	_fill(9, 41, 12, 42, "h")
	_fill(BASE_MAX.x - 2, 37, BASE_MAX.x - 1, 39, "h")
	# gravel outside the wall
	for y in range(BASE_MIN.y - 2, BASE_MAX.y + 3):
		for x in range(BASE_MIN.x - 2, BASE_MAX.x + 3):
			if _getc(x, y) == "," and not _in_base(x, y) and _rng.randf() < 0.35:
				_setc(x, y, "v")


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


## Ground variety: meadow and dry-grass patches, sandy river banks with mud and shallows.
func _biomes() -> void:
	for y in H:
		for x in W:
			if _getc(x, y) == "." and not _in_base(x, y, 3):
				var f := sin(float(x) * 0.17 + 1.1) * sin(float(y) * 0.23 + 0.3)
				if f > 0.42:
					_setc(x, y, "g")
				elif f < -0.5:
					_setc(x, y, "y")
	for y in H:
		for x in W:
			var dx := absf(float(x) - _river_x(y))
			var ch := _getc(x, y)
			if ch == "w" and dx > 1.15 and not _in_base(x, y, 2):
				_setc(x, y, "~")
			elif ch in [".", ",", "g", "y"] and dx >= 1.9 and dx < 3.2 and not _in_base(x, y, 3):
				if _rng.randf() < 0.75:
					_setc(x, y, "s")
			elif ch in [".", ",", "g", "y"] and dx >= 3.2 and dx < 4.2 and not _in_base(x, y, 3):
				if _rng.randf() < 0.35:
					_setc(x, y, "m")


## Roads become asphalt (with worn and cracked stretches); the straight side roads get lane lines; gravel shoulders.
func _road_surface() -> void:
	for y in H:
		for x in W:
			if _getc(x, y) == "=":
				var r := _rng.randf()
				_setc(x, y, "a" if r < 0.8 else ("k" if r < 0.97 else "="))  # almost all dark: the lighter plain road tile made a checker
	for y in range(4, 21):
		if _getc(45, y) in ["a", "k", "="]:
			_setc(45, y, "L")
	for x in range(9, 30):
		if _getc(x, 21) in ["a", "k", "="]:
			_setc(x, 21, "l")
	for y in range(40, 46):
		if _getc(24, y) in ["a", "k", "="]:
			_setc(24, y, "L")
	for y in H:
		for x in W:
			if _getc(x, y) in [".", ",", "g", "y"] and _next_to_any(x, y, ["a", "k", "=", "l", "L"]) and _rng.randf() < 0.55:
				_setc(x, y, "v")


# ---- the airstrip north of the base ------------------------------------------------------------------------

func _airstrip_ground() -> void:
	_fill(APRON_MIN.x, APRON_MIN.y, APRON_MAX.x, APRON_MAX.y, "t")
	_fill(APRON_MIN.x, APRON_MAX.y, APRON_MAX.x, APRON_MAX.y, "h")
	_fill(1, RUNWAY_Y, 22, RUNWAY_Y + 1, "R")
	for x in range(0, 24):
		if _getc(x, RUNWAY_Y + 2) in [".", ",", "g", "y"]:
			_setc(x, RUNWAY_Y + 2, "v")


func _airstrip_scenery() -> void:
	_must("base_hangar", 2, 22)
	_must("base_control_tower", 20, 23)
	_must4("air_cargo_plane", 13, 22, "se")
	_must4("air_fighter_jet", 7, 22, "se")
	_must4("air_attack_jet", 7, 24, "se")
	_must4("air_utility_heli", 18, 25, "se")
	_must("base_fuel_pump", 2, 26)
	_must("base_hazard_drums", 5, 25)
	_must("base_warning_sign", 22, 26)
	_must("floodlight", 21, 22)
	_must("emp_searchlight_post", 23, 27)
	_must("emp_aa_gun", 1, 24)


# ---- the town square ----------------------------------------------------------------------------------------

func _town_square_ground() -> void:
	_fill(SQUARE.position.x - 1, SQUARE.position.y - 1, SQUARE.end.x, SQUARE.end.y, "b")
	_fill(SQUARE.position.x, SQUARE.position.y, SQUARE.end.x - 1, SQUARE.end.y - 1, "c")


func _town_square_scenery() -> void:
	var x := SQUARE.position.x
	var y := SQUARE.position.y
	_must("fountain", x + 2, y + 1)
	_must("park_statue", x + 4, y)
	_must("market_stall", x, y + 3)
	_must("market_stall", x + 3, y + 3)
	_must("street_cafe_table", x + 1, y)
	_must("street_cafe_table", x + 2, y)
	_must("street_lamp", x - 1, y - 1)
	_must("street_lamp", SQUARE.end.x, y - 1)
	_must("street_lamp", x - 1, SQUARE.end.y)
	_must("street_lamp", SQUARE.end.x, SQUARE.end.y)
	_must("bench", x + 4, y + 2)
	_must("bench_y", x - 1, y + 2)
	_must("mailbox", SQUARE.end.x, y + 2)
	_must("phone_booth", x - 1, y + 4)
	_must("bus_stop", x + 2, SQUARE.end.y)
	_must("newspaper_stand", x + 5, y + 4)


# ---- the farm in the north-west corner ---------------------------------------------------------------------

func _farm_ground() -> void:
	_fill(3, 3, 11, 9, "r")
	_fill(13, 3, 19, 9, "r")
	_fill(3, 11, 11, 16, "r")
	_fill(12, 3, 12, 16, "d")  # hardpan lane between the fields
	_fill(3, 10, 11, 10, "d")
	_fill(13, 10, 21, 10, "d")
	for y in range(11, 18):
		for x in range(13, 22):
			if _getc(x, y) in [".", "g", "y"] and _rng.randf() < 0.4:
				_setc(x, y, "d")


func _farm_scenery() -> void:
	_must("bld_farmhouse", 13, 12)
	_must("bld_barn", 17, 12)
	_must("bld_silo_complex", 17, 15)
	_must("bld_shed", 14, 16)
	_must("scarecrow", 6, 6)
	_must("scarecrow", 16, 6)
	_must("scarecrow", 7, 13)
	_must("water_well", 12, 11)
	_must("power_pole", 12, 2)
	_must("power_pole", 12, 9)
	for p in [Vector2i(4, 8), Vector2i(9, 4), Vector2i(14, 8), Vector2i(18, 4), Vector2i(4, 12), Vector2i(10, 15), Vector2i(8, 8), Vector2i(17, 7)]:
		_put("hay_bale", p.x, p.y, false, 0.0)


# ---- scenery placement ---------------------------------------------------------------------------------------

## Tries to place `id` at `cell`. Returns true when it fit (terrain, overlap, route corridor, bounds).
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
			if cx < 0 or cy < 0 or cx >= W or cy >= H or _taken.has(Vector2i(cx, cy)):
				return false
			if strict and not (_getc(cx, cy) in OPEN):
				return false
			if _dist_to_routes(_c(Vector2i(cx, cy))) < margin:
				return false
	for dy in fp.y:
		for dx in fp.x:
			_taken[Vector2i(x + dx, y + dy)] = true
	_lines.append(("%s %d %d %s" % [id, x, y, facing]).strip_edges())
	return true


## Manual placement (the base, the airstrip, the square): a failure is a bug in this script, so it is reported loudly.
func _must(id: String, x: int, y: int, facing: String = "") -> void:
	if not _defs.has(id):
		push_error("unknown scenery id %s" % id)
		_errors += 1
		return
	var fp: Vector2i = _defs[id]
	for dy in fp.y:
		for dx in fp.x:
			if _taken.has(Vector2i(x + dx, y + dy)):
				push_error("piece %s at (%d, %d) overlaps another" % [id, x, y])
				_errors += 1
				return
	for dy in fp.y:
		for dx in fp.x:
			_taken[Vector2i(x + dx, y + dy)] = true
	_lines.append(("%s %d %d %s" % [id, x, y, facing]).strip_edges())


## A vehicle, aircraft, emplacement or soldier: facing "se" or "nw" uses the art along ground x (nose to the
## south-east or the north-west); "sw" or "ne" uses the `_y` definition (art along ground y).
func _must4(id: String, x: int, y: int, facing: String) -> void:
	if facing in ["sw", "ne"]:
		_must(id + "_y", x, y, "nw" if facing == "ne" else "")
	else:
		_must(id, x, y, "nw" if facing == "nw" else "")


## Random orientation of a four-facing piece, tried with _put.
func _put4(id: String, x: int, y: int, strict: bool = true, margin: float = 2.2) -> bool:
	var o := _rng.randi() % 4
	var use_y := o >= 2 and _defs.has(id + "_y")
	var face := "nw" if (o % 2 == 1 and _facings.has(id)) else ""
	return _put(id + ("_y" if use_y else ""), x, y, strict, margin, face)


func _base_scenery() -> void:
	var x0 := BASE_MIN.x
	var y0 := BASE_MIN.y
	var x1 := BASE_MAX.x
	var y1 := BASE_MAX.y
	# corner towers
	for c in [Vector2i(x0, y0), Vector2i(x1, y0), Vector2i(x0, y1), Vector2i(x1, y1)]:
		_must("watchtower", c.x, c.y)
	# north and south walls (along x): razor-wire fence on the quiet west half, tall concrete on the front half
	for x in range(x0 + 1, x1 - 1, 2):
		_must("base_concrete_wall_tall" if x > 10 else "base_razor_wire_fence", x, y0)
		_must("base_concrete_wall_tall", x, y1)
	_must("floodlight", x1 - 1, y0)
	_must("floodlight", x1 - 1, y1)
	# west wall (along y)
	for y in range(y0 + 1, y1 - 1, 2):
		_must("base_razor_wire_fence_y", x0, y)
	_must("floodlight", x0, y1 - 1)
	# east (front) wall with the gate: gap on rows 37..39
	for y in [32, 34]:
		_must("base_concrete_wall_tall_y", x1, y)
	_must("gate_post", x1, 36)
	_must("gate_post", x1, 40)
	for y in [41, 43]:
		_must("base_concrete_wall_tall_y", x1, y)
	_must("boom_gate_y", x1 + 1, 36)
	_must("base_guard_shack", x1 - 1, 35)
	_must("base_guard_shack", x1 - 1, 41)
	_must("emp_mg_bunker", x1 - 1, 36)
	_must("emp_mg_bunker", x1 - 1, 40)
	# outside the gate: hesco, pillboxes, wire and dragon's teeth along the approach (clear of the route on row 38)
	_must("base_hesco_barrier_y", x1 + 1, 33)
	_must("base_hesco_barrier_y", x1 + 1, 42)
	_must("emp_pillbox", x1 + 2, 35)
	_must("emp_pillbox", x1 + 2, 41)
	_must("emp_razor_wire_y", x1 + 3, 33)
	_must("emp_razor_wire_y", x1 + 3, 43)
	_must("emp_dragons_teeth_y", x1 + 4, 35)
	_must("emp_dragons_teeth_y", x1 + 4, 41)
	# the command bunker area stays clear (rows 36..40 around the core, rows 37..39 to the gate)
	# north block: command tent, headquarters, comms, medical, the sensors
	_must("base_command_tent", 6, 32)
	_must("base_hq_building", 10, 32)
	_must("base_comms_center", 14, 32)
	_must("base_antenna_array", 17, 32)
	_must("emp_aa_gun", 9, 33)
	_must("emp_sam_launcher", 13, 33)
	_must("base_medical_bay", 13, 34)
	_must("base_water_tank", 17, 34)
	_must("emp_searchlight_post", 12, 35)
	_must("barracks", 6, 35)
	# west: services
	_must("base_latrine", 6, 37)
	_must("base_generator_shed", 6, 38)
	_must("fuel_tank", 6, 39)
	_must("radar_mast", 8, 38)
	_must("base_weapon_rack", 6, 40)
	_must("flag_pole", 8, 40)
	# south: mess, armoury, motor pool with its vehicles, workshop, stores
	_must("base_mess_hall", 6, 41)
	_must("base_armoury", 6, 43)
	_must("base_motor_pool", 9, 43)
	_must4("humvee", 9, 41, "se")
	_must4("apc_wheeled", 11, 41, "se")
	_must("base_fuel_pump", 9, 42)
	_must("base_workshop", 13, 43)
	_must("container_red", 16, 43)
	_must("helipad", 13, 40)
	_must("base_ammo_pile", 16, 41)
	_must("floodlight", 12, 36)
	_must("tire_stack", 17, 33)
	# trenches outside the north and west walls
	_must("emp_trench", 7, 29)
	_must("emp_trench", 12, 29)
	_must("emp_trench_y", 3, 35)


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
		if _facings.has(id):
			if _put4(id, x, y, strict, margin):
				placed += 1
		elif _put(id, x, y, strict, margin):
			placed += 1
	return placed


func _suburb() -> void:
	var houses := ["house_small", "house_small_brick", "house_large", "house_large_y", "shop", "shop_y", "bld_cottage", "bld_bungalow", "bld_villa", "bld_townhouse_row", "bld_cottage", "bld_bungalow"]
	_zone_try(houses, 16, 46, 61, 2, 31, 2.6)
	_zone_try(["apartment", "bld_office_block", "bld_tower_block"], 4, 47, 58, 6, 30, 3.0)
	_zone_try(["bld_church", "bld_school", "bld_clinic", "bld_police_station", "bld_fire_station", "bld_bank", "bld_diner", "bld_petrol_station", "bld_supermarket", "bld_hospital", "bld_motel", "bld_garage_shop"], 8, 46, 61, 2, 31, 3.0)
	_zone_try(["warehouse", "warehouse_y", "bld_factory"], 2, 48, 58, 22, 30, 3.0)
	_zone_try(["bld_water_tower"], 1, 48, 60, 22, 32, 3.0)
	_zone_try(["bush", "bush", "oak_tree", "oak_tree_b", "pine_tree", "birch_tree", "maple_autumn", "berry_bush", "flower_patch", "tall_grass"], 22, 44, 62, 2, 36, 2.2)


func _ruined_district() -> void:
	var ruins := ["house_ruin", "house_burnt", "shop_ruin", "shop_ruin_y", "warehouse_ruin", "barracks_ruin", "apartment_ruin", "apartment_burnt", "bld_church_ruin", "bld_hospital_ruin", "bld_supermarket_ruin", "bld_factory_ruin", "bld_tower_block_ruin", "bld_barn_burnt", "bld_office_block_burnt"]
	_zone_try(ruins, 12, 22, 37, 2, 18, 2.6)
	_zone_try(ruins, 8, 22, 34, 24, 44, 2.6)
	var bits := ["wall_ruin", "wall_ruin_y", "rubble_heap", "rubble_field", "wrecked_car", "scrap_pile", "burnt_tree", "dead_pine", "dead_tree", "branch_pile", "tree_stump"]
	_zone_try(bits, 26, 22, 38, 2, 46, 2.3)
	# a fallen convoy and the dead around it
	_zone_try(["ifv_tracked", "light_tank", "troop_truck", "ambulance", "armored_car", "recovery_truck", "aa_vehicle", "air_crashed_heli", "air_crashed_jet"], 6, 22, 37, 2, 46, 3.0)
	_zone_try(["inf_fallen", "inf_fallen", "inf_rifleman_kneel", "inf_medic"], 8, 22, 37, 2, 46, 2.4)
	_zone_try(["air_crashed_cargo"], 1, 24, 36, 4, 16, 3.0)
	# rubble, ash and craters round the damaged pieces
	for line in _lines.duplicate():
		var parts := line.split(" ")
		var pid: String = parts[0]
		if pid.contains("ruin") or pid.contains("burnt") or pid.contains("rubble") or pid.contains("crashed"):
			var fp: Vector2i = _defs[pid]
			var ox := int(parts[1])
			var oy := int(parts[2])
			var burnt := pid.contains("burnt") or pid.contains("crashed")
			for y in range(oy - 1, oy + fp.y + 1):
				for x in range(ox - 1, ox + fp.x + 1):
					if _getc(x, y) in [".", ",", "g", "y", "v", "o"] and _rng.randf() < 0.7 and _dist_to_routes(_c(Vector2i(x, y))) > 1.8:
						_setc(x, y, "q" if burnt and _rng.randf() < 0.6 else "x")
	for i in 14:
		var cx := _rng.randi_range(22, 37)
		var cy := _rng.randi_range(2, 46)
		if _getc(cx, cy) in [".", ",", "x", "q", "g", "y"] and not _taken.has(Vector2i(cx, cy)) and _dist_to_routes(_c(Vector2i(cx, cy))) > 2.4:
			_setc(cx, cy, "u")


func _forest() -> void:
	for y in range(1, H - 1):
		for x in range(1, W - 1):
			if _in_base(x, y, 3) or _taken.has(Vector2i(x, y)) or (x < FARM_MAX.x and y < FARM_MAX.y):
				continue
			if x < 24 and y > 18 and y < 31:
				continue  # the airstrip
			var density := (sin(float(x) * 0.21 + 0.9) * sin(float(y) * 0.19 + 2.1) + 1.0) * 0.5
			density = density * density
			if density > 0.55 and _rng.randf() < density * 0.55:
				var pick := _rng.randf()
				var near_water := absf(float(x) - _river_x(y)) < 7.0
				var id := ""
				if near_water and pick < 0.3:
					id = "willow_tree"
				elif pick < 0.28:
					id = "pine_tree"
				elif pick < 0.5:
					id = "oak_tree"
				elif pick < 0.62:
					id = "oak_tree_b"
				elif pick < 0.72:
					id = "birch_tree"
				elif pick < 0.78:
					id = "maple_autumn"
				elif pick < 0.83:
					id = "cypress_tree"
				elif pick < 0.88:
					id = "dead_tree"
				elif pick < 0.93:
					id = "fern"
				else:
					id = "bush"
				if _put(id, x, y, true, 2.0):
					for dy in range(-1, 2):
						for dx in range(-1, 2):
							if _getc(x + dx, y + dy) in [".", "g", "y", ","] and _rng.randf() < 0.65 and not _in_base(x + dx, y + dy, 3):
								_setc(x + dx, y + dy, "f")
	var floor_bits := ["boulder", "rock_pile", "fallen_log", "bush", "mossy_boulder", "mushrooms", "tree_stump", "branch_pile", "tall_grass", "flower_patch", "slate_outcrop", "boulder_pair", "rock_spire"]
	for i in 60:
		_put(floor_bits[_rng.randi() % floor_bits.size()], _rng.randi_range(1, W - 3), _rng.randi_range(1, H - 3), true, 2.0)
	# reeds and lily pads along the river
	for y in range(0, H - 1):
		var rx := int(round(_river_x(y)))
		for side in [-3, 3]:
			if _rng.randf() < 0.25:
				_put("reeds", rx + side, y, false, 1.2)
	for i in 8:
		var ly := _rng.randi_range(2, H - 3)
		_put("lily_pads", int(round(_river_x(ly))) - 1, ly, false, 1.0)


func _street_clutter() -> void:
	# lamps and signs beside the roads, bins and tyres where people used to live
	for t in range(0, 20):
		var a := _c(SPAWN_A).lerp(_c(PATH[0]), float(t) / 20.0)
		var off := Vector2(1.0, 1.0).normalized() * 2.6
		var cell := IsoProjection.cell_of(a + off)
		_put("street_lamp" if t % 4 == 0 else ("power_pole" if t % 4 == 2 else "road_sign"), cell.x, cell.y, true, 2.0)
	_zone_try(["trash_pile", "dumpster", "tire_stack", "bench", "street_lamp", "mailbox", "fire_hydrant", "wheelie_bin", "traffic_cone", "road_barricade", "vending_machine", "pallet_stack", "cardboard_boxes", "shopping_cart", "transformer", "ac_unit"], 40, 44, 62, 2, 36, 2.2)
	_zone_try(["trash_pile", "scrap_pile", "tire_stack", "cable_drum", "pallet_stack", "tarp_pile"], 12, 20, 36, 22, 44, 2.2)
	_zone_try(["gravestone", "gravestone", "picnic_table", "swing_set", "campfire", "lawn_chairs"], 8, 44, 62, 2, 36, 2.4)
	# bridge rails: low walls along both sides of the bridge on the water
	for x in range(37, 43, 2):
		_put("concrete_wall", x, 19, false, 0.9)
		_put("concrete_wall", x, 23, false, 0.9)
	# traffic lights where the town road meets the main road
	_put("traffic_light", 44, 19, false, 0.9)
	_put("traffic_light", 47, 23, false, 0.9)


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
	if "--missions" not in OS.get_cmdline_user_args():
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
