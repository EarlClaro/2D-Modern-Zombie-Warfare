extends RefCounted
## Theme pack: airforce (static aircraft: parked on helipads, runways and aprons, or crashed in the field). Loaded by
## tools/gen_sprites.gd, see docs/specs/art-pack-2.md. Pack contract: MATS (extra palette, prefix `a_`), specs(), build().
## Everything is static (no flight, no spinning rotors); rotor and propeller blades are thin flat boxes held still.
## Models are authored at their real tile size (a fighter is 2.2 long, the tank hull 0.92), k = 1. Nose is +x.
## Wing, fin and blade parts go through `_slab`/`_wing` (a box whose long axis runs between two points and whose
## width is measured across the chord); fuselages are chains of ellipsoids (`_tube`).

const Base = preload("res://tools/gen_sprites.gd")
const Prim = Base.Prim
const FACINGS := ["se", "nw", "sw", "ne"]

const MATS := {
	"a_grey": ["4f565e", "7a838c", "a4aeb7"],
	"a_greyd": ["2c3237", "434a51", "5d656d"],
	"a_greyl": ["6c747c", "9aa3ab", "c3cbd2"],
	"a_tan": ["8a7650", "b39d6e", "d3c08e"],
	"a_olive": ["3b4526", "56623a", "73834f"],
	"a_olived": ["2a3319", "3b4727", "505f36"],
	"a_drab": ["4c5035", "6c7250", "8e966c"],
	"a_char": ["262b32", "3a414a", "525b66"],
	"a_charl": ["3c434c", "58616c", "7a8591"],
	"a_gun": ["1d2328", "2f383f", "465259"],
	"a_white": ["a2a8ac", "d0d5d7", "f0f2f2"],
	"a_black": ["0a0b0c", "141618", "212528"],
	"a_dark": ["050708", "0b0e10", "12171a"],
	"a_nozzle": ["3a342e", "5c5348", "85796a"],
	"a_canopy": ["15324a", "2b6c96", "86cdf0"],
	"a_yellow": ["9a7c0c", "d6b21e", "f5dc54"],
	"a_blue": ["1a3678", "2956b0", "4a80da"],
	"a_missile": ["a8aeb0", "d6dadb", "f4f6f6"],
	"a_alu": ["666c70", "959b9f", "c0c6c9"],
	"a_scorch": ["0b0a09", "131110", "1d1a17"],
	"a_charm": ["101112", "1b1d1f", "2b2e31"],
	"a_charolive": ["14160f", "1e2218", "2c3024"],
	"a_chartan": ["211c14", "30291d", "433a29"],
}

# material -> burnt-out version (crashed sets char parts of the airframe, not all of it)
const BURN := {
	"a_grey": "a_charm", "a_greyd": "a_charm", "a_greyl": "a_charm", "a_tan": "a_chartan", "a_olive": "a_charolive",
	"a_olived": "a_charolive", "a_drab": "a_charolive", "a_white": "a_charm", "a_yellow": "a_chartan", "a_blue": "a_charm",
	"a_missile": "a_chartan", "a_canopy": "a_charm", "a_gun": "a_charm",
}


static func _spec(dir: String, nm: String, foot: Vector2i, glow: Array = []) -> Dictionary:
	var s := {"dir": dir, "name": nm, "cat": "aircraft", "auto": true, "k": 1.0, "frames": 1, "columns": 1, "ss": 1, "facings": FACINGS, "foot": foot, "fades": false}
	if not glow.is_empty():
		s["glow"] = glow
	return s


static func specs() -> Array:
	return [
		_spec("air_fighter_jet", "Fighter Jet", Vector2i(3, 2)),
		_spec("air_parked_fighter_camo", "Camouflaged Fighter", Vector2i(3, 2)),
		_spec("air_attack_jet", "Attack Jet", Vector2i(3, 2)),
		_spec("air_bomber", "Stealth Bomber", Vector2i(5, 5)),
		_spec("air_cargo_plane", "Cargo Plane", Vector2i(5, 5)),
		_spec("air_transport_heli", "Transport Helicopter", Vector2i(3, 2)),
		_spec("air_gunship_heli", "Gunship Helicopter", Vector2i(2, 2)),
		_spec("air_utility_heli", "Utility Helicopter", Vector2i(2, 2)),
		_spec("air_tiltrotor", "Tiltrotor", Vector2i(3, 3)),
		_spec("air_drone_uav", "Drone", Vector2i(2, 3)),
		_spec("air_light_plane", "Light Plane", Vector2i(2, 2)),
		_spec("air_crashed_jet", "Crashed Jet", Vector2i(3, 3), [Vector3(0.1, 0.0, 0.25), 70.0, Color(1.0, 0.5, 0.15)]),
		_spec("air_crashed_heli", "Crashed Helicopter", Vector2i(2, 2), [Vector3(0.0, 0.0, 0.2), 54.0, Color(1.0, 0.5, 0.15)]),
		_spec("air_crashed_cargo", "Crashed Cargo Plane", Vector2i(5, 5), [Vector3(-0.4, 0.0, 0.5), 110.0, Color(1.0, 0.5, 0.15)]),
	]


static func build(_host: Object, m: Array[Prim], unit: String, _frame: int) -> bool:
	match unit:
		"air_fighter_jet":
			_fighter(m, false)
		"air_parked_fighter_camo":
			_fighter(m, true)
		"air_attack_jet":
			_attack_jet(m)
		"air_bomber":
			_bomber(m)
		"air_cargo_plane":
			_cargo(m)
		"air_transport_heli":
			_transport_heli(m)
		"air_gunship_heli":
			_gunship(m)
		"air_utility_heli":
			_utility_heli(m)
		"air_tiltrotor":
			_tiltrotor(m)
		"air_drone_uav":
			_drone(m)
		"air_light_plane":
			_light_plane(m)
		"air_crashed_jet":
			_crashed_jet(m)
		"air_crashed_heli":
			_crashed_heli(m)
		"air_crashed_cargo":
			_crashed_cargo(m)
		_:
			return false
	return true


# ---- helpers ----------------------------------------------------------------------------------------------

## Box whose long axis runs p0 -> p1. `hw` is the half width across the axis towards `hint` (the chord direction for
## wings and fins, default +x), `ht` the half thickness perpendicular to both.
static func _slab(l: Array[Prim], p0: Vector3, p1: Vector3, hw: float, ht: float, mat: String, hint: Vector3 = Vector3(1, 0, 0)) -> void:
	var v := p1 - p0
	var length := v.length()
	if length < 1e-5:
		return
	var ax := v / length
	var wd := hint - ax * hint.dot(ax)
	if wd.length() < 1e-3:
		wd = Vector3(0, 0, 1) - ax * ax.z
	wd = wd.normalized()
	var td := ax.cross(wd)
	var pr := Prim.new(Base.BOX, (p0 + p1) * 0.5, Vector3(length * 0.5, hw, ht), mat)
	pr.basis = Basis(ax, wd, td)
	l.append(pr)


## Tapered wing or fin from p0 to p1 (points on the mid-chord line) with streamwise chords c0 -> c1, in `n` segments.
static func _wing(l: Array[Prim], p0: Vector3, p1: Vector3, c0: float, c1: float, ht: float, mat: String, n: int = 3) -> void:
	var ax := (p1 - p0).normalized()
	var cosf := sqrt(maxf(1.0 - ax.x * ax.x, 0.0))
	for i in n:
		var t0 := float(i) / float(n)
		var t1 := float(i + 1) / float(n)
		var a := p0.lerp(p1, t0)
		var b := p0.lerp(p1, t1)
		var c := lerpf(c0, c1, (t0 + t1) * 0.5)
		_slab(l, a, b + (b - a) * 0.03, c * 0.5 * cosf, ht, mat)


## Fuselage or nacelle: a chain of `n` overlapping ellipsoids between x0 and x1 (radii ry, rz).
static func _tube(l: Array[Prim], x0: float, x1: float, y: float, z: float, ry: float, rz: float, mat: String, n: int = 4) -> void:
	var step := (x1 - x0) / float(n)
	for i in n:
		Base._sp(l, Vector3(x0 + step * (float(i) + 0.5), y, z), Vector3(step * 0.8, ry, rz), mat)


## Rotor held still: `arms` flat blades from the hub, tips drooped by `droop`.
static func _rotor(l: Array[Prim], c: Vector3, r: float, arms: int, droop: float, phase: float, hw: float = 0.05, mat: String = "rotor") -> void:
	for i in arms:
		var a := phase + TAU * float(i) / float(arms)
		var d := Vector3(cos(a), sin(a), 0.0)
		_slab(l, c, c + d * r + Vector3(0, 0, -droop), hw, 0.016, mat, Vector3(-d.y, d.x, 0.0))
	Base._cy(l, c + Vector3(0, 0, 0.0), 0.05, 0.025, "a_greyd")


## Propeller disc standing in the y-z plane (a still prop): `blades` full-diameter blades.
static func _prop(l: Array[Prim], c: Vector3, r: float, blades: int, phase: float = 0.3) -> void:
	for i in blades:
		var a := phase + PI * float(i) / float(blades)
		var d := Vector3(0.0, cos(a), sin(a))
		_slab(l, c - d * r, c + d * r, 0.012, 0.034, "a_black", Vector3(1, 0, 0))
	Base._sp(l, c + Vector3(0.015, 0, 0), Vector3(0.05, 0.045, 0.045), "a_greyl")


