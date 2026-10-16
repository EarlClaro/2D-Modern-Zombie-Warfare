extends RefCounted
## Theme pack: military vehicles (static, parked or posted map dressing, four diagonal facings, one frame).
## Loaded by tools/gen_sprites.gd, see docs/specs/art-pack-2.md and the contract in pack_nature.gd.
## Models are built at authoring scale (nose +x, 1 unit = 32 px, existing tank hull 0.92 long) and enlarged by the spec `k`.
## Cylinders: the renderer only draws a cylinder whose local +z axis points away from the camera, so a horizontal or
## tilted one (`_tube`) is emitted twice with opposite axes and exactly one of the pair is ever visible.

const Base = preload("res://tools/gen_sprites.gd")
const Prim = Base.Prim

const MATS := {
	"v_tan": ["8a7a50", "a89868", "c4b684"],
	"v_dgreen": ["26331c", "394a28", "4e633a"],
	"v_olive": ["46502e", "5f6c3d", "7b8a52"],
	"v_yellow": ["a67c12", "d9a521", "f5cf4a"],
	"v_blue": ["1c2a44", "2a4572", "5a8ad0"],
	"v_amber": ["b06a10", "f0a020", "ffd878"],
	"v_canvas": ["3e4a2c", "58683e", "74874f"],
	"v_canvasd": ["2a3320", "3c4a2c", "505f3a"],
	"v_pale": ["7a7a70", "a4a496", "c8c8b8"],
}

# dir, display name, k
const SETS := [
	["apc_wheeled", "Wheeled APC", 1.1],
	["ifv_tracked", "Tracked IFV", 1.1],
	["light_tank", "Light Tank", 1.15],
	["heavy_tank", "Heavy Tank", 1.0],
	["spg", "Self-Propelled Gun", 1.0],
	["mlrs_truck", "Rocket Launcher Truck", 1.0],
	["aa_vehicle", "Anti-Aircraft Vehicle", 1.05],
	["armored_car", "Armored Car", 1.2],
	["humvee", "Utility Vehicle", 1.25],
	["fuel_tanker", "Fuel Tanker", 1.05],
	["ambulance", "Field Ambulance", 1.1],
	["command_truck", "Command Truck", 1.05],
	["engineer_dozer", "Armored Dozer", 1.1],
	["recovery_truck", "Recovery Truck", 1.05],
	["troop_truck", "Troop Truck", 1.05],
]


static func specs() -> Array:
	var out: Array = []
	for s in SETS:
		out.append({"dir": s[0], "name": s[1], "cat": "vehicle", "auto": true, "k": s[2], "frames": 1, "columns": 1, "ss": 1, "facings": ["se", "nw", "sw", "ne"], "fades": false})
	return out


static func build(_host: Object, m: Array[Prim], unit: String, _frame: int) -> bool:
	match unit:
		"apc_wheeled":
			_apc(m)
		"ifv_tracked":
			_ifv(m)
		"light_tank":
			_light_tank(m)
		"heavy_tank":
			_heavy_tank(m)
		"spg":
			_spg(m)
		"mlrs_truck":
			_mlrs(m)
		"aa_vehicle":
			_aa(m)
		"armored_car":
			_armored_car(m)
		"humvee":
			_humvee(m)
		"fuel_tanker":
			_tanker(m)
		"ambulance":
			_ambulance(m)
		"command_truck":
			_command(m)
		"engineer_dozer":
			_dozer(m)
		"recovery_truck":
			_recovery(m)
		"troop_truck":
			_troop(m)
		_:
			return false
	return true


# ---- helpers -------------------------------------------------------------------------------------------

## Box from centre and half extents.
static func _b(m: Array[Prim], x: float, y: float, z: float, hx: float, hy: float, hz: float, mat: String, yaw: float = 0.0) -> void:
	Base._bx(m, Vector3(x, y, z), Vector3(hx, hy, hz), mat, yaw)


## The same box mirrored to both sides (y and -y).
static func _sym(m: Array[Prim], x: float, y: float, z: float, hx: float, hy: float, hz: float, mat: String) -> void:
	Base._bx(m, Vector3(x, y, z), Vector3(hx, hy, hz), mat)
	Base._bx(m, Vector3(x, -y, z), Vector3(hx, hy, hz), mat)


## Vertical cylinder.
static func _v(m: Array[Prim], x: float, y: float, z: float, r: float, hz: float, mat: String) -> void:
	Base._cy(m, Vector3(x, y, z), r, hz, mat)


## Cylinder of radius r from p0 to p1 (any direction), emitted twice with opposite axes (see the header note).
static func _tube(m: Array[Prim], p0: Vector3, p1: Vector3, r: float, mat: String) -> void:
	var v := p1 - p0
	var len := v.length()
	if len < 1e-5:
		return
	var z := v / len
	var up := Vector3(0, 0, 1) if absf(z.z) < 0.95 else Vector3(1, 0, 0)
	var x := up.cross(z).normalized()
	var y := z.cross(x)
	for s in [1.0, -1.0]:
		var pr := Prim.new(Base.CYL, (p0 + p1) * 0.5, Vector3(r, 0, len * 0.5), mat)
		pr.basis = Basis(x * s, y, z * s)
		m.append(pr)


## Thin strut or plate between two points.
static func _rod(m: Array[Prim], p0: Vector3, p1: Vector3, t: float, mat: String) -> void:
	Base._bone(m, p0, p1, t, t, mat)


## Road wheel / tyre with its axis along y: dark tyre, steel hub standing out on the outer side, nut.
static func _wheel(m: Array[Prim], x: float, y: float, r: float, hw: float) -> void:
	var s := 1.0 if y >= 0.0 else -1.0
	_tube(m, Vector3(x, y - s * hw, r), Vector3(x, y + s * hw, r), r, "track")
	_tube(m, Vector3(x, y - s * hw * 0.5, r), Vector3(x, y + s * (hw + 0.01), r), r * 0.55, "steel")
	_tube(m, Vector3(x, y, r), Vector3(x, y + s * (hw + 0.018), r), r * 0.22, "gun")


## One wheel per x in `xs` on both sides, at lateral offset y.
static func _wheels(m: Array[Prim], xs: Array, y: float, r: float, hw: float) -> void:
	for x in xs:
		_wheel(m, float(x), y, r, hw)
		_wheel(m, float(x), -y, r, hw)


## Tracked running gear on both sides: striped track belt with round ends, `n` road wheels, sprocket (+x), idler.
static func _tread(m: Array[Prim], x0: float, x1: float, y: float, tw: float, r: float, n: int) -> void:
	for s in [1.0, -1.0]:
		var yy: float = y * s
		m.append(Prim.new(Base.BOX, Vector3((x0 + x1) * 0.5, yy, r), Vector3((x1 - x0) * 0.5 - r, tw, r), "track", 0.0, 0.05))
		for xe in [x0 + r, x1 - r]:
			_tube(m, Vector3(xe, yy - tw, r), Vector3(xe, yy + tw, r), r, "track")
		var out: float = yy + s * (tw + 0.012)
		for i in n:
			var x: float = lerpf(x0 + 2.1 * r, x1 - 2.1 * r, float(i) / float(maxi(n - 1, 1)))
			_tube(m, Vector3(x, yy, r * 0.95), Vector3(x, out, r * 0.95), r * 0.8, "steel")
			_tube(m, Vector3(x, yy, r * 0.95), Vector3(x, out + s * 0.008, r * 0.95), r * 0.34, "gun")
		_tube(m, Vector3(x1 - r, yy, r), Vector3(x1 - r, out, r), r * 0.72, "steel")
		_tube(m, Vector3(x1 - r, yy, r), Vector3(x1 - r, out + s * 0.008, r), r * 0.3, "gun")
		_tube(m, Vector3(x0 + r, yy, r), Vector3(x0 + r, out, r), r * 0.72, "steel")
		_tube(m, Vector3(x0 + r, yy, r), Vector3(x0 + r, out + s * 0.008, r), r * 0.3, "gun")


