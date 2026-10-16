extends RefCounted
## Theme pack: infantry (static posed soldiers used as map dressing, one frame, four diagonal facings). Loaded by
## tools/gen_sprites.gd, see docs/specs/art-pack-2.md and the contract in pack_nature.gd. Material prefix `i_`,
## category `infantry`. Same proportions and olive uniform family as the rifle soldier (k 1.0, ~0.94 tall standing).
## The rig is the soldier's (torso, vest, head with a face, helmet, two-bone legs and arms); the arm and gun helpers
## of gen_sprites.gd are called through `host`. Axes: +x front (the way the figure faces), +y left, +z up.

const Base = preload("res://tools/gen_sprites.gd")
const Prim = Base.Prim

const MATS := {
	"i_ghillie": ["343f20", "4f5f33", "6e8248"],
	"i_ghillie2": ["4a4024", "665a35", "84764a"],
	"i_toolbox": ["4a1c14", "7a3224", "a44c36"],
	"i_radio": ["222b20", "343f2e", "4a5842"],
	"i_cap": ["2e3a24", "445535", "5f7449"],
	"i_tank": ["50554a", "7a806c", "a2a98e"],
	"i_c4": ["6a5a38", "8f7c4e", "b5a06a"],
	"i_map": ["a8a08a", "d0c8b0", "eeeadc"],
	"i_plate": ["24291f", "353c2d", "495240"],
	"i_visor": ["14171a", "1f2429", "2c343b"],
}

const FOUR: Array = ["se", "nw", "sw", "ne"]
const UP := Vector3(0, 0, 1)


static func _spec(dir: String, name: String) -> Dictionary:
	return {"dir": dir, "name": name, "cat": "infantry", "auto": true, "k": 1.0, "frames": 1, "columns": 1, "ss": 3, "facings": FOUR, "foot": Vector2i(1, 1)}


static func specs() -> Array:
	return [
		_spec("inf_sentry", "Sentry"),
		_spec("inf_sniper_prone", "Prone Sniper"),
		_spec("inf_machine_gunner", "Machine Gunner"),
		_spec("inf_medic", "Medic"),
		_spec("inf_engineer", "Engineer"),
		_spec("inf_grenadier", "Grenadier"),
		_spec("inf_officer", "Officer"),
		_spec("inf_flamethrower", "Flamethrower Trooper"),
		_spec("inf_heavy_gunner", "Heavy Gunner"),
		_spec("inf_scout", "Scout"),
		_spec("inf_radio_operator", "Radio Operator"),
		_spec("inf_fallen", "Fallen Soldier"),
		_spec("inf_rpg_kneel", "Kneeling Rocketeer"),
		_spec("inf_rifleman_kneel", "Kneeling Rifleman"),
	]


static func build(host: Object, m: Array[Prim], unit: String, _frame: int) -> bool:
	match unit:
		"inf_sentry":
			_sentry(host, m)
		"inf_sniper_prone":
			_sniper(host, m)
		"inf_machine_gunner":
			_mg(host, m)
		"inf_medic":
			_medic(host, m)
		"inf_engineer":
			_engineer(host, m)
		"inf_grenadier":
			_grenadier(host, m)
		"inf_officer":
			_officer(host, m)
		"inf_flamethrower":
			_flamer(host, m)
		"inf_heavy_gunner":
			_heavy(host, m)
		"inf_scout":
			_scout(host, m)
		"inf_radio_operator":
			_radio(host, m)
		"inf_fallen":
			_fallen(host, m)
		"inf_rpg_kneel":
			_rpg(host, m)
		"inf_rifleman_kneel":
			_rifleman(host, m)
		_:
			return false
	return true


# ---------------------------------------------------------------- the rig

static func _p(m: Array[Prim], kind: int, c: Vector3, h: Vector3, mat: String, lean: float = 0.0) -> void:
	m.append(Prim.new(kind, c, h, mat, 0.0, 0.0, lean))


## Both legs: hip joints at hip +- 0.06 y, ankles at `fl` / `fr`, knees bend toward the poles; boots point along `bdl` / `bdr`.
static func _legs(m: Array[Prim], hip: Vector3, fl: Vector3, fr: Vector3, pl: Vector3 = Vector3(1, 0, 0.15), pr: Vector3 = Vector3(1, 0, 0.15), bdl: Vector3 = Vector3(1, 0, 0), bdr: Vector3 = Vector3(1, 0, 0)) -> void:
	for side: int in [1, -1]:
		var foot: Vector3 = fl if side == 1 else fr
		var pole: Vector3 = pl if side == 1 else pr
		var bd: Vector3 = bdl if side == 1 else bdr
		var hj := hip + Vector3(0, 0.06 * float(side), 0)
		var ik: Array = Base._ik2(hj, foot, 0.19, 0.19, pole)
		var knee: Vector3 = ik[0]
		var ankle: Vector3 = ik[1]
		Base._bone(m, hj, knee, 0.047, 0.047, "uni")
		Base._bone(m, knee, ankle, 0.04, 0.04, "uni")
		Base._bone(m, ankle - bd * 0.035 + Vector3(0, 0, -0.025), ankle + bd * 0.1 + Vector3(0, 0, -0.03), 0.045, 0.04, "boot")