## Missile or bomb with a nose cap and tail fins, from p0 (tail) to p1 (nose).
static func _missile(l: Array[Prim], p0: Vector3, p1: Vector3, r: float, mat: String = "a_missile", tip: String = "a_greyd") -> void:
	_slab(l, p0, p1, r, r, mat, Vector3(0, 1, 0))
	Base._sp(l, p1, Vector3(r * 1.7, r, r), tip)
	Base._bx(l, p0 + Vector3(0.015, 0, 0), Vector3(r * 1.5, r * 2.4, 0.006), "a_greyd")
	Base._bx(l, p0 + Vector3(0.015, 0, 0), Vector3(r * 1.5, 0.006, r * 2.4), "a_greyd")


## Landing-gear leg from `top` to a wheel on the ground at (x, y), wheel radius `wr`.
static func _leg(l: Array[Prim], top: Vector3, x: float, y: float, wr: float) -> void:
	_slab(l, top, Vector3(x, y, wr), 0.015, 0.015, "a_greyl", Vector3(1, 0, 0))
	Base._sp(l, Vector3(x, y, wr), Vector3(wr, wr * 0.55, wr), "a_black")
	Base._sp(l, Vector3(x, y, wr), Vector3(wr * 0.5, wr * 0.62, wr * 0.5), "a_greyl")


## Swaps a share of the parts to their burnt-out materials (patchy char: the rest keeps its paint).
static func _burn(l: Array[Prim], frac: float, seed_k: int) -> void:
	for i in l.size():
		if Base._rnd(i, seed_k) < frac:
			l[i].mat = BURN.get(l[i].mat, l[i].mat)


## Scattered wreckage on the ground: flat slabs and chunks around (cx, cy) within radius r.
static func _debris(l: Array[Prim], cx: float, cy: float, r: float, count: int, seed_k: int) -> void:
	var mats := ["a_charm", "a_alu", "a_greyd", "a_charolive", "a_charm"]
	for i in count:
		var a := Base._rnd(i, seed_k) * TAU
		var d := r * (0.35 + 0.65 * Base._rnd(i, seed_k + 1))
		var c := Vector3(cx + cos(a) * d, cy + sin(a) * d, 0.02 + 0.02 * Base._rnd(i, seed_k + 2))
		var h := Vector3(0.05 + 0.1 * Base._rnd(i, seed_k + 3), 0.03 + 0.07 * Base._rnd(i, seed_k + 4), 0.012 + 0.012 * Base._rnd(i, seed_k + 5))
		Base._bx(l, c, h, mats[i % mats.size()], Base._rnd(i, seed_k + 6) * PI)


## Rising smoke: `n` puffs growing and drifting upwards from `base` (r0 = first radius), irregular so it is not a stack of balls.
static func _smoke(l: Array[Prim], base: Vector3, n: int, r0: float, seed_k: int) -> void:
	var z := base.z
	for i in n:
		var r := r0 * (1.0 + 0.28 * float(i))
		var off := Vector3((Base._rnd(i, seed_k) - 0.5) * r * 1.1 + 0.04 * float(i), (Base._rnd(i, seed_k + 1) - 0.5) * r * 1.1, 0.0)
		Base._sp(l, Vector3(base.x, base.y, z) + off, Vector3(r * 1.1, r, r * 0.85), "smoke")
		z += r * 1.05


## Ground scorch plus churned earth: flat dark ellipse and a few dirt mounds.
static func _scorch_ground(l: Array[Prim], c: Vector3, rx: float, ry: float) -> void:
	Base._sp(l, Vector3(c.x, c.y, 0.0), Vector3(rx, ry, 0.014), "a_scorch")
	Base._sp(l, Vector3(c.x + rx * 0.35, c.y - ry * 0.25, 0.0), Vector3(rx * 0.55, ry * 0.5, 0.012), "a_scorch")


# ---- fighter ------------------------------------------------------------------------------------------------

## Delta-ish swept-wing fighter, twin canted tails, side intakes, missiles. `camo` = tan scheme with patches and
## wing-tip tanks. `g` lets the crashed version split the airframe: groups "nose", "wr" (right wing) and "fin_r".
static func _fighter(m: Array[Prim], camo: bool, gear: bool = true, g: Dictionary = {}) -> void:
	var nose: Array[Prim] = g.get("nose", m)
	var wr: Array[Prim] = g.get("wr", m)
	var fr: Array[Prim] = g.get("fin_r", m)
	var body := "a_tan" if camo else "a_grey"
	var zc := 0.27
	_tube(m, -0.95, 0.5, 0.0, zc, 0.115, 0.105, body, 5)
	Base._sp(nose, Vector3(0.62, 0, zc - 0.005), Vector3(0.5, 0.1, 0.09), body)
	Base._sp(nose, Vector3(1.04, 0, zc - 0.01), Vector3(0.08, 0.045, 0.045), "a_greyd")  # radome tip
	Base._sp(m, Vector3(-0.35, 0, zc + 0.095), Vector3(0.5, 0.05, 0.04), "a_greyl" if not camo else "a_drab")  # spine
	for s: float in [1.0, -1.0]:
		_tube(m, -1.0, -0.2, s * 0.085, zc - 0.01, 0.085, 0.09, body, 3)  # twin engines
		Base._sp(m, Vector3(-1.04, s * 0.085, zc - 0.01), Vector3(0.07, 0.07, 0.075), "a_nozzle")
		Base._sp(m, Vector3(-1.1, s * 0.085, zc - 0.01), Vector3(0.03, 0.052, 0.058), "a_black")
		Base._bx(nose, Vector3(0.3, s * 0.165, zc - 0.025), Vector3(0.2, 0.05, 0.062), "a_greyl" if not camo else "a_drab")  # intake
		Base._bx(nose, Vector3(0.504, s * 0.165, zc - 0.025), Vector3(0.004, 0.044, 0.052), "a_dark")
	Base._sp(nose, Vector3(0.34, 0, zc + 0.085), Vector3(0.2, 0.065, 0.07), "a_canopy")
	Base._bx(nose, Vector3(0.34, 0, zc + 0.045), Vector3(0.2, 0.052, 0.02), "a_greyd")  # canopy sill
	for s: float in [1.0, -1.0]:
		var wl: Array[Prim] = m if s > 0.0 else wr
		var wz := zc - 0.03
		_wing(wl, Vector3(-0.1, s * 0.08, wz), Vector3(-0.46, s * 0.78, wz), 0.8, 0.22, 0.022, body, 4)
		_slab(wl, Vector3(-0.5, s * 0.3, wz + 0.028), Vector3(-0.55, s * 0.74, wz + 0.028), 0.03, 0.004, "a_greyd")  # aileron line
		_slab(wl, Vector3(0.28, s * 0.1, wz + 0.028), Vector3(-0.2, s * 0.62, wz + 0.028), 0.015, 0.004, "a_greyd")  # leading-edge line
		if not camo:
			Base._bx(wl, Vector3(-0.28, s * 0.5, wz + 0.028), Vector3(0.07, 0.07, 0.003), "a_blue")
			Base._bx(wl, Vector3(-0.28, s * 0.5, wz + 0.034), Vector3(0.035, 0.035, 0.003), "a_yellow")
		_wing(wl, Vector3(-0.88, s * 0.1, zc - 0.02), Vector3(-0.95, s * 0.46, zc - 0.02), 0.34, 0.16, 0.018, body, 2)  # tailplane
		_missile(wl, Vector3(-0.28, s * 0.42, zc - 0.115), Vector3(0.2, s * 0.42, zc - 0.115), 0.024)
		Base._bx(wl, Vector3(-0.05, s * 0.42, zc - 0.065), Vector3(0.05, 0.012, 0.03), "a_greyd")
		if camo:
			Base._sp(wl, Vector3(-0.35, s * 0.84, wz), Vector3(0.3, 0.05, 0.05), "a_greyd")  # wing-tip tank
			Base._sp(wl, Vector3(-0.35, s * 0.84, wz + 0.0), Vector3(0.31, 0.044, 0.044), "a_drab")
		else:
			_missile(wl, Vector3(-0.62, s * 0.82, wz), Vector3(-0.12, s * 0.82, wz), 0.024)
		var fl: Array[Prim] = m if s > 0.0 else fr
		_wing(fl, Vector3(-0.66, s * 0.12, zc + 0.07), Vector3(-0.84, s * 0.3, zc + 0.46), 0.4, 0.2, 0.014, body, 3)  # canted fin
		Base._bx(fl, Vector3(-0.82, s * 0.28, zc + 0.4), Vector3(0.09, 0.02, 0.03), "a_yellow" if not camo else "a_olived")
	if camo:
		Base._sp(m, Vector3(0, 0, 0.13), Vector3(0.3, 0.06, 0.06), "a_greyd")  # centre-line tank
		Base._bx(m, Vector3(0, 0, 0.2), Vector3(0.05, 0.012, 0.04), "a_greyd")
		for i in 6:  # camouflage patches
			var mat := "a_olive" if i % 2 == 0 else "a_olived"
			Base._sp(m, Vector3(0.15 - 0.3 * float(i) * 0.9 + 0.3, 0.0, zc + 0.085), Vector3(0.12 + 0.06 * Base._rnd(i, 3), 0.075, 0.03), mat)
		Base._sp(nose, Vector3(0.66, 0, zc + 0.062), Vector3(0.2, 0.07, 0.03), "a_olive")
		for s: float in [1.0, -1.0]:
			var wl2: Array[Prim] = m if s > 0.0 else wr
			for i in 5:
				var y := 0.2 + 0.11 * float(i)
				var xm := -0.1 - 0.36 * (y - 0.08) / 0.7
				var ch := 0.8 - 0.58 * (y - 0.08) / 0.7
				var hx := minf(0.09 + 0.05 * Base._rnd(i, 5), ch * 0.4)
				Base._bx(wl2, Vector3(xm + (Base._rnd(i, 6) - 0.5) * 0.1, s * y, zc - 0.002), Vector3(hx, 0.07, 0.003), "a_olive" if (i + int(s)) % 2 == 0 else "a_olived", Base._rnd(i, 7) * 0.6)
			Base._bx(fr if s < 0.0 else m, Vector3(-0.77, s * 0.24, zc + 0.3), Vector3(0.1, 0.018, 0.06), "a_olive")
	if gear:
		_leg(m, Vector3(0.6, 0, zc - 0.06), 0.6, 0.0, 0.04)
		for s: float in [1.0, -1.0]:
			_leg(m, Vector3(-0.3, s * 0.15, zc - 0.07), -0.3, s * 0.22, 0.052)