## Sloped front plate: stepped fill under it (from `base`) plus the plate itself, rising from the low nose
## (xf, z_lo) to the high edge (xb, z_hi).
static func _ramp(m: Array[Prim], xf: float, xb: float, z_lo: float, z_hi: float, hy: float, base: float, mat: String, steps: int = 4) -> void:
	for i in steps:
		var x0: float = lerpf(xb, xf, float(i) / steps)
		var x1: float = lerpf(xb, xf, float(i + 1) / steps)
		var top: float = lerpf(z_hi, z_lo, (float(i) + 0.5) / steps) - 0.008
		_b(m, (x0 + x1) * 0.5, 0.0, (base + top) * 0.5, absf(x1 - x0) * 0.5, hy, (top - base) * 0.5, mat)
	Base._bone(m, Vector3(xf, 0, z_lo), Vector3(xb, 0, z_hi), hy, 0.011, mat)


## Stencil marking: three small white bars on both flanks at (x, |y|, z).
static func _stencil(m: Array[Prim], x: float, y: float, z: float, seed_i: int) -> void:
	for s in [1.0, -1.0]:
		for i in 3:
			var hh: float = 0.014 + 0.016 * Base._rnd(seed_i + i, 5)
			_b(m, x + 0.03 * i, s * (y + 0.004), z, 0.006, 0.003, hh, "whitep")
		_b(m, x + 0.03, s * (y + 0.004), z + 0.03, 0.03, 0.003, 0.005, "whitep")


## Camouflage patch lying on a surface at height z (a thin box in a second colour).
static func _camo(m: Array[Prim], x: float, y: float, z: float, hx: float, hy: float, mat: String) -> void:
	_b(m, x, y, z + 0.004, hx, hy, 0.004, mat)


## Camouflage patch on a flank: thin in y at lateral offset y, both sides, offset mirrored in x for variety.
static func _camo_side(m: Array[Prim], x: float, y: float, z: float, hx: float, hz: float, mat: String) -> void:
	_b(m, x, y + 0.003, z, hx, 0.003, hz, mat)
	_b(m, -x * 0.6, -(y + 0.003), z, hx, 0.003, hz, mat)


## Whip antenna on a small base.
static func _antenna(m: Array[Prim], x: float, y: float, z0: float, z1: float, lean: float = 0.04) -> void:
	_b(m, x, y, z0 + 0.012, 0.016, 0.016, 0.012, "gun")
	Base._bone(m, Vector3(x, y, z0), Vector3(x - lean, y, z1), 0.004, 0.004, "gun")


## Pair of headlights on the front face at x.
static func _lights(m: Array[Prim], x: float, y: float, z: float, s: float = 0.025) -> void:
	_sym(m, x, y, z, 0.006, s, s * 0.8, "lampglow")


## Truck cab: box with windscreen, side windows, grille and bumper. `hood` > 0 adds an engine bonnet in front.
static func _cab(m: Array[Prim], x: float, hx: float, hz: float, z0: float, hood: float, mat: String = "hull") -> void:
	var zc: float = z0 + hz
	_b(m, x, 0, zc, hx, 0.19, hz, mat)
	_b(m, x + hx * 0.02, 0, z0 + hz * 2.0 + 0.008, hx * 1.05, 0.2, 0.012, mat)  # roof lip
	_b(m, x + hx + 0.004, 0, z0 + hz * 1.4, 0.004, 0.16, hz * 0.42, "glass")  # windscreen
	_sym(m, x + hx * 0.1, 0.194, z0 + hz * 1.4, hx * 0.62, 0.004, hz * 0.4, "glass")
	_sym(m, x - hx * 0.55, 0.194, z0 + hz * 0.7, 0.004 + hx * 0.01, 0.004, hz * 0.55, "gun")  # door seam
	_sym(m, x + hx * 0.6, 0.225, z0 + hz * 1.45, 0.01, 0.014, hz * 0.4, "gun")  # mirror
	var xf: float = x + hx
	var zg: float = z0 + hz * 0.5
	if hood > 0.0:
		_b(m, x + hx + hood * 0.5, 0, z0 + hz * 0.62, hood * 0.5, 0.17, hz * 0.62, mat)
		_b(m, x + hx + hood * 0.5, 0, z0 + hz * 1.27, hood * 0.5, 0.14, 0.012, mat)
		xf = x + hx + hood
		zg = z0 + hz * 0.62
	_b(m, xf + 0.005, 0, zg, 0.005, 0.14, hz * 0.4, "gun")  # grille
	for i in 3:
		_b(m, xf + 0.011, 0, zg - 0.03 + 0.03 * i, 0.003, 0.12, 0.006, "steel")
	_lights(m, xf + 0.005, 0.15, zg + hz * 0.1)
	_b(m, xf + 0.02, 0, z0 + 0.04, 0.02, 0.21, 0.03, "gun")  # bumper


## Truck running gear: frame rails, wheels at `xs`, fenders over each wheel.
static func _chassis(m: Array[Prim], x_rear: float, x_front: float, xs: Array, r: float, y: float = 0.235) -> void:
	_b(m, (x_rear + x_front) * 0.5, 0, r + 0.05, (x_front - x_rear) * 0.5, 0.17, 0.05, "gun")
	_wheels(m, xs, y, r, 0.05)
	for x in xs:
		_sym(m, float(x), y, r * 2.0 + 0.02, r * 1.15, 0.062, 0.008, "hull")


## Hoop (rear canvas frame): arch from the side rails at height z up to the crown.
static func _hoop(m: Array[Prim], x: float, z: float, w: float, rise: float, mat: String) -> void:
	var pts: Array = [Vector3(x, -w, z), Vector3(x, -w * 0.68, z + rise * 0.82), Vector3(x, 0, z + rise), Vector3(x, w * 0.68, z + rise * 0.82), Vector3(x, w, z)]
	for i in 4:
		Base._bone(m, pts[i], pts[i + 1], 0.008, 0.008, mat)


# ---- wheeled and tracked armour ------------------------------------------------------------------------

## 8x8 armoured personnel carrier: sloped hull, four axles, small turret with a machine gun.
static func _apc(m: Array[Prim]) -> void:
	_wheels(m, [0.42, 0.14, -0.14, -0.42], 0.235, 0.1, 0.045)
	_b(m, -0.13, 0, 0.28, 0.47, 0.2, 0.17, "hull")
	_ramp(m, 0.6, 0.34, 0.2, 0.45, 0.2, 0.11, "hull")
	_b(m, -0.13, 0, 0.455, 0.46, 0.14, 0.008, "v_dgreen")  # roof plate
	for x in [0.42, 0.14, -0.14, -0.42]:
		_sym(m, x, 0.236, 0.22, 0.1, 0.055, 0.008, "hull")  # fenders
	Base._bone(m, Vector3(0.5, 0, 0.298), Vector3(0.43, 0, 0.358), 0.075, 0.018, "glass")  # driver vision block
	_v(m, 0.0, 0, 0.485, 0.15, 0.025, "hull")
	_v(m, -0.02, 0, 0.54, 0.12, 0.04, "hull")
	_b(m, 0.12, 0, 0.545, 0.03, 0.075, 0.04, "gun")
	_tube(m, Vector3(0.14, 0, 0.55), Vector3(0.52, 0, 0.55), 0.017, "gun")
	_tube(m, Vector3(0.14, 0, 0.55), Vector3(0.3, 0, 0.55), 0.027, "steel")
	_tube(m, Vector3(0.5, 0, 0.55), Vector3(0.545, 0, 0.55), 0.026, "gun")
	_v(m, -0.1, 0.06, 0.59, 0.035, 0.012, "gun")
	_v(m, 0.2, 0.1, 0.462, 0.04, 0.012, "gun")
	_sym(m, -0.03, 0.204, 0.28, 0.12, 0.003, 0.1, "v_dgreen")  # side doors
	_sym(m, 0.27, 0.204, 0.3, 0.003, 0.003, 0.1, "gun")
	_b(m, -0.604, 0, 0.28, 0.003, 0.15, 0.12, "v_dgreen")  # rear door
	_b(m, -0.607, 0.07, 0.32, 0.002, 0.04, 0.025, "gun")
	_lights(m, 0.6, 0.15, 0.2)
	_stencil(m, 0.14, 0.2, 0.36, 3)
	_camo(m, -0.3, 0.05, 0.463, 0.14, 0.07, "v_tan")
	_camo(m, 0.1, -0.08, 0.463, 0.1, 0.05, "v_dgreen")
	_camo_side(m, -0.32, 0.2, 0.34, 0.12, 0.05, "v_tan")
	_antenna(m, -0.5, 0.13, 0.458, 0.95, 0.06)
	_b(m, -0.4, -0.15, 0.48, 0.06, 0.04, 0.025, "gun")  # stowage box


