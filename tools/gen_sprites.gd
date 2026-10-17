extends SceneTree
## Dev tool (not a test). Renders the sprite sheets (soldier, zombie, Gatling Gun, Tank, Helicopter) from
## simple box/cylinder/ellipsoid models: rays through the fixed 2:1 projection, 3-tone shading from one
## world light (all 8 facings are lit consistently, no mirroring), 1 px outline. Deterministic.
## Run: godot --headless --path . --script tools/gen_sprites.gd [-- --units=tank,rifle_soldier] [--packs=nature,town]
## Writes assets/sprites/<unit>/<facing>.png (facing = e, se, s, sw, w, nw, n, ne), one sheet per facing.
## Model axes (object-local, in tiles): +x forward, +y left, +z up (1.0 = Z_PX_PER_UNIT px).
## Theme packs: every tools/sprite_packs/pack_*.gd adds specs, materials and models (see docs/specs/art-pack-2.md).

const SEAM_DEPTH := 0.08  # depth gap (ray units) that draws a dark seam between two parts
const INK := Color("12140f")
const FOOT_MAX_Z := 0.2  # a part whose lowest point is above this does not count towards the ground footprint
const LIGHT := Vector3(0.25, 0.7, 0.8)  # world direction toward the light (ground x, ground y, up)

# material -> [dark, mid, light]
const MATS := {
	"hull": ["3b4a2a", "55683a", "6f8650"],
	"track": ["1f2220", "2c302c", "3a403b"],
	"gun": ["1c1e20", "3a3e42", "5c6268"],
	"glass": ["1e3b4a", "2f6a85", "6fb7d6"],
	"base": ["4a4338", "6b6252", "8a7f6a"],
	"ammo": ["2f3a24", "46552f", "5d7040"],
	"heli": ["2f3b3a", "46585a", "62797a"],
	"rotor": ["15181a", "1f2326", "2c3235"],
	# humanoids
	"uni": ["434f31", "5b6b43", "74875a"],
	"vest": ["2b3326", "3c4636", "4f5c47"],
	"belt": ["1d1a14", "2b2620", "3c352b"],
	"pack": ["4d432b", "6b5d3e", "857553"],
	"helm": ["3a4a2c", "4a5a3a", "7a8f5c"],
	"skin": ["b98a64", "d9a87f", "ecc39f"],
	"boot": ["1c1712", "2b241d", "3d342a"],
	"eye": ["12140f", "12140f", "12140f"],
	"zskin": ["58774a", "7fa069", "9ec184"],
	"shirt": ["434a56", "6a7280", "8892a1"],
	"shirtd": ["2f343d", "434a56", "58606e"],
	"pants": ["332e27", "4b4338", "5f5547"],
	"red": ["8a1f18", "d23a2e", "ff6a55"],
	"mouth": ["1a0c0c", "2a1414", "3a1c1c"],
	"stock": ["3b2a1a", "5b4128", "7a5a3a"],
	"lip": ["8f5f45", "a8705a", "bf8a74"],
	"hair": ["1a1410", "2a2018", "3a2e24"],
	"wound": ["5a1a14", "7a2a20", "9a3a2e"],
	"tooth": ["b0a98c", "e8e2c8", "fffaf0"],
	"zdark": ["3d5733", "58774a", "7fa069"],
	# variants
	"rshirt": ["5a1f1a", "8a3228", "ad4a3c"],
	"rpants": ["22201d", "33302b", "46423b"],
	"bpants": ["26262b", "38383f", "4c4c56"],
	"vestt": ["5a4d36", "7a6a4a", "978660"],
	"tube": ["3a3f2a", "55603c", "74814f"],
	"warhead": ["6a2a14", "9a4a22", "c46a34"],
	"brass": ["8a6a1e", "c29a30", "e8c85a"],
	"steel": ["2a3030", "454e4e", "66726f"],
	# machines: sandbags, ground, fire, smoke and burnt-out versions
	"sand": ["8a7348", "a88f5c", "c2a974"],
	"dirt": ["2a2418", "3a3426", "4a4332"],
	"fire": ["b43a0c", "f0701a", "ffd24a"],
	"flash": ["f0a020", "ffd060", "fff4c0"],
	"smoke": ["2b2b2b", "444444", "5f5f5f"],
	"hullc": ["14160f", "1f2218", "2c3024"],
	"trackc": ["0f100f", "171917", "202320"],
	"gunc": ["0e0f10", "18191b", "26282b"],
	"helic": ["15191a", "1f2526", "2c3435"],
	"basec": ["221f1a", "302c24", "40392f"],
	"sandc": ["3a3023", "4d402c", "61513a"],
	"dirtc": ["14120e", "1c1913", "26221a"],
	# props
	"wood": ["6a4a2a", "8f6a3e", "b08a58"],
	"woodd": ["3e2a16", "58401f", "725430"],
	"woodc": ["1c140c", "28201a", "362b1f"],
	"concrete": ["6a6a66", "8d8d86", "b0b0a8"],
	"concretec": ["26262a", "34343a", "46464c"],
	"drum": ["6a2a1c", "8f3e28", "b05a3c"],
	"drumc": ["1c1410", "2a1f1a", "3a2c24"],
	"canvas": ["5a5236", "7a7048", "9a8e60"],
	"canvasc": ["201e16", "2c2a1e", "3a3828"],
	"rust": ["4a2a1a", "6b3d24", "8a5434"],
	"rustc": ["1e1410", "2a1e18", "382a22"],
	"steelc": ["14181a", "1f2527", "2c3335"],
	# spitter and charred wreck
	"acid": ["5a7a10", "8fc020", "c8f050"],
	"acidh": ["7a9a20", "b8e040", "eaff80"],
	"acidd": ["3a5208", "567a10", "7a9e1c"],
	"rags": ["3a2f20", "58492f", "756444"],
	"char": ["171513", "26231f", "3a352f"],
	"charhi": ["241f1a", "3b342c", "544a3f"],
	# scenery
	"leaf": ["2f5a2a", "447a38", "63a04c"],
	"leafd": ["234a2c", "356638", "4c8450"],
	"leafl": ["3d6a30", "5a8f42", "7db85a"],
	"bark": ["2e2118", "4a3524", "654a33"],
	"deadwood": ["3a3631", "5a544c", "7a7266"],
	"stone": ["3e4046", "5c5f66", "7c8088"],
	"stonel": ["4c4e55", "6c6f77", "8d9199"],
	"bag": ["14161a", "232830", "363d48"],
	"cardboard": ["5e4828", "816539", "a1824f"],
	"dump": ["1f4430", "2b6040", "3a7e54"],
	"dumpd": ["173525", "20492f", "2c6341"],
	"lampglow": ["e8c870", "fbe9a0", "fffbe0"],
	"whitep": ["a8a8a4", "d4d4d0", "f2f2ee"],
	"plaster": ["8f8872", "b3ac94", "d3ccb4"],
	"plasterw": ["a0a09a", "c8c8c0", "e6e6de"],
	"plasterc": ["3a342d", "4f473c", "675d4e"],
	"brick": ["5e2a22", "7e3d30", "9c5444"],
	"roofred": ["54261f", "743729", "94503a"],
	"slate": ["272d33", "38414a", "4d5965"],
	"tento": ["34432a", "4d6137", "677e49"],
	"corrugated": ["505860", "727c86", "949ea8"],
	"concretel": ["7a7a76", "9a9a94", "babab3"],
	"tankg": ["58605a", "7a847c", "9ca79e"],
	"padg": ["30353a", "40464c", "525a62"],
	"rubble": ["3f3b36", "58544c", "736f65"],
	"cont_red": ["54201a", "7e3328", "a04a3a"],
	"cont_blue": ["1c2a44", "2a4572", "40649a"],
	"cont_green": ["26382a", "385040", "4d6c56"],
}

const BOX := 0
const CYL := 1  # vertical cylinder: half.x = radius, half.z = half height
const SPH := 2  # ellipsoid: half = radii

var _light := LIGHT.normalized()
var _track_phase: float = 0.0
var _kit: String = "rifle"  # soldier weapon: "rifle", "rpg", "sniper" or "mortar"
var _variant: String = ""  # tank rig variants: "ifv"
var _z_stride: float = 1.0  # zombie variants: stride multiplier
var _z_lean: float = 0.0  # zombie variants: extra forward lean (rad)
var _spec_k: Dictionary = {}  # unit -> uniform scale, filled from the specs
var _k: float = 1.0  # scenery: uniform enlargement applied to the finished model
var _z_kind: String = ""  # zombie variants: "spitter" adds the acid sac and the spit stream
var _packs: Array = []  # loaded theme-pack scripts (tools/sprite_packs/pack_*.gd)
var _mats: Dictionary = MATS.duplicate()  # MATS plus every pack's own materials


class Prim:
	var kind: int
	var c: Vector3
	var h: Vector3
	var mat: String
	var basis: Basis = Basis.IDENTITY
	var stripe: float = 0.0  # >0: alternating dark bands along local x on side faces (tank tracks)

	func _init(p_kind: int, p_c: Vector3, p_h: Vector3, p_mat: String, p_yaw: float = 0.0, p_stripe: float = 0.0, p_pitch: float = 0.0) -> void:
		kind = p_kind
		c = p_c
		h = p_h
		mat = p_mat
		stripe = p_stripe
		basis = Basis(Vector3(0, 0, 1), p_yaw) * Basis(Vector3(0, 1, 0), p_pitch)


func _initialize() -> void:
	var specs := [
		{"dir": "rifle_soldier", "frame": Vector2i(88, 72), "origin": Vector2(44, 44), "frames": 10, "columns": 3, "ss": 3},
		{"dir": "shambler", "frame": Vector2i(72, 72), "origin": Vector2(36, 44), "frames": 10, "columns": 3, "ss": 3},
		{"dir": "mg_nest", "frame": Vector2i(64, 48), "origin": Vector2(32, 32), "frames": 5, "columns": 3, "ss": 2},
		{"dir": "gatling_gun", "frame": Vector2i(64, 48), "origin": Vector2(32, 32), "frames": 5, "columns": 3, "ss": 1},
		{"dir": "tank", "frame": Vector2i(80, 56), "origin": Vector2(40, 38), "frames": 9, "columns": 3, "ss": 1},
		{"dir": "helicopter", "frame": Vector2i(96, 64), "origin": Vector2(48, 46), "frames": 8, "columns": 2, "ss": 1},
		{"dir": "runner", "frame": Vector2i(72, 72), "origin": Vector2(36, 44), "frames": 10, "columns": 3, "ss": 3},
		{"dir": "brute", "frame": Vector2i(80, 72), "origin": Vector2(40, 54), "frames": 10, "columns": 3, "ss": 3},
		{"dir": "spitter", "frame": Vector2i(88, 72), "origin": Vector2(44, 44), "frames": 10, "columns": 3, "ss": 3},
		{"dir": "rpg_soldier", "frame": Vector2i(124, 76), "origin": Vector2(62, 46), "frames": 10, "columns": 3, "ss": 3},
		{"dir": "howitzer", "frame": Vector2i(128, 104), "origin": Vector2(64, 62), "frames": 6, "columns": 3, "ss": 1},
		{"dir": "marksman", "frame": Vector2i(124, 76), "origin": Vector2(62, 46), "frames": 10, "columns": 3, "ss": 3},
		{"dir": "mortar_team", "frame": Vector2i(100, 76), "origin": Vector2(46, 46), "frames": 10, "columns": 3, "ss": 3},
		{"dir": "ifv", "frame": Vector2i(80, 56), "origin": Vector2(40, 38), "frames": 9, "columns": 3, "ss": 1},
		{"dir": "rocket_launcher", "frame": Vector2i(128, 104), "origin": Vector2(64, 62), "frames": 6, "columns": 3, "ss": 1},
		{"dir": "sandbag_wall", "frame": Vector2i(80, 64), "origin": Vector2(40, 42), "frames": 4, "columns": 2, "ss": 2},
		{"dir": "concrete_barrier", "frame": Vector2i(80, 64), "origin": Vector2(40, 42), "frames": 4, "columns": 2, "ss": 2},
		{"dir": "crate_stack", "frame": Vector2i(64, 56), "origin": Vector2(32, 40), "frames": 4, "columns": 2, "ss": 2},
		{"dir": "oil_drums", "frame": Vector2i(64, 56), "origin": Vector2(32, 40), "frames": 4, "columns": 2, "ss": 2},
		{"dir": "tank_trap", "frame": Vector2i(64, 56), "origin": Vector2(32, 40), "frames": 4, "columns": 2, "ss": 2},
		{"dir": "jeep", "frame": Vector2i(80, 60), "origin": Vector2(40, 42), "frames": 5, "columns": 3, "ss": 1},
		{"dir": "supply_truck", "frame": Vector2i(112, 76), "origin": Vector2(56, 52), "frames": 5, "columns": 3, "ss": 1},
		{"dir": "oak_tree", "auto": true, "k": 1.8, "frames": 1, "columns": 1, "ss": 2, "facings": ["se"]},
		{"dir": "oak_tree_b", "auto": true, "k": 1.9, "frames": 1, "columns": 1, "ss": 2, "facings": ["se"]},
		{"dir": "pine_tree", "auto": true, "k": 1.8, "frames": 1, "columns": 1, "ss": 2, "facings": ["se"]},
		{"dir": "dead_tree", "auto": true, "k": 1.7, "frames": 1, "columns": 1, "ss": 2, "facings": ["se"]},
		{"dir": "bush", "auto": true, "k": 1.4, "frames": 1, "columns": 1, "ss": 2, "facings": ["se"]},
		{"dir": "boulder", "auto": true, "k": 1.5, "frames": 1, "columns": 1, "ss": 2, "facings": ["se"]},
		{"dir": "rock_pile", "auto": true, "k": 1.5, "frames": 1, "columns": 1, "ss": 2, "facings": ["se"]},
		{"dir": "fallen_log", "auto": true, "k": 1.5, "frames": 1, "columns": 1, "ss": 2, "facings": ["se", "sw"]},
		{"dir": "trash_pile", "auto": true, "k": 1.3, "frames": 1, "columns": 1, "ss": 2, "facings": ["se"]},
		{"dir": "dumpster", "auto": true, "k": 1.3, "frames": 1, "columns": 1, "ss": 2, "facings": ["se", "sw"]},
		{"dir": "tire_stack", "auto": true, "k": 1.3, "frames": 1, "columns": 1, "ss": 2, "facings": ["se"]},
		{"dir": "scrap_pile", "auto": true, "k": 1.4, "frames": 1, "columns": 1, "ss": 2, "facings": ["se"]},
		{"dir": "street_lamp", "auto": true, "k": 2.0, "frames": 1, "columns": 1, "ss": 2, "facings": ["se", "sw"]},
		{"dir": "road_sign", "auto": true, "k": 1.8, "frames": 1, "columns": 1, "ss": 2, "facings": ["se", "sw"]},
		{"dir": "bench", "auto": true, "k": 1.3, "frames": 1, "columns": 1, "ss": 2, "facings": ["se", "sw"]},
		{"dir": "house_small", "auto": true, "k": 1.45, "frames": 1, "columns": 1, "ss": 1, "facings": ["se"]},
		{"dir": "house_small_brick", "auto": true, "k": 1.45, "frames": 1, "columns": 1, "ss": 1, "facings": ["se"]},
		{"dir": "house_large", "auto": true, "k": 1.3, "frames": 1, "columns": 1, "ss": 1, "facings": ["se", "sw"]},
		{"dir": "house_ruin", "auto": true, "k": 1.45, "frames": 1, "columns": 1, "ss": 1, "facings": ["se"]},
		{"dir": "house_burnt", "auto": true, "k": 1.45, "frames": 1, "columns": 1, "ss": 1, "facings": ["se"]},
		{"dir": "shop", "auto": true, "k": 1.3, "frames": 1, "columns": 1, "ss": 1, "facings": ["se", "sw"]},
		{"dir": "shop_ruin", "auto": true, "k": 1.3, "frames": 1, "columns": 1, "ss": 1, "facings": ["se", "sw"]},
		{"dir": "apartment", "auto": true, "k": 1.25, "frames": 1, "columns": 1, "ss": 1, "facings": ["se"]},
		{"dir": "apartment_ruin", "auto": true, "k": 1.25, "frames": 1, "columns": 1, "ss": 1, "facings": ["se"]},
		{"dir": "apartment_burnt", "auto": true, "k": 1.25, "frames": 1, "columns": 1, "ss": 1, "facings": ["se"]},
		{"dir": "warehouse", "auto": true, "k": 1.15, "frames": 1, "columns": 1, "ss": 1, "facings": ["se", "sw"]},
		{"dir": "warehouse_ruin", "auto": true, "k": 1.15, "frames": 1, "columns": 1, "ss": 1, "facings": ["se", "sw"]},
		{"dir": "wall_ruin", "auto": true, "k": 1.5, "frames": 1, "columns": 1, "ss": 2, "facings": ["se", "sw"]},
		{"dir": "rubble_heap", "auto": true, "k": 1.4, "frames": 1, "columns": 1, "ss": 2, "facings": ["se"]},
		{"dir": "rubble_field", "auto": true, "k": 1.4, "frames": 1, "columns": 1, "ss": 1, "facings": ["se"]},
		{"dir": "hq_bunker", "auto": true, "k": 1.2, "frames": 4, "columns": 2, "ss": 1, "facings": ["se"]},
		{"dir": "concrete_wall", "auto": true, "k": 1.7, "frames": 1, "columns": 1, "ss": 2, "facings": ["se", "sw"]},
		{"dir": "chain_fence", "auto": true, "k": 1.7, "frames": 1, "columns": 1, "ss": 2, "facings": ["se", "sw"]},
		{"dir": "sandbag_line", "auto": true, "k": 1.7, "frames": 1, "columns": 1, "ss": 2, "facings": ["se", "sw"]},
		{"dir": "gate_post", "auto": true, "k": 1.6, "frames": 1, "columns": 1, "ss": 2, "facings": ["se"]},
		{"dir": "boom_gate", "auto": true, "k": 1.6, "frames": 1, "columns": 1, "ss": 2, "facings": ["se", "sw"]},
		{"dir": "watchtower", "auto": true, "k": 1.5, "frames": 1, "columns": 1, "ss": 1, "facings": ["se"]},
		{"dir": "floodlight", "auto": true, "k": 1.7, "frames": 1, "columns": 1, "ss": 2, "facings": ["se"]},
		{"dir": "tent", "auto": true, "k": 1.4, "frames": 1, "columns": 1, "ss": 1, "facings": ["se", "sw"]},
		{"dir": "generator", "auto": true, "k": 1.5, "frames": 1, "columns": 1, "ss": 2, "facings": ["se", "sw"]},
		{"dir": "fuel_tank", "auto": true, "k": 1.5, "frames": 1, "columns": 1, "ss": 2, "facings": ["se"]},
		{"dir": "container_red", "auto": true, "k": 1.5, "frames": 1, "columns": 1, "ss": 1, "facings": ["se", "sw"]},
		{"dir": "container_blue", "auto": true, "k": 1.5, "frames": 1, "columns": 1, "ss": 1, "facings": ["se", "sw"]},
		{"dir": "container_green", "auto": true, "k": 1.5, "frames": 1, "columns": 1, "ss": 1, "facings": ["se", "sw"]},
		{"dir": "radar_mast", "auto": true, "k": 1.7, "frames": 1, "columns": 1, "ss": 2, "facings": ["se"]},
		{"dir": "flag_pole", "auto": true, "k": 1.7, "frames": 1, "columns": 1, "ss": 2, "facings": ["se"]},
		{"dir": "helipad", "auto": true, "k": 1.0, "frames": 1, "columns": 1, "ss": 1, "facings": ["se"]},
		{"dir": "barracks", "auto": true, "k": 1.3, "frames": 1, "columns": 1, "ss": 1, "facings": ["se", "sw"]},
		{"dir": "barracks_ruin", "auto": true, "k": 1.3, "frames": 1, "columns": 1, "ss": 1, "facings": ["se", "sw"]},
		{"dir": "wrecked_car", "frame": Vector2i(80, 56), "origin": Vector2(40, 38), "frames": 1, "columns": 1, "ss": 1},
	]
	_load_packs(specs)
	var only: PackedStringArray = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--units="):
			only = a.substr(8).split(",")
	for spec in specs:
		if spec.has("k"):
			_spec_k[spec["dir"]] = spec["k"]
	for spec in specs:
		if only.is_empty() or spec["dir"] in only:
			if spec.get("auto", false):
				_auto_frame(spec)
			_render_unit(spec)
	quit()


