extends RefCounted
## Theme pack: emplacements (static defensive positions used as map dressing). Loaded by tools/gen_sprites.gd, see
## docs/specs/art-pack-2.md and the contract in pack_nature.gd. Material prefix `e_`, category `emplacement`.
## Models are authored with +x as the muzzle / front, about 0.9 across for a 1x1 piece (k 1.15 to 1.25 enlarges them).

const Base = preload("res://tools/gen_sprites.gd")
const Prim = Base.Prim

const MATS := {
	"e_earth": ["3a2e1f", "5a4830", "76603f"],
	"e_turf": ["35502a", "4e7036", "6b9048"],
	"e_pit": ["0c0a08", "17120e", "241d16"],
	"e_camo": ["2c4222", "44602e", "5f7f40"],
	"e_camod": ["46391f", "62522f", "80703f"],
	"e_tarp": ["2d3d4a", "45606f", "628295"],
	"e_ink": ["0d0e0c", "17191a", "24282b"],
}

const SE_ONLY: Array = ["se"]
const LONG: Array = ["se", "sw"]
const FOUR: Array = ["se", "nw", "sw", "ne"]


static func specs() -> Array:
	return [
		{"dir": "emp_pillbox", "name": "Pillbox", "cat": "emplacement", "auto": true, "k": 1.2, "frames": 1, "columns": 1, "ss": 2, "facings": FOUR, "foot": Vector2i(1, 1)},
		{"dir": "emp_aa_gun", "name": "Anti-Aircraft Gun", "cat": "emplacement", "auto": true, "k": 1.2, "frames": 1, "columns": 1, "ss": 2, "facings": FOUR, "foot": Vector2i(1, 1)},
		{"dir": "emp_mortar_pit", "name": "Mortar Pit", "cat": "emplacement", "auto": true, "k": 1.2, "frames": 1, "columns": 1, "ss": 2, "facings": FOUR, "foot": Vector2i(1, 1)},
		{"dir": "emp_sam_launcher", "name": "SAM Launcher", "cat": "emplacement", "auto": true, "k": 1.2, "frames": 1, "columns": 1, "ss": 2, "facings": FOUR, "foot": Vector2i(1, 1)},
		{"dir": "emp_searchlight_post", "name": "Searchlight Post", "cat": "emplacement", "auto": true, "k": 1.3, "frames": 1, "columns": 1, "ss": 2, "facings": SE_ONLY, "foot": Vector2i(1, 1), "glow": [Vector3(0.2, 0, 0.68), 64.0, Color(1.0, 0.95, 0.75)]},
		{"dir": "emp_at_gun", "name": "Anti-Tank Gun", "cat": "emplacement", "auto": true, "k": 1.15, "frames": 1, "columns": 1, "ss": 2, "facings": FOUR, "foot": Vector2i(1, 1)},
		{"dir": "emp_sniper_nest", "name": "Sniper Nest", "cat": "emplacement", "auto": true, "k": 1.25, "frames": 1, "columns": 1, "ss": 2, "facings": SE_ONLY, "foot": Vector2i(1, 1)},
		{"dir": "emp_foxhole", "name": "Foxhole", "cat": "emplacement", "auto": true, "k": 1.1, "frames": 1, "columns": 1, "ss": 2, "facings": SE_ONLY, "foot": Vector2i(1, 1)},
		{"dir": "emp_trench", "name": "Trench", "cat": "emplacement", "auto": true, "k": 1.25, "frames": 1, "columns": 1, "ss": 2, "facings": LONG, "foot": Vector2i(2, 1)},
		{"dir": "emp_razor_wire", "name": "Razor Wire", "cat": "emplacement", "auto": true, "k": 1.25, "frames": 1, "columns": 1, "ss": 2, "facings": LONG, "foot": Vector2i(2, 1)},
		{"dir": "emp_dragons_teeth", "name": "Dragon's Teeth", "cat": "emplacement", "auto": true, "k": 1.25, "frames": 1, "columns": 1, "ss": 2, "facings": LONG, "foot": Vector2i(2, 1)},
		{"dir": "emp_field_artillery", "name": "Field Artillery", "cat": "emplacement", "auto": true, "k": 1.15, "frames": 1, "columns": 1, "ss": 2, "facings": FOUR, "foot": Vector2i(2, 1)},
		{"dir": "emp_ammo_dump", "name": "Ammo Dump", "cat": "emplacement", "auto": true, "k": 1.2, "frames": 1, "columns": 1, "ss": 2, "facings": SE_ONLY, "foot": Vector2i(2, 2)},
		{"dir": "emp_radar_dish", "name": "Mobile Radar", "cat": "emplacement", "auto": true, "k": 1.2, "frames": 1, "columns": 1, "ss": 2, "facings": FOUR, "foot": Vector2i(1, 1)},
		{"dir": "emp_mg_bunker", "name": "MG Bunker", "cat": "emplacement", "auto": true, "k": 1.2, "frames": 1, "columns": 1, "ss": 2, "facings": FOUR, "foot": Vector2i(1, 1)},
	]


static func build(_host: Object, m: Array[Prim], unit: String, _frame: int) -> bool:
	match unit:
		"emp_pillbox":
			_pillbox(m)
		"emp_aa_gun":
			_aa_gun(m)
		"emp_mortar_pit":
			_mortar_pit(m)
		"emp_sam_launcher":
			_sam_launcher(m)
		"emp_searchlight_post":
			_searchlight(m)
		"emp_at_gun":
			_at_gun(m)
		"emp_sniper_nest":
			_sniper_nest(m)
		"emp_foxhole":
			_foxhole(m)
		"emp_trench":
			_trench(m)
		"emp_razor_wire":
			_razor_wire(m)
		"emp_dragons_teeth":
			_dragons_teeth(m)
		"emp_field_artillery":
			_field_artillery(m)
		"emp_ammo_dump":
			_ammo_dump(m)
		"emp_radar_dish":
			_radar_dish(m)
		"emp_mg_bunker":
			_mg_bunker(m)
		_:
			return false
	return true


# ---------------------------------------------------------------- shared helpers