## Tracked infantry fighting vehicle: boxy hull, side skirts, autocannon turret with an ATGM launcher.
static func _ifv(m: Array[Prim]) -> void:
	_tread(m, -0.56, 0.56, 0.27, 0.07, 0.1, 6)
	_b(m, -0.12, 0, 0.275, 0.44, 0.27, 0.095, "hull")
	_ramp(m, 0.58, 0.32, 0.2, 0.37, 0.27, 0.18, "hull")
	for i in 4:  # side skirt plates, seams show the track
		var xc: float = -0.38 + 0.25 * i
		_sym(m, xc, 0.385, 0.215, 0.115, 0.012, 0.085, "hull" if i % 2 == 0 else "v_olive")
	_b(m, -0.48, 0, 0.3, 0.003, 0.2, 0.08, "v_dgreen")
	_b(m, -0.12, 0, 0.375, 0.44, 0.26, 0.008, "v_dgreen")  # deck
	for i in 4:  # engine louvres
		_b(m, -0.38 + 0.05 * i, 0.0, 0.386, 0.012, 0.12, 0.004, "gun")
	_v(m, 0.02, 0.05, 0.4, 0.17, 0.02, "hull")
	_b(m, 0.0, 0.05, 0.46, 0.17, 0.15, 0.06, "hull")
	_b(m, 0.17, 0.05, 0.47, 0.025, 0.1, 0.045, "gun")  # mantlet
	_tube(m, Vector3(0.2, 0.07, 0.475), Vector3(0.62, 0.07, 0.475), 0.02, "gun")
	_tube(m, Vector3(0.2, 0.07, 0.475), Vector3(0.36, 0.07, 0.475), 0.03, "steel")
	_tube(m, Vector3(0.2, 0.0, 0.46), Vector3(0.4, 0.0, 0.46), 0.011, "gun")
	_b(m, -0.05, -0.17, 0.5, 0.07, 0.04, 0.045, "gun")  # ATGM launcher
	_tube(m, Vector3(-0.1, -0.17, 0.52), Vector3(0.04, -0.17, 0.52), 0.022, "gunc")
	_b(m, 0.1, 0.19, 0.5, 0.012, 0.03, 0.025, "glass")  # sight
	_v(m, -0.06, 0.12, 0.535, 0.045, 0.014, "gun")  # commander hatch
	_v(m, -0.28, 0.1, 0.388, 0.05, 0.012, "gun")  # troop hatches
	_v(m, -0.28, -0.1, 0.388, 0.05, 0.012, "gun")
	_tube(m, Vector3(-0.5, 0.2, 0.32), Vector3(-0.58, 0.2, 0.32), 0.022, "steel")  # exhaust
	_lights(m, 0.45, 0.2, 0.3, 0.02)
	_stencil(m, 0.1, 0.27, 0.34, 7)
	_camo(m, -0.25, 0.1, 0.383, 0.12, 0.08, "v_tan")
	_camo(m, 0.2, -0.12, 0.383, 0.1, 0.06, "v_dgreen")
	_camo(m, 0.0, 0.05, 0.522, 0.1, 0.07, "v_tan")
	_antenna(m, -0.4, -0.2, 0.383, 0.95, 0.05)
	_b(m, -0.4, 0.2, 0.41, 0.05, 0.03, 0.025, "gun")


## Light tank: low wedge turret, thin gun, five big road wheels.
static func _light_tank(m: Array[Prim]) -> void:
	_tread(m, -0.46, 0.46, 0.26, 0.055, 0.09, 5)
	_b(m, -0.1, 0, 0.21, 0.34, 0.21, 0.07, "hull")
	_ramp(m, 0.47, 0.25, 0.16, 0.28, 0.21, 0.14, "hull")
	_sym(m, 0.0, 0.3, 0.195, 0.4, 0.05, 0.008, "v_dgreen")  # fenders
	_sym(m, 0.4, 0.3, 0.205, 0.07, 0.05, 0.01, "hull")
	_b(m, -0.42, 0, 0.21, 0.003, 0.2, 0.06, "v_dgreen")
	for i in 3:
		_b(m, -0.3 + 0.07 * i, 0, 0.286, 0.015, 0.1, 0.005, "gun")  # engine deck grille
	_v(m, -0.05, 0, 0.3, 0.17, 0.02, "hull")
	_b(m, -0.08, 0, 0.35, 0.16, 0.12, 0.04, "hull")
	_b(m, 0.1, 0, 0.35, 0.05, 0.1, 0.035, "v_olive")
	_b(m, 0.15, 0, 0.35, 0.02, 0.055, 0.035, "gun")  # mantlet
	_tube(m, Vector3(0.16, 0, 0.35), Vector3(0.72, 0, 0.35), 0.018, "gun")
	_tube(m, Vector3(0.56, 0, 0.35), Vector3(0.63, 0, 0.35), 0.026, "steel")  # fume extractor
	_tube(m, Vector3(0.7, 0, 0.35), Vector3(0.74, 0, 0.35), 0.026, "gun")  # muzzle brake
	_v(m, -0.14, 0.07, 0.4, 0.045, 0.02, "hull")  # cupola
	_b(m, -0.14, 0.07, 0.425, 0.04, 0.04, 0.008, "gun")
	_tube(m, Vector3(-0.14, 0.09, 0.44), Vector3(-0.03, 0.09, 0.44), 0.01, "gun")  # cupola MG
	_v(m, -0.15, -0.07, 0.395, 0.04, 0.012, "gun")
	_b(m, 0.02, -0.12, 0.38, 0.025, 0.012, 0.012, "glass")
	_b(m, -0.28, -0.14, 0.4, 0.04, 0.05, 0.02, "v_tan")  # turret stowage
	_b(m, -0.2, 0.16, 0.31, 0.08, 0.02, 0.02, "track")  # spare track links on the glacis side
	_lights(m, 0.465, 0.15, 0.2, 0.02)
	_stencil(m, -0.12, 0.2, 0.24, 11)
	_camo(m, -0.25, 0.08, 0.294, 0.08, 0.1, "v_tan")
	_camo(m, 0.28, -0.05, 0.294, 0.05, 0.12, "v_dgreen")
	_camo(m, -0.08, 0.0, 0.393, 0.09, 0.06, "v_dgreen")
	_antenna(m, -0.3, 0.13, 0.39, 0.95, 0.05)


