extends RefCounted
## Theme pack: military base (hangars, towers, sheds, perimeter walls and gates, camp props). Loaded by
## tools/gen_sprites.gd, see docs/specs/art-pack-2.md. Contract: MATS (prefixed `b_`), specs(), build().
## Conventions: models are built at authoring scale (1 unit = 32 px) and enlarged by the spec's `k`. Only the +x face
## and, depending on the facing, the +y face (se) or the -y face (sw) are seen, so long buildings carry their details
## on both long faces and the door or front on +x.

const Base = preload("res://tools/gen_sprites.gd")
const Prim = Base.Prim

const MATS := {
	"b_olive": ["2f3a26", "46543a", "607250"],
	"b_oliveh": ["444c34", "5f6a48", "7e8a60"],
	"b_tan": ["6e6246", "958762", "b8a97f"],
	"b_trim": ["6a6a62", "8c8c84", "aeaea6"],
	"b_roof": ["32403a", "4b5c54", "697e74"],
	"b_gal": ["5a646a", "7e8a92", "a4b0b8"],
	"b_gald": ["404850", "5a646c", "78848c"],
	"b_yellow": ["8a6a0e", "d4a418", "f6d44c"],
	"b_black": ["0c0c0c", "1a1a1c", "2a2a2e"],
	"b_hesco": ["76694a", "9a8e66", "bcb084"],
	"b_mesh": ["343c3e", "546062", "86989a"],
	"b_wire": ["54544f", "8a8a84", "c0c0ba"],
	"b_brickd": ["3a1812", "50241c", "683628"],
	"b_camo1": ["2a361f", "3e502d", "566c3e"],
	"b_camo2": ["4a4226", "675a36", "86784c"],
	"b_camo3": ["24281f", "353b2f", "485142"],
	"b_tarp": ["2a382a", "3f5339", "567250"],
	"b_wrap": ["86909a", "b2bec8", "dce6ee"],
	"b_paper": ["a29a74", "d2caa4", "f0e8c8"],
	"b_orange": ["84360e", "c4561a", "f0843a"],
	"b_drumy": ["88680e", "c89818", "f0cc40"],
	"b_drumr": ["661410", "a02a1e", "d0483a"],
	"b_drumg": ["28382e", "3a5044", "506c5c"],
	"b_tentw": ["777b66", "a0a48c", "c6cab2"],
	"b_glassd": ["12242c", "1d4150", "2d6074"],
	"b_cable": ["131315", "232327", "38383e"],
	"b_sack": ["6a5c3c", "8b7c54", "ae9f72"],
	"b_pad": ["2c3034", "3c4248", "4e565e"],
}


static func specs() -> Array:
	return [
		{"dir": "base_hangar", "name": "Aircraft Hangar", "cat": "base", "auto": true, "k": 1.15, "frames": 1, "columns": 1, "ss": 1, "facings": ["se", "sw"]},
		{"dir": "base_control_tower", "name": "Control Tower", "cat": "base", "auto": true, "k": 1.4, "frames": 1, "columns": 1, "ss": 1, "facings": ["se"], "glow": [Vector3(0, 0, 1.22), 70.0, Color(1.0, 0.9, 0.55)]},
		{"dir": "base_mess_hall", "name": "Mess Hall", "cat": "base", "auto": true, "k": 1.3, "frames": 1, "columns": 1, "ss": 1, "facings": ["se", "sw"], "foot": Vector2i(3, 2)},
		{"dir": "base_armoury", "name": "Armoury", "cat": "base", "auto": true, "k": 1.5, "frames": 1, "columns": 1, "ss": 1, "facings": ["se"], "foot": Vector2i(2, 2)},
		{"dir": "base_motor_pool", "name": "Motor Pool Shed", "cat": "base", "auto": true, "k": 1.2, "frames": 1, "columns": 1, "ss": 1, "facings": ["se", "sw"], "foot": Vector2i(3, 2)},
		{"dir": "base_comms_center", "name": "Comms Centre", "cat": "base", "auto": true, "k": 1.4, "frames": 1, "columns": 1, "ss": 1, "facings": ["se"], "foot": Vector2i(2, 2)},
		{"dir": "base_medical_bay", "name": "Medical Bay", "cat": "base", "auto": true, "k": 1.3, "frames": 1, "columns": 1, "ss": 1, "facings": ["se", "sw"], "foot": Vector2i(3, 2)},
		{"dir": "base_guard_shack", "name": "Guard Shack", "cat": "base", "auto": true, "k": 1.7, "frames": 1, "columns": 1, "ss": 2, "facings": ["se"], "foot": Vector2i(1, 1), "glow": [Vector3(0.0, 0, 0.5), 44.0, Color(1.0, 0.88, 0.5)]},
		{"dir": "base_hq_building", "name": "Command Building", "cat": "base", "auto": true, "k": 1.25, "frames": 1, "columns": 1, "ss": 1, "facings": ["se"], "foot": Vector2i(3, 2)},
		{"dir": "base_workshop", "name": "Repair Workshop", "cat": "base", "auto": true, "k": 1.3, "frames": 1, "columns": 1, "ss": 1, "facings": ["se"]},
		{"dir": "base_generator_shed", "name": "Generator Shed", "cat": "base", "auto": true, "k": 1.6, "frames": 1, "columns": 1, "ss": 2, "facings": ["se"], "foot": Vector2i(2, 1), "glow": [Vector3(0.3, 0, 0.2), 52.0, Color(1.0, 0.85, 0.45)]},
		{"dir": "base_hesco_barrier", "name": "HESCO Barrier", "cat": "base", "auto": true, "k": 1.7, "frames": 1, "columns": 1, "ss": 2, "facings": ["se", "sw"], "foot": Vector2i(2, 1)},
		{"dir": "base_blast_wall_corner", "name": "Blast Wall Corner", "cat": "base", "auto": true, "k": 1.5, "frames": 1, "columns": 1, "ss": 2, "facings": ["se"]},
		{"dir": "base_sliding_gate", "name": "Sliding Gate", "cat": "base", "auto": true, "k": 1.6, "frames": 1, "columns": 1, "ss": 2, "facings": ["se", "sw"]},
		{"dir": "base_razor_wire_fence", "name": "Razor Wire Fence", "cat": "base", "auto": true, "k": 1.7, "frames": 1, "columns": 1, "ss": 2, "facings": ["se", "sw"]},
		{"dir": "base_sandbag_corner", "name": "Sandbag Bastion", "cat": "base", "auto": true, "k": 1.5, "frames": 1, "columns": 1, "ss": 2, "facings": ["se"], "foot": Vector2i(2, 2)},
		{"dir": "base_brick_wall", "name": "Brick Perimeter Wall", "cat": "base", "auto": true, "k": 1.7, "frames": 1, "columns": 1, "ss": 2, "facings": ["se", "sw"]},
		{"dir": "base_concrete_wall_tall", "name": "Tall Concrete Wall", "cat": "base", "auto": true, "k": 1.7, "frames": 1, "columns": 1, "ss": 2, "facings": ["se", "sw"]},
		{"dir": "base_wall_tower", "name": "Wall Tower", "cat": "base", "auto": true, "k": 1.5, "frames": 1, "columns": 1, "ss": 1, "facings": ["se"]},
		{"dir": "base_steel_gate_post", "name": "Steel Gate Post", "cat": "base", "auto": true, "k": 1.7, "frames": 1, "columns": 1, "ss": 2, "facings": ["se"]},
		{"dir": "base_camo_net", "name": "Camouflage Net", "cat": "base", "auto": true, "k": 1.4, "frames": 1, "columns": 1, "ss": 2, "facings": ["se"], "foot": Vector2i(2, 2)},
		{"dir": "base_antenna_array", "name": "Antenna Array", "cat": "base", "auto": true, "k": 1.7, "frames": 1, "columns": 1, "ss": 2, "facings": ["se"], "foot": Vector2i(1, 1)},
		{"dir": "base_water_tank", "name": "Elevated Water Tank", "cat": "base", "auto": true, "k": 1.7, "frames": 1, "columns": 1, "ss": 2, "facings": ["se"], "foot": Vector2i(1, 1)},
		{"dir": "base_fuel_pump", "name": "Fuel Bowser", "cat": "base", "auto": true, "k": 1.6, "frames": 1, "columns": 1, "ss": 2, "facings": ["se", "sw"], "foot": Vector2i(3, 1)},
		{"dir": "base_latrine", "name": "Latrine Row", "cat": "base", "auto": true, "k": 1.6, "frames": 1, "columns": 1, "ss": 2, "facings": ["se", "sw"], "foot": Vector2i(2, 1)},
		{"dir": "base_supply_stack", "name": "Supply Stack", "cat": "base", "auto": true, "k": 1.9, "frames": 1, "columns": 1, "ss": 2, "facings": ["se"]},
		{"dir": "base_ammo_pile", "name": "Ammo Pile", "cat": "base", "auto": true, "k": 1.8, "frames": 1, "columns": 1, "ss": 2, "facings": ["se"]},
		{"dir": "base_weapon_rack", "name": "Weapon Rack", "cat": "base", "auto": true, "k": 1.2, "frames": 1, "columns": 1, "ss": 2, "facings": ["se", "sw"]},
		{"dir": "base_map_table", "name": "Map Table", "cat": "base", "auto": true, "k": 1.4, "frames": 1, "columns": 1, "ss": 2, "facings": ["se"], "foot": Vector2i(2, 1)},
		{"dir": "base_warning_sign", "name": "Hazard Warning Sign", "cat": "base", "auto": true, "k": 1.1, "frames": 1, "columns": 1, "ss": 2, "facings": ["se", "sw"]},
		{"dir": "base_hazard_drums", "name": "Hazard Drums", "cat": "base", "auto": true, "k": 1.6, "frames": 1, "columns": 1, "ss": 2, "facings": ["se"]},
		{"dir": "base_cable_reel", "name": "Cable Reel", "cat": "base", "auto": true, "k": 1.7, "frames": 1, "columns": 1, "ss": 2, "facings": ["se"], "foot": Vector2i(2, 1)},
		{"dir": "base_field_kitchen", "name": "Field Kitchen", "cat": "base", "auto": true, "k": 1.2, "frames": 1, "columns": 1, "ss": 2, "facings": ["se", "sw"], "foot": Vector2i(2, 1)},
		{"dir": "base_medical_tent", "name": "Medical Tent", "cat": "base", "auto": true, "k": 1.4, "frames": 1, "columns": 1, "ss": 1, "facings": ["se", "sw"], "foot": Vector2i(3, 2)},
		{"dir": "base_command_tent", "name": "Command Tent", "cat": "base", "auto": true, "k": 1.3, "frames": 1, "columns": 1, "ss": 1, "facings": ["se"], "foot": Vector2i(3, 3)},
		{"dir": "base_shower_tent", "name": "Shower Tent", "cat": "base", "auto": true, "k": 1.4, "frames": 1, "columns": 1, "ss": 2, "facings": ["se"], "foot": Vector2i(2, 1)},
	]


static func build(_host: Object, m: Array[Prim], unit: String, _frame: int) -> bool:
	match unit:
		"base_hangar":
			_hangar(m)
		"base_control_tower":
			_control_tower(m)
		"base_mess_hall":
			_mess_hall(m)
		"base_armoury":
			_armoury(m)
		"base_motor_pool":
			_motor_pool(m)
		"base_comms_center":
			_comms_center(m)
		"base_medical_bay":
			_medical_bay(m)
		"base_guard_shack":
			_guard_shack(m)
		"base_hq_building":
			_hq_building(m)
		"base_workshop":
			_workshop(m)
		"base_generator_shed":
			_generator_shed(m)
		"base_hesco_barrier":
			_hesco(m)
		"base_blast_wall_corner":
			_blast_corner(m)
		"base_sliding_gate":
			_sliding_gate(m)
		"base_razor_wire_fence":
			_razor_fence(m)
		"base_sandbag_corner":
			_sandbag_corner(m)
		"base_brick_wall":
			_brick_wall(m)
		"base_concrete_wall_tall":
			_tall_wall(m)
		"base_wall_tower":
			_wall_tower(m)
		"base_steel_gate_post":
			_gate_post(m)
		"base_camo_net":
			_camo_net(m)
		"base_antenna_array":
			_antenna_array(m)
		"base_water_tank":
			_water_tank(m)
		"base_fuel_pump":
			_fuel_pump(m)
		"base_latrine":
			_latrine(m)
		"base_supply_stack":
			_supply_stack(m)
		"base_ammo_pile":
			_ammo_pile(m)
		"base_weapon_rack":
			_weapon_rack(m)
		"base_map_table":
			_map_table(m)
		"base_warning_sign":
			_warning_sign(m)
		"base_hazard_drums":
			_hazard_drums(m)
		"base_cable_reel":
			_cable_reel(m)
		"base_field_kitchen":
			_field_kitchen(m)
		"base_medical_tent":
			_medical_tent(m)
		"base_command_tent":
			_command_tent(m)
		"base_shower_tent":
			_shower_tent(m)
		_:
			return false
	return true


# ---------------------------------------------------------------- helpers

static func _b(m: Array[Prim], c: Vector3, h: Vector3, mat: String, yaw: float = 0.0) -> void:
	Base._bx(m, c, h, mat, yaw)


static func _c(m: Array[Prim], c: Vector3, r: float, hz: float, mat: String) -> void:
	Base._cy(m, c, r, hz, mat)


static func _s(m: Array[Prim], c: Vector3, r: Vector3, mat: String) -> void:
	Base._sp(m, c, r, mat)


## Thin strut from p0 to p1 with a square cross-section of half thickness t.
static func _l(m: Array[Prim], p0: Vector3, p1: Vector3, t: float, mat: String) -> void:
	Base._bone(m, p0, p1, t, t, mat)


## Cylinder lying along x (half length hl).
static func _cx(m: Array[Prim], c: Vector3, r: float, hl: float, mat: String) -> void:
	var p := Prim.new(Base.CYL, c, Vector3(r, 0, hl), mat)
	p.basis = Basis(Vector3(0, 1, 0), PI * 0.5)
	m.append(p)


## Wheel or drum lying along y (half width hl). The renderer's cylinders only work with +z toward the camera, so this is
## an octagon built from five boxes turned about the y axis.
static func _cyy(m: Array[Prim], c: Vector3, r: float, hl: float, mat: String) -> void:
	for k in 4:
		_ry(m, c, Vector3(r * 0.93, hl, r * 0.39), mat, float(k) * PI * 0.25)
	_b(m, c, Vector3(r * 0.7, hl, r * 0.7), mat)