## Round part (barrel, tube, pole) running from p0 to p1, radius r. Built from 1 to 4 crossed box sections because the
## renderer's cylinder test misses tilted cylinders whose local ray climbs backwards (the sections also keep it faceted).
static func _tube(m: Array[Prim], p0: Vector3, p1: Vector3, r: float, mat: String) -> void:
	var v := p1 - p0
	var length := v.length()
	if length < 1e-5:
		return
	var x := v / length
	var ref := Vector3(0, 0, 1) if absf(x.z) < 0.95 else Vector3(0, 1, 0)
	var y := ref.cross(x).normalized()
	var z := x.cross(y)
	var n := 1 if r < 0.035 else (2 if r < 0.07 else 4)
	var half := r * (0.9 if n == 1 else (0.8 if n == 2 else 0.74))
	for i in n:
		var a := float(i) * PI / float(n * 2)
		var yy := y * cos(a) + z * sin(a)
		var zz := z * cos(a) - y * sin(a)
		var pr := Prim.new(Base.BOX, (p0 + p1) * 0.5, Vector3(length * 0.5, half, half), mat)
		pr.basis = Basis(x, yy, zz)
		m.append(pr)


## Flat disc lying on the ground (earth pad, concrete pad).
static func _disc(m: Array[Prim], c: Vector3, r: float, mat: String, hz: float = 0.012) -> void:
	Base._cy(m, c + Vector3(0, 0, hz), r, hz, mat)


## Wheel with its axle along y: dark tyre, lighter (wooden or steel) face and a hub.
static func _wheel(m: Array[Prim], c: Vector3, r: float, face: String = "steel") -> void:
	Base._sp(m, c, Vector3(r, 0.04, r), "track")
	Base._sp(m, c + Vector3(0, signf(c.y) * 0.012, 0), Vector3(r * 0.8, 0.044, r * 0.8), face)
	Base._sp(m, c + Vector3(0, signf(c.y) * 0.02, 0), Vector3(r * 0.32, 0.05, r * 0.32), "gun")


## Ring of sandbags (`layers` courses) round `c`, with a gap centred on angle `gap_a` of half width `gap_w` (rad).
static func _bag_ring(m: Array[Prim], c: Vector3, r: float, layers: int, n: int, gap_a: float = 0.0, gap_w: float = 0.0, mat: String = "sand") -> void:
	var arc := TAU * r / float(n)
	for layer in layers:
		for i in n:
			var a := TAU * (float(i) + 0.5 * float(layer % 2)) / float(n)
			if gap_w > 0.0 and absf(angle_difference(a, gap_a)) < gap_w:
				continue
			var pos := c + Vector3(cos(a) * r, sin(a) * r, 0.042 + 0.082 * float(layer))
			Base._bx(m, pos, Vector3(arc * 0.5 * 0.97, 0.056, 0.042), mat, a + PI * 0.5 + (Base._rnd(i, layer + 31) - 0.5) * 0.08)


## Straight run of sandbags from a to b (ground xy), `layers` courses, optional starting course height offset.
static func _bag_row(m: Array[Prim], a: Vector2, b: Vector2, layers: int, z0: float = 0.0, mat: String = "sand") -> void:
	var d := b - a
	var length := d.length()
	var n := maxi(1, roundi(length / 0.17))
	var step := length / float(n)
	var yaw := atan2(d.y, d.x)
	for layer in layers:
		var odd := layer % 2 == 1
		for i in (n + 1 if odd else n):
			var t := float(i) * step if odd else (float(i) + 0.5) * step
			var half := step * 0.5 * 0.96
			if odd and (i == 0 or i == n):
				half *= 0.5
				t += half * (1.0 if i == 0 else -1.0)
			var p := a + d.normalized() * t
			Base._bx(m, Vector3(p.x, p.y, z0 + 0.042 + 0.082 * float(layer)), Vector3(half, 0.056, 0.042), mat, yaw + (Base._rnd(i, layer + 17) - 0.5) * 0.07)


## Wooden ammo crate with lid and a stencil.
static func _crate(m: Array[Prim], c: Vector3, h: Vector3, mat: String = "wood") -> void:
	Base._bx(m, c, h, mat)
	Base._bx(m, c + Vector3(0, 0, h.z + 0.004), Vector3(h.x * 1.04, h.y * 1.04, 0.01), "woodd")
	Base._bx(m, c + Vector3(h.x + 0.004, 0, 0.0), Vector3(0.006, h.y * 0.5, h.z * 0.3), "whitep")


## Upright shell: brass body, warhead tip.
static func _shell(m: Array[Prim], c: Vector3, r: float, hz: float) -> void:
	Base._cy(m, c, r, hz, "brass")
	Base._cy(m, c + Vector3(0, 0, hz + r * 0.9), r * 0.92, r * 0.9, "warhead")


# ---------------------------------------------------------------- models

## Low reinforced-concrete pillbox: earth banked on the sides and back, firing slit and overhanging roof at the front (+x).
static func _pillbox(m: Array[Prim]) -> void:
	_disc(m, Vector3(0, 0, 0), 0.46, "dirt")
	Base._bx(m, Vector3(0.0, 0, 0.2), Vector3(0.33, 0.3, 0.2), "concrete")  # main body
	Base._bx(m, Vector3(0.06, 0, 0.415), Vector3(0.34, 0.31, 0.025), "concretel")  # roof slab, overhangs the front a little
	Base._bx(m, Vector3(0.355, 0, 0.075), Vector3(0.03, 0.31, 0.075), "concrete")  # sloped front apron
	Base._bx(m, Vector3(0.335, 0, 0.26), Vector3(0.008, 0.2, 0.045), "e_ink")  # firing slit
	Base._bx(m, Vector3(0.334, 0, 0.312), Vector3(0.009, 0.215, 0.008), "concretel")  # slit lintel and sill
	Base._bx(m, Vector3(0.334, 0, 0.205), Vector3(0.009, 0.215, 0.008), "concretel")
	for s: float in [1.0, -1.0]:  # formwork seams
		Base._bx(m, Vector3(0.334, 0.27 * s, 0.2), Vector3(0.006, 0.005, 0.19), "concretec")
	Base._bx(m, Vector3(-0.12, 0.304, 0.17), Vector3(0.06, 0.006, 0.09), "concretec")  # side door recess
	Base._sp(m, Vector3(-0.32, 0.0, 0.0), Vector3(0.3, 0.44, 0.34), "e_earth")  # earth banked behind and at the sides
	Base._sp(m, Vector3(-0.1, 0.34, 0.0), Vector3(0.3, 0.14, 0.2), "e_earth")
	Base._sp(m, Vector3(-0.1, -0.34, 0.0), Vector3(0.3, 0.14, 0.2), "e_earth")
	Base._sp(m, Vector3(-0.34, 0.0, 0.2), Vector3(0.2, 0.34, 0.2), "e_turf")
	Base._sp(m, Vector3(-0.14, -0.33, 0.08), Vector3(0.2, 0.1, 0.1), "e_turf")
	Base._bx(m, Vector3(-0.08, 0.1, 0.45), Vector3(0.07, 0.07, 0.014), "gun")  # roof hatch
	Base._cy(m, Vector3(-0.22, -0.12, 0.47), 0.025, 0.04, "steel")  # vent pipe
	Base._sp(m, Vector3(0.12, -0.15, 0.44), Vector3(0.07, 0.05, 0.025), "e_camo")  # camouflage on the roof
	Base._sp(m, Vector3(-0.02, 0.2, 0.44), Vector3(0.05, 0.06, 0.022), "e_camod")
	Base._bx(m, Vector3(0.42, 0.28, 0.048), Vector3(0.055, 0.05, 0.045), "sand", 0.3)  # sandbags at the front corners
	Base._bx(m, Vector3(0.42, -0.28, 0.048), Vector3(0.055, 0.05, 0.045), "sand", -0.3)
	Base._bx(m, Vector3(0.44, 0.19, 0.045), Vector3(0.05, 0.05, 0.04), "sand", 0.1)