## Heavy main battle tank: big boxy hull in dark green, skirts, large angular turret, long barrel with bore evacuator,
## smoke dischargers.
static func _heavy_tank(m: Array[Prim]) -> void:
	_tread(m, -0.62, 0.6, 0.34, 0.09, 0.12, 6)
	_b(m, -0.1, 0, 0.3, 0.52, 0.3, 0.09, "v_dgreen")
	_ramp(m, 0.66, 0.42, 0.2, 0.39, 0.3, 0.21, "v_dgreen")
	for i in 5:  # skirt plates over the tracks
		_sym(m, -0.48 + 0.22 * i, 0.45, 0.25, 0.1, 0.014, 0.1, "v_dgreen" if i % 2 == 0 else "v_olive")
	_sym(m, 0.52, 0.45, 0.2, 0.07, 0.014, 0.06, "v_dgreen")
	_b(m, -0.6, 0, 0.3, 0.004, 0.28, 0.08, "gun")  # rear plate
	for i in 4:  # engine deck grille
		_b(m, -0.5 + 0.06 * i, 0.0, 0.396, 0.016, 0.16, 0.005, "gun")
	_v(m, -0.04, 0, 0.42, 0.26, 0.03, "v_dgreen")
	_b(m, -0.1, 0, 0.5, 0.3, 0.22, 0.08, "v_dgreen")  # turret
	_b(m, -0.38, 0, 0.5, 0.08, 0.2, 0.08, "v_dgreen")  # bustle
	_b(m, 0.25, 0, 0.5, 0.06, 0.16, 0.08, "v_dgreen")
	_b(m, 0.23, 0.2, 0.5, 0.07, 0.04, 0.08, "v_dgreen", 0.7)  # angled cheeks
	_b(m, 0.23, -0.2, 0.5, 0.07, 0.04, 0.08, "v_dgreen", -0.7)
	_b(m, -0.1, 0, 0.585, 0.3, 0.22, 0.008, "v_olive")  # roof
	_b(m, 0.32, 0, 0.5, 0.025, 0.1, 0.065, "gun")  # mantlet
	_tube(m, Vector3(0.34, 0, 0.5), Vector3(1.18, 0, 0.5), 0.034, "gun")
	_tube(m, Vector3(0.78, 0, 0.5), Vector3(0.92, 0, 0.5), 0.05, "steel")  # bore evacuator
	_tube(m, Vector3(1.16, 0, 0.5), Vector3(1.2, 0, 0.5), 0.042, "gun")  # muzzle ring
	_tube(m, Vector3(0.34, 0, 0.5), Vector3(0.5, 0, 0.5), 0.05, "gun")  # barrel shroud
	for s in [1.0, -1.0]:  # smoke dischargers: two banks of three
		for i in 3:
			_b(m, 0.19 + 0.01 * i, s * 0.115 - s * 0.0, 0.612, 0.006, 0.006, 0.012, "gunc")
		_b(m, 0.2, s * 0.115, 0.598, 0.02, 0.026, 0.01, "gun")
		_b(m, 0.11, s * 0.225, 0.52, 0.04, 0.005, 0.04, "gun")  # side stowage panel
	_v(m, -0.18, 0.1, 0.61, 0.06, 0.025, "v_dgreen")  # commander cupola
	_b(m, -0.18, 0.1, 0.64, 0.05, 0.05, 0.008, "glass")
	_tube(m, Vector3(-0.2, 0.14, 0.66), Vector3(-0.08, 0.14, 0.66), 0.012, "gun")
	_v(m, -0.2, -0.1, 0.595, 0.05, 0.012, "gun")  # loader hatch
	_b(m, 0.05, 0.1, 0.596, 0.03, 0.03, 0.012, "glass")  # gunner sight
	_b(m, -0.42, 0.0, 0.58, 0.06, 0.1, 0.03, "v_tan")  # bustle rack
	_b(m, -0.55, 0.15, 0.42, 0.045, 0.045, 0.03, "v_tan")  # jerry cans on the deck
	_b(m, -0.55, -0.15, 0.42, 0.045, 0.045, 0.03, "v_olive")
	_tube(m, Vector3(-0.64, 0.22, 0.34), Vector3(-0.72, 0.22, 0.34), 0.026, "steel")
	_lights(m, 0.66, 0.2, 0.22, 0.022)
	_stencil(m, 0.02, 0.3, 0.3, 21)
	_camo(m, -0.3, -0.1, 0.396, 0.12, 0.12, "v_tan")
	_camo(m, 0.2, 0.15, 0.396, 0.1, 0.1, "v_olive")
	_camo(m, -0.15, 0.05, 0.593, 0.14, 0.09, "v_tan")
	_antenna(m, -0.4, -0.18, 0.585, 1.05, 0.06)


## Self-propelled gun: tracked chassis, big rear-mounted turret, long barrel with a muzzle brake along the nose.
static func _spg(m: Array[Prim]) -> void:
	_tread(m, -0.66, 0.62, 0.32, 0.075, 0.1, 6)
	_b(m, -0.02, 0, 0.275, 0.58, 0.29, 0.085, "hull")
	_ramp(m, 0.66, 0.46, 0.2, 0.36, 0.29, 0.19, "hull")
	_b(m, -0.66, 0, 0.3, 0.004, 0.26, 0.08, "gun")
	_sym(m, 0.0, 0.405, 0.2, 0.5, 0.01, 0.022, "v_dgreen")  # side rails
	_b(m, 0.3, 0, 0.375, 0.1, 0.2, 0.008, "v_dgreen")  # driver deck
	_b(m, 0.34, 0.1, 0.4, 0.04, 0.06, 0.03, "hull")  # driver hatch block
	_b(m, 0.38, 0.1, 0.42, 0.01, 0.045, 0.012, "glass")
	_b(m, -0.28, 0, 0.5, 0.33, 0.255, 0.13, "hull")  # turret
	_b(m, -0.28, 0, 0.635, 0.3, 0.23, 0.008, "v_dgreen")
	Base._bone(m, Vector3(0.1, 0, 0.42), Vector3(0.05, 0, 0.6), 0.2, 0.012, "hull")  # sloped turret front
	_b(m, 0.04, 0, 0.52, 0.03, 0.2, 0.1, "hull")
	_b(m, 0.1, 0, 0.55, 0.035, 0.07, 0.06, "gun")  # mantlet
	_tube(m, Vector3(0.1, 0, 0.55), Vector3(1.0, 0, 0.62), 0.04, "gun")
	_tube(m, Vector3(0.45, 0, 0.58), Vector3(0.6, 0, 0.592), 0.05, "steel")  # fume extractor
	_tube(m, Vector3(0.98, 0, 0.618), Vector3(1.1, 0, 0.628), 0.055, "steel")  # muzzle brake
	for i in 3:
		_tube(m, Vector3(1.0 + 0.03 * i, 0, 0.62 + 0.002 * i), Vector3(1.012 + 0.03 * i, 0, 0.622 + 0.002 * i), 0.058, "gunc")
	_b(m, 0.4, 0, 0.4, 0.04, 0.05, 0.035, "gun")  # travel lock cradle
	_v(m, -0.4, 0.1, 0.66, 0.06, 0.025, "hull")  # hatches
	_v(m, -0.18, -0.12, 0.652, 0.05, 0.012, "gun")
	_tube(m, Vector3(-0.4, 0.1, 0.69), Vector3(-0.3, 0.1, 0.69), 0.012, "gun")  # AA machine gun
	_b(m, -0.58, 0, 0.5, 0.012, 0.18, 0.1, "gun")  # rear ammunition door
	_b(m, -0.6, 0, 0.5, 0.004, 0.16, 0.08, "v_dgreen")
	_b(m, -0.1, 0.27, 0.5, 0.04, 0.005, 0.05, "gun")  # stowage panel
	_sym(m, -0.45, 0.275, 0.57, 0.1, 0.02, 0.025, "v_tan")
	_lights(m, 0.66, 0.22, 0.22, 0.02)
	_stencil(m, 0.1, 0.29, 0.3, 31)
	_camo(m, -0.45, 0.1, 0.644, 0.1, 0.09, "v_tan")
	_camo(m, -0.1, -0.12, 0.644, 0.08, 0.08, "v_dgreen")
	_camo(m, 0.2, 0.08, 0.383, 0.08, 0.1, "v_tan")
	_antenna(m, -0.55, -0.2, 0.64, 1.05, 0.06)


## 6x6 multiple-rocket-launcher truck: cab-over, twelve-tube pod raised at the rear, stabiliser jacks.
static func _mlrs(m: Array[Prim]) -> void:
	_chassis(m, -0.7, 0.68, [0.5, -0.12, -0.44], 0.125)
	_cab(m, 0.52, 0.14, 0.15, 0.22, 0.0)
	_b(m, -0.2, 0, 0.3, 0.46, 0.19, 0.035, "gun")  # sub-frame
	_sym(m, -0.2, 0.2, 0.36, 0.44, 0.012, 0.05, "hull")  # side lockers
	_b(m, 0.2, 0, 0.5, 0.05, 0.1, 0.03, "hull")
	var t: float = 0.58  # elevation
	var rot := Basis(Vector3(0, 1, 0), -t)
	var pivot := Vector3(-0.58, 0, 0.4)
	var c: Vector3 = pivot + rot * Vector3(0.34, 0, 0.17)
	var shell := Prim.new(Base.BOX, c, Vector3(0.34, 0.2, 0.16), "hull")
	shell.basis = rot
	m.append(shell)
	for j in 3:
		for i in 4:
			var yl: float = (float(i) - 1.5) * 0.09
			var zl: float = (float(j) - 1.0) * 0.09
			var a: Vector3 = c + rot * Vector3(-0.3, yl, zl)
			var b: Vector3 = c + rot * Vector3(0.375, yl, zl)
			_tube(m, a, b, 0.034, "gunc")
			_tube(m, c + rot * Vector3(0.33, yl, zl), c + rot * Vector3(0.36, yl, zl), 0.046, "steel")
	# frame, elevating ram and rear jacks
	_rod(m, Vector3(-0.02, 0.17, 0.3), c + rot * Vector3(0.1, 0.15, -0.16), 0.012, "gun")
	_rod(m, Vector3(-0.02, -0.17, 0.3), c + rot * Vector3(0.1, -0.15, -0.16), 0.012, "gun")
	_tube(m, Vector3(-0.15, 0, 0.33), c + rot * Vector3(0.0, 0, -0.16), 0.022, "steel")
	_b(m, -0.6, 0, 0.36, 0.03, 0.2, 0.05, "gun")
	for s in [1.0, -1.0]:
		_rod(m, Vector3(-0.64, s * 0.2, 0.3), Vector3(-0.7, s * 0.3, 0.04), 0.014, "steel")
		_b(m, -0.7, s * 0.3, 0.03, 0.05, 0.04, 0.012, "gun")
	_b(m, -0.64, 0.0, 0.28, 0.01, 0.15, 0.06, "v_dgreen")
	_stencil(m, 0.48, 0.19, 0.31, 41)
	_camo(m, -0.2, 0.05, 0.337, 0.2, 0.1, "v_tan")
	_camo_side(m, 0.0, 0.2, 0.36, 0.12, 0.03, "v_tan")
	_antenna(m, 0.4, -0.17, 0.52, 1.0, 0.04)