## Box turned about the x axis (a roof slope that falls toward +y when a < 0).
static func _rx(m: Array[Prim], c: Vector3, h: Vector3, mat: String, a: float) -> void:
	var p := Prim.new(Base.BOX, c, h, mat)
	p.basis = Basis(Vector3(1, 0, 0), a)
	m.append(p)


## Box turned about the y axis (falls toward +x when a > 0).
static func _ry(m: Array[Prim], c: Vector3, h: Vector3, mat: String, a: float) -> void:
	var p := Prim.new(Base.BOX, c, h, mat)
	p.basis = Basis(Vector3(0, 1, 0), a)
	m.append(p)


## Window with a light frame on both long faces (the wall plane is |y| = y).
static func _wy(m: Array[Prim], x: float, y: float, z: float, hw: float, hh: float, glass: String = "glass") -> void:
	for s: float in [1.0, -1.0]:
		_b(m, Vector3(x, s * (y + 0.003), z), Vector3(hw + 0.012, 0.004, hh + 0.012), "b_trim")
		_b(m, Vector3(x, s * (y + 0.007), z), Vector3(hw, 0.004, hh), glass)


## Window with a light frame on the +x face (wall plane x).
static func _wx(m: Array[Prim], x: float, y: float, z: float, hw: float, hh: float, glass: String = "glass") -> void:
	_b(m, Vector3(x + 0.003, y, z), Vector3(0.004, hw + 0.012, hh + 0.012), "b_trim")
	_b(m, Vector3(x + 0.007, y, z), Vector3(0.004, hw, hh), glass)


## Steps climbing to the +x wall at x0 (n treads, each `rise` high and `run` deep).
static func _steps_x(m: Array[Prim], x0: float, y: float, hw: float, n: int, rise: float, run: float, mat: String) -> void:
	for i in n:
		var h: float = rise * float(n - i)
		_b(m, Vector3(x0 + run * (float(i) + 0.5), y, h * 0.5), Vector3(run * 0.5, hw, h * 0.5), mat)


## Gable roof over a box (half extents hx, hy, eaves at z), ridge along x, gable end on +x. `ribs` (a material or "")
## adds corrugation ribs down the slopes, `ends` false leaves the +x end open (a shed).
static func _gabx(m: Array[Prim], c: Vector3, hx: float, hy: float, z: float, rise: float, mat: String, wall_mat: String, ribs: String = "", ends: bool = true, over: float = 0.07) -> void:
	var span: float = hy + over
	var th: float = atan2(rise, span)
	var half_len: float = span / cos(th) * 0.5
	for s: float in [1.0, -1.0]:
		_rx(m, Vector3(c.x, c.y + s * span * 0.5, z + rise * 0.5 + 0.015), Vector3(hx + over, half_len, 0.02), mat, -s * th)
		if ribs != "":
			var n: int = int((hx + over) * 2.0 / 0.11)
			for i in n + 1:
				var x: float = c.x - (hx + over) + 2.0 * (hx + over) * float(i) / float(n)
				_rx(m, Vector3(x, c.y + s * span * 0.5, z + rise * 0.5 + 0.04), Vector3(0.006, half_len, 0.006), ribs, -s * th)
	_b(m, Vector3(c.x, c.y, z + rise + 0.03), Vector3(hx + over, 0.025, 0.014), "b_gald")
	if ends:
		for k in 4:
			var f: float = 1.0 - (float(k) + 0.5) / 4.0
			_b(m, Vector3(c.x + hx - 0.01, c.y, z + rise * (float(k) + 0.5) / 4.0), Vector3(0.02, hy * f, rise / 8.0 + 0.004), wall_mat)


## Elliptical vault (hangar roof) extruded along x: half width a, rise b above z0, segment thickness th.
static func _arch(m: Array[Prim], x: float, hl: float, a: float, b: float, z0: float, th: float, mat: String, n: int = 10) -> void:
	for i in n:
		var t0: float = -PI * 0.5 + PI * float(i) / float(n)
		var t1: float = -PI * 0.5 + PI * float(i + 1) / float(n)
		var y0: float = a * sin(t0)
		var y1: float = a * sin(t1)
		var q0: float = z0 + b * cos(t0)
		var q1: float = z0 + b * cos(t1)
		var ang: float = atan2(q1 - q0, y1 - y0)
		var len: float = Vector2(y1 - y0, q1 - q0).length()
		var nrm := Vector2(-sin(ang), cos(ang))
		_rx(m, Vector3(x, (y0 + y1) * 0.5 + nrm.x * th, (q0 + q1) * 0.5 + nrm.y * th), Vector3(hl, len * 0.5 + 0.012, th), mat, ang)


## Lattice mast: four tapering legs, rings and alternating diagonals.
static func _lattice(m: Array[Prim], x: float, y: float, z0: float, w: float, h: float, levels: int, mat: String, taper: float = 0.55) -> void:
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			_l(m, Vector3(x + sx * w, y + sy * w, z0), Vector3(x + sx * w * taper, y + sy * w * taper, z0 + h), 0.011, mat)
	var cs: Array[Vector2] = [Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, -1)]
	for i in levels:
		var za: float = z0 + h * float(i) / float(levels)
		var zb: float = z0 + h * float(i + 1) / float(levels)
		var wa: float = w * (1.0 - (1.0 - taper) * float(i) / float(levels))
		var wb: float = w * (1.0 - (1.0 - taper) * float(i + 1) / float(levels))
		for k in 4:
			var c0: Vector2 = cs[k]
			var c1: Vector2 = cs[(k + 1) % 4]
			var a0 := Vector3(x + c0.x * wa, y + c0.y * wa, za)
			var a1 := Vector3(x + c1.x * wa, y + c1.y * wa, za)
			var b0 := Vector3(x + c0.x * wb, y + c0.y * wb, zb)
			var b1 := Vector3(x + c1.x * wb, y + c1.y * wb, zb)
			_l(m, a0, a1, 0.008, mat)
			if i % 2 == 0:
				_l(m, a0, b1, 0.007, mat)
			else:
				_l(m, a1, b0, 0.007, mat)


## Satellite dish: pedestal, flattened bowl tilted by `pitch` (toward +x) and turned by `yaw`, feed horn.
static func _dish(m: Array[Prim], c: Vector3, r: float, pitch: float, yaw: float) -> void:
	_l(m, c - Vector3(0, 0, r * 0.9), c, 0.02, "steel")
	m.append(Prim.new(Base.SPH, c, Vector3(r, r, r * 0.3), "whitep", yaw, 0.0, pitch))
	m.append(Prim.new(Base.SPH, c + Basis(Vector3(0, 0, 1), yaw) * Basis(Vector3(0, 1, 0), pitch) * Vector3(0, 0, r * 0.12), Vector3(r * 0.8, r * 0.8, r * 0.22), "concretel", yaw, 0.0, pitch))
	var n := Basis(Vector3(0, 0, 1), yaw) * Basis(Vector3(0, 1, 0), pitch) * Vector3(0, 0, 1)
	_l(m, c + n * r * 0.2, c + n * r * 0.95, 0.012, "steel")


## Red cross on the +x face (wall plane x), centre (y, z), arm half length s.
static func _cross_x(m: Array[Prim], x: float, y: float, z: float, s: float) -> void:
	_b(m, Vector3(x + 0.01, y, z), Vector3(0.004, s * 1.25, s * 1.25), "whitep")
	_b(m, Vector3(x + 0.016, y, z), Vector3(0.004, s, s * 0.32), "red")
	_b(m, Vector3(x + 0.016, y, z), Vector3(0.004, s * 0.32, s), "red")


## Red cross on both long faces (wall plane |y|), centre (x, z).
static func _cross_y(m: Array[Prim], x: float, y: float, z: float, s: float) -> void:
	for sg: float in [1.0, -1.0]:
		_b(m, Vector3(x, sg * (y + 0.01), z), Vector3(s * 1.25, 0.004, s * 1.25), "whitep")
		_b(m, Vector3(x, sg * (y + 0.016), z), Vector3(s, 0.004, s * 0.32), "red")
		_b(m, Vector3(x, sg * (y + 0.016), z), Vector3(s * 0.32, 0.004, s), "red")


# ---------------------------------------------------------------- buildings

## Aircraft hangar: vaulted corrugated roof on low walls, wide sliding door in the +x end, skylight strip.
static func _hangar(m: Array[Prim]) -> void:
	var hx := 1.45
	var hy := 1.0
	var z0 := 0.3
	var rise := 0.55
	_b(m, Vector3(0, 0, 0.025), Vector3(hx + 0.06, hy + 0.07, 0.025), "concrete")
	for s: float in [1.0, -1.0]:
		_b(m, Vector3(0, s * (hy - 0.02), 0.17), Vector3(hx, 0.03, 0.15), "b_oliveh")
		for i in 7:  # buttresses and high windows
			var x: float = -1.2 + 0.4 * float(i)
			_b(m, Vector3(x + 0.2, s * (hy + 0.012), 0.17), Vector3(0.02, 0.012, 0.15), "b_trim")
	for i in 6:
		_wy(m, -1.0 + 0.4 * float(i), hy + 0.01, 0.17, 0.07, 0.045, "b_glassd")
	_b(m, Vector3(hx - 0.02, 0, z0 * 0.5 + 0.02), Vector3(0.025, hy, z0 * 0.5), "b_oliveh")
	_arch(m, 0.0, hx + 0.04, hy, rise, z0, 0.025, "b_gal")
	for i in 8:
		_arch(m, -hx + 0.12 + float(i) * (2.0 * hx - 0.24) / 7.0, 0.022, hy + 0.012, rise + 0.012, z0, 0.02, "b_gald")
	_b(m, Vector3(0, 0, z0 + rise + 0.03), Vector3(1.1, 0.07, 0.008), "b_glassd")  # skylight
	for i in 9:  # tympanum under the vault on the +x end
		var t: float = (float(i) + 0.5) / 9.0
		var w: float = hy * sqrt(1.0 - t * t)
		_b(m, Vector3(hx - 0.02, 0, z0 + rise * t), Vector3(0.025, w, rise / 18.0 + 0.004), "b_trim" if i % 2 == 0 else "b_oliveh")
	_b(m, Vector3(hx + 0.012, 0, 0.34), Vector3(0.012, 0.56, 0.31), "b_black")  # door opening
	for s: float in [1.0, -1.0]:
		_b(m, Vector3(hx + 0.03, s * 0.575, 0.34), Vector3(0.016, 0.022, 0.33), "b_trim")
		_b(m, Vector3(hx + 0.035, s * 0.73, 0.33), Vector3(0.014, 0.16, 0.29), "b_gal")
		for i in 4:
			_b(m, Vector3(hx + 0.05, s * (0.62 + 0.08 * float(i)), 0.33), Vector3(0.006, 0.006, 0.28), "b_gald")
		_c(m, Vector3(hx + 0.17, s * 0.72, 0.07), 0.035, 0.07, "b_yellow")
	_b(m, Vector3(hx + 0.03, 0, 0.675), Vector3(0.016, 0.6, 0.022), "b_trim")
	_b(m, Vector3(hx + 0.05, 0, 0.7), Vector3(0.012, 0.9, 0.012), "gun")
	_b(m, Vector3(hx + 0.03, 0, 0.705), Vector3(0.01, 0.5, 0.025), "b_yellow")  # warning band over the door
	for i in 6:
		_b(m, Vector3(hx + 0.04, -0.46 + 0.19 * float(i), 0.705), Vector3(0.008, 0.045, 0.026), "b_black")


## Airfield control tower: concrete shaft with stair annex, glazed cab on a balcony, radar on the roof.
static func _control_tower(m: Array[Prim]) -> void:
	_b(m, Vector3(0, 0, 0.03), Vector3(0.42, 0.36, 0.03), "concrete")
	_b(m, Vector3(0, 0, 0.56), Vector3(0.13, 0.13, 0.5), "concrete")
	for z in [0.2, 0.45, 0.7, 0.95]:
		_b(m, Vector3(0, 0, z), Vector3(0.138, 0.138, 0.01), "concretel")
	for z in [0.34, 0.6, 0.85]:  # window slits
		_b(m, Vector3(0.135, 0, z), Vector3(0.004, 0.035, 0.02), "gun")
		for s: float in [1.0, -1.0]:
			_b(m, Vector3(0, s * 0.135, z), Vector3(0.035, 0.004, 0.02), "gun")
	_b(m, Vector3(0.24, 0.0, 0.16), Vector3(0.14, 0.2, 0.13), "concrete")  # stair annex
	_b(m, Vector3(0.24, 0.0, 0.3), Vector3(0.15, 0.21, 0.02), "concretel")
	_b(m, Vector3(0.385, 0.0, 0.14), Vector3(0.008, 0.07, 0.1), "steel")
	_b(m, Vector3(0.39, 0.0, 0.14), Vector3(0.006, 0.06, 0.09), "gun")
	for s: float in [1.0, -1.0]:
		_b(m, Vector3(0.24, s * 0.205, 0.17), Vector3(0.05, 0.005, 0.04), "glass")
	_b(m, Vector3(0, 0, 1.075), Vector3(0.4, 0.4, 0.022), "concretel")  # balcony
	for s: float in [1.0, -1.0]:  # rails
		_b(m, Vector3(0.39, s * 0.2, 1.13), Vector3(0.008, 0.2, 0.008), "steel")
		_b(m, Vector3(0.39, s * 0.2, 1.11), Vector3(0.008, 0.2, 0.006), "steel")
		_b(m, Vector3(s * 0.2, 0.39, 1.13), Vector3(0.2, 0.008, 0.008), "steel")
		_b(m, Vector3(s * 0.2, 0.39, 1.11), Vector3(0.2, 0.008, 0.006), "steel")
		_b(m, Vector3(s * 0.2, -0.39, 1.13), Vector3(0.2, 0.008, 0.008), "steel")
		_b(m, Vector3(s * 0.2, -0.39, 1.11), Vector3(0.2, 0.008, 0.006), "steel")
	_b(m, Vector3(0, 0, 1.22), Vector3(0.3, 0.3, 0.14), "glass")  # glazed cab
	for sx: float in [1.0, -1.0]:
		for sy: float in [1.0, -1.0]:
			_b(m, Vector3(0.3 * sx, 0.3 * sy, 1.22), Vector3(0.022, 0.022, 0.145), "concrete")
	for i in 3:
		var o: float = -0.15 + 0.15 * float(i)
		_b(m, Vector3(0.302, o, 1.22), Vector3(0.006, 0.01, 0.14), "steel")
		for s: float in [1.0, -1.0]:
			_b(m, Vector3(o, s * 0.302, 1.22), Vector3(0.01, 0.006, 0.14), "steel")
	_b(m, Vector3(0, 0, 1.24), Vector3(0.31, 0.31, 0.008), "steel")  # transom
	_b(m, Vector3(0, 0, 1.385), Vector3(0.38, 0.38, 0.022), "concrete")  # overhanging roof
	_b(m, Vector3(0, 0, 1.417), Vector3(0.33, 0.33, 0.012), "concretel")
	_l(m, Vector3(-0.08, 0.0, 1.43), Vector3(-0.08, 0.0, 1.58), 0.016, "steel")
	_b(m, Vector3(-0.07, 0.0, 1.63), Vector3(0.02, 0.2, 0.03), "gun")  # radar bar
	_b(m, Vector3(-0.09, 0.0, 1.63), Vector3(0.012, 0.18, 0.05), "steel")
	_b(m, Vector3(-0.08, 0.0, 1.58), Vector3(0.03, 0.03, 0.03), "gun")
	_b(m, Vector3(0.0, 0.0, 1.7), Vector3(0.012, 0.012, 0.012), "red")
	_l(m, Vector3(0.25, 0.25, 1.43), Vector3(0.25, 0.25, 1.85), 0.008, "steel")  # whip
	_l(m, Vector3(-0.25, 0.22, 1.43), Vector3(-0.25, 0.22, 1.78), 0.008, "steel")
	_b(m, Vector3(0.0, -0.3, 1.46), Vector3(0.08, 0.04, 0.03), "whitep")  # roof cabinet