## Loads tools/sprite_packs/pack_*.gd: appends each pack's specs and merges its materials (a material name that
## already exists is an error, so packs prefix theirs).
func _load_packs(specs: Array) -> void:
	var dir := DirAccess.open("res://tools/sprite_packs")
	if dir == null:
		return
	var wanted: PackedStringArray = []  # --packs=nature,town loads only those (a broken pack then cannot block the others)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--packs="):
			wanted = a.substr(8).split(",")
	var files := Array(dir.get_files())
	files.sort()
	for f in files:
		if not (f.begins_with("pack_") and f.ends_with(".gd")):
			continue
		if not wanted.is_empty() and f.trim_prefix("pack_").trim_suffix(".gd") not in wanted:
			continue
		var pk: GDScript = load("res://tools/sprite_packs/%s" % f)
		if pk == null:
			push_error("cannot load pack %s" % f)
			continue
		var consts: Dictionary = pk.get_script_constant_map()
		var pack_mats: Dictionary = consts.get("MATS", {})
		for k in pack_mats:
			if _mats.has(k):
				push_error("pack %s: material '%s' already exists" % [f, k])
			_mats[k] = pack_mats[k]
		_packs.append(pk)
		for spec in pk.specs():
			specs.append(spec)


## Sizes the frame to fit every primitive of every frame and listed facing (4 px margin) and stores origin and
## size in the spec; also writes assets/sprites/<unit>/frame.json (frame, origin, layout, ground footprint in
## cells, height in units) so the data tool can read them.
func _auto_frame(spec: Dictionary) -> void:
	var unit: String = spec["dir"]
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var half := Vector2.ZERO  # largest |x|, |y| of any part in model axes (the ground footprint)
	var top := 0.0
	for f in 8:
		if IsoProjection.facing_name(f).to_lower() not in spec["facings"]:
			continue
		var fwd := IsoProjection.ground_dir_of_facing(f)
		var perp := Vector2(-fwd.y, fwd.x)
		for k in spec["frames"]:
			for p in _model(unit, k):
				var ext := Vector3(p.h.x, p.h.y, p.h.z)
				if p.kind == CYL:
					ext = Vector3(p.h.x, p.h.x, p.h.z)
				for sx in [-1.0, 1.0]:
					for sy in [-1.0, 1.0]:
						for sz in [-1.0, 1.0]:
							var q: Vector3 = p.c + p.basis * Vector3(ext.x * sx, ext.y * sy, ext.z * sz)
							var g := fwd * q.x + perp * q.y
							var sp := IsoProjection.ground_to_screen_z(g, q.z)
							lo = lo.min(sp)
							hi = hi.max(sp)
	for k in spec["frames"]:  # footprint: only parts that reach the ground count (a tree's crown does not)
		for p in _model(unit, k):
			var ext := Vector3(p.h.x, p.h.y, p.h.z)
			if p.kind == CYL:
				ext = Vector3(p.h.x, p.h.x, p.h.z)
			var corners: Array[Vector3] = []
			var zmin := INF
			for sx in [-1.0, 1.0]:
				for sy in [-1.0, 1.0]:
					for sz in [-1.0, 1.0]:
						var q: Vector3 = p.c + p.basis * Vector3(ext.x * sx, ext.y * sy, ext.z * sz)
						corners.append(q)
						zmin = minf(zmin, q.z)
						top = maxf(top, q.z)
			if zmin < FOOT_MAX_Z:
				for q in corners:
					half = half.max(Vector2(absf(q.x), absf(q.y)))
	var margin := 4.0
	lo -= Vector2(margin, margin)
	hi += Vector2(margin, margin)
	var size := Vector2i(int(ceil(hi.x - lo.x)), int(ceil(hi.y - lo.y)))
	spec["frame"] = size
	spec["origin"] = Vector2(floor(-lo.x), floor(-lo.y))
	DirAccess.make_dir_recursive_absolute("res://assets/sprites/%s" % unit)
	var fh := FileAccess.open("res://assets/sprites/%s/frame.json" % unit, FileAccess.WRITE)
	var foot := Vector2i(maxi(1, ceili(2.0 * half.x - 0.1)), maxi(1, ceili(2.0 * half.y - 0.1)))
	foot = spec.get("foot", foot)  # a pack's own footprint wins over the estimate
	fh.store_string(JSON.stringify({"frame": [size.x, size.y], "origin": [int(spec["origin"].x), int(spec["origin"].y)], "frames": spec["frames"], "columns": spec["columns"], "footprint": [foot.x, foot.y], "height": snappedf(top, 0.01)}))
	fh.close()


func _render_unit(spec: Dictionary) -> void:
	var unit: String = spec["dir"]
	var frame_size: Vector2i = spec["frame"]
	var frames: int = spec["frames"]
	var columns: int = spec["columns"]
	var rows := int(ceil(float(frames) / columns))
	DirAccess.make_dir_recursive_absolute("res://assets/sprites/%s" % unit)
	var facings: Array = spec.get("facings", ["e", "se", "s", "sw", "w", "nw", "n", "ne"])
	for f in 8:
		if IsoProjection.facing_name(f).to_lower() not in facings:
			continue
		var sheet := Image.create(frame_size.x * columns, frame_size.y * rows, false, Image.FORMAT_RGBA8)
		for k in frames:
			var model := _model(unit, k)
			var img := _render(model, f, frame_size, spec["origin"], spec["ss"])
			@warning_ignore("integer_division")
			var row := k / columns
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, frame_size), Vector2i((k % columns) * frame_size.x, row * frame_size.y))
		var path := "res://assets/sprites/%s/%s.png" % [unit, IsoProjection.facing_name(f).to_lower()]
		var err := sheet.save_png(path)
		print("%s %s (%dx%d)" % ["wrote" if err == OK else "FAILED", path, sheet.get_width(), sheet.get_height()])


static func _ry(theta: float) -> Basis:
	return Basis(Vector3(0, 1, 0), theta)


## A part hanging off a pivot: its centre is `off` (in the part's own frame) rotated by `theta` about +y.
static func _limb(kind: int, pivot: Vector3, off: Vector3, half: Vector3, mat: String, theta: float) -> Prim:
	return Prim.new(kind, pivot + _ry(theta) * off, half, mat, 0.0, 0.0, theta)


func _model(unit: String, frame: int) -> Array[Prim]:
	var m: Array[Prim] = []
	_track_phase = 0.0
	_kit = "rifle"
	_variant = ""
	_z_stride = 1.0
	_z_lean = 0.0
	_z_kind = ""
	_k = _spec_k.get(unit, 1.0)
	match unit:
		"rifle_soldier":
			_soldier(m, frame)
		"rpg_soldier":
			_kit = "rpg"
			_soldier(m, frame)
			_remap(m, {"vest": "vestt"})
		"shambler":
			_zombie(m, frame)
		"runner":  # fast, lean, bloodied: long stride, deep forward lean
			_z_stride = 1.8
			_z_lean = 0.14
			_zombie(m, frame)
			_remap(m, {"shirt": "rshirt", "pants": "rpants"})
			_scale(m, 0.96)
		"spitter":  # upright, bloated throat sac, spits acid on its attack frame
			_z_kind = "spitter"
			_z_lean = -0.06
			_zombie(m, frame)
			_remap(m, {"shirt": "rags"})
		"brute":  # hulking, slow, bare-chested
			_z_stride = 0.75
			_z_lean = 0.05
			_zombie(m, frame)
			_remap(m, {"shirt": "zskin", "shirtd": "zdark", "pants": "bpants"})
			_scale(m, 1.3)
		"howitzer":
			_howitzer(m, frame)
		"marksman":  # long rifle with a scope, desert-brown kit
			_kit = "sniper"
			_soldier(m, frame)
			_remap(m, {"uni": "pack", "helm": "pack", "vest": "vestt"})
		"mortar_team":
			_kit = "mortar"
			_soldier(m, frame)
			_remap(m, {"vest": "vestt"})
		"ifv":
			_variant = "ifv"
			_tank(m, frame)
		"rocket_launcher":
			_rocket_launcher(m, frame)
		"sandbag_wall":
			_sandbags(m, frame)
		"concrete_barrier":
			_barrier(m, frame)
		"crate_stack":
			_crates(m, frame)
		"oil_drums":
			_drums(m, frame)
		"tank_trap":
			_trap(m, frame)
		"jeep":
			_jeep(m, frame)
		"supply_truck":
			_truck(m, frame)
		"wrecked_car":
			_wreck_car(m)
		"tank":
			_tank(m, frame)
		"gatling_gun":
			_gatling(m, frame)
		"mg_nest":
			_nest(m, frame)
		"helicopter":
			_heli(m, frame)
		_:
			_scenery_model(m, unit, frame)
	return m


## Scenery models, built at authoring scale and then enlarged by the spec's uniform factor `_k`.
func _scenery_model(m: Array[Prim], unit: String, frame: int) -> void:
	match unit:
		"oak_tree":
			_oak(m, 0)
		"oak_tree_b":
			_oak(m, 1)
		"pine_tree":
			_pine(m)
		"dead_tree":
			_dead_tree(m)
		"bush":
			_bush(m)
		"boulder":
			_boulder(m)
		"rock_pile":
			_rock_pile(m)
		"fallen_log":
			_fallen_log(m)
		"trash_pile":
			_trash_pile(m)
		"dumpster":
			_dumpster(m)
		"tire_stack":
			_tire_stack(m)
		"scrap_pile":
			_scrap_pile(m)
		"street_lamp":
			_street_lamp(m)
		"road_sign":
			_road_sign(m)
		"bench":
			_bench(m)
		"house_small":
			_house(m, 0, "plaster", "roofred", false)
		"house_small_brick":
			_house(m, 0, "brick", "slate", false)
		"house_large":
			_house(m, 0, "plasterw", "slate", true)
		"house_ruin":
			_house(m, 1, "plaster", "roofred", false)
		"house_burnt":
			_house(m, 2, "plaster", "roofred", false)
		"shop":
			_shop(m, 0)
		"shop_ruin":
			_shop(m, 1)
		"apartment":
			_apartment(m, 0)
		"apartment_ruin":
			_apartment(m, 1)
		"apartment_burnt":
			_apartment(m, 2)
		"warehouse":
			_warehouse(m, 0)
		"warehouse_ruin":
			_warehouse(m, 1)
		"wall_ruin":
			_wall_ruin(m)
		"rubble_heap":
			_rubble_heap(m, false)
		"rubble_field":
			_rubble_heap(m, true)
		"hq_bunker":
			_hq(m, frame)
		"concrete_wall":
			_wall_x(m, "concrete")
		"chain_fence":
			_wall_x(m, "fence")
		"sandbag_line":
			_wall_x(m, "sandbags")
		"gate_post":
			_gate_post(m)
		"boom_gate":
			_boom_gate(m)
		"watchtower":
			_watchtower(m)
		"floodlight":
			_floodlight(m)
		"tent":
			_tent(m)
		"generator":
			_generator(m)
		"fuel_tank":
			_fuel_tank(m)
		"container_red":
			_container(m, "cont_red")
		"container_blue":
			_container(m, "cont_blue")
		"container_green":
			_container(m, "cont_green")
		"radar_mast":
			_radar_mast(m)
		"flag_pole":
			_flag_pole(m)
		"helipad":
			_helipad(m)
		"barracks":
			_barracks(m, 0)
		"barracks_ruin":
			_barracks(m, 1)
		_:
			for pk in _packs:
				if pk.build(self, m, unit, frame):
					break
	if _k != 1.0:
		_scale(m, _k)


const CHAR := {
	"hull": "hullc", "track": "trackc", "gun": "gunc", "glass": "gunc", "base": "basec", "ammo": "gunc",
	"heli": "helic", "rotor": "gunc", "sand": "sandc", "dirt": "dirtc",
	"wood": "woodc", "woodd": "woodc", "concrete": "concretec", "drum": "drumc", "canvas": "canvasc", "rust": "rustc",
	"steel": "steelc", "plaster": "plasterc", "plasterw": "plasterc", "brick": "basec", "corrugated": "steelc",
	"tento": "hullc", "concretel": "concretec", "dump": "basec", "dumpd": "basec", "roofred": "basec", "slate": "gunc",
	"tankg": "steelc", "cont_red": "hullc", "cont_blue": "hullc", "cont_green": "hullc", "leaf": "dirtc",
	"leafd": "dirtc", "leafl": "dirtc", "rubble": "basec", "whitep": "basec",
}


## Swaps parts to their burnt-out materials.
static func _scorch(list: Array[Prim]) -> void:
	for p in list:
		p.mat = CHAR.get(p.mat, p.mat)


## Rotates/moves a group of parts about `pivot`: p' = pivot + g * (p - pivot) + shift.
static func _xform_about(list: Array[Prim], pivot: Vector3, g: Basis, shift: Vector3) -> void:
	for p in list:
		p.c = pivot + g * (p.c - pivot) + shift
		p.basis = g * p.basis


## Swaps materials by name (variants reuse a rig with different clothes).
static func _remap(list: Array[Prim], table: Dictionary) -> void:
	for p in list:
		p.mat = table.get(p.mat, p.mat)


## Uniformly scales a finished model about the ground origin (feet stay on the ground).
static func _scale(list: Array[Prim], k: float) -> void:
	for p in list:
		p.c *= k
		p.h *= k


static func _blob(list: Array[Prim], c: Vector3, r: float, mat: String) -> void:
	list.append(Prim.new(SPH, c, Vector3(r, r, r), mat))


## Deterministic pseudo-random in [0, 1).
static func _rnd(i: int, k: int) -> float:
	return fposmod(sin(float(i) * 12.9898 + float(k) * 78.233) * 43758.5453, 1.0)


func _tank(m: Array[Prim], frame: int) -> void:
	var d := frame - 4 if frame >= 5 else 0  # frames 0 idle, 1-4 track scroll, 5-8 death
	if frame >= 1 and frame <= 4:
		_track_phase = frame * 0.5
	var hull: Array[Prim] = []
	var turret: Array[Prim] = []
	hull.append(Prim.new(BOX, Vector3(0, 0.34, 0.09), Vector3(0.46, 0.09, 0.09), "track", 0.0, 0.11))
	hull.append(Prim.new(BOX, Vector3(0, -0.34, 0.09), Vector3(0.46, 0.09, 0.09), "track", 0.0, 0.11))
	hull.append(Prim.new(BOX, Vector3(0, 0, 0.19), Vector3(0.40, 0.27, 0.09), "hull"))
	turret.append(Prim.new(CYL, Vector3(-0.02, 0, 0.34), Vector3(0.22, 0, 0.07), "hull"))
	turret.append(Prim.new(BOX, Vector3(-0.20, 0, 0.34), Vector3(0.10, 0.17, 0.06), "hull"))
	turret.append(Prim.new(BOX, Vector3(0.36, 0, 0.35), Vector3(0.38, 0.035, 0.035), "gun"))
	turret.append(Prim.new(BOX, Vector3(0.76, 0, 0.35), Vector3(0.05, 0.05, 0.05), "gun"))
	turret.append(Prim.new(CYL, Vector3(-0.10, 0.08, 0.43), Vector3(0.06, 0, 0.025), "gun"))
	if _variant == "ifv":  # infantry fighting vehicle: boxier, taller hull, small turret with an autocannon and a missile pod
		hull.clear()
		turret.clear()
		hull.append(Prim.new(BOX, Vector3(0, 0.33, 0.09), Vector3(0.42, 0.08, 0.09), "track", 0.0, 0.11))
		hull.append(Prim.new(BOX, Vector3(0, -0.33, 0.09), Vector3(0.42, 0.08, 0.09), "track", 0.0, 0.11))
		hull.append(Prim.new(BOX, Vector3(-0.02, 0, 0.22), Vector3(0.42, 0.25, 0.1), "hull"))
		hull.append(Prim.new(BOX, Vector3(0.36, 0, 0.2), Vector3(0.1, 0.25, 0.07), "hull"))  # sloped nose
		hull.append(Prim.new(BOX, Vector3(-0.45, 0, 0.22), Vector3(0.02, 0.19, 0.09), "steel"))  # rear ramp
		turret.append(Prim.new(BOX, Vector3(0.02, 0, 0.38), Vector3(0.17, 0.14, 0.06), "hull"))
		turret.append(Prim.new(BOX, Vector3(0.3, 0, 0.39), Vector3(0.2, 0.022, 0.022), "gun"))  # autocannon
		turret.append(Prim.new(BOX, Vector3(0.51, 0, 0.39), Vector3(0.035, 0.035, 0.035), "gun"))
		turret.append(Prim.new(BOX, Vector3(-0.03, 0.15, 0.43), Vector3(0.08, 0.035, 0.04), "gun"))  # missile pod
		turret.append(Prim.new(CYL, Vector3(-0.1, -0.06, 0.45), Vector3(0.05, 0, 0.02), "gun"))  # hatch
	var pivot := Vector3(-0.02, 0, 0.34)
	var fx: Array[Prim] = []
	match d:
		1:  # ammunition goes up: the whole tank is inside a fireball
			_blob(fx, Vector3(0.0, 0, 0.36), 0.34, "flash")
			_blob(fx, Vector3(0.18, 0.1, 0.3), 0.2, "fire")
		2:  # turret blown upwards, tilting
			_scorch(hull)
			_xform_about(turret, pivot, Basis(Vector3(1, 0, 0), 0.3) * _ry(0.25), Vector3(0, 0, 0.26))
			_scorch(turret)
			_blob(fx, Vector3(0.0, 0, 0.32), 0.2, "fire")
			_blob(fx, Vector3(-0.2, 0.12, 0.3), 0.13, "flash")
		3:  # turret toppling off the hull
			_scorch(hull)
			_xform_about(turret, pivot, Basis(Vector3(1, 0, 0), 0.75) * _ry(0.3), Vector3(-0.04, 0.2, 0.18))
			_scorch(turret)
			_blob(fx, Vector3(0.0, 0, 0.3), 0.17, "fire")
			_blob(fx, Vector3(0.0, -0.05, 0.5), 0.1, "smoke")
		4:  # wreck: turret lying on its side next to the hull, small fire, smoke
			_scorch(hull)
			_xform_about(turret, pivot, Basis(Vector3(1, 0, 0), 1.35) * _ry(0.35), Vector3(-0.08, 0.34, -0.06))
			_scorch(turret)
			_blob(fx, Vector3(0.05, -0.02, 0.3), 0.09, "fire")
			_blob(fx, Vector3(0.05, -0.02, 0.5), 0.09, "smoke")
			_blob(fx, Vector3(0.1, 0.0, 0.66), 0.07, "smoke")
	m.append_array(hull)
	m.append_array(turret)
	m.append_array(fx)