## Torso with vest, pouches, belt and pack (as the rifle soldier), pitched forward by `lean`. `bulk` widens it.
static func _torso(m: Array[Prim], hip: Vector3, lean: float, pack: bool = true, bulk: float = 1.0) -> void:
	var tb := Basis(Vector3(0, 1, 0), lean)
	_p(m, Base.BOX, hip + tb * Vector3(0, 0, 0.14), Vector3(0.07 * bulk, 0.105 * bulk, 0.135), "uni", lean)
	_p(m, Base.BOX, hip + tb * Vector3(0.03, 0, 0.15), Vector3(0.05 * bulk, 0.108 * bulk, 0.105), "vest", lean)
	_p(m, Base.BOX, hip + tb * Vector3(0.062 * bulk, 0.05, 0.12), Vector3(0.016, 0.028, 0.03), "belt", lean)
	_p(m, Base.BOX, hip + tb * Vector3(0.062 * bulk, -0.05, 0.12), Vector3(0.016, 0.028, 0.03), "belt", lean)
	_p(m, Base.BOX, hip + tb * Vector3(0, 0, 0.01), Vector3(0.075 * bulk, 0.108 * bulk, 0.022), "belt", lean)
	if pack:
		_p(m, Base.BOX, hip + tb * Vector3(-0.10 * bulk, 0, 0.15), Vector3(0.055, 0.08, 0.10), "pack", lean)


## Head with face (eyes, nose, mouth, ears) and helmet. `face_up` leaves out the face details (a fallen soldier).
static func _head(m: Array[Prim], head: Vector3, helm: String = "helm", face: bool = true, lean: float = 0.0) -> void:
	_p(m, Base.SPH, head, Vector3(0.078, 0.07, 0.082), "skin")
	for side: float in [1.0, -1.0]:
		_p(m, Base.BOX, head + Vector3(0, 0.074 * side, -0.01), Vector3(0.012, 0.01, 0.02), "skin")
		if face:
			_p(m, Base.BOX, head + Vector3(0.071, 0.029 * side, 0.0), Vector3(0.016, 0.016, 0.016), "eye")
	if face:
		_p(m, Base.BOX, head + Vector3(0.082, 0, -0.016), Vector3(0.014, 0.012, 0.022), "skin")
		_p(m, Base.BOX, head + Vector3(0.072, 0, -0.045), Vector3(0.01, 0.026, 0.007), "lip")
		_p(m, Base.BOX, head + Vector3(0.058, 0, -0.068), Vector3(0.012, 0.05, 0.007), "belt")
	if helm != "":
		_p(m, Base.SPH, head + Vector3(-0.005, 0, 0.05), Vector3(0.098, 0.09, 0.065), helm)
		_p(m, Base.CYL, head + Vector3(0.012, 0, 0.012), Vector3(0.108, 0, 0.01), helm)
		_p(m, Base.CYL, head + Vector3(-0.005, 0, 0.046), Vector3(0.101, 0, 0.011), "belt")


## Standing rig: returns the points every pose needs (head, shoulders, torso basis).
static func _rig(m: Array[Prim], hip: Vector3, lean: float, fl: Vector3, fr: Vector3, pl: Vector3 = Vector3(1, 0, 0.15), pr: Vector3 = Vector3(1, 0, 0.15), pack: bool = true, helm: String = "helm", bulk: float = 1.0) -> Dictionary:
	var tb := Basis(Vector3(0, 1, 0), lean)
	_legs(m, hip, fl, fr, pl, pr)
	_torso(m, hip, lean, pack, bulk)
	_p(m, Base.CYL, hip + tb * Vector3(0.015, 0, 0.29), Vector3(0.036, 0, 0.03), "skin")
	var head := hip + tb * Vector3(0.04, 0, 0.36)
	_head(m, head, helm)
	return {"tb": tb, "head": head, "sl": hip + tb * Vector3(0, 0.145 * bulk, 0.25), "sr": hip + tb * Vector3(0, -0.145 * bulk, 0.25), "hip": hip}


## Kneeling legs: right knee down, left foot forward. Returns the hip to use (z 0.25).
static func _kneel_rig(m: Array[Prim], lean: float = 0.15, pack: bool = true, helm: String = "helm") -> Dictionary:
	var hip := Vector3(0, 0, 0.25)
	var r := _rig(m, hip, lean, Vector3(0.22, 0.1, 0.065), Vector3(-0.17, -0.1, 0.06), Vector3(0, 0, 1), Vector3(1, 0, -0.6), pack, helm)
	return r


static func _arm(host: Object, m: Array[Prim], shoulder: Vector3, hand: Vector3, side: int) -> void:
	host._arm(m, shoulder, hand, side, "uni", "skin")


# ---------------------------------------------------------------- poses

## Standing at ease, rifle slung muzzle-up on the right shoulder, one hand on the sling.
static func _sentry(host: Object, m: Array[Prim]) -> void:
	var r := _rig(m, Vector3(0, 0, 0.385), 0.03, Vector3(0.03, 0.09, 0.065), Vector3(-0.02, -0.09, 0.065))
	host._rifle(m, Vector3(-0.09, -0.17, 0.2), Vector3(0.1, 0.0, 1.0).normalized())
	Base._bone(m, Vector3(-0.02, -0.14, 0.7), Vector3(0.07, 0.08, 0.34), 0.012, 0.01, "belt")  # sling
	_arm(host, m, r["sr"], Vector3(0.09, -0.1, 0.5), -1)
	_arm(host, m, r["sl"], Vector3(0.0, 0.17, 0.3), 1)