## Mess hall: long low tan building, gable roof with a chimney and vent, serving hatches, steps and porch.
static func _mess_hall(m: Array[Prim]) -> void:
	var hx := 1.15
	var hy := 0.5
	_b(m, Vector3(0, 0, 0.03), Vector3(hx + 0.05, hy + 0.05, 0.03), "concrete")
	_b(m, Vector3(0, 0, 0.21), Vector3(hx, hy, 0.15), "b_tan")
	for s: float in [1.0, -1.0]:
		_b(m, Vector3(0, s * (hy + 0.004), 0.08), Vector3(hx, 0.006, 0.02), "b_trim")
		for i in 4:
			_wy(m, -0.95 + 0.36 * float(i) + (0.3 if i > 1 else 0.0), hy, 0.24, 0.07, 0.05)
		_b(m, Vector3(0.45, s * (hy + 0.004), 0.22), Vector3(0.14, 0.006, 0.045), "gun")  # serving hatch
		_rx(m, Vector3(0.45, s * (hy + 0.07), 0.31), Vector3(0.17, 0.07, 0.012), "wood", -s * 0.35)
		_b(m, Vector3(0.45, s * (hy + 0.025), 0.17), Vector3(0.15, 0.025, 0.012), "woodd")
	_gabx(m, Vector3(0, 0, 0), hx, hy, 0.36, 0.26, "b_roof", "b_tan", "b_olive")
	_b(m, Vector3(hx + 0.008, 0, 0.19), Vector3(0.008, 0.11, 0.13), "b_trim")  # door
	_b(m, Vector3(hx + 0.014, 0, 0.18), Vector3(0.006, 0.09, 0.115), "woodd")
	_wx(m, hx, 0.3, 0.24, 0.05, 0.045)
	_wx(m, hx, -0.3, 0.24, 0.05, 0.045)
	_steps_x(m, hx + 0.01, 0, 0.17, 3, 0.03, 0.08, "concrete")
	_b(m, Vector3(hx + 0.2, 0, 0.35), Vector3(0.2, 0.19, 0.012), "b_roof")  # porch roof
	for s: float in [1.0, -1.0]:
		_b(m, Vector3(hx + 0.37, s * 0.17, 0.2), Vector3(0.015, 0.015, 0.15), "woodd")
	_c(m, Vector3(-0.5, 0.0, 0.7), 0.045, 0.13, "steel")  # chimney
	_c(m, Vector3(-0.5, 0.0, 0.84), 0.06, 0.016, "gun")
	_c(m, Vector3(0.0, 0.0, 0.68), 0.04, 0.07, "steel")  # roof vents
	_b(m, Vector3(0.0, 0.0, 0.76), Vector3(0.07, 0.07, 0.012), "gun")
	_c(m, Vector3(-0.15, 0.0, 0.67), 0.03, 0.06, "steel")
	_b(m, Vector3(-hx - 0.08, 0.2, 0.3), Vector3(0.06, 0.1, 0.1), "b_gald")  # fuel / grease bin (rear, peeks out)
	_b(m, Vector3(-hx + 0.4, 0.0, 0.12), Vector3(0.008, 0.01, 0.1), "gun")


## Armoury: squat reinforced concrete block, steel door under a hazard band, barred slit windows, roof vents.
static func _armoury(m: Array[Prim]) -> void:
	var hx := 0.62
	var hy := 0.5
	_b(m, Vector3(0, 0, 0.03), Vector3(hx + 0.06, hy + 0.06, 0.03), "concrete")
	_b(m, Vector3(0, 0, 0.26), Vector3(hx, hy, 0.2), "concrete")
	for sx: float in [1.0, -1.0]:  # corner pilasters
		for sy: float in [1.0, -1.0]:
			_b(m, Vector3(sx * (hx - 0.01), sy * (hy - 0.01), 0.26), Vector3(0.045, 0.045, 0.205), "concretel")
	_b(m, Vector3(0, 0, 0.47), Vector3(hx + 0.04, hy + 0.04, 0.025), "concretel")  # roof slab with lip
	_b(m, Vector3(0, 0, 0.5), Vector3(hx - 0.01, hy - 0.01, 0.012), "concrete")
	for s: float in [1.0, -1.0]:
		for x in [-0.3, 0.3]:
			_b(m, Vector3(x, s * (hy + 0.005), 0.3), Vector3(0.1, 0.006, 0.05), "b_trim")
			_b(m, Vector3(x, s * (hy + 0.01), 0.3), Vector3(0.085, 0.004, 0.036), "gun")
			for i in 4:
				_b(m, Vector3(x - 0.06 + 0.04 * float(i), s * (hy + 0.016), 0.3), Vector3(0.005, 0.004, 0.038), "steel")
	_b(m, Vector3(hx + 0.006, 0, 0.2), Vector3(0.01, 0.17, 0.16), "b_trim")  # door frame
	_b(m, Vector3(hx + 0.014, 0, 0.2), Vector3(0.008, 0.14, 0.145), "steel")
	_b(m, Vector3(hx + 0.022, 0, 0.2), Vector3(0.005, 0.005, 0.145), "gun")
	for z in [0.14, 0.27]:
		_b(m, Vector3(hx + 0.024, 0, z), Vector3(0.004, 0.13, 0.008), "gun")
	_b(m, Vector3(hx + 0.026, 0.08, 0.2), Vector3(0.006, 0.014, 0.014), "gun")  # lock
	_b(m, Vector3(hx + 0.012, 0, 0.395), Vector3(0.012, 0.22, 0.03), "b_yellow")
	for i in 6:
		_b(m, Vector3(hx + 0.018, -0.18 + 0.07 * float(i), 0.395), Vector3(0.006, 0.02, 0.03), "b_black")
	_b(m, Vector3(hx + 0.03, 0.34, 0.33), Vector3(0.025, 0.04, 0.02), "lampglow")
	_wx(m, hx, -0.33, 0.28, 0.05, 0.05, "gun")
	_b(m, Vector3(0.2, 0.2, 0.55), Vector3(0.07, 0.07, 0.04), "steel")  # roof vents
	_b(m, Vector3(-0.2, -0.15, 0.54), Vector3(0.05, 0.05, 0.03), "steel")
	_c(m, Vector3(-0.3, 0.25, 0.58), 0.025, 0.08, "gun")
	for i in 4:  # sandbags by the door
		_b(m, Vector3(hx + 0.17, -0.3 + 0.12 * float(i), 0.05), Vector3(0.08, 0.06, 0.045), "sand", (Base._rnd(i, 9) - 0.5) * 0.3)
	_b(m, Vector3(hx + 0.17, 0.3, 0.05), Vector3(0.08, 0.06, 0.045), "sand")
	_b(m, Vector3(hx + 0.17, -0.24, 0.135), Vector3(0.08, 0.06, 0.04), "sand")


## Motor pool: roofed shed open on both long sides, three bays with yellow lines and partitions.
static func _motor_pool(m: Array[Prim]) -> void:
	var hx := 1.35
	var hy := 0.62
	_b(m, Vector3(0, 0, 0.015), Vector3(hx + 0.05, hy + 0.05, 0.015), "b_pad")
	for x in [-0.45, 0.45]:
		_b(m, Vector3(x, 0, 0.034), Vector3(0.012, hy, 0.004), "b_yellow")
	for s: float in [1.0, -1.0]:
		_b(m, Vector3(0, s * (hy - 0.02), 0.034), Vector3(hx, 0.012, 0.004), "b_yellow")
	for x in [-1.25, -0.45, 0.45, 1.25]:
		for s: float in [1.0, -1.0]:
			_b(m, Vector3(x, s * 0.58, 0.31), Vector3(0.026, 0.026, 0.3), "gun")
			_b(m, Vector3(x, s * 0.58, 0.04), Vector3(0.05, 0.05, 0.02), "concrete")
		_b(m, Vector3(x, 0, 0.58), Vector3(0.012, 0.6, 0.014), "steel")
	for x in [-0.45, 0.45]:  # bay partitions
		_b(m, Vector3(x, 0, 0.15), Vector3(0.025, 0.44, 0.12), "concrete")
		_b(m, Vector3(x, 0, 0.275), Vector3(0.035, 0.46, 0.012), "concretel")
	_gabx(m, Vector3(0, 0, 0), hx, hy - 0.01, 0.6, 0.17, "b_gal", "b_gald", "b_gald", false, 0.1)
	for i in 3:  # tyres, drums, a toolbox
		_c(m, Vector3(-1.18, 0.34, 0.05 + 0.09 * float(i)), 0.1, 0.045, "track")
	_c(m, Vector3(1.18, -0.3, 0.1), 0.07, 0.1, "drum")
	_c(m, Vector3(1.18, -0.16, 0.1), 0.07, 0.1, "b_drumy")
	_b(m, Vector3(0.0, -0.36, 0.1), Vector3(0.12, 0.05, 0.08), "red")
	_b(m, Vector3(0.0, -0.36, 0.185), Vector3(0.125, 0.052, 0.012), "gun")


## Comms centre: olive box with cable trunking, a lattice mast, two dishes, whip antennas and an AC unit.
static func _comms_center(m: Array[Prim]) -> void:
	var hx := 0.66
	var hy := 0.5
	_b(m, Vector3(0, 0, 0.03), Vector3(hx + 0.05, hy + 0.05, 0.03), "concrete")
	_b(m, Vector3(0, 0, 0.22), Vector3(hx, hy, 0.16), "b_olive")
	_b(m, Vector3(0, 0, 0.395), Vector3(hx + 0.04, hy + 0.04, 0.025), "concrete")
	_b(m, Vector3(0, 0, 0.425), Vector3(hx - 0.02, hy - 0.02, 0.012), "concretel")
	for s: float in [1.0, -1.0]:
		_wy(m, -0.3, hy, 0.25, 0.07, 0.05)
		_wy(m, 0.15, hy, 0.25, 0.07, 0.05)
		_b(m, Vector3(0, s * (hy + 0.012), 0.34), Vector3(hx - 0.1, 0.012, 0.014), "b_black")  # trunking
		_b(m, Vector3(-0.55, s * (hy + 0.012), 0.2), Vector3(0.014, 0.012, 0.14), "b_black")
	_b(m, Vector3(hx + 0.006, 0.0, 0.16), Vector3(0.01, 0.1, 0.1), "b_trim")
	_b(m, Vector3(hx + 0.012, 0.0, 0.155), Vector3(0.008, 0.085, 0.09), "gun")
	_steps_x(m, hx, 0, 0.12, 2, 0.03, 0.07, "concrete")
	_wx(m, hx, 0.32, 0.25, 0.05, 0.05)
	_b(m, Vector3(hx + 0.014, -0.28, 0.3), Vector3(0.014, 0.012, 0.18), "b_black")
	_b(m, Vector3(hx + 0.014, -0.28 + 0.06, 0.38), Vector3(0.014, 0.07, 0.012), "b_black")
	_lattice(m, -0.35, 0.0, 0.43, 0.07, 1.0, 5, "steel")
	_b(m, Vector3(-0.35, 0.0, 1.45), Vector3(0.015, 0.015, 0.015), "red")
	_dish(m, Vector3(0.28, -0.2, 0.66), 0.13, 0.55, 0.0)
	_dish(m, Vector3(0.1, 0.28, 0.6), 0.1, 0.4, 0.6)
	_b(m, Vector3(-0.05, -0.22, 0.47), Vector3(0.09, 0.07, 0.04), "b_gald")  # AC unit
	_c(m, Vector3(-0.05, -0.22, 0.512), 0.05, 0.006, "gun")
	for p in [Vector2(0.4, 0.3), Vector2(-0.5, 0.3), Vector2(-0.55, -0.28)]:
		_l(m, Vector3(p.x, p.y, 0.42), Vector3(p.x, p.y, 0.9), 0.008, "steel")


## Medical bay: pale block on an olive base band, red crosses, canopy over the doors, ramp.
static func _medical_bay(m: Array[Prim]) -> void:
	var hx := 0.95
	var hy := 0.6
	_b(m, Vector3(0, 0, 0.03), Vector3(hx + 0.05, hy + 0.05, 0.03), "concrete")
	_b(m, Vector3(0, 0, 0.22), Vector3(hx, hy, 0.16), "whitep")
	for s: float in [1.0, -1.0]:
		_b(m, Vector3(0, s * (hy + 0.003), 0.11), Vector3(hx, 0.006, 0.05), "b_olive")
	_b(m, Vector3(hx + 0.003, 0, 0.11), Vector3(0.006, hy, 0.05), "b_olive")
	_b(m, Vector3(0, 0, 0.395), Vector3(hx + 0.05, hy + 0.05, 0.025), "b_roof")
	_b(m, Vector3(0, 0, 0.425), Vector3(hx - 0.02, hy - 0.02, 0.012), "b_olive")
	for x in [-0.6, -0.1, 0.4]:
		_wy(m, x, hy, 0.27, 0.08, 0.06)
	_cross_y(m, 0.75, hy, 0.27, 0.07)
	_cross_x(m, hx, -0.35, 0.28, 0.08)
	_b(m, Vector3(hx + 0.008, 0.14, 0.19), Vector3(0.008, 0.13, 0.13), "b_trim")  # double door
	_b(m, Vector3(hx + 0.014, 0.14, 0.18), Vector3(0.006, 0.115, 0.115), "glass")
	_b(m, Vector3(hx + 0.018, 0.14, 0.18), Vector3(0.006, 0.006, 0.115), "steel")
	_b(m, Vector3(hx + 0.24, 0.14, 0.34), Vector3(0.24, 0.2, 0.012), "b_roof")  # canopy
	for s: float in [1.0, -1.0]:
		_b(m, Vector3(hx + 0.46, 0.14 + s * 0.17, 0.19), Vector3(0.014, 0.014, 0.15), "steel")
	_b(m, Vector3(hx + 0.485, 0.14, 0.335), Vector3(0.008, 0.2, 0.03), "red")  # red valance
	_ry(m, Vector3(hx + 0.2, 0.14, 0.04), Vector3(0.22, 0.14, 0.012), "concrete", 0.12)  # ramp
	_cross_y(m, -0.1, hy, 0.5, 0.0)
	_b(m, Vector3(-0.5, 0.0, 0.5), Vector3(0.08, 0.08, 0.05), "steel")  # roof vents
	_c(m, Vector3(0.2, 0.2, 0.5), 0.04, 0.05, "steel")
	_b(m, Vector3(-0.8, -0.25, 0.47), Vector3(0.12, 0.09, 0.04), "whitep")  # AC unit
	_c(m, Vector3(-0.8, -0.25, 0.512), 0.05, 0.006, "gun")