func _gatling(m: Array[Prim], frame: int) -> void:
	var d := frame  # 0 idle, 1-4 death
	var base: Array[Prim] = []
	var gun: Array[Prim] = []
	base.append(Prim.new(CYL, Vector3(0, 0, 0.04), Vector3(0.34, 0, 0.04), "base"))
	base.append(Prim.new(CYL, Vector3(0, 0, 0.15), Vector3(0.07, 0, 0.07), "gun"))
	gun.append(Prim.new(BOX, Vector3(0.02, 0, 0.30), Vector3(0.18, 0.10, 0.08), "gun"))
	gun.append(Prim.new(BOX, Vector3(0.40, 0, 0.33), Vector3(0.26, 0.025, 0.025), "gun"))
	gun.append(Prim.new(BOX, Vector3(0.40, 0.05, 0.27), Vector3(0.26, 0.025, 0.025), "gun"))
	gun.append(Prim.new(BOX, Vector3(0.40, -0.05, 0.27), Vector3(0.26, 0.025, 0.025), "gun"))
	gun.append(Prim.new(BOX, Vector3(0.56, 0, 0.30), Vector3(0.025, 0.08, 0.07), "gun"))
	gun.append(Prim.new(CYL, Vector3(-0.02, 0.17, 0.28), Vector3(0.08, 0, 0.07), "ammo"))
	var pivot := Vector3(0.1, 0, 0.3)
	var fx: Array[Prim] = []
	match d:
		1:
			_blob(fx, Vector3(0.05, 0, 0.3), 0.3, "flash")
		2:
			_scorch(base)
			_xform_about(gun, pivot, Basis(Vector3(1, 0, 0), 0.5) * _ry(0.4), Vector3(0, 0.02, 0.26))
			_scorch(gun)
			_blob(fx, Vector3(0.05, 0, 0.3), 0.18, "fire")
		3:
			_scorch(base)
			_xform_about(gun, pivot, Basis(Vector3(1, 0, 0), 1.1) * _ry(0.3), Vector3(0.0, 0.22, -0.02))
			_scorch(gun)
			_blob(fx, Vector3(0.0, 0, 0.25), 0.12, "fire")
			_blob(fx, Vector3(0.0, 0, 0.42), 0.09, "smoke")
		4:
			_scorch(base)
			_xform_about(gun, pivot, Basis(Vector3(1, 0, 0), 1.5) * _ry(0.1), Vector3(0.0, 0.3, -0.2))
			_scorch(gun)
			_blob(fx, Vector3(0.0, 0, 0.2), 0.07, "fire")
			_blob(fx, Vector3(0.0, 0, 0.36), 0.08, "smoke")
	m.append_array(base)
	m.append_array(gun)
	m.append_array(fx)


func _nest(m: Array[Prim], frame: int) -> void:
	var d := frame  # 0 idle, 1-4 death
	var ring: Array[Prim] = []
	var gun: Array[Prim] = []
	var ground: Array[Prim] = []
	ground.append(Prim.new(CYL, Vector3(0, 0, 0.01), Vector3(0.36, 0, 0.01), "dirt"))
	var n := 12
	var seeds: Array[int] = []
	for layer in 2:
		for i in n:
			var a := TAU * (float(i) + 0.5 * layer) / n
			var pos := Vector3(cos(a) * 0.40, sin(a) * 0.40, 0.04 + 0.085 * layer)
			var bag := Prim.new(BOX, pos, Vector3(0.085, 0.05, 0.045), "sand", a + PI * 0.5)
			ring.append(bag)
			seeds.append(layer * n + i)
	gun.append(Prim.new(BOX, Vector3(0.0, 0, 0.30), Vector3(0.12, 0.045, 0.05), "gun"))
	gun.append(Prim.new(BOX, Vector3(0.32, 0, 0.30), Vector3(0.20, 0.02, 0.02), "gun"))
	gun.append(Prim.new(BOX, Vector3(0.17, 0, 0.31), Vector3(0.012, 0.1, 0.07), "gun"))  # shield
	gun.append(Prim.new(BOX, Vector3(-0.02, 0.13, 0.2), Vector3(0.07, 0.04, 0.045), "ammo"))
	_bone(gun, Vector3(0, 0, 0.26), Vector3(0.12, 0.12, 0.05), 0.014, 0.014, "gun")
	_bone(gun, Vector3(0, 0, 0.26), Vector3(0.12, -0.12, 0.05), 0.014, 0.014, "gun")
	_bone(gun, Vector3(0, 0, 0.26), Vector3(-0.12, 0, 0.05), 0.014, 0.014, "gun")
	var pivot := Vector3(0.0, 0, 0.3)
	var fx: Array[Prim] = []
	if d >= 1:
		var out: float = [0.0, 0.10, 0.15, 0.17][d - 1]
		var up: float = [0.0, 0.12, 0.03, 0.0][d - 1]
		for k in ring.size():
			var bag := ring[k]
			var dir := Vector3(bag.c.x, bag.c.y, 0).normalized()
			var jitter := _rnd(k, d)
			bag.c += dir * out * (0.6 + jitter) + Vector3(0, 0, up * (0.5 + jitter))
			if d >= 2:
				bag.basis = Basis(Vector3(1, 0, 0), (jitter - 0.5) * 0.9) * bag.basis
			if d == 4 and _rnd(k, 9) < 0.28:  # blown clean away: a bag lying further out on the ground
				bag.c = Vector3(dir.x * (0.62 + 0.15 * jitter), dir.y * (0.62 + 0.15 * jitter), 0.04)
	match d:
		1:
			_xform_about(gun, pivot, Basis.IDENTITY, Vector3(0, 0, 0.1))
			_blob(fx, Vector3(0, 0, 0.3), 0.3, "flash")
		2:
			_scorch(ground)
			_xform_about(gun, pivot, Basis(Vector3(1, 0, 0), 0.9) * _ry(0.5), Vector3(0, 0, 0.36))
			_scorch(gun)
			_blob(fx, Vector3(0, 0, 0.26), 0.2, "fire")
		3:
			_scorch(ground)
			_xform_about(gun, pivot, Basis(Vector3(1, 0, 0), 1.3) * _ry(0.3), Vector3(0.1, 0.18, -0.14))
			_scorch(gun)
			_blob(fx, Vector3(0, 0, 0.18), 0.13, "fire")
			_blob(fx, Vector3(0, 0, 0.36), 0.09, "smoke")
		4:
			_scorch(ground)
			_scorch(ring)
			_xform_about(gun, pivot, Basis(Vector3(1, 0, 0), 1.5) * _ry(0.15), Vector3(0.1, 0.2, -0.22))
			_scorch(gun)
			_blob(fx, Vector3(0, 0, 0.12), 0.07, "fire")
			_blob(fx, Vector3(0, 0, 0.28), 0.08, "smoke")
	m.append_array(ground)
	m.append_array(ring)
	m.append_array(gun)
	m.append_array(fx)


func _heli(m: Array[Prim], frame: int) -> void:
	var d := frame - 3 if frame >= 4 else 0  # frames 0-3 rotor spin, 4-7 death
	var spin := (frame if d == 0 else d) * 22.5 * PI / 180.0
	var body: Array[Prim] = []
	var tail: Array[Prim] = []
	var rotor: Array[Prim] = []
	body.append(Prim.new(BOX, Vector3(0, 0, 0.28), Vector3(0.34, 0.14, 0.12), "heli"))
	body.append(Prim.new(BOX, Vector3(0.34, 0, 0.26), Vector3(0.12, 0.12, 0.09), "heli"))
	body.append(Prim.new(BOX, Vector3(0.30, 0, 0.35), Vector3(0.14, 0.11, 0.06), "glass"))
	body.append(Prim.new(BOX, Vector3(0, 0.16, 0.04), Vector3(0.30, 0.02, 0.02), "gun"))
	body.append(Prim.new(BOX, Vector3(0, -0.16, 0.04), Vector3(0.30, 0.02, 0.02), "gun"))
	body.append(Prim.new(BOX, Vector3(0.12, 0.15, 0.10), Vector3(0.02, 0.02, 0.06), "gun"))
	body.append(Prim.new(BOX, Vector3(-0.12, 0.15, 0.10), Vector3(0.02, 0.02, 0.06), "gun"))
	body.append(Prim.new(BOX, Vector3(0.12, -0.15, 0.10), Vector3(0.02, 0.02, 0.06), "gun"))
	body.append(Prim.new(BOX, Vector3(-0.12, -0.15, 0.10), Vector3(0.02, 0.02, 0.06), "gun"))
	body.append(Prim.new(CYL, Vector3(0, 0, 0.46), Vector3(0.04, 0, 0.06), "gun"))
	tail.append(Prim.new(BOX, Vector3(-0.62, 0, 0.34), Vector3(0.40, 0.04, 0.04), "heli"))
	tail.append(Prim.new(BOX, Vector3(-0.98, 0, 0.42), Vector3(0.04, 0.02, 0.12), "heli"))
	tail.append(Prim.new(BOX, Vector3(-0.98, 0.03, 0.46), Vector3(0.02, 0.01, 0.10), "rotor"))
	rotor.append(Prim.new(BOX, Vector3(0, 0, 0.53), Vector3(0.62, 0.045, 0.012), "rotor", spin))
	rotor.append(Prim.new(BOX, Vector3(0, 0, 0.53), Vector3(0.62, 0.045, 0.012), "rotor", spin + PI * 0.5))
	var c := Vector3(0, 0, 0.28)
	var fx: Array[Prim] = []
	match d:
		1:  # hit: engine on fire, trailing smoke, starting to roll
			var g := Basis(Vector3(1, 0, 0), 0.35) * _ry(0.12)
			_xform_about(body, c, g, Vector3.ZERO)
			_xform_about(tail, c, g, Vector3.ZERO)
			_xform_about(rotor, c, g, Vector3.ZERO)
			_blob(fx, Vector3(-0.08, 0, 0.46), 0.15, "fire")
			_blob(fx, Vector3(-0.4, 0, 0.5), 0.1, "smoke")
		2:  # spinning in, nose down
			var g := Basis(Vector3(1, 0, 0), 0.85) * _ry(0.4)
			_xform_about(body, c, g, Vector3.ZERO)
			_xform_about(tail, c, g, Vector3.ZERO)
			_xform_about(rotor, c, g, Vector3.ZERO)
			_scorch(body)
			_blob(fx, Vector3(-0.05, 0, 0.4), 0.2, "fire")
			_blob(fx, Vector3(-0.45, 0, 0.55), 0.12, "smoke")
		3:  # impact: fireball over a broken airframe
			var g := Basis(Vector3(1, 0, 0), 1.35) * _ry(0.15)
			_xform_about(body, c, g, Vector3(0.04, 0, -0.14))
			_xform_about(tail, c, Basis(Vector3(0, 0, 1), 0.5), Vector3(-0.1, 0.1, -0.26))
			_xform_about(rotor, c, g, Vector3(0.04, 0, -0.1))
			_scorch(body)
			_scorch(tail)
			_blob(fx, Vector3(0.0, 0, 0.2), 0.34, "flash")
			_blob(fx, Vector3(-0.15, 0.1, 0.12), 0.2, "fire")
		4:  # wreck: on its side, tail snapped off, rotor stubs, smoke
			var g := Basis(Vector3(1, 0, 0), 1.4) * _ry(0.15)
			_xform_about(body, c, g, Vector3(0.04, 0, -0.14))
			_xform_about(tail, c, Basis(Vector3(0, 0, 1), 0.55), Vector3(-0.12, 0.14, -0.28))
			for p in rotor:
				p.h.x = 0.2
			_xform_about(rotor, c, g, Vector3(0.04, 0.0, -0.1))
			_scorch(body)
			_scorch(tail)
			_blob(fx, Vector3(0.0, 0, 0.14), 0.09, "fire")
			_blob(fx, Vector3(0.0, 0, 0.3), 0.09, "smoke")
			_blob(fx, Vector3(0.04, 0, 0.46), 0.08, "smoke")
	m.append_array(body)
	m.append_array(tail)
	m.append_array(rotor)
	m.append_array(fx)


## Prim whose local x axis runs p0 -> p1 (a limb or gun segment). hy/hz are its half thicknesses.
static func _bone(list: Array[Prim], p0: Vector3, p1: Vector3, hy: float, hz: float, mat: String) -> void:
	var v := p1 - p0
	var length := v.length()
	if length < 1e-5:
		return
	var x := v / length
	var up := Vector3(0, 0, 1) if absf(x.z) < 0.95 else Vector3(0, 1, 0)
	var y := up.cross(x).normalized()
	var z := x.cross(y)
	var pr := Prim.new(BOX, (p0 + p1) * 0.5, Vector3(length * 0.5, hy, hz), mat)
	pr.basis = Basis(x, y, z)
	list.append(pr)


## Two-bone IK: returns [mid joint, end point]. `pole` picks which way the middle joint bends.
static func _ik2(root: Vector3, target: Vector3, a: float, b: float, pole: Vector3) -> Array:
	var to := target - root
	var dist := minf(maxf(to.length(), 0.001), (a + b) * 0.999)
	var dir := to.normalized()
	var t := (a * a - b * b + dist * dist) / (2.0 * dist)
	var h := sqrt(maxf(a * a - t * t, 0.0))
	var pp := pole - dir * pole.dot(dir)
	if pp.length() < 1e-4:
		pp = Vector3(0, 0, 1).cross(dir)
	return [root + dir * t + pp.normalized() * h, root + dir * dist]


## Rigidly moves already-built parts: p' = g * p + shift (used for falling bodies).
static func _xform(list: Array[Prim], g: Basis, shift: Vector3) -> void:
	for p in list:
		p.c = g * p.c + shift
		p.basis = g * p.basis


## Walk numbers: foot x offsets and lifts per leg, plus body bob. Frame 0 / other = standing.
func _gait(frame: int, stride_r: float, stride_l: float, lift_h: float) -> Dictionary:
	if frame < 1 or frame > 4:
		return {"fr": 0.07, "fl": -0.05, "lr": 0.0, "ll": 0.0, "bob": 0.0}
	var p := TAU * float(frame - 1) / 4.0
	return {
		"fr": stride_r * cos(p), "fl": -stride_l * cos(p),
		"lr": lift_h * maxf(0.0, -sin(p)), "ll": lift_h * maxf(0.0, sin(p)),
		"bob": 0.012 * absf(sin(p)) - 0.008,
	}


## Both legs with knees, hips at `hz`. Foot targets come from `g`.
func _legs(body: Array[Prim], g: Dictionary, hz: float, pants: String, foot_mat: String, boot_len: float) -> void:
	for side in [1, -1]:
		var fx: float = g["fl"] if side == 1 else g["fr"]
		var lift: float = g["ll"] if side == 1 else g["lr"]
		var hj := Vector3(0, 0.06 * side, hz)
		var ankle := Vector3(fx, 0.07 * side, 0.065 + lift)
		var ik := _ik2(hj, ankle, 0.19, 0.19, Vector3(1, 0, 0.15))
		_bone(body, hj, ik[0], 0.047, 0.047, pants)
		_bone(body, ik[0], ik[1], 0.04, 0.04, pants)
		body.append(Prim.new(BOX, ik[1] + Vector3(boot_len * 0.3, 0, -0.03), Vector3(boot_len, 0.045, 0.04), foot_mat))


## The rifle as segments from the butt `b` along unit direction `u` (0.63 long): stock, receiver with
## magazine and top rail, handguard, barrel. Returns hand points {"grip": under the receiver, "fore": handguard}.
func _rifle(list: Array[Prim], b: Vector3, u: Vector3) -> Dictionary:
	var up := Vector3(0, 0, 1)
	_bone(list, b, b + u * 0.13, 0.018, 0.040, "stock")
	_bone(list, b + u * 0.13, b + u * 0.31, 0.022, 0.034, "gun")
	_bone(list, b + u * 0.17 - up * 0.03, b + u * 0.19 - up * 0.095, 0.014, 0.018, "gun")  # magazine
	_bone(list, b + u * 0.15 + up * 0.034, b + u * 0.30 + up * 0.034, 0.010, 0.010, "gun")  # top rail
	_bone(list, b + u * 0.31, b + u * 0.45, 0.025, 0.028, "stock")
	_bone(list, b + u * 0.45, b + u * 0.60, 0.012, 0.012, "gun")
	_bone(list, b + u * 0.60, b + u * 0.63, 0.016, 0.016, "gun")
	return {"grip": b + u * 0.20 - up * 0.045, "fore": b + u * 0.40 - up * 0.04}


func _gun(list: Array[Prim], b: Vector3, u: Vector3) -> Dictionary:
	match _kit:
		"rpg":
			return _launcher(list, b, u)
		"sniper":
			return _sniper(list, b, u)
		"mortar":
			return _mortar(list, b, u)
	return _rifle(list, b, u)


## Long scoped rifle with a bipod (~0.9 long).
func _sniper(list: Array[Prim], b: Vector3, u: Vector3) -> Dictionary:
	var up := Vector3(0, 0, 1)
	_bone(list, b, b + u * 0.16, 0.02, 0.045, "stock")
	_bone(list, b + u * 0.16, b + u * 0.38, 0.022, 0.034, "gun")
	_bone(list, b + u * 0.38, b + u * 0.82, 0.014, 0.014, "gun")
	_bone(list, b + u * 0.82, b + u * 0.88, 0.02, 0.02, "gun")  # muzzle brake
	_bone(list, b + u * 0.22 + up * 0.05, b + u * 0.44 + up * 0.05, 0.024, 0.024, "gun")  # scope
	_bone(list, b + u * 0.5, b + u * 0.46 - up * 0.13, 0.01, 0.01, "gun")  # bipod
	return {"grip": b + u * 0.2 - up * 0.05, "fore": b + u * 0.45 - up * 0.03}


## Mortar tube with a base plate and a bipod (~0.55 long, thick).
func _mortar(list: Array[Prim], b: Vector3, u: Vector3) -> Dictionary:
	var up := Vector3(0, 0, 1)
	list.append(Prim.new(BOX, b - u * 0.05, Vector3(0.06, 0.09, 0.016), "steel"))  # base plate
	_bone(list, b, b + u * 0.5, 0.046, 0.046, "tube")
	_bone(list, b + u * 0.5, b + u * 0.56, 0.056, 0.056, "gun")  # muzzle ring
	_bone(list, b + u * 0.34, b + u * 0.3 - up * 0.2 + Vector3(0, 0.08, 0), 0.012, 0.012, "gun")  # bipod
	_bone(list, b + u * 0.34, b + u * 0.3 - up * 0.2 - Vector3(0, 0.08, 0), 0.012, 0.012, "gun")
	return {"grip": b + u * 0.2 - up * 0.03, "fore": b + u * 0.4 - up * 0.02}