## Anti-aircraft vehicle: tracked chassis, twin autocannon turret raised to fire, ammo boxes, radar dish on a mast.
static func _aa(m: Array[Prim]) -> void:
	_tread(m, -0.52, 0.52, 0.3, 0.065, 0.095, 5)
	_b(m, -0.04, 0, 0.27, 0.46, 0.27, 0.075, "hull")
	_ramp(m, 0.54, 0.34, 0.2, 0.345, 0.27, 0.195, "hull")
	_sym(m, 0.0, 0.37, 0.2, 0.46, 0.012, 0.03, "v_dgreen")
	_b(m, -0.48, 0, 0.28, 0.003, 0.22, 0.07, "gun")
	_v(m, -0.02, 0, 0.36, 0.22, 0.02, "hull")
	_b(m, -0.02, 0, 0.46, 0.25, 0.23, 0.08, "hull")  # turret
	_b(m, -0.02, 0, 0.545, 0.25, 0.23, 0.007, "v_dgreen")
	_b(m, 0.22, 0, 0.46, 0.025, 0.2, 0.06, "hull")
	_b(m, 0.2, 0.2, 0.46, 0.04, 0.03, 0.06, "hull", 0.6)
	_b(m, 0.2, -0.2, 0.46, 0.04, 0.03, 0.06, "hull", -0.6)
	for s in [1.0, -1.0]:  # twin guns, elevated
		_b(m, 0.26, s * 0.1, 0.48, 0.05, 0.045, 0.05, "gun")
		_tube(m, Vector3(0.28, s * 0.1, 0.49), Vector3(0.84, s * 0.1, 0.65), 0.019, "gun")
		_tube(m, Vector3(0.36, s * 0.1, 0.512), Vector3(0.5, s * 0.1, 0.552), 0.029, "steel")
		_tube(m, Vector3(0.8, s * 0.1, 0.639), Vector3(0.87, s * 0.1, 0.659), 0.025, "gun")
		_b(m, 0.0, s * 0.25, 0.47, 0.1, 0.03, 0.05, "ammo")  # ammo boxes
		_b(m, 0.0, s * 0.25, 0.47, 0.012, 0.032, 0.052, "gun")
	_b(m, 0.0, 0.0, 0.575, 0.1, 0.07, 0.012, "glass")  # gunner sight block
	_b(m, 0.02, 0.0, 0.556, 0.1, 0.08, 0.012, "v_dgreen")
	_tube(m, Vector3(-0.2, 0.0, 0.55), Vector3(-0.2, 0.0, 0.8), 0.018, "gun")  # radar mast
	var ax := Vector3(0.45, 0, 0.9).normalized()
	var dc := Vector3(-0.2, 0, 0.85)
	_tube(m, dc - ax * 0.015, dc + ax * 0.015, 0.1, "steel")  # dish
	_tube(m, dc + ax * 0.015, dc + ax * 0.035, 0.04, "gun")
	_tube(m, dc, dc + ax * 0.12, 0.01, "gun")  # feed horn
	_b(m, -0.3, 0.12, 0.575, 0.04, 0.05, 0.03, "gun")  # radar electronics
	_lights(m, 0.54, 0.2, 0.22, 0.02)
	_stencil(m, 0.08, 0.27, 0.3, 51)
	_camo(m, -0.3, -0.1, 0.554, 0.1, 0.1, "v_tan")
	_camo(m, 0.1, 0.12, 0.554, 0.06, 0.07, "v_olive")
	_camo(m, 0.3, 0.0, 0.358, 0.05, 0.1, "v_tan")
	_antenna(m, -0.36, -0.2, 0.545, 1.0, 0.05)


## 4x4 armoured scout car: sloped hull, small turret with a machine gun, spare wheel on the rear.
static func _armored_car(m: Array[Prim]) -> void:
	_wheels(m, [0.3, -0.3], 0.225, 0.105, 0.05)
	_b(m, -0.04, 0, 0.27, 0.42, 0.2, 0.1, "hull")
	_ramp(m, 0.52, 0.38, 0.24, 0.37, 0.2, 0.17, "hull")
	_b(m, -0.06, 0, 0.4, 0.3, 0.17, 0.035, "hull")  # cabin
	_b(m, -0.06, 0, 0.438, 0.28, 0.15, 0.006, "v_dgreen")
	Base._bone(m, Vector3(0.28, 0, 0.372), Vector3(0.24, 0, 0.4), 0.15, 0.012, "hull")
	_b(m, 0.39, 0, 0.345, 0.008, 0.12, 0.012, "glass")  # driver slit on the plate
	_sym(m, -0.04, 0.2, 0.405, 0.2, 0.004, 0.022, "glass")  # side vision slits
	_v(m, -0.1, 0, 0.465, 0.13, 0.03, "hull")
	_b(m, -0.1, 0, 0.5, 0.11, 0.1, 0.03, "hull")
	_b(m, 0.02, 0, 0.5, 0.025, 0.06, 0.03, "gun")
	_tube(m, Vector3(0.04, 0, 0.5), Vector3(0.4, 0, 0.5), 0.015, "gun")
	_tube(m, Vector3(0.04, 0, 0.5), Vector3(0.2, 0, 0.5), 0.024, "steel")
	_v(m, -0.15, 0.06, 0.535, 0.03, 0.01, "gun")
	for x in [0.3, -0.3]:
		_sym(m, x, 0.226, 0.225, 0.12, 0.055, 0.008, "hull")
	_b(m, 0.52, 0, 0.19, 0.03, 0.2, 0.025, "gun")  # bumper / bull bar
	_lights(m, 0.505, 0.13, 0.26, 0.022)
	_tube(m, Vector3(-0.47, 0, 0.3), Vector3(-0.51, 0, 0.3), 0.085, "track")  # spare wheel
	_tube(m, Vector3(-0.47, 0, 0.3), Vector3(-0.53, 0, 0.3), 0.04, "steel")
	_sym(m, -0.3, 0.21, 0.4, 0.07, 0.014, 0.04, "gun")  # stowage boxes
	_stencil(m, -0.02, 0.2, 0.3, 61)
	_camo(m, -0.25, 0.08, 0.44, 0.1, 0.08, "v_tan")
	_camo_side(m, -0.15, 0.2, 0.3, 0.12, 0.04, "v_tan")
	_antenna(m, -0.28, 0.14, 0.438, 0.95, 0.05)
	_antenna(m, -0.28, -0.14, 0.438, 0.8, 0.0)


# ---- light vehicles and trucks -------------------------------------------------------------------------