## Guard shack: small booth, sloped overhanging roof, big windows, lamp, barrier arm base with a short arm.
static func _guard_shack(m: Array[Prim]) -> void:
	_b(m, Vector3(0, 0, 0.03), Vector3(0.3, 0.26, 0.03), "concrete")
	_b(m, Vector3(0, 0, 0.21), Vector3(0.24, 0.2, 0.15), "b_oliveh")
	for s: float in [1.0, -1.0]:
		_b(m, Vector3(0, s * 0.204, 0.26), Vector3(0.16, 0.005, 0.06), "b_trim")
		_b(m, Vector3(0, s * 0.209, 0.26), Vector3(0.145, 0.005, 0.048), "glass")
		_b(m, Vector3(0, s * 0.214, 0.26), Vector3(0.005, 0.005, 0.048), "steel")
	_b(m, Vector3(0.244, 0, 0.26), Vector3(0.005, 0.12, 0.06), "b_trim")
	_b(m, Vector3(0.249, 0, 0.26), Vector3(0.005, 0.105, 0.048), "glass")
	_b(m, Vector3(0.254, 0, 0.26), Vector3(0.005, 0.005, 0.048), "steel")
	_b(m, Vector3(0.24, 0.0, 0.12), Vector3(0.008, 0.19, 0.04), "b_olive")  # lower panel
	_ry(m, Vector3(0, 0, 0.405), Vector3(0.33, 0.27, 0.018), "b_roof", 0.1)
	_b(m, Vector3(0.07, 0.0, 0.48), Vector3(0.03, 0.03, 0.025), "lampglow")  # lamp on the roof
	_b(m, Vector3(0.07, 0.0, 0.455), Vector3(0.015, 0.015, 0.015), "gun")
	_b(m, Vector3(0.52, 0.0, 0.2), Vector3(0.07, 0.08, 0.2), "hull")  # barrier post
	_b(m, Vector3(0.52, 0.0, 0.41), Vector3(0.08, 0.09, 0.015), "gun")
	_b(m, Vector3(0.53, 0.0, 0.28), Vector3(0.075, 0.075, 0.03), "red")
	_b(m, Vector3(0.595, 0.0, 0.2), Vector3(0.008, 0.04, 0.03), "lampglow")
	_l(m, Vector3(0.52, 0.0, 0.5), Vector3(0.52, 0.34, 0.54), 0.03, "whitep")
	for k in 3:
		_l(m, Vector3(0.52, 0.06 + 0.1 * float(k), 0.5 + 0.012 * float(k)), Vector3(0.52, 0.11 + 0.1 * float(k), 0.5 + 0.0125 * float(k)), 0.032, "red")
	_b(m, Vector3(0.52, 0.0, 0.46), Vector3(0.04, 0.04, 0.045), "gun")
	_b(m, Vector3(-0.2, -0.17, 0.34), Vector3(0.04, 0.01, 0.04), "steel")


## Command building: two-storey grey block, string course, two window rows, portico with steps, roof gear, flag stub.
static func _hq_building(m: Array[Prim]) -> void:
	var hx := 0.92
	var hy := 0.66
	_b(m, Vector3(0, 0, 0.03), Vector3(hx + 0.06, hy + 0.06, 0.03), "concrete")
	_b(m, Vector3(0, 0, 0.42), Vector3(hx, hy, 0.36), "concretel")
	_b(m, Vector3(0, 0, 0.43), Vector3(hx + 0.012, hy + 0.012, 0.012), "concrete")  # string course
	_b(m, Vector3(0, 0, 0.8), Vector3(hx + 0.04, hy + 0.04, 0.028), "concrete")  # roof slab
	_b(m, Vector3(0, 0, 0.84), Vector3(hx + 0.03, hy + 0.03, 0.016), "concretel")  # parapet band
	for z in [0.25, 0.62]:
		for i in 5:
			_wy(m, -0.72 + 0.36 * float(i), hy, z, 0.07, 0.07, "glass")
	for z in [0.25, 0.62]:
		for y in [-0.38, 0.38]:
			_wx(m, hx, y, z, 0.07, 0.07)
	_wx(m, hx, 0.0, 0.62, 0.07, 0.07)
	_b(m, Vector3(hx + 0.008, 0, 0.2), Vector3(0.008, 0.16, 0.15), "b_trim")  # double door
	_b(m, Vector3(hx + 0.014, 0, 0.19), Vector3(0.006, 0.14, 0.135), "steel")
	_b(m, Vector3(hx + 0.02, 0, 0.19), Vector3(0.004, 0.005, 0.135), "gun")
	_steps_x(m, hx + 0.01, 0, 0.25, 3, 0.03, 0.08, "concrete")
	_b(m, Vector3(hx + 0.26, 0, 0.395), Vector3(0.26, 0.3, 0.018), "concrete")  # portico
	for s: float in [1.0, -1.0]:
		_b(m, Vector3(hx + 0.46, s * 0.26, 0.2), Vector3(0.025, 0.025, 0.2), "concretel")
		_b(m, Vector3(hx + 0.46, s * 0.26, 0.015), Vector3(0.04, 0.04, 0.015), "concrete")
	_b(m, Vector3(hx + 0.26, 0, 0.42), Vector3(0.24, 0.28, 0.01), "b_olive")
	_b(m, Vector3(hx + 0.01, 0.0, 0.5), Vector3(0.01, 0.16, 0.03), "b_olive")  # name board
	for i in 5:
		_b(m, Vector3(hx + 0.018, -0.12 + 0.06 * float(i), 0.5), Vector3(0.004, 0.018, 0.012), "whitep")
	_c(m, Vector3(0.45, 0.4, 1.1), 0.014, 0.28, "steel")  # flagpole stub and flag
	_b(m, Vector3(0.45, 0.31, 1.26), Vector3(0.006, 0.09, 0.055), "red")
	_b(m, Vector3(0.45, 0.28, 1.26), Vector3(0.008, 0.03, 0.03), "whitep")
	_s(m, Vector3(0.45, 0.4, 1.4), Vector3(0.022, 0.022, 0.022), "brass")
	_b(m, Vector3(-0.4, 0.2, 0.9), Vector3(0.1, 0.08, 0.05), "steel")  # AC units
	_c(m, Vector3(-0.4, 0.2, 0.955), 0.055, 0.006, "gun")
	_b(m, Vector3(-0.2, -0.3, 0.89), Vector3(0.08, 0.07, 0.04), "steel")
	_l(m, Vector3(-0.65, -0.2, 0.84), Vector3(-0.65, -0.2, 1.35), 0.012, "steel")  # mast
	_l(m, Vector3(-0.65, -0.2, 1.15), Vector3(-0.65, 0.0, 1.15), 0.008, "steel")
	_l(m, Vector3(-0.65, -0.2, 1.05), Vector3(-0.65, -0.4, 1.05), 0.008, "steel")
	for s: float in [1.0, -1.0]:
		_b(m, Vector3(hx - 0.1, s * (hy - 0.1), 0.88), Vector3(0.08, 0.02, 0.02), "concretel")


## Repair workshop: corrugated shed with a roll-up door, a hoist beam with chain over the doorway, side doors.
static func _workshop(m: Array[Prim]) -> void:
	var hx := 0.85
	var hy := 0.6
	_b(m, Vector3(0, 0, 0.03), Vector3(hx + 0.05, hy + 0.05, 0.03), "concrete")
	_b(m, Vector3(0, 0, 0.24), Vector3(hx, hy, 0.18), "b_gal")
	for s: float in [1.0, -1.0]:
		for i in 17:
			_b(m, Vector3(-0.8 + 0.1 * float(i), s * (hy + 0.004), 0.24), Vector3(0.012, 0.004, 0.17), "b_gald")
		_wy(m, -0.4, hy + 0.005, 0.28, 0.1, 0.05, "b_glassd")
		_wy(m, 0.05, hy + 0.005, 0.28, 0.1, 0.05, "b_glassd")
		_b(m, Vector3(-0.68, s * (hy + 0.01), 0.16), Vector3(0.1, 0.008, 0.12), "b_trim")  # side door
		_b(m, Vector3(-0.68, s * (hy + 0.017), 0.155), Vector3(0.085, 0.006, 0.105), "woodd")
	_gabx(m, Vector3(0, 0, 0), hx, hy, 0.42, 0.24, "b_gal", "b_gal", "b_gald")
	_b(m, Vector3(hx + 0.006, 0, 0.2), Vector3(0.01, 0.42, 0.17), "b_trim")  # roll-up door
	_b(m, Vector3(hx + 0.012, 0, 0.3), Vector3(0.008, 0.4, 0.06), "b_black")  # half-open gap
	for i in 5:
		_b(m, Vector3(hx + 0.014, 0, 0.065 + 0.05 * float(i)), Vector3(0.008, 0.4, 0.022), "b_gal" if i % 2 == 0 else "b_gald")
	_b(m, Vector3(hx + 0.02, 0, 0.395), Vector3(0.025, 0.42, 0.02), "gun")  # door hood
	_b(m, Vector3(hx + 0.3, 0, 0.5), Vector3(0.36, 0.028, 0.025), "gun")  # hoist beam
	_b(m, Vector3(hx + 0.3, 0, 0.525), Vector3(0.36, 0.05, 0.008), "gun")
	_l(m, Vector3(hx + 0.02, 0, 0.44), Vector3(hx + 0.22, 0, 0.5), 0.012, "steel")
	_b(m, Vector3(hx + 0.4, 0, 0.45), Vector3(0.05, 0.04, 0.04), "b_yellow")  # trolley and chain block
	_l(m, Vector3(hx + 0.4, 0, 0.41), Vector3(hx + 0.4, 0, 0.2), 0.008, "steel")
	_b(m, Vector3(hx + 0.4, 0, 0.18), Vector3(0.015, 0.02, 0.025), "gun")
	for k in 4:  # chain links
		_b(m, Vector3(hx + 0.4, 0, 0.23 + 0.05 * float(k)), Vector3(0.01, 0.012, 0.012), "b_black")
	_c(m, Vector3(hx + 0.25, -0.42, 0.1), 0.07, 0.1, "drum")  # drums by the door
	_c(m, Vector3(hx + 0.25, -0.58, 0.1), 0.07, 0.1, "b_drumg")
	_b(m, Vector3(hx + 0.2, 0.55, 0.08), Vector3(0.08, 0.1, 0.07), "rust")  # parts bin
	_c(m, Vector3(-0.3, 0.0, 0.76), 0.04, 0.1, "steel")  # roof vents
	_c(m, Vector3(0.3, 0.0, 0.76), 0.04, 0.1, "steel")
	_c(m, Vector3(-0.3, 0.0, 0.87), 0.06, 0.012, "gun")
	_c(m, Vector3(0.3, 0.0, 0.87), 0.06, 0.012, "gun")


## Generator shed: small olive shed with louvres, lit window, conduit and a tall exhaust stack with a rain cap.
static func _generator_shed(m: Array[Prim]) -> void:
	var hx := 0.4
	var hy := 0.32
	_b(m, Vector3(0, 0, 0.03), Vector3(hx + 0.06, hy + 0.06, 0.03), "concrete")
	_b(m, Vector3(0, 0, 0.24), Vector3(hx, hy, 0.18), "b_olive")
	_gabx(m, Vector3(0, 0, 0), hx, hy, 0.42, 0.1, "b_roof", "b_olive", "b_gald", true, 0.05)
	for s: float in [1.0, -1.0]:
		for i in 4:  # louvre vents
			_b(m, Vector3(-0.1, s * (hy + 0.006), 0.14 + 0.035 * float(i)), Vector3(0.14, 0.004, 0.01), "gun")
		_b(m, Vector3(-0.1, s * (hy + 0.003), 0.21), Vector3(0.16, 0.003, 0.08), "b_trim")
		_b(m, Vector3(0.22, s * (hy + 0.006), 0.26), Vector3(0.07, 0.005, 0.055), "b_trim")
		_b(m, Vector3(0.22, s * (hy + 0.011), 0.26), Vector3(0.055, 0.004, 0.042), "lampglow")
	for i in 4:
		_b(m, Vector3(hx + 0.008, 0, 0.14 + 0.035 * float(i)), Vector3(0.006, 0.18, 0.01), "gun")  # front louvres
	_b(m, Vector3(hx + 0.004, 0, 0.21), Vector3(0.004, 0.2, 0.09), "b_trim")
	_b(m, Vector3(hx + 0.014, 0.0, 0.35), Vector3(0.008, 0.05, 0.04), "lampglow")  # status lamp window
	_b(m, Vector3(hx + 0.012, -0.24, 0.22), Vector3(0.008, 0.03, 0.12), "gun")  # conduit
	_c(m, Vector3(-0.22, 0.2, 0.62), 0.05, 0.35, "steel")  # exhaust stack
	_c(m, Vector3(-0.22, 0.2, 0.34), 0.07, 0.03, "gun")
	_c(m, Vector3(-0.22, 0.2, 0.93), 0.065, 0.015, "gun")
	_c(m, Vector3(-0.22, 0.2, 0.97), 0.015, 0.03, "gun")
	_c(m, Vector3(-0.22, 0.2, 1.0), 0.055, 0.008, "steel")
	for z in [0.5, 0.75]:
		_c(m, Vector3(-0.22, 0.2, z), 0.058, 0.01, "rust")
	_b(m, Vector3(0.3, -hy - 0.1, 0.12), Vector3(0.08, 0.07, 0.1), "drum")  # fuel drum + jerrycan
	_b(m, Vector3(0.45, -hy - 0.08, 0.06), Vector3(0.04, 0.025, 0.05), "b_drumy")