## Shoulder-fired rocket launcher: flared rear, tube, sight, pistol grip, bulbous warhead (~0.9 long).
func _launcher(list: Array[Prim], b: Vector3, u: Vector3) -> Dictionary:
	var up := Vector3(0, 0, 1)
	_bone(list, b - u * 0.10, b + u * 0.02, 0.05, 0.05, "tube")  # blast flare
	_bone(list, b + u * 0.02, b + u * 0.56, 0.036, 0.036, "tube")
	_bone(list, b + u * 0.18, b + u * 0.30, 0.012, 0.012, "gun")  # sight rail
	list.append(Prim.new(SPH, b + u * 0.26 + up * 0.05, Vector3(0.02, 0.016, 0.02), "gun"))
	_bone(list, b + u * 0.22 - up * 0.02, b + u * 0.23 - up * 0.10, 0.014, 0.014, "gun")  # grip
	_bone(list, b + u * 0.56, b + u * 0.66, 0.056, 0.056, "warhead")
	_bone(list, b + u * 0.66, b + u * 0.78, 0.03, 0.03, "warhead")
	_bone(list, b + u * 0.78, b + u * 0.82, 0.012, 0.012, "gun")  # fuse tip
	return {"grip": b + u * 0.23 - up * 0.10, "fore": b + u * 0.45 - up * 0.04}


func _arm(list: Array[Prim], shoulder: Vector3, hand: Vector3, side: int, sleeve: String, skin: String) -> void:
	var ik := _ik2(shoulder, hand, 0.15, 0.15, Vector3(-0.2, side * 0.7, -1.0))
	_bone(list, shoulder, ik[0], 0.036, 0.036, sleeve)
	_bone(list, ik[0], ik[1], 0.032, 0.032, sleeve)
	list.append(Prim.new(BOX, ik[1], Vector3(0.032, 0.03, 0.03), skin))


func _soldier(m: Array[Prim], frame: int) -> void:
	var d := frame - 4 if frame >= 5 and frame <= 8 else 0  # death step 1-4 (frame 9 = firing recoil)
	var fire := frame == 9
	var g := _gait(frame, 0.16, 0.16, 0.05)
	if d > 0:
		g = {"fr": 0.10, "fl": -0.08, "lr": 0.0, "ll": 0.0, "bob": 0.0}
	var hz := 0.385 + float(g["bob"])
	var hip := Vector3(-0.025 if fire else 0.0, 0, hz)
	var lean := 0.03 if fire else 0.10  # recoil pushes the shooter upright
	var tb := _ry(lean)
	var body: Array[Prim] = []
	_legs(body, g, hz, "uni", "boot", 0.07)
	# Torso: uniform, vest with pouches, belt, pack.
	body.append(Prim.new(BOX, hip + tb * Vector3(0, 0, 0.14), Vector3(0.07, 0.105, 0.135), "uni", 0.0, 0.0, lean))
	body.append(Prim.new(BOX, hip + tb * Vector3(0.03, 0, 0.15), Vector3(0.05, 0.108, 0.105), "vest", 0.0, 0.0, lean))
	body.append(Prim.new(BOX, hip + tb * Vector3(0.062, 0.05, 0.12), Vector3(0.016, 0.028, 0.03), "belt", 0.0, 0.0, lean))
	body.append(Prim.new(BOX, hip + tb * Vector3(0.062, -0.05, 0.12), Vector3(0.016, 0.028, 0.03), "belt", 0.0, 0.0, lean))
	body.append(Prim.new(BOX, hip + tb * Vector3(0, 0, 0.01), Vector3(0.075, 0.108, 0.022), "belt", 0.0, 0.0, lean))
	body.append(Prim.new(BOX, hip + tb * Vector3(-0.10, 0, 0.15), Vector3(0.055, 0.08, 0.10), "pack", 0.0, 0.0, lean))
	# Neck and head with a proper face: eyes, nose, mouth, ears, chin strap; helmet with a band and brim.
	body.append(Prim.new(CYL, hip + tb * Vector3(0.015, 0, 0.29), Vector3(0.036, 0, 0.03), "skin"))
	var head := hip + tb * Vector3(0.04, 0, 0.36)
	body.append(Prim.new(SPH, head, Vector3(0.078, 0.07, 0.082), "skin"))
	for side in [1, -1]:
		body.append(Prim.new(BOX, head + Vector3(0.071, 0.029 * side, 0.0), Vector3(0.016, 0.016, 0.016), "eye"))
		body.append(Prim.new(BOX, head + Vector3(0, 0.074 * side, -0.01), Vector3(0.012, 0.01, 0.02), "skin"))  # ears
	body.append(Prim.new(BOX, head + Vector3(0.082, 0, -0.016), Vector3(0.014, 0.012, 0.022), "skin"))  # nose
	body.append(Prim.new(BOX, head + Vector3(0.072, 0, -0.045), Vector3(0.01, 0.026, 0.007), "lip"))  # mouth
	body.append(Prim.new(BOX, head + Vector3(0.058, 0, -0.068), Vector3(0.012, 0.05, 0.007), "belt"))  # chin strap
	body.append(Prim.new(SPH, head + Vector3(-0.005, 0, 0.05), Vector3(0.098, 0.09, 0.065), "helm"))
	body.append(Prim.new(CYL, head + Vector3(0.012, 0, 0.012), Vector3(0.108, 0, 0.01), "helm"))  # brim
	body.append(Prim.new(CYL, head + Vector3(-0.005, 0, 0.046), Vector3(0.101, 0, 0.011), "belt"))  # band
	# Rifle shouldered, both hands on it; muzzle a little low and toward the centre line.
	var butt := hip + tb * Vector3(-0.045 if fire else -0.015, -0.098, 0.265)
	var u := (tb * Vector3(1.0, 0.13, 0.09 if fire else -0.07)).normalized()  # muzzle climbs on the shot
	var sh_r := hip + tb * Vector3(0, -0.145, 0.25)
	var sh_l := hip + tb * Vector3(0, 0.145, 0.25)
	if d == 0:
		var pts := _gun(body, butt, u)
		_arm(body, sh_r, pts["grip"], -1, "uni", "skin")
		_arm(body, sh_l, pts["fore"], 1, "uni", "skin")
	else:
		var out := 0.28 if d == 1 else 0.2  # arms thrown out, then limp
		var drop := 0.12 if d == 1 else -0.2
		_arm(body, sh_r, sh_r + Vector3(-0.03, -out, drop), -1, "uni", "skin")
		_arm(body, sh_l, sh_l + Vector3(-0.03, out, drop), 1, "uni", "skin")
	var extra: Array[Prim] = []
	if d > 0:
		var phi: float = [0.4, 0.85, 1.3, PI * 0.5][d - 1]
		_xform(body, _ry(-phi), Vector3(0.4 * sin(phi), 0, 0.12 * sin(phi)))
		match d:
			1:
				_gun(extra, Vector3(0.22, -0.16, 0.5 if _kit == "rifle" else 0.36), Vector3(0.9, 0.2, 0.4 if _kit == "rifle" else 0.18).normalized())
			2:
				_gun(extra, Vector3(0.30, -0.2, 0.28), Vector3(1.0, 0.2, -0.5).normalized())
			_:
				_gun(extra, Vector3(0.12, -0.24, 0.04), Vector3(1.0, 0.12, 0.0).normalized())
	m.append_array(body)
	m.append_array(extra)


func _zombie(m: Array[Prim], frame: int) -> void:
	var d := frame - 5 if frame >= 6 else 0  # death step 1-4 (frame 5 = attack)
	var attack := frame == 5
	var g := _gait(frame, 0.13 * _z_stride, 0.07 * _z_stride, 0.04 * _z_stride)
	g["ll"] = minf(g["ll"], 0.012)  # the left foot drags
	if d > 0:
		g = {"fr": 0.09, "fl": -0.09, "lr": 0.0, "ll": 0.0, "bob": 0.0}
	var hz := 0.37 + float(g["bob"])
	var hip := Vector3(0.0, 0, hz)
	var lean := (0.42 if attack else 0.33) + _z_lean
	if attack:
		hip.x += 0.05
	var tb := _ry(lean)
	var body: Array[Prim] = []
	_legs(body, g, hz, "pants", "zskin", 0.06)
	# Hunched, torn torso.
	body.append(Prim.new(BOX, hip + tb * Vector3(0, 0, 0.14), Vector3(0.07, 0.105, 0.135), "shirt", 0.0, 0.0, lean))
	body.append(Prim.new(BOX, hip + tb * Vector3(0.04, 0.045, 0.12), Vector3(0.034, 0.04, 0.05), "shirtd", 0.0, 0.0, lean))
	body.append(Prim.new(BOX, hip + tb * Vector3(0.06, -0.05, 0.1), Vector3(0.018, 0.035, 0.04), "wound", 0.0, 0.0, lean))
	body.append(Prim.new(BOX, hip + tb * Vector3(0.0, 0.06, -0.035), Vector3(0.072, 0.03, 0.04), "shirtd", 0.0, 0.0, lean))  # ragged hem
	body.append(Prim.new(BOX, hip + tb * Vector3(0, 0, 0.01), Vector3(0.075, 0.108, 0.025), "pants", 0.0, 0.0, lean))
	# Head slung forward on a stretched neck.
	var head := hip + tb * Vector3(0.0, 0, 0.36) + Vector3(0.03, 0, 0.0)
	var neck_base := hip + tb * Vector3(0, 0, 0.27)
	_bone(body, neck_base, head + Vector3(-0.02, 0, -0.05), 0.04, 0.04, "zskin")
	body.append(Prim.new(SPH, head, Vector3(0.088, 0.08, 0.092), "zskin"))
	for side in [1, -1]:
		body.append(Prim.new(BOX, head + Vector3(0.078, 0.034 * side, 0.016), Vector3(0.02, 0.02, 0.02), "red"))
		body.append(Prim.new(BOX, head + Vector3(0, 0.082 * side, -0.01), Vector3(0.012, 0.01, 0.022), "zskin"))  # ears
		body.append(Prim.new(SPH, head + Vector3(-0.045, 0.03 * side, 0.07), Vector3(0.03, 0.03, 0.025), "hair"))  # tufts
	body.append(Prim.new(BOX, head + Vector3(0.07, 0, 0.048), Vector3(0.02, 0.07, 0.012), "zdark"))  # brow ridge
	var jaw := 0.026 if attack else 0.016
	body.append(Prim.new(BOX, head + Vector3(0.078, 0, -0.045), Vector3(0.014, 0.04, jaw), "mouth"))
	for side in [1, -1]:
		body.append(Prim.new(BOX, head + Vector3(0.084, 0.018 * side, -0.03 + 0.012 - jaw * 0.3), Vector3(0.008, 0.009, 0.011), "tooth"))
	# Arms reaching out, hands clawed; higher and further on the attack frame.
	var reach := 0.46 if attack else 0.40
	for side in [1, -1]:
		var sh := hip + tb * Vector3(0, 0.145 * side, 0.25)
		var dz := 0.12 + (0.2 if attack else 0.0) + (0.02 if side == 1 else -0.04)
		var sway: float = 0.02 * sin(TAU * float(frame - 1) / 4.0) * side if frame >= 1 and frame <= 4 else 0.0
		var hand := Vector3(hip.x + reach, 0.12 * side + sway, hz + dz)
		if d > 0:
			hand = sh + Vector3(0.0, 0.2 * side, -0.25)
			if d == 1:
				hand = sh + Vector3(0.28, 0.12 * side, 0.05)
		var ik := _ik2(sh, hand, 0.15, 0.15, Vector3(-0.2, side * 0.7, -1.0))
		_bone(body, sh, ik[0], 0.036, 0.036, "shirt")
		_bone(body, ik[0], ik[1], 0.031, 0.031, "zskin")
		for f in [-1, 0, 1]:
			body.append(Prim.new(BOX, ik[1] + Vector3(0.035, 0.016 * f, 0.0), Vector3(0.034, 0.008, 0.008), "zskin"))
	if _z_kind == "spitter":
		var chest := hip + tb * Vector3(0.07, 0, 0.27)
		body.append(Prim.new(SPH, chest, Vector3(0.1, 0.115, 0.1), "acid"))
		body.append(Prim.new(SPH, chest + tb * Vector3(0.07, 0.05, 0.03), Vector3(0.04, 0.04, 0.04), "acidh"))
		body.append(Prim.new(SPH, chest + tb * Vector3(0.05, -0.06, -0.04), Vector3(0.03, 0.03, 0.03), "acidh"))
		_bone(body, head + Vector3(0.06, 0, -0.06), chest + tb * Vector3(0.0, 0, 0.05), 0.032, 0.032, "acidd")  # swollen throat
		if attack:
			for k in 4:  # a stream of acid leaving the open mouth
				var r := 0.04 - 0.006 * float(k)
				body.append(Prim.new(SPH, head + Vector3(0.14 + 0.12 * float(k), 0.0, -0.04 - 0.02 * float(k)), Vector3(r, r, r), "acid"))
		else:
			body.append(Prim.new(BOX, head + Vector3(0.082, 0, -0.1), Vector3(0.008, 0.008, 0.03), "acid"))  # drool
	if d > 0:
		var phi: float = [0.4, 0.85, 1.3, PI * 0.5][d - 1]
		_xform(body, _ry(phi), Vector3(-0.4 * sin(phi), 0, 0.12 * sin(phi)))
	m.append_array(body)


func _howitzer(m: Array[Prim], frame: int) -> void:
	var d := frame - 1 if frame >= 2 else 0  # frames 0 idle, 1 firing, 2-5 destruction
	var fire := frame == 1
	var carriage: Array[Prim] = []
	var barrel: Array[Prim] = []
	var wheels: Array[Prim] = []
	var elev := 0.42
	var dirv := Vector3(cos(elev), 0, sin(elev))
	var breech := Vector3(-0.02, 0, 0.40)
	var back := -0.1 if fire else 0.0  # the barrel slides back in the cradle when it fires
	var rb := breech + dirv * back
	# Split trails with spades, planted on the ground behind the gun.
	for side in [1, -1]:
		_bone(carriage, Vector3(-0.02, 0.1 * side, 0.14), Vector3(-0.58, 0.28 * side, 0.04), 0.05, 0.045, "steel")
		carriage.append(Prim.new(BOX, Vector3(-0.6, 0.29 * side, 0.04), Vector3(0.08, 0.08, 0.04), "gun"))
	carriage.append(Prim.new(BOX, Vector3(0.0, 0, 0.22), Vector3(0.13, 0.27, 0.07), "hull"))  # axle block
	carriage.append(Prim.new(BOX, Vector3(0.14, 0, 0.38), Vector3(0.03, 0.3, 0.2), "steel"))  # gun shield
	carriage.append(Prim.new(BOX, Vector3(-0.02, 0, 0.34), Vector3(0.11, 0.09, 0.1), "hull"))  # cradle
	carriage.append(Prim.new(BOX, Vector3(-0.24, 0.18, 0.26), Vector3(0.06, 0.04, 0.06), "gun"))  # seat post
	for side in [1, -1]:
		wheels.append(Prim.new(SPH, Vector3(0.0, 0.33 * side, 0.17), Vector3(0.17, 0.05, 0.17), "track"))
		wheels.append(Prim.new(SPH, Vector3(0.0, 0.33 * side, 0.17), Vector3(0.07, 0.058, 0.07), "steel"))
	# Barrel with a bore sleeve, thick breech and a muzzle brake.
	_bone(barrel, rb - dirv * 0.14, rb + dirv * 0.05, 0.08, 0.08, "gun")
	_bone(barrel, rb + dirv * 0.05, rb + dirv * 0.45, 0.06, 0.06, "steel")
	_bone(barrel, rb + dirv * 0.45, rb + dirv * 0.72, 0.046, 0.046, "steel")
	_bone(barrel, rb + dirv * 0.72, rb + dirv * 0.82, 0.068, 0.068, "gun")
	barrel.append(Prim.new(BOX, Vector3(0.1, 0.22, 0.2), Vector3(0.07, 0.035, 0.035), "brass"))  # shell on the rack
	var fx: Array[Prim] = []
	if fire:
		var muzzle := rb + dirv * 0.86
		_blob(fx, muzzle, 0.13, "flash")
		_blob(fx, muzzle + dirv * 0.1, 0.06, "fire")
		_blob(fx, muzzle + Vector3(0, 0, 0.1), 0.06, "smoke")
	match d:
		1:
			_blob(fx, Vector3(0.0, 0, 0.4), 0.3, "flash")
		2:
			_scorch(carriage)
			_scorch(wheels)
			_xform_about(barrel, breech, Basis(Vector3(1, 0, 0), 0.5) * _ry(0.5), Vector3(0, 0.02, 0.26))
			_scorch(barrel)
			_blob(fx, Vector3(0.0, 0, 0.4), 0.18, "fire")
		3:
			_scorch(carriage)
			_scorch(wheels)
			_xform_about(barrel, breech, Basis(Vector3(1, 0, 0), 1.1) * _ry(0.9), Vector3(0.1, 0.24, -0.08))
			_scorch(barrel)
			_blob(fx, Vector3(0.0, 0, 0.32), 0.12, "fire")
			_blob(fx, Vector3(0.0, 0, 0.5), 0.09, "smoke")
		4:
			_scorch(carriage)
			_scorch(wheels)
			_xform_about(barrel, breech, Basis(Vector3(1, 0, 0), 1.5) * _ry(1.3), Vector3(0.18, 0.3, -0.22))
			_scorch(barrel)
			# one wheel knocked off and lying flat
			var n := wheels.size()
			wheels[n - 2].c = Vector3(0.12, -0.42, 0.03)
			wheels[n - 2].h = Vector3(0.115, 0.115, 0.03)
			wheels[n - 1].c = Vector3(0.12, -0.42, 0.05)
			wheels[n - 1].h = Vector3(0.05, 0.05, 0.036)
			_blob(fx, Vector3(0.0, 0, 0.28), 0.07, "fire")
			_blob(fx, Vector3(0.0, 0, 0.44), 0.08, "smoke")
	m.append_array(carriage)
	m.append_array(wheels)
	m.append_array(barrel)
	m.append_array(fx)