## Twin-barrel anti-aircraft gun on a round sandbag ring, barrels raised. Muzzles point +x.
static func _aa_gun(m: Array[Prim]) -> void:
	_disc(m, Vector3(0, 0, 0), 0.45, "dirt")
	_bag_ring(m, Vector3.ZERO, 0.38, 2, 14, PI, 0.5)
	Base._cy(m, Vector3(0, 0, 0.06), 0.2, 0.025, "steel")  # gun platform
	Base._cy(m, Vector3(0, 0, 0.17), 0.065, 0.1, "gun")  # pedestal
	Base._bx(m, Vector3(-0.02, 0, 0.29), Vector3(0.13, 0.17, 0.035), "hull")  # turntable
	Base._bx(m, Vector3(-0.13, 0.0, 0.34), Vector3(0.04, 0.16, 0.06), "hull")  # rear counterweight
	for s: float in [1.0, -1.0]:
		Base._bx(m, Vector3(0.0, 0.115 * s, 0.4), Vector3(0.09, 0.022, 0.1), "hull")  # cradle cheeks
		var yb := 0.065 * s
		_tube(m, Vector3(-0.16, yb, 0.4), Vector3(0.02, yb, 0.5), 0.042, "gun")  # breech
		_tube(m, Vector3(0.0, yb, 0.5), Vector3(0.37, yb, 0.92), 0.028, "steel")  # barrel
		_tube(m, Vector3(0.34, yb, 0.89), Vector3(0.41, yb, 0.965), 0.04, "gun")  # muzzle brake
		_tube(m, Vector3(0.02, yb, 0.52), Vector3(0.18, yb, 0.7), 0.04, "gun")  # recoil sleeve
		Base._cy(m, Vector3(-0.02, 0.23 * s, 0.34), 0.07, 0.05, "ammo")  # drum magazines
		Base._cy(m, Vector3(-0.02, 0.23 * s, 0.395), 0.04, 0.012, "brass")
	Base._bx(m, Vector3(0.1, 0.0, 0.46), Vector3(0.012, 0.15, 0.1), "hull")  # light shield
	Base._bx(m, Vector3(-0.18, 0.14, 0.28), Vector3(0.05, 0.05, 0.015), "gun")  # gunner's seat
	Base._cy(m, Vector3(-0.18, 0.14, 0.2), 0.012, 0.06, "gun")
	Base._bx(m, Vector3(0.0, -0.17, 0.47), Vector3(0.04, 0.02, 0.025), "glass")  # sight
	Base._bx(m, Vector3(-0.28, -0.12, 0.06), Vector3(0.07, 0.08, 0.06), "ammo")  # ammo boxes in the gap
	Base._bx(m, Vector3(-0.28, 0.1, 0.06), Vector3(0.07, 0.07, 0.05), "ammo")


## Mortar pit: sandbag ring open at the back, tube on its base plate, shells and crates inside.
static func _mortar_pit(m: Array[Prim]) -> void:
	_disc(m, Vector3(0, 0, 0), 0.43, "dirt")
	_bag_ring(m, Vector3.ZERO, 0.36, 2, 13, PI, 0.55)
	Base._bx(m, Vector3(0.0, 0, 0.03), Vector3(0.11, 0.11, 0.016), "steel")  # base plate
	_tube(m, Vector3(-0.03, 0, 0.04), Vector3(0.12, 0, 0.58), 0.04, "gun")
	_tube(m, Vector3(0.11, 0, 0.55), Vector3(0.13, 0, 0.62), 0.052, "steel")  # muzzle ring
	_tube(m, Vector3(-0.05, 0, 0.1), Vector3(-0.1, 0, 0.06), 0.058, "gun")  # breech cap
	for s: float in [1.0, -1.0]:  # bipod
		Base._bone(m, Vector3(0.06, 0.0, 0.34), Vector3(0.2, 0.13 * s, 0.04), 0.012, 0.012, "steel")
	Base._bx(m, Vector3(0.05, 0.05, 0.36), Vector3(0.025, 0.012, 0.025), "gun")  # sight
	_crate(m, Vector3(-0.2, 0.15, 0.065), Vector3(0.1, 0.07, 0.065), "ammo")
	_crate(m, Vector3(-0.2, 0.15, 0.2), Vector3(0.08, 0.06, 0.055), "wood")
	for i in 4:  # loose shells
		_shell(m, Vector3(-0.24 + 0.05 * float(i % 2), -0.12 - 0.05 * float(i / 2), 0.08), 0.024, 0.07)
	Base._bx(m, Vector3(0.2, -0.04, 0.012), Vector3(0.09, 0.07, 0.012), "e_earth")  # scorched earth at the muzzle