# ---------------------------------------------------------------- walls and gates

## HESCO barrier: a row of sand-filled wire-mesh cubes, stepped up in the middle.
static func _hesco(m: Array[Prim]) -> void:
	_b(m, Vector3(0, 0, 0.012), Vector3(0.52, 0.22, 0.012), "dirt")
	for i in 3:
		_hesco_cell(m, -0.34 + 0.34 * float(i), 0.0, 0.0, i == 1)


static func _hesco_cell(m: Array[Prim], x: float, y: float, z0: float, tall: bool) -> void:
	var hx := 0.165
	var hy := 0.17
	var hz := 0.17
	_b(m, Vector3(x, y, z0 + hz + 0.02), Vector3(hx, hy, hz), "b_hesco")
	for j in 5:  # mesh wires
		var zz: float = z0 + 0.06 + 0.06 * float(j)
		for s: float in [1.0, -1.0]:
			_b(m, Vector3(x, y + s * (hy + 0.004), zz), Vector3(hx + 0.004, 0.004, 0.005), "b_mesh")
		_b(m, Vector3(x + hx + 0.004, y, zz), Vector3(0.004, hy + 0.004, 0.005), "b_mesh")
	for i in 3:
		var xx: float = x - hx * 0.6 + hx * 0.6 * float(i)
		for s: float in [1.0, -1.0]:
			_b(m, Vector3(xx, y + s * (hy + 0.004), z0 + hz + 0.02), Vector3(0.004, 0.004, hz - 0.005), "b_mesh")
	for sy: float in [1.0, -1.0]:
		_b(m, Vector3(x + hx, y + sy * hy, z0 + hz + 0.02), Vector3(0.012, 0.012, hz + 0.01), "gun")
		_b(m, Vector3(x - hx, y + sy * hy, z0 + hz + 0.02), Vector3(0.012, 0.012, hz + 0.01), "gun")
	_s(m, Vector3(x, y, z0 + 2.0 * hz + 0.03), Vector3(hx * 0.9, hy * 0.9, 0.035), "sand")
	if tall:
		_hesco_cell(m, x, y, z0 + 2.0 * hz + 0.03, false)


## Blast wall corner: two tall concrete T-walls meeting at an L, hazard-striped ends, top lip.
static func _blast_corner(m: Array[Prim]) -> void:
	var c := -0.4
	_b(m, Vector3(0.0, c, 0.035), Vector3(0.52, 0.17, 0.035), "concrete")  # feet
	_b(m, Vector3(c, 0.0, 0.035), Vector3(0.17, 0.52, 0.035), "concrete")
	_b(m, Vector3(0.05, c, 0.4), Vector3(0.52, 0.065, 0.36), "concrete")  # arm along x (corner at -x)
	_b(m, Vector3(c, 0.05, 0.4), Vector3(0.065, 0.52, 0.36), "concrete")
	_b(m, Vector3(c, c, 0.4), Vector3(0.09, 0.09, 0.36), "concretel")  # corner post
	_b(m, Vector3(0.05, c, 0.78), Vector3(0.53, 0.095, 0.025), "concretel")  # top lips
	_b(m, Vector3(c, 0.05, 0.78), Vector3(0.095, 0.53, 0.025), "concretel")
	_b(m, Vector3(c, c, 0.78), Vector3(0.115, 0.115, 0.025), "concretel")
	for i in 3:  # seams
		_b(m, Vector3(-0.1 + 0.3 * float(i), c + 0.068, 0.4), Vector3(0.005, 0.004, 0.34), "concretec")
		_b(m, Vector3(c + 0.068, -0.1 + 0.3 * float(i), 0.4), Vector3(0.004, 0.005, 0.34), "concretec")
	for i in 4:  # hazard stripes on the end faces
		var z: float = 0.15 + 0.14 * float(i)
		_b(m, Vector3(0.575, c, z), Vector3(0.006, 0.066, 0.035), "b_yellow" if i % 2 == 0 else "b_black")
		_b(m, Vector3(c, 0.575, z), Vector3(0.066, 0.006, 0.035), "b_yellow" if i % 2 == 0 else "b_black")
	_b(m, Vector3(0.1, c + 0.068, 0.2), Vector3(0.3, 0.004, 0.03), "b_yellow")  # lower painted band
	_b(m, Vector3(c + 0.068, 0.1, 0.2), Vector3(0.004, 0.3, 0.03), "b_yellow")
	for i in 5:
		_b(m, Vector3(-0.1 + 0.15 * float(i), c + 0.07, 0.2), Vector3(0.025, 0.004, 0.03), "b_black")
		_b(m, Vector3(c + 0.07, -0.1 + 0.15 * float(i), 0.2), Vector3(0.004, 0.025, 0.03), "b_black")


## Sliding gate: two heavy posts, a steel picket leaf with a diagonal brace on a floor track, keypad on a post.
static func _sliding_gate(m: Array[Prim]) -> void:
	var px := 0.82
	for s: float in [1.0, -1.0]:
		_b(m, Vector3(px * s, 0, 0.04), Vector3(0.09, 0.09, 0.04), "concrete")
		_b(m, Vector3(px * s, 0, 0.36), Vector3(0.065, 0.065, 0.32), "steel")
		_b(m, Vector3(px * s, 0, 0.7), Vector3(0.08, 0.08, 0.025), "gun")
		_b(m, Vector3(px * s, 0, 0.5), Vector3(0.068, 0.068, 0.012), "gun")
		_b(m, Vector3(px * s, 0, 0.22), Vector3(0.068, 0.068, 0.012), "gun")
	_b(m, Vector3(0, 0, 0.025), Vector3(px + 0.07, 0.035, 0.025), "gun")  # track
	_b(m, Vector3(0, 0, 0.058), Vector3(px - 0.08, 0.02, 0.008), "steel")
	var y := 0.0
	_b(m, Vector3(0.0, y, 0.095), Vector3(0.74, 0.025, 0.02), "steel")  # leaf: bottom and top rails
	_b(m, Vector3(0.0, y, 0.6), Vector3(0.74, 0.025, 0.022), "steel")
	_b(m, Vector3(0.0, y, 0.35), Vector3(0.74, 0.02, 0.014), "steel")
	for sx: float in [1.0, -1.0]:
		_b(m, Vector3(sx * 0.73, y, 0.35), Vector3(0.02, 0.025, 0.26), "steel")
	for i in 14:
		_b(m, Vector3(-0.68 + 0.105 * float(i), y, 0.35), Vector3(0.008, 0.009, 0.25), "gun")
	_l(m, Vector3(-0.72, 0.0, 0.12), Vector3(0.72, 0.0, 0.58), 0.012, "b_gald")
	for i in 8:  # spikes
		_b(m, Vector3(-0.66 + 0.19 * float(i), y, 0.635), Vector3(0.01, 0.01, 0.025), "steel")
	for i in 3:
		var wx: float = -0.5 + 0.5 * float(i)
		_c(m, Vector3(wx, y, 0.075), 0.03, 0.012, "gun")
	_b(m, Vector3(0.4, 0.0, 0.34), Vector3(0.14, 0.014, 0.1), "whitep")  # sign plate on the leaf
	_b(m, Vector3(0.4, 0.0, 0.4), Vector3(0.13, 0.016, 0.02), "red")
	for s: float in [1.0, -1.0]:
		_b(m, Vector3(0.4, s * 0.016, 0.34), Vector3(0.14, 0.004, 0.1), "whitep")
		_b(m, Vector3(0.4, s * 0.018, 0.4), Vector3(0.13, 0.004, 0.02), "red")
		_b(m, Vector3(0.4, s * 0.018, 0.31), Vector3(0.09, 0.004, 0.008), "gun")
	_b(m, Vector3(px + 0.07, 0.07, 0.3), Vector3(0.025, 0.04, 0.05), "hull")  # keypad box
	_b(m, Vector3(px + 0.097, 0.07, 0.31), Vector3(0.004, 0.025, 0.03), "lampglow")
	_b(m, Vector3(-px - 0.07, -0.07, 0.3), Vector3(0.025, 0.04, 0.05), "hull")


## Razor-wire fence: tall steel mesh between posts with outriggers carrying three coils of razor wire.
static func _razor_fence(m: Array[Prim]) -> void:
	for i in 3:
		var x: float = -0.5 + 0.5 * float(i)
		_c(m, Vector3(x, 0, 0.4), 0.022, 0.4, "steel")
		_c(m, Vector3(x, 0, 0.03), 0.04, 0.03, "concrete")
		for s: float in [1.0, -1.0]:
			_l(m, Vector3(x, 0, 0.78), Vector3(x, s * 0.1, 0.95), 0.012, "steel")
	_b(m, Vector3(0, 0, 0.78), Vector3(0.5, 0.012, 0.012), "steel")
	_b(m, Vector3(0, 0, 0.1), Vector3(0.5, 0.012, 0.012), "steel")
	_b(m, Vector3(0, 0, 0.44), Vector3(0.5, 0.008, 0.008), "steel")
	for i in 15:
		_b(m, Vector3(-0.47 + 0.0672 * float(i), 0, 0.44), Vector3(0.005, 0.005, 0.34), "b_mesh")
	for j in 7:
		_b(m, Vector3(0, 0, 0.15 + 0.1 * float(j)), Vector3(0.5, 0.004, 0.004), "b_mesh")
	for i in 12:  # three coils of razor wire
		var x: float = -0.48 + 0.087 * float(i)
		var w: float = Base._rnd(i, 3) * 0.01
		_s(m, Vector3(x, -0.1, 0.96 + w), Vector3(0.05, 0.04, 0.04), "b_wire")
		_s(m, Vector3(x + 0.04, 0.1, 0.96 - w), Vector3(0.05, 0.04, 0.04), "b_wire")
		_s(m, Vector3(x + 0.02, 0.0, 1.03 + w), Vector3(0.05, 0.04, 0.04), "steel")
	_b(m, Vector3(0, 0, 1.0), Vector3(0.5, 0.004, 0.004), "b_wire")
	_b(m, Vector3(0, 0, 0.92), Vector3(0.5, 0.004, 0.004), "b_wire")


## Sandbag bastion: an L of double-width sandbag walls stepped up toward the corner, a crate and a helmet inside.
static func _sandbag_corner(m: Array[Prim]) -> void:
	var c := -0.35
	_b(m, Vector3(0.05, 0.05, 0.01), Vector3(0.5, 0.5, 0.01), "dirt")
	for layer in 5:
		var z: float = 0.045 + 0.085 * float(layer) + 0.012
		var n: int = 5 - int(float(layer) * 0.6)
		var off: float = 0.11 if layer % 2 == 1 else 0.0
		for row in 2:
			for i in n:
				var d: float = float(i) * 0.24 + off
				var jit: float = (Base._rnd(i + row * 9, layer + 80) - 0.5) * 0.06
				_b(m, Vector3(c + d, c + float(row) * 0.19, z), Vector3(0.11, 0.075, 0.045), "sand", jit)
				if i > 0 or layer % 2 == 0:
					_b(m, Vector3(c + float(row) * 0.19, c + d + 0.12, z), Vector3(0.075, 0.11, 0.045), "sand", jit)
	_b(m, Vector3(0.12, 0.12, 0.08), Vector3(0.09, 0.075, 0.07), "ammo")  # ammo box inside
	_b(m, Vector3(0.12, 0.12, 0.155), Vector3(0.092, 0.077, 0.008), "gun")
	_s(m, Vector3(0.0, 0.25, 0.04), Vector3(0.05, 0.05, 0.035), "helm")


## Brick perimeter wall: brick panels between piers, mortar courses, concrete capping and footing.
static func _brick_wall(m: Array[Prim]) -> void:
	_b(m, Vector3(0, 0, 0.04), Vector3(0.5, 0.125, 0.04), "concrete")
	_b(m, Vector3(0, 0, 0.4), Vector3(0.5, 0.07, 0.32), "brick")
	for i in 10:
		for s: float in [1.0, -1.0]:
			_b(m, Vector3(0, s * 0.073, 0.12 + 0.063 * float(i)), Vector3(0.5, 0.004, 0.005), "b_brickd")
			for j in 5:  # staggered vertical joints
				var xo: float = -0.45 + 0.2 * float(j) + (0.1 if i % 2 == 0 else 0.0)
				if xo < 0.5:
					_b(m, Vector3(xo, s * 0.073, 0.12 + 0.063 * float(i) + 0.031), Vector3(0.004, 0.004, 0.03), "b_brickd")
	for x in [-0.47, 0.0, 0.47]:
		_b(m, Vector3(x, 0, 0.42), Vector3(0.05, 0.105, 0.34), "brick")
		_b(m, Vector3(x, 0, 0.775), Vector3(0.07, 0.125, 0.02), "concretel")
		_b(m, Vector3(x, 0, 0.805), Vector3(0.05, 0.1, 0.014), "concrete")
	_b(m, Vector3(0, 0, 0.73), Vector3(0.5, 0.1, 0.022), "concretel")  # capping
	_b(m, Vector3(0, 0, 0.755), Vector3(0.5, 0.075, 0.008), "concrete")


## Tall concrete wall: precast panels with pilasters at the joints, hazard band, overhanging anti-climb lip.
static func _tall_wall(m: Array[Prim]) -> void:
	_b(m, Vector3(0, 0, 0.04), Vector3(0.5, 0.2, 0.04), "concrete")
	_b(m, Vector3(0, 0, 0.52), Vector3(0.5, 0.075, 0.44), "concrete")
	for x in [-0.47, 0.0, 0.47]:
		_b(m, Vector3(x, 0, 0.5), Vector3(0.035, 0.105, 0.42), "concretel")
	for s: float in [1.0, -1.0]:
		_b(m, Vector3(0, s * 0.078, 0.15), Vector3(0.5, 0.004, 0.028), "b_yellow")
		for i in 10:
			_b(m, Vector3(-0.46 + 0.1 * float(i), s * 0.081, 0.15), Vector3(0.022, 0.004, 0.028), "b_black")
		for z in [0.4, 0.6, 0.8]:
			_b(m, Vector3(0, s * 0.077, z), Vector3(0.5, 0.003, 0.004), "concretec")
		_rx(m, Vector3(0, s * 0.13, 0.99), Vector3(0.5, 0.06, 0.018), "concretel", -s * 0.5)  # anti-climb lip
		_b(m, Vector3(0, s * 0.1, 0.96), Vector3(0.5, 0.02, 0.025), "concrete")
	_b(m, Vector3(0, 0, 0.98), Vector3(0.5, 0.08, 0.022), "concretel")