## Prone sniper: face down, long rifle with a scope on a bipod, ghillie scraps over back and helmet.
static func _sniper(host: Object, m: Array[Prim]) -> void:
	var lean := 1.42
	var hip := Vector3(-0.22, 0, 0.075)
	var tb := Basis(Vector3(0, 1, 0), lean)
	for side: int in [1, -1]:  # legs straight back, toes on the ground
		var hj := hip + Vector3(0, 0.06 * float(side), 0)
		var ank := Vector3(-0.58, 0.1 * float(side), 0.055)
		Base._bone(m, hj, hj.lerp(ank, 0.5) + Vector3(0, 0, 0.012), 0.047, 0.045, "uni")
		Base._bone(m, hj.lerp(ank, 0.5) + Vector3(0, 0, 0.012), ank, 0.04, 0.04, "uni")
		Base._bone(m, ank, ank + Vector3(-0.11, 0.0, 0.0), 0.045, 0.035, "boot")
	_torso(m, hip, lean, true)
	var head := hip + tb * Vector3(0.04, 0, 0.36)
	_head(m, head, "helm", true)
	var sr := hip + tb * Vector3(0, -0.145, 0.25)
	var sl := hip + tb * Vector3(0, 0.145, 0.25)
	# long rifle: stock, receiver, heavy barrel, scope, bipod
	var b := Vector3(-0.0, -0.11, 0.14)
	Base._bone(m, b, b + Vector3(0.16, 0, 0.0), 0.02, 0.04, "stock")
	Base._bone(m, b + Vector3(0.16, 0, 0), b + Vector3(0.34, 0, 0.0), 0.024, 0.035, "gun")
	Base._bone(m, b + Vector3(0.34, 0, 0), b + Vector3(0.7, 0, 0.02), 0.014, 0.014, "gun")
	Base._bone(m, b + Vector3(0.66, 0, 0.02), b + Vector3(0.74, 0, 0.02), 0.02, 0.02, "gun")  # muzzle brake
	Base._bone(m, b + Vector3(0.18, 0, 0.05), b + Vector3(0.38, 0, 0.05), 0.02, 0.02, "gun")  # scope tube
	Base._bx(m, b + Vector3(0.4, 0, 0.05), Vector3(0.012, 0.026, 0.026), "glass")
	Base._bx(m, b + Vector3(0.2, 0, 0.065), Vector3(0.02, 0.02, 0.012), "gun")
	Base._bone(m, b + Vector3(0.5, 0, 0), b + Vector3(0.56, 0.07, -0.1), 0.008, 0.008, "steel")  # bipod
	Base._bone(m, b + Vector3(0.5, 0, 0), b + Vector3(0.56, -0.07, -0.1), 0.008, 0.008, "steel")
	_arm(host, m, sr, b + Vector3(0.12, 0.0, 0.0), -1)
	_arm(host, m, sl, b + Vector3(0.3, 0.05, -0.05), 1)
	for i in 9:  # ghillie scraps over the back and the helmet
		var a := float(i)
		var pos := hip + tb * Vector3(-0.12 + 0.01 * a, (Base._rnd(i, 61) - 0.5) * 0.22, 0.04 + 0.025 * a)
		Base._sp(m, pos, Vector3(0.04, 0.035, 0.03), "i_ghillie" if i % 2 == 0 else "i_ghillie2")
	for i in 4:
		Base._sp(m, head + Vector3(-0.04 + 0.03 * float(i), (Base._rnd(i, 66) - 0.5) * 0.12, 0.1), Vector3(0.04, 0.04, 0.025), "i_ghillie" if i % 2 == 0 else "i_ghillie2")
	_p(m, Base.BOX, hip + tb * Vector3(0.0, 0, 0.19), Vector3(0.06, 0.13, 0.15), "i_ghillie", lean)  # ghillie cloak over back and shoulders
	Base._bx(m, hip + Vector3(-0.2, 0.0, 0.095), Vector3(0.14, 0.13, 0.04), "i_ghillie2")
	for i in 7:
		var tx := -0.45 + 0.1 * float(i)
		Base._sp(m, Vector3(tx, (Base._rnd(i, 71) - 0.5) * 0.2, 0.1), Vector3(0.05, 0.045, 0.035), "i_ghillie" if i % 2 == 1 else "i_ghillie2")


## Kneeling behind a light machine gun on its bipod, belt running to an ammo box.
static func _mg(host: Object, m: Array[Prim]) -> void:
	var r := _kneel_rig(m, 0.22)
	var tb: Basis = r["tb"]
	var hip: Vector3 = r["hip"]
	var butt := hip + tb * Vector3(-0.03, -0.098, 0.265)
	var u := (tb * Vector3(1.0, 0.1, -0.03)).normalized()
	var pts: Dictionary = host._rifle(m, butt, u)
	Base._bx(m, butt + u * 0.24 + Vector3(0, 0.0, 0.02), Vector3(0.06, 0.04, 0.04), "gun")  # big receiver
	Base._bone(m, butt + u * 0.45, butt + u * 0.62, 0.02, 0.02, "steel")  # barrel jacket
	Base._bone(m, butt + u * 0.62, butt + u * 0.72, 0.014, 0.014, "gun")
	var foot: Vector3 = butt + u * 0.5
	for s: float in [1.0, -1.0]:  # bipod
		Base._bone(m, foot, Vector3(foot.x + 0.12, foot.y + 0.1 * s, 0.015), 0.01, 0.01, "steel")
	var box := Vector3(0.28, 0.2, 0.06)
	Base._bx(m, box, Vector3(0.07, 0.045, 0.055), "ammo")  # ammo box with the belt up to the gun
	Base._bx(m, box + Vector3(0.071, 0, 0), Vector3(0.006, 0.03, 0.03), "brass")
	for i in 5:
		var t := float(i) / 4.0
		var pos := box.lerp(butt + u * 0.22, t) + Vector3(0, -0.03 * sin(t * PI), 0.08 * t + 0.03)
		Base._bx(m, pos, Vector3(0.016, 0.014, 0.014), "brass")
	_arm(host, m, r["sr"], pts["grip"], -1)
	_arm(host, m, r["sl"], pts["fore"], 1)