## Trailer-mounted SAM launcher: four angled missile canisters on a turntable, stabiliser jacks, towbar.
static func _sam_launcher(m: Array[Prim]) -> void:
	Base._bx(m, Vector3(0, 0, 0.15), Vector3(0.38, 0.2, 0.035), "hull")  # trailer bed
	Base._bx(m, Vector3(0, 0, 0.117), Vector3(0.38, 0.17, 0.03), "gun")
	for s: float in [1.0, -1.0]:
		_wheel(m, Vector3(-0.1, 0.24 * s, 0.11), 0.11)
		Base._bone(m, Vector3(0.32, 0.2 * s, 0.15), Vector3(0.36, 0.25 * s, 0.02), 0.014, 0.014, "steel")  # jacks
		Base._bone(m, Vector3(-0.34, 0.2 * s, 0.15), Vector3(-0.38, 0.25 * s, 0.02), 0.014, 0.014, "steel")
		Base._bx(m, Vector3(0.36, 0.25 * s, 0.015), Vector3(0.03, 0.03, 0.015), "gun")
		Base._bx(m, Vector3(-0.38, 0.25 * s, 0.015), Vector3(0.03, 0.03, 0.015), "gun")
	Base._bone(m, Vector3(0.36, 0, 0.14), Vector3(0.52, 0, 0.07), 0.025, 0.02, "gun")  # towbar
	Base._bx(m, Vector3(0.1, 0, 0.19), Vector3(0.14, 0.15, 0.025), "steel")  # turntable
	Base._bx(m, Vector3(0.22, -0.13, 0.22), Vector3(0.07, 0.03, 0.05), "hull")  # control box
	Base._bx(m, Vector3(0.292, -0.13, 0.225), Vector3(0.006, 0.02, 0.02), "lampglow")
	Base._bone(m, Vector3(-0.1, 0.0, 0.2), Vector3(0.02, 0.0, 0.36), 0.04, 0.05, "gun")  # elevation frame
	var e := 0.72  # launch elevation (rad)
	var dir := Vector3(cos(e), 0, sin(e))
	var up := Vector3(-sin(e), 0, cos(e))
	for iy: float in [1.0, -1.0]:
		for iz: float in [1.0, -1.0]:
			var p0: Vector3 = Vector3(-0.2, 0.0, 0.42) + Vector3(0, iy * 0.078, 0) + up * (iz * 0.068)
			var p1: Vector3 = p0 + dir * 0.6
			_tube(m, p0, p1, 0.06, "tankg")
			_tube(m, p0 - dir * 0.02, p0 + dir * 0.06, 0.064, "gun")  # rear cap
			_tube(m, p1 - dir * 0.04, p1 + dir * 0.01, 0.064, "steel")
			_tube(m, p0 + dir * 0.3, p0 + dir * 0.34, 0.064, "gun")  # band
			Base._sp(m, p1 + dir * 0.02, Vector3(0.05, 0.05, 0.05), "red")  # nose cone showing through the canister mouth
	Base._bone(m, Vector3(-0.2, 0.0, 0.4), Vector3(0.1, 0.0, 0.7), 0.012, 0.012, "steel")  # cross brace


## Searchlight on a swivel on a concrete pad, with a small generator. Lens faces +x, raised.
static func _searchlight(m: Array[Prim]) -> void:
	Base._cy(m, Vector3(0, 0, 0.03), 0.3, 0.03, "concrete")
	Base._cy(m, Vector3(0, 0, 0.065), 0.24, 0.012, "concretel")
	Base._cy(m, Vector3(0, 0, 0.2), 0.045, 0.14, "gun")  # pedestal
	Base._cy(m, Vector3(0, 0, 0.35), 0.075, 0.03, "steel")  # swivel
	for s: float in [1.0, -1.0]:
		Base._bx(m, Vector3(0.0, 0.15 * s, 0.46), Vector3(0.03, 0.02, 0.1), "hull")  # yoke arms
	Base._bx(m, Vector3(0.0, 0, 0.37), Vector3(0.04, 0.15, 0.025), "hull")
	var back := Vector3(-0.13, 0, 0.45)
	var front := Vector3(0.17, 0, 0.64)
	_tube(m, back, front, 0.15, "hull")  # lamp drum
	_tube(m, front - (front - back).normalized() * 0.03, front + (front - back).normalized() * 0.005, 0.15, "steel")  # rim
	_tube(m, front, front + (front - back).normalized() * 0.012, 0.14, "lampglow")  # lens
	Base._sp(m, back - (front - back).normalized() * 0.02, Vector3(0.12, 0.12, 0.1), "hull")  # rear cap
	Base._cy(m, Vector3(-0.2, 0, 0.6), 0.02, 0.03, "gun")
	Base._bx(m, Vector3(-0.1, -0.2, 0.12), Vector3(0.12, 0.1, 0.07), "hull")  # generator
	Base._bx(m, Vector3(-0.1, -0.2, 0.2), Vector3(0.125, 0.105, 0.012), "gun")
	Base._bx(m, Vector3(0.025, -0.2, 0.13), Vector3(0.006, 0.06, 0.035), "gun")
	Base._bx(m, Vector3(0.028, -0.17, 0.14), Vector3(0.006, 0.015, 0.015), "lampglow")
	Base._bone(m, Vector3(-0.05, -0.15, 0.06), Vector3(-0.02, -0.02, 0.06), 0.008, 0.008, "e_ink")  # cable
	Base._bone(m, Vector3(-0.02, -0.02, 0.06), Vector3(0.0, 0.0, 0.3), 0.008, 0.008, "e_ink")


## Anti-tank gun: low horizontal barrel, sloped shield plate, two small wheels, split trail behind.
static func _at_gun(m: Array[Prim]) -> void:
	_wheel(m, Vector3(0.0, 0.26, 0.12), 0.12)
	_wheel(m, Vector3(0.0, -0.26, 0.12), 0.12)
	Base._bx(m, Vector3(0.0, 0, 0.12), Vector3(0.03, 0.26, 0.03), "steel")  # axle
	Base._bx(m, Vector3(0.0, 0, 0.21), Vector3(0.13, 0.11, 0.06), "hull")  # carriage
	for s: float in [1.0, -1.0]:  # split trail, spades planted
		Base._bone(m, Vector3(-0.08, 0.06 * s, 0.17), Vector3(-0.5, 0.26 * s, 0.03), 0.032, 0.03, "hull")
		Base._bx(m, Vector3(-0.5, 0.26 * s, 0.03), Vector3(0.05, 0.05, 0.03), "gun", 0.5 * s)
	_tube(m, Vector3(-0.16, 0, 0.27), Vector3(0.0, 0, 0.28), 0.052, "gun")  # breech
	_tube(m, Vector3(-0.02, 0, 0.28), Vector3(0.5, 0, 0.31), 0.03, "steel")  # long barrel
	_tube(m, Vector3(0.0, 0, 0.28), Vector3(0.22, 0, 0.29), 0.045, "gun")  # recoil sleeve
	_tube(m, Vector3(0.46, 0, 0.305), Vector3(0.54, 0, 0.315), 0.045, "gun")  # muzzle brake
	Base._bx(m, Vector3(0.12, 0, 0.33), Vector3(0.014, 0.23, 0.14), "hull")  # shield, lower plate
	var top := Prim.new(Base.BOX, Vector3(0.095, 0, 0.5), Vector3(0.014, 0.2, 0.06), "hull", 0.0, 0.0, 0.35)  # leaning top plate
	m.append(top)
	Base._bx(m, Vector3(0.136, 0, 0.3), Vector3(0.006, 0.05, 0.045), "gun")  # gun port
	Base._bx(m, Vector3(0.134, 0.15, 0.33), Vector3(0.006, 0.04, 0.012), "e_ink")
	Base._bx(m, Vector3(0.134, -0.15, 0.33), Vector3(0.006, 0.04, 0.012), "e_ink")
	Base._bx(m, Vector3(-0.08, 0.12, 0.31), Vector3(0.03, 0.03, 0.03), "glass")  # sight
	Base._bx(m, Vector3(-0.22, 0.08, 0.04), Vector3(0.07, 0.05, 0.04), "ammo")  # ammo box
	_shell(m, Vector3(0.18, -0.38, 0.03), 0.02, 0.06)