## Wall tower: square concrete turret on the wall corner with an overhanging fighting floor, slits, roof and lamp.
static func _wall_tower(m: Array[Prim]) -> void:
	_b(m, Vector3(0, 0, 0.03), Vector3(0.58, 0.58, 0.03), "concrete")
	for s: float in [1.0, -1.0]:  # wall stubs
		_b(m, Vector3(0.55, 0.0, 0.28), Vector3(0.1, 0.06, 0.25), "concrete")
		_b(m, Vector3(0.0, 0.55, 0.28), Vector3(0.06, 0.1, 0.25), "concrete")
		_b(m, Vector3(-0.55, 0.0, 0.28), Vector3(0.1, 0.06, 0.25), "concrete")
		_b(m, Vector3(0.0, -0.55, 0.28), Vector3(0.06, 0.1, 0.25), "concrete")
		break
	_b(m, Vector3(0, 0, 0.35), Vector3(0.4, 0.4, 0.29), "concrete")
	for s: float in [1.0, -1.0]:
		_b(m, Vector3(0.405, s * 0.2, 0.35), Vector3(0.006, 0.012, 0.28), "concretec")
		_b(m, Vector3(s * 0.2, 0.405, 0.35), Vector3(0.012, 0.006, 0.28), "concretec")
		_b(m, Vector3(s * 0.2, -0.405, 0.35), Vector3(0.012, 0.006, 0.28), "concretec")
	_b(m, Vector3(0, 0, 0.66), Vector3(0.47, 0.47, 0.035), "concretel")  # corbelled floor
	_b(m, Vector3(0, 0, 0.62), Vector3(0.44, 0.44, 0.02), "concrete")
	_b(m, Vector3(0, 0, 0.88), Vector3(0.45, 0.45, 0.19), "concrete")  # fighting level
	for s: float in [1.0, -1.0]:
		_b(m, Vector3(0.455, s * 0.2, 0.9), Vector3(0.006, 0.09, 0.025), "gun")  # slits
		_b(m, Vector3(s * 0.2, 0.455, 0.9), Vector3(0.09, 0.006, 0.025), "gun")
		_b(m, Vector3(s * 0.2, -0.455, 0.9), Vector3(0.09, 0.006, 0.025), "gun")
	_b(m, Vector3(0.455, 0, 0.85), Vector3(0.006, 0.05, 0.06), "gun")  # door slit
	_b(m, Vector3(0, 0, 1.095), Vector3(0.5, 0.5, 0.025), "concretel")  # roof slab
	_b(m, Vector3(0, 0, 1.13), Vector3(0.4, 0.4, 0.015), "b_roof")
	_b(m, Vector3(0.12, 0.12, 1.17), Vector3(0.05, 0.05, 0.03), "lampglow")  # searchlight
	_b(m, Vector3(0.12, 0.12, 1.14), Vector3(0.03, 0.03, 0.02), "gun")
	_l(m, Vector3(-0.2, -0.2, 1.14), Vector3(-0.2, -0.2, 1.7), 0.012, "steel")
	_b(m, Vector3(-0.2, -0.32, 1.6), Vector3(0.006, 0.1, 0.06), "red")
	for i in 5:  # sandbags on the roof lip
		_b(m, Vector3(0.45, -0.3 + 0.15 * float(i), 1.14), Vector3(0.05, 0.07, 0.03), "sand")
		_b(m, Vector3(-0.3 + 0.15 * float(i), 0.45, 1.14), Vector3(0.07, 0.05, 0.03), "sand")


## Steel gate post: concrete plinth, riveted steel-clad pillar with bands, sign plate, hinge knuckles and a cap lamp.
static func _gate_post(m: Array[Prim]) -> void:
	_b(m, Vector3(0, 0, 0.04), Vector3(0.2, 0.2, 0.04), "concrete")
	_b(m, Vector3(0, 0, 0.14), Vector3(0.14, 0.14, 0.06), "concretel")
	_b(m, Vector3(0, 0, 0.58), Vector3(0.105, 0.105, 0.38), "steel")
	for z in [0.26, 0.5, 0.74]:
		_b(m, Vector3(0, 0, z), Vector3(0.115, 0.115, 0.015), "gun")
	for z in [0.38, 0.62]:
		for i in 3:
			_s(m, Vector3(0.108, -0.06 + 0.06 * float(i), z), Vector3(0.008, 0.008, 0.008), "steelc")
			_s(m, Vector3(-0.06 + 0.06 * float(i), 0.108, z), Vector3(0.008, 0.008, 0.008), "steelc")
	_b(m, Vector3(0, 0, 0.98), Vector3(0.14, 0.14, 0.03), "gun")  # cap
	_b(m, Vector3(0, 0, 1.03), Vector3(0.1, 0.1, 0.025), "steel")
	_b(m, Vector3(0, 0, 1.075), Vector3(0.05, 0.05, 0.03), "red")
	_b(m, Vector3(0.113, 0, 0.7), Vector3(0.008, 0.09, 0.07), "whitep")  # sign plate
	_b(m, Vector3(0.12, 0, 0.745), Vector3(0.004, 0.08, 0.016), "red")
	_b(m, Vector3(0.12, 0.0, 0.69), Vector3(0.004, 0.06, 0.006), "gun")
	_b(m, Vector3(0.12, 0.0, 0.67), Vector3(0.004, 0.045, 0.005), "gun")
	for s: float in [1.0, -1.0]:
		_b(m, Vector3(0, s * 0.113, 0.7), Vector3(0.09, 0.008, 0.07), "whitep")
		_b(m, Vector3(0, s * 0.12, 0.745), Vector3(0.08, 0.004, 0.016), "red")
		_b(m, Vector3(0.0, s * 0.12, 0.69), Vector3(0.06, 0.004, 0.006), "gun")
		_b(m, Vector3(0.0, s * 0.12, 0.67), Vector3(0.045, 0.004, 0.005), "gun")
		for z in [0.34, 0.6]:  # hinge knuckles
			_c(m, Vector3(0.1, s * 0.13, z), 0.025, 0.04, "gun")
			_l(m, Vector3(0.1, s * 0.12, z), Vector3(0.1, s * 0.22, z), 0.014, "gun")
	_b(m, Vector3(0.18, 0.0, 0.025), Vector3(0.05, 0.05, 0.025), "b_yellow")  # kerb mark


# ---------------------------------------------------------------- props

## Camouflage net: a patchwork of net patches in three tones on corner poles with a raised centre, over a parked hull.
static func _camo_net(m: Array[Prim]) -> void:
	_b(m, Vector3(0.0, 0.0, 0.16), Vector3(0.42, 0.22, 0.12), "hull")  # something under the net
	_b(m, Vector3(0.1, 0.0, 0.32), Vector3(0.2, 0.17, 0.05), "hull")
	var mats: Array[String] = ["b_camo1", "b_camo2", "b_camo3", "b_camo1"]
	for gx in 7:
		for gy in 7:
			var seed_i: int = gx * 7 + gy
			var edge: bool = gx == 0 or gy == 0 or gx == 6 or gy == 6
			if Base._rnd(seed_i, 31) < 0.14 and not edge:
				continue
			var x: float = -0.6 + 0.2 * float(gx)
			var y: float = -0.6 + 0.2 * float(gy)
			var r: float = maxf(absf(x), absf(y)) / 0.6
			var z: float = 0.46 + 0.17 * (1.0 - r * r)
			var sz: float = 0.092 + 0.02 * Base._rnd(seed_i, 32)
			var mi: int = int(Base._rnd(seed_i, 33) * 3.99)
			_b(m, Vector3(x, y, z), Vector3(sz, sz, 0.008), mats[mi], (Base._rnd(seed_i, 34) - 0.5) * 0.5)
	for p: Vector2 in [Vector2(-0.64, -0.64), Vector2(0.64, -0.64), Vector2(0.64, 0.64), Vector2(-0.64, 0.64)]:
		_c(m, Vector3(p.x, p.y, 0.25), 0.02, 0.25, "woodd")
		_l(m, Vector3(p.x * 1.18, p.y * 1.18, 0.0), Vector3(p.x, p.y, 0.48), 0.006, "b_cable")
	_c(m, Vector3(0, 0, 0.35), 0.02, 0.35, "woodd")


## Antenna array: lattice mast with a yagi and a beacon, four whips, an equipment cabinet and guy wires.
static func _antenna_array(m: Array[Prim]) -> void:
	_c(m, Vector3(0, 0, 0.03), 0.14, 0.03, "concrete")
	_lattice(m, 0.0, 0.0, 0.06, 0.08, 1.25, 7, "steel")
	_c(m, Vector3(0, 0, 1.36), 0.02, 0.1, "steel")
	_b(m, Vector3(0, 0, 1.47), Vector3(0.016, 0.016, 0.016), "red")
	_l(m, Vector3(0.0, -0.2, 1.05), Vector3(0.0, 0.2, 1.05), 0.012, "steel")  # yagi
	for i in 4:
		var y: float = -0.15 + 0.1 * float(i)
		_l(m, Vector3(0.0, y, 0.99), Vector3(0.0, y, 1.11), 0.007, "gun")
	_l(m, Vector3(0.0, -0.14, 0.82), Vector3(0.0, 0.14, 0.82), 0.012, "steel")
	var whips: Array[Vector3] = [Vector3(0.3, 0.2, 0.8), Vector3(0.28, -0.22, 0.65), Vector3(-0.3, 0.26, 0.9), Vector3(-0.26, -0.3, 0.7)]
	for p in whips:
		_c(m, Vector3(p.x, p.y, 0.03), 0.035, 0.03, "concrete")
		_l(m, Vector3(p.x, p.y, 0.05), Vector3(p.x, p.y, p.z), 0.008, "steel")
	_b(m, Vector3(0.28, 0.0, 0.14), Vector3(0.11, 0.09, 0.11), "hull")  # cabinet
	_b(m, Vector3(0.39, 0.0, 0.16), Vector3(0.006, 0.07, 0.07), "gun")
	_b(m, Vector3(0.395, 0.03, 0.18), Vector3(0.004, 0.012, 0.012), "lampglow")
	_l(m, Vector3(0.18, 0.0, 0.09), Vector3(0.06, 0.0, 0.1), 0.01, "b_cable")
	for a: float in [0.8, 2.9, 4.9]:  # guys
		_l(m, Vector3(cos(a) * 0.5, sin(a) * 0.5, 0.0), Vector3(0.0, 0.0, 0.95), 0.004, "b_wire")
		_b(m, Vector3(cos(a) * 0.5, sin(a) * 0.5, 0.025), Vector3(0.02, 0.02, 0.025), "concrete")


## Elevated water tank: grey-green cylinder with a domed lid on a braced steel tower, ladder and standpipe.
static func _water_tank(m: Array[Prim]) -> void:
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			_l(m, Vector3(0.3 * sx, 0.3 * sy, 0.0), Vector3(0.22 * sx, 0.22 * sy, 0.86), 0.022, "steel")
			_b(m, Vector3(0.3 * sx, 0.3 * sy, 0.02), Vector3(0.05, 0.05, 0.02), "concrete")
	for z in [0.3, 0.6]:
		var f: float = 0.3 - 0.08 * (z / 0.86)
		_l(m, Vector3(f, -f, z), Vector3(f, f, z), 0.01, "gun")
		_l(m, Vector3(-f, f, z), Vector3(f, f, z), 0.01, "gun")
		_l(m, Vector3(-f, -f, z), Vector3(f, -f, z), 0.01, "gun")
		_l(m, Vector3(-f, -f, z), Vector3(-f, f, z), 0.01, "gun")
		_l(m, Vector3(f, -f, z - 0.26), Vector3(f, f, z), 0.008, "steel")
		_l(m, Vector3(f, f, z - 0.26), Vector3(f, -f, z), 0.008, "steel")
		_l(m, Vector3(-f, f, z - 0.26), Vector3(f, f, z), 0.008, "steel")
		_l(m, Vector3(f, f, z - 0.26), Vector3(-f, f, z), 0.008, "steel")
	_b(m, Vector3(0, 0, 0.88), Vector3(0.32, 0.32, 0.02), "gun")
	_c(m, Vector3(0, 0, 1.12), 0.28, 0.22, "tankg")
	for z in [1.0, 1.24]:
		_c(m, Vector3(0, 0, z), 0.288, 0.012, "steel")
	_s(m, Vector3(0, 0, 1.34), Vector3(0.28, 0.28, 0.1), "tankg")
	_c(m, Vector3(0.05, 0.05, 1.45), 0.05, 0.02, "steel")
	_b(m, Vector3(0.288, 0.0, 1.1), Vector3(0.006, 0.09, 0.07), "whitep")  # stencil plate
	_b(m, Vector3(0.292, 0.0, 1.14), Vector3(0.004, 0.07, 0.012), "b_black")
	_b(m, Vector3(0.292, 0.0, 1.08), Vector3(0.004, 0.05, 0.01), "b_black")
	_l(m, Vector3(0.38, -0.06, 0.0), Vector3(0.3, -0.06, 1.28), 0.012, "steel")  # ladder
	_l(m, Vector3(0.38, 0.06, 0.0), Vector3(0.3, 0.06, 1.28), 0.012, "steel")
	for i in 9:
		var t: float = 0.08 + 0.13 * float(i)
		var xr: float = 0.38 - 0.08 * t / 1.28
		_l(m, Vector3(xr, -0.06, t), Vector3(xr, 0.06, t), 0.007, "steel")
	_c(m, Vector3(-0.06, 0.0, 0.43), 0.025, 0.43, "rust")  # standpipe
	_c(m, Vector3(-0.06, 0.0, 0.2), 0.04, 0.025, "red")  # valve