# ---- attack jet ---------------------------------------------------------------------------------------------

## Straight-winged ground attacker: bubble canopy, nose cannon, twin engines high on the rear fuselage, twin fins,
## bombs, rocket pods and a missile under each wing.
static func _attack_jet(m: Array[Prim]) -> void:
	var b := "a_olive"
	var zc := 0.3
	_tube(m, -0.7, 0.55, 0.0, zc, 0.115, 0.12, b, 5)
	Base._sp(m, Vector3(0.8, 0, zc - 0.02), Vector3(0.34, 0.1, 0.1), b)
	Base._sp(m, Vector3(-0.85, 0, zc + 0.02), Vector3(0.4, 0.09, 0.09), b)
	Base._sp(m, Vector3(0.95, 0, zc - 0.1), Vector3(0.2, 0.05, 0.045), "a_greyd")
	_slab(m, Vector3(1.0, 0, zc - 0.095), Vector3(1.42, 0, zc - 0.095), 0.022, 0.022, "a_greyd", Vector3(0, 1, 0))  # cannon
	Base._sp(m, Vector3(1.42, 0, zc - 0.095), Vector3(0.025, 0.03, 0.03), "a_black")
	Base._sp(m, Vector3(0.62, 0, zc + 0.12), Vector3(0.24, 0.092, 0.1), "a_canopy")  # bubble canopy
	Base._bx(m, Vector3(0.62, 0, zc + 0.075), Vector3(0.24, 0.085, 0.015), "a_olived")
	for s: float in [1.0, -1.0]:
		_tube(m, -1.0, -0.05, s * 0.24, zc + 0.12, 0.105, 0.105, b, 4)  # engines
		Base._sp(m, Vector3(-0.04, s * 0.24, zc + 0.12), Vector3(0.03, 0.09, 0.09), "a_greyd")
		Base._sp(m, Vector3(-0.02, s * 0.24, zc + 0.12), Vector3(0.02, 0.07, 0.07), "a_dark")
		Base._sp(m, Vector3(-1.03, s * 0.24, zc + 0.12), Vector3(0.05, 0.09, 0.09), "a_nozzle")
		Base._sp(m, Vector3(-1.08, s * 0.24, zc + 0.12), Vector3(0.03, 0.06, 0.06), "a_black")
		Base._bx(m, Vector3(-0.55, s * 0.15, zc + 0.065), Vector3(0.42, 0.07, 0.03), b)  # engine pylon
		var wz := 0.25
		_wing(m, Vector3(0.0, s * 0.1, wz), Vector3(-0.02, s * 0.8, wz), 0.72, 0.58, 0.028, b, 4)
		_wing(m, Vector3(-0.02, s * 0.8, wz), Vector3(-0.03, s * 0.97, wz - 0.05), 0.58, 0.4, 0.025, b, 2)  # drooped tip
		_slab(m, Vector3(-0.26, s * 0.18, wz + 0.034), Vector3(-0.27, s * 0.5, wz + 0.034), 0.04, 0.004, "a_olived")  # flaps
		_slab(m, Vector3(-0.24, s * 0.55, wz + 0.034), Vector3(-0.25, s * 0.9, wz + 0.02), 0.035, 0.004, "a_greyd")  # ailerons
		_slab(m, Vector3(0.3, s * 0.12, wz + 0.034), Vector3(0.24, s * 0.9, wz + 0.02), 0.014, 0.004, "a_olived")
		# bomb, rocket pod, missile
		Base._sp(m, Vector3(0.0, s * 0.38, 0.14), Vector3(0.21, 0.06, 0.06), "a_drab")
		Base._bx(m, Vector3(-0.18, s * 0.38, 0.14), Vector3(0.04, 0.09, 0.008), "a_greyd")
		Base._bx(m, Vector3(-0.18, s * 0.38, 0.14), Vector3(0.04, 0.008, 0.09), "a_greyd")
		Base._bx(m, Vector3(0.0, s * 0.38, 0.2), Vector3(0.05, 0.012, 0.03), "a_greyd")
		Base._sp(m, Vector3(0.0, s * 0.62, 0.155), Vector3(0.17, 0.05, 0.05), "a_greyd")
		Base._sp(m, Vector3(0.17, s * 0.62, 0.155), Vector3(0.015, 0.042, 0.042), "a_black")
		Base._bx(m, Vector3(0.0, s * 0.62, 0.2), Vector3(0.05, 0.012, 0.025), "a_greyd")
		_missile(m, Vector3(-0.15, s * 0.88, 0.165), Vector3(0.18, s * 0.88, 0.165), 0.022)
		# twin fins and tailplane
		_wing(m, Vector3(-1.0, s * 0.34, zc + 0.05), Vector3(-1.08, s * 0.34, zc + 0.5), 0.38, 0.26, 0.018, b, 3)
		Base._bx(m, Vector3(-1.07, s * 0.364, zc + 0.4), Vector3(0.09, 0.004, 0.035), "a_yellow")
		Base._bx(m, Vector3(-1.07, s * 0.32, zc + 0.52), Vector3(0.14, 0.03, 0.012), "a_olived")  # fin cap
		_leg(m, Vector3(0.05, s * 0.3, 0.23), 0.05, s * 0.3, 0.06)
	_slab(m, Vector3(-1.05, -0.4, zc + 0.14), Vector3(-1.05, 0.4, zc + 0.14), 0.15, 0.02, b)
	_leg(m, Vector3(0.85, 0, zc - 0.1), 0.85, 0.0, 0.045)
	Base._bx(m, Vector3(0.2, 0, zc + 0.125), Vector3(0.02, 0.1, 0.01), "a_greyd")  # cockpit rail


# ---- bomber -------------------------------------------------------------------------------------------------