## Open-top utility vehicle: boxy, roof-mounted gun with a shield, roll cage, spare wheel and jerry cans.
static func _humvee(m: Array[Prim]) -> void:
	_wheels(m, [0.28, -0.26], 0.225, 0.09, 0.05)
	_b(m, 0.0, 0, 0.17, 0.45, 0.2, 0.05, "gun")
	_b(m, 0.3, 0, 0.27, 0.15, 0.2, 0.065, "hull")  # bonnet
	_b(m, 0.3, 0, 0.34, 0.14, 0.17, 0.012, "hull")
	_b(m, 0.452, 0, 0.27, 0.006, 0.16, 0.05, "gun")  # grille
	for i in 3:
		_b(m, 0.46, 0, 0.245 + 0.025 * i, 0.003, 0.14, 0.006, "steel")
	_lights(m, 0.455, 0.17, 0.3, 0.022)
	_b(m, 0.1, 0, 0.255, 0.012, 0.19, 0.06, "hull")  # scuttle
	Base._bone(m, Vector3(0.14, 0, 0.32), Vector3(0.1, 0, 0.44), 0.17, 0.008, "glass")  # windscreen
	Base._bone(m, Vector3(0.14, -0.17, 0.32), Vector3(0.1, -0.17, 0.44), 0.01, 0.01, "gun")
	Base._bone(m, Vector3(0.14, 0.17, 0.32), Vector3(0.1, 0.17, 0.44), 0.01, 0.01, "gun")
	_sym(m, -0.05, 0.195, 0.31, 0.15, 0.012, 0.075, "hull")  # doors / cab sides
	_b(m, -0.3, 0.0, 0.255, 0.15, 0.2, 0.025, "hull")  # load bed
	_sym(m, -0.3, 0.195, 0.31, 0.15, 0.012, 0.045, "hull")
	_b(m, -0.45, 0, 0.31, 0.012, 0.2, 0.045, "hull")
	_b(m, -0.1, 0.09, 0.3, 0.07, 0.065, 0.04, "ammo")  # seats
	_b(m, -0.1, -0.09, 0.3, 0.07, 0.065, 0.04, "ammo")
	_b(m, -0.18, 0.09, 0.37, 0.012, 0.065, 0.045, "ammo")
	_b(m, -0.18, -0.09, 0.37, 0.012, 0.065, 0.045, "ammo")
	for s in [1.0, -1.0]:  # roll cage
		Base._bone(m, Vector3(-0.2, s * 0.19, 0.35), Vector3(-0.2, s * 0.19, 0.55), 0.008, 0.008, "gun")
		Base._bone(m, Vector3(0.08, s * 0.185, 0.4), Vector3(-0.2, s * 0.19, 0.55), 0.008, 0.008, "gun")
	Base._bone(m, Vector3(-0.2, -0.19, 0.55), Vector3(-0.2, 0.19, 0.55), 0.008, 0.008, "gun")
	_tube(m, Vector3(-0.06, 0, 0.35), Vector3(-0.06, 0, 0.5), 0.02, "gun")  # gun pedestal
	_b(m, -0.04, 0, 0.54, 0.075, 0.03, 0.035, "gun")
	_tube(m, Vector3(0.02, 0, 0.545), Vector3(0.36, 0, 0.545), 0.015, "gun")
	_tube(m, Vector3(0.02, 0, 0.545), Vector3(0.17, 0, 0.545), 0.025, "steel")
	_b(m, 0.04, 0, 0.55, 0.012, 0.1, 0.07, "gun")  # shield
	_b(m, 0.04, 0, 0.6, 0.012, 0.1, 0.012, "steel")
	_tube(m, Vector3(-0.47, 0, 0.3), Vector3(-0.5, 0, 0.3), 0.085, "track")  # spare wheel
	_tube(m, Vector3(-0.47, 0, 0.3), Vector3(-0.52, 0, 0.3), 0.04, "steel")
	_b(m, -0.4, 0.14, 0.375, 0.035, 0.04, 0.045, "v_tan")  # jerry cans
	_b(m, -0.4, -0.14, 0.375, 0.035, 0.04, 0.045, "v_olive")
	_sym(m, -0.3, 0.225, 0.3, 0.02, 0.015, 0.03, "gun")
	_sym(m, 0.0, 0.226, 0.215, 0.5, 0.05, 0.008, "hull")
	_stencil(m, 0.0, 0.2, 0.31, 71)
	_camo(m, 0.3, 0.05, 0.354, 0.1, 0.1, "v_tan")
	_camo_side(m, -0.05, 0.2, 0.31, 0.09, 0.035, "v_tan")
	_antenna(m, -0.42, 0.18, 0.355, 0.95, 0.03)
	_antenna(m, -0.42, -0.18, 0.355, 0.8, 0.0)


## Fuel tanker: cab-over truck with a banded cylindrical tank, hazard stripes, dome hatch, ladder and hose reel.
static func _tanker(m: Array[Prim]) -> void:
	_chassis(m, -0.72, 0.68, [0.5, -0.18, -0.5], 0.12)
	_cab(m, 0.54, 0.14, 0.16, 0.2, 0.0)
	_b(m, -0.12, 0, 0.3, 0.6, 0.19, 0.03, "gun")
	_tube(m, Vector3(-0.64, 0, 0.5), Vector3(0.34, 0, 0.5), 0.19, "hull")  # tank
	for x in [-0.5, -0.1, 0.22]:
		_tube(m, Vector3(x - 0.012, 0, 0.5), Vector3(x + 0.012, 0, 0.5), 0.196, "steel")
	for i in 8:  # hazard stripe rings
		_tube(m, Vector3(-0.63 + 0.0 + 0.018 * i, 0, 0.5), Vector3(-0.612 + 0.018 * i, 0, 0.5), 0.196, "v_yellow" if i % 2 == 0 else "gun")
	for i in 4:
		_tube(m, Vector3(0.2 + 0.018 * i + 0.06, 0, 0.5), Vector3(0.218 + 0.018 * i + 0.06, 0, 0.5), 0.196, "v_yellow" if i % 2 == 0 else "gun")
	_v(m, -0.1, 0, 0.69, 0.065, 0.02, "steel")  # dome hatch
	_v(m, -0.1, 0, 0.715, 0.05, 0.012, "gun")
	_v(m, 0.1, 0, 0.69, 0.03, 0.012, "steel")
	for s in [1.0, -1.0]:  # handrail
		Base._bone(m, Vector3(-0.5, s * 0.1, 0.7), Vector3(0.2, s * 0.1, 0.7), 0.006, 0.006, "steel")
	Base._bone(m, Vector3(-0.5, -0.1, 0.7), Vector3(-0.5, 0.1, 0.7), 0.006, 0.006, "steel")
	for s in [1.0, -1.0]:  # side pipes and valves
		_tube(m, Vector3(-0.5, s * 0.205, 0.34), Vector3(0.24, s * 0.205, 0.34), 0.014, "steel")
		_b(m, -0.3, s * 0.215, 0.34, 0.025, 0.02, 0.035, "gun")
		_b(m, -0.45, s * 0.2, 0.28, 0.12, 0.03, 0.045, "gun")
	for i in 5:  # ladder
		_b(m, -0.655, -0.07 + 0.0, 0.34 + 0.07 * i, 0.006, 0.07, 0.006, "steel")
	_rod(m, Vector3(-0.655, -0.075, 0.3), Vector3(-0.655, -0.075, 0.68), 0.006, "steel")
	_rod(m, Vector3(-0.655, 0.075, 0.3), Vector3(-0.655, 0.075, 0.68), 0.006, "steel")
	_tube(m, Vector3(-0.72, -0.12, 0.27), Vector3(-0.72, 0.12, 0.27), 0.06, "gunc")  # hose reel
	_tube(m, Vector3(-0.72, -0.125, 0.27), Vector3(-0.72, -0.12, 0.27), 0.085, "steel")
	_tube(m, Vector3(-0.72, 0.12, 0.27), Vector3(-0.72, 0.125, 0.27), 0.085, "steel")
	_tube(m, Vector3(-0.72, 0.0, 0.27), Vector3(-0.72, 0.15, 0.27), 0.02, "v_yellow")
	_sym(m, 0.34, 0.1, 0.62, 0.006, 0.05, 0.02, "gun")
	_stencil(m, -0.12, 0.19, 0.5, 81)
	_camo(m, 0.55, 0.0, 0.363, 0.1, 0.1, "v_tan")
	_antenna(m, 0.45, -0.18, 0.4, 0.9, 0.0)