## Military fuel bowser: horizontal tank on a two-wheel chassis with a pump cabinet, hose and nozzle at the front.
static func _fuel_pump(m: Array[Prim]) -> void:
	_b(m, Vector3(-0.05, 0, 0.17), Vector3(0.52, 0.17, 0.02), "gun")  # chassis
	_cx(m, Vector3(-0.05, 0.0, 0.36), 0.2, 0.42, "b_olive")
	_s(m, Vector3(0.37, 0.0, 0.36), Vector3(0.05, 0.2, 0.2), "b_olive")
	_s(m, Vector3(-0.47, 0.0, 0.36), Vector3(0.05, 0.2, 0.2), "b_olive")
	for x in [-0.25, 0.15]:
		_cx(m, Vector3(x, 0.0, 0.36), 0.208, 0.012, "gun")
	_b(m, Vector3(0.05, 0.0, 0.57), Vector3(0.1, 0.07, 0.02), "gun")  # hatch
	_c(m, Vector3(0.05, 0.0, 0.6), 0.04, 0.012, "steel")
	_b(m, Vector3(-0.05, 0.0, 0.562), Vector3(0.33, 0.025, 0.012), "b_yellow")  # stripe along the top
	for s: float in [1.0, -1.0]:
		_cyy(m, Vector3(-0.12, s * 0.27, 0.14), 0.14, 0.04, "track")
		_cyy(m, Vector3(-0.12, s * 0.3, 0.14), 0.08, 0.012, "steel")
		_b(m, Vector3(-0.12, s * 0.22, 0.28), Vector3(0.17, 0.05, 0.015), "b_olive")  # fender
	_b(m, Vector3(0.56, 0.0, 0.26), Vector3(0.12, 0.11, 0.17), "b_olive")  # pump cabinet
	_b(m, Vector3(0.56, 0.0, 0.44), Vector3(0.13, 0.12, 0.012), "gun")
	_b(m, Vector3(0.682, 0.0, 0.3), Vector3(0.006, 0.07, 0.07), "b_trim")
	_b(m, Vector3(0.69, 0.0, 0.33), Vector3(0.004, 0.05, 0.02), "lampglow")  # meter
	_b(m, Vector3(0.69, 0.0, 0.25), Vector3(0.004, 0.05, 0.03), "gun")
	_b(m, Vector3(0.55, 0.113, 0.28), Vector3(0.07, 0.004, 0.08), "red")
	_b(m, Vector3(0.55, -0.113, 0.28), Vector3(0.07, 0.004, 0.08), "red")
	var pts: Array[Vector3] = [Vector3(0.7, 0.08, 0.16), Vector3(0.8, 0.12, 0.05), Vector3(0.94, 0.14, 0.03), Vector3(1.04, 0.04, 0.03), Vector3(1.06, -0.12, 0.03)]
	for i in pts.size() - 1:
		_l(m, pts[i], pts[i + 1], 0.016, "b_black")
	_b(m, Vector3(1.1, -0.12, 0.05), Vector3(0.05, 0.016, 0.03), "steel")  # nozzle
	_l(m, Vector3(-0.55, 0.0, 0.17), Vector3(-0.8, 0.0, 0.06), 0.02, "gun")  # drawbar


## Latrine row: three plank outhouses back to back with doors on both sides, tin roofs and vent pipes.
static func _latrine(m: Array[Prim]) -> void:
	_b(m, Vector3(0.0, 0, 0.012), Vector3(0.62, 0.3, 0.012), "dirt")
	for i in 3:
		var x: float = -0.38 + 0.38 * float(i)
		_b(m, Vector3(x, 0, 0.27), Vector3(0.17, 0.2, 0.25), "wood")
		for k in 6:
			var xx: float = x - 0.14 + 0.056 * float(k)
			for s: float in [1.0, -1.0]:
				_b(m, Vector3(xx, s * 0.203, 0.27), Vector3(0.003, 0.004, 0.24), "woodd")
		for s: float in [1.0, -1.0]:
			_b(m, Vector3(x, s * 0.207, 0.22), Vector3(0.1, 0.005, 0.19), "woodd" if i != 1 else "b_olive")
			_b(m, Vector3(x + 0.07, s * 0.213, 0.2), Vector3(0.012, 0.004, 0.012), "steel")
			_b(m, Vector3(x, s * 0.213, 0.4), Vector3(0.025, 0.004, 0.02), "gun")  # moon vent
		_b(m, Vector3(x, 0, 0.55), Vector3(0.19, 0.24, 0.012), "b_gal")
		_c(m, Vector3(x - 0.08, 0.0, 0.7), 0.02, 0.13, "steel")
	_b(m, Vector3(0.0, 0, 0.575), Vector3(0.58, 0.02, 0.01), "b_gald")  # ridge strip
	_b(m, Vector3(0.82, 0.0, 0.03), Vector3(0.1, 0.16, 0.03), "b_gald")  # slop drum
	_c(m, Vector3(0.82, 0.0, 0.1), 0.06, 0.04, "b_drumg")


## Supply stack: two pallets, shrink-wrapped cartons and sacks.
static func _supply_stack(m: Array[Prim]) -> void:
	for px in [-0.2, 0.26]:
		_b(m, Vector3(px, 0.0, 0.04), Vector3(0.22, 0.19, 0.02), "woodd")
		for i in 3:
			_b(m, Vector3(px - 0.16 + 0.16 * float(i), 0.0, 0.015), Vector3(0.03, 0.18, 0.015), "wood")
	for layer in 3:
		for i in 2:
			for j in 2:
				var x: float = -0.31 + 0.22 * float(i)
				var y: float = -0.1 + 0.2 * float(j)
				var z: float = 0.1 + 0.115 * float(layer)
				if layer == 2 and i == 1 and j == 0:
					continue
				_b(m, Vector3(x, y, z), Vector3(0.1, 0.095, 0.052), "cardboard" if (i + j + layer) % 2 == 0 else "b_tan")
				_b(m, Vector3(x + 0.101, y, z), Vector3(0.004, 0.03, 0.02), "b_black")
	for z in [0.17, 0.33]:  # wrap bands
		_b(m, Vector3(-0.2, 0.0, z), Vector3(0.222, 0.2, 0.014), "b_wrap")
	for i in 7:  # sacks
		var layer: int = 0 if i < 4 else 1
		var px: float = 0.12 + 0.14 * float(i % 3) if layer == 0 else 0.19 + 0.14 * float(i % 2)
		var py: float = -0.08 + 0.16 * float(i % 2)
		_s(m, Vector3(px, py, 0.115 + 0.1 * float(layer)), Vector3(0.115, 0.085, 0.065), "b_sack")


## Ammunition pile: stencilled crates, a pallet of shell cases and a tarp thrown over a small stack.
static func _ammo_pile(m: Array[Prim]) -> void:
	_b(m, Vector3(0.0, 0.0, 0.012), Vector3(0.5, 0.4, 0.012), "dirt")
	for layer in 2:
		for i in 3:
			var x: float = -0.3 + 0.2 * float(i)
			if layer == 1 and i == 2:
				continue
			var z: float = 0.08 + 0.115 * float(layer)
			_b(m, Vector3(x, -0.2, z), Vector3(0.09, 0.13, 0.052), "ammo")
			_b(m, Vector3(x + 0.092, -0.2, z), Vector3(0.004, 0.09, 0.012), "b_yellow")
			_b(m, Vector3(x, -0.2 + 0.134, z), Vector3(0.06, 0.004, 0.012), "b_yellow")
			_b(m, Vector3(x, -0.2, z + 0.054), Vector3(0.092, 0.132, 0.004), "b_olive")
	_b(m, Vector3(0.12, 0.26, 0.03), Vector3(0.3, 0.14, 0.02), "woodd")  # pallet with shells
	for i in 4:
		for j in 2:
			var x: float = -0.02 + 0.095 * float(i)
			var y: float = 0.2 + 0.11 * float(j)
			_c(m, Vector3(x, y, 0.15), 0.04, 0.1, "brass")
			_c(m, Vector3(x, y, 0.255), 0.04, 0.012, "b_black")
			_s(m, Vector3(x, y, 0.27), Vector3(0.036, 0.036, 0.05), "warhead")
	_b(m, Vector3(0.38, -0.2, 0.06), Vector3(0.12, 0.2, 0.056), "ammo")  # small stack under a tarp
	_b(m, Vector3(0.38, -0.2, 0.118), Vector3(0.13, 0.21, 0.01), "b_tarp")
	_ry(m, Vector3(0.52, -0.2, 0.1), Vector3(0.07, 0.21, 0.01), "b_tarp", 0.9)
	_b(m, Vector3(0.38, 0.015, 0.075), Vector3(0.13, 0.012, 0.075), "b_tarp")


## Weapon rack: an open roofed shelter over a double-sided rack of leaning rifles, with ammo cans beneath.
static func _weapon_rack(m: Array[Prim]) -> void:
	_b(m, Vector3(0.0, 0.0, 0.012), Vector3(0.48, 0.28, 0.012), "dirt")
	for sx: float in [1.0, -1.0]:
		for sy: float in [1.0, -1.0]:
			_c(m, Vector3(0.44 * sx, 0.24 * sy, 0.34), 0.02, 0.34, "woodd")
	_gabx(m, Vector3(0, 0, 0), 0.44, 0.24, 0.68, 0.1, "b_roof", "b_roof", "b_gald", false, 0.08)
	_b(m, Vector3(0, 0, 0.1), Vector3(0.4, 0.07, 0.015), "woodd")  # base rail
	_b(m, Vector3(0, 0, 0.42), Vector3(0.4, 0.014, 0.018), "wood")  # top bar
	for sx: float in [1.0, -1.0]:
		_b(m, Vector3(0.36 * sx, 0, 0.26), Vector3(0.016, 0.016, 0.2), "woodd")
	for i in 6:
		var x: float = -0.32 + 0.128 * float(i)
		for s: float in [1.0, -1.0]:
			var top := Vector3(x, s * 0.03, 0.58)
			var bot := Vector3(x, s * 0.13, 0.1)
			_l(m, bot, top, 0.012, "gun")
			_l(m, bot, bot.lerp(top, 0.34), 0.019, "stock")
	_b(m, Vector3(0.0, 0.0, 0.06), Vector3(0.18, 0.05, 0.04), "ammo")


## Map table: trestle table with a pinned map and markers, a lamp on a bent arm, a radio and a stool.
static func _map_table(m: Array[Prim]) -> void:
	for sx: float in [1.0, -1.0]:
		for sy: float in [1.0, -1.0]:
			_b(m, Vector3(0.28 * sx, 0.18 * sy, 0.15), Vector3(0.02, 0.02, 0.15), "woodd")
	_b(m, Vector3(0, 0, 0.3), Vector3(0.34, 0.24, 0.02), "wood")
	_b(m, Vector3(0, 0, 0.325), Vector3(0.3, 0.2, 0.006), "b_paper")
	for i in 5:
		_b(m, Vector3(-0.24 + 0.12 * float(i), 0.0, 0.332), Vector3(0.002, 0.2, 0.002), "plasterc")
	for j in 3:
		_b(m, Vector3(0.0, -0.12 + 0.12 * float(j), 0.332), Vector3(0.3, 0.002, 0.002), "plasterc")
	var pins: Array[Vector2] = [Vector2(-0.12, -0.05), Vector2(0.06, 0.08), Vector2(0.14, -0.08)]
	for p in pins:
		_b(m, Vector3(p.x, p.y, 0.345), Vector3(0.02, 0.02, 0.012), "red")
	var pins2: Array[Vector2] = [Vector2(-0.2, 0.1), Vector2(-0.05, -0.1)]
	for p in pins2:
		_b(m, Vector3(p.x, p.y, 0.345), Vector3(0.02, 0.02, 0.012), "cont_blue")
	_l(m, Vector3(-0.1, -0.05, 0.334), Vector3(0.1, 0.08, 0.336), 0.004, "red")
	_b(m, Vector3(-0.22, -0.17, 0.35), Vector3(0.045, 0.03, 0.025), "b_olive")  # radio
	_l(m, Vector3(-0.2, -0.17, 0.375), Vector3(-0.2, -0.17, 0.55), 0.005, "steel")
	_b(m, Vector3(0.26, 0.15, 0.34), Vector3(0.025, 0.025, 0.012), "gun")  # lamp
	_l(m, Vector3(0.26, 0.15, 0.35), Vector3(0.26, 0.15, 0.5), 0.006, "gun")
	_l(m, Vector3(0.26, 0.15, 0.5), Vector3(0.12, 0.15, 0.56), 0.006, "gun")
	_b(m, Vector3(0.1, 0.15, 0.55), Vector3(0.04, 0.035, 0.015), "lampglow")
	_b(m, Vector3(0.1, 0.15, 0.57), Vector3(0.045, 0.04, 0.008), "gun")
	_c(m, Vector3(0.55, -0.1, 0.17), 0.09, 0.012, "wood")  # stool
	for a in 3:
		var an: float = float(a) * 2.1
		_l(m, Vector3(0.55 + cos(an) * 0.08, -0.1 + sin(an) * 0.08, 0.0), Vector3(0.55, -0.1, 0.17), 0.01, "woodd")


## Hazard warning sign: a red-bordered diamond on a post with an exclamation mark, plus a lower plate on each side.
static func _warning_sign(m: Array[Prim]) -> void:
	_c(m, Vector3(0, 0, 0.03), 0.07, 0.03, "concrete")
	_c(m, Vector3(-0.02, 0, 0.4), 0.022, 0.4, "steel")
	var d := Prim.new(Base.BOX, Vector3(0.012, 0, 0.78), Vector3(0.006, 0.14, 0.14), "red")
	d.basis = Basis(Vector3(1, 0, 0), PI * 0.25)
	m.append(d)
	var w := Prim.new(Base.BOX, Vector3(0.02, 0, 0.78), Vector3(0.006, 0.11, 0.11), "whitep")
	w.basis = Basis(Vector3(1, 0, 0), PI * 0.25)
	m.append(w)
	_b(m, Vector3(0.03, 0, 0.8), Vector3(0.004, 0.014, 0.05), "b_black")
	_b(m, Vector3(0.03, 0, 0.72), Vector3(0.004, 0.014, 0.014), "b_black")
	for s: float in [1.0, -1.0]:
		_b(m, Vector3(-0.02, s * 0.025, 0.4), Vector3(0.14, 0.006, 0.075), "red")
		_b(m, Vector3(-0.02, s * 0.03, 0.4), Vector3(0.12, 0.004, 0.058), "whitep")
		_b(m, Vector3(-0.02, s * 0.034, 0.42), Vector3(0.09, 0.004, 0.012), "red")
		_b(m, Vector3(-0.02, s * 0.034, 0.37), Vector3(0.07, 0.004, 0.008), "b_black")
		_b(m, Vector3(-0.02, s * 0.034, 0.345), Vector3(0.05, 0.004, 0.006), "b_black")


## Hazard drums: yellow, red and green drums with black bands and steel lids on a yellow-edged spill bund; one tipped over.
static func _hazard_drums(m: Array[Prim]) -> void:
	_b(m, Vector3(0, 0, 0.02), Vector3(0.55, 0.45, 0.02), "b_pad")
	for s: float in [1.0, -1.0]:
		_b(m, Vector3(0, s * 0.45, 0.05), Vector3(0.55, 0.018, 0.035), "b_yellow")
		_b(m, Vector3(s * 0.55, 0, 0.05), Vector3(0.018, 0.45, 0.035), "b_yellow")
	var drums: Array = [[-0.3, -0.22, "b_drumy"], [-0.3, 0.18, "b_drumr"], [-0.05, -0.25, "b_drumr"], [-0.04, 0.02, "b_drumy"], [-0.1, 0.28, "b_drumg"], [0.2, -0.2, "b_drumg"], [0.22, 0.08, "b_drumy"]]
	for d in drums:
		var x: float = d[0]
		var y: float = d[1]
		var mat: String = d[2]
		_c(m, Vector3(x, y, 0.19), 0.095, 0.15, mat)
		for z in [0.12, 0.28]:
			_c(m, Vector3(x, y, z), 0.099, 0.012, "b_black")
		_c(m, Vector3(x, y, 0.345), 0.075, 0.012, "steel")
		_c(m, Vector3(x, y, 0.36), 0.025, 0.012, "gun")
	_cx(m, Vector3(0.38, 0.28, 0.115), 0.095, 0.15, "b_drumr")
	_cx(m, Vector3(0.38, 0.28, 0.115), 0.099, 0.012, "b_black")