## Elevated sniper hide: sandbag-and-plank platform on four posts, camouflage netting over the top, ladder.
static func _sniper_nest(m: Array[Prim]) -> void:
	_disc(m, Vector3(0, 0, 0), 0.42, "dirt")
	for sx: float in [1.0, -1.0]:
		for sy: float in [1.0, -1.0]:
			Base._bone(m, Vector3(0.3 * sx, 0.3 * sy, 0.0), Vector3(0.27 * sx, 0.27 * sy, 0.62), 0.028, 0.028, "wood")
	for z: float in [0.22, 0.4]:
		for s: float in [1.0, -1.0]:
			Base._bone(m, Vector3(0.28 * s, -0.3, z), Vector3(0.28 * s, 0.3, z + 0.14), 0.012, 0.012, "woodd")
			Base._bone(m, Vector3(-0.3, 0.28 * s, z), Vector3(0.3, 0.28 * s, z + 0.14), 0.012, 0.012, "woodd")
	for i in 6:  # planks
		Base._bx(m, Vector3(-0.25 + 0.1 * float(i), 0, 0.64), Vector3(0.045, 0.33, 0.02), "wood" if i % 2 == 0 else "woodd")
	_bag_row(m, Vector2(0.33, -0.31), Vector2(0.33, 0.31), 2, 0.66)  # parapet: front and both sides
	_bag_row(m, Vector2(0.33, 0.31), Vector2(-0.2, 0.31), 2, 0.66)
	_bag_row(m, Vector2(0.33, -0.31), Vector2(-0.2, -0.31), 2, 0.66)
	for s: float in [1.0, -1.0]:  # lean-to roof over the back half only, front stays open
		Base._bone(m, Vector3(-0.26, 0.28 * s, 0.66), Vector3(-0.26, 0.28 * s, 1.0), 0.016, 0.016, "woodd")
		Base._bone(m, Vector3(0.0, 0.28 * s, 0.66), Vector3(0.0, 0.28 * s, 0.84), 0.016, 0.016, "woodd")
	m.append(Prim.new(Base.BOX, Vector3(-0.13, 0, 0.93), Vector3(0.2, 0.34, 0.014), "e_camo", 0.0, 0.0, 0.5))
	for i in 4:
		Base._bx(m, Vector3(-0.22 + 0.07 * float(i), 0.12 * (float(i % 2) - 0.5), 0.99 - 0.065 * float(i)), Vector3(0.05, 0.05, 0.02), "e_camod")
	Base._bx(m, Vector3(-0.1, 0.355, 0.8), Vector3(0.22, 0.012, 0.1), "e_camo")  # netting drooping at the sides
	Base._bx(m, Vector3(-0.1, -0.355, 0.8), Vector3(0.22, 0.012, 0.1), "e_camod")
	for i in 3:  # camo scraps on the front parapet
		Base._sp(m, Vector3(0.33, -0.2 + 0.2 * float(i), 0.79), Vector3(0.05, 0.05, 0.035), "e_camo" if i != 1 else "e_camod")
	Base._bone(m, Vector3(-0.42, 0.14, 0.0), Vector3(-0.3, 0.14, 0.64), 0.014, 0.012, "wood")  # ladder rails
	Base._bone(m, Vector3(-0.42, -0.06, 0.0), Vector3(-0.3, -0.06, 0.64), 0.014, 0.012, "wood")
	for i in 5:
		Base._bx(m, Vector3(-0.395 + 0.022 * float(i), 0.04, 0.1 + 0.12 * float(i)), Vector3(0.012, 0.1, 0.01), "woodd")
	_tube(m, Vector3(0.05, 0.0, 0.8), Vector3(0.52, 0.0, 0.83), 0.016, "gun")  # long rifle poking out
	Base._bx(m, Vector3(0.1, 0, 0.78), Vector3(0.1, 0.03, 0.025), "stock")
	Base._bx(m, Vector3(0.18, 0, 0.84), Vector3(0.04, 0.012, 0.012), "glass")  # scope
	Base._sp(m, Vector3(-0.1, -0.1, 0.78), Vector3(0.07, 0.06, 0.05), "e_camo")  # the sniper's ghillie hump