## Military ambulance: olive box body on a truck chassis, red cross on a white square on both flanks, roof and rear;
## light bar on the cab.
static func _ambulance(m: Array[Prim]) -> void:
	_chassis(m, -0.58, 0.6, [0.33, -0.3], 0.115)
	_cab(m, 0.34, 0.15, 0.14, 0.2, 0.14)
	_b(m, -0.22, 0, 0.43, 0.38, 0.2, 0.19, "hull")  # box body
	_b(m, -0.22, 0, 0.625, 0.4, 0.21, 0.012, "hull")  # roof lip
	for s in [1.0, -1.0]:
		_b(m, -0.22, s * 0.204, 0.45, 0.14, 0.004, 0.14, "whitep")  # white square
		_b(m, -0.22, s * 0.21, 0.45, 0.1, 0.004, 0.03, "red")  # red cross
		_b(m, -0.22, s * 0.21, 0.45, 0.03, 0.004, 0.1, "red")
		_b(m, -0.45, s * 0.204, 0.4, 0.002 + 0.0, 0.004, 0.17, "gun")  # panel seams
		_b(m, -0.02, s * 0.204, 0.4, 0.003, 0.004, 0.17, "gun")
	_b(m, -0.22, 0, 0.639, 0.14, 0.14, 0.004, "whitep")  # roof marking
	_b(m, -0.22, 0, 0.644, 0.1, 0.03, 0.004, "red")
	_b(m, -0.22, 0, 0.644, 0.03, 0.1, 0.004, "red")
	_b(m, -0.604, 0, 0.43, 0.004, 0.19, 0.17, "v_olive")  # rear doors
	_b(m, -0.609, 0, 0.43, 0.003, 0.003, 0.17, "gun")
	_b(m, -0.612, 0, 0.45, 0.003, 0.09, 0.09, "whitep")
	_b(m, -0.616, 0, 0.45, 0.003, 0.07, 0.02, "red")
	_b(m, -0.616, 0, 0.45, 0.003, 0.02, 0.07, "red")
	_b(m, -0.612, 0, 0.58, 0.004, 0.1, 0.03, "glass")
	_b(m, 0.34, 0, 0.634 + 0.01, 0.05, 0.12, 0.012, "gun")  # light bar base
	_b(m, 0.34, 0.07, 0.66, 0.035, 0.05, 0.02, "red")
	_b(m, 0.34, -0.07, 0.66, 0.035, 0.05, 0.02, "v_blue")
	_b(m, -0.35, 0.0, 0.655, 0.06, 0.05, 0.015, "steel")  # roof vent
	_b(m, -0.1, 0.205, 0.26, 0.05, 0.012, 0.03, "gun")  # step
	_b(m, -0.5, -0.2, 0.3, 0.07, 0.012, 0.05, "gun")
	_stencil(m, 0.12, 0.2, 0.3, 91)
	_antenna(m, 0.02, -0.17, 0.63, 1.0, 0.04)


## Command truck: box body with antennas, a satellite dish on the roof, a generator, a side awning on the left.
static func _command(m: Array[Prim]) -> void:
	_chassis(m, -0.66, 0.64, [0.46, -0.16, -0.46], 0.12)
	_cab(m, 0.5, 0.15, 0.15, 0.2, 0.1)
	_b(m, -0.2, 0, 0.47, 0.42, 0.2, 0.2, "hull")  # box body
	_b(m, -0.2, 0, 0.682, 0.43, 0.21, 0.012, "v_dgreen")
	_sym(m, -0.2, 0.204, 0.5, 0.2, 0.004, 0.06, "v_dgreen")  # service hatches
	_b(m, -0.2, -0.204, 0.45, 0.1, 0.004, 0.1, "gun")  # door
	_b(m, -0.06, 0.204, 0.4, 0.002 + 0.001, 0.004, 0.14, "gun")
	_b(m, -0.62, 0, 0.47, 0.004, 0.18, 0.18, "v_dgreen")
	_b(m, -0.62, 0, 0.55, 0.005, 0.06, 0.04, "glass")
	# roof gear: dish on a mast, generator, vents, antennas
	_tube(m, Vector3(-0.4, 0, 0.7), Vector3(-0.4, 0, 0.82), 0.022, "gun")
	var ax := Vector3(0.5, 0, 0.85).normalized()
	var dc := Vector3(-0.4, 0, 0.9)
	_tube(m, dc - ax * 0.015, dc + ax * 0.015, 0.12, "steel")
	_tube(m, dc + ax * 0.015, dc + ax * 0.03, 0.05, "gun")
	_rod(m, dc, dc + ax * 0.16, 0.008, "gun")
	_b(m, -0.4, 0, 0.77, 0.06, 0.06, 0.02, "gun")
	_b(m, -0.02, -0.08, 0.735, 0.12, 0.09, 0.04, "gun")  # generator
	_b(m, -0.02, -0.08, 0.735, 0.1, 0.07, 0.042, "v_tan")
	for i in 3:
		_b(m, -0.1 + 0.05 * i, -0.08, 0.778, 0.01, 0.06, 0.004, "gun")
	_tube(m, Vector3(0.08, -0.14, 0.76), Vector3(0.08, -0.14, 0.86), 0.014, "steel")  # exhaust
	_b(m, -0.2, 0.12, 0.7, 0.06, 0.05, 0.02, "steel")  # AC unit
	_v(m, -0.2, 0.12, 0.724, 0.035, 0.006, "gun")
	_antenna(m, -0.55, 0.16, 0.694, 1.15, 0.04)
	_antenna(m, -0.55, -0.16, 0.694, 1.0, 0.0)
	_antenna(m, 0.08, 0.17, 0.694, 0.95, 0.03)
	_antenna(m, 0.3, -0.12, 0.682, 1.1, 0.0)
	# side awning (left) on two poles
	Base._bone(m, Vector3(-0.2, 0.21, 0.64), Vector3(-0.2, 0.5, 0.52), 0.2, 0.01, "v_canvas")
	_rod(m, Vector3(-0.4, 0.49, 0.52), Vector3(-0.4, 0.49, 0.02), 0.01, "steel")
	_rod(m, Vector3(0.0, 0.49, 0.52), Vector3(0.0, 0.49, 0.02), 0.01, "steel")
	_b(m, -0.2, 0.34, 0.025, 0.2, 0.14, 0.012, "woodd")  # duckboards under the awning
	_b(m, -0.28, 0.38, 0.06, 0.05, 0.04, 0.04, "wood")  # folding table / crate
	_stencil(m, 0.4, 0.19, 0.35, 101)
	_camo_side(m, -0.3, 0.21, 0.5, 0.12, 0.05, "v_tan")


## Armoured bulldozer: blade and push arms at the front, armoured cab at the rear, exhaust stack, tracked.
static func _dozer(m: Array[Prim]) -> void:
	_tread(m, -0.5, 0.5, 0.3, 0.08, 0.12, 4)
	_b(m, -0.02, 0, 0.3, 0.46, 0.28, 0.08, "hull")  # chassis
	_b(m, 0.24, 0, 0.44, 0.2, 0.2, 0.12, "hull")  # engine hood
	_b(m, 0.24, 0, 0.56, 0.2, 0.2, 0.008, "v_dgreen")
	for i in 4:
		_b(m, 0.45, 0, 0.42 + 0.03 * i, 0.003, 0.16, 0.008, "gun")  # radiator grille
	_b(m, -0.2, 0, 0.55, 0.2, 0.21, 0.14, "hull")  # armoured cab
	_b(m, -0.2, 0, 0.7, 0.24, 0.24, 0.015, "v_dgreen")  # roof plate overhang
	_b(m, 0.005, 0, 0.58, 0.004, 0.14, 0.05, "glass")  # front slit
	_b(m, -0.2, 0.213, 0.6, 0.12, 0.004, 0.045, "glass")  # side slits
	_b(m, -0.2, -0.213, 0.6, 0.12, 0.004, 0.045, "glass")
	_b(m, -0.4, 0, 0.55, 0.004, 0.14, 0.05, "glass")
	_sym(m, -0.32, 0.213, 0.5, 0.0 + 0.003, 0.004, 0.1, "gun")  # door seam
	_tube(m, Vector3(0.12, 0.17, 0.5), Vector3(0.12, 0.17, 0.84), 0.022, "steel")  # exhaust stack
	_tube(m, Vector3(0.12, 0.17, 0.84), Vector3(0.12, 0.17, 0.88), 0.03, "gun")
	# blade
	_b(m, 0.66, 0, 0.26, 0.04, 0.4, 0.14, "v_olive")
	_b(m, 0.68, 0, 0.42, 0.06, 0.4, 0.015, "v_olive", 0.0)
	Base._bone(m, Vector3(0.62, 0, 0.4), Vector3(0.7, 0, 0.46), 0.4, 0.016, "hull")  # blade curl
	_b(m, 0.7, 0, 0.12, 0.012, 0.4, 0.03, "steel")  # cutting edge
	for i in 4:  # blade ribs
		_b(m, 0.708, -0.27 + 0.18 * i, 0.27, 0.006, 0.012, 0.12, "gun")
	for s in [1.0, -1.0]:
		Base._bone(m, Vector3(0.0, s * 0.33, 0.3), Vector3(0.62, s * 0.36, 0.22), 0.025, 0.04, "gun")  # push arms
		_tube(m, Vector3(0.3, s * 0.22, 0.52), Vector3(0.62, s * 0.34, 0.4), 0.018, "steel")  # lift rams
	# rear ripper
	_b(m, -0.54, 0, 0.36, 0.04, 0.22, 0.06, "gun")
	for s in [-0.12, 0.0, 0.12]:
		Base._bone(m, Vector3(-0.56, s, 0.38), Vector3(-0.66, s, 0.12), 0.018, 0.026, "gun")
	_lights(m, 0.45, 0.2, 0.52, 0.025)
	_stencil(m, 0.1, 0.26, 0.35, 111)
	_camo(m, 0.24, 0.0, 0.564, 0.14, 0.12, "v_tan")
	_camo(m, -0.2, 0.0, 0.715 + 0.0, 0.16, 0.14, "v_tan")
	_camo(m, -0.02, 0.1, 0.388, 0.1, 0.08, "v_tan")
	_antenna(m, -0.4, -0.2, 0.715, 1.0, 0.04)
	_v(m, -0.2, 0.12, 0.74, 0.03, 0.012, "lampglow")  # beacon
	_v(m, -0.2, 0.12, 0.725, 0.03, 0.005, "gun")