## Cable reel: a wooden drum with orange cable on its side, chocked, plus a loose coil of cable on the ground.
static func _cable_reel(m: Array[Prim]) -> void:
	for s: float in [1.0, -1.0]:
		_cyy(m, Vector3(-0.15, s * 0.17, 0.3), 0.3, 0.022, "wood")
		_cyy(m, Vector3(-0.15, s * 0.19, 0.3), 0.04, 0.012, "gun")
		_b(m, Vector3(-0.15, s * 0.17, 0.02), Vector3(0.07, 0.025, 0.02), "woodd")
	_cyy(m, Vector3(-0.15, 0.0, 0.3), 0.2, 0.15, "b_orange")
	for y in [-0.1, 0.0, 0.1]:
		_cyy(m, Vector3(-0.15, y, 0.3), 0.205, 0.012, "b_cable")
	_cyy(m, Vector3(-0.15, 0.0, 0.3), 0.06, 0.2, "gun")
	var n := 14
	for ring in 2:
		for i in n:
			var a0: float = TAU * float(i) / float(n)
			var a1: float = TAU * float(i + 1) / float(n)
			var r: float = 0.2 - 0.02 * float(ring)
			var z: float = 0.03 + 0.045 * float(ring)
			_l(m, Vector3(0.42 + cos(a0) * r, 0.06 + sin(a0) * r, z), Vector3(0.42 + cos(a1) * r, 0.06 + sin(a1) * r, z), 0.022, "b_orange")
	_l(m, Vector3(0.22, 0.06, 0.05), Vector3(0.0, 0.0, 0.07), 0.018, "b_orange")
	_l(m, Vector3(0.0, 0.0, 0.07), Vector3(-0.1, 0.1, 0.22), 0.018, "b_orange")


## Field kitchen: trailer with a stove body, two chimneys, steel pots, drop-down serving shelves and a canvas awning.
static func _field_kitchen(m: Array[Prim]) -> void:
	_b(m, Vector3(0, 0, 0.14), Vector3(0.55, 0.25, 0.02), "gun")
	for s: float in [1.0, -1.0]:
		_cyy(m, Vector3(-0.05, s * 0.29, 0.13), 0.13, 0.035, "track")
		_cyy(m, Vector3(-0.05, s * 0.32, 0.13), 0.07, 0.012, "steel")
		_b(m, Vector3(-0.05, s * 0.26, 0.27), Vector3(0.17, 0.045, 0.012), "b_olive")
		_b(m, Vector3(0.05, s * 0.33, 0.34), Vector3(0.28, 0.065, 0.012), "wood")  # serving shelf
		_b(m, Vector3(0.05, s * 0.27, 0.3), Vector3(0.28, 0.008, 0.04), "b_olive")
	_b(m, Vector3(-0.05, 0, 0.3), Vector3(0.5, 0.24, 0.14), "b_olive")
	_b(m, Vector3(0.0, 0, 0.445), Vector3(0.5, 0.25, 0.012), "gun")
	for s: float in [1.0, -1.0]:
		for i in 3:
			_b(m, Vector3(-0.3 + 0.2 * float(i), s * 0.244, 0.3), Vector3(0.07, 0.005, 0.08), "b_trim")
			_b(m, Vector3(-0.3 + 0.2 * float(i), s * 0.25, 0.3), Vector3(0.06, 0.004, 0.065), "b_olive")
	_b(m, Vector3(0.455, 0, 0.3), Vector3(0.006, 0.16, 0.1), "gun")
	_b(m, Vector3(0.462, 0.0, 0.34), Vector3(0.004, 0.04, 0.025), "lampglow")
	for i in 2:  # pots on the front hobs
		var px: float = 0.18 + 0.2 * float(i)
		_c(m, Vector3(px, 0.0, 0.52), 0.1, 0.06, "steel")
		_c(m, Vector3(px, 0.0, 0.585), 0.104, 0.012, "b_gal")
		_s(m, Vector3(px, 0.0, 0.6), Vector3(0.02, 0.02, 0.015), "gun")
	for i in 2:
		var py: float = -0.1 + 0.2 * float(i)
		_c(m, Vector3(-0.38, py, 0.78), 0.03, 0.33, "steel")
		_c(m, Vector3(-0.38, py, 1.1), 0.05, 0.012, "gun")
	_gabx(m, Vector3(-0.12, 0, 0), 0.34, 0.26, 0.7, 0.1, "tento", "tento", "", false, 0.06)
	for sx: float in [1.0, -1.0]:
		for sy: float in [1.0, -1.0]:
			_c(m, Vector3(-0.12 + 0.34 * sx, 0.27 * sy, 0.57), 0.013, 0.13, "woodd")
	_l(m, Vector3(0.55, 0.0, 0.16), Vector3(0.98, 0.0, 0.07), 0.02, "gun")  # drawbar
	_b(m, Vector3(1.0, 0.0, 0.05), Vector3(0.03, 0.03, 0.05), "gun")


## Medical tent: big pale tent, ridge along x, red crosses on both roof slopes and the +x gable, an awning over the entrance.
static func _medical_tent(m: Array[Prim]) -> void:
	var hx := 0.8
	var hy := 0.5
	var over := 0.07
	_b(m, Vector3(0, 0, 0.02), Vector3(hx + 0.1, hy + 0.1, 0.02), "dirt")
	_b(m, Vector3(0, 0, 0.21), Vector3(hx, hy, 0.19), "b_tentw")
	_gabx(m, Vector3(0, 0, 0), hx, hy, 0.4, 0.34, "b_tentw", "b_tentw", "", true, over)
	var span: float = hy + over
	var th: float = atan2(0.34, span)
	for s: float in [1.0, -1.0]:  # crosses on the slopes
		var cy: float = s * span * 0.5
		var cz: float = 0.4 + 0.34 * 0.5 + 0.045
		_rx(m, Vector3(0.1, cy, cz), Vector3(0.17, 0.17, 0.003), "whitep", -s * th)
		_rx(m, Vector3(0.1, cy, cz + 0.006), Vector3(0.14, 0.045, 0.003), "red", -s * th)
		_rx(m, Vector3(0.1, cy, cz + 0.006), Vector3(0.045, 0.14, 0.003), "red", -s * th)
		for i in 5:  # wall seams
			_b(m, Vector3(-0.64 + 0.32 * float(i), s * (hy + 0.003), 0.21), Vector3(0.006, 0.003, 0.18), "b_olive")
		_b(m, Vector3(0, s * (hy + 0.003), 0.04), Vector3(hx, 0.003, 0.03), "b_olive")
	_b(m, Vector3(hx + 0.012, 0, 0.2), Vector3(0.008, 0.2, 0.2), "b_black")  # entrance opening
	for s: float in [1.0, -1.0]:
		_b(m, Vector3(hx + 0.02, s * 0.27, 0.2), Vector3(0.008, 0.08, 0.2), "b_tentw")  # tied-back flaps
	_cross_x(m, hx - 0.01, 0.0, 0.55, 0.07)
	_ry(m, Vector3(hx + 0.2, 0, 0.4), Vector3(0.22, 0.34, 0.01), "b_tentw", 0.22)  # awning
	_b(m, Vector3(hx + 0.4, 0.0, 0.34), Vector3(0.008, 0.34, 0.035), "red")
	for s: float in [1.0, -1.0]:
		_c(m, Vector3(hx + 0.41, s * 0.32, 0.19), 0.014, 0.19, "woodd")
		_l(m, Vector3(hx + 0.41, s * 0.32, 0.02), Vector3(hx + 0.55, s * 0.5, 0.0), 0.004, "b_cable")
		_l(m, Vector3(-0.5, s * (hy + 0.06), 0.4), Vector3(-0.6, s * (hy + 0.28), 0.0), 0.004, "b_cable")
		_l(m, Vector3(0.45, s * (hy + over), 0.4), Vector3(0.5, s * (hy + 0.3), 0.0), 0.004, "b_cable")
	_b(m, Vector3(hx + 0.2, 0.52, 0.08), Vector3(0.09, 0.07, 0.07), "whitep")  # supply case


## Command tent: large canvas tent with a hooded entrance, a flag, whip antennas, a dish, sandbags and crates.
static func _command_tent(m: Array[Prim]) -> void:
	var hx := 1.1
	var hy := 0.85
	var over := 0.08
	_b(m, Vector3(0, 0, 0.02), Vector3(hx + 0.1, hy + 0.1, 0.02), "dirt")
	_b(m, Vector3(0, 0, 0.19), Vector3(hx, hy, 0.17), "tento")
	_gabx(m, Vector3(0, 0, 0), hx, hy, 0.36, 0.42, "tento", "tento", "", true, over)
	for s: float in [1.0, -1.0]:
		for i in 7:
			_b(m, Vector3(-0.9 + 0.3 * float(i), s * (hy + 0.003), 0.19), Vector3(0.006, 0.003, 0.165), "hull")
		_b(m, Vector3(0, s * (hy + 0.003), 0.045), Vector3(hx, 0.003, 0.03), "hull")
		_b(m, Vector3(-0.3, s * (hy + 0.004), 0.22), Vector3(0.13, 0.004, 0.07), "b_black")  # vent flap
		_b(m, Vector3(-0.3, s * (hy + 0.009), 0.3), Vector3(0.14, 0.006, 0.01), "hull")
	_b(m, Vector3(hx + 0.012, 0, 0.19), Vector3(0.008, 0.2, 0.17), "b_black")
	for s: float in [1.0, -1.0]:
		_b(m, Vector3(hx + 0.02, s * 0.34, 0.19), Vector3(0.008, 0.14, 0.17), "tento")
	_ry(m, Vector3(hx + 0.22, 0, 0.4), Vector3(0.24, 0.36, 0.012), "hull", 0.2)  # porch
	for s: float in [1.0, -1.0]:
		_c(m, Vector3(hx + 0.44, s * 0.34, 0.2), 0.015, 0.2, "woodd")
		_l(m, Vector3(hx + 0.44, s * 0.34, 0.02), Vector3(hx + 0.6, s * 0.6, 0.0), 0.004, "b_cable")
		_l(m, Vector3(0.6, s * (hy + over), 0.36), Vector3(0.66, s * (hy + 0.35), 0.0), 0.004, "b_cable")
		_l(m, Vector3(-0.6, s * (hy + over), 0.36), Vector3(-0.66, s * (hy + 0.35), 0.0), 0.004, "b_cable")
	_c(m, Vector3(0.9, 0.0, 1.0), 0.014, 0.22, "steel")  # flag
	_b(m, Vector3(0.9, 0.1, 1.12), Vector3(0.006, 0.1, 0.06), "red")
	_b(m, Vector3(0.9, 0.06, 1.12), Vector3(0.008, 0.03, 0.03), "whitep")
	_l(m, Vector3(-0.8, 0.0, 0.78), Vector3(-0.8, 0.0, 1.45), 0.01, "steel")  # whips
	_l(m, Vector3(-0.5, 0.0, 0.77), Vector3(-0.5, 0.0, 1.25), 0.008, "steel")
	_dish(m, Vector3(1.0, -1.15, 0.28), 0.14, 0.5, 0.0)
	_b(m, Vector3(hx + 0.3, 0.62, 0.05), Vector3(0.08, 0.14, 0.05), "sand")  # sandbags
	_b(m, Vector3(hx + 0.3, 0.46, 0.05), Vector3(0.08, 0.14, 0.05), "sand")
	_b(m, Vector3(hx + 0.3, 0.54, 0.14), Vector3(0.08, 0.14, 0.05), "sand")
	_b(m, Vector3(hx + 0.3, -0.58, 0.07), Vector3(0.1, 0.12, 0.07), "ammo")
	_b(m, Vector3(hx + 0.3, -0.58, 0.15), Vector3(0.1, 0.1, 0.01), "b_tarp")
	_b(m, Vector3(-0.2, -hy - 0.2, 0.12), Vector3(0.16, 0.1, 0.1), "hull")  # generator
	_b(m, Vector3(-0.2, -hy - 0.2, 0.235), Vector3(0.17, 0.11, 0.012), "gun")


## Shower tent: small canvas cubicle with duckboards, a water tank on a stand behind it and a pipe running down.
static func _shower_tent(m: Array[Prim]) -> void:
	_b(m, Vector3(0.05, 0, 0.015), Vector3(0.38, 0.32, 0.015), "dirt")
	_b(m, Vector3(0.1, 0, 0.19), Vector3(0.28, 0.24, 0.17), "tento")
	_gabx(m, Vector3(0.1, 0, 0), 0.28, 0.24, 0.36, 0.16, "tento", "tento", "", true, 0.05)
	_b(m, Vector3(0.39, 0, 0.17), Vector3(0.008, 0.1, 0.15), "b_black")
	for s: float in [1.0, -1.0]:
		_b(m, Vector3(0.395, s * 0.115, 0.17), Vector3(0.008, 0.045, 0.15), "tento")
	for i in 4:  # duckboards
		_b(m, Vector3(0.44 + 0.06 * float(i), 0.0, 0.03), Vector3(0.026, 0.12, 0.012), "wood")
	for sx: float in [1.0, -1.0]:
		for sy: float in [1.0, -1.0]:
			_l(m, Vector3(-0.35 + 0.16 * sx, 0.14 * sy, 0.0), Vector3(-0.35 + 0.13 * sx, 0.12 * sy, 0.62), 0.014, "steel")
	_b(m, Vector3(-0.35, 0, 0.63), Vector3(0.15, 0.14, 0.012), "gun")
	_c(m, Vector3(-0.35, 0, 0.78), 0.12, 0.14, "b_olive")
	_s(m, Vector3(-0.35, 0, 0.92), Vector3(0.12, 0.12, 0.04), "b_olive")
	_c(m, Vector3(-0.35, 0, 0.78), 0.125, 0.012, "gun")
	_c(m, Vector3(-0.35, 0.0, 0.5), 0.016, 0.12, "steel")
	_l(m, Vector3(-0.35, 0.0, 0.4), Vector3(-0.1, 0.0, 0.42), 0.014, "steel")
	_c(m, Vector3(-0.2, 0.2, 0.06), 0.05, 0.06, "steel")  # bucket