## Foxhole: dark pit ringed by a lip of earth, a couple of sandbags, a helmet and a shovel.
static func _foxhole(m: Array[Prim]) -> void:
	_disc(m, Vector3(0, 0, 0), 0.4, "dirt")
	Base._cy(m, Vector3(0, 0, 0.026), 0.25, 0.01, "e_pit")
	for i in 11:
		var a := TAU * float(i) / 11.0 + 0.2
		var r := 0.31 + 0.03 * Base._rnd(i, 3)
		var s := 0.085 + 0.03 * Base._rnd(i, 4)
		Base._sp(m, Vector3(cos(a) * r, sin(a) * r, 0.03), Vector3(s, s, 0.065 + 0.03 * Base._rnd(i, 5)), "e_earth" if i % 3 != 0 else "dirt")
	for i in 4:  # earth thrown up behind
		Base._sp(m, Vector3(-0.3 - 0.04 * float(i % 2), -0.14 + 0.1 * float(i), 0.1), Vector3(0.1, 0.09, 0.07), "e_earth")
	Base._bx(m, Vector3(0.0, -0.33, 0.13), Vector3(0.1, 0.055, 0.042), "sand", 0.1)
	Base._bx(m, Vector3(0.14, -0.3, 0.13), Vector3(0.1, 0.055, 0.042), "sand", -0.5)
	Base._bx(m, Vector3(0.06, -0.3, 0.2), Vector3(0.09, 0.05, 0.04), "sand", 0.2)
	Base._sp(m, Vector3(0.3, 0.2, 0.14), Vector3(0.065, 0.06, 0.04), "helm")  # helmet resting on the lip
	Base._cy(m, Vector3(0.3, 0.2, 0.11), 0.075, 0.008, "helm")
	Base._bone(m, Vector3(-0.28, 0.2, 0.08), Vector3(-0.2, 0.26, 0.42), 0.014, 0.014, "wood")  # shovel standing in the mound
	Base._bx(m, Vector3(-0.19, 0.265, 0.45), Vector3(0.035, 0.012, 0.05), "steel")
	Base._bx(m, Vector3(-0.1, 0.12, 0.2), Vector3(0.07, 0.015, 0.012), "gun")  # rifle laid on the parapet
	Base._bx(m, Vector3(0.05, 0.1, 0.205), Vector3(0.1, 0.012, 0.01), "stock")


## Trench segment along x, two cells long: dark floor with duckboards, sandbag parapets, spoil behind, crates, a ladder.
static func _trench(m: Array[Prim]) -> void:
	Base._bx(m, Vector3(0, 0, 0.012), Vector3(0.78, 0.2, 0.012), "e_pit")
	for i in 12:  # duckboards: planks across, two rails along
		Base._bx(m, Vector3(-0.67 + 0.122 * float(i), 0, 0.035), Vector3(0.042, 0.15, 0.012), "wood" if i % 3 != 1 else "woodd")
	for s: float in [1.0, -1.0]:
		Base._bx(m, Vector3(0, 0.16 * s, 0.026), Vector3(0.78, 0.014, 0.014), "woodd")
	_bag_row(m, Vector2(-0.78, -0.3), Vector2(0.78, -0.3), 3)  # far parapet, 3 courses
	_bag_row(m, Vector2(-0.78, 0.3), Vector2(0.78, 0.3), 2)  # near parapet, 2 courses
	for i in 6:  # spoil banked behind the far parapet
		Base._sp(m, Vector3(-0.66 + 0.26 * float(i), -0.44, 0.05), Vector3(0.18, 0.12, 0.1 + 0.03 * Base._rnd(i, 8)), "e_earth" if i % 2 == 0 else "e_turf")
	Base._bx(m, Vector3(0.78, 0.0, 0.1), Vector3(0.05, 0.3, 0.1), "e_earth")  # trench ends closed with earth ramps
	Base._bx(m, Vector3(-0.8, 0.0, 0.08), Vector3(0.04, 0.26, 0.08), "e_earth")
	_crate(m, Vector3(-0.5, 0.0, 0.085), Vector3(0.1, 0.08, 0.06), "ammo")  # crate and a few shell cases on the floor
	_crate(m, Vector3(0.45, 0.02, 0.085), Vector3(0.09, 0.07, 0.06), "wood")
	Base._bx(m, Vector3(0.1, 0.3, 0.2), Vector3(0.14, 0.01, 0.01), "gun")  # rifle on the near parapet
	Base._bx(m, Vector3(0.2, 0.3, 0.21), Vector3(0.1, 0.01, 0.012), "stock")
	Base._bone(m, Vector3(-0.1, -0.17, 0.0), Vector3(-0.1, -0.33, 0.3), 0.014, 0.012, "wood")  # ladder
	Base._bone(m, Vector3(0.0, -0.17, 0.0), Vector3(0.0, -0.33, 0.3), 0.014, 0.012, "wood")
	for i in 3:
		Base._bx(m, Vector3(-0.05, -0.21 - 0.045 * float(i), 0.05 + 0.08 * float(i)), Vector3(0.06, 0.008, 0.01), "woodd")


## Razor wire: three iron pickets with two stacked coils between them (octagonal loops of thin wire), along x.
static func _razor_wire(m: Array[Prim]) -> void:
	for i in 3:
		var x := -0.7 + 0.7 * float(i)
		Base._bone(m, Vector3(x, 0.0, 0.0), Vector3(x, 0.0, 0.52), 0.016, 0.016, "steel")
		Base._bone(m, Vector3(x, 0.0, 0.0), Vector3(x + 0.1, 0.2, 0.0), 0.014, 0.012, "steel")  # ground anchors
		Base._bone(m, Vector3(x, 0.0, 0.0), Vector3(x - 0.1, -0.2, 0.0), 0.014, 0.012, "steel")
		Base._bone(m, Vector3(x, 0.0, 0.34), Vector3(x + 0.12, 0.2, 0.02), 0.008, 0.008, "rust")  # stays
		Base._bone(m, Vector3(x, 0.0, 0.34), Vector3(x - 0.12, -0.2, 0.02), 0.008, 0.008, "rust")
	for coil in [[0.15, 0.15], [0.42, 0.11]]:
		var zc: float = coil[0]
		var r: float = coil[1]
		var loops := 12
		for k in loops:
			var x := -0.78 + 1.56 * float(k) / float(loops - 1)
			for s in 8:
				var a0 := TAU * float(s) / 8.0 + float(k) * 0.4
				var a1 := TAU * float(s + 1) / 8.0 + float(k) * 0.4
				var p0 := Vector3(x, cos(a0) * r, zc + sin(a0) * r * 0.9)
				var p1 := Vector3(x + 0.04, cos(a1) * r, zc + sin(a1) * r * 0.9)
				Base._bone(m, p0, p1, 0.011, 0.011, "steel" if s % 4 != 0 else "rust")
	for i in 4:  # a few barbs
		Base._bx(m, Vector3(-0.5 + 0.35 * float(i), 0.0, 0.05), Vector3(0.012, 0.012, 0.012), "rust")