## Stealth flying wing, 3.6 long x 4.2 span: built as chord-wise strips so the planform (swept leading edge, W trailing
## edge) is exact. Lighter leading-edge band, dark intakes and exhausts on top, glazed nose.
static func _bomber(m: Array[Prim]) -> void:
	var dy := 0.07
	var zw := 0.3
	for j in 30:
		var y0 := dy * float(j)
		var y1 := y0 + dy
		var ym := (y0 + y1) * 0.5
		var lead := 1.8 - 1.024 * maxf(ym, 0.12)
		var trail: float
		if ym < 0.5:
			trail = -1.8 + 1.1 * ym
		elif ym < 1.4:
			trail = -1.3 + 0.35 * (ym - 0.5)
		else:
			trail = -1.15 + 0.6 * (ym - 1.4)
		var ht := 0.035 + 0.06 * maxf(0.0, 1.0 - ym / 1.6)
		var band := 0.2
		for s: float in [1.0, -1.0]:
			Base._bx(m, Vector3((lead - band + trail) * 0.5, s * ym, zw), Vector3((lead - band - trail) * 0.5, dy * 0.5 + 0.003, ht), "a_char")
			Base._bx(m, Vector3(lead - band * 0.5, s * ym, zw), Vector3(band * 0.5, dy * 0.5 + 0.003, ht * 0.9), "a_charl")
	Base._sp(m, Vector3(0.1, 0, zw + 0.02), Vector3(1.5, 0.3, 0.2), "a_char")  # centre hump
	Base._sp(m, Vector3(1.25, 0, zw + 0.01), Vector3(0.4, 0.14, 0.12), "a_charl")
	for s: float in [1.0, -1.0]:
		Base._bx(m, Vector3(1.28, s * 0.09, zw + 0.1), Vector3(0.1, 0.045, 0.014), "a_canopy", s * 0.15)  # cockpit glass
		Base._bx(m, Vector3(0.62, s * 0.46, zw + 0.07), Vector3(0.14, 0.1, 0.012), "a_dark")  # intakes
		Base._bx(m, Vector3(0.62, s * 0.46, zw + 0.062), Vector3(0.16, 0.115, 0.005), "a_greyd")
		Base._bx(m, Vector3(-0.95, s * 0.32, zw + 0.075), Vector3(0.22, 0.13, 0.008), "a_nozzle")  # exhaust troughs
		Base._bx(m, Vector3(-1.0, s * 0.32, zw + 0.084), Vector3(0.15, 0.09, 0.004), "a_dark")
		Base._bx(m, Vector3(-0.35, s * 1.15, zw + 0.045), Vector3(0.09, 0.09, 0.003), "a_blue")
		Base._bx(m, Vector3(-0.35, s * 1.15, zw + 0.051), Vector3(0.045, 0.045, 0.003), "a_yellow")
		_slab(m, Vector3(-0.75, s * 0.6, zw + 0.05), Vector3(-0.55, s * 1.8, zw + 0.03), 0.012, 0.004, "a_greyd")  # elevon seam
		_slab(m, Vector3(0.4, s * 0.3, zw + 0.085), Vector3(-0.2, s * 1.6, zw + 0.04), 0.01, 0.004, "a_greyd")  # spar panel line
		# main gear bogies and doors
		_leg(m, Vector3(-0.3, s * 0.62, 0.26), -0.3, s * 0.62, 0.07)
		Base._sp(m, Vector3(-0.3, s * 0.62 + s * 0.05, 0.07), Vector3(0.07, 0.03, 0.07), "a_black")
	Base._bx(m, Vector3(-1.55, 0, zw + 0.02), Vector3(0.2, 0.2, 0.05), "a_char")  # centre tail lobe
	_leg(m, Vector3(1.0, 0, 0.28), 1.0, 0.0, 0.055)
	Base._bx(m, Vector3(0.3, 0, zw + 0.205), Vector3(0.55, 0.014, 0.004), "a_greyd")  # spine seam


# ---- cargo plane --------------------------------------------------------------------------------------------

## Four-engine turboprop transport, 4.2 long x 5.0 span: high straight wing, deep boxy fuselage, lowered rear ramp, T-tail.
## `g` groups for the crashed version: "front" (nose, forward fuselage), "wl" (left wing + engines), "wri"/"wro" (right wing
## inner/outer + engines); everything else is the "rear" (rear fuselage, tail).
static func _cargo(m: Array[Prim], gear: bool = true, g: Dictionary = {}) -> void:
	var front: Array[Prim] = g.get("front", m)
	var wl: Array[Prim] = g.get("wl", m)
	var wri: Array[Prim] = g.get("wri", m)
	var wro: Array[Prim] = g.get("wro", m)
	var body := "a_grey"
	# fuselage: boxy section with chamfered roof and belly, glazed nose, upswept tail cone
	Base._bx(front, Vector3(0.45, 0, 0.55), Vector3(0.85, 0.34, 0.3), body)
	Base._bx(front, Vector3(0.45, 0, 0.88), Vector3(0.85, 0.27, 0.06), body)
	Base._bx(front, Vector3(0.45, 0, 0.27), Vector3(0.85, 0.27, 0.04), "a_greyd")
	Base._bx(m, Vector3(-0.95, 0, 0.55), Vector3(0.56, 0.34, 0.3), body)
	Base._bx(m, Vector3(-0.95, 0, 0.88), Vector3(0.56, 0.27, 0.06), body)
	Base._bx(m, Vector3(-0.95, 0, 0.27), Vector3(0.56, 0.27, 0.04), "a_greyd")
	Base._sp(front, Vector3(1.3, 0, 0.57), Vector3(0.65, 0.33, 0.3), body)
	Base._bx(front, Vector3(1.55, 0, 0.84), Vector3(0.14, 0.2, 0.03), "a_canopy")  # flight deck glass
	Base._bx(front, Vector3(1.6, 0.0, 0.8), Vector3(0.1, 0.27, 0.03), "a_canopy")
	Base._sp(m, Vector3(-1.7, 0, 0.64), Vector3(0.55, 0.3, 0.26), body)
	Base._bx(m, Vector3(-2.19, 0, 0.5), Vector3(0.012, 0.19, 0.13), "a_dark")  # rear door opening
	_slab(m, Vector3(-2.0, 0, 0.36), Vector3(-2.45, 0, 0.04), 0.24, 0.02, "a_greyd", Vector3(0, 1, 0))  # lowered ramp
	for s: float in [1.0, -1.0]:
		_slab(m, Vector3(-2.0, s * 0.22, 0.38), Vector3(-2.44, s * 0.22, 0.06), 0.012, 0.03, "a_greyl", Vector3(0, 1, 0))
		var ys := s * 0.344
		Base._bx(front, Vector3(-0.15 + 0.65, ys, 0.62), Vector3(0.65, 0.004, 0.012), "a_white")  # cheat line
		Base._bx(m, Vector3(-0.95, ys, 0.62), Vector3(0.55, 0.004, 0.012), "a_white")
		Base._bx(front, Vector3(1.18, ys, 0.72), Vector3(0.07, 0.004, 0.05), "a_canopy")  # cockpit side windows
		for xl: float in [-1.3, -0.8, -0.3, 0.2, 0.7]:  # panel lines
			Base._bx(front if xl > -0.4 else m, Vector3(xl, ys, 0.52), Vector3(0.008, 0.004, 0.26), "a_greyd")
		Base._bx(m, Vector3(-0.55, ys, 0.45), Vector3(0.18, 0.005, 0.2), "a_greyl")  # paratroop door
		Base._bx(m, Vector3(-0.55, ys * 1.003, 0.52), Vector3(0.06, 0.006, 0.06), "a_canopy")
		# main-gear sponsons
		Base._bx(m, Vector3(-0.2, s * 0.37, 0.3), Vector3(0.7, 0.07, 0.13), "a_greyd")
	# wings: left whole, right in two panels (inner/outer)
	for s: float in [1.0, -1.0]:
		var panels: Array = [[0.2, 2.5, wl]] if s > 0.0 else [[0.2, 1.3, wri], [1.3, 2.5, wro]]
		for pn in panels:
			var y0: float = pn[0]
			var y1: float = pn[1]
			var lst: Array[Prim] = pn[2]
			var t0 := (y0 - 0.2) / 2.3
			var t1 := (y1 - 0.2) / 2.3
			_wing(lst, Vector3(lerpf(0.1, -0.05, t0), s * y0, 0.95), Vector3(lerpf(0.1, -0.05, t1), s * y1, 0.95), lerpf(0.8, 0.5, t0), lerpf(0.8, 0.5, t1), 0.04, body, 3)
			# aileron / flap lines, leading-edge band, tip light
			var xt0 := lerpf(0.1, -0.05, t0) - lerpf(0.8, 0.5, t0) * 0.5 + 0.1
			var xt1 := lerpf(0.1, -0.05, t1) - lerpf(0.8, 0.5, t1) * 0.5 + 0.1
			_slab(lst, Vector3(xt0, s * (y0 + 0.02), 0.995), Vector3(xt1, s * (y1 - 0.02), 0.995), 0.06, 0.004, "a_greyd")
			var xl0 := lerpf(0.1, -0.05, t0) + lerpf(0.8, 0.5, t0) * 0.5 - 0.04
			var xl1 := lerpf(0.1, -0.05, t1) + lerpf(0.8, 0.5, t1) * 0.5 - 0.04
			_slab(lst, Vector3(xl0, s * (y0 + 0.02), 0.995), Vector3(xl1, s * (y1 - 0.02), 0.995), 0.035, 0.004, "a_greyl")
		Base._bx(wro if s < 0.0 else wl, Vector3(-0.12, s * 2.0, 0.998), Vector3(0.09, 0.09, 0.003), "a_blue")
		Base._bx(wro if s < 0.0 else wl, Vector3(-0.12, s * 2.0, 1.004), Vector3(0.045, 0.045, 0.003), "a_yellow")
		# two turboprops per wing
		for ye: float in [0.95, 1.75]:
			var lst2: Array[Prim] = wl if s > 0.0 else (wri if ye < 1.3 else wro)
			_tube(lst2, -0.2, 0.6, s * ye, 0.8, 0.1, 0.1, "a_greyd", 4)
			Base._bx(lst2, Vector3(0.15, s * ye, 0.9), Vector3(0.28, 0.05, 0.06), "a_greyd")  # pylon
			Base._sp(lst2, Vector3(0.6, s * ye, 0.8), Vector3(0.1, 0.1, 0.1), "a_greyl")
			Base._bx(lst2, Vector3(0.28, s * ye, 0.715), Vector3(0.12, 0.06, 0.025), "a_dark")  # intake
			_prop(lst2, Vector3(0.74, s * ye, 0.8), 0.4, 3, 0.2 + 0.3 * absf(ye))
	# T-tail
	_wing(m, Vector3(-2.0, 0, 0.8), Vector3(-2.2, 0, 1.55), 0.8, 0.42, 0.035, body, 3)
	_slab(m, Vector3(-2.38, 0, 0.9), Vector3(-2.42, 0, 1.5), 0.04, 0.038, "a_greyl")  # rudder
	for s: float in [1.0, -1.0]:
		_wing(m, Vector3(-2.2, s * 0.05, 1.58), Vector3(-2.3, s * 0.72, 1.58), 0.46, 0.28, 0.03, body, 2)
	Base._bx(m, Vector3(-2.2, 0, 1.6), Vector3(0.2, 0.07, 0.03), "a_greyl")
	if gear:
		for s: float in [1.0, -1.0]:
			for xw: float in [-0.5, 0.15]:
				Base._sp(m, Vector3(xw, s * 0.46, 0.14), Vector3(0.14, 0.065, 0.14), "a_black")
				Base._sp(m, Vector3(xw, s * 0.47, 0.14), Vector3(0.07, 0.07, 0.07), "a_greyl")
		_leg(m, Vector3(1.35, 0, 0.4), 1.35, 0.0, 0.1)
		Base._sp(m, Vector3(1.35, 0.1, 0.1), Vector3(0.1, 0.04, 0.1), "a_black")
		Base._sp(m, Vector3(1.35, -0.1, 0.1), Vector3(0.1, 0.04, 0.1), "a_black")


