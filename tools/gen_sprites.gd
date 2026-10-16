extends SceneTree
## Dev tool (not a test). Renders the sprite sheets (soldier, zombie, Gatling Gun, Tank, Helicopter) from
## simple box/cylinder/ellipsoid models: rays through the fixed 2:1 projection, 3-tone shading from one
## world light (all 8 facings are lit consistently, no mirroring), 1 px outline. Deterministic.
## Run: godot --headless --path . --script tools/gen_sprites.gd [-- --units=tank,rifle_soldier]
## Writes assets/sprites/<unit>/<facing>.png (facing = e, se, s, sw, w, nw, n, ne), one sheet per facing.
## Model axes (object-local, in tiles): +x forward, +y left, +z up (1.0 = Z_PX_PER_UNIT px).

const SEAM_DEPTH := 0.08  # depth gap (ray units) that draws a dark seam between two parts
const INK := Color("12140f")
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
}

const BOX := 0
const CYL := 1  # vertical cylinder: half.x = radius, half.z = half height
const SPH := 2  # ellipsoid: half = radii

var _light := LIGHT.normalized()
var _track_phase: float = 0.0
var _kit: String = "rifle"  # soldier weapon: "rifle" or "rpg"
var _z_stride: float = 1.0  # zombie variants: stride multiplier
var _z_lean: float = 0.0  # zombie variants: extra forward lean (rad)


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
		{"dir": "rpg_soldier", "frame": Vector2i(124, 76), "origin": Vector2(62, 46), "frames": 10, "columns": 3, "ss": 3},
		{"dir": "howitzer", "frame": Vector2i(128, 104), "origin": Vector2(64, 62), "frames": 6, "columns": 3, "ss": 1},
		{"dir": "sandbag_wall", "frame": Vector2i(80, 64), "origin": Vector2(40, 42), "frames": 4, "columns": 2, "ss": 2},
		{"dir": "concrete_barrier", "frame": Vector2i(80, 64), "origin": Vector2(40, 42), "frames": 4, "columns": 2, "ss": 2},
		{"dir": "crate_stack", "frame": Vector2i(64, 56), "origin": Vector2(32, 40), "frames": 4, "columns": 2, "ss": 2},
		{"dir": "oil_drums", "frame": Vector2i(64, 56), "origin": Vector2(32, 40), "frames": 4, "columns": 2, "ss": 2},
		{"dir": "tank_trap", "frame": Vector2i(64, 56), "origin": Vector2(32, 40), "frames": 4, "columns": 2, "ss": 2},
		{"dir": "jeep", "frame": Vector2i(80, 60), "origin": Vector2(40, 42), "frames": 5, "columns": 3, "ss": 1},
		{"dir": "supply_truck", "frame": Vector2i(112, 76), "origin": Vector2(56, 52), "frames": 5, "columns": 3, "ss": 1},
		{"dir": "wrecked_car", "frame": Vector2i(80, 56), "origin": Vector2(40, 38), "frames": 1, "columns": 1, "ss": 1},
	]
	var only: PackedStringArray = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--units="):
			only = a.substr(8).split(",")
	for spec in specs:
		if only.is_empty() or spec["dir"] in only:
			_render_unit(spec)
	quit()


func _render_unit(spec: Dictionary) -> void:
	var unit: String = spec["dir"]
	var frame_size: Vector2i = spec["frame"]
	var frames: int = spec["frames"]
	var columns: int = spec["columns"]
	var rows := int(ceil(float(frames) / columns))
	DirAccess.make_dir_recursive_absolute("res://assets/sprites/%s" % unit)
	for f in 8:
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
	_z_stride = 1.0
	_z_lean = 0.0
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
		"brute":  # hulking, slow, bare-chested
			_z_stride = 0.75
			_z_lean = 0.05
			_zombie(m, frame)
			_remap(m, {"shirt": "zskin", "shirtd": "zdark", "pants": "bpants"})
			_scale(m, 1.3)
		"howitzer":
			_howitzer(m, frame)
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
	return m