## Medic kneeling beside an open aid bag, white cross on the helmet, red cross on the pack, armband.
static func _medic(host: Object, m: Array[Prim]) -> void:
	var r := _kneel_rig(m, 0.2, false)
	var tb: Basis = r["tb"]
	var hip: Vector3 = r["hip"]
	var head: Vector3 = r["head"]
	# medical backpack: pack with a white square and red cross on the back and both sides
	_p(m, Base.BOX, hip + tb * Vector3(-0.115, 0, 0.17), Vector3(0.06, 0.1, 0.125), "pack", 0.2)
	for s: float in [-1.0]:
		_p(m, Base.BOX, hip + tb * Vector3(-0.178, 0, 0.17), Vector3(0.006, 0.07, 0.07), "whitep", 0.2)
		_p(m, Base.BOX, hip + tb * Vector3(-0.184, 0, 0.17), Vector3(0.006, 0.05, 0.016), "red", 0.2)
		_p(m, Base.BOX, hip + tb * Vector3(-0.184, 0, 0.17), Vector3(0.006, 0.016, 0.05), "red", 0.2)
	for s: float in [1.0, -1.0]:  # side plates, seen from the left
		_p(m, Base.BOX, hip + tb * Vector3(-0.115, 0.104 * s, 0.17), Vector3(0.045, 0.006, 0.045), "whitep", 0.2)
		_p(m, Base.BOX, hip + tb * Vector3(-0.115, 0.11 * s, 0.17), Vector3(0.04, 0.006, 0.012), "red", 0.2)
		_p(m, Base.BOX, hip + tb * Vector3(-0.115, 0.11 * s, 0.17), Vector3(0.012, 0.006, 0.04), "red", 0.2)
	# helmet cross on the front and sides
	_p(m, Base.BOX, head + Vector3(0.082, 0, 0.065), Vector3(0.012, 0.045, 0.04), "whitep")
	_p(m, Base.BOX, head + Vector3(0.09, 0, 0.065), Vector3(0.008, 0.035, 0.01), "red")
	_p(m, Base.BOX, head + Vector3(0.09, 0, 0.065), Vector3(0.008, 0.01, 0.03), "red")
	for s: float in [1.0, -1.0]:
		_p(m, Base.BOX, head + Vector3(-0.005, 0.082 * s, 0.07), Vector3(0.026, 0.008, 0.024), "whitep")
		_p(m, Base.BOX, head + Vector3(-0.005, 0.09 * s, 0.07), Vector3(0.02, 0.006, 0.006), "red")
		_p(m, Base.BOX, head + Vector3(-0.005, 0.09 * s, 0.07), Vector3(0.006, 0.006, 0.02), "red")
	# aid bag on the ground, lid open, bandages
	var bag := Vector3(0.2, 0.3, 0.0)
	Base._bx(m, bag + Vector3(0, 0, 0.055), Vector3(0.1, 0.075, 0.055), "uni")
	Base._bx(m, bag + Vector3(0, 0, 0.112), Vector3(0.1, 0.075, 0.01), "vest")
	Base._bx(m, bag + Vector3(0.102, 0, 0.06), Vector3(0.006, 0.05, 0.04), "whitep")  # cross on the front
	Base._bx(m, bag + Vector3(0.108, 0, 0.06), Vector3(0.006, 0.03, 0.01), "red")
	Base._bx(m, bag + Vector3(0.108, 0, 0.06), Vector3(0.006, 0.01, 0.03), "red")
	Base._bx(m, bag + Vector3(-0.02, 0.0, 0.126), Vector3(0.04, 0.03, 0.018), "whitep")  # bandages poking out
	Base._cy(m, bag + Vector3(0.04, -0.02, 0.13), 0.022, 0.018, "whitep")
	# armband on the left sleeve
	var sl: Vector3 = r["sl"]
	_arm(host, m, r["sr"], bag + Vector3(0.0, -0.07, 0.12), -1)
	_arm(host, m, sl, hip + Vector3(0.22, 0.2, 0.12), 1)
	_p(m, Base.BOX, sl + Vector3(0.02, 0.01, -0.07), Vector3(0.04, 0.04, 0.035), "whitep")
	_p(m, Base.BOX, sl + Vector3(0.02, 0.05, -0.07), Vector3(0.025, 0.006, 0.008), "red")
	_p(m, Base.BOX, sl + Vector3(0.02, 0.05, -0.07), Vector3(0.008, 0.006, 0.025), "red")


## Engineer walking with a toolbox in one hand, a demolition pack on the chest and a shovel across the back.
static func _engineer(host: Object, m: Array[Prim]) -> void:
	var r := _rig(m, Vector3(0, 0, 0.385), 0.08, Vector3(0.1, 0.09, 0.065), Vector3(-0.06, -0.09, 0.065))
	var tb: Basis = r["tb"]
	var hip: Vector3 = r["hip"]
	var head: Vector3 = r["head"]
	_p(m, Base.BOX, head + Vector3(0.078, 0, 0.032), Vector3(0.016, 0.07, 0.016), "i_visor")  # goggles on the helmet
	_p(m, Base.BOX, hip + tb * Vector3(0.09, 0, 0.17), Vector3(0.03, 0.09, 0.07), "i_c4", 0.08)  # demo charges on the chest
	_p(m, Base.BOX, hip + tb * Vector3(0.123, 0.03, 0.17), Vector3(0.006, 0.012, 0.06), "belt", 0.08)
	_p(m, Base.BOX, hip + tb * Vector3(0.123, -0.04, 0.17), Vector3(0.006, 0.012, 0.06), "belt", 0.08)
	_p(m, Base.BOX, hip + tb * Vector3(0.126, 0.07, 0.22), Vector3(0.006, 0.014, 0.014), "red", 0.08)
	Base._bone(m, hip + tb * Vector3(-0.14, 0.07, 0.0), hip + tb * Vector3(-0.2, 0.07, 0.5), 0.014, 0.014, "wood")  # shovel
	Base._bx(m, hip + tb * Vector3(-0.205, 0.07, 0.58), Vector3(0.012, 0.055, 0.065), "steel", 0.0)
	Base._bone(m, hip + tb * Vector3(-0.14, -0.06, 0.04), hip + tb * Vector3(-0.15, 0.1, 0.34), 0.02, 0.02, "canvas")  # rolled wire/canvas
	var hand_r := Vector3(0.03, -0.17, 0.22)
	_arm(host, m, r["sr"], hand_r, -1)
	_arm(host, m, r["sl"], Vector3(0.12, 0.2, 0.46), 1)
	Base._bx(m, hand_r + Vector3(0, -0.01, -0.06), Vector3(0.09, 0.035, 0.05), "i_toolbox")  # toolbox
	Base._bx(m, hand_r + Vector3(0, -0.01, -0.02), Vector3(0.092, 0.037, 0.01), "steel")
	Base._bx(m, hand_r + Vector3(0.0, -0.01, 0.0), Vector3(0.05, 0.02, 0.008), "gun")  # handle
	Base._bx(m, hand_r + Vector3(0.093, -0.01, -0.06), Vector3(0.006, 0.014, 0.014), "brass")