# ---- helicopters --------------------------------------------------------------------------------------------

## Tandem-rotor transport: long box fuselage with raised cockpit, rear ramp, two stilled three-blade rotors (the rear one
## on a tall pylon), wheel sponsons.
static func _transport_heli(m: Array[Prim]) -> void:
	var b := "a_drab"
	Base._bx(m, Vector3(-0.1, 0, 0.34), Vector3(0.8, 0.17, 0.17), b)
	Base._bx(m, Vector3(-0.1, 0, 0.53), Vector3(0.72, 0.13, 0.03), b)
	Base._sp(m, Vector3(0.72, 0, 0.32), Vector3(0.28, 0.17, 0.15), b)
	Base._bx(m, Vector3(-0.98, 0, 0.4), Vector3(0.2, 0.14, 0.13), b)
	Base._bx(m, Vector3(0.62, 0, 0.5), Vector3(0.22, 0.13, 0.07), b)  # raised cockpit
	Base._bx(m, Vector3(0.842, 0, 0.5), Vector3(0.006, 0.115, 0.052), "a_canopy")
	Base._bx(m, Vector3(0.92, 0, 0.32), Vector3(0.006, 0.12, 0.08), "a_dark")
	_slab(m, Vector3(-1.12, 0, 0.3), Vector3(-1.42, 0, 0.05), 0.13, 0.02, "a_greyd", Vector3(0, 1, 0))  # ramp
	Base._bx(m, Vector3(-1.19, 0, 0.36), Vector3(0.006, 0.12, 0.1), "a_dark")
	Base._cy(m, Vector3(0.5, 0, 0.66), 0.05, 0.1, "a_greyd")  # front mast
	Base._bx(m, Vector3(-0.82, 0, 0.62), Vector3(0.13, 0.07, 0.3), b)  # rear pylon
	Base._cy(m, Vector3(-0.8, 0, 0.94), 0.05, 0.04, "a_greyd")
	_rotor(m, Vector3(0.5, 0, 0.78), 0.62, 3, 0.04, 0.4)
	_rotor(m, Vector3(-0.8, 0, 0.99), 0.62, 3, 0.04, 1.0)
	for s: float in [1.0, -1.0]:
		var ys := s * 0.174
		Base._bx(m, Vector3(0.2, ys, 0.34), Vector3(0.45, 0.004, 0.055), "a_greyd")  # window band
		for i in 5:
			Base._bx(m, Vector3(0.58 - 0.18 * float(i), ys + s * 0.003, 0.34), Vector3(0.05, 0.004, 0.04), "a_canopy")
		Base._bx(m, Vector3(0.64, s * 0.134, 0.5), Vector3(0.1, 0.004, 0.045), "a_canopy")
		Base._bx(m, Vector3(-0.5, ys, 0.31), Vector3(0.16, 0.004, 0.13), "a_olive")  # door
		Base._bx(m, Vector3(-0.05, s * 0.2, 0.21), Vector3(0.4, 0.06, 0.07), "a_greyd")  # sponson
		_leg(m, Vector3(0.5, s * 0.2, 0.2), 0.5, s * 0.21, 0.06)
		_leg(m, Vector3(-0.7, s * 0.18, 0.28), -0.7, s * 0.2, 0.06)
	Base._bx(m, Vector3(-0.1, 0, 0.55), Vector3(0.55, 0.012, 0.012), "a_olived")  # roof seam


## Narrow tandem-seat attack helicopter: slim fuselage, stepped canopies, chin gun, stub wings with rocket pods and
## missiles, skids, thin tail boom with fin, stilled tail rotor and four-blade main rotor.
static func _gunship(m: Array[Prim]) -> void:
	var b := "a_gun"
	Base._sp(m, Vector3(0.1, 0, 0.3), Vector3(0.5, 0.085, 0.11), b)
	Base._sp(m, Vector3(0.4, 0, 0.36), Vector3(0.14, 0.066, 0.07), "a_canopy")
	Base._sp(m, Vector3(0.17, 0, 0.44), Vector3(0.17, 0.072, 0.085), "a_canopy")
	Base._bx(m, Vector3(0.29, 0, 0.4), Vector3(0.012, 0.07, 0.07), "a_greyd")
	Base._sp(m, Vector3(0.62, 0, 0.27), Vector3(0.07, 0.065, 0.065), "a_black")  # sensor ball
	Base._sp(m, Vector3(0.62, 0, 0.27), Vector3(0.015, 0.045, 0.045), "a_canopy")
	Base._sp(m, Vector3(0.45, 0, 0.2), Vector3(0.07, 0.05, 0.04), "a_greyd")
	_slab(m, Vector3(0.45, 0, 0.19), Vector3(0.74, 0, 0.17), 0.018, 0.018, "steel", Vector3(0, 1, 0))  # chin gun
	for s: float in [1.0, -1.0]:
		Base._sp(m, Vector3(-0.08, s * 0.095, 0.42), Vector3(0.25, 0.075, 0.075), b)  # engines
		Base._sp(m, Vector3(-0.33, s * 0.095, 0.42), Vector3(0.03, 0.05, 0.05), "a_black")
		_wing(m, Vector3(0.05, s * 0.08, 0.26), Vector3(0.05, s * 0.36, 0.26), 0.22, 0.17, 0.02, b, 1)  # stub wing
		Base._sp(m, Vector3(0.06, s * 0.36, 0.19), Vector3(0.15, 0.045, 0.045), "a_greyl")  # rocket pod
		Base._sp(m, Vector3(0.23, s * 0.36, 0.19), Vector3(0.012, 0.042, 0.042), "a_black")
		Base._bx(m, Vector3(0.06, s * 0.36, 0.23), Vector3(0.05, 0.012, 0.025), "a_greyd")
		_missile(m, Vector3(-0.1, s * 0.2, 0.205), Vector3(0.18, s * 0.2, 0.205), 0.018)
		# skids
		_slab(m, Vector3(-0.3, s * 0.15, 0.04), Vector3(0.4, s * 0.15, 0.04), 0.02, 0.02, "a_greyd", Vector3(0, 1, 0))
		_slab(m, Vector3(0.4, s * 0.15, 0.04), Vector3(0.5, s * 0.15, 0.1), 0.02, 0.02, "a_greyd", Vector3(0, 1, 0))
		_slab(m, Vector3(0.22, s * 0.075, 0.2), Vector3(0.22, s * 0.15, 0.05), 0.012, 0.012, "a_greyd")
		_slab(m, Vector3(-0.12, s * 0.075, 0.2), Vector3(-0.12, s * 0.15, 0.05), 0.012, 0.012, "a_greyd")
		Base._bx(m, Vector3(0.0, s * 0.087, 0.35), Vector3(0.18, 0.004, 0.03), "a_greyd")  # intake panel
	Base._cy(m, Vector3(0.0, 0, 0.58), 0.04, 0.07, "a_greyd")  # mast
	_rotor(m, Vector3(0.0, 0, 0.66), 0.62, 4, 0.04, 0.55, 0.045)
	_slab(m, Vector3(-0.3, 0, 0.36), Vector3(-0.98, 0, 0.41), 0.035, 0.035, b, Vector3(0, 1, 0))  # tail boom
	_wing(m, Vector3(-0.93, 0, 0.42), Vector3(-1.0, 0, 0.7), 0.24, 0.13, 0.018, b, 2)  # fin
	_slab(m, Vector3(-0.86, -0.17, 0.43), Vector3(-0.86, 0.17, 0.43), 0.065, 0.014, b)  # stabilator
	_slab(m, Vector3(-1.12, 0.06, 0.58), Vector3(-0.88, 0.06, 0.58), 0.026, 0.012, "rotor", Vector3(0, 0, 1))  # tail rotor
	_slab(m, Vector3(-1.0, 0.06, 0.46), Vector3(-1.0, 0.06, 0.7), 0.026, 0.012, "rotor", Vector3(1, 0, 0))
	Base._cy(m, Vector3(-1.0, 0.05, 0.58), 0.025, 0.02, "a_greyd")