const CHAR := {
	"hull": "hullc", "track": "trackc", "gun": "gunc", "glass": "gunc", "base": "basec", "ammo": "gunc",
	"heli": "helic", "rotor": "gunc", "sand": "sandc", "dirt": "dirtc",
	"wood": "woodc", "woodd": "woodc", "concrete": "concretec", "drum": "drumc", "canvas": "canvasc", "rust": "rustc",
	"steel": "steelc",
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
	return _launcher(list, b, u) if _kit == "rpg" else _rifle(list, b, u)


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
	var breech := Vector3(-0.02, 0, 0.30)
	var back := -0.1 if fire else 0.0  # the barrel slides back in the cradle when it fires
	var rb := breech + dirv * back
	# Split trails with spades, planted on the ground behind the gun.
	for side in [1, -1]:
		_bone(carriage, Vector3(-0.05, 0.08 * side, 0.1), Vector3(-0.78, 0.32 * side, 0.03), 0.028, 0.03, "steel")
		carriage.append(Prim.new(BOX, Vector3(-0.8, 0.33 * side, 0.03), Vector3(0.05, 0.05, 0.03), "steel"))
	carriage.append(Prim.new(BOX, Vector3(0.0, 0, 0.17), Vector3(0.16, 0.2, 0.06), "hull"))  # axle block
	carriage.append(Prim.new(BOX, Vector3(0.1, 0, 0.27), Vector3(0.02, 0.2, 0.15), "steel"))  # gun shield
	carriage.append(Prim.new(BOX, Vector3(-0.02, 0, 0.27), Vector3(0.07, 0.05, 0.08), "hull"))  # cradle
	carriage.append(Prim.new(BOX, Vector3(-0.22, 0.16, 0.2), Vector3(0.05, 0.03, 0.05), "gun"))  # seat post
	for side in [1, -1]:
		wheels.append(Prim.new(SPH, Vector3(0.0, 0.25 * side, 0.115), Vector3(0.115, 0.03, 0.115), "track"))
		wheels.append(Prim.new(SPH, Vector3(0.0, 0.25 * side, 0.115), Vector3(0.05, 0.036, 0.05), "steel"))
	# Barrel with a bore sleeve, thick breech and a muzzle brake.
	_bone(barrel, rb - dirv * 0.12, rb + dirv * 0.05, 0.05, 0.05, "gun")
	_bone(barrel, rb + dirv * 0.05, rb + dirv * 0.55, 0.036, 0.036, "steel")
	_bone(barrel, rb + dirv * 0.55, rb + dirv * 0.85, 0.028, 0.028, "steel")
	_bone(barrel, rb + dirv * 0.85, rb + dirv * 0.94, 0.045, 0.045, "gun")
	barrel.append(Prim.new(BOX, Vector3(0.12, 0.17, 0.13), Vector3(0.05, 0.03, 0.03), "brass"))  # shell on the rack
	var fx: Array[Prim] = []
	if fire:
		var muzzle := rb + dirv * 0.97
		_blob(fx, muzzle, 0.1, "flash")
		_blob(fx, muzzle + dirv * 0.1, 0.06, "fire")
		_blob(fx, muzzle + Vector3(0, 0, 0.1), 0.06, "smoke")
	match d:
		1:
			_blob(fx, Vector3(0.0, 0, 0.3), 0.3, "flash")
		2:
			_scorch(carriage)
			_scorch(wheels)
			_xform_about(barrel, breech, Basis(Vector3(1, 0, 0), 0.5) * _ry(0.5), Vector3(0, 0.02, 0.26))
			_scorch(barrel)
			_blob(fx, Vector3(0.0, 0, 0.3), 0.18, "fire")
		3:
			_scorch(carriage)
			_scorch(wheels)
			_xform_about(barrel, breech, Basis(Vector3(1, 0, 0), 1.1) * _ry(0.9), Vector3(0.1, 0.24, -0.08))
			_scorch(barrel)
			_blob(fx, Vector3(0.0, 0, 0.24), 0.12, "fire")
			_blob(fx, Vector3(0.0, 0, 0.42), 0.09, "smoke")
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
			_blob(fx, Vector3(0.0, 0, 0.2), 0.07, "fire")
			_blob(fx, Vector3(0.0, 0, 0.36), 0.08, "smoke")
	m.append_array(carriage)
	m.append_array(wheels)
	m.append_array(barrel)
	m.append_array(fx)


## Sandbag wall along local y, three courses high. Frames 0 intact, 1-3 progressively blown apart.
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
	m.append_array(ground)
	m.append_array(bags)
	m.append_array(fx)


## Jersey barrier made of three segments along local y. Frames 0 intact, 1 cracked and leaning, 2 toppled, 3 rubble.
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
	car.append(Prim.new(BOX, Vector3(0, 0, 0.14), Vector3(0.4, 0.17, 0.06), "rust"))
	car.append(Prim.new(BOX, Vector3(-0.04, 0, 0.27), Vector3(0.2, 0.15, 0.065), "rust"))  # cabin
	car.append(Prim.new(BOX, Vector3(0.26, 0, 0.21), Vector3(0.13, 0.16, 0.03), "rust"))  # bonnet
	car.append(Prim.new(BOX, Vector3(-0.04, 0, 0.345), Vector3(0.17, 0.12, 0.012), "gun"))  # roof
	car.append(Prim.new(BOX, Vector3(0.065, 0, 0.28), Vector3(0.01, 0.12, 0.045), "gun"))  # empty windscreen
	car.append(Prim.new(BOX, Vector3(-0.04, 0.152, 0.28), Vector3(0.13, 0.006, 0.04), "gun"))
	car.append(Prim.new(BOX, Vector3(-0.04, -0.152, 0.28), Vector3(0.13, 0.006, 0.04), "gun"))
	for x in [0.25, -0.25]:
		for side in [1, -1]:
			if x < 0 and side < 0:
				continue  # that wheel is gone: the car sits lower on its axle
			wheels.append(Prim.new(SPH, Vector3(x, 0.18 * side, 0.085), Vector3(0.085, 0.035, 0.085), "track"))
	_scorch(wheels)
	_xform_about(car, Vector3(0, 0, 0), Basis(Vector3(1, 0, 0), -0.1), Vector3(0, -0.04, 0.0))
	m.append_array(car)
	m.append_array(wheels)
	_blob(m, Vector3(0.0, 0, 0.5), 0.06, "smoke")
	_blob(m, Vector3(0.05, 0.02, 0.62), 0.045, "smoke")


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
	for y in h:
		for x in w:
			var i := y * w + x
			pid[i] = -1
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
					for pi in model.size():
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
	return Color(MATS[p.mat][tone])


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
					c = Color(MATS[model[pid[i]].mat][0]).darkened(0.35)
					break
			img.set_pixel(x, y, c)
	return img