## Truck-mounted rocket launcher: a six-tube rack raised over the cab-forward chassis. Frames 0 idle, 1 firing, 2-5 destruction.
func _rocket_launcher(m: Array[Prim], frame: int) -> void:
	var d := frame - 1 if frame >= 2 else 0
	var fire := frame == 1
	var body: Array[Prim] = []
	var wheels: Array[Prim] = []
	var rack: Array[Prim] = []
	body.append(Prim.new(BOX, Vector3(-0.05, 0, 0.2), Vector3(0.55, 0.2, 0.06), "hull"))  # chassis
	body.append(Prim.new(BOX, Vector3(0.42, 0, 0.34), Vector3(0.13, 0.2, 0.13), "hull"))  # cab
	body.append(Prim.new(BOX, Vector3(0.555, 0, 0.38), Vector3(0.012, 0.16, 0.07), "glass"))
	body.append(Prim.new(BOX, Vector3(-0.58, 0, 0.14), Vector3(0.03, 0.18, 0.03), "steel"))  # stabiliser bar
	for ax in [0.38, -0.05, -0.42]:
		for side in [1, -1]:
			wheels.append(Prim.new(SPH, Vector3(ax, 0.22 * side, 0.13), Vector3(0.13, 0.05, 0.13), "track"))
			wheels.append(Prim.new(SPH, Vector3(ax, 0.235 * side, 0.13), Vector3(0.06, 0.04, 0.06), "steel"))
	var elev := 0.6
	var dirv := Vector3(cos(elev), 0, sin(elev))
	var base := Vector3(-0.26, 0, 0.3)
	rack.append(Prim.new(BOX, base, Vector3(0.2, 0.2, 0.04), "steel"))  # cradle
	var fx: Array[Prim] = []
	for row in 2:
		for col in 3:
			var p0 := base + Vector3(0, (col - 1) * 0.115, 0.07 + row * 0.11)
			_bone(rack, p0, p0 + dirv * 0.75, 0.042, 0.042, "tube")
			_bone(rack, p0 + dirv * 0.72, p0 + dirv * 0.77, 0.05, 0.05, "gun")  # muzzle collar
			if fire and row == 1:
				_blob(fx, p0 + dirv * 0.85, 0.07, "flash")
				_blob(fx, p0 + dirv * 0.97, 0.045, "fire")
				_blob(fx, p0 + dirv * 0.8 + Vector3(-0.1, 0, 0.02), 0.05, "smoke")
	var breech := base
	match d:
		1:
			_blob(fx, Vector3(0.0, 0, 0.4), 0.32, "flash")
		2:
			_scorch(body)
			_scorch(wheels)
			_xform_about(rack, breech, Basis(Vector3(1, 0, 0), 0.5) * _ry(0.5), Vector3(0, 0.02, 0.2))
			_scorch(rack)
			_blob(fx, Vector3(0.0, 0, 0.4), 0.18, "fire")
		3:
			_scorch(body)
			_scorch(wheels)
			_xform_about(rack, breech, Basis(Vector3(1, 0, 0), 1.1) * _ry(0.9), Vector3(0.1, 0.24, -0.08))
			_scorch(rack)
			_blob(fx, Vector3(0.0, 0, 0.32), 0.12, "fire")
			_blob(fx, Vector3(0.0, 0, 0.5), 0.09, "smoke")
		4:
			_scorch(body)
			_scorch(wheels)
			_xform_about(rack, breech, Basis(Vector3(1, 0, 0), 1.5) * _ry(1.3), Vector3(0.18, 0.3, -0.22))
			_scorch(rack)
			_blob(fx, Vector3(0.0, 0, 0.28), 0.07, "fire")
			_blob(fx, Vector3(0.0, 0, 0.44), 0.08, "smoke")
	m.append_array(body)
	m.append_array(wheels)
	m.append_array(rack)
	m.append_array(fx)


## Sandbag wall along local x (rotated at the end), three courses high. Frames 0 intact, 1-3 progressively blown apart.
func _sandbags(m: Array[Prim], frame: int) -> void:
	var d := frame
	var bags: Array[Prim] = []
	var ground: Array[Prim] = []
	var fx: Array[Prim] = []
	ground.append(Prim.new(CYL, Vector3(0, 0, 0.008), Vector3(0.5, 0, 0.008), "dirt"))
	var k := 0
	for layer in 3:
		var n := 4 if layer == 1 else 5
		for i in n:
			var y := (float(i) - float(n - 1) * 0.5) * 0.19
			var bag := Prim.new(BOX, Vector3(0, y, 0.045 + 0.085 * layer), Vector3(0.075, 0.088, 0.045), "sand", (_rnd(k, 1) - 0.5) * 0.12)
			var j := _rnd(k, d + 3)
			var gone := false
			match d:
				1:
					gone = layer == 2 and j < 0.45
				2:
					gone = layer == 2 or (layer == 1 and j < 0.5)
				3:
					gone = true
			if gone:
				bag.c = Vector3((_rnd(k, 7) - 0.5) * 0.7, y * 1.15, 0.045 if j < 0.7 else 0.13)
				if d == 1:
					bag.c = Vector3(0.18 + 0.2 * j, y, 0.045)
				bag.basis = Basis(Vector3(0, 0, 1), (_rnd(k, 5) - 0.5) * 2.4)
			bags.append(bag)
			k += 1
	match d:
		1:
			_blob(fx, Vector3(0.05, 0.1, 0.24), 0.2, "flash")
		2:
			_scorch(ground)
			_blob(fx, Vector3(0.0, -0.05, 0.2), 0.12, "fire")
		3:
			_scorch(ground)
			_scorch(bags)
			_blob(fx, Vector3(0.0, 0.0, 0.14), 0.08, "smoke")
	var all: Array[Prim] = []
	all.append_array(ground)
	all.append_array(bags)
	all.append_array(fx)
	_xform_about(all, Vector3.ZERO, Basis(Vector3(0, 0, 1), PI * 0.5), Vector3.ZERO)  # long side along local x, like the vehicles
	m.append_array(all)


## Jersey barrier made of three segments along local x (rotated at the end). Frames 0 intact, 1 cracked and leaning, 2 toppled, 3 rubble.
func _barrier(m: Array[Prim], frame: int) -> void:
	var d := frame
	var segs: Array[Array] = []
	for i in 3:
		var y := (float(i) - 1.0) * 0.31
		var seg: Array[Prim] = []
		seg.append(Prim.new(BOX, Vector3(0, y, 0.05), Vector3(0.12, 0.15, 0.05), "concrete"))
		seg.append(Prim.new(BOX, Vector3(0, y, 0.16), Vector3(0.085, 0.15, 0.055), "concrete"))
		seg.append(Prim.new(BOX, Vector3(0, y, 0.27), Vector3(0.055, 0.15, 0.055), "concrete"))
		seg.append(Prim.new(BOX, Vector3(0.062, y, 0.2), Vector3(0.012, 0.08, 0.018), "woodd"))  # painted marker
		segs.append(seg)
	var fx: Array[Prim] = []
	var rubble: Array[Prim] = []
	match d:
		1:
			_xform_about(segs[2], Vector3(0, 0.31, 0), Basis(Vector3(1, 0, 0), -0.28), Vector3(0.03, 0.02, 0))
			_blob(fx, Vector3(0.05, 0.3, 0.22), 0.16, "flash")
		2:
			_xform_about(segs[2], Vector3(0, 0.31, 0), Basis(Vector3(1, 0, 0), -1.25), Vector3(0.12, 0.12, 0.17))
			_xform_about(segs[1], Vector3(0, 0, 0), Basis(Vector3(1, 0, 0), 0.22), Vector3(0.0, 0, 0))
			_blob(fx, Vector3(0.0, 0.3, 0.1), 0.1, "fire")
		3:
			_xform_about(segs[2], Vector3(0, 0.31, 0), Basis(Vector3(1, 0, 0), -1.3), Vector3(0.14, 0.14, 0.17))
			_xform_about(segs[1], Vector3(0, 0, 0), Basis(Vector3(1, 0, 0), 1.2), Vector3(0.12, -0.04, 0.17))
			_xform_about(segs[0], Vector3(0, -0.31, 0), Basis(Vector3(1, 0, 0), 0.5), Vector3(-0.04, -0.03, 0.08))
			for q in 6:
				rubble.append(Prim.new(BOX, Vector3((_rnd(q, 2) - 0.5) * 0.5, (_rnd(q, 3) - 0.5) * 0.9, 0.025), Vector3(0.04 + 0.03 * _rnd(q, 4), 0.04 + 0.03 * _rnd(q, 5), 0.025), "concrete", _rnd(q, 6) * 3.0))
			_blob(fx, Vector3(0.0, 0.0, 0.16), 0.08, "smoke")
	for seg in segs:
		var typed: Array[Prim] = []
		typed.assign(seg)
		if d >= 2:
			_scorch(typed)
		m.append_array(typed)
	if d >= 2:
		_scorch(rubble)
	m.append_array(rubble)
	m.append_array(fx)
	_xform_about(m, Vector3.ZERO, Basis(Vector3(0, 0, 1), PI * 0.5), Vector3.ZERO)  # long side along local x, like the vehicles


static func _crate(list: Array[Prim], c: Vector3, s: float, yaw: float, tilt: float = 0.0) -> void:
	var g := Basis(Vector3(0, 0, 1), yaw) * Basis(Vector3(1, 0, 0), tilt)
	var parts: Array[Prim] = []
	parts.append(Prim.new(BOX, Vector3(0, 0, 0), Vector3(s, s, s * 0.9), "wood"))
	for z in [-0.55, 0.55]:
		parts.append(Prim.new(BOX, Vector3(0, 0, z * s), Vector3(s * 1.04, s * 1.04, s * 0.13), "woodd"))
	parts.append(Prim.new(BOX, Vector3(0, 0, s * 0.92), Vector3(s * 0.8, s * 0.12, s * 0.02), "woodd"))  # lid slat
	_xform_about(parts, Vector3.ZERO, g, c)
	list.append_array(parts)


## Three stacked wooden crates. Frames 0 intact, 1 top crate knocked off, 2 smashed and burning, 3 splinters.
func _crates(m: Array[Prim], frame: int) -> void:
	var d := frame
	var list: Array[Prim] = []
	var fx: Array[Prim] = []
	var ground: Array[Prim] = [Prim.new(CYL, Vector3(0, 0, 0.008), Vector3(0.4, 0, 0.008), "dirt")]
	match d:
		0:
			_crate(list, Vector3(-0.03, -0.14, 0.16), 0.17, 0.0)
			_crate(list, Vector3(-0.02, 0.17, 0.16), 0.17, 0.1)
			_crate(list, Vector3(-0.02, 0.0, 0.5), 0.15, 0.5)
		1:
			_crate(list, Vector3(-0.03, -0.14, 0.16), 0.17, 0.0)
			_crate(list, Vector3(-0.02, 0.17, 0.16), 0.17, 0.1)
			_crate(list, Vector3(0.26, -0.06, 0.15), 0.15, 0.9, 0.35)
			_blob(fx, Vector3(0.05, 0.0, 0.34), 0.16, "flash")
		2:
			_crate(list, Vector3(-0.03, -0.14, 0.1), 0.15, 0.3, 0.15)
			_crate(list, Vector3(0.0, 0.2, 0.08), 0.12, 0.6, 0.4)
			_crate(list, Vector3(0.24, -0.08, 0.08), 0.1, 1.2, 0.5)
			_scorch(list)
			_blob(fx, Vector3(-0.03, -0.05, 0.2), 0.13, "fire")
		3:
			for q in 9:
				var a := _rnd(q, 21) * TAU
				var r := 0.1 + 0.28 * _rnd(q, 22)
				var plank := Prim.new(BOX, Vector3(cos(a) * r, sin(a) * r, 0.02), Vector3(0.16 * (0.5 + _rnd(q, 23)), 0.025, 0.012), "wood", _rnd(q, 24) * 3.1)
				list.append(plank)
			_crate(list, Vector3(0, 0, 0.05), 0.08, 0.4, 0.6)
			_scorch(list)
			_blob(fx, Vector3(0, 0, 0.12), 0.07, "smoke")
	if d >= 2:
		_scorch(ground)
	m.append_array(ground)
	m.append_array(list)
	m.append_array(fx)


static func _drum(list: Array[Prim], c: Vector3, mat: String, pitch: float = 0.0, yaw: float = 0.0) -> void:
	var parts: Array[Prim] = []
	parts.append(Prim.new(CYL, Vector3(0, 0, 0), Vector3(0.115, 0, 0.14), mat))
	parts.append(Prim.new(CYL, Vector3(0, 0, -0.07), Vector3(0.122, 0, 0.012), "steel"))
	parts.append(Prim.new(CYL, Vector3(0, 0, 0.07), Vector3(0.122, 0, 0.012), "steel"))
	parts.append(Prim.new(CYL, Vector3(0, 0, 0.14), Vector3(0.1, 0, 0.012), "steel"))
	_xform_about(parts, Vector3.ZERO, Basis(Vector3(0, 0, 1), yaw) * Basis(Vector3(0, 1, 0), pitch), c)
	list.append_array(parts)


## Three oil drums. Frames 0 intact, 1 blast (one tipped), 2 burning, 3 charred and scattered.
func _drums(m: Array[Prim], frame: int) -> void:
	var d := frame
	var list: Array[Prim] = []
	var fx: Array[Prim] = []
	var ground: Array[Prim] = [Prim.new(CYL, Vector3(0, 0, 0.008), Vector3(0.38, 0, 0.008), "dirt")]
	match d:
		0:
			_drum(list, Vector3(0.0, -0.13, 0.14), "drum")
			_drum(list, Vector3(0.0, 0.13, 0.14), "hull")
			_drum(list, Vector3(0.2, 0.0, 0.14), "drum")
		1:
			_drum(list, Vector3(0.0, -0.13, 0.14), "drum")
			_drum(list, Vector3(0.0, 0.13, 0.14), "hull")
			_drum(list, Vector3(0.28, 0.12, 0.115), "drum", PI * 0.5, 0.7)
			_blob(fx, Vector3(0.1, 0.0, 0.3), 0.2, "flash")
		2:
			_drum(list, Vector3(-0.02, -0.16, 0.115), "drum", PI * 0.5, 0.3)
			_drum(list, Vector3(0.05, 0.14, 0.14), "hull")
			_drum(list, Vector3(0.3, 0.1, 0.115), "drum", PI * 0.5, 1.2)
			_scorch(list)
			_blob(fx, Vector3(0.0, 0.1, 0.3), 0.13, "fire")
			_blob(fx, Vector3(-0.02, -0.16, 0.22), 0.07, "fire")
		3:
			_drum(list, Vector3(-0.04, -0.17, 0.115), "drum", PI * 0.5, 0.3)
			_drum(list, Vector3(0.08, 0.2, 0.115), "hull", PI * 0.5, 1.9)
			_drum(list, Vector3(0.28, 0.0, 0.115), "drum", PI * 0.5, 1.2)
			_scorch(list)
			_blob(fx, Vector3(0.0, 0.0, 0.2), 0.08, "smoke")
			_blob(fx, Vector3(0.04, 0.02, 0.36), 0.07, "smoke")
	if d >= 2:
		_scorch(ground)
	m.append_array(ground)
	m.append_array(list)
	m.append_array(fx)


## Czech hedgehog: three perpendicular angle-iron beams. Frames 0 intact, 1 one beam bent, 2 knocked over, 3 flung apart.
func _trap(m: Array[Prim], frame: int) -> void:
	var d := frame
	var list: Array[Prim] = []
	var fx: Array[Prim] = []
	var ground: Array[Prim] = [Prim.new(CYL, Vector3(0, 0, 0.008), Vector3(0.4, 0, 0.008), "dirt")]
	var dirs: Array[Vector3] = [
		Vector3(sqrt(2.0 / 3.0), 0, sqrt(1.0 / 3.0)),
		Vector3(-sqrt(1.0 / 6.0), sqrt(0.5), sqrt(1.0 / 3.0)),
		Vector3(-sqrt(1.0 / 6.0), -sqrt(0.5), sqrt(1.0 / 3.0)),
	]
	var half := 0.4
	var c := Vector3(0, 0, half * dirs[0].z + 0.03)
	match d:
		0:
			for u in dirs:
				_bone(list, c - u * half, c + u * half, 0.034, 0.034, "steel")
		1:
			_bone(list, c - dirs[0] * half, c + dirs[0] * half, 0.034, 0.034, "steel")
			_bone(list, c - dirs[1] * half, c + dirs[1] * half, 0.034, 0.034, "steel")
			var bent := Vector3(-sqrt(1.0 / 6.0), -sqrt(0.5) * 0.4, sqrt(1.0 / 3.0) * 1.6).normalized()
			_bone(list, c - dirs[2] * half, c, 0.034, 0.034, "steel")
			_bone(list, c, c + bent * half, 0.034, 0.034, "steel")
			_blob(fx, c, 0.17, "flash")
		2:
			var g := Basis(Vector3(1, 0, 0), 0.7) * Basis(Vector3(0, 0, 1), 0.4)
			var c2 := Vector3(0.05, 0.06, 0.26)
			for u in dirs:
				var v := g * u
				_bone(list, c2 - v * half, c2 + v * half, 0.034, 0.034, "steel")
			_scorch(list)
			_blob(fx, Vector3(0.0, 0, 0.12), 0.1, "fire")
		3:
			var ends: Array[Array] = [
				[Vector3(-0.3, -0.1, 0.03), Vector3(0.1, 0.1, 0.04)],
				[Vector3(0.0, 0.3, 0.03), Vector3(0.38, 0.15, 0.04)],
				[Vector3(-0.1, -0.38, 0.03), Vector3(0.25, -0.2, 0.04)],
			]
			for e in ends:
				_bone(list, e[0], e[1], 0.034, 0.03, "steel")
			_scorch(list)
			_blob(fx, Vector3(0, 0, 0.1), 0.07, "smoke")
	if d >= 2:
		_scorch(ground)
	m.append_array(ground)
	m.append_array(list)
	m.append_array(fx)


## Tilts a wrecked vehicle: d = 2 sagging, 3 tipping, 4 lying on its side. Parts are lifted so none sink below the ground.
static func _tip(parts: Array[Prim], d: int, half_w: float) -> void:
	match d:
		2:
			_xform_about(parts, Vector3.ZERO, Basis(Vector3(1, 0, 0), 0.12), Vector3(0, 0, 0.05))
		3:
			_xform_about(parts, Vector3.ZERO, Basis(Vector3(1, 0, 0), 0.5), Vector3(0, 0.02, half_w * 0.55))
		4:
			_xform_about(parts, Vector3.ZERO, Basis(Vector3(1, 0, 0), 1.42), Vector3(0, 0.0, half_w + 0.02))


## Army jeep. Frames 0 idle, 1-4 destruction (fireball, sagging, tipping, burnt wreck on its side).
func _jeep(m: Array[Prim], frame: int) -> void:
	var d := frame
	var body: Array[Prim] = []
	var wheels: Array[Prim] = []
	var gun: Array[Prim] = []
	var fx: Array[Prim] = []
	body.append(Prim.new(BOX, Vector3(-0.02, 0, 0.17), Vector3(0.38, 0.17, 0.06), "hull"))
	body.append(Prim.new(BOX, Vector3(0.27, 0, 0.26), Vector3(0.13, 0.16, 0.05), "hull"))  # hood
	body.append(Prim.new(BOX, Vector3(0.43, 0, 0.2), Vector3(0.025, 0.14, 0.04), "gun"))  # grille
	body.append(Prim.new(BOX, Vector3(0.11, 0, 0.35), Vector3(0.012, 0.15, 0.065), "glass"))  # windscreen
	body.append(Prim.new(BOX, Vector3(-0.1, 0.1, 0.28), Vector3(0.07, 0.05, 0.05), "ammo"))  # seats
	body.append(Prim.new(BOX, Vector3(-0.1, -0.1, 0.28), Vector3(0.07, 0.05, 0.05), "ammo"))
	body.append(Prim.new(BOX, Vector3(-0.3, 0, 0.27), Vector3(0.1, 0.15, 0.04), "hull"))  # rear bed
	body.append(Prim.new(BOX, Vector3(-0.42, 0, 0.3), Vector3(0.02, 0.07, 0.07), "track"))  # spare wheel
	for x in [0.27, -0.24]:
		for side in [1, -1]:
			wheels.append(Prim.new(SPH, Vector3(x, 0.19 * side, 0.1), Vector3(0.1, 0.04, 0.1), "track"))
			wheels.append(Prim.new(SPH, Vector3(x, 0.205 * side, 0.1), Vector3(0.045, 0.02, 0.045), "steel"))
	gun.append(Prim.new(BOX, Vector3(-0.06, 0, 0.37), Vector3(0.015, 0.015, 0.07), "gun"))  # pintle MG
	gun.append(Prim.new(BOX, Vector3(0.04, 0, 0.45), Vector3(0.12, 0.02, 0.025), "gun"))
	if d >= 1:
		_scorch(body)
		_scorch(wheels)
		_scorch(gun)
	if d >= 3:
		_xform_about(gun, Vector3(-0.06, 0, 0.37), Basis(Vector3(0, 1, 0), 0.6), Vector3(-0.1, 0.12, -0.2))
	match d:
		1:
			_blob(fx, Vector3(0.0, 0, 0.3), 0.38, "flash")
			_blob(fx, Vector3(0.12, 0.08, 0.28), 0.22, "fire")
		2:
			_blob(fx, Vector3(0.0, 0, 0.34), 0.2, "fire")
			_blob(fx, Vector3(0.25, 0.0, 0.34), 0.13, "flash")
		3:
			_blob(fx, Vector3(-0.05, 0, 0.3), 0.15, "fire")
			_blob(fx, Vector3(-0.05, 0, 0.5), 0.1, "smoke")
		4:
			_blob(fx, Vector3(0.0, 0, 0.26), 0.09, "fire")
			_blob(fx, Vector3(0.0, 0, 0.46), 0.1, "smoke")
			_blob(fx, Vector3(0.05, 0.0, 0.64), 0.08, "smoke")
	if d >= 2:
		var tipped: Array[Prim] = []
		tipped.append_array(body)
		tipped.append_array(wheels)
		tipped.append_array(gun)
		_tip(tipped, d, 0.2)
		if d == 4:
			_xform_about(fx, Vector3.ZERO, Basis.IDENTITY, Vector3(0, 0.1, 0.0))
	m.append_array(body)
	m.append_array(wheels)
	m.append_array(gun)
	m.append_array(fx)