## Huey-style utility helicopter: glazed bubble nose, sliding doors, two-blade rotor with stabiliser bar, slim tail boom,
## skids.
static func _utility_heli(m: Array[Prim]) -> void:
	var b := "a_olive"
	Base._bx(m, Vector3(-0.05, 0, 0.3), Vector3(0.3, 0.16, 0.14), b)
	Base._bx(m, Vector3(-0.05, 0, 0.46), Vector3(0.28, 0.13, 0.03), b)
	Base._sp(m, Vector3(-0.1, 0, 0.52), Vector3(0.25, 0.1, 0.08), "a_olived")  # engine hump
	Base._sp(m, Vector3(0.32, 0, 0.3), Vector3(0.27, 0.15, 0.14), "a_canopy")  # bubble nose
	Base._bx(m, Vector3(0.45, 0, 0.3), Vector3(0.015, 0.135, 0.012), b)  # nose frame bars
	Base._bx(m, Vector3(0.38, 0, 0.4), Vector3(0.12, 0.012, 0.012), b)
	Base._cy(m, Vector3(-0.05, 0, 0.62), 0.04, 0.06, "a_greyd")
	_rotor(m, Vector3(-0.05, 0, 0.7), 0.8, 2, 0.04, 0.5, 0.05)
	_rotor(m, Vector3(-0.05, 0, 0.73), 0.24, 2, 0.0, 0.5 + PI * 0.5, 0.012, "a_greyd")  # stabiliser bar
	_slab(m, Vector3(-0.3, 0, 0.36), Vector3(-0.62, 0, 0.38), 0.08, 0.075, b, Vector3(0, 1, 0))  # boom, thick part
	_slab(m, Vector3(-0.6, 0, 0.38), Vector3(-1.0, 0, 0.41), 0.042, 0.04, b, Vector3(0, 1, 0))
	_wing(m, Vector3(-0.94, 0, 0.42), Vector3(-1.02, 0, 0.66), 0.24, 0.13, 0.018, b, 2)
	_slab(m, Vector3(-0.78, -0.15, 0.4), Vector3(-0.78, 0.15, 0.4), 0.05, 0.012, b)
	_slab(m, Vector3(-1.14, 0.06, 0.55), Vector3(-0.9, 0.06, 0.55), 0.026, 0.012, "rotor", Vector3(0, 0, 1))
	_slab(m, Vector3(-1.02, 0.06, 0.43), Vector3(-1.02, 0.06, 0.67), 0.026, 0.012, "rotor", Vector3(1, 0, 0))
	for s: float in [1.0, -1.0]:
		Base._bx(m, Vector3(-0.05, s * 0.163, 0.3), Vector3(0.15, 0.004, 0.105), "a_drab")  # sliding door
		Base._bx(m, Vector3(0.0, s * 0.168, 0.34), Vector3(0.07, 0.004, 0.04), "a_canopy")
		Base._bx(m, Vector3(-0.05, s * 0.167, 0.42), Vector3(0.18, 0.005, 0.012), "a_greyd")  # door rail
		Base._bx(m, Vector3(-0.05, s * 0.167, 0.2), Vector3(0.18, 0.005, 0.012), "a_greyd")
		_slab(m, Vector3(-0.38, s * 0.2, 0.05), Vector3(0.38, s * 0.2, 0.05), 0.02, 0.02, "a_greyd", Vector3(0, 1, 0))
		_slab(m, Vector3(0.38, s * 0.2, 0.05), Vector3(0.5, s * 0.2, 0.13), 0.02, 0.02, "a_greyd", Vector3(0, 1, 0))
		_slab(m, Vector3(-0.15, s * 0.14, 0.2), Vector3(-0.15, s * 0.2, 0.06), 0.014, 0.014, "a_greyd")
		_slab(m, Vector3(0.2, s * 0.14, 0.2), Vector3(0.2, s * 0.2, 0.06), 0.014, 0.014, "a_greyd")
	_slab(m, Vector3(-0.15, -0.2, 0.1), Vector3(-0.15, 0.2, 0.1), 0.014, 0.014, "a_greyd", Vector3(1, 0, 0))
	_slab(m, Vector3(0.2, -0.2, 0.1), Vector3(0.2, 0.2, 0.1), 0.014, 0.014, "a_greyd", Vector3(1, 0, 0))
	Base._bx(m, Vector3(-0.7, 0, 0.41), Vector3(0.11, 0.045, 0.004), "a_white")  # boom band
	Base._bx(m, Vector3(-0.7, 0, 0.375), Vector3(0.11, 0.075, 0.004), "a_white")


## Tiltrotor: transport fuselage, high straight wing, two nacelles tilted up at the wingtips with stilled three-blade
## rotors, twin-fin tail, ramp, wheel sponsons.
static func _tiltrotor(m: Array[Prim]) -> void:
	var b := "a_grey"
	_tube(m, -0.9, 0.55, 0.0, 0.36, 0.19, 0.18, b, 5)
	Base._sp(m, Vector3(0.62, 0, 0.34), Vector3(0.4, 0.17, 0.15), b)
	Base._sp(m, Vector3(0.78, 0, 0.43), Vector3(0.18, 0.13, 0.08), "a_canopy")
	Base._sp(m, Vector3(-1.05, 0, 0.5), Vector3(0.45, 0.12, 0.14), b)
	_slab(m, Vector3(-1.3, 0, 0.42), Vector3(-1.62, 0, 0.06), 0.14, 0.02, "a_greyd", Vector3(0, 1, 0))
	Base._bx(m, Vector3(-1.5, 0, 0.45), Vector3(0.01, 0.1, 0.07), "a_dark")
	for s: float in [1.0, -1.0]:
		_wing(m, Vector3(0.05, s * 0.12, 0.6), Vector3(0.05, s * 1.2, 0.6), 0.48, 0.4, 0.035, b, 3)
		_slab(m, Vector3(-0.15, s * 0.4, 0.64), Vector3(-0.15, s * 1.1, 0.64), 0.04, 0.004, "a_greyd")
		_slab(m, Vector3(0.22, s * 0.3, 0.64), Vector3(0.22, s * 1.15, 0.64), 0.014, 0.004, "a_greyl")
		# nacelle tilted up: a short chain of ellipsoids
		for i in 4:
			var t := float(i) / 3.0
			Base._sp(m, Vector3(0.02 + 0.1 * t, s * 1.25, 0.62 + 0.26 * t), Vector3(0.14, 0.1, 0.1), "a_greyd" if i < 2 else b)
		Base._sp(m, Vector3(0.14, s * 1.25, 0.93), Vector3(0.06, 0.06, 0.07), "a_greyl")
		_rotor(m, Vector3(0.14, s * 1.25, 0.99), 0.5, 3, 0.05, 0.6 + s * 0.4)
		Base._bx(m, Vector3(-0.1, s * 1.25, 0.76), Vector3(0.05, 0.11, 0.015), "a_dark")  # exhaust
		# wheel sponsons
		Base._bx(m, Vector3(-0.15, s * 0.21, 0.22), Vector3(0.5, 0.05, 0.1), "a_greyd")
		_leg(m, Vector3(-0.25, s * 0.22, 0.2), -0.25, s * 0.24, 0.075)
		# tail: tailplane with end fins
		_wing(m, Vector3(-1.15, s * 0.05, 0.58), Vector3(-1.2, s * 0.38, 0.58), 0.34, 0.26, 0.02, b, 2)
		_wing(m, Vector3(-1.19, s * 0.38, 0.45), Vector3(-1.24, s * 0.38, 0.9), 0.3, 0.2, 0.02, b, 3)
		Base._bx(m, Vector3(-1.2, s * 0.405, 0.8), Vector3(0.08, 0.004, 0.03), "a_yellow")
		Base._bx(m, Vector3(-0.1, s * 0.192, 0.4), Vector3(0.45, 0.004, 0.01), "a_greyd")
		for i in 4:
			Base._bx(m, Vector3(0.3 - 0.2 * float(i), s * 0.192, 0.4), Vector3(0.04, 0.004, 0.035), "a_canopy")
	_leg(m, Vector3(0.6, 0, 0.22), 0.6, 0.0, 0.06)
	Base._bx(m, Vector3(-0.4, 0, 0.545), Vector3(0.5, 0.04, 0.012), "a_greyd")  # roof seam


# ---- small aircraft -----------------------------------------------------------------------------------------