## Dragon's teeth: two staggered rows of stepped concrete pyramids along x.
static func _dragons_teeth(m: Array[Prim]) -> void:
	for row in 2:
		var n := 5 if row == 0 else 4
		for i in n:
			var x := (float(i) - float(n - 1) * 0.5) * 0.37
			var y := 0.17 if row == 0 else -0.17
			var jx := (Base._rnd(i, row + 40) - 0.5) * 0.03
			var tall := 0.9 + 0.2 * Base._rnd(i, row + 50)
			var steps := [[0.16, 0.06], [0.13, 0.16], [0.095, 0.25], [0.055, 0.32]]
			var prev_top := 0.0
			for st in steps:
				var h: float = st[0]
				var zt: float = st[1] * tall
				var mat := "concrete" if (i + row) % 2 == 0 else "concretel"
				Base._bx(m, Vector3(x + jx, y, (prev_top + zt) * 0.5), Vector3(h, h, (zt - prev_top) * 0.5), mat)
				prev_top = zt
	Base._bx(m, Vector3(-0.2, 0.17, 0.2), Vector3(0.008, 0.008, 0.008), "rust")


## Towed light field gun: wooden wheels, high barrel on a cradle, closed split trails with spades, shells. Muzzle +x.
static func _field_artillery(m: Array[Prim]) -> void:
	_wheel(m, Vector3(0.0, 0.3, 0.2), 0.2, "wood")
	_wheel(m, Vector3(0.0, -0.3, 0.2), 0.2, "wood")
	Base._bx(m, Vector3(0.0, 0, 0.2), Vector3(0.035, 0.3, 0.035), "steel")  # axle
	Base._bx(m, Vector3(0.0, 0, 0.3), Vector3(0.11, 0.1, 0.07), "hull")  # carriage
	for s: float in [1.0, -1.0]:
		Base._bone(m, Vector3(-0.06, 0.06 * s, 0.26), Vector3(-0.6, 0.12 * s, 0.03), 0.034, 0.032, "hull")
		Base._bx(m, Vector3(-0.62, 0.125 * s, 0.03), Vector3(0.05, 0.06, 0.03), "gun", 0.2 * s)
	Base._bx(m, Vector3(0.1, 0, 0.36), Vector3(0.012, 0.19, 0.09), "hull")  # small low shield
	var e := 0.5
	var dir := Vector3(cos(e), 0, sin(e))
	var breech := Vector3(-0.02, 0, 0.44)
	Base._bx(m, Vector3(-0.02, 0, 0.4), Vector3(0.05, 0.1, 0.06), "gun")  # trunnion block
	_tube(m, breech - dir * 0.1, breech + dir * 0.06, 0.056, "gun")  # breech
	_tube(m, breech + dir * 0.06, breech + dir * 0.4, 0.052, "steel")  # recoil sleeve
	_tube(m, breech + dir * 0.4, breech + dir * 0.95, 0.03, "steel")  # barrel
	_tube(m, breech + dir * 0.9, breech + dir * 1.0, 0.045, "gun")  # muzzle brake
	Base._bx(m, Vector3(-0.1, 0.14, 0.4), Vector3(0.05, 0.015, 0.05), "gun")  # elevating handwheel mount
	Base._cy(m, Vector3(-0.1, 0.17, 0.4), 0.045, 0.008, "steel")
	Base._bx(m, Vector3(0.02, -0.14, 0.5), Vector3(0.03, 0.02, 0.03), "glass")  # sight
	for i in 3:  # shells in a rack at the trail
		Base._bone(m, Vector3(-0.3 + 0.06 * float(i), -0.17, 0.1), Vector3(-0.28 + 0.06 * float(i), -0.17, 0.24), 0.02, 0.02, "brass")
	Base._bx(m, Vector3(-0.32, 0.0, 0.14), Vector3(0.012, 0.018, 0.012), "gun")


## Ammo dump: sandbag walls on three sides round stacks of crates and shells, a tarp over the back half.
static func _ammo_dump(m: Array[Prim]) -> void:
	Base._bx(m, Vector3(0, 0, 0.012), Vector3(0.78, 0.78, 0.012), "dirt")
	_bag_row(m, Vector2(-0.7, -0.7), Vector2(-0.7, 0.7), 3)  # back wall
	_bag_row(m, Vector2(-0.7, 0.7), Vector2(0.7, 0.7), 3)  # left wall (+y), faces the camera
	_bag_row(m, Vector2(-0.7, -0.7), Vector2(0.7, -0.7), 3)  # right wall (-y)
	_bag_row(m, Vector2(0.7, 0.7), Vector2(0.7, 0.28), 3)  # front wall with a gap
	_bag_row(m, Vector2(0.7, -0.7), Vector2(0.7, -0.28), 3)
	_crate(m, Vector3(-0.44, 0.38, 0.1), Vector3(0.16, 0.13, 0.1), "cardboard")  # crate stacks
	_crate(m, Vector3(-0.44, 0.38, 0.3), Vector3(0.15, 0.12, 0.1), "ammo")
	_crate(m, Vector3(-0.44, -0.3, 0.1), Vector3(0.16, 0.13, 0.1), "ammo")
	_crate(m, Vector3(-0.44, -0.3, 0.3), Vector3(0.14, 0.12, 0.1), "cardboard")
	_crate(m, Vector3(-0.1, 0.4, 0.09), Vector3(0.15, 0.12, 0.09), "wood")
	_crate(m, Vector3(-0.1, -0.35, 0.09), Vector3(0.14, 0.12, 0.09), "cardboard")
	_crate(m, Vector3(-0.1, -0.35, 0.27), Vector3(0.12, 0.1, 0.08), "ammo")
	for iy in 3:  # shells stacked upright in the middle
		for ix in 3:
			_shell(m, Vector3(0.12 + 0.1 * float(ix), -0.1 + 0.1 * float(iy), 0.12), 0.036, 0.12)
	for s: float in [1.0, -1.0]:  # tarp poles and the tarp over the back, sloping down toward the front
		Base._bone(m, Vector3(-0.66, 0.62 * s, 0.0), Vector3(-0.66, 0.62 * s, 0.68), 0.016, 0.016, "woodd")
		Base._bone(m, Vector3(-0.22, 0.62 * s, 0.0), Vector3(-0.22, 0.62 * s, 0.5), 0.016, 0.016, "woodd")
	m.append(Prim.new(Base.BOX, Vector3(-0.44, 0, 0.6), Vector3(0.25, 0.66, 0.014), "e_tarp", 0.0, 0.0, 0.38))
	Base._bx(m, Vector3(-0.2, 0.0, 0.5), Vector3(0.01, 0.62, 0.02), "e_tarp")  # front hem
	Base._bx(m, Vector3(0.62, 0.0, 0.03), Vector3(0.1, 0.26, 0.012), "e_earth")  # worn track through the gap
	Base._bx(m, Vector3(0.5, 0.26, 0.12), Vector3(0.012, 0.012, 0.06), "red")  # warning sign post
	Base._bx(m, Vector3(0.514, 0.26, 0.2), Vector3(0.008, 0.06, 0.05), "red")
	Base._bx(m, Vector3(0.52, 0.26, 0.2), Vector3(0.006, 0.03, 0.02), "whitep")