## Canvas-top supply truck. Frames 0 idle, 1-4 destruction as for the jeep.
func _truck(m: Array[Prim], frame: int) -> void:
	var d := frame
	var body: Array[Prim] = []
	var wheels: Array[Prim] = []
	var fx: Array[Prim] = []
	body.append(Prim.new(BOX, Vector3(0, 0, 0.17), Vector3(0.62, 0.2, 0.05), "gun"))  # chassis
	body.append(Prim.new(BOX, Vector3(0.43, 0, 0.35), Vector3(0.16, 0.19, 0.14), "hull"))  # cab
	body.append(Prim.new(BOX, Vector3(0.575, 0, 0.3), Vector3(0.025, 0.17, 0.08), "hull"))  # bonnet
	body.append(Prim.new(BOX, Vector3(0.575, 0, 0.4), Vector3(0.012, 0.15, 0.06), "glass"))
	body.append(Prim.new(BOX, Vector3(0.435, 0.195, 0.4), Vector3(0.1, 0.008, 0.07), "glass"))  # side windows
	body.append(Prim.new(BOX, Vector3(0.435, -0.195, 0.4), Vector3(0.1, 0.008, 0.07), "glass"))
	body.append(Prim.new(BOX, Vector3(-0.14, 0, 0.42), Vector3(0.43, 0.19, 0.17), "canvas"))  # cargo cover
	for i in 5:  # canvas ribs
		body.append(Prim.new(BOX, Vector3(-0.44 + 0.15 * i, 0, 0.6), Vector3(0.012, 0.2, 0.012), "woodd"))
	body.append(Prim.new(BOX, Vector3(-0.58, 0, 0.3), Vector3(0.012, 0.18, 0.12), "canvas"))  # tailgate flap
	for x in [0.43, -0.12, -0.45]:
		for side in [1, -1]:
			wheels.append(Prim.new(SPH, Vector3(x, 0.215 * side, 0.115), Vector3(0.115, 0.05, 0.115), "track"))
			wheels.append(Prim.new(SPH, Vector3(x, 0.235 * side, 0.115), Vector3(0.05, 0.02, 0.05), "steel"))
	if d >= 1:
		_scorch(body)
		_scorch(wheels)
	match d:
		1:
			_blob(fx, Vector3(0.0, 0, 0.4), 0.48, "flash")
			_blob(fx, Vector3(0.2, 0.1, 0.34), 0.26, "fire")
			_blob(fx, Vector3(-0.3, -0.08, 0.4), 0.22, "fire")
		2:
			_blob(fx, Vector3(-0.1, 0, 0.5), 0.26, "fire")
			_blob(fx, Vector3(0.3, 0.0, 0.46), 0.14, "flash")
		3:
			_blob(fx, Vector3(-0.1, 0, 0.42), 0.18, "fire")
			_blob(fx, Vector3(-0.1, 0, 0.64), 0.12, "smoke")
		4:
			_blob(fx, Vector3(0.0, 0, 0.3), 0.1, "fire")
			_blob(fx, Vector3(0.0, 0, 0.5), 0.11, "smoke")
			_blob(fx, Vector3(0.05, 0.0, 0.7), 0.09, "smoke")
	if d >= 2:
		var tipped: Array[Prim] = []
		tipped.append_array(body)
		tipped.append_array(wheels)
		_tip(tipped, d, 0.26)
		if d == 4:
			_xform_about(fx, Vector3.ZERO, Basis.IDENTITY, Vector3(0, 0.1, 0.0))
	m.append_array(body)
	m.append_array(wheels)
	m.append_array(fx)


## Burnt-out civilian car, one static frame: no glass, a wheel missing, blackened and rusted, a wisp of smoke.
func _wreck_car(m: Array[Prim]) -> void:
	var car: Array[Prim] = []
	var wheels: Array[Prim] = []
	car.append(Prim.new(BOX, Vector3(0, 0, 0.14), Vector3(0.4, 0.17, 0.06), "char"))
	car.append(Prim.new(BOX, Vector3(-0.04, 0, 0.27), Vector3(0.2, 0.15, 0.065), "char"))  # cabin
	car.append(Prim.new(BOX, Vector3(0.26, 0, 0.21), Vector3(0.13, 0.16, 0.03), "char"))  # bonnet
	car.append(Prim.new(BOX, Vector3(-0.04, 0, 0.345), Vector3(0.17, 0.12, 0.012), "charhi"))  # roof
	car.append(Prim.new(BOX, Vector3(0.065, 0, 0.28), Vector3(0.01, 0.12, 0.045), "gun"))  # empty windscreen
	car.append(Prim.new(BOX, Vector3(-0.04, 0.152, 0.28), Vector3(0.13, 0.006, 0.04), "gun"))
	car.append(Prim.new(BOX, Vector3(-0.04, -0.152, 0.28), Vector3(0.13, 0.006, 0.04), "gun"))
	for x in [0.25, -0.25]:
		for side in [1, -1]:
			if x < 0 and side < 0:
				continue  # that wheel is gone: the car sits lower on its axle
			wheels.append(Prim.new(SPH, Vector3(x, 0.18 * side, 0.085), Vector3(0.085, 0.035, 0.085), "track"))
	_scorch(wheels)
	_blob(m, Vector3(0.28, 0, 0.2), 0.035, "fire")  # embers under the bonnet
	_xform_about(car, Vector3(0, 0, 0), Basis(Vector3(1, 0, 0), -0.1), Vector3(0, -0.04, 0.0))
	m.append_array(car)
	m.append_array(wheels)
	_blob(m, Vector3(0.0, 0, 0.5), 0.06, "smoke")
	_blob(m, Vector3(0.05, 0.02, 0.62), 0.045, "smoke")


# ---- scenery: nature, street clutter, buildings, ruins, base pieces ----------------------------------

static func _bx(l: Array[Prim], c: Vector3, h: Vector3, mat: String, yaw: float = 0.0) -> void:
	l.append(Prim.new(BOX, c, h, mat, yaw))


static func _cy(l: Array[Prim], c: Vector3, r: float, hz: float, mat: String) -> void:
	l.append(Prim.new(CYL, c, Vector3(r, 0, hz), mat))


static func _sp(l: Array[Prim], c: Vector3, r: Vector3, mat: String) -> void:
	l.append(Prim.new(SPH, c, r, mat))


## Windows on all four faces of a box centred at `c` with half extents hx, hy: `nx` along x (on the +/-y faces),
## `ny` along y (on the +/-x faces), at each height in `zs`.
static func _windows(l: Array[Prim], c: Vector3, hx: float, hy: float, zs: Array, nx: int, ny: int, ww: float, wh: float) -> void:
	for z in zs:
		for i in nx:
			var x := c.x + (float(i) + 0.5 - float(nx) * 0.5) * (2.0 * hx / float(nx))
			for s in [1.0, -1.0]:
				l.append(Prim.new(BOX, Vector3(x, c.y + s * (hy + 0.004), float(z)), Vector3(ww, 0.008, wh), "glass"))
		for j in ny:
			var y := c.y + (float(j) + 0.5 - float(ny) * 0.5) * (2.0 * hy / float(ny))
			for s in [1.0, -1.0]:
				l.append(Prim.new(BOX, Vector3(c.x + s * (hx + 0.004), y, float(z)), Vector3(0.008, ww, wh), "glass"))


## Gable roof over a box with half extents hx, hy whose top is at `z`; ridge runs along y.
static func _gable(l: Array[Prim], c: Vector3, hx: float, hy: float, z: float, rise: float, mat: String, wall_mat: String) -> void:
	var span := hx + 0.06
	var th := atan2(rise, span)
	var half_len := span / cos(th) * 0.5
	for s in [1.0, -1.0]:
		var p := Prim.new(BOX, Vector3(c.x + s * span * 0.5, c.y, z + rise * 0.5 + 0.015), Vector3(half_len, hy + 0.07, 0.02), mat, 0.0, 0.06)
		p.basis = Basis(Vector3(0, 1, 0), th * s)
		l.append(p)
	for k in 3:  # triangular gable ends, stepped
		var f := 1.0 - (float(k) + 0.5) / 3.0
		for s in [1.0, -1.0]:
			l.append(Prim.new(BOX, Vector3(c.x, c.y + s * (hy - 0.005), z + rise * (float(k) + 0.5) / 3.0), Vector3(hx * f, 0.02, rise / 6.0), wall_mat))


static func _leaf_blob(l: Array[Prim], c: Vector3, r: float, seed_i: int) -> void:
	var mats := ["leafd", "leaf", "leafl"]
	l.append(Prim.new(SPH, c, Vector3(r, r, r * 0.85), mats[seed_i % 3]))


func _oak(m: Array[Prim], variant: int) -> void:
	_cy(m, Vector3(0, 0, 0.25), 0.075 + 0.02 * variant, 0.25, "bark")
	_bone(m, Vector3(0, 0, 0.45), Vector3(0.12, 0.1, 0.72), 0.03, 0.03, "bark")
	_bone(m, Vector3(0, 0, 0.45), Vector3(-0.1, -0.12, 0.7), 0.025, 0.025, "bark")
	var blobs: Array = [
		[Vector3(0.0, 0.0, 0.95), 0.34], [Vector3(0.18, 0.12, 0.8), 0.24], [Vector3(-0.17, -0.1, 0.82), 0.25],
		[Vector3(0.06, -0.2, 1.0), 0.22], [Vector3(-0.08, 0.18, 1.05), 0.22], [Vector3(0.05, 0.0, 1.18), 0.2],
	]
	if variant == 1:
		blobs = [
			[Vector3(0.0, 0.0, 0.85), 0.4], [Vector3(0.24, 0.0, 0.95), 0.26], [Vector3(-0.22, 0.12, 1.0), 0.28],
			[Vector3(0.0, -0.22, 1.1), 0.26], [Vector3(0.02, 0.1, 1.28), 0.26],
		]
	for i in blobs.size():
		_leaf_blob(m, blobs[i][0], blobs[i][1], i)


func _pine(m: Array[Prim]) -> void:
	_cy(m, Vector3(0, 0, 0.2), 0.06, 0.2, "bark")
	var radii := [0.36, 0.29, 0.22, 0.15]
	for i in 4:
		_cy(m, Vector3(0, 0, 0.32 + 0.22 * float(i)), float(radii[i]), 0.11, "leafd" if i % 2 == 0 else "leaf")
	_sp(m, Vector3(0, 0, 1.28), Vector3(0.07, 0.07, 0.12), "leaf")


func _dead_tree(m: Array[Prim]) -> void:
	_cy(m, Vector3(0, 0, 0.3), 0.07, 0.3, "deadwood")
	_bone(m, Vector3(0, 0, 0.55), Vector3(0.3, 0.15, 0.95), 0.028, 0.028, "deadwood")
	_bone(m, Vector3(0, 0, 0.5), Vector3(-0.28, -0.1, 0.85), 0.025, 0.025, "deadwood")
	_bone(m, Vector3(0, 0, 0.62), Vector3(0.05, -0.3, 0.92), 0.022, 0.022, "deadwood")
	_bone(m, Vector3(0.12, 0.06, 0.74), Vector3(0.3, 0.3, 1.08), 0.018, 0.018, "deadwood")
	_bone(m, Vector3(0, 0, 0.6), Vector3(0, 0.02, 1.15), 0.03, 0.03, "deadwood")


func _bush(m: Array[Prim]) -> void:
	_sp(m, Vector3(0, 0, 0.14), Vector3(0.24, 0.22, 0.15), "leafd")
	_sp(m, Vector3(0.12, 0.1, 0.2), Vector3(0.16, 0.15, 0.13), "leaf")
	_sp(m, Vector3(-0.1, -0.08, 0.22), Vector3(0.15, 0.15, 0.13), "leaf")
	_sp(m, Vector3(0.02, -0.02, 0.3), Vector3(0.1, 0.1, 0.08), "leafl")


func _boulder(m: Array[Prim]) -> void:
	_sp(m, Vector3(0, 0, 0.17), Vector3(0.3, 0.26, 0.2), "stone")
	_sp(m, Vector3(0.1, 0.12, 0.26), Vector3(0.15, 0.13, 0.12), "stonel")
	_bx(m, Vector3(-0.18, -0.08, 0.06), Vector3(0.08, 0.06, 0.06), "stone", 0.5)


func _rock_pile(m: Array[Prim]) -> void:
	var spots: Array = [[Vector3(0.0, 0.0, 0.12), 0.2], [Vector3(0.24, 0.1, 0.09), 0.14], [Vector3(-0.2, 0.14, 0.1), 0.15], [Vector3(0.05, -0.24, 0.1), 0.16], [Vector3(-0.18, -0.2, 0.07), 0.1]]
	for i in spots.size():
		var r: float = spots[i][1]
		_sp(m, spots[i][0], Vector3(r, r * 0.9, r * 0.8), "stone" if i % 2 == 0 else "stonel")


func _fallen_log(m: Array[Prim]) -> void:
	_bone(m, Vector3(-0.38, 0, 0.1), Vector3(0.38, 0.04, 0.11), 0.1, 0.1, "bark")
	_bone(m, Vector3(-0.3, 0.14, 0.07), Vector3(0.2, 0.2, 0.08), 0.07, 0.07, "bark")
	_cy(m, Vector3(0.42, -0.1, 0.08), 0.1, 0.08, "bark")
	_sp(m, Vector3(0.42, -0.1, 0.17), Vector3(0.08, 0.08, 0.02), "wood")


func _trash_pile(m: Array[Prim]) -> void:
	for i in 6:
		var a := TAU * float(i) / 6.0
		_sp(m, Vector3(cos(a) * 0.17, sin(a) * 0.17, 0.09), Vector3(0.1, 0.09, 0.09), "bag")
	_sp(m, Vector3(0.0, 0.0, 0.2), Vector3(0.13, 0.12, 0.12), "bag")
	_bx(m, Vector3(0.12, -0.15, 0.15), Vector3(0.07, 0.06, 0.04), "cardboard", 0.6)
	_bx(m, Vector3(-0.14, 0.1, 0.22), Vector3(0.05, 0.08, 0.03), "cardboard", 0.2)
	_cy(m, Vector3(0.22, 0.14, 0.04), 0.03, 0.04, "steel")
	_cy(m, Vector3(-0.22, -0.12, 0.04), 0.03, 0.04, "red")


func _dumpster(m: Array[Prim]) -> void:
	_bx(m, Vector3(0, 0, 0.18), Vector3(0.36, 0.2, 0.15), "dump")
	_bx(m, Vector3(0, 0, 0.35), Vector3(0.38, 0.22, 0.025), "dumpd")
	_bx(m, Vector3(0.0, 0.0, 0.05), Vector3(0.34, 0.18, 0.03), "gun")
	for s in [1.0, -1.0]:
		_cy(m, Vector3(-0.28, 0.2 * s, 0.05), 0.04, 0.04, "track")
		_cy(m, Vector3(0.28, 0.2 * s, 0.05), 0.04, 0.04, "track")
	_bx(m, Vector3(0.0, 0.0, 0.38), Vector3(0.1, 0.1, 0.02), "cardboard", 0.4)


func _tire_stack(m: Array[Prim]) -> void:
	for i in 4:
		_cy(m, Vector3(0, 0, 0.04 + 0.075 * float(i)), 0.15, 0.037, "track")
	_cy(m, Vector3(0, 0, 0.34), 0.07, 0.005, "gun")
	_cy(m, Vector3(0.3, 0.12, 0.04), 0.14, 0.037, "track")
	_cy(m, Vector3(0.28, -0.18, 0.04), 0.14, 0.037, "track")
	_cy(m, Vector3(0.28, -0.18, 0.115), 0.14, 0.037, "track")


func _scrap_pile(m: Array[Prim]) -> void:
	_sp(m, Vector3(0, 0, 0.1), Vector3(0.3, 0.26, 0.14), "rust")
	_bone(m, Vector3(-0.25, -0.1, 0.1), Vector3(0.22, 0.2, 0.4), 0.025, 0.025, "steel")
	_bone(m, Vector3(-0.1, 0.2, 0.08), Vector3(0.28, -0.1, 0.3), 0.03, 0.02, "rust")
	_bx(m, Vector3(0.1, -0.05, 0.24), Vector3(0.14, 0.1, 0.02), "corrugated", 0.4)
	_bx(m, Vector3(-0.05, 0.1, 0.2), Vector3(0.1, 0.12, 0.02), "steel", -0.3)
	_cy(m, Vector3(0.22, 0.12, 0.08), 0.08, 0.07, "drumc")


func _street_lamp(m: Array[Prim]) -> void:
	_cy(m, Vector3(0, 0, 0.02), 0.07, 0.02, "steel")
	_cy(m, Vector3(0, 0, 0.55), 0.025, 0.55, "steel")
	_bone(m, Vector3(0, 0, 1.08), Vector3(0.22, 0, 1.14), 0.02, 0.02, "steel")
	_bx(m, Vector3(0.27, 0, 1.11), Vector3(0.09, 0.05, 0.025), "gun")
	_bx(m, Vector3(0.27, 0, 1.08), Vector3(0.07, 0.04, 0.01), "lampglow")


func _road_sign(m: Array[Prim]) -> void:
	_cy(m, Vector3(0, 0, 0.35), 0.018, 0.35, "steel")
	_bx(m, Vector3(0.015, 0, 0.68), Vector3(0.012, 0.13, 0.13), "red")
	_bx(m, Vector3(0.027, 0, 0.68), Vector3(0.006, 0.09, 0.03), "whitep")