## Long-winged surveillance drone: slim body with bulbous nose and sensor ball, V-tail, pusher propeller.
static func _drone(m: Array[Prim]) -> void:
	var b := "a_white"
	Base._sp(m, Vector3(0.0, 0, 0.2), Vector3(0.55, 0.055, 0.065), b)
	Base._sp(m, Vector3(0.45, 0, 0.22), Vector3(0.14, 0.08, 0.085), b)
	Base._sp(m, Vector3(0.28, 0, 0.29), Vector3(0.13, 0.055, 0.045), "a_greyl")
	Base._sp(m, Vector3(0.52, 0, 0.14), Vector3(0.04, 0.04, 0.04), "a_black")
	Base._sp(m, Vector3(0.58, 0, 0.23), Vector3(0.04, 0.05, 0.05), "a_greyd")
	Base._sp(m, Vector3(-0.66, 0, 0.24), Vector3(0.14, 0.06, 0.065), "a_greyl")  # engine pod
	_slab(m, Vector3(-0.45, 0, 0.23), Vector3(-0.85, 0, 0.27), 0.03, 0.03, b, Vector3(0, 1, 0))
	for s: float in [1.0, -1.0]:
		_wing(m, Vector3(0.05, s * 0.07, 0.24), Vector3(0.0, s * 1.2, 0.22), 0.22, 0.13, 0.016, b, 5)
		_slab(m, Vector3(-0.07, s * 0.2, 0.263), Vector3(-0.07, s * 1.15, 0.243), 0.025, 0.004, "a_greyd")  # aileron line
		Base._bx(m, Vector3(0.0, s * 0.95, 0.248), Vector3(0.05, 0.05, 0.003), "a_blue")
		_wing(m, Vector3(-0.8, s * 0.04, 0.28), Vector3(-0.98, s * 0.24, 0.5), 0.2, 0.1, 0.014, b, 2)  # V-tail
		_missile(m, Vector3(-0.1, s * 0.45, 0.165), Vector3(0.12, s * 0.45, 0.165), 0.016, "a_greyd", "a_greyd")
		Base._bx(m, Vector3(0.0, s * 0.45, 0.2), Vector3(0.03, 0.01, 0.02), "a_greyd")
		_leg(m, Vector3(-0.15, s * 0.04, 0.16), -0.15, s * 0.07, 0.035)
	_leg(m, Vector3(0.38, 0, 0.17), 0.38, 0.0, 0.03)
	_prop(m, Vector3(-0.92, 0, 0.26), 0.14, 2, 0.5)


## Single-engine high-wing trainer: cowl and propeller, glazed cabin, wing struts, fixed tricycle gear with wheel spats,
## blue trim.
static func _light_plane(m: Array[Prim]) -> void:
	var b := "a_white"
	_tube(m, -0.5, 0.2, 0.0, 0.25, 0.085, 0.095, b, 3)
	Base._sp(m, Vector3(0.27, 0, 0.22), Vector3(0.17, 0.085, 0.085), b)
	Base._sp(m, Vector3(-0.47, 0, 0.28), Vector3(0.28, 0.062, 0.07), b)
	Base._sp(m, Vector3(0.12, 0, 0.33), Vector3(0.11, 0.075, 0.045), "a_canopy")
	Base._bx(m, Vector3(0.42, 0, 0.22), Vector3(0.02, 0.07, 0.07), "a_dark")  # cowl opening
	Base._sp(m, Vector3(0.45, 0, 0.22), Vector3(0.05, 0.045, 0.045), "a_greyd")
	_prop(m, Vector3(0.47, 0, 0.22), 0.22, 1, 0.35)
	for s: float in [1.0, -1.0]:
		Base._bx(m, Vector3(-0.08, s * 0.086, 0.3), Vector3(0.14, 0.004, 0.035), "a_canopy")
		Base._bx(m, Vector3(-0.15, s * 0.088, 0.205), Vector3(0.4, 0.004, 0.014), "a_blue")
		_wing(m, Vector3(0.1, s * 0.08, 0.41), Vector3(0.1, s * 0.75, 0.41), 0.3, 0.24, 0.02, b, 3)
		Base._bx(m, Vector3(0.1, s * 0.7, 0.432), Vector3(0.12, 0.05, 0.003), "a_blue")
		_slab(m, Vector3(0.06, s * 0.08, 0.17), Vector3(0.13, s * 0.5, 0.39), 0.014, 0.014, "a_greyl")  # wing strut
		_slab(m, Vector3(-0.64, s * 0.04, 0.3), Vector3(-0.7, s * 0.3, 0.3), 0.1, 0.014, b)  # tailplane (halves)
		_slab(m, Vector3(0.0, s * 0.1, 0.17), Vector3(-0.02, s * 0.27, 0.07), 0.016, 0.016, "a_greyd")  # gear leg
		Base._sp(m, Vector3(-0.02, s * 0.28, 0.07), Vector3(0.07, 0.025, 0.07), "a_black")
		Base._sp(m, Vector3(-0.04, s * 0.29, 0.1), Vector3(0.1, 0.03, 0.08), b)  # wheel spat
	_wing(m, Vector3(-0.55, 0, 0.32), Vector3(-0.68, 0, 0.52), 0.26, 0.14, 0.016, b, 2)
	Base._bx(m, Vector3(-0.64, 0.02, 0.45), Vector3(0.06, 0.004, 0.04), "a_blue")
	Base._bx(m, Vector3(-0.64, -0.02, 0.45), Vector3(0.06, 0.004, 0.04), "a_blue")
	_leg(m, Vector3(0.3, 0, 0.18), 0.3, 0.0, 0.05)


# ---- crashed ------------------------------------------------------------------------------------------------

## A fighter broken in two: nose section dug in ahead with its canopy cracked, the rear half skidded on its belly
## with one wing up, the other wing and a tail fin torn off and lying apart. Patchy char, fire and smoke at the break.
static func _crashed_jet(m: Array[Prim]) -> void:
	var nose: Array[Prim] = []
	var wr: Array[Prim] = []
	var fr: Array[Prim] = []
	var rear: Array[Prim] = []
	_fighter(rear, false, false, {"nose": nose, "wr": wr, "fin_r": fr})
	var zc := 0.27
	_scorch_ground(m, Vector3(0.15, 0.0, 0.0), 0.95, 0.65)
	# dirt trench ahead of the nose, mounds around the dug-in tip
	_slab(m, Vector3(0.2, 0, 0.015), Vector3(1.35, 0.05, 0.015), 0.16, 0.012, "dirt", Vector3(0, 1, 0))
	# rear half: rolled, yawed, resting on the belly
	_burn(rear, 0.55, 11)
	Base._xform_about(rear, Vector3(-0.3, 0, zc), Basis(Vector3(0, 0, 1), 0.2) * Basis(Vector3(1, 0, 0), 0.22), Vector3(-0.05, 0.0, -0.1))
	# nose section: pitched down into the ground, rolled
	_burn(nose, 0.45, 12)
	Base._xform_about(nose, Vector3(0.15, 0, zc), Base._ry(0.3) * Basis(Vector3(1, 0, 0), 0.35), Vector3(0.45, -0.05, -0.08))
	# right wing and fin: torn off
	_burn(wr, 0.6, 13)
	Base._xform_about(wr, Vector3(-0.1, -0.08, zc - 0.03), Basis(Vector3(0, 0, 1), -0.75) * Basis(Vector3(1, 0, 0), -0.04), Vector3(0.1, -0.55, -0.2))
	_burn(fr, 0.6, 14)
	Base._xform_about(fr, Vector3(-0.75, -0.2, zc + 0.2), Basis(Vector3(1, 0, 0), -1.3) * Basis(Vector3(0, 0, 1), 0.4), Vector3(-0.1, -0.45, -0.43))
	m.append_array(rear)
	m.append_array(nose)
	m.append_array(wr)
	m.append_array(fr)
	# torn edges at the break: bare metal and ribs
	Base._bx(m, Vector3(0.0, 0.0, 0.2), Vector3(0.012, 0.11, 0.08), "a_alu", 0.2)
	for i in 5:
		var a := float(i) * 0.9
		_slab(m, Vector3(0.0, sin(a) * 0.05, 0.2 + cos(a) * 0.05), Vector3(0.12, sin(a) * 0.12, 0.2 + cos(a) * 0.13 + 0.04), 0.012, 0.012, "a_alu", Vector3(0, 1, 0))
	_debris(m, 0.0, 0.0, 1.1, 9, 21)
	Base._sp(m, Vector3(0.95, 0.08, 0.02), Vector3(0.22, 0.2, 0.08), "dirt")
	Base._sp(m, Vector3(0.75, -0.25, 0.015), Vector3(0.16, 0.12, 0.05), "dirt")
	Base._sp(m, Vector3(1.1, 0.3, 0.015), Vector3(0.12, 0.1, 0.05), "dirt")
	Base._sp(m, Vector3(-0.15, 0.05, 0.28), Vector3(0.13, 0.13, 0.12), "fire")
	Base._sp(m, Vector3(-0.15, 0.05, 0.3), Vector3(0.07, 0.07, 0.09), "flash")
	Base._sp(m, Vector3(-0.5, 0.2, 0.2), Vector3(0.08, 0.08, 0.07), "fire")
	_smoke(m, Vector3(-0.15, 0.05, 0.45), 4, 0.07, 71)