## Grenadier in a throwing pose: launcher slung across the chest, grenade bandolier, right arm cocked back.
static func _grenadier(host: Object, m: Array[Prim]) -> void:
	var r := _rig(m, Vector3(0, 0, 0.385), -0.06, Vector3(0.14, 0.09, 0.065), Vector3(-0.12, -0.1, 0.065))
	var tb: Basis = r["tb"]
	var hip: Vector3 = r["hip"]
	# launcher across the chest: short fat barrel, wooden stock, running from the right hip up to the left shoulder
	var a := hip + tb * Vector3(0.09, -0.1, 0.1)
	var b := hip + tb * Vector3(0.1, 0.14, 0.34)
	Base._bone(m, a, b, 0.032, 0.032, "gun")
	Base._bone(m, a, a - (b - a).normalized() * 0.12, 0.022, 0.03, "stock")
	Base._bone(m, b, b + (b - a).normalized() * 0.04, 0.04, 0.04, "steel")  # open muzzle
	for i in 5:  # bandolier
		var t := float(i) / 4.0
		Base._bx(m, hip + tb * Vector3(0.075, 0.1 - 0.2 * t, 0.3 - 0.2 * t), Vector3(0.012, 0.016, 0.03), "warhead")
		Base._bx(m, hip + tb * Vector3(0.075, 0.1 - 0.2 * t, 0.335 - 0.2 * t), Vector3(0.012, 0.016, 0.008), "brass")
	var hand_r := hip + Vector3(-0.17, -0.2, 0.62)
	_arm(host, m, r["sr"], hand_r, -1)
	_arm(host, m, r["sl"], hip + Vector3(0.3, 0.12, 0.6), 1)
	Base._sp(m, hand_r + Vector3(-0.02, 0.0, 0.06), Vector3(0.036, 0.036, 0.045), "tube")  # grenade
	Base._bx(m, hand_r + Vector3(-0.02, 0.0, 0.11), Vector3(0.016, 0.016, 0.014), "steel")


## Officer: peaked cap, map board in one hand, binoculars on the chest, pistol holster and cross strap, no rifle.
static func _officer(host: Object, m: Array[Prim]) -> void:
	var r := _rig(m, Vector3(0, 0, 0.385), 0.03, Vector3(0.05, 0.09, 0.065), Vector3(-0.03, -0.09, 0.065), Vector3(1, 0, 0.15), Vector3(1, 0, 0.15), false, "")
	var tb: Basis = r["tb"]
	var hip: Vector3 = r["hip"]
	var head: Vector3 = r["head"]
	_p(m, Base.CYL, head + Vector3(-0.005, 0, 0.065), Vector3(0.088, 0, 0.032), "i_cap")  # peaked cap
	_p(m, Base.CYL, head + Vector3(-0.005, 0, 0.1), Vector3(0.1, 0, 0.012), "i_cap")
	_p(m, Base.BOX, head + Vector3(0.08, 0, 0.05), Vector3(0.05, 0.075, 0.008), "belt")  # visor
	_p(m, Base.BOX, head + Vector3(0.088, 0, 0.073), Vector3(0.008, 0.016, 0.014), "brass")  # cap badge
	for s: float in [1.0, -1.0]:
		_p(m, Base.BOX, hip + tb * Vector3(0.0, 0.14 * s, 0.265), Vector3(0.026, 0.026, 0.01), "brass")  # shoulder boards
	_p(m, Base.BOX, hip + tb * Vector3(0.075, 0, 0.1), Vector3(0.012, 0.11, 0.012), "belt")  # Sam Browne belt
	Base._bone(m, hip + tb * Vector3(0.07, 0.1, 0.26), hip + tb * Vector3(0.075, -0.07, 0.04), 0.012, 0.01, "belt")  # cross strap
	Base._bx(m, hip + tb * Vector3(0.0, -0.13, -0.03), Vector3(0.04, 0.022, 0.05), "belt")  # holster on the right hip
	Base._bx(m, hip + tb * Vector3(0.03, -0.13, -0.0), Vector3(0.012, 0.014, 0.02), "gun")
	Base._bx(m, hip + tb * Vector3(0.082, 0.01, 0.2), Vector3(0.02, 0.05, 0.026), "gun")  # binoculars on the chest
	for s: float in [1.0, -1.0]:
		Base._cy(m, hip + tb * Vector3(0.1, 0.03 * s + 0.01, 0.2), 0.016, 0.02, "steel")
	var map_c := Vector3(0.2, 0.06, 0.47)
	Base._bx(m, map_c, Vector3(0.1, 0.13, 0.008), "i_map")  # map board held in front
	Base._bx(m, map_c + Vector3(0.0, 0, -0.005), Vector3(0.104, 0.134, 0.004), "stock")
	Base._bx(m, map_c + Vector3(-0.03, 0.02, 0.01), Vector3(0.04, 0.003, 0.0035), "red")
	Base._bone(m, map_c + Vector3(-0.04, -0.06, 0.012), map_c + Vector3(0.06, 0.07, 0.012), 0.004, 0.0035, "gun")
	_arm(host, m, r["sl"], map_c + Vector3(-0.04, 0.12, -0.01), 1)
	_arm(host, m, r["sr"], map_c + Vector3(0.0, -0.1, 0.02), -1)