## Recovery truck: heavy truck with a winch drum, a crane boom with cable and hook, tool lockers and rear spade jacks.
static func _recovery(m: Array[Prim]) -> void:
	_chassis(m, -0.68, 0.64, [0.46, -0.14, -0.46], 0.125)
	_cab(m, 0.46, 0.15, 0.16, 0.22, 0.14)
	_b(m, -0.2, 0, 0.3, 0.46, 0.2, 0.03, "hull")  # flatbed floor
	_sym(m, -0.2, 0.2, 0.37, 0.44, 0.012, 0.045, "hull")
	_b(m, 0.17, 0, 0.4, 0.04, 0.2, 0.09, "hull")  # headboard
	_b(m, -0.47, 0, 0.35, 0.012, 0.2, 0.045, "hull")
	_sym(m, -0.1, 0.205, 0.37, 0.12, 0.004, 0.05, "gun")  # lockers
	_sym(m, -0.38, 0.205, 0.37, 0.1, 0.004, 0.05, "gun")
	_tube(m, Vector3(0.0, -0.13, 0.4), Vector3(0.0, 0.13, 0.4), 0.065, "gun")  # winch drum
	_tube(m, Vector3(0.0, -0.14, 0.4), Vector3(0.0, -0.13, 0.4), 0.09, "steel")
	_tube(m, Vector3(0.0, 0.13, 0.4), Vector3(0.0, 0.14, 0.4), 0.09, "steel")
	_tube(m, Vector3(0.0, -0.1, 0.4), Vector3(0.0, 0.1, 0.4), 0.075, "track")  # cable wrap
	# crane: slewing base, boom raised over the rear, cable and hook
	_v(m, -0.18, 0, 0.35, 0.09, 0.03, "gun")
	_b(m, -0.18, 0, 0.45, 0.1, 0.1, 0.07, "v_olive")
	var tip := Vector3(-0.66, 0, 0.9)
	Base._bone(m, Vector3(-0.2, 0, 0.5), tip, 0.04, 0.05, "hull")
	Base._bone(m, Vector3(-0.2, 0, 0.5), tip, 0.02, 0.06, "v_dgreen")
	for i in 5:  # lattice cross bars
		var f: float = 0.15 + 0.17 * i
		var p := Vector3(-0.2, 0, 0.5).lerp(tip, f)
		_b(m, p.x, p.y, p.z, 0.015, 0.055, 0.015, "gun")
	_rod(m, Vector3(-0.1, 0, 0.45), Vector3(-0.5, 0, 0.7), 0.012, "steel")  # boom ram
	_tube(m, tip + Vector3(0.0, 0, -0.02), tip + Vector3(0.0, 0, -0.34), 0.006, "steel")  # cable
	_b(m, tip.x, 0, tip.z - 0.36, 0.025, 0.02, 0.03, "gun")
	Base._bone(m, tip + Vector3(0.0, 0, -0.39), tip + Vector3(0.03, 0, -0.43), 0.01, 0.01, "steel")
	_tube(m, tip - Vector3(0.0, 0.05, 0), tip + Vector3(0.0, 0.05, 0), 0.025, "steel")  # sheave
	# rear spade jacks
	_b(m, -0.7, 0, 0.3, 0.025, 0.2, 0.05, "gun")
	for s in [1.0, -1.0]:
		_rod(m, Vector3(-0.7, s * 0.2, 0.3), Vector3(-0.76, s * 0.3, 0.05), 0.015, "steel")
		_b(m, -0.76, s * 0.3, 0.035, 0.05, 0.05, 0.012, "gun")
	_v(m, 0.4, 0.0, 0.62, 0.035, 0.015, "v_amber")  # beacon
	_v(m, 0.4, 0.0, 0.6, 0.04, 0.004, "gun")
	_sym(m, -0.3, 0.215, 0.25, 0.04, 0.02, 0.03, "gun")
	_stencil(m, 0.1, 0.2, 0.37, 121)
	_camo(m, -0.2, 0.0, 0.333, 0.3, 0.14, "v_tan")
	_camo_side(m, 0.46, 0.19, 0.38, 0.07, 0.07, "v_tan")
	_antenna(m, 0.34, -0.17, 0.62, 0.95, 0.0)


## Canvas-covered 6x6 troop carrier: tall cab, arched canvas with ribs, open rear showing bench seats, spare wheel.
static func _troop(m: Array[Prim]) -> void:
	_chassis(m, -0.66, 0.62, [0.46, -0.12, -0.44], 0.125)
	_cab(m, 0.46, 0.17, 0.2, 0.22, 0.1)
	_b(m, -0.2, 0, 0.28, 0.44, 0.2, 0.02, "woodd")  # bed floor
	_sym(m, -0.2, 0.2, 0.37, 0.44, 0.012, 0.085, "hull")  # side boards
	_b(m, 0.18, 0, 0.4, 0.014, 0.2, 0.11, "hull")  # headboard
	_b(m, -0.64, 0, 0.32, 0.01, 0.2, 0.04, "wood")  # tailgate
	_sym(m, -0.28, 0.14, 0.34, 0.3, 0.04, 0.02, "wood")  # bench seats
	_sym(m, -0.28, 0.186, 0.42, 0.3, 0.008, 0.045, "woodd")  # backs
	_tube(m, Vector3(-0.36, 0, 0.46), Vector3(0.17, 0, 0.46), 0.205, "v_canvas")  # canvas arch
	for x in [-0.33, -0.2, -0.07, 0.06, 0.15]:
		_tube(m, Vector3(x - 0.007, 0, 0.46), Vector3(x + 0.007, 0, 0.46), 0.212, "v_canvasd")
	for x in [-0.46, -0.58]:
		_hoop(m, x, 0.46, 0.2, 0.2, "woodd")
	_b(m, 0.13, 0, 0.675, 0.04, 0.12, 0.01, "v_canvasd")  # front canvas lip
	_tube(m, Vector3(-0.35, -0.12, 0.61), Vector3(-0.35, 0.12, 0.61), 0.02, "v_canvasd")  # rolled flap
	_tube(m, Vector3(0.26, 0.21, 0.3), Vector3(0.26, 0.21, 0.74), 0.015, "steel")  # exhaust
	_tube(m, Vector3(0.0, 0.215, 0.43), Vector3(0.0, 0.265, 0.43), 0.095, "track")  # spare wheel on the left
	_tube(m, Vector3(0.0, 0.215, 0.43), Vector3(0.0, 0.275, 0.43), 0.045, "steel")
	_sym(m, -0.4, 0.215, 0.24, 0.07, 0.025, 0.04, "gun")
	_stencil(m, 0.4, 0.19, 0.42, 131)
	_camo_side(m, -0.28, 0.215, 0.37, 0.12, 0.04, "v_dgreen")
	_antenna(m, 0.36, -0.17, 0.62, 0.9, 0.0)