func _bench(m: Array[Prim]) -> void:
	_bx(m, Vector3(0, 0, 0.17), Vector3(0.05, 0.3, 0.015), "wood")
	_bx(m, Vector3(-0.09, 0, 0.27), Vector3(0.012, 0.3, 0.07), "wood")
	for s in [1.0, -1.0]:
		_bx(m, Vector3(0, 0.26 * s, 0.08), Vector3(0.05, 0.015, 0.08), "steel")
		_bx(m, Vector3(-0.09, 0.26 * s, 0.17), Vector3(0.012, 0.015, 0.12), "steel")


# ---- buildings ----

func _house(m: Array[Prim], ruin: int, wall: String, roof: String, large: bool) -> void:
	var hx := 0.9 if not large else 1.35
	var hy := 0.8 if not large else 0.8
	var wz := 0.38
	var c := Vector3(0, 0, wz)
	if ruin == 0:
		_bx(m, c, Vector3(hx, hy, wz), wall)
		_bx(m, Vector3(0, 0, 0.02), Vector3(hx + 0.03, hy + 0.03, 0.02), "concrete")  # footing
		_windows(m, c, hx, hy, [0.45], 3 if not large else 5, 2, 0.1, 0.1)
		_bx(m, Vector3(hx + 0.006, 0.0, 0.18), Vector3(0.008, 0.1, 0.16), "woodd")  # door
		_bx(m, Vector3(0.0, hy + 0.006, 0.18), Vector3(0.1, 0.008, 0.16), "woodd")
		_gable(m, c, hx, hy, wz * 2.0, 0.34, roof, wall)
		_bx(m, Vector3(-hx * 0.45, hy * 0.35, wz * 2.0 + 0.3), Vector3(0.07, 0.07, 0.14), "brick")  # chimney
		return
	# ruin: broken walls of varying height, collapsed beams, rubble, scorch
	var w2 := "plasterc" if ruin == 2 else wall
	var rng_i := 7
	var segs := 7
	for i in segs:  # front (+x) and back (-x) walls as jagged runs
		var y := (float(i) + 0.5 - float(segs) * 0.5) * (2.0 * hy / float(segs))
		var h1 := wz * (0.25 + 1.5 * _rnd(i, rng_i))
		_bx(m, Vector3(hx, y, h1 * 0.5), Vector3(0.05, hy / float(segs), h1 * 0.5), w2)
		var h2 := wz * (0.2 + 1.7 * _rnd(i, rng_i + 1))
		_bx(m, Vector3(-hx, y, h2 * 0.5), Vector3(0.05, hy / float(segs), h2 * 0.5), w2)
	var sx := 9
	for i in sx:
		var x := (float(i) + 0.5 - float(sx) * 0.5) * (2.0 * hx / float(sx))
		var h3 := wz * (0.15 + 1.4 * _rnd(i, rng_i + 2))
		_bx(m, Vector3(x, hy, h3 * 0.5), Vector3(hx / float(sx), 0.05, h3 * 0.5), w2)
		if i % 3 != 1:
			var h4 := wz * (0.2 + 1.2 * _rnd(i, rng_i + 3))
			_bx(m, Vector3(x, -hy, h4 * 0.5), Vector3(hx / float(sx), 0.05, h4 * 0.5), w2)
	_bx(m, Vector3(0, 0, 0.03), Vector3(hx * 0.95, hy * 0.95, 0.03), "rubble")
	for i in 7:  # rubble heaps
		var rx := (_rnd(i, 21) - 0.5) * 2.0 * hx * 0.8
		var ry := (_rnd(i, 22) - 0.5) * 2.0 * hy * 0.8
		_bx(m, Vector3(rx, ry, 0.07), Vector3(0.1 + 0.12 * _rnd(i, 23), 0.1 + 0.1 * _rnd(i, 24), 0.07), "rubble", _rnd(i, 25) * 3.0)
	_bone(m, Vector3(-hx * 0.6, -hy * 0.5, 0.5), Vector3(hx * 0.3, hy * 0.1, 0.14), 0.035, 0.035, "woodd")  # fallen roof beams
	_bone(m, Vector3(-hx * 0.2, hy * 0.4, 0.45), Vector3(hx * 0.7, -hy * 0.2, 0.1), 0.035, 0.035, "woodd")
	_bone(m, Vector3(hx * 0.1, -hy * 0.6, 0.38), Vector3(hx * 0.6, hy * 0.3, 0.12), 0.03, 0.03, "woodd")
	if ruin == 2:
		_blob(m, Vector3(-hx * 0.2, 0, 0.18), 0.1, "fire")
		_blob(m, Vector3(-hx * 0.2, 0.0, 0.42), 0.12, "smoke")


func _shop(m: Array[Prim], ruin: int) -> void:
	var hx := 1.35
	var hy := 0.85
	var wz := 0.45
	if ruin > 0:
		_house(m, ruin, "brick", "slate", true)
		return
	_bx(m, Vector3(0, 0, wz), Vector3(hx, hy, wz), "brick")
	_bx(m, Vector3(0, 0, wz * 2.0 + 0.03), Vector3(hx + 0.04, hy + 0.04, 0.03), "concrete")  # flat roof slab
	_bx(m, Vector3(hx + 0.008, 0.0, 0.3), Vector3(0.008, hy * 0.78, 0.2), "glass")  # shop front
	_bx(m, Vector3(hx + 0.008, 0.52, 0.28), Vector3(0.008, 0.1, 0.16), "woodd")
	_bx(m, Vector3(hx + 0.09, 0.0, 0.62), Vector3(0.1, hy * 0.82, 0.015), "red", 0.0)  # awning
	_bx(m, Vector3(hx + 0.012, 0.0, 0.79), Vector3(0.012, hy * 0.55, 0.07), "whitep")  # sign board
	_windows(m, Vector3(0, 0, wz), hx, hy, [0.55], 4, 2, 0.1, 0.09)
	_bx(m, Vector3(-0.6, 0.3, wz * 2.0 + 0.12), Vector3(0.12, 0.1, 0.07), "steel")  # roof unit


func _apartment(m: Array[Prim], ruin: int) -> void:
	var hx := 1.3
	var hy := 1.3
	var hz := 1.35
	if ruin == 0:
		_bx(m, Vector3(0, 0, hz), Vector3(hx, hy, hz), "plaster")
		_bx(m, Vector3(0, 0, 0.03), Vector3(hx + 0.04, hy + 0.04, 0.03), "concrete")
		_bx(m, Vector3(0, 0, hz * 2.0 + 0.04), Vector3(hx + 0.05, hy + 0.05, 0.04), "concrete")
		_windows(m, Vector3(0, 0, hz), hx, hy, [0.55, 1.05, 1.55, 2.05], 4, 4, 0.1, 0.1)
		_bx(m, Vector3(hx + 0.01, 0.0, 0.18), Vector3(0.01, 0.17, 0.17), "woodd")  # entrance
		_bx(m, Vector3(hx + 0.14, 0.0, 0.4), Vector3(0.14, 0.24, 0.02), "concrete")  # canopy
		_bx(m, Vector3(-0.5, -0.5, hz * 2.0 + 0.18), Vector3(0.16, 0.12, 0.1), "steel")
		_cy(m, Vector3(0.5, 0.4, hz * 2.0 + 0.2), 0.07, 0.12, "steel")
		return
	# ruin: jagged walls, the top floors gone on one side, exposed floors
	var w2 := "plasterc" if ruin == 2 else "plaster"
	var n := 8
	for i in n:
		var t := (float(i) + 0.5 - float(n) * 0.5) * (2.0 / float(n))
		var hh := hz * (0.5 + 1.15 * _rnd(i, 31)) * (1.0 - 0.45 * maxf(t, 0.0))
		_bx(m, Vector3(hx * t, hy, hh * 0.5), Vector3(hx / float(n), 0.06, hh * 0.5), w2)
		var hh2 := hz * (0.4 + 1.2 * _rnd(i, 32)) * (1.0 - 0.5 * maxf(-t, 0.0))
		_bx(m, Vector3(hx, hy * t, hh2 * 0.5), Vector3(0.06, hy / float(n), hh2 * 0.5), w2)
	for k in 2:  # floors sagging
		_bx(m, Vector3(-0.1, 0, 0.55 + 0.5 * float(k)), Vector3(hx * 0.9, hy * 0.9, 0.025), "concrete")
	_bx(m, Vector3(0, 0, 0.04), Vector3(hx, hy, 0.04), "rubble")
	for i in 9:
		var rx := (_rnd(i, 41) - 0.5) * 2.0 * hx * 0.9
		var ry := (_rnd(i, 42) - 0.5) * 2.0 * hy * 0.9
		_bx(m, Vector3(rx, ry, 0.1), Vector3(0.12 + 0.14 * _rnd(i, 43), 0.12 + 0.12 * _rnd(i, 44), 0.1), "rubble", _rnd(i, 45) * 3.0)
	_bone(m, Vector3(-hx * 0.7, hy * 0.2, 1.1), Vector3(-hx * 0.2, hy * 0.5, 1.6), 0.03, 0.03, "rust")  # rebar
	_bone(m, Vector3(hx * 0.1, -hy * 0.5, 1.0), Vector3(hx * 0.3, -hy * 0.1, 1.5), 0.03, 0.03, "rust")
	if ruin == 2:
		_blob(m, Vector3(0.0, 0.0, 0.25), 0.16, "fire")
		_blob(m, Vector3(0.1, 0.0, 0.55), 0.18, "smoke")
		_blob(m, Vector3(0.15, 0.05, 0.85), 0.14, "smoke")


func _warehouse(m: Array[Prim], ruin: int) -> void:
	var hx := 1.85
	var hy := 1.3
	var wz := 0.55
	if ruin > 0:
		_house(m, ruin, "corrugated", "corrugated", true)
		_bx(m, Vector3(0, 0, 0.35), Vector3(hx * 0.2, hy * 0.6, 0.35), "corrugated")
		return
	_bx(m, Vector3(0, 0, wz), Vector3(hx, hy, wz), "corrugated")
	_gable(m, Vector3(0, 0, wz), hx, hy, wz * 2.0, 0.3, "steel", "corrugated")
	_bx(m, Vector3(hx + 0.01, 0.0, 0.35), Vector3(0.012, 0.5, 0.33), "woodd")  # big door
	_bx(m, Vector3(hx + 0.014, 0.0, 0.35), Vector3(0.008, 0.01, 0.33), "gun")
	for j in 3:
		_bx(m, Vector3(-0.8 + 0.8 * float(j), hy + 0.008, 0.82), Vector3(0.22, 0.008, 0.06), "glass")
	_bx(m, Vector3(0.0, 0, wz * 2.0 + 0.36), Vector3(0.9, 0.04, 0.04), "steel")  # ridge vents
	_bx(m, Vector3(0, 0, 0.03), Vector3(hx + 0.04, hy + 0.04, 0.03), "concrete")


func _wall_ruin(m: Array[Prim]) -> void:
	for i in 6:
		var x := (float(i) - 2.5) * 0.15
		var h := 0.15 + 0.5 * _rnd(i, 51)
		_bx(m, Vector3(x, 0, h * 0.5), Vector3(0.075, 0.06, h * 0.5), "plaster")
	for i in 4:
		_bx(m, Vector3((_rnd(i, 52) - 0.5) * 0.8, (_rnd(i, 53) - 0.5) * 0.4, 0.04), Vector3(0.08, 0.07, 0.04), "rubble", _rnd(i, 54) * 3.0)
	_bone(m, Vector3(0.2, 0, 0.3), Vector3(0.3, 0.05, 0.62), 0.02, 0.02, "rust")


func _rubble_heap(m: Array[Prim], big: bool) -> void:
	var n := 14 if big else 7
	var span := 0.9 if big else 0.4
	for i in n:
		var rx := (_rnd(i, 61) - 0.5) * 2.0 * span
		var ry := (_rnd(i, 62) - 0.5) * 2.0 * span
		var h := (0.1 + 0.16 * _rnd(i, 63)) * (1.0 - 0.5 * (absf(rx) + absf(ry)) / (2.0 * span))
		_bx(m, Vector3(rx, ry, h), Vector3(0.1 + 0.1 * _rnd(i, 64), 0.1 + 0.09 * _rnd(i, 65), h), "rubble", _rnd(i, 66) * 3.0)
	_bone(m, Vector3(-span * 0.4, 0, 0.2), Vector3(span * 0.3, span * 0.4, 0.45), 0.02, 0.02, "rust")
	_bx(m, Vector3(span * 0.2, -span * 0.3, 0.3), Vector3(0.14, 0.05, 0.02), "woodd", 0.7)


# ---- base ----

## The command bunker: frames 0 intact, 1 damaged, 2 burning, 3 ruin. About 1.6 cells wide.
func _hq(m: Array[Prim], frame: int) -> void:
	var d := frame
	var body: Array[Prim] = []
	var top: Array[Prim] = []
	var gear: Array[Prim] = []
	var fx: Array[Prim] = []
	_bx(body, Vector3(0, 0, 0.03), Vector3(0.84, 0.84, 0.03), "concrete")  # plinth
	_bx(body, Vector3(0, 0, 0.3), Vector3(0.72, 0.68, 0.27), "concrete")
	_bx(body, Vector3(0, 0, 0.6), Vector3(0.76, 0.72, 0.035), "concretel")  # roof slab
	_bx(body, Vector3(0.73, 0.0, 0.22), Vector3(0.012, 0.16, 0.19), "steel")  # armoured door
	_bx(body, Vector3(0.74, 0.0, 0.22), Vector3(0.008, 0.01, 0.19), "gun")
	for s in [1.0, -1.0]:
		_bx(body, Vector3(0.73, 0.42 * s, 0.38), Vector3(0.012, 0.12, 0.04), "gun")  # firing slits
		_bx(body, Vector3(0.0, 0.69 * s, 0.38), Vector3(0.12, 0.012, 0.04), "gun")
		_bx(body, Vector3(0.73, 0.42 * s, 0.38), Vector3(0.014, 0.1, 0.025), "glass")
	_bx(top, Vector3(-0.1, 0, 0.78), Vector3(0.38, 0.34, 0.15), "concrete")  # control room
	_bx(top, Vector3(-0.1, 0, 0.94), Vector3(0.4, 0.36, 0.02), "concretel")
	_windows(top, Vector3(-0.1, 0, 0.78), 0.38, 0.34, [0.8], 3, 3, 0.07, 0.05)
	_bone(top, Vector3(-0.32, 0.18, 0.96), Vector3(-0.32, 0.18, 1.55), 0.015, 0.015, "steel")  # mast
	_bone(top, Vector3(-0.32, 0.18, 1.35), Vector3(-0.32, 0.4, 1.35), 0.012, 0.012, "steel")
	_bone(top, Vector3(-0.32, 0.18, 1.2), Vector3(-0.32, -0.02, 1.2), 0.012, 0.012, "steel")
	_cy(top, Vector3(0.1, -0.2, 1.0), 0.1, 0.012, "steel")  # radar dish (flat)
	_bone(top, Vector3(0.1, -0.2, 0.96), Vector3(0.1, -0.2, 1.0), 0.02, 0.02, "steel")
	_bone(top, Vector3(0.18, 0.2, 0.96), Vector3(0.18, 0.2, 1.4), 0.012, 0.012, "steel")  # flag pole
	_bx(top, Vector3(0.18, 0.12, 1.34), Vector3(0.01, 0.1, 0.06), "red")
	for i in 5:  # sandbags along the front
		_bx(gear, Vector3(0.9, -0.5 + 0.25 * float(i), 0.06), Vector3(0.08, 0.1, 0.05), "sand")
		if i % 2 == 0:
			_bx(gear, Vector3(0.9, -0.38 + 0.25 * float(i), 0.15), Vector3(0.08, 0.1, 0.05), "sand")
	_bx(gear, Vector3(0.74, -0.2, 0.52), Vector3(0.012, 0.28, 0.04), "hull")  # hazard band over the door
	match d:
		1:  # scorched, a chunk gone from the roof edge, cracks, smoke
			_scorch(top)
			_bone(body, Vector3(0.74, 0.3, 0.5), Vector3(0.74, 0.5, 0.25), 0.012, 0.012, "gun")
			_bone(body, Vector3(0.3, 0.7, 0.55), Vector3(0.45, 0.7, 0.2), 0.012, 0.012, "gun")
			_blob(fx, Vector3(-0.2, 0.2, 1.05), 0.14, "smoke")
			_blob(fx, Vector3(-0.15, 0.25, 1.28), 0.12, "smoke")
		2:  # control room half collapsed, fires
			_scorch(top)
			_scorch(body)
			_xform_about(top, Vector3(-0.1, 0, 0.62), Basis(Vector3(1, 0, 0), 0.22), Vector3(0, 0.06, -0.12))
			_blob(fx, Vector3(0.1, 0.1, 0.7), 0.16, "fire")
			_blob(fx, Vector3(-0.3, -0.1, 0.62), 0.12, "fire")
			_blob(fx, Vector3(-0.1, 0.1, 1.0), 0.17, "smoke")
			_blob(fx, Vector3(-0.05, 0.12, 1.3), 0.15, "smoke")
		3:  # burnt-out shell
			_scorch(body)
			_scorch(top)
			_scorch(gear)
			_xform_about(top, Vector3(-0.1, 0, 0.62), Basis(Vector3(1, 0, 0), 0.9), Vector3(0.1, 0.3, -0.5))
			_blob(fx, Vector3(0.0, 0.0, 0.66), 0.1, "fire")
			_blob(fx, Vector3(0.0, 0.0, 0.88), 0.14, "smoke")
			_blob(fx, Vector3(0.05, 0.0, 1.14), 0.12, "smoke")
	m.append_array(body)
	m.append_array(top)
	m.append_array(gear)
	m.append_array(fx)


func _wall_x(m: Array[Prim], kind: String) -> void:
	# kind: "concrete" T-wall, "fence" chain-link, "sandbags" short sandbag wall. Runs along local x, 1 cell long.
	match kind:
		"concrete":
			_bx(m, Vector3(0, 0, 0.04), Vector3(0.5, 0.17, 0.04), "concrete")
			_bx(m, Vector3(0, 0, 0.3), Vector3(0.5, 0.06, 0.26), "concrete")
			_bx(m, Vector3(0, 0, 0.57), Vector3(0.5, 0.075, 0.025), "concretel")
			for s in [1.0, -1.0]:
				_bx(m, Vector3(0.48 * s, 0, 0.3), Vector3(0.025, 0.09, 0.27), "concrete")
		"fence":
			for i in 3:
				_cy(m, Vector3(-0.5 + 0.5 * float(i), 0, 0.28), 0.02, 0.28, "steel")
			_bx(m, Vector3(0, 0, 0.55), Vector3(0.5, 0.012, 0.012), "steel")
			_bx(m, Vector3(0, 0, 0.1), Vector3(0.5, 0.012, 0.012), "steel")
			for i in 12:
				_bx(m, Vector3(-0.45 + 0.082 * float(i), 0, 0.33), Vector3(0.006, 0.006, 0.23), "glass")
			_bx(m, Vector3(0, 0, 0.62), Vector3(0.5, 0.01, 0.01), "rust")  # razor wire
			_bx(m, Vector3(0, 0, 0.66), Vector3(0.5, 0.01, 0.01), "rust")
		"sandbags":
			for layer in 3:
				var n := 4 if layer % 2 == 0 else 3
				for i in n:
					var x := (float(i) - float(n - 1) * 0.5) * 0.24
					_bx(m, Vector3(x, 0, 0.045 + 0.085 * float(layer)), Vector3(0.11, 0.075, 0.045), "sand", (_rnd(i, layer + 70) - 0.5) * 0.12)