## Flamethrower trooper: two fuel tanks on the back, hose to a wand held forward with a small pilot flame.
static func _flamer(host: Object, m: Array[Prim]) -> void:
	var r := _rig(m, Vector3(0, 0, 0.385), 0.06, Vector3(0.1, 0.09, 0.065), Vector3(-0.07, -0.09, 0.065), Vector3(1, 0, 0.15), Vector3(1, 0, 0.15), false)
	var tb: Basis = r["tb"]
	var hip: Vector3 = r["hip"]
	var head: Vector3 = r["head"]
	_p(m, Base.BOX, head + Vector3(0.07, 0, -0.03), Vector3(0.022, 0.07, 0.035), "i_visor")  # mask over the face
	_p(m, Base.CYL, head + Vector3(0.1, 0, -0.045), Vector3(0.025, 0, 0.012), "gun")
	for s: float in [1.0, -1.0]:  # fuel tanks
		var c := hip + tb * Vector3(-0.15, 0.058 * s, 0.17)
		_p(m, Base.CYL, c, Vector3(0.055, 0, 0.17), "i_tank", 0.06)
		_p(m, Base.CYL, c + tb * Vector3(0, 0, 0.18), Vector3(0.03, 0, 0.02), "red", 0.06)
		_p(m, Base.CYL, c + tb * Vector3(0, 0, 0.05), Vector3(0.058, 0, 0.012), "steel", 0.06)
		_p(m, Base.CYL, c + tb * Vector3(0, 0, -0.08), Vector3(0.058, 0, 0.012), "steel", 0.06)
	var top := hip + tb * Vector3(-0.15, 0.0, 0.37)
	var wand_a := hip + tb * Vector3(0.1, -0.1, 0.2) + Vector3(0, 0, 0.14)
	var wand_b := wand_a + Vector3(0.5, 0.03, -0.03)
	Base._bone(m, top, hip + tb * Vector3(-0.14, -0.12, 0.2), 0.012, 0.012, "belt")  # hose
	Base._bone(m, hip + tb * Vector3(-0.14, -0.12, 0.2), wand_a + Vector3(-0.1, 0.02, 0.0), 0.012, 0.012, "belt")
	Base._bone(m, wand_a - Vector3(0.1, 0, 0), wand_b, 0.02, 0.02, "gun")  # wand
	Base._bone(m, wand_a + Vector3(0.28, 0, 0), wand_a + Vector3(0.28, 0, -0.1), 0.012, 0.012, "gun")  # foregrip
	Base._bone(m, wand_b, wand_b + Vector3(0.05, 0.0, 0.0), 0.03, 0.03, "steel")  # nozzle
	Base._sp(m, wand_b + Vector3(0.1, 0, 0.02), Vector3(0.055, 0.04, 0.05), "fire")  # pilot flame
	Base._sp(m, wand_b + Vector3(0.09, 0, 0.0), Vector3(0.03, 0.025, 0.03), "flash")
	Base._sp(m, wand_b + Vector3(0.14, 0, 0.05), Vector3(0.02, 0.015, 0.03), "flash")
	_arm(host, m, r["sr"], wand_a + Vector3(0.02, 0.0, -0.02), -1)
	_arm(host, m, r["sl"], wand_a + Vector3(0.28, 0.0, -0.1), 1)