## Mobile radar: boxy shelter on a wheeled bed, a mast and a tilted parabolic dish facing +x.
static func _radar_dish(m: Array[Prim]) -> void:
	Base._bx(m, Vector3(-0.05, 0, 0.15), Vector3(0.38, 0.22, 0.03), "hull")  # bed
	for s: float in [1.0, -1.0]:
		_wheel(m, Vector3(-0.2, 0.26 * s, 0.1), 0.1)
		Base._bone(m, Vector3(0.28, 0.2 * s, 0.17), Vector3(0.33, 0.3 * s, 0.02), 0.014, 0.014, "steel")  # jacks
	Base._bone(m, Vector3(0.3, 0, 0.14), Vector3(0.48, 0, 0.07), 0.025, 0.02, "gun")  # towbar
	Base._bx(m, Vector3(-0.2, 0, 0.3), Vector3(0.16, 0.18, 0.12), "tankg")  # equipment shelter
	Base._bx(m, Vector3(-0.2, 0, 0.425), Vector3(0.165, 0.185, 0.012), "gun")
	Base._bx(m, Vector3(-0.039, 0.0, 0.3), Vector3(0.005, 0.11, 0.08), "gun")  # shelter door
	Base._bx(m, Vector3(-0.037, 0.0, 0.3), Vector3(0.004, 0.09, 0.06), "tankg")
	Base._bx(m, Vector3(-0.2, 0.183, 0.3), Vector3(0.06, 0.005, 0.04), "glass")
	Base._cy(m, Vector3(0.1, 0, 0.3), 0.035, 0.15, "steel")  # mast
	Base._cy(m, Vector3(0.1, 0, 0.47), 0.05, 0.03, "gun")  # rotating head
	var ctr := Vector3(0.14, 0, 0.66)
	var e := 0.55  # dish tilt (rad above the horizon)
	var n := Vector3(cos(e), 0, sin(e))
	var ny := Vector3(0, 1, 0)
	var nz := n.cross(ny)
	var face := Basis(n, ny, nz)
	var d1 := Prim.new(Base.SPH, ctr, Vector3(0.03, 0.27, 0.27), "whitep")  # dish: a flattened ellipsoid turned to face n
	d1.basis = face
	m.append(d1)
	var d2 := Prim.new(Base.SPH, ctr + n * 0.018, Vector3(0.022, 0.22, 0.22), "steel")  # concave face
	d2.basis = face
	m.append(d2)
	_tube(m, ctr - n * 0.02, ctr - n * 0.14, 0.04, "gun")  # backing hub
	Base._bone(m, ctr + n * 0.03, ctr + n * 0.26, 0.01, 0.01, "steel")  # feed horn boom
	Base._bx(m, ctr + n * 0.28, Vector3(0.025, 0.025, 0.025), "red")
	Base._bone(m, Vector3(0.1, 0, 0.5), ctr - n * 0.1, 0.02, 0.02, "gun")


## MG bunker: sandbag walls, a front wall with an embrasure, overhead roof of logs and earth. MG barrel at +x.
static func _mg_bunker(m: Array[Prim]) -> void:
	_disc(m, Vector3(0, 0, 0), 0.44, "dirt")
	Base._bx(m, Vector3(-0.05, 0, 0.02), Vector3(0.28, 0.27, 0.02), "e_pit")
	_bag_row(m, Vector2(0.32, 0.36), Vector2(0.32, 0.06), 3)  # front wall, embrasure between
	_bag_row(m, Vector2(0.32, -0.36), Vector2(0.32, -0.06), 3)
	_bag_row(m, Vector2(0.32, 0.06), Vector2(0.32, -0.06), 1)  # one bag under the embrasure
	_bag_row(m, Vector2(0.32, 0.36), Vector2(-0.3, 0.36), 2)  # side walls
	_bag_row(m, Vector2(0.32, -0.36), Vector2(-0.3, -0.36), 2)
	for sx: float in [1.0, -1.0]:
		for sy: float in [1.0, -1.0]:
			Base._bone(m, Vector3(0.27 * sx, 0.3 * sy, 0.0), Vector3(0.27 * sx, 0.3 * sy, 0.4), 0.025, 0.025, "woodd")
	for i in 7:  # log roof: logs run along y
		var x := -0.28 + 0.1 * float(i)
		_tube(m, Vector3(x, -0.38, 0.42), Vector3(x, 0.38, 0.42), 0.05, "wood" if i % 2 == 0 else "woodd")
	Base._sp(m, Vector3(0.0, 0, 0.44), Vector3(0.36, 0.4, 0.15), "e_earth")  # earth heaped on the roof
	Base._sp(m, Vector3(-0.08, 0.1, 0.52), Vector3(0.24, 0.24, 0.1), "e_turf")
	Base._sp(m, Vector3(-0.16, -0.14, 0.5), Vector3(0.14, 0.16, 0.09), "e_camo")
	Base._sp(m, Vector3(0.14, -0.1, 0.48), Vector3(0.1, 0.1, 0.06), "e_camod")
	Base._bx(m, Vector3(0.325, 0, 0.27), Vector3(0.012, 0.075, 0.07), "e_ink")  # dark embrasure
	_tube(m, Vector3(0.05, 0, 0.2), Vector3(0.5, 0, 0.2), 0.022, "gun")  # MG barrel through the slit
	_tube(m, Vector3(0.28, 0, 0.2), Vector3(0.42, 0, 0.2), 0.034, "steel")  # barrel jacket
	Base._bx(m, Vector3(0.02, 0, 0.2), Vector3(0.1, 0.04, 0.045), "gun")  # receiver
	Base._bx(m, Vector3(-0.02, 0.07, 0.17), Vector3(0.05, 0.035, 0.04), "ammo")  # ammo can
	Base._bone(m, Vector3(0.2, 0, 0.19), Vector3(0.26, 0.07, 0.04), 0.01, 0.01, "steel")  # bipod
	Base._bone(m, Vector3(0.2, 0, 0.19), Vector3(0.26, -0.07, 0.04), 0.01, 0.01, "steel")