func _gate_post(m: Array[Prim]) -> void:
	_bx(m, Vector3(0, 0, 0.04), Vector3(0.16, 0.16, 0.04), "concrete")
	_bx(m, Vector3(0, 0, 0.5), Vector3(0.11, 0.11, 0.46), "concrete")
	_bx(m, Vector3(0, 0, 0.98), Vector3(0.14, 0.14, 0.03), "concretel")
	_bx(m, Vector3(0.0, 0, 1.05), Vector3(0.06, 0.06, 0.05), "lampglow")
	_bx(m, Vector3(0.115, 0, 0.6), Vector3(0.008, 0.07, 0.07), "whitep")
	_bx(m, Vector3(0.115, 0, 0.8), Vector3(0.008, 0.07, 0.02), "red")


func _boom_gate(m: Array[Prim]) -> void:
	_bx(m, Vector3(0, 0, 0.18), Vector3(0.1, 0.1, 0.18), "hull")
	_bx(m, Vector3(0, 0, 0.38), Vector3(0.11, 0.11, 0.025), "gun")
	_bone(m, Vector3(0, 0, 0.5), Vector3(0.0, 0.0, 1.25), 0.03, 0.02, "whitep")  # arm raised
	for k in 3:
		_bone(m, Vector3(0, 0, 0.62 + 0.25 * float(k)), Vector3(0, 0, 0.74 + 0.25 * float(k)), 0.032, 0.022, "red")
	_bx(m, Vector3(0.1, 0, 0.2), Vector3(0.008, 0.05, 0.05), "lampglow")


func _watchtower(m: Array[Prim]) -> void:
	for sx in [1.0, -1.0]:
		for sy in [1.0, -1.0]:
			_bone(m, Vector3(0.3 * sx, 0.3 * sy, 0.0), Vector3(0.22 * sx, 0.22 * sy, 1.35), 0.03, 0.03, "wood")
	for z in [0.4, 0.85]:
		for s in [1.0, -1.0]:
			_bone(m, Vector3(0.26 * s + 0.0, -0.28, z), Vector3(0.26 * s, 0.28, z + 0.3), 0.012, 0.012, "woodd")
	_bx(m, Vector3(0, 0, 1.38), Vector3(0.34, 0.34, 0.03), "wood")  # platform
	_bx(m, Vector3(0, 0, 1.58), Vector3(0.28, 0.28, 0.17), "hull")  # cabin
	_windows(m, Vector3(0, 0, 1.6), 0.28, 0.28, [1.62], 2, 2, 0.1, 0.05)
	_bx(m, Vector3(0, 0, 1.77), Vector3(0.38, 0.38, 0.025), "gun")  # roof
	_bx(m, Vector3(0, 0, 1.82), Vector3(0.3, 0.3, 0.025), "hull")
	_bx(m, Vector3(0.36, 0.0, 1.5), Vector3(0.02, 0.34, 0.1), "sand")  # sandbag rail
	_bx(m, Vector3(0.12, 0.34, 1.5), Vector3(0.24, 0.02, 0.1), "sand")
	_bx(m, Vector3(0.38, 0.2, 1.84), Vector3(0.05, 0.05, 0.04), "lampglow")  # searchlight
	_cy(m, Vector3(0.0, 0.0, 0.03), 0.4, 0.03, "dirt")


func _floodlight(m: Array[Prim]) -> void:
	_cy(m, Vector3(0, 0, 0.03), 0.09, 0.03, "concrete")
	_cy(m, Vector3(0, 0, 0.8), 0.03, 0.8, "steel")
	_bx(m, Vector3(0.02, 0, 1.62), Vector3(0.05, 0.28, 0.05), "gun")
	for i in 4:
		_bx(m, Vector3(0.08, -0.2 + 0.13 * float(i), 1.62), Vector3(0.02, 0.05, 0.04), "lampglow")


func _tent(m: Array[Prim]) -> void:
	var hx := 0.95
	var hy := 0.7
	_bx(m, Vector3(0, 0, 0.03), Vector3(hx + 0.1, hy + 0.1, 0.02), "dirt")
	_bx(m, Vector3(0, 0, 0.18), Vector3(hx, hy, 0.18), "tento")
	_gable(m, Vector3(0, 0, 0.18), hx, hy, 0.36, 0.38, "tento", "tento")
	_bx(m, Vector3(0.0, hy + 0.008, 0.14), Vector3(0.14, 0.008, 0.14), "gun")  # flap
	_bone(m, Vector3(hx + 0.1, 0.5, 0.0), Vector3(hx * 0.4, 0.4, 0.5), 0.008, 0.008, "woodd")
	_bone(m, Vector3(hx + 0.1, -0.5, 0.0), Vector3(hx * 0.4, -0.4, 0.5), 0.008, 0.008, "woodd")


func _generator(m: Array[Prim]) -> void:
	_bx(m, Vector3(0, 0, 0.04), Vector3(0.36, 0.26, 0.04), "concrete")
	_bx(m, Vector3(0, 0, 0.25), Vector3(0.3, 0.2, 0.17), "hull")
	_bx(m, Vector3(0.0, 0.0, 0.43), Vector3(0.31, 0.21, 0.015), "gun")
	_cy(m, Vector3(-0.2, 0.12, 0.62), 0.03, 0.2, "steel")
	_bx(m, Vector3(0.31, 0.0, 0.26), Vector3(0.008, 0.12, 0.1), "gun")
	_bx(m, Vector3(0.315, 0.06, 0.3), Vector3(0.006, 0.03, 0.03), "lampglow")
	_bone(m, Vector3(0.3, -0.2, 0.08), Vector3(0.5, -0.45, 0.02), 0.012, 0.012, "gun")
	_cy(m, Vector3(0.12, -0.34, 0.1), 0.07, 0.1, "drum")


func _fuel_tank(m: Array[Prim]) -> void:
	_cy(m, Vector3(0, 0, 0.03), 0.4, 0.03, "concrete")
	_cy(m, Vector3(0, 0, 0.42), 0.3, 0.36, "tankg")
	_cy(m, Vector3(0, 0, 0.8), 0.31, 0.015, "steel")
	_bone(m, Vector3(0.3, 0.0, 0.08), Vector3(0.3, 0.0, 0.78), 0.015, 0.015, "steel")  # ladder
	_bx(m, Vector3(0.0, 0.0, 0.84), Vector3(0.05, 0.05, 0.03), "red")
	_bone(m, Vector3(-0.3, 0.0, 0.2), Vector3(-0.45, 0.0, 0.08), 0.02, 0.02, "steel")
	_bx(m, Vector3(0.31, 0.0, 0.5), Vector3(0.008, 0.08, 0.1), "whitep")


func _container(m: Array[Prim], mat: String) -> void:
	# 2 cells long along local x.
	_bx(m, Vector3(0, 0, 0.3), Vector3(0.95, 0.4, 0.3), mat)
	for i in 9:  # corrugation ribs
		_bx(m, Vector3(-0.8 + 0.2 * float(i), 0.402, 0.3), Vector3(0.012, 0.004, 0.27), "steel")
		_bx(m, Vector3(-0.8 + 0.2 * float(i), -0.402, 0.3), Vector3(0.012, 0.004, 0.27), "steel")
	_bx(m, Vector3(0.953, 0.0, 0.3), Vector3(0.006, 0.34, 0.26), "steel")
	_bx(m, Vector3(0.96, 0.0, 0.3), Vector3(0.004, 0.005, 0.26), "gun")
	for sx in [1.0, -1.0]:
		for sy in [1.0, -1.0]:
			_bx(m, Vector3(0.95 * sx, 0.4 * sy, 0.3), Vector3(0.025, 0.025, 0.31), "steel")


func _radar_mast(m: Array[Prim]) -> void:
	_cy(m, Vector3(0, 0, 0.03), 0.16, 0.03, "concrete")
	_bx(m, Vector3(0, 0, 0.16), Vector3(0.1, 0.1, 0.13), "hull")
	_bone(m, Vector3(0, 0, 0.3), Vector3(0, 0, 1.3), 0.025, 0.025, "steel")
	for k in 3:
		_bone(m, Vector3(0, 0, 0.55 + 0.25 * float(k)), Vector3(0.0, 0.2 - 0.05 * float(k), 0.55 + 0.25 * float(k)), 0.012, 0.012, "steel")
		_bone(m, Vector3(0, 0, 0.55 + 0.25 * float(k)), Vector3(0.0, -0.2 + 0.05 * float(k), 0.55 + 0.25 * float(k)), 0.012, 0.012, "steel")
	_cy(m, Vector3(0.1, 0, 1.3), 0.17, 0.012, "steel")
	_sp(m, Vector3(0.1, 0, 1.3), Vector3(0.18, 0.18, 0.05), "steel")
	_bx(m, Vector3(0.0, 0, 1.38), Vector3(0.015, 0.015, 0.06), "red")


func _flag_pole(m: Array[Prim]) -> void:
	_cy(m, Vector3(0, 0, 0.03), 0.09, 0.03, "concrete")
	_cy(m, Vector3(0, 0, 0.75), 0.015, 0.75, "steel")
	_bx(m, Vector3(0.0, 0.14, 1.34), Vector3(0.006, 0.13, 0.08), "red")
	_bx(m, Vector3(0.0, 0.12, 1.34), Vector3(0.008, 0.04, 0.04), "whitep")
	_sp(m, Vector3(0, 0, 1.52), Vector3(0.025, 0.025, 0.025), "brass")


func _helipad(m: Array[Prim]) -> void:
	_bx(m, Vector3(0, 0, 0.012), Vector3(1.45, 1.45, 0.012), "padg")
	_bx(m, Vector3(0, 0.34, 0.026), Vector3(0.4, 0.05, 0.006), "whitep")  # the H
	_bx(m, Vector3(0, -0.34, 0.026), Vector3(0.4, 0.05, 0.006), "whitep")
	_bx(m, Vector3(0, 0, 0.026), Vector3(0.05, 0.34, 0.006), "whitep")
	_bx(m, Vector3(0.0, 0.0, 0.026), Vector3(0.4, 0.04, 0.006), "whitep")
	for s in [1.0, -1.0]:
		_bx(m, Vector3(1.4 * s, 0, 0.024), Vector3(0.04, 1.4, 0.006), "hull")
		_bx(m, Vector3(0, 1.4 * s, 0.024), Vector3(1.4, 0.04, 0.006), "hull")
	for sx in [1.0, -1.0]:
		for sy in [1.0, -1.0]:
			_bx(m, Vector3(1.38 * sx, 1.38 * sy, 0.05), Vector3(0.04, 0.04, 0.04), "lampglow")


func _barracks(m: Array[Prim], ruin: int) -> void:
	if ruin > 0:
		_house(m, ruin, "hull", "gun", true)
		return
	var hx := 1.35
	var hy := 0.6
	_bx(m, Vector3(0, 0, 0.03), Vector3(hx + 0.05, hy + 0.05, 0.03), "concrete")
	_bx(m, Vector3(0, 0, 0.3), Vector3(hx, hy, 0.27), "hull")
	_bx(m, Vector3(0, 0, 0.6), Vector3(hx + 0.05, hy + 0.05, 0.03), "gun")
	_windows(m, Vector3(0, 0, 0.3), hx, hy, [0.34], 5, 2, 0.1, 0.08)
	for i in 2:
		_bx(m, Vector3(hx + 0.008, -0.25 + 0.5 * float(i), 0.2), Vector3(0.008, 0.1, 0.17), "woodd")
	_bx(m, Vector3(-0.6, 0, 0.7), Vector3(0.12, 0.1, 0.06), "steel")


## Ray-cast every pixel (ss x ss samples, majority colour, >=50% coverage); returns the finished frame.
func _render(model: Array[Prim], facing: int, frame_size: Vector2i, origin: Vector2, ss: int) -> Image:
	var fwd := IsoProjection.ground_dir_of_facing(facing)
	var perp := Vector2(-fwd.y, fwd.x)
	var dz := IsoProjection.TILE_H / IsoProjection.Z_PX_PER_UNIT  # z gained per unit of ray t, along (1,1)
	var d := Vector3(Vector2(1, 1).dot(fwd), Vector2(1, 1).dot(perp), dz)
	var w := frame_size.x
	var h := frame_size.y
	var color: Array = []
	var depth: PackedFloat32Array = PackedFloat32Array()
	var pid: PackedInt32Array = PackedInt32Array()
	color.resize(w * h)
	depth.resize(w * h)
	pid.resize(w * h)
	# Screen box of every part, so a pixel only tests the parts that can cover it (same result, far fewer tests).
	var bx0 := PackedInt32Array()
	var bx1 := PackedInt32Array()
	var by_row: Array = []
	for y in h:
		by_row.append(PackedInt32Array())
	for pi in model.size():
		var mp := model[pi]
		var ext := mp.h if mp.kind != CYL else Vector3(mp.h.x, mp.h.x, mp.h.z)
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					var q: Vector3 = mp.c + mp.basis * Vector3(ext.x * sx, ext.y * sy, ext.z * sz)
					var sp2 := IsoProjection.ground_to_screen_z(fwd * q.x + perp * q.y, q.z) + origin
					lo = lo.min(sp2)
					hi = hi.max(sp2)
		bx0.append(floori(lo.x) - 1)
		bx1.append(ceili(hi.x) + 1)
		for ry in range(maxi(floori(lo.y) - 1, 0), mini(ceili(hi.y) + 1, h - 1) + 1):
			by_row[ry].append(pi)
	for y in h:
		for x in w:
			var i := y * w + x
			pid[i] = -1
			var cands := PackedInt32Array()
			for pi in by_row[y]:
				if x >= bx0[pi] and x <= bx1[pi]:
					cands.append(pi)
			if cands.is_empty():
				continue
			var votes: Dictionary = {}  # Color -> [count, depth, pid]
			var hits := 0
			for sj in ss:
				for si in ss:
					var sp := Vector2(x + (si + 0.5) / ss, y + (sj + 0.5) / ss) - origin
					var g0 := IsoProjection.screen_to_ground(sp)
					var o := Vector3(g0.dot(fwd), g0.dot(perp), 0.0)
					var best_t := -INF
					var best_n := Vector3.ZERO
					var best_p := -1
					for pi in cands:
						var hit := _hit(model[pi], o, d)
						if hit.is_empty():
							continue
						if hit["t"] > best_t:
							best_t = hit["t"]
							best_n = hit["n"]
							best_p = pi
					if best_p < 0:
						continue
					hits += 1
					var gn := Vector2(fwd * best_n.x + perp * best_n.y)
					var n_world := Vector3(gn.x, gn.y, best_n.z)
					var col := _shade(model[best_p], n_world, best_n, o + d * best_t)
					if votes.has(col):
						votes[col][0] += 1
					else:
						votes[col] = [1, best_t, best_p]
			if hits * 2 < ss * ss:
				continue
			var best_col := Color.BLACK
			var best_count := 0
			for col in votes:
				if votes[col][0] > best_count:
					best_count = votes[col][0]
					best_col = col
			color[i] = best_col
			depth[i] = votes[best_col][1]
			pid[i] = votes[best_col][2]
	return _finish(color, depth, pid, model, w, h)


## Ray vs primitive. The camera is on the +t side, so the visible surface is the exit point.
func _hit(p: Prim, o: Vector3, d: Vector3) -> Dictionary:
	var inv := p.basis.transposed()
	var lo := inv * (o - p.c)
	var ld := inv * d
	var t_exit := INF
	var t_enter := -INF
	var n := Vector3.ZERO
	if p.kind == BOX:
		for ax in 3:
			var oa := lo[ax]
			var da := ld[ax]
			var ha := p.h[ax]
			if absf(da) < 1e-9:
				if absf(oa) > ha:
					return {}
				continue
			var t1 := (-ha - oa) / da
			var t2 := (ha - oa) / da
			t_enter = maxf(t_enter, minf(t1, t2))
			var texit := maxf(t1, t2)
			if texit < t_exit:
				t_exit = texit
				n = Vector3.ZERO
				n[ax] = 1.0 if da > 0.0 else -1.0
	elif p.kind == CYL:
		var a := ld.x * ld.x + ld.y * ld.y
		var b := 2.0 * (lo.x * ld.x + lo.y * ld.y)
		var c := lo.x * lo.x + lo.y * lo.y - p.h.x * p.h.x
		var disc := b * b - 4.0 * a * c
		if disc < 0.0 or a < 1e-12:
			return {}
		var sq := sqrt(disc)
		var s1 := (-b - sq) / (2.0 * a)
		var s2 := (-b + sq) / (2.0 * a)
		var tz0 := (-p.h.z - lo.z) / ld.z
		var tz1 := (p.h.z - lo.z) / ld.z
		t_enter = maxf(s1, tz0)
		t_exit = minf(s2, tz1)
		if tz1 < s2:
			n = Vector3(0, 0, 1)
		else:
			var hp := lo + ld * s2
			n = Vector3(hp.x, hp.y, 0).normalized()
	else:
		var so := Vector3(lo.x / p.h.x, lo.y / p.h.y, lo.z / p.h.z)
		var sd := Vector3(ld.x / p.h.x, ld.y / p.h.y, ld.z / p.h.z)
		var a := sd.dot(sd)
		var b := 2.0 * so.dot(sd)
		var c := so.dot(so) - 1.0
		var disc := b * b - 4.0 * a * c
		if disc < 0.0:
			return {}
		var sq := sqrt(disc)
		t_enter = (-b - sq) / (2.0 * a)
		t_exit = (-b + sq) / (2.0 * a)
		var hp := lo + ld * t_exit
		n = Vector3(hp.x / (p.h.x * p.h.x), hp.y / (p.h.y * p.h.y), hp.z / (p.h.z * p.h.z)).normalized()
	if t_exit < t_enter:
		return {}
	return {"t": t_exit, "n": p.basis * n}


func _shade(p: Prim, n_world: Vector3, n_local: Vector3, hit_local: Vector3) -> Color:
	var b := n_world.dot(_light)
	var tone := 0 if b < 0.35 else (1 if b < 0.68 else 2)
	if p.stripe > 0.0 and absf(n_local.y) > 0.5:
		if int(floor(hit_local.x / p.stripe + _track_phase)) % 2 != 0:
			tone = maxi(0, tone - 1)
	return Color(_mats[p.mat][tone])


## Seams between parts, then the 1 px silhouette outline.
func _finish(color: Array, depth: PackedFloat32Array, pid: PackedInt32Array, model: Array[Prim], w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var neigh := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for y in h:
		for x in w:
			var i := y * w + x
			if pid[i] < 0:
				for nb in neigh:
					var nx: int = x + nb.x
					var ny: int = y + nb.y
					if nx >= 0 and ny >= 0 and nx < w and ny < h and pid[ny * w + nx] >= 0:
						img.set_pixel(x, y, INK)
						break
				continue
			var c: Color = color[i]
			for nb in neigh:
				var nx: int = x + nb.x
				var ny: int = y + nb.y
				if nx < 0 or ny < 0 or nx >= w or ny >= h:
					continue
				var j := ny * w + nx
				if pid[j] >= 0 and pid[j] != pid[i] and depth[j] - depth[i] > SEAM_DEPTH:
					c = Color(_mats[model[pid[i]].mat][0]).darkened(0.35)
					break
			img.set_pixel(x, y, c)
	return img