## Helicopter on its side after a hard landing: body rolled over, tail boom snapped off and lying apart, rotor bent
## down to stubs with two blades thrown clear, smoke and a small fire.
static func _crashed_heli(m: Array[Prim]) -> void:
	var body: Array[Prim] = []
	var tail: Array[Prim] = []
	var rotor: Array[Prim] = []
	var b := "a_olive"
	Base._bx(body, Vector3(-0.05, 0, 0.3), Vector3(0.3, 0.16, 0.14), b)
	Base._bx(body, Vector3(-0.05, 0, 0.46), Vector3(0.28, 0.13, 0.03), b)
	Base._sp(body, Vector3(-0.1, 0, 0.52), Vector3(0.25, 0.1, 0.08), "a_olived")
	Base._sp(body, Vector3(0.32, 0, 0.3), Vector3(0.27, 0.15, 0.14), "a_canopy")
	Base._bx(body, Vector3(0.45, 0, 0.3), Vector3(0.015, 0.135, 0.012), b)
	for s: float in [1.0, -1.0]:
		Base._bx(body, Vector3(-0.05, s * 0.163, 0.3), Vector3(0.15, 0.004, 0.105), "a_drab")
		Base._bx(body, Vector3(0.0, s * 0.168, 0.34), Vector3(0.07, 0.004, 0.04), "a_canopy")
		_slab(body, Vector3(-0.38, s * 0.2, 0.05), Vector3(0.38, s * 0.2, 0.05), 0.02, 0.02, "a_greyd", Vector3(0, 1, 0))
		_slab(body, Vector3(0.38, s * 0.2, 0.05), Vector3(0.5, s * 0.2, 0.13), 0.02, 0.02, "a_greyd", Vector3(0, 1, 0))
		_slab(body, Vector3(-0.15, s * 0.14, 0.2), Vector3(-0.15, s * 0.2, 0.06), 0.014, 0.014, "a_greyd")
		_slab(body, Vector3(0.2, s * 0.14, 0.2), Vector3(0.2, s * 0.2, 0.06), 0.014, 0.014, "a_greyd")
	Base._cy(rotor, Vector3(-0.05, 0, 0.6), 0.04, 0.06, "a_greyd")  # bent mast stub
	for i in 2:  # blade stubs, bent down
		var a := 0.5 + PI * float(i)
		var d := Vector3(cos(a), sin(a), 0.0)
		_slab(rotor, Vector3(-0.05, 0, 0.67), Vector3(-0.05, 0, 0.67) + d * 0.28 + Vector3(0, 0, -0.12), 0.05, 0.016, "rotor", Vector3(-d.y, d.x, 0.0))
	# tail boom, snapped
	_slab(tail, Vector3(-0.62, 0, 0.38), Vector3(-1.0, 0, 0.41), 0.042, 0.04, b, Vector3(0, 1, 0))
	_wing(tail, Vector3(-0.94, 0, 0.42), Vector3(-1.02, 0, 0.66), 0.24, 0.13, 0.018, b, 2)
	_slab(tail, Vector3(-0.78, -0.15, 0.4), Vector3(-0.78, 0.15, 0.4), 0.05, 0.012, b)
	_slab(tail, Vector3(-1.14, 0.06, 0.55), Vector3(-0.9, 0.06, 0.55), 0.026, 0.012, "rotor", Vector3(0, 0, 1))
	_slab(tail, Vector3(-1.02, 0.06, 0.43), Vector3(-1.02, 0.06, 0.67), 0.026, 0.012, "rotor", Vector3(1, 0, 0))
	Base._bx(tail, Vector3(-0.7, 0, 0.41), Vector3(0.11, 0.045, 0.004), "a_white")
	_scorch_ground(m, Vector3(0.0, 0.0, 0.0), 0.62, 0.48)
	_burn(body, 0.4, 31)
	_burn(tail, 0.4, 32)
	# body on its side (the +y flank up), a little nose-down
	Base._xform_about(body, Vector3(0, 0, 0.3), Basis(Vector3(0, 0, 1), -0.25) * Basis(Vector3(1, 0, 0), 1.42), Vector3(0.0, 0.0, -0.1))
	Base._xform_about(rotor, Vector3(0, 0, 0.3), Basis(Vector3(0, 0, 1), -0.25) * Basis(Vector3(1, 0, 0), 1.42), Vector3(0.0, 0.0, -0.1))
	# tail lying on the ground, rolled onto its side and yawed away from the body
	Base._xform_about(tail, Vector3(-0.62, 0, 0.38), Basis(Vector3(0, 0, 1), 0.5) * Basis(Vector3(1, 0, 0), 1.2), Vector3(-0.15, 0.18, -0.34))
	m.append_array(body)
	m.append_array(rotor)
	m.append_array(tail)
	# blades thrown clear (flat on the ground)
	_slab(m, Vector3(0.1, -0.5, 0.025), Vector3(0.62, -0.62, 0.03), 0.05, 0.016, "a_charm", Vector3(0, 1, 0))
	_slab(m, Vector3(-0.5, 0.6, 0.025), Vector3(-0.12, 0.75, 0.03), 0.05, 0.016, "a_charm", Vector3(0, 1, 0))
	_debris(m, 0.0, 0.0, 0.8, 6, 41)
	Base._sp(m, Vector3(0.0, 0.0, 0.18), Vector3(0.1, 0.1, 0.09), "fire")
	Base._sp(m, Vector3(-0.08, 0.04, 0.22), Vector3(0.05, 0.05, 0.06), "flash")
	_smoke(m, Vector3(0.0, 0.0, 0.36), 3, 0.06, 72)


## Cargo plane belly-landed: nose tipped down and dug in, fuselage cracked in two with the rear half twisted, left wing
## drooping, right wing snapped with its outer half and engine lying apart, fire at the break, scorched ground.
static func _crashed_cargo(m: Array[Prim]) -> void:
	var front: Array[Prim] = []
	var wl: Array[Prim] = []
	var wri: Array[Prim] = []
	var wro: Array[Prim] = []
	var rear: Array[Prim] = []
	_cargo(rear, false, {"front": front, "wl": wl, "wri": wri, "wro": wro})
	_scorch_ground(m, Vector3(-0.2, 0.0, 0.0), 2.5, 1.5)
	_slab(m, Vector3(1.0, 0, 0.015), Vector3(2.9, 0.1, 0.015), 0.4, 0.012, "dirt", Vector3(0, 1, 0))
	_burn(rear, 0.6, 51)
	_burn(front, 0.4, 52)
	_burn(wl, 0.5, 53)
	_burn(wri, 0.6, 54)
	_burn(wro, 0.65, 55)
	var pf := Vector3(-0.4, 0, 0.55)
	# front: nose down, a touch of roll
	Base._xform_about(front, pf, Base._ry(0.09) * Basis(Vector3(1, 0, 0), 0.06), Vector3(0.0, 0.0, -0.2))
	Base._xform_about(wl, pf, Base._ry(0.09) * Basis(Vector3(1, 0, 0), 0.06), Vector3(0.0, 0.0, -0.2))
	Base._xform_about(wl, Vector3(0, 0.3, 0.95), Basis(Vector3(1, 0, 0), -0.1), Vector3.ZERO)
	Base._xform_about(wri, pf, Base._ry(0.09) * Basis(Vector3(1, 0, 0), 0.06), Vector3(0.0, 0.0, -0.2))
	Base._xform_about(wri, Vector3(0, -0.3, 0.95), Basis(Vector3(1, 0, 0), 0.22), Vector3.ZERO)
	# rear: twisted at the break, lowered, nose of the rear half rides up
	Base._xform_about(rear, pf, Basis(Vector3(0, 0, 1), 0.22) * Basis(Vector3(1, 0, 0), -0.05), Vector3(-0.12, -0.12, -0.2))
	# outer right wing: snapped, yawed and lying on the ground
	Base._xform_about(wro, Vector3(0.0, -1.3, 0.95), Basis(Vector3(0, 0, 1), 0.55) * Basis(Vector3(1, 0, 0), 0.12), Vector3(-0.35, -0.55, -0.88))
	m.append_array(rear)
	m.append_array(front)
	m.append_array(wl)
	m.append_array(wri)
	m.append_array(wro)
	# torn skin at the break: bare metal edge and a few ribs
	Base._bx(m, Vector3(-0.44, 0.0, 0.5), Vector3(0.012, 0.3, 0.28), "a_alu", 0.1)
	for i in 8:
		var a := float(i) * 0.78
		_slab(m, Vector3(-0.4, sin(a) * 0.2, 0.5 + cos(a) * 0.2), Vector3(-0.25, sin(a) * 0.3, 0.5 + cos(a) * 0.27 + 0.05), 0.016, 0.016, "a_alu", Vector3(0, 1, 0))
	Base._bx(m, Vector3(-0.2, 0.9, 0.18), Vector3(0.12, 0.012, 0.15), "a_charm", 0.5)  # a torn panel
	_debris(m, -0.4, 0.0, 2.3, 16, 61)
	Base._sp(m, Vector3(2.3, 0.2, 0.03), Vector3(0.35, 0.4, 0.1), "dirt")
	Base._sp(m, Vector3(1.9, -0.5, 0.02), Vector3(0.3, 0.2, 0.07), "dirt")
	Base._sp(m, Vector3(2.0, 0.8, 0.02), Vector3(0.25, 0.2, 0.06), "dirt")
	# fire and smoke at the break and the broken wing root
	Base._sp(m, Vector3(-0.45, 0.05, 0.4), Vector3(0.3, 0.3, 0.22), "fire")
	Base._sp(m, Vector3(-0.42, 0.05, 0.45), Vector3(0.17, 0.17, 0.15), "flash")
	Base._sp(m, Vector3(-0.2, -1.25, 0.65), Vector3(0.14, 0.14, 0.12), "fire")
	_smoke(m, Vector3(-0.45, 0.05, 0.8), 4, 0.14, 73)
	_smoke(m, Vector3(-0.2, -1.25, 0.9), 3, 0.07, 74)