## Heavy gunner: broad armoured torso with plates and shoulder guards, visored helmet, rotary gun on a shoulder strap, ammo box.
static func _heavy(host: Object, m: Array[Prim]) -> void:
	var r := _rig(m, Vector3(0, 0, 0.375), 0.1, Vector3(0.08, 0.12, 0.065), Vector3(-0.05, -0.12, 0.065), Vector3(1, 0, 0.15), Vector3(1, 0, 0.15), false, "helm", 1.2)
	var tb: Basis = r["tb"]
	var hip: Vector3 = r["hip"]
	var head: Vector3 = r["head"]
	_p(m, Base.BOX, hip + tb * Vector3(0.09, 0, 0.16), Vector3(0.025, 0.14, 0.11), "i_plate", 0.1)  # chest and back plates
	_p(m, Base.BOX, hip + tb * Vector3(-0.1, 0, 0.16), Vector3(0.025, 0.14, 0.11), "i_plate", 0.1)
	_p(m, Base.BOX, hip + tb * Vector3(0.1, 0, 0.065), Vector3(0.02, 0.11, 0.03), "i_plate", 0.1)  # groin plate
	for s: float in [1.0, -1.0]:
		Base._sp(m, hip + tb * Vector3(0, 0.18 * s, 0.27), Vector3(0.06, 0.05, 0.04), "i_plate")  # shoulder guards
	_p(m, Base.BOX, head + Vector3(0.082, 0, 0.0), Vector3(0.016, 0.075, 0.025), "i_visor")  # visor
	_p(m, Base.BOX, head + Vector3(0.0, 0, 0.1), Vector3(0.05, 0.016, 0.02), "i_plate")
	# rotary gun held at the hip: motor, six barrels in a ring, shroud
	var g0 := Vector3(0.0, -0.02, 0.5)
	var dir := Vector3(1, 0.04, -0.02).normalized()
	Base._bone(m, g0 - dir * 0.08, g0 + dir * 0.2, 0.05, 0.05, "gun")  # motor housing
	Base._bone(m, g0 + dir * 0.2, g0 + dir * 0.62, 0.012, 0.012, "steel")
	for i in 6:
		var a := TAU * float(i) / 6.0
		var off := Vector3(0, cos(a) * 0.035, sin(a) * 0.035)
		Base._bone(m, g0 + dir * 0.2 + off, g0 + dir * 0.68 + off, 0.012, 0.012, "steel" if i % 2 == 0 else "gun")
	Base._bone(m, g0 + dir * 0.66, g0 + dir * 0.7, 0.05, 0.05, "gun")  # muzzle clamp
	Base._bone(m, g0 + dir * 0.34, g0 + dir * 0.38, 0.05, 0.05, "gun")
	Base._bx(m, g0 + Vector3(0.0, 0.0, 0.07), Vector3(0.06, 0.012, 0.014), "gun")  # carry handle
	Base._bone(m, hip + tb * Vector3(0.0, -0.14, 0.4), g0 + Vector3(-0.02, -0.04, 0.05), 0.014, 0.01, "belt")  # strap
	var box := hip + tb * Vector3(-0.18, 0.0, 0.14)  # ammo box on the back
	_p(m, Base.BOX, box, Vector3(0.07, 0.11, 0.1), "ammo", 0.1)
	_p(m, Base.BOX, box + tb * Vector3(0, 0, 0.105), Vector3(0.07, 0.11, 0.01), "gun", 0.1)
	for i in 6:  # belt feeding from the box round the waist to the gun
		var t := float(i) / 5.0
		Base._bx(m, hip + Vector3(-0.1 + 0.2 * t, 0.2 * (1.0 - t) + 0.0, 0.2 + 0.28 * t), Vector3(0.012, 0.016, 0.016), "brass")
	_arm(host, m, r["sr"], g0 + dir * 0.0 + Vector3(0.0, -0.05, -0.05), -1)
	_arm(host, m, r["sl"], g0 + dir * 0.28 + Vector3(0.0, 0.03, -0.05), 1)


## Scout crouched low, binoculars up to the eyes, rifle slung on the back.
static func _scout(host: Object, m: Array[Prim]) -> void:
	var r := _rig(m, Vector3(0, 0, 0.27), 0.34, Vector3(0.14, 0.1, 0.065), Vector3(-0.02, -0.1, 0.065), Vector3(1, 0, 0.8), Vector3(1, 0, 0.8))
	var tb: Basis = r["tb"]
	var head: Vector3 = r["head"]
	host._rifle(m, Vector3(-0.12, -0.1, 0.3), Vector3(0.45, 0.0, 1.0).normalized())
	_p(m, Base.SPH, head + Vector3(-0.01, 0, 0.08), Vector3(0.06, 0.07, 0.03), "i_ghillie")  # helmet scrim
	var eye := head + Vector3(0.09, 0, 0.0)
	for s: float in [1.0, -1.0]:  # binoculars: two barrels and a bridge
		Base._bone(m, eye + Vector3(0, 0.032 * s, 0.0), eye + Vector3(0.11, 0.032 * s, 0.01), 0.024, 0.024, "gun")
		Base._bx(m, eye + Vector3(0.12, 0.032 * s, 0.01), Vector3(0.006, 0.026, 0.026), "glass")
	Base._bx(m, eye + Vector3(0.05, 0, 0.0), Vector3(0.035, 0.03, 0.016), "gun")
	_arm(host, m, r["sr"], eye + Vector3(0.0, -0.06, -0.01), -1)
	_arm(host, m, r["sl"], eye + Vector3(0.0, 0.06, -0.01), 1)


## Radio operator: large radio on the back with a whip antenna, handset to the ear.
static func _radio(host: Object, m: Array[Prim]) -> void:
	var r := _rig(m, Vector3(0, 0, 0.385), 0.04, Vector3(0.04, 0.09, 0.065), Vector3(-0.03, -0.09, 0.065), Vector3(1, 0, 0.15), Vector3(1, 0, 0.15), false)
	var tb: Basis = r["tb"]
	var hip: Vector3 = r["hip"]
	var head: Vector3 = r["head"]
	var rc := hip + tb * Vector3(-0.16, 0, 0.2)
	_p(m, Base.BOX, rc, Vector3(0.08, 0.115, 0.17), "i_radio", 0.04)
	_p(m, Base.BOX, rc + tb * Vector3(0.0, 0, 0.175), Vector3(0.085, 0.12, 0.01), "gun", 0.04)
	_p(m, Base.BOX, rc + tb * Vector3(0.0, 0.118, 0.04), Vector3(0.06, 0.006, 0.09), "gun", 0.04)  # side panel
	for i in 3:  # dials and a lamp on the visible faces
		_p(m, Base.CYL, rc + tb * Vector3(-0.03 + 0.03 * float(i), 0.125, 0.09), Vector3(0.012, 0, 0.006), "steel", 0.04)
	_p(m, Base.BOX, rc + tb * Vector3(0.03, 0.123, 0.0), Vector3(0.015, 0.004, 0.01), "red", 0.04)
	_p(m, Base.BOX, rc + tb * Vector3(-0.085, 0, 0.0), Vector3(0.006, 0.07, 0.1), "gun", 0.04)
	Base._bone(m, rc + tb * Vector3(0.04, 0.07, 0.17), rc + Vector3(-0.1, 0.09, 0.6), 0.008, 0.008, "steel")  # whip antenna
	Base._bone(m, rc + tb * Vector3(0.04, 0.07, 0.17), rc + tb * Vector3(0.04, 0.07, 0.22), 0.014, 0.014, "gun")
	var ear := head + Vector3(0.0, -0.08, 0.0)
	var hand_r := head + Vector3(0.04, -0.14, -0.04)
	_arm(host, m, r["sr"], hand_r, -1)
	Base._bx(m, hand_r + Vector3(0.0, 0.0, 0.02), Vector3(0.02, 0.02, 0.07), "gun")  # handset
	Base._bone(m, hand_r + Vector3(-0.01, -0.02, -0.05), hip + tb * Vector3(-0.1, -0.1, 0.3), 0.007, 0.007, "belt")  # cord
	_arm(host, m, r["sl"], Vector3(0.06, 0.16, 0.3), 1)
	_p(m, Base.BOX, ear + Vector3(0.0, 0.0, 0.0), Vector3(0.005, 0.005, 0.005), "belt")


## Fallen soldier on his back, arms slack, helmet and rifle on the ground beside him.
static func _fallen(host: Object, m: Array[Prim]) -> void:
	var lean := -1.42
	var hip := Vector3(0.12, 0, 0.075)
	var tb := Basis(Vector3(0, 1, 0), lean)
	var kl := hip + Vector3(0.18, 0.06, 0.12)  # one knee drawn up
	Base._bone(m, hip + Vector3(0, 0.06, 0), kl, 0.047, 0.045, "uni")
	Base._bone(m, kl, Vector3(0.5, 0.1, 0.05), 0.04, 0.04, "uni")
	Base._bone(m, Vector3(0.5, 0.1, 0.05), Vector3(0.58, 0.1, 0.04), 0.045, 0.04, "boot")
	var ank := Vector3(0.48, -0.08, 0.055)
	Base._bone(m, hip + Vector3(0, -0.06, 0), hip + Vector3(0.24, -0.07, 0.03), 0.047, 0.045, "uni")
	Base._bone(m, hip + Vector3(0.24, -0.07, 0.03), ank, 0.04, 0.04, "uni")
	Base._bone(m, ank, ank + Vector3(0.1, 0.0, 0.02), 0.045, 0.04, "boot")
	_torso(m, hip, lean, true)
	var head := hip + tb * Vector3(0.0, 0, 0.35) + Vector3(0, 0.0, 0.01)
	_p(m, Base.CYL, hip + tb * Vector3(0.0, 0, 0.29), Vector3(0.036, 0, 0.03), "skin")
	_head(m, head, "", false)
	_p(m, Base.SPH, head + Vector3(0, 0, -0.01), Vector3(0.082, 0.072, 0.07), "hair")
	_p(m, Base.SPH, head + Vector3(0.0, 0, 0.0), Vector3(0.075, 0.068, 0.078), "skin")
	_p(m, Base.BOX, head + Vector3(0.0, 0, 0.074), Vector3(0.012, 0.03, 0.006), "lip")  # open mouth/nose up
	var sr := hip + tb * Vector3(0, -0.145, 0.25)
	var sl := hip + tb * Vector3(0, 0.145, 0.25)
	_arm(host, m, sr, hip + Vector3(-0.1, -0.05, 0.12), -1)  # hand laid on the chest
	_arm(host, m, sl, hip + Vector3(-0.2, 0.3, 0.04), 1)  # other arm flung out
	Base._sp(m, Vector3(-0.15, -0.26, 0.06), Vector3(0.11, 0.1, 0.07), "helm")  # helmet on the ground
	Base._cy(m, Vector3(-0.15, -0.26, 0.03), 0.12, 0.01, "helm")
	host._rifle(m, Vector3(-0.06, -0.38, 0.03), Vector3(1.0, 0.04, 0.0))  # rifle on the ground


## Kneeling rocketeer: launcher on the right shoulder, spare round slung on the back.
static func _rpg(host: Object, m: Array[Prim]) -> void:
	var r := _kneel_rig(m, 0.14)
	var tb: Basis = r["tb"]
	var hip: Vector3 = r["hip"]
	var b := hip + tb * Vector3(-0.02, -0.098, 0.265)
	var u := (tb * Vector3(1.0, 0.06, 0.1)).normalized()
	var pts: Dictionary = host._launcher(m, b, u)
	Base._bone(m, hip + tb * Vector3(-0.14, 0.06, 0.05), hip + tb * Vector3(-0.1, 0.06, 0.4), 0.032, 0.032, "tube")  # spare round on the back
	Base._bone(m, hip + tb * Vector3(-0.1, 0.06, 0.4), hip + tb * Vector3(-0.09, 0.06, 0.5), 0.05, 0.05, "warhead")
	_arm(host, m, r["sr"], pts["grip"], -1)
	_arm(host, m, r["sl"], pts["fore"], 1)


## Kneeling rifleman aiming, magazine pouches on the vest.
static func _rifleman(host: Object, m: Array[Prim]) -> void:
	var r := _kneel_rig(m, 0.14)
	var tb: Basis = r["tb"]
	var hip: Vector3 = r["hip"]
	var b := hip + tb * Vector3(-0.015, -0.098, 0.265)
	var u := (tb * Vector3(1.0, 0.1, -0.05)).normalized()
	var pts: Dictionary = host._rifle(m, b, u)
	_arm(host, m, r["sr"], pts["grip"], -1)
	_arm(host, m, r["sl"], pts["fore"], 1)
	_p(m, Base.BOX, hip + tb * Vector3(0.062, 0.0, 0.2), Vector3(0.016, 0.04, 0.03), "belt", 0.14)  # extra pouch
	Base._bx(m, hip + tb * Vector3(0.0, 0.12, 0.0), Vector3(0.03, 0.025, 0.045), "belt")  # canteen
