extends RefCounted
## Theme pack: town and countryside buildings (houses, farm, civic, commercial, industrial, ruined and burnt versions).
## Loaded by tools/gen_sprites.gd, see docs/specs/art-pack-2.md and the contract in pack_nature.gd.
## Models are authored at 1 unit = 1 tile (a storey is 0.5, a door 0.32 tall, a window 0.2 tall) and enlarged by the
## spec's `k`. Detail goes on the +x and +y faces (the two the camera sees), each built from a few shared helpers.
## Glow points in the specs are authored-scale model points (the data tool multiplies them by k).

const Base = preload("res://tools/gen_sprites.gd")
const Prim = Base.Prim

const MATS := {
	"t_trim": ["b8b4a6", "e2dfd2", "fbf9f0"],
	"t_cream": ["a89a78", "cdbf98", "ebdfba"],
	"t_peach": ["a8825e", "d0a67e", "ecc6a0"],
	"t_yellow": ["a88a30", "d4b24a", "f0d472"],
	"t_weather": ["8a8470", "aaa38a", "c8c2a8"],
	"t_weatherd": ["5e5a4a", "787360", "938d78"],
	"t_pblue": ["4a6280", "6f8cae", "98b4d2"],
	"t_thatch": ["6a5326", "9a7c3a", "c4a456"],
	"t_tile": ["7a3a20", "a8532e", "cf7444"],
	"t_rustroof": ["5a2a1a", "8a3e26", "b05a3c"],
	"t_barn": ["5a1a14", "8f2a20", "bd4434"],
	"t_dgreen": ["1e4a2a", "2f7040", "46965a"],
	"t_dblue": ["1e3a5c", "2f5a8a", "4a7cb4"],
	"t_dyellow": ["8a6a14", "c8a02a", "f0cc50"],
	"t_flower": ["8a2a50", "d0508a", "f58ab8"],
	"t_curt": ["16303f", "2a5568", "4e8aa4"],
	"t_curtl": ["2a4a5c", "4a7a92", "7ab0c8"],
	"t_ggl": ["6a9a94", "9ccac2", "d0eee8"],
	"t_police": ["1e2c4a", "2e4470", "466296"],
	"t_chrome": ["5c6468", "a6b0b4", "eef4f6"],
	"t_asph": ["22252a", "32363c", "464b52"],
	"t_marble": ["a09c90", "cac6ba", "eeeae0"],
	"t_silo": ["8a8e90", "b6bcbe", "dce2e4"],
	"t_silor": ["5a6064", "7e868a", "a2abb0"],
	"t_stainb": ["20307a", "3a56c8", "7a96f0"],
	"t_stainr": ["7a1a20", "c03040", "f06870"],
	"t_copper": ["2e5a4c", "4a8a72", "7ab89a"],
	"t_wtank": ["6a7078", "96a0aa", "c4ccd4"],
	"t_dark": ["0c0e10", "14181a", "1e2326"],
	"t_plant": ["24501f", "3a7a2e", "5ca048"],
	"t_soil": ["2a1c12", "3e2a1a", "563c26"],
	"t_panel": ["8a8c88", "aeb0aa", "ced0c8"],
	"t_panelw": ["a2a49c", "c6c8c0", "e2e4dc"],
	"t_barnd": ["3e100c", "6a1e18", "8f3328"],
	"t_ash": ["1a1917", "2a2825", "3c3a35"],
}

# Burnt-out versions of this pack's materials (Base.CHAR covers the shared ones).
const CHARM := {
	"t_trim": "charhi", "t_cream": "plasterc", "t_peach": "plasterc", "t_yellow": "plasterc", "t_weather": "plasterc",
	"t_weatherd": "char", "t_pblue": "plasterc", "t_thatch": "char", "t_tile": "basec", "t_rustroof": "rustc",
	"t_barn": "hullc", "t_dgreen": "hullc", "t_dblue": "hullc", "t_dyellow": "hullc", "t_flower": "hullc",
	"t_curt": "gunc", "t_curtl": "gunc", "t_ggl": "gunc", "t_police": "gunc", "t_chrome": "steelc",
	"t_marble": "plasterc", "t_silo": "steelc", "t_silor": "steelc", "t_wtank": "steelc", "t_panel": "charhi",
	"t_panelw": "charhi", "t_plant": "dirtc", "lampglow": "gunc", "glass": "gunc", "whitep": "basec", "red": "hullc",
}


static func specs() -> Array:
	return [
		{"dir": "bld_cottage", "name": "Cottage", "cat": "building", "auto": true, "k": 1.45, "frames": 1, "columns": 1, "ss": 1, "foot": Vector2i(2, 2), "facings": ["se"]},
		{"dir": "bld_bungalow", "name": "Bungalow", "cat": "building", "auto": true, "k": 1.4, "frames": 1, "columns": 1, "ss": 1, "foot": Vector2i(3, 2), "facings": ["se"]},
		{"dir": "bld_townhouse_row", "name": "Townhouse Row", "cat": "building", "auto": true, "k": 1.4, "frames": 1, "columns": 1, "ss": 1, "facings": ["se", "sw"]},
		{"dir": "bld_villa", "name": "Villa", "cat": "building", "auto": true, "k": 1.4, "frames": 1, "columns": 1, "ss": 1, "facings": ["se"]},
		{"dir": "bld_farmhouse", "name": "Farmhouse", "cat": "building", "auto": true, "k": 1.4, "frames": 1, "columns": 1, "ss": 1, "facings": ["se"]},
		{"dir": "bld_barn", "name": "Barn", "cat": "building", "auto": true, "k": 1.2, "frames": 1, "columns": 1, "ss": 1, "foot": Vector2i(3, 2), "facings": ["se", "sw"]},
		{"dir": "bld_barn_burnt", "name": "Burnt Barn", "cat": "building", "auto": true, "k": 1.2, "frames": 1, "columns": 1, "ss": 1, "foot": Vector2i(3, 2), "facings": ["se"], "glow": [Vector3(0.0, 0.0, 0.35), 90.0, Color(1.0, 0.5, 0.15)]},
		{"dir": "bld_silo_complex", "name": "Grain Silos", "cat": "building", "auto": true, "k": 1.4, "frames": 1, "columns": 1, "ss": 1, "facings": ["se"]},
		{"dir": "bld_greenhouse", "name": "Greenhouse", "cat": "building", "auto": true, "k": 1.5, "frames": 1, "columns": 1, "ss": 1, "facings": ["se"]},
		{"dir": "bld_shed", "name": "Shed", "cat": "building", "auto": true, "k": 1.5, "frames": 1, "columns": 1, "ss": 1, "facings": ["se"]},
		{"dir": "bld_church", "name": "Church", "cat": "building", "auto": true, "k": 1.3, "frames": 1, "columns": 1, "ss": 1, "facings": ["se"]},
		{"dir": "bld_church_ruin", "name": "Ruined Church", "cat": "building", "auto": true, "k": 1.3, "frames": 1, "columns": 1, "ss": 1, "facings": ["se"]},
		{"dir": "bld_school", "name": "School", "cat": "building", "auto": true, "k": 1.25, "frames": 1, "columns": 1, "ss": 1, "facings": ["se", "sw"]},
		{"dir": "bld_clinic", "name": "Clinic", "cat": "building", "auto": true, "k": 1.4, "frames": 1, "columns": 1, "ss": 1, "facings": ["se"]},
		{"dir": "bld_hospital", "name": "Hospital", "cat": "building", "auto": true, "k": 1.2, "frames": 1, "columns": 1, "ss": 1, "foot": Vector2i(3, 4), "facings": ["se"]},
		{"dir": "bld_hospital_ruin", "name": "Ruined Hospital", "cat": "building", "auto": true, "k": 1.2, "frames": 1, "columns": 1, "ss": 1, "foot": Vector2i(3, 4), "facings": ["se"]},
		{"dir": "bld_police_station", "name": "Police Station", "cat": "building", "auto": true, "k": 1.3, "frames": 1, "columns": 1, "ss": 1, "facings": ["se"], "glow": [Vector3(1.04, 0.3, 0.98), 46.0, Color(0.55, 0.7, 1.0)]},
		{"dir": "bld_fire_station", "name": "Fire Station", "cat": "building", "auto": true, "k": 1.3, "frames": 1, "columns": 1, "ss": 1, "facings": ["se"]},
		{"dir": "bld_bank", "name": "Bank", "cat": "building", "auto": true, "k": 1.4, "frames": 1, "columns": 1, "ss": 1, "facings": ["se"]},
		{"dir": "bld_train_station", "name": "Train Station", "cat": "building", "auto": true, "k": 1.2, "frames": 1, "columns": 1, "ss": 1, "facings": ["se", "sw"]},
		{"dir": "bld_petrol_station", "name": "Petrol Station", "cat": "building", "auto": true, "k": 1.3, "frames": 1, "columns": 1, "ss": 1, "facings": ["se"], "glow": [Vector3(0.3, 0.0, 0.62), 90.0, Color(1.0, 0.92, 0.65)]},
		{"dir": "bld_diner", "name": "Diner", "cat": "building", "auto": true, "k": 1.4, "frames": 1, "columns": 1, "ss": 1, "foot": Vector2i(4, 2), "facings": ["se"], "glow": [Vector3(0.0, 0.45, 0.4), 80.0, Color(1.0, 0.85, 0.55)]},
		{"dir": "bld_supermarket", "name": "Supermarket", "cat": "building", "auto": true, "k": 1.2, "frames": 1, "columns": 1, "ss": 1, "foot": Vector2i(3, 4), "facings": ["se", "sw"]},
		{"dir": "bld_supermarket_ruin", "name": "Ruined Supermarket", "cat": "building", "auto": true, "k": 1.2, "frames": 1, "columns": 1, "ss": 1, "foot": Vector2i(3, 4), "facings": ["se", "sw"]},
		{"dir": "bld_garage_shop", "name": "Garage Workshop", "cat": "building", "auto": true, "k": 1.4, "frames": 1, "columns": 1, "ss": 1, "foot": Vector2i(3, 2), "facings": ["se"]},
		{"dir": "bld_office_block", "name": "Office Block", "cat": "building", "auto": true, "k": 1.25, "frames": 1, "columns": 1, "ss": 1, "facings": ["se"]},
		{"dir": "bld_office_block_burnt", "name": "Burnt Office Block", "cat": "building", "auto": true, "k": 1.25, "frames": 1, "columns": 1, "ss": 1, "foot": Vector2i(2, 2), "facings": ["se"], "glow": [Vector3(0.1, 0.0, 1.5), 100.0, Color(1.0, 0.5, 0.15)]},
		{"dir": "bld_tower_block", "name": "Tower Block", "cat": "building", "auto": true, "k": 1.2, "frames": 1, "columns": 1, "ss": 1, "facings": ["se"]},
		{"dir": "bld_tower_block_ruin", "name": "Ruined Tower Block", "cat": "building", "auto": true, "k": 1.2, "frames": 1, "columns": 1, "ss": 1, "foot": Vector2i(3, 3), "facings": ["se"]},
		{"dir": "bld_factory", "name": "Factory", "cat": "building", "auto": true, "k": 1.2, "frames": 1, "columns": 1, "ss": 1, "facings": ["se", "sw"]},
		{"dir": "bld_factory_ruin", "name": "Ruined Factory", "cat": "building", "auto": true, "k": 1.2, "frames": 1, "columns": 1, "ss": 1, "facings": ["se", "sw"]},
		{"dir": "bld_water_tower", "name": "Water Tower", "cat": "building", "auto": true, "k": 1.5, "frames": 1, "columns": 1, "ss": 1, "facings": ["se"]},
		{"dir": "bld_motel", "name": "Motel", "cat": "building", "auto": true, "k": 1.25, "frames": 1, "columns": 1, "ss": 1, "foot": Vector2i(4, 2), "facings": ["se", "sw"], "glow": [Vector3(1.65, 0.0, 1.05), 70.0, Color(1.0, 0.8, 0.5)]},
	]


static func build(_host: Object, m: Array[Prim], unit: String, _frame: int) -> bool:
	_mir = unit in MIRROR
	match unit:
		"bld_cottage":
			_cottage(m)
		"bld_bungalow":
			_bungalow(m)
		"bld_townhouse_row":
			_townhouse_row(m)
		"bld_villa":
			_villa(m)
		"bld_farmhouse":
			_farmhouse(m)
		"bld_barn":
			_barn(m, 0)
		"bld_barn_burnt":
			_barn(m, 1)
		"bld_silo_complex":
			_silo_complex(m)
		"bld_greenhouse":
			_greenhouse(m)
		"bld_shed":
			_shed(m)
		"bld_church":
			_church(m, 0)
		"bld_church_ruin":
			_church(m, 1)
		"bld_school":
			_school(m)
		"bld_clinic":
			_clinic(m)
		"bld_hospital":
			_hospital(m, 0)
		"bld_hospital_ruin":
			_hospital(m, 1)
		"bld_police_station":
			_police(m)
		"bld_fire_station":
			_fire_station(m)
		"bld_bank":
			_bank(m)
		"bld_train_station":
			_train_station(m)
		"bld_petrol_station":
			_petrol(m)
		"bld_diner":
			_diner(m)
		"bld_supermarket":
			_supermarket(m, 0)
		"bld_supermarket_ruin":
			_supermarket(m, 1)
		"bld_garage_shop":
			_garage(m)
		"bld_office_block":
			_office(m, 0)
		"bld_office_block_burnt":
			_office(m, 1)
		"bld_tower_block":
			_tower_block(m, 0)
		"bld_tower_block_ruin":
			_tower_block(m, 1)
		"bld_factory":
			_factory(m, 0)
		"bld_factory_ruin":
			_factory(m, 1)
		"bld_water_tower":
			_water_tower(m)
		"bld_motel":
			_motel(m)
		_:
			return false
	return true


# ---- helpers -------------------------------------------------------------------------------------------------------

static func _bx(m: Array[Prim], c: Vector3, h: Vector3, mat: String, yaw: float = 0.0) -> void:
	Base._bx(m, c, h, mat, yaw)


static func _cy(m: Array[Prim], c: Vector3, r: float, hz: float, mat: String) -> void:
	Base._cy(m, c, r, hz, mat)


static func _sp(m: Array[Prim], c: Vector3, r: Vector3, mat: String) -> void:
	Base._sp(m, c, r, mat)


static func _bone(m: Array[Prim], p0: Vector3, p1: Vector3, hy: float, hz: float, mat: String) -> void:
	Base._bone(m, p0, p1, hy, hz, mat)


## True for sets rendered facing SW as well: `_fy` details are mirrored onto the -y face (the one that art sees).
static var _mir: bool = false
const MIRROR: Array[String] = ["bld_townhouse_row", "bld_barn", "bld_school", "bld_train_station", "bld_supermarket", "bld_supermarket_ruin", "bld_factory", "bld_factory_ruin", "bld_motel"]


## Flat detail on the +x face (wall plane x = wx), centre (y, z), half sizes (hw, hh); `lift` stacks layers.
static func _sides() -> Array:
	return [1.0, -1.0] if _mir else [1.0]


static func _fx(m: Array[Prim], wx: float, y: float, z: float, hw: float, hh: float, mat: String, lift: float = 0.0) -> void:
	_bx(m, Vector3(wx + 0.006 + lift, y, z), Vector3(0.006, hw, hh), mat)


## Flat detail on the +y face (wall plane y = wy), centre (x, z).
static func _fy(m: Array[Prim], x: float, wy: float, z: float, hw: float, hh: float, mat: String, lift: float = 0.0) -> void:
	_bx(m, Vector3(x, wy + 0.006 + lift, z), Vector3(hw, 0.006, hh), mat)
	if _mir:  # the SW art shows the -y face instead: mirror the detail (wy > 0, models are y-symmetric)
		_bx(m, Vector3(x, -wy - 0.006 - lift, z), Vector3(hw, 0.006, hh), mat)


## A framed window on the +x face / on the +y face.
static func _wx(m: Array[Prim], wx: float, y: float, z: float, hw: float, hh: float, mat: String = "glass") -> void:
	_fx(m, wx, y, z, hw + 0.014, hh + 0.014, "t_trim")
	_fx(m, wx, y, z, hw, hh, mat, 0.004)


static func _wy(m: Array[Prim], x: float, wy: float, z: float, hw: float, hh: float, mat: String = "glass") -> void:
	_fy(m, x, wy, z, hw + 0.014, hh + 0.014, "t_trim")
	_fy(m, x, wy, z, hw, hh, mat, 0.004)


## `n` windows between y0 and y1 on the +x face, one row per height in `zs`; a share `lit` of them glows warm.
static func _grid_x(m: Array[Prim], wx: float, y0: float, y1: float, n: int, zs: Array, hw: float, hh: float, lit: float = 0.0, seed_i: int = 0, mat: String = "glass") -> void:
	for zi in zs.size():
		var z: float = zs[zi]
		for i in n:
			var y := y0 + (float(i) + 0.5) * (y1 - y0) / float(n)
			var g := "lampglow" if lit > 0.0 and Base._rnd(i + zi * 7, seed_i + 3) < lit else mat
			_wx(m, wx, y, z, hw, hh, g)


static func _grid_y(m: Array[Prim], wy: float, x0: float, x1: float, n: int, zs: Array, hw: float, hh: float, lit: float = 0.0, seed_i: int = 0, mat: String = "glass") -> void:
	for zi in zs.size():
		var z: float = zs[zi]
		for i in n:
			var x := x0 + (float(i) + 0.5) * (x1 - x0) / float(n)
			var g := "lampglow" if lit > 0.0 and Base._rnd(i + zi * 7, seed_i + 5) < lit else mat
			_wy(m, x, wy, z, hw, hh, g)


## A door with a trim frame standing on z0 (+x face / +y face).
static func _door_x(m: Array[Prim], wx: float, y: float, hw: float = 0.1, hh: float = 0.16, mat: String = "woodd", z0: float = 0.0) -> void:
	_fx(m, wx, y, z0 + hh + 0.007, hw + 0.014, hh + 0.007, "t_trim")
	_fx(m, wx, y, z0 + hh, hw, hh, mat, 0.004)
	_fx(m, wx, y + hw * 0.7, z0 + hh * 0.95, 0.012, 0.012, "brass", 0.008)


static func _door_y(m: Array[Prim], x: float, wy: float, hw: float = 0.1, hh: float = 0.16, mat: String = "woodd", z0: float = 0.0) -> void:
	_fy(m, x, wy, z0 + hh + 0.007, hw + 0.014, hh + 0.007, "t_trim")
	_fy(m, x, wy, z0 + hh, hw, hh, mat, 0.004)
	_fy(m, x - hw * 0.7, wy, z0 + hh * 0.95, 0.012, 0.012, "brass", 0.008)


## Concrete footing under a walled box.
static func _plinth(m: Array[Prim], c: Vector3, hx: float, hy: float, h: float = 0.04, mat: String = "concrete") -> void:
	_bx(m, Vector3(c.x, c.y, h), Vector3(hx + 0.03, hy + 0.03, h), mat)


## Gable roof over a box whose top is at z. Ridge runs along y (slopes in x), or along x with `ridge_x`
## (then the gable end faces +x).
static func _gab(m: Array[Prim], c: Vector3, hx: float, hy: float, z: float, rise: float, mat: String, wall: String, ridge_x: bool = false) -> void:
	if not ridge_x:
		Base._gable(m, c, hx, hy, z, rise, mat, wall)
		return
	var t: Array[Prim] = []
	Base._gable(t, Vector3.ZERO, hy, hx, z, rise, mat, wall)
	Base._xform_about(t, Vector3.ZERO, Basis(Vector3(0, 0, 1), PI * 0.5), Vector3(c.x, c.y, 0.0))
	m.append_array(t)


## Hip roof as `n` stacked, shrinking layers (reads as a tiled hip at this size).
static func _hip(m: Array[Prim], c: Vector3, hx: float, hy: float, z: float, rise: float, mat: String, n: int = 5) -> void:
	var ax := hx + 0.07
	var ay := hy + 0.07
	var run := minf(ax, ay)
	for i in n:
		var s := run * (float(i) + 0.5) / float(n)
		var zc := z + rise * (float(i) + 0.5) / float(n)
		_bx(m, Vector3(c.x, c.y, zc), Vector3(ax - s, ay - s, rise / float(n) * 0.5 + 0.004), mat)


## Flat roof slab with a low parapet.
static func _flat(m: Array[Prim], c: Vector3, hx: float, hy: float, z: float, slab: String = "concrete", rim: String = "t_trim", rim_h: float = 0.05) -> void:
	_bx(m, Vector3(c.x, c.y, z + 0.03), Vector3(hx + 0.04, hy + 0.04, 0.03), slab)
	var rz := z + 0.06 + rim_h
	for s in [1.0, -1.0]:
		_bx(m, Vector3(c.x + s * (hx + 0.03), c.y, rz), Vector3(0.016, hy + 0.045, rim_h), rim)
		_bx(m, Vector3(c.x, c.y + s * (hy + 0.03), rz), Vector3(hx + 0.045, 0.016, rim_h), rim)


## Stepped infill under a sloped edge on a wall plane y: heights lerp from h0 (at x0) to h1 (at x1).
static func _wedge_y(m: Array[Prim], x0: float, x1: float, y: float, z0: float, h0: float, h1: float, mat: String, n: int = 6) -> void:
	for i in n:
		var t := (float(i) + 0.5) / float(n)
		var h := lerpf(h0, h1, t)
		_bx(m, Vector3(lerpf(x0, x1, t), y, z0 + h * 0.5), Vector3(absf(x1 - x0) / float(n) * 0.5, 0.02, h * 0.5), mat)


static func _chimney(m: Array[Prim], c: Vector3, h: float, mat: String = "brick", r: float = 0.06) -> void:
	_bx(m, Vector3(c.x, c.y, c.z + h * 0.5), Vector3(r, r, h * 0.5), mat)
	_bx(m, Vector3(c.x, c.y, c.z + h + 0.015), Vector3(r + 0.015, r + 0.015, 0.015), "concrete")


## A row of `n` thin posts along +y at (x, y0..y1) with the given height and top rail, as a railing on the +x side.
static func _rail_x(m: Array[Prim], x: float, y0: float, y1: float, z: float, h: float, n: int, mat: String = "t_trim") -> void:
	_bx(m, Vector3(x, (y0 + y1) * 0.5, z + h), Vector3(0.012, absf(y1 - y0) * 0.5, 0.012), mat)
	for i in n:
		var y := lerpf(y0, y1, float(i) / float(maxi(n - 1, 1)))
		_bx(m, Vector3(x, y, z + h * 0.5), Vector3(0.008, 0.008, h * 0.5), mat)


static func _rail_y(m: Array[Prim], y: float, x0: float, x1: float, z: float, h: float, n: int, mat: String = "t_trim") -> void:
	_bx(m, Vector3((x0 + x1) * 0.5, y, z + h), Vector3(absf(x1 - x0) * 0.5, 0.012, 0.012), mat)
	for i in n:
		var x := lerpf(x0, x1, float(i) / float(maxi(n - 1, 1)))
		_bx(m, Vector3(x, y, z + h * 0.5), Vector3(0.008, 0.008, h * 0.5), mat)


# ---- damage helpers ------------------------------------------------------------------------------------------------

## A jagged broken wall run from p0 to p1 (axis aligned, ground coordinates): segment heights vary between lo and hi.
static func _jag(m: Array[Prim], p0: Vector2, p1: Vector2, lo: float, hi: float, mat: String, seed_i: int, segs: int, th: float = 0.05, z0: float = 0.0) -> void:
	for i in segs:
		var t := (float(i) + 0.5) / float(segs)
		var p := p0.lerp(p1, t)
		var h := lerpf(lo, hi, Base._rnd(i, seed_i))
		var half := (p1 - p0).abs() / float(segs) * 0.5
		var hx := maxf(half.x, th)
		var hy := maxf(half.y, th)
		_bx(m, Vector3(p.x, p.y, z0 + h * 0.5), Vector3(hx, hy, h * 0.5), mat)


## Rubble floor plus scattered chunks inside a rectangle.
static func _rubble(m: Array[Prim], c: Vector2, hx: float, hy: float, n: int, seed_i: int, big: float = 1.0) -> void:
	_bx(m, Vector3(c.x, c.y, 0.03), Vector3(hx, hy, 0.03), "rubble")
	for i in n:
		var rx := c.x + (Base._rnd(i, seed_i) - 0.5) * 2.0 * hx * 0.9
		var ry := c.y + (Base._rnd(i, seed_i + 1) - 0.5) * 2.0 * hy * 0.9
		var h := (0.06 + 0.06 * Base._rnd(i, seed_i + 2)) * big
		_bx(m, Vector3(rx, ry, h), Vector3((0.1 + 0.12 * Base._rnd(i, seed_i + 3)) * big, (0.1 + 0.1 * Base._rnd(i, seed_i + 4)) * big, h), "rubble", Base._rnd(i, seed_i + 5) * 3.0)


static func _rebar(m: Array[Prim], p: Vector3, seed_i: int, length: float = 0.4) -> void:
	var a := Base._rnd(seed_i, 9) * 6.28
	_bone(m, p, p + Vector3(cos(a) * 0.12, sin(a) * 0.12, length), 0.012, 0.012, "rust")


## Swaps every part to its burnt-out material.
static func _burn(m: Array[Prim]) -> void:
	for p in m:
		var mt: String = p.mat
		p.mat = CHARM.get(mt, Base.CHAR.get(mt, mt))


# ---- houses --------------------------------------------------------------------------------------------------------

## Front-gabled cottage: thatch roof, stone chimney, flower boxes.
static func _cottage(m: Array[Prim]) -> void:
	var hx := 0.7
	var hy := 0.55
	var wz := 0.27
	_plinth(m, Vector3.ZERO, hx, hy)
	_bx(m, Vector3(0, 0, wz), Vector3(hx, hy, wz), "t_cream")
	_bx(m, Vector3(0, 0, 0.07), Vector3(hx + 0.012, hy + 0.012, 0.07), "stone")  # stone base course
	_door_x(m, hx, -0.16, 0.09, 0.16, "t_dgreen")
	_wx(m, hx, 0.26, 0.33, 0.075, 0.08)
	_bx(m, Vector3(hx + 0.03, 0.26, 0.2), Vector3(0.03, 0.09, 0.025), "woodd")  # flower box
	_bx(m, Vector3(hx + 0.034, 0.26, 0.232), Vector3(0.026, 0.085, 0.015), "t_flower")
	_grid_y(m, hy, -0.4, 0.4, 3, [0.32], 0.075, 0.08, 0.0)
	_door_y(m, 0.2, hy, 0.085, 0.16, "woodd")
	_gab(m, Vector3.ZERO, hx, hy, wz * 2.0, 0.36, "t_thatch", "t_cream", true)
	_bone(m, Vector3(-hx - 0.06, 0, wz * 2.0 + 0.36), Vector3(hx + 0.06, 0, wz * 2.0 + 0.36), 0.025, 0.025, "woodd")  # ridge cap
	_wx(m, hx, 0.0, wz * 2.0 + 0.12, 0.05, 0.05, "glass")  # gable window
	_chimney(m, Vector3(-0.35, 0.22, wz * 2.0), 0.46, "stone", 0.07)


## Single-storey bungalow: low hip roof of terracotta tiles, front porch on posts.
static func _bungalow(m: Array[Prim]) -> void:
	var hx := 0.85
	var hy := 0.65
	var wz := 0.27
	_plinth(m, Vector3.ZERO, hx, hy)
	_bx(m, Vector3(0, 0, wz), Vector3(hx, hy, wz), "t_cream")
	_bx(m, Vector3(0, 0, wz * 2.0 - 0.025), Vector3(hx + 0.012, hy + 0.012, 0.025), "t_trim")  # fascia band
	_grid_x(m, hx, -0.55, 0.55, 3, [0.31], 0.075, 0.085, 0.0)
	_door_x(m, hx, 0.0, 0.1, 0.17, "t_dblue")
	_grid_y(m, hy, -0.7, 0.7, 4, [0.31], 0.075, 0.085, 0.0)
	_hip(m, Vector3.ZERO, hx, hy, wz * 2.0, 0.2, "t_tile", 10)
	_bx(m, Vector3(hx + 0.13, 0, 0.03), Vector3(0.13, 0.42, 0.03), "concrete")  # porch slab
	_bx(m, Vector3(hx + 0.13, 0, 0.5), Vector3(0.16, 0.46, 0.022), "t_tile")  # porch roof
	for s in [1.0, -1.0]:
		_cy(m, Vector3(hx + 0.24, 0.4 * s, 0.26), 0.022, 0.23, "t_trim")
	_chimney(m, Vector3(-0.35, -0.2, wz * 2.0 + 0.04), 0.3, "brick", 0.06)
	_bx(m, Vector3(hx + 0.16, 0.0, 0.07), Vector3(0.06, 0.1, 0.02), "concrete")  # step


## Three attached narrow houses (brick, cream, blue siding), each with its own door colour, roofs gabled to the front.
static func _townhouse_row(m: Array[Prim]) -> void:
	var hx := 0.55
	var w := 0.3  # half width of each house
	var walls := ["brick", "t_cream", "t_pblue"]
	var doors := ["t_dgreen", "red", "t_dyellow"]
	var roofs := ["slate", "t_tile", "slate"]
	for i in 3:
		var y := (float(i) - 1.0) * w * 2.0
		var wm: String = walls[i]
		_plinth(m, Vector3(0, y, 0), hx, w, 0.04)
		_bx(m, Vector3(0, y, 0.45), Vector3(hx, w, 0.45), wm)
		_bx(m, Vector3(hx + 0.004, y, 0.5), Vector3(0.006, w, 0.012), "t_trim")  # floor band
		_door_x(m, hx, y - 0.1, 0.075, 0.16, doors[i])
		_wx(m, hx, y + 0.12, 0.26, 0.06, 0.09)
		_wx(m, hx, y - 0.1, 0.72, 0.065, 0.09)
		_wx(m, hx, y + 0.12, 0.72, 0.06, 0.09)
		_bx(m, Vector3(hx + 0.06, y - 0.1, 0.34), Vector3(0.06, 0.1, 0.02), "concrete")  # stoop canopy slab
		_gab(m, Vector3(0, y, 0), hx, w, 0.9, 0.26 + 0.04 * float(i % 2), roofs[i], wm, true)
		_chimney(m, Vector3(-0.3, y + 0.06, 0.92), 0.42 + 0.05 * float(i), "brick", 0.05)
		if i < 2:
			_bx(m, Vector3(0, y + w, 0.46), Vector3(hx + 0.02, 0.012, 0.47), "t_trim")  # party wall pilaster
	_grid_y(m, w * 3.0, -0.4, 0.4, 2, [0.28, 0.72], 0.06, 0.09, 0.0)


## Two-storey villa: tiled hip roof, balcony over the entrance, garage wing with a roll door.
static func _villa(m: Array[Prim]) -> void:
	var mc := Vector3(0, -0.3, 0)  # main block centre (the garage wing fills +y so the whole thing is balanced)
	var hx := 0.75
	var hy := 0.6
	_plinth(m, mc, hx, hy)
	_bx(m, Vector3(0, mc.y, 0.5), Vector3(hx, hy, 0.5), "t_peach")
	_bx(m, Vector3(hx + 0.004, mc.y, 0.5), Vector3(0.006, hy, 0.012), "t_trim")
	_bx(m, Vector3(0, mc.y + hy + 0.004, 0.5), Vector3(hx, 0.006, 0.012), "t_trim")
	_door_x(m, hx, mc.y - 0.2, 0.1, 0.17, "t_dblue")
	_wx(m, hx, mc.y + 0.3, 0.26, 0.08, 0.1)
	_wx(m, hx, mc.y + 0.3, 0.74, 0.08, 0.1)
	_bx(m, Vector3(hx + 0.004, mc.y - 0.2, 0.74), Vector3(0.006, 0.09, 0.13), "t_dark")  # balcony door
	_bx(m, Vector3(hx + 0.008, mc.y - 0.2, 0.74), Vector3(0.006, 0.075, 0.115), "glass")
	_bx(m, Vector3(hx + 0.12, mc.y - 0.2, 0.5), Vector3(0.12, 0.22, 0.02), "t_trim")  # balcony slab
	_rail_x(m, hx + 0.24, mc.y - 0.42, mc.y + 0.02, 0.52, 0.12, 6)
	_rail_y(m, mc.y - 0.42, hx, hx + 0.24, 0.52, 0.12, 3)
	_rail_y(m, mc.y + 0.02, hx, hx + 0.24, 0.52, 0.12, 3)
	_cy(m, Vector3(hx + 0.22, mc.y - 0.4, 0.24), 0.02, 0.24, "t_trim")  # balcony posts down to the porch
	_cy(m, Vector3(hx + 0.22, mc.y + 0.0, 0.24), 0.02, 0.24, "t_trim")
	_hip(m, mc, hx, hy, 1.0, 0.3, "t_tile", 12)
	_grid_y(m, mc.y + hy, -0.5, 0.25, 2, [0.74], 0.07, 0.1)
	# garage wing (+y)
	var wc := Vector3(-0.15, 0.6, 0)
	_plinth(m, wc, 0.6, 0.3)
	_bx(m, Vector3(wc.x, wc.y, 0.2), Vector3(0.6, 0.3, 0.2), "t_peach")
	_bx(m, Vector3(wc.x, wc.y, 0.42), Vector3(0.64, 0.34, 0.03), "t_trim")
	_door_x(m, 0.45, 0.58, 0.2, 0.16, "t_trim")
	for i in 3:
		_fx(m, 0.45, 0.58, 0.1 + 0.1 * float(i), 0.185, 0.004, "gun", 0.009)
	_fx(m, 0.45, 0.58, 0.32, 0.17, 0.02, "t_dark", 0.008)
	_grid_y(m, 0.9, -0.55, 0.15, 2, [0.22], 0.08, 0.06)
	_hip(m, wc + Vector3(0, 0, 0.0), 0.6, 0.3, 0.45, 0.1, "t_tile", 5)
	_chimney(m, Vector3(-0.5, mc.y - 0.2, 1.1), 0.22, "brick", 0.06)


## Weathered L-shaped farmhouse: clapboard walls, tin roof, covered porch, field-stone chimney.
static func _farmhouse(m: Array[Prim]) -> void:
	var mc := Vector3(0, -0.3, 0)
	var hx := 0.75
	var hy := 0.5
	var wz := 0.3
	_plinth(m, mc, hx, hy, 0.04, "stone")
	_bx(m, Vector3(0, mc.y, wz), Vector3(hx, hy, wz), "t_weather")
	for i in 5:  # clapboard shadow lines (+x and +y faces)
		_fx(m, hx, mc.y, 0.1 + 0.11 * float(i), hy, 0.006, "t_weatherd")
		_fy(m, 0.0, mc.y + hy, 0.1 + 0.11 * float(i), hx, 0.006, "t_weatherd")
	_door_x(m, hx, mc.y - 0.12, 0.09, 0.17, "t_dgreen")
	_wx(m, hx, mc.y - 0.38, 0.33, 0.07, 0.1)
	_wx(m, hx, mc.y + 0.14, 0.33, 0.07, 0.1)
	for y in [-0.38, 0.14]:  # shutters
		for s in [1.0, -1.0]:
			_fx(m, hx, mc.y + y + s * 0.115, 0.33, 0.026, 0.1, "t_dgreen", 0.003)
	_gab(m, mc, hx, hy, wz * 2.0, 0.3, "t_rustroof", "t_weather", true)
	# wing towards +y
	var wc := Vector3(-0.42, 0.5, 0)
	_plinth(m, wc, 0.33, 0.3, 0.04, "stone")
	_bx(m, Vector3(wc.x, wc.y, 0.24), Vector3(0.33, 0.3, 0.24), "t_weather")
	_grid_y(m, 0.8, -0.62, -0.22, 2, [0.28], 0.06, 0.085)
	_wx(m, -0.09, 0.5, 0.28, 0.07, 0.085)
	_gab(m, Vector3(wc.x, wc.y, 0), 0.33, 0.3, 0.48, 0.24, "t_rustroof", "t_weather", false)
	# porch on the +x face
	_bx(m, Vector3(hx + 0.14, mc.y - 0.1, 0.03), Vector3(0.14, 0.42, 0.03), "woodd")
	_bone(m, Vector3(hx - 0.02, mc.y - 0.1, 0.56), Vector3(hx + 0.32, mc.y - 0.1, 0.47), 0.46, 0.015, "t_rustroof")
	for y in [-0.46, -0.1, 0.26]:
		_cy(m, Vector3(hx + 0.28, mc.y + y, 0.25), 0.02, 0.22, "t_trim")
	_rail_x(m, hx + 0.28, mc.y - 0.5, mc.y + 0.3, 0.06, 0.12, 6, "t_weather")
	_chimney(m, Vector3(-0.1, mc.y + 0.3, 0.55), 0.38, "stone", 0.07)


# ---- farm ----------------------------------------------------------------------------------------------------------

## Gambrel roof (two slopes per side) over a box whose top is at z; ridge along y, or along x with `ridge_x`.
static func _gambrel(m: Array[Prim], c: Vector3, sp: float, hl: float, z: float, r1: float, r2: float, mat: String, wall: String, ridge_x: bool = false) -> void:
	var t: Array[Prim] = []
	var kx := sp * 0.6
	for s in [1.0, -1.0]:
		_bone(t, Vector3(s * (sp + 0.06), 0, z - 0.01), Vector3(s * kx, 0, z + r1), hl + 0.07, 0.02, mat)
		_bone(t, Vector3(s * kx, 0, z + r1), Vector3(0, 0, z + r1 + r2 + 0.02), hl + 0.07, 0.02, mat)
	var n := 9
	for k in n:
		var zz := (float(k) + 0.5) / float(n) * (r1 + r2)
		var w := lerpf(sp, kx, zz / r1) if zz < r1 else lerpf(kx, 0.0, (zz - r1) / r2)
		for s in [1.0, -1.0]:
			_bx(t, Vector3(0, s * (hl - 0.005), z + zz), Vector3(w, 0.02, (r1 + r2) / float(n) * 0.5 + 0.003), wall)
	Base._xform_about(t, Vector3.ZERO, Basis(Vector3(0, 0, 1), PI * 0.5 if ridge_x else 0.0), Vector3(c.x, c.y, 0.0))
	m.append_array(t)


## Big red barn: gambrel roof, white-trimmed double doors with X bracing, hay loft hatch and hoist beam, cupola.
## `burnt` 0 intact, 1 burning frame (walls gone to charred ribs, roof half fallen, fire).
static func _barn(m: Array[Prim], burnt: int) -> void:
	var hx := 1.2
	var hy := 0.85
	var wz := 0.5
	_plinth(m, Vector3.ZERO, hx, hy, 0.04, "stone")
	if burnt == 0:
		_bx(m, Vector3(0, 0, wz), Vector3(hx, hy, wz), "t_barn")
		for i in 12:  # vertical battens on the long side
			_fy(m, -hx + 0.1 + 0.2 * float(i), hy, wz, 0.01, wz - 0.03, "t_barnd")
		for i in 8:
			_fx(m, hx, -hy + 0.1 + 0.21 * float(i), wz, 0.01, wz - 0.03, "t_barnd")
		_fy(m, 0.0, hy, 0.06, hx, 0.03, "t_trim", 0.003)  # white base and eave trim
		_fy(m, 0.0, hy, wz * 2.0 - 0.03, hx, 0.025, "t_trim", 0.003)
		_fx(m, hx, 0.0, 0.06, hy, 0.03, "t_trim", 0.003)
		# big double door with white frame and X braces
		_fx(m, hx, 0.0, 0.3, 0.3, 0.3, "t_trim", 0.004)
		_fx(m, hx, 0.0, 0.3, 0.27, 0.27, "t_barn", 0.008)
		for s in [1.0, -1.0]:
			_bone(m, Vector3(hx + 0.02, 0.27 * s, 0.03), Vector3(hx + 0.02, 0.0, 0.57), 0.012, 0.012, "t_trim")
			_bone(m, Vector3(hx + 0.02, 0.27 * s, 0.57), Vector3(hx + 0.02, 0.0, 0.03), 0.012, 0.012, "t_trim")
		_fx(m, hx, 0.0, 0.3, 0.008, 0.27, "t_dark", 0.012)
		# side sliding door and windows on the long face
		_fy(m, -0.55, hy, 0.27, 0.22, 0.25, "t_trim", 0.004)
		_fy(m, -0.55, hy, 0.27, 0.2, 0.23, "t_barn", 0.008)
		_bone(m, Vector3(-0.73, hy + 0.02, 0.05), Vector3(-0.37, hy + 0.02, 0.49), 0.01, 0.012, "t_trim")
		_bone(m, Vector3(-0.73, hy + 0.02, 0.49), Vector3(-0.37, hy + 0.02, 0.05), 0.01, 0.012, "t_trim")
		for x in [0.0, 0.4, 0.8]:
			_wy(m, x, hy, 0.62, 0.07, 0.07, "t_dark")
		_gambrel(m, Vector3.ZERO, hy, hx, wz * 2.0, 0.26, 0.22, "t_rustroof", "t_barn", true)
		# hay loft hatch in the front gable with hoist beam
		_fx(m, hx, 0.0, 1.14, 0.13, 0.12, "t_trim", 0.004)
		_fx(m, hx, 0.0, 1.14, 0.1, 0.1, "t_dark", 0.008)
		_fx(m, hx, 0.0, 1.07, 0.09, 0.03, "brass", 0.012)
		_bone(m, Vector3(hx - 0.1, 0, 1.3), Vector3(hx + 0.15, 0, 1.3), 0.015, 0.015, "woodd")
		# cupola on the ridge
		_bx(m, Vector3(-0.2, 0, 1.46), Vector3(0.1, 0.1, 0.08), "t_trim")
		_bx(m, Vector3(-0.2, 0.0, 1.56), Vector3(0.13, 0.13, 0.02), "t_silor")
		_bx(m, Vector3(-0.2, 0.0, 1.63), Vector3(0.07, 0.07, 0.05), "t_silor")
		_fx(m, -0.1, 0.0, 1.46, 0.05, 0.04, "t_dark", 0.0)
		# round hay bales and wagon
		for i in 2:
			_cy(m, Vector3(hx + 0.28, -0.7 + 0.33 * float(i), 0.1), 0.1, 0.1, "brass")
		return
	# burning frame: charred posts and ribs, half the roof fallen in, fire
	var cm := "woodc"
	for ix in 7:
		var x := -hx + 2.0 * hx * float(ix) / 6.0
		for s in [1.0, -1.0]:
			var hh := wz * 2.0 * (0.45 + 0.6 * Base._rnd(ix, 11 if s > 0.0 else 12))
			_bx(m, Vector3(x, s * hy, hh * 0.5), Vector3(0.035, 0.035, hh * 0.5), cm)
	for iy in 4:
		var y := -hy + 2.0 * hy * float(iy) / 3.0
		for s in [1.0, -1.0]:
			var hh2 := wz * 2.0 * (0.4 + 0.6 * Base._rnd(iy, 13 if s > 0.0 else 14))
			_bx(m, Vector3(s * hx, y, hh2 * 0.5), Vector3(0.035, 0.035, hh2 * 0.5), cm)
	_jag(m, Vector2(-hx, hy), Vector2(hx, hy), 0.06, 0.3, "t_barnd", 21, 10, 0.02)  # remains of the lower boards
	_jag(m, Vector2(hx, -hy), Vector2(hx, hy), 0.05, 0.35, "t_barnd", 22, 7, 0.02)
	# roof ribs, the left half still standing
	for ix in 5:
		var x2 := -hx + 0.3 + 0.45 * float(ix)
		_bone(m, Vector3(x2, hy, wz * 2.0), Vector3(x2, 0.5 * hy, wz * 2.0 + 0.26), 0.02, 0.025, cm)
		_bone(m, Vector3(x2, 0.5 * hy, wz * 2.0 + 0.26), Vector3(x2, 0.0, wz * 2.0 + 0.46), 0.02, 0.025, cm)
	_bone(m, Vector3(-hx + 0.3, 0, wz * 2.0 + 0.46), Vector3(hx - 0.3, 0, wz * 2.0 + 0.46), 0.025, 0.025, cm)
	_bone(m, Vector3(0.3, hy * 0.9, 0.9), Vector3(0.7, 0.2, 0.15), 0.025, 0.025, cm)  # fallen rafters
	_bone(m, Vector3(-0.1, -hy * 0.8, 0.9), Vector3(0.4, -0.1, 0.12), 0.025, 0.025, cm)
	_rubble(m, Vector2(0, 0), hx * 0.95, hy * 0.9, 12, 61, 1.1)
	_bx(m, Vector3(0.0, 0.0, 0.1), Vector3(0.5, 0.35, 0.08), "t_ash")
	_blob(m, Vector3(0.1, 0.0, 0.3), 0.2, "fire")
	_blob(m, Vector3(-0.5, 0.2, 0.28), 0.16, "fire")
	_blob(m, Vector3(0.7, -0.25, 0.22), 0.12, "fire")
	_blob(m, Vector3(0.0, 0.0, 0.7), 0.2, "smoke")
	_blob(m, Vector3(0.1, 0.05, 1.05), 0.22, "smoke")
	_blob(m, Vector3(0.2, 0.1, 1.4), 0.2, "smoke")


static func _blob(m: Array[Prim], c: Vector3, r: float, mat: String) -> void:
	Base._blob(m, c, r, mat)


## Two tall grain silos (domed, banded, with a ladder) joined to a corrugated feed shed by a conveyor.
static func _silo_complex(m: Array[Prim]) -> void:
	for i in 2:
		var y := -0.34 + 0.68 * float(i)
		var c := Vector3(-0.42, y, 0)
		_cy(m, c + Vector3(0, 0, 0.04), 0.3, 0.04, "concrete")
		_cy(m, c + Vector3(0, 0, 0.85), 0.24, 0.8, "t_silo")
		for k in 7:  # welded bands
			_cy(m, c + Vector3(0, 0, 0.2 + 0.22 * float(k)), 0.246, 0.012, "t_silor")
		_sp(m, c + Vector3(0, 0, 1.64), Vector3(0.24, 0.24, 0.14), "t_silor")
		_cy(m, c + Vector3(0, 0, 1.8), 0.04, 0.03, "steel")
		_bone(m, c + Vector3(0.23, 0.0, 0.06), c + Vector3(0.23, 0.0, 1.62), 0.025, 0.012, "steel")  # ladder
		for k in 8:
			_bx(m, c + Vector3(0.245, 0.0, 0.14 + 0.2 * float(k)), Vector3(0.012, 0.03, 0.01), "steel")
		_bx(m, c + Vector3(0.23, 0.0, 0.1), Vector3(0.025, 0.07, 0.07), "t_silor")  # outlet hatch
	# feed shed
	var sc := Vector3(0.38, 0.0, 0)
	_plinth(m, sc, 0.35, 0.55, 0.03)
	_bx(m, Vector3(sc.x, 0, 0.2), Vector3(0.35, 0.55, 0.2), "corrugated")
	for i in 9:
		_fx(m, sc.x + 0.35, -0.5 + 0.125 * float(i), 0.2, 0.008, 0.18, "steel", 0.0)
	_gab(m, sc, 0.35, 0.55, 0.4, 0.2, "t_rustroof", "corrugated", true)
	_door_x(m, sc.x + 0.35, 0.0, 0.17, 0.16, "t_dyellow")
	_fy(m, sc.x, 0.55, 0.22, 0.06, 0.06, "glass", 0.004)
	# conveyor from the shed roof to the first silo top and pipe across to the second
	_bone(m, Vector3(0.2, 0.18, 0.5), Vector3(-0.3, 0.34, 1.62), 0.025, 0.025, "steel")
	_bone(m, Vector3(-0.42, -0.1, 1.82), Vector3(-0.42, 0.1, 1.82), 0.02, 0.02, "steel")
	_bx(m, Vector3(0.78, 0.35, 0.1), Vector3(0.1, 0.12, 0.1), "brass")  # grain pile
	_sp(m, Vector3(0.78, 0.35, 0.08), Vector3(0.14, 0.14, 0.1), "brass")


## Free-standing greenhouse: white frame, pale glass with open panes through which the plants show.
static func _greenhouse(m: Array[Prim]) -> void:
	var hx := 0.8
	var hy := 0.5
	var pz := 0.06  # plinth height
	_bx(m, Vector3(0, 0, 0.03), Vector3(hx + 0.03, hy + 0.03, 0.03), "concrete")
	_bx(m, Vector3(0, 0, 0.06), Vector3(hx, hy, 0.06), "brick")
	var wh := 0.3  # glass wall height above the plinth
	var top := pz * 2.0 + wh * 2.0
	# +y face panes (long side): every third pane is open
	var n := 7
	for i in n:
		var x := -hx + (float(i) + 0.5) * 2.0 * hx / float(n)
		if i % 3 != 1:
			_bx(m, Vector3(x, hy, pz * 2.0 + wh), Vector3(hx / float(n) - 0.012, 0.008, wh - 0.01), "t_ggl")
	for i in n + 1:
		_bx(m, Vector3(-hx + float(i) * 2.0 * hx / float(n), hy, pz * 2.0 + wh), Vector3(0.012, 0.014, wh), "t_trim")
	_bx(m, Vector3(0, hy, top), Vector3(hx, 0.016, 0.014), "t_trim")
	_bx(m, Vector3(0, hy, pz * 2.0 + 0.01), Vector3(hx, 0.016, 0.012), "t_trim")
	# +x end: door with glass panes
	_bx(m, Vector3(hx, 0, pz * 2.0 + wh), Vector3(0.008, hy - 0.01, wh - 0.01), "t_ggl")
	for i in 5:
		_bx(m, Vector3(hx, -hy + float(i) * 2.0 * hy / 4.0, pz * 2.0 + wh), Vector3(0.012, 0.012, wh), "t_trim")
	_bx(m, Vector3(hx + 0.01, 0, pz * 2.0 + 0.18), Vector3(0.012, 0.15, 0.17), "t_trim")  # door
	_bx(m, Vector3(hx + 0.02, 0, pz * 2.0 + 0.18), Vector3(0.008, 0.125, 0.145), "glass")
	_bx(m, Vector3(hx + 0.026, 0.0, pz * 2.0 + 0.18), Vector3(0.006, 0.008, 0.145), "t_trim")
	# roof: strips along x, a few missing on the near slope; ridge bar
	var rise := 0.3
	var m_n := 6
	for s in [1.0, -1.0]:
		for i in m_n:
			var x2 := -hx + (float(i) + 0.5) * 2.0 * hx / float(m_n)
			if s > 0.0 and i % 3 == 1:
				continue
			_bone(m, Vector3(x2, s * (hy + 0.04), top), Vector3(x2, 0.0, top + rise), hx / float(m_n) - 0.012, 0.008, "t_ggl")
	for i in m_n + 1:
		var x3 := -hx + float(i) * 2.0 * hx / float(m_n)
		for s in [1.0, -1.0]:
			_bone(m, Vector3(x3, s * (hy + 0.04), top), Vector3(x3, 0.0, top + rise), 0.012, 0.012, "t_trim")
	_bx(m, Vector3(0, 0, top + rise + 0.01), Vector3(hx + 0.02, 0.02, 0.02), "t_trim")
	for k in 4:  # gable end glass (stepped triangle) on the +x end
		var f := 1.0 - (float(k) + 0.5) / 4.0
		_bx(m, Vector3(hx - 0.004, 0, top + rise * (float(k) + 0.5) / 4.0), Vector3(0.008, (hy + 0.0) * f, rise / 8.0), "t_ggl")
	# interior: floor, planters, plants (seen through the open panes and the missing roof strips)
	_bx(m, Vector3(0, 0, 0.13), Vector3(hx - 0.02, hy - 0.02, 0.01), "t_soil")
	for row in 2:
		var y := -0.2 + 0.4 * float(row)
		_bx(m, Vector3(0, y, 0.2), Vector3(hx - 0.1, 0.08, 0.05), "woodd")
		for i in 8:
			var x4 := -hx + 0.14 + 0.2 * float(i)
			var ph := 0.12 + 0.2 * Base._rnd(i, 70 + row)
			_bone(m, Vector3(x4, y, 0.24), Vector3(x4, y, 0.24 + ph), 0.01, 0.01, "t_plant")
			_sp(m, Vector3(x4, y, 0.28 + ph), Vector3(0.07, 0.07, 0.07), "t_plant" if i % 2 == 0 else "leaf")
			if i % 3 == 0:
				_sp(m, Vector3(x4 + 0.04, y + 0.03, 0.3 + ph * 0.7), Vector3(0.025, 0.025, 0.025), "red")
	for i in 3:  # terracotta pots by the door
		_cy(m, Vector3(hx + 0.12, -0.38 + 0.38 * float(i), 0.05), 0.045, 0.05, "t_tile")
		_sp(m, Vector3(hx + 0.12, -0.38 + 0.38 * float(i), 0.12), Vector3(0.06, 0.06, 0.05), "t_plant")


## Small timber garden shed with a lean-to tin roof.
static func _shed(m: Array[Prim]) -> void:
	var hx := 0.4
	var hy := 0.32
	var wz := 0.24
	_bx(m, Vector3(0, 0, 0.03), Vector3(hx + 0.03, hy + 0.03, 0.03), "stone")
	_bx(m, Vector3(0, 0, wz + 0.03), Vector3(hx, hy, wz), "wood")
	for i in 9:  # board lines
		_fy(m, -hx + 0.05 + 0.1 * float(i), hy, wz + 0.03, 0.004, wz - 0.02, "woodd")
	for i in 6:
		_fx(m, hx, -hy + 0.055 + 0.11 * float(i), wz + 0.03, 0.004, wz - 0.02, "woodd")
	_wy(m, 0.0, hy, 0.3, 0.09, 0.07, "glass")
	_fx(m, hx, 0.0, 0.25, 0.14, 0.2, "woodd", 0.002)  # door with brace
	_bone(m, Vector3(hx + 0.012, -0.12, 0.08), Vector3(hx + 0.012, 0.12, 0.42), 0.012, 0.012, "wood")
	_fx(m, hx, 0.11, 0.26, 0.012, 0.025, "steel", 0.008)
	_bone(m, Vector3(-hx - 0.04, 0, 0.62), Vector3(hx + 0.08, 0, 0.5), hy + 0.05, 0.014, "t_rustroof")
	_wedge_y(m, -hx, hx, hy, wz * 2.0 + 0.06, 0.1, 0.0, "wood", 5)
	_bx(m, Vector3(hx + 0.12, -0.3, 0.07), Vector3(0.07, 0.07, 0.07), "woodd")  # crate and bucket
	_cy(m, Vector3(hx + 0.12, 0.22, 0.05), 0.04, 0.05, "steel")


# ---- civic ---------------------------------------------------------------------------------------------------------

## A stepped pyramid spire (n layers) from half sizes (ax, ay) down to a point.
static func _spire(m: Array[Prim], c: Vector3, ax: float, ay: float, h: float, mat: String, n: int = 12) -> void:
	for i in n:
		var f := 1.0 - (float(i) + 0.5) / float(n)
		_bx(m, Vector3(c.x, c.y, c.z + h * (float(i) + 0.5) / float(n)), Vector3(ax * f, ay * f, h / float(n) * 0.5 + 0.004), mat)


## A tall stained-glass window on the +y face of a wall.
static func _stained_y(m: Array[Prim], x: float, wy: float, z: float, hw: float, hh: float) -> void:
	_fy(m, x, wy, z, hw + 0.016, hh + 0.016, "t_trim")
	_fy(m, x, wy, z, hw, hh, "t_stainb", 0.004)
	_fy(m, x, wy, z + hh * 0.35, hw * 0.45, hh * 0.28, "t_stainr", 0.008)
	_fy(m, x, wy, z, 0.008, hh, "t_trim", 0.01)
	_fy(m, x, wy, z + hh * 0.2, hw, 0.008, "t_trim", 0.01)


## Church: stone nave with buttresses, stained windows, square bell tower with a slate spire and cross.
## dmg 1: roofless nave, jagged walls, the tower snapped off, spire and cross lying in the rubble.
static func _church(m: Array[Prim], dmg: int) -> void:
	var nc := Vector3(-0.2, 0, 0)  # nave centre
	var nx := 0.75
	var ny := 0.5
	var wz := 0.5
	var tc := Vector3(0.75, 0, 0)  # tower centre
	_plinth(m, nc, nx, ny, 0.04, "stone")
	_plinth(m, tc, 0.22, 0.26, 0.04, "stone")
	if dmg == 0:
		_bx(m, Vector3(nc.x, 0, wz), Vector3(nx, ny, wz), "stonel")
		for i in 5:  # buttresses on the +y side
			var bxp := nc.x - nx + 0.1 + (2.0 * nx - 0.2) * float(i) / 4.0
			_bx(m, Vector3(bxp, ny + 0.03, 0.4), Vector3(0.03, 0.035, 0.4), "stone")
		for i in 4:
			var wxp := nc.x - nx + 0.1 + (2.0 * nx - 0.2) * (float(i) + 0.5) / 4.0
			_stained_y(m, wxp, ny, 0.55, 0.06, 0.2)
		_gab(m, nc, nx, ny, wz * 2.0, 0.36, "slate", "stonel", true)
		_bone(m, Vector3(nc.x - nx - 0.06, 0, wz * 2.0 + 0.37), Vector3(nc.x + nx, 0, wz * 2.0 + 0.37), 0.02, 0.02, "stone")
		# tower
		_bx(m, Vector3(tc.x, 0, 0.8), Vector3(0.2, 0.24, 0.8), "stonel")
		_bx(m, Vector3(tc.x, 0, 1.64), Vector3(0.23, 0.27, 0.04), "stone")  # belfry cornice
		for z in [0.62, 1.1]:
			_fx(m, tc.x + 0.2, 0.0, z, 0.2, 0.012, "stone", 0.0)
		_door_x(m, tc.x + 0.2, 0.0, 0.1, 0.2, "woodd")
		_bx(m, Vector3(tc.x + 0.206, 0.0, 0.44), Vector3(0.006, 0.1, 0.05), "stonel")  # arch head
		_fx(m, tc.x + 0.2, 0.0, 0.9, 0.06, 0.14, "t_stainb", 0.004)  # stained window over the door
		_fx(m, tc.x + 0.2, 0.0, 0.95, 0.025, 0.06, "t_stainr", 0.008)
		for z in [1.38]:  # belfry louvres
			_fx(m, tc.x + 0.2, 0.0, z, 0.08, 0.13, "t_dark", 0.004)
			_fy(m, tc.x, 0.24, z, 0.08, 0.13, "t_dark", 0.004)
		_fx(m, tc.x + 0.2, 0.0, 1.44, 0.13, 0.012, "stone", 0.008)
		_spire(m, Vector3(tc.x, 0, 1.68), 0.24, 0.28, 0.7, "slate", 14)
		_bone(m, Vector3(tc.x, 0, 2.36), Vector3(tc.x, 0, 2.6), 0.012, 0.012, "brass")
		_bone(m, Vector3(tc.x, -0.06, 2.5), Vector3(tc.x, 0.06, 2.5), 0.012, 0.012, "brass")
		_door_y(m, -0.1, ny, 0.07, 0.16, "woodd")  # side door
		return
	# ruin
	_jag(m, Vector2(nc.x - nx, ny), Vector2(nc.x + nx, ny), 0.2, 1.05, "stonel", 31, 9, 0.05)
	_jag(m, Vector2(nc.x - nx, -ny), Vector2(nc.x + nx, -ny), 0.15, 1.0, "stonel", 32, 9, 0.05)
	_jag(m, Vector2(nc.x - nx, -ny), Vector2(nc.x - nx, ny), 0.3, 1.1, "stonel", 33, 6, 0.05)
	for i in 4:  # window arches that survived
		var wxp := nc.x - nx + 0.1 + (2.0 * nx - 0.2) * (float(i) + 0.5) / 4.0
		if i != 1:
			_stained_y(m, wxp, ny, 0.55, 0.06, 0.2)
	# tower stump
	_jag(m, Vector2(tc.x - 0.2, tc.y), Vector2(tc.x + 0.2, tc.y), 0.5, 1.0, "stonel", 34, 4, 0.2)
	_bx(m, Vector3(tc.x, 0.0, 0.3), Vector3(0.2, 0.24, 0.3), "stonel")
	_jag(m, Vector2(tc.x + 0.2, -0.22), Vector2(tc.x + 0.2, 0.22), 0.6, 1.0, "stonel", 35, 4, 0.03)
	_door_x(m, tc.x + 0.2, 0.0, 0.1, 0.2, "woodc")
	_rubble(m, Vector2(nc.x, 0), nx * 0.95, ny * 0.9, 12, 81, 1.1)
	# charred rafters, fallen spire and cross
	_bone(m, Vector3(-0.8, -0.4, 0.9), Vector3(-0.3, 0.1, 0.16), 0.025, 0.025, "woodc")
	_bone(m, Vector3(-0.2, 0.4, 0.95), Vector3(0.1, -0.1, 0.14), 0.025, 0.025, "woodc")
	_bone(m, Vector3(-0.55, 0.4, 0.5), Vector3(-0.1, 0.0, 0.12), 0.025, 0.025, "woodc")
	_bone(m, Vector3(0.9, 0.2, 0.05), Vector3(1.0, 0.6, 0.2), 0.12, 0.1, "slate")  # a spire section on the ground
	_bone(m, Vector3(0.6, 0.45, 0.04), Vector3(0.85, 0.72, 0.1), 0.012, 0.012, "brass")
	_rebar(m, Vector3(tc.x - 0.1, 0.2, 0.9), 3, 0.3)
	_rebar(m, Vector3(nc.x + 0.5, -ny, 0.8), 5, 0.3)
	_blob(m, Vector3(-0.3, 0, 0.3), 0.1, "smoke")


## Long two-storey brick school with a gabled entrance bay, window rows, a roof flagpole.
static func _school(m: Array[Prim]) -> void:
	var hx := 1.5
	var hy := 0.42
	var wz := 0.45
	_plinth(m, Vector3.ZERO, hx, hy, 0.04)
	_bx(m, Vector3(0, 0, wz), Vector3(hx, hy, wz), "brick")
	_bx(m, Vector3(0, 0, 0.1), Vector3(hx + 0.012, hy + 0.012, 0.1), "stonel")
	_fy(m, 0.0, hy, 0.5, hx, 0.02, "t_trim", 0.002)
	_fx(m, hx, 0.0, 0.5, hy, 0.02, "t_trim", 0.002)
	_grid_y(m, hy, -1.4, -0.42, 4, [0.3, 0.7], 0.07, 0.1, 0.0)
	_grid_y(m, hy, 0.42, 1.4, 4, [0.3, 0.7], 0.07, 0.1, 0.0)
	_grid_x(m, hx, -0.25, 0.25, 2, [0.3, 0.7], 0.07, 0.1)
	_flat(m, Vector3.ZERO, hx, hy, wz * 2.0, "concrete", "t_trim", 0.04)
	# entrance bay (both y sides for the SW art)
	for s in _sides():
		var bc := Vector3(0.0, s * (hy + 0.1), 0)
		_bx(m, Vector3(0, bc.y, 0.42), Vector3(0.3, 0.1, 0.42), "t_cream")
		_bx(m, Vector3(0, bc.y, 0.86), Vector3(0.33, 0.12, 0.03), "t_trim")
		_bx(m, Vector3(0, s * (hy + 0.22), 0.03), Vector3(0.26, 0.1, 0.03), "concrete")  # steps
		_bx(m, Vector3(0, s * (hy + 0.3), 0.015), Vector3(0.3, 0.05, 0.015), "concrete")
		for k in 2:
			_bx(m, Vector3(-0.18 + 0.36 * float(k), s * (hy + 0.19), 0.42), Vector3(0.025, 0.025, 0.4), "t_trim")  # entrance pillars
		_bx(m, Vector3(0, s * (hy + 0.19), 0.84), Vector3(0.22, 0.04, 0.03), "t_trim")
	_door_y(m, -0.07, hy + 0.2, 0.07, 0.17, "t_dgreen")
	_door_y(m, 0.07, hy + 0.2, 0.07, 0.17, "t_dgreen")
	_wy(m, 0.0, hy + 0.2, 0.62, 0.2, 0.08)
	# flagpole on the roof, flag towards +x
	_cy(m, Vector3(1.1, 0.0, wz * 2.0 + 0.4), 0.012, 0.36, "steel")
	_bx(m, Vector3(1.1, 0.0, wz * 2.0 + 0.56), Vector3(0.12, 0.006, 0.07), "red")
	_bx(m, Vector3(-0.8, 0.1, wz * 2.0 + 0.12), Vector3(0.1, 0.08, 0.06), "steel")
	_bx(m, Vector3(1.1, 0.0, wz * 2.0 + 0.08), Vector3(0.05, 0.05, 0.04), "concrete")


## Small white clinic with a red cross panel over the entrance, canopy and access ramp.
static func _clinic(m: Array[Prim]) -> void:
	var hx := 0.75
	var hy := 0.55
	var wz := 0.3
	_plinth(m, Vector3.ZERO, hx, hy, 0.04)
	_bx(m, Vector3(0, 0, wz), Vector3(hx, hy, wz), "plasterw")
	_bx(m, Vector3(0, 0, 0.06), Vector3(hx + 0.01, hy + 0.01, 0.06), "concrete")
	_fy(m, 0.0, hy, 0.5, hx, 0.03, "t_dgreen", 0.0)  # green band
	_fx(m, hx, 0.0, 0.5, hy, 0.03, "t_dgreen", 0.0)
	_grid_y(m, hy, -0.6, 0.6, 3, [0.3], 0.1, 0.09)
	_fx(m, hx, 0.3, 0.3, 0.1, 0.09, "t_trim", 0.0)
	_wx(m, hx, 0.3, 0.3, 0.085, 0.075)
	_fx(m, hx, -0.1, 0.17, 0.17, 0.17, "t_trim", 0.0)  # double glass door
	_fx(m, hx, -0.1, 0.17, 0.15, 0.15, "glass", 0.004)
	_fx(m, hx, -0.1, 0.17, 0.008, 0.15, "t_trim", 0.008)
	_bx(m, Vector3(hx + 0.12, -0.1, 0.4), Vector3(0.12, 0.22, 0.015), "t_dgreen")  # canopy
	for s in [1.0, -1.0]:
		_cy(m, Vector3(hx + 0.2, -0.1 + 0.19 * s, 0.2), 0.012, 0.2, "steel")
	_flat(m, Vector3.ZERO, hx, hy, wz * 2.0, "concrete", "t_trim", 0.04)
	# red cross sign board standing on the roof edge
	_bx(m, Vector3(hx - 0.02, -0.1, 0.84), Vector3(0.02, 0.2, 0.2), "t_trim")
	_bx(m, Vector3(hx, -0.1, 0.84), Vector3(0.012, 0.15, 0.04), "red")
	_bx(m, Vector3(hx, -0.1, 0.84), Vector3(0.012, 0.04, 0.15), "red")
	_bx(m, Vector3(hx - 0.02, -0.1, 0.68), Vector3(0.015, 0.03, 0.04), "steel")
	_bone(m, Vector3(hx + 0.05, 0.38, 0.02), Vector3(hx + 0.3, 0.55, 0.02), 0.07, 0.02, "concrete")  # ramp
	_bx(m, Vector3(-0.3, 0.2, wz * 2.0 + 0.16), Vector3(0.12, 0.1, 0.07), "steel")


## Hospital: a tall ward block with a lower entrance wing, a rooftop helipad and a red cross banner.
## dmg 1: the upper storeys of the ward block and the end of the wing have collapsed (slabs, rebar, rubble).
static func _hospital(m: Array[Prim], dmg: int) -> void:
	var wc := Vector3(-0.6, 0, 0)  # ward block (long along y)
	var wx := 0.5
	var wy := 1.4
	var sc := Vector3(0.5, 0, 0)  # entrance wing
	var sx := 0.6
	var sy := 0.5
	_plinth(m, wc, wx, wy, 0.04)
	_plinth(m, sc, sx, sy, 0.04)
	if dmg == 0:
		_bx(m, Vector3(wc.x, 0, 0.75), Vector3(wx, wy, 0.75), "plasterw")
		_bx(m, Vector3(sc.x, 0, 0.5), Vector3(sx, sy, 0.5), "plasterw")
		for z in [0.5, 1.0]:  # floor bands
			_fy(m, wc.x, wy, z, wx, 0.015, "t_trim", 0.0)
		_grid_y(m, wy, wc.x - 0.42, wc.x + 0.42, 4, [0.3, 0.8, 1.3], 0.075, 0.09, 0.0)
		# ward block +x face (the parts the wing does not cover)
		for sgn in [1.0, -1.0]:
			for j in 4:
				var y: float = float(sgn) * (0.62 + 0.2 * float(j))
				for z in [0.3, 0.8, 1.3]:
					_wx(m, wc.x + wx, y, z, 0.065, 0.09)
		_flat(m, wc, wx, wy, 1.5, "concrete", "t_trim", 0.05)
		# wing windows (+y side) and entrance (+x)
		_grid_y(m, sy, sc.x - 0.5, sc.x + 0.5, 4, [0.3, 0.75], 0.075, 0.1)
		_grid_x(m, sc.x + sx, -0.4, 0.4, 3, [0.78], 0.075, 0.1)
		_fx(m, sc.x + sx, 0.0, 0.2, 0.2, 0.2, "t_trim")
		_fx(m, sc.x + sx, 0.0, 0.2, 0.18, 0.18, "glass", 0.004)
		_fx(m, sc.x + sx, 0.0, 0.2, 0.01, 0.18, "t_trim", 0.008)
		_bx(m, Vector3(sc.x + sx + 0.15, 0.0, 0.44), Vector3(0.15, 0.3, 0.02), "t_dgreen")  # canopy
		for s in [1.0, -1.0]:
			_cy(m, Vector3(sc.x + sx + 0.27, 0.27 * s, 0.22), 0.014, 0.22, "steel")
		_flat(m, sc, sx, sy, 1.0, "concrete", "t_trim", 0.05)
		# red cross banner above the entrance
		_fx(m, sc.x + sx, 0.0, 0.73, 0.22, 0.15, "whitep", 0.002)
		_fx(m, sc.x + sx, 0.0, 0.73, 0.1, 0.03, "red", 0.006)
		_fx(m, sc.x + sx, 0.0, 0.73, 0.03, 0.1, "red", 0.006)
		# helipad on the ward block roof
		_bx(m, Vector3(wc.x, -0.6, 1.58), Vector3(0.36, 0.36, 0.015), "padg")
		_bx(m, Vector3(wc.x, -0.6, 1.6), Vector3(0.16, 0.025, 0.006), "whitep")
		_bx(m, Vector3(wc.x, -0.46, 1.6), Vector3(0.025, 0.14, 0.006), "whitep")
		_bx(m, Vector3(wc.x, -0.74, 1.6), Vector3(0.025, 0.14, 0.006), "whitep")
		_bx(m, Vector3(wc.x, -0.6, 1.6), Vector3(0.025, 0.14, 0.006), "whitep")
		for sx2 in [1.0, -1.0]:
			for sy2 in [1.0, -1.0]:
				_bx(m, Vector3(wc.x + 0.34 * sx2, -0.6 + 0.34 * sy2, 1.62), Vector3(0.02, 0.02, 0.02), "lampglow")
		_bx(m, Vector3(wc.x - 0.1, 0.7, 1.68), Vector3(0.14, 0.12, 0.12), "t_panel")  # lift bulkhead
		_cy(m, Vector3(wc.x + 0.1, 1.0, 1.62), 0.06, 0.07, "steel")
		return
	# ruin: slabs and jagged walls; the +y end and the top of the ward block gone
	for k in 3:
		var fz := 0.04 + 0.5 * float(k)
		var ext := wy * (1.0 - 0.25 * float(k))
		_bx(m, Vector3(wc.x, -wy + ext, fz), Vector3(wx, ext, 0.025), "concrete")
	_jag(m, Vector2(wc.x + wx, -wy), Vector2(wc.x + wx, wy), 0.2, 1.4, "plasterw", 41, 12, 0.04)
	_jag(m, Vector2(wc.x - wx, -wy), Vector2(wc.x + wx, -wy), 0.4, 1.5, "plasterw", 42, 5, 0.04)
	_jag(m, Vector2(wc.x - wx, wy * 0.2), Vector2(wc.x + wx, wy * 0.2), 0.3, 1.0, "plasterw", 43, 5, 0.04)
	_jag(m, Vector2(wc.x - wx, -wy), Vector2(wc.x - wx, wy), 0.5, 1.5, "plasterw", 44, 10, 0.04)
	for z in [0.3, 0.8]:  # surviving windows on the +x wall of the ward
		for j in 3:
			_wx(m, wc.x + wx, -1.15 + 0.22 * float(j), z, 0.065, 0.09)
	_jag(m, Vector2(sc.x - sx, sy), Vector2(sc.x + sx, sy), 0.15, 0.85, "plasterw", 45, 6, 0.04)
	_jag(m, Vector2(sc.x + sx, -sy), Vector2(sc.x + sx, sy), 0.15, 0.9, "plasterw", 46, 5, 0.04)
	_jag(m, Vector2(sc.x - sx, -sy), Vector2(sc.x + sx, -sy), 0.2, 0.9, "plasterw", 47, 6, 0.04)
	_bx(m, Vector3(sc.x, 0.0, 0.5), Vector3(sx, sy, 0.025), "concrete")  # wing floor slab, sagging
	_bx(m, Vector3(sc.x + sx + 0.02, 0.1, 0.35), Vector3(0.006, 0.17, 0.1), "whitep")  # banner remnant
	_bx(m, Vector3(sc.x + sx + 0.03, 0.1, 0.35), Vector3(0.006, 0.07, 0.02), "red")
	_bx(m, Vector3(sc.x + sx + 0.03, 0.1, 0.35), Vector3(0.006, 0.02, 0.07), "red")
	_rubble(m, Vector2(sc.x, 0), sx, sy, 8, 91, 1.1)
	_rubble(m, Vector2(wc.x, 0.8), wx, 0.6, 10, 92, 1.2)
	for i in 5:
		_rebar(m, Vector3(wc.x + (Base._rnd(i, 95) - 0.5) * 0.8, -1.2 + 0.55 * float(i), 1.1 + 0.2 * Base._rnd(i, 96)), i, 0.35)
	_blob(m, Vector3(wc.x, 0.9, 0.3), 0.14, "smoke")


## Police station: pale concrete, blue fascia, entrance canopy with a blue lamp, roof flagpole and antenna.
static func _police(m: Array[Prim]) -> void:
	var hx := 1.0
	var hy := 0.65
	var wz := 0.5
	_plinth(m, Vector3.ZERO, hx, hy, 0.04)
	_bx(m, Vector3(0, 0, wz), Vector3(hx, hy, wz), "t_panelw")
	_bx(m, Vector3(0, 0, wz * 2.0 - 0.08), Vector3(hx + 0.015, hy + 0.015, 0.08), "t_police")  # blue fascia
	_fy(m, 0.0, hy, 0.38, hx, 0.025, "t_police", 0.002)
	_fx(m, hx, 0.0, 0.38, hy, 0.025, "t_police", 0.002)
	_grid_y(m, hy, -0.85, 0.85, 4, [0.24, 0.68], 0.08, 0.09)
	_grid_x(m, hx, -0.5, 0.5, 2, [0.68], 0.08, 0.09)
	_wx(m, hx, -0.45, 0.24, 0.08, 0.09)
	_fx(m, hx, 0.15, 0.17, 0.17, 0.17, "t_trim")
	_fx(m, hx, 0.15, 0.17, 0.15, 0.15, "glass", 0.004)
	_fx(m, hx, 0.15, 0.17, 0.008, 0.15, "t_trim", 0.008)
	_bx(m, Vector3(hx + 0.13, 0.15, 0.4), Vector3(0.13, 0.26, 0.02), "t_police")  # canopy
	for s in [1.0, -1.0]:
		_cy(m, Vector3(hx + 0.24, 0.15 + 0.23 * s, 0.2), 0.012, 0.2, "steel")
	# blue lamp and sign board on the facade
	_bx(m, Vector3(hx + 0.03, 0.3, 0.9), Vector3(0.03, 0.04, 0.05), "t_dblue")
	_bx(m, Vector3(hx + 0.05, 0.3, 0.9), Vector3(0.018, 0.028, 0.035), "t_curtl")
	_fx(m, hx, -0.15, 0.82, 0.3, 0.07, "t_trim", 0.002)
	_fx(m, hx, -0.15, 0.82, 0.27, 0.025, "t_police", 0.006)
	_flat(m, Vector3.ZERO, hx, hy, wz * 2.0, "concrete", "t_police", 0.04)
	_cy(m, Vector3(-0.6, 0.0, 1.35), 0.012, 0.34, "steel")  # flagpole
	_bx(m, Vector3(-0.6, 0.12, 1.58), Vector3(0.006, 0.12, 0.07), "t_dblue")
	_bone(m, Vector3(0.4, -0.3, 1.04), Vector3(0.4, -0.3, 1.5), 0.01, 0.01, "steel")  # antenna
	_bx(m, Vector3(-0.1, 0.3, 1.12), Vector3(0.12, 0.1, 0.06), "steel")


## Fire station: brick, two red roll-up bay doors, a white sign band, a tall hose tower at the back corner.
static func _fire_station(m: Array[Prim]) -> void:
	var hx := 0.85
	var hy := 0.75
	var wz := 0.42
	_plinth(m, Vector3.ZERO, hx, hy, 0.04)
	_bx(m, Vector3(0, 0, wz), Vector3(hx, hy, wz), "brick")
	_flat(m, Vector3.ZERO, hx, hy, wz * 2.0, "concrete", "t_trim", 0.04)
	# bay doors (+x face)
	for k in 2:
		var y := -0.38 + 0.76 * float(k)
		_fx(m, hx, y, 0.3, 0.3, 0.3, "t_trim")
		_fx(m, hx, y, 0.3, 0.27, 0.27, "red", 0.004)
		for i in 6:
			_fx(m, hx, y, 0.06 + 0.095 * float(i), 0.27, 0.005, "t_barnd", 0.008)
		_fx(m, hx, y, 0.52, 0.2, 0.04, "glass", 0.006)
	_fx(m, hx, 0.0, 0.68, 0.5, 0.06, "t_trim", 0.002)  # sign band with a red stripe
	_fx(m, hx, 0.0, 0.68, 0.46, 0.02, "red", 0.006)
	_grid_y(m, hy, -0.55, 0.55, 3, [0.28, 0.62], 0.08, 0.09)
	# hose tower at the back (-x, +y) corner
	var tc := Vector3(-0.5, 0.55, 0)
	_bx(m, Vector3(tc.x, tc.y, 1.05), Vector3(0.16, 0.16, 0.75), "brick")
	_bx(m, Vector3(tc.x, tc.y, 1.82), Vector3(0.19, 0.19, 0.03), "t_trim")
	for z in [1.0, 1.35, 1.65]:
		_fy(m, tc.x, tc.y + 0.16, z, 0.05, 0.08, "t_dark", 0.0)
		_fx(m, tc.x + 0.16, tc.y, z, 0.05, 0.08, "t_dark", 0.0)
	_hip(m, tc, 0.16, 0.16, 1.85, 0.2, "slate", 6)
	_bx(m, Vector3(0.1, -0.2, wz * 2.0 + 0.12), Vector3(0.12, 0.1, 0.07), "steel")


## Bank: stone block with a columned portico, pediment, steps, bronze doors and a lettered frieze.
static func _bank(m: Array[Prim]) -> void:
	var hx := 0.8
	var hy := 0.6
	var wz := 0.4
	_plinth(m, Vector3.ZERO, hx, hy, 0.05, "stone")
	_bx(m, Vector3(0, 0, wz), Vector3(hx, hy, wz), "t_marble")
	_bx(m, Vector3(0, 0, wz * 2.0 + 0.02), Vector3(hx + 0.04, hy + 0.04, 0.03), "concretel")
	_grid_y(m, hy, -0.55, 0.55, 3, [0.4], 0.07, 0.15, 0.0)
	_grid_x(m, hx, -0.55, -0.35, 1, [0.4], 0.06, 0.15)
	_grid_x(m, hx, 0.35, 0.55, 1, [0.4], 0.06, 0.15)
	# portico
	var px := hx + 0.28
	_bx(m, Vector3(hx + 0.14, 0, 0.04), Vector3(0.2, 0.52, 0.04), "stone")  # porch floor
	for k in 3:  # steps
		_bx(m, Vector3(px + 0.1 + 0.06 * float(k), 0, 0.02 + 0.015 * float(2 - k)), Vector3(0.06, 0.4, 0.02 + 0.015 * float(2 - k)), "t_marble")
	for i in 4:
		_cy(m, Vector3(px, -0.42 + 0.28 * float(i), 0.34), 0.045, 0.3, "t_trim")
		_cy(m, Vector3(px, -0.42 + 0.28 * float(i), 0.05), 0.06, 0.012, "t_marble")
		_cy(m, Vector3(px, -0.42 + 0.28 * float(i), 0.66), 0.058, 0.012, "t_marble")
	_bx(m, Vector3(hx + 0.14, 0, 0.7), Vector3(0.2, 0.5, 0.04), "t_trim")  # entablature
	for i in 5:  # gold lettering blocks
		_bx(m, Vector3(px + 0.21, -0.2 + 0.1 * float(i), 0.7), Vector3(0.008, 0.025, 0.025), "brass")
	_gab(m, Vector3(hx + 0.14, 0, 0), 0.2, 0.5, 0.74, 0.17, "t_marble", "t_marble", true)
	_door_x(m, hx, 0.0, 0.14, 0.24, "brass")
	_fx(m, hx, 0.0, 0.24, 0.006, 0.24, "t_dark", 0.01)
	_bx(m, Vector3(-0.3, 0.1, wz * 2.0 + 0.1), Vector3(0.14, 0.12, 0.06), "steel")
	_cy(m, Vector3(0.1, -0.2, wz * 2.0 + 0.12), 0.06, 0.08, "steel")


## Railway station: long brick hall with a clock tower, platform canopies on posts along the track sides.
static func _train_station(m: Array[Prim]) -> void:
	var hx := 1.5
	var hy := 0.45
	var wz := 0.55
	_plinth(m, Vector3.ZERO, hx, hy, 0.04)
	_bx(m, Vector3(0, 0, wz), Vector3(hx, hy, wz), "brick")
	_bx(m, Vector3(0, 0, 0.08), Vector3(hx + 0.012, hy + 0.012, 0.08), "stonel")
	_fy(m, 0.0, hy, 0.62, hx, 0.025, "t_trim", 0.002)
	_grid_y(m, hy, -1.35, -0.3, 4, [0.5], 0.07, 0.18, 0.0)
	_grid_y(m, hy, 0.3, 1.35, 4, [0.5], 0.07, 0.18, 0.0)
	_grid_x(m, hx, -0.2, 0.2, 2, [0.5], 0.07, 0.18)
	_hip(m, Vector3.ZERO, hx, hy, wz * 2.0, 0.22, "slate", 8)
	# platforms and canopies (both track sides, so either facing shows one)
	for s in [1.0, -1.0]:
		_bx(m, Vector3(0, s * (hy + 0.24), 0.04), Vector3(hx + 0.1, 0.24, 0.04), "concrete")
		_bx(m, Vector3(0, s * (hy + 0.46), 0.045), Vector3(hx + 0.1, 0.012, 0.012), "t_yellow")
		_bone(m, Vector3(0, s * (hy - 0.02), 1.0), Vector3(0, s * (hy + 0.3), 0.92), hx + 0.1, 0.018, "t_police")
		for i in 7:
			var x := -hx + 0.1 + (2.0 * hx - 0.2) * float(i) / 6.0
			_cy(m, Vector3(x, s * (hy + 0.28), 0.46), 0.014, 0.42, "steel")
		_bx(m, Vector3(0.9, s * (hy + 0.2), 0.12), Vector3(0.12, 0.04, 0.04), "woodd")  # bench
	# clock tower in the middle of the hall
	_bx(m, Vector3(0.0, 0, 1.25), Vector3(0.18, 0.2, 0.65), "brick")
	_bx(m, Vector3(0.0, 0, 1.92), Vector3(0.21, 0.23, 0.03), "t_trim")
	for s in _sides():
		_fy(m, 0.0, 0.2, 1.55, 0.1, 0.1, "t_trim", 0.0)  # clock faces
		_fy(m, 0.0, 0.2, 1.55, 0.085, 0.085, "whitep", 0.004)
		_fy(m, 0.0, 0.2, 1.58, 0.008, 0.045, "t_dark", 0.008)
		_fy(m, 0.02, 0.2, 1.55, 0.04, 0.008, "t_dark", 0.008)
	_fx(m, 0.18, 0.0, 1.55, 0.1, 0.1, "t_trim", 0.0)
	_fx(m, 0.18, 0.0, 1.55, 0.085, 0.085, "whitep", 0.004)
	_fx(m, 0.18, 0.0, 1.58, 0.045, 0.008, "t_dark", 0.008)
	_fx(m, 0.18, 0.02, 1.55, 0.008, 0.04, "t_dark", 0.008)
	_hip(m, Vector3(0, 0, 0), 0.18, 0.2, 1.95, 0.28, "t_copper", 8)
	_bone(m, Vector3(0, 0, 2.22), Vector3(0, 0, 2.4), 0.01, 0.01, "steel")
	_door_x(m, hx, 0.0, 0.12, 0.2, "woodd")
	_door_y(m, -1.0, hy, 0.1, 0.18, "woodd")
	_bx(m, Vector3(hx + 0.1, 0.0, 0.46), Vector3(0.1, 0.18, 0.015), "t_police")  # entrance canopy


# ---- commercial ----------------------------------------------------------------------------------------------------

## A roof air-conditioning unit: box with a fan drum.
static func _ac(m: Array[Prim], c: Vector3, s: float = 1.0) -> void:
	_bx(m, c + Vector3(0, 0, 0.05 * s), Vector3(0.12 * s, 0.09 * s, 0.05 * s), "steel")
	_cy(m, c + Vector3(0, 0, 0.115 * s), 0.055 * s, 0.015 * s, "t_dark")


## Petrol station: red-and-white forecourt canopy on four posts with a lit fascia, two pump islands, a small shop, price pylon.
static func _petrol(m: Array[Prim]) -> void:
	var cc := Vector3(0.3, 0, 0)  # canopy centre
	var ch := 0.62  # canopy underside
	# forecourt
	_bx(m, Vector3(0.2, 0, 0.012), Vector3(1.0, 0.85, 0.012), "t_asph")
	# shop
	var sc := Vector3(-0.85, 0, 0)
	_bx(m, Vector3(sc.x, 0, 0.21), Vector3(0.35, 0.55, 0.2), "whitep")
	_bx(m, Vector3(sc.x, 0, 0.44), Vector3(0.38, 0.58, 0.03), "red")
	_fx(m, sc.x + 0.35, 0.0, 0.2, 0.46, 0.14, "glass", 0.0)  # shop front glass
	_fx(m, sc.x + 0.35, 0.0, 0.2, 0.008, 0.14, "t_trim", 0.006)
	_fx(m, sc.x + 0.35, 0.3, 0.2, 0.008, 0.14, "t_trim", 0.006)
	_fx(m, sc.x + 0.35, -0.3, 0.2, 0.008, 0.14, "t_trim", 0.006)
	_fy(m, sc.x, 0.55, 0.22, 0.2, 0.09, "glass", 0.0)
	_fx(m, sc.x + 0.35, 0.0, 0.38, 0.4, 0.03, "red", 0.004)
	_bx(m, Vector3(sc.x, 0.2, 0.52), Vector3(0.1, 0.08, 0.06), "steel")
	# canopy
	for sx in [1.0, -1.0]:
		for sy in [1.0, -1.0]:
			_cy(m, Vector3(cc.x + 0.5 * sx, 0.55 * sy, ch * 0.5), 0.028, ch * 0.5, "whitep")
	_bx(m, Vector3(cc.x, 0, ch + 0.03), Vector3(0.58, 0.64, 0.03), "whitep")
	_bx(m, Vector3(cc.x, 0, ch + 0.09), Vector3(0.6, 0.66, 0.025), "red")  # roof cap
	_fx(m, cc.x + 0.58, 0.0, ch + 0.035, 0.64, 0.04, "red", 0.002)  # fascia
	_fx(m, cc.x + 0.58, 0.0, ch + 0.035, 0.6, 0.014, "lampglow", 0.006)
	_fy(m, cc.x, 0.64, ch + 0.035, 0.58, 0.04, "red", 0.002)
	_fy(m, cc.x, 0.64, ch + 0.035, 0.54, 0.014, "lampglow", 0.006)
	# pump islands
	for i in 2:
		var y := -0.25 + 0.5 * float(i)
		_bx(m, Vector3(cc.x, y, 0.035), Vector3(0.34, 0.07, 0.025), "concrete")
		for j in 2:
			var x := cc.x - 0.16 + 0.32 * float(j)
			_bx(m, Vector3(x, y, 0.2), Vector3(0.045, 0.04, 0.14), "red")
			_bx(m, Vector3(x, y, 0.36), Vector3(0.05, 0.045, 0.02), "whitep")
			_bx(m, Vector3(x + 0.046, y, 0.27), Vector3(0.006, 0.026, 0.035), "lampglow")
			_bone(m, Vector3(x, y + 0.04, 0.2), Vector3(x, y + 0.07, 0.07), 0.006, 0.006, "gun")
	# price pylon
	_cy(m, Vector3(1.15, 0.72, 0.5), 0.022, 0.5, "steel")
	_bx(m, Vector3(1.15, 0.72, 1.05), Vector3(0.05, 0.18, 0.18), "whitep")
	_fx(m, 1.2, 0.72, 1.1, 0.15, 0.04, "red", 0.0)
	_fx(m, 1.2, 0.72, 0.98, 0.14, 0.03, "lampglow", 0.004)
	_fx(m, 1.2, 0.72, 0.9, 0.14, 0.025, "lampglow", 0.004)
	_bx(m, Vector3(-0.1, -0.78, 0.07), Vector3(0.1, 0.04, 0.07), "drum")  # oil drums by the shop
	_cy(m, Vector3(-0.5, 0.75, 0.1), 0.06, 0.1, "drum")


## Chrome-and-red diner with rounded ends, a window ribbon, striped awning and a tall lit roadside sign.
static func _diner(m: Array[Prim]) -> void:
	var r := 0.45
	var hx := 0.62  # straight part half length
	_bx(m, Vector3(0, 0, 0.025), Vector3(hx + r + 0.04, r + 0.04, 0.025), "concrete")
	for s in [1.0, -1.0]:
		var ex: float = float(s) * hx
		_cy(m, Vector3(ex, 0, 0.15), r, 0.12, "red")
		_cy(m, Vector3(ex, 0, 0.29), r + 0.008, 0.02, "t_chrome")
		_cy(m, Vector3(ex, 0, 0.42), r + 0.004, 0.11, "glass")
		_cy(m, Vector3(ex, 0, 0.56), r + 0.01, 0.03, "whitep")
		_cy(m, Vector3(ex, 0, 0.6), r + 0.03, 0.012, "red")
	_bx(m, Vector3(0, 0, 0.15), Vector3(hx, r, 0.12), "red")
	_bx(m, Vector3(0, 0, 0.29), Vector3(hx, r + 0.008, 0.02), "t_chrome")
	_bx(m, Vector3(0, 0, 0.56), Vector3(hx, r + 0.01, 0.03), "whitep")
	_bx(m, Vector3(0, 0, 0.6), Vector3(hx, r + 0.03, 0.012), "red")
	# window ribbon on the +y face with mullions
	_fy(m, 0.0, r, 0.42, hx, 0.11, "glass", 0.0)
	for i in 8:
		_fy(m, -hx + 0.08 + (2.0 * hx - 0.16) * float(i) / 7.0, r, 0.42, 0.012, 0.11, "t_chrome", 0.006)
	for i in 6:  # red/white awning strips above the windows
		_bx(m, Vector3(-hx + 0.1 + (2.0 * hx - 0.2) * float(i) / 5.0, r + 0.05, 0.54), Vector3((hx - 0.1) / 5.0, 0.06, 0.012), "red" if i % 2 == 0 else "whitep", 0.0)
	# flat roof with a rounded edge
	_cy(m, Vector3(hx, 0, 0.64), r, 0.012, "t_chrome")
	_cy(m, Vector3(-hx, 0, 0.64), r, 0.012, "t_chrome")
	_bx(m, Vector3(0, 0, 0.64), Vector3(hx, r, 0.012), "t_chrome")
	# front vestibule at the +x end
	_bx(m, Vector3(hx + r + 0.04, 0.0, 0.25), Vector3(0.1, 0.16, 0.25), "t_chrome")
	_fx(m, hx + r + 0.14, 0.0, 0.2, 0.12, 0.18, "glass", 0.0)
	_fx(m, hx + r + 0.14, 0.0, 0.2, 0.008, 0.18, "t_chrome", 0.006)
	_bx(m, Vector3(hx + r + 0.04, 0.0, 0.52), Vector3(0.12, 0.18, 0.015), "red")
	# roof sign pole with lit board
	_cy(m, Vector3(-0.3, 0.1, 0.9), 0.014, 0.3, "steel")
	_bx(m, Vector3(-0.3, 0.1, 1.28), Vector3(0.025, 0.3, 0.1), "red")
	_fx(m, -0.275, 0.1, 1.28, 0.27, 0.07, "lampglow", 0.0)
	_fx(m, -0.275, 0.1, 1.28, 0.2, 0.02, "red", 0.006)
	# a parked-sign and bench by the door
	_bx(m, Vector3(hx + r + 0.3, -0.35, 0.1), Vector3(0.1, 0.04, 0.03), "woodd")
	_bx(m, Vector3(hx + r + 0.3, -0.35, 0.17), Vector3(0.1, 0.01, 0.06), "woodd")


## Supermarket: a wide flat box with a glazed entrance bay, sign band, tall pylon sign, trolley bay and roof plant.
## dmg 1: half the roof fallen, front wall broken, shelving exposed, rubble.
static func _supermarket(m: Array[Prim], dmg: int) -> void:
	var hx := 1.1  # depth (front wall is the +x face)
	var hy := 1.7
	var wz := 0.45
	_plinth(m, Vector3.ZERO, hx, hy, 0.04)
	if dmg == 0:
		_bx(m, Vector3(0, 0, wz), Vector3(hx, hy, wz), "t_panelw")
		_fx(m, hx, 0.0, 0.78, hy, 0.06, "t_dgreen", 0.0)  # sign band
		_fx(m, hx, 0.0, 0.1, hy, 0.1, "t_panel", 0.0)  # plinth band
		for i in 6:
			if i != 2 and i != 3:
				_fx(m, hx, -1.3 + 0.52 * float(i), 0.5, 0.17, 0.12, "t_curtl", 0.0)
		# entrance bay
		_bx(m, Vector3(hx + 0.1, 0.0, 0.3), Vector3(0.1, 0.4, 0.3), "t_curtl")
		_bx(m, Vector3(hx + 0.14, 0.0, 0.62), Vector3(0.16, 0.44, 0.025), "t_dgreen")  # entrance canopy
		_fx(m, hx + 0.2, 0.0, 0.28, 0.34, 0.26, "glass", 0.0)
		for k in 5:
			_fx(m, hx + 0.2, -0.34 + 0.17 * float(k), 0.28, 0.01, 0.26, "t_trim", 0.006)
		_fx(m, hx + 0.2, 0.0, 0.5, 0.34, 0.01, "t_trim", 0.006)
		# tall pylon sign (lit)
		_bx(m, Vector3(1.45, 1.3, 0.85), Vector3(0.04, 0.04, 0.85), "steel")
		_bx(m, Vector3(1.45, 1.3, 1.5), Vector3(0.05, 0.25, 0.16), "t_dgreen")
		_fx(m, 1.5, 1.3, 1.5, 0.22, 0.06, "lampglow", 0.0)
		_fx(m, 1.5, 1.3, 1.5, 0.17, 0.02, "t_dgreen", 0.006)
		# trolley bay by the entrance
		_bx(m, Vector3(hx + 0.4, -0.7, 0.025), Vector3(0.25, 0.14, 0.012), "concrete")
		_bx(m, Vector3(hx + 0.4, -0.7, 0.32), Vector3(0.22, 0.012, 0.012), "t_dgreen")
		for k in 4:
			_bx(m, Vector3(hx + 0.2 + 0.1 * float(k), -0.7, 0.12), Vector3(0.05, 0.07, 0.07), "t_chrome")
			_bx(m, Vector3(hx + 0.2 + 0.1 * float(k), -0.7, 0.19), Vector3(0.05, 0.07, 0.008), "t_dgreen")
		# end wall (+y): loading dock door and windows
		_fy(m, 0.4, hy, 0.25, 0.3, 0.24, "t_trim")
		_fy(m, 0.4, hy, 0.25, 0.27, 0.21, "steel", 0.004)
		for i in 5:
			_fy(m, 0.4, hy, 0.1 + 0.08 * float(i), 0.27, 0.004, "gun", 0.009)
		_grid_y(m, hy, -0.8, -0.1, 3, [0.6], 0.09, 0.07)
		_flat(m, Vector3.ZERO, hx, hy, wz * 2.0, "concrete", "t_trim", 0.05)
		_ac(m, Vector3(-0.4, -1.1, wz * 2.0 + 0.06), 1.2)
		_ac(m, Vector3(-0.4, -0.4, wz * 2.0 + 0.06), 1.2)
		_ac(m, Vector3(-0.4, 0.3, wz * 2.0 + 0.06), 1.2)
		_bx(m, Vector3(0.2, 1.0, wz * 2.0 + 0.14), Vector3(0.18, 0.2, 0.1), "t_panel")
		_cy(m, Vector3(-0.1, 1.2, wz * 2.0 + 0.2), 0.05, 0.14, "steel")
		return
	# ruin
	_bx(m, Vector3(0, 0, 0.05), Vector3(hx, hy, 0.02), "concrete")  # floor slab
	_jag(m, Vector2(hx, -hy), Vector2(hx, hy), 0.12, 0.8, "t_panelw", 51, 14, 0.05)
	_jag(m, Vector2(-hx, -hy), Vector2(-hx, hy), 0.3, 0.85, "t_panelw", 52, 14, 0.05)
	_jag(m, Vector2(-hx, -hy), Vector2(hx, -hy), 0.3, 0.85, "t_panelw", 53, 8, 0.05)
	_jag(m, Vector2(-hx, hy), Vector2(hx, hy), 0.15, 0.7, "t_panelw", 54, 8, 0.05)
	for i in 3:  # shelving that survived
		_bx(m, Vector3(-0.5 + 0.35 * float(i), -0.6, 0.16), Vector3(0.05, 0.8, 0.14), "t_panel")
	for i in 3:
		_bx(m, Vector3(-0.5 + 0.35 * float(i), 0.9, 0.12), Vector3(0.05, 0.5, 0.1), "t_panel", 0.0)
	# roof: half fallen, sagging sheet resting on a few columns
	for k in 3:
		_bx(m, Vector3(-0.8, -1.2 + 0.5 * float(k), 0.4), Vector3(0.05, 0.05, 0.4), "concrete")
	_bone(m, Vector3(-1.1, -1.5, 0.84), Vector3(0.1, -0.5, 0.3), 0.5, 0.025, "concretel")  # roof slab hanging down
	_bone(m, Vector3(-1.1, -0.3, 0.8), Vector3(-0.2, 0.2, 0.55), 0.3, 0.025, "t_panel")
	_rubble(m, Vector2(0.2, 0.8), 0.8, 0.8, 14, 101, 1.2)
	_rubble(m, Vector2(hx + 0.2, -0.6), 0.2, 0.5, 4, 102, 1.0)
	for i in 4:
		_rebar(m, Vector3(-1.0 + 0.45 * float(i), -1.6 + 0.2 * float(i), 0.8), i, 0.4)
	# pylon sign leaning
	_bone(m, Vector3(1.45, 1.3, 0.0), Vector3(1.2, 1.55, 1.2), 0.04, 0.04, "steel")
	_bx(m, Vector3(1.15, 1.6, 0.18), Vector3(0.05, 0.25, 0.14), "t_dgreen", 0.3)
	_bx(m, Vector3(0.1, 0.0, 0.1), Vector3(0.18, 0.14, 0.1), "t_panel", 0.4)


## Garage workshop: block walls with a yellow band, roll-up door, office window, tyre stacks and drums.
static func _garage(m: Array[Prim]) -> void:
	var hx := 0.85
	var hy := 0.65
	var wz := 0.3
	_plinth(m, Vector3.ZERO, hx, hy, 0.04)
	_bx(m, Vector3(0, 0, wz), Vector3(hx, hy, wz), "t_panel")
	_fx(m, hx, 0.0, 0.54, hy, 0.05, "t_dyellow", 0.0)
	_fy(m, 0.0, hy, 0.54, hx, 0.05, "t_dyellow", 0.0)
	# roll-up door with slats
	_fx(m, hx, -0.15, 0.27, 0.38, 0.27, "t_trim")
	_fx(m, hx, -0.15, 0.27, 0.35, 0.25, "steel", 0.004)
	for i in 8:
		_fx(m, hx, -0.15, 0.06 + 0.06 * float(i), 0.35, 0.004, "gun", 0.009)
	# office door and window
	_door_x(m, hx, 0.5, 0.07, 0.16, "t_dblue")
	_grid_y(m, hy, -0.5, 0.5, 3, [0.36], 0.09, 0.07)
	# sign board over the door and a corner pole sign
	_fx(m, hx, -0.15, 0.7, 0.4, 0.07, "t_dyellow", 0.0)
	_fx(m, hx, -0.15, 0.7, 0.34, 0.03, "t_dark", 0.006)
	# flat roof
	_flat(m, Vector3.ZERO, hx, hy, wz * 2.0, "corrugated", "steel", 0.04)
	_ac(m, Vector3(-0.3, 0.0, wz * 2.0 + 0.06), 1.0)
	# tyre stacks and drums
	for k in 4:
		_cy(m, Vector3(hx + 0.18, 0.55, 0.04 + 0.075 * float(k)), 0.08, 0.04, "t_dark")
	for k in 3:
		_cy(m, Vector3(hx + 0.2, -0.65, 0.04 + 0.075 * float(k)), 0.08, 0.04, "t_dark")
	_cy(m, Vector3(hx + 0.1, 0.2, 0.1), 0.06, 0.1, "drum")
	_cy(m, Vector3(-0.3, hy + 0.12, 0.1), 0.06, 0.1, "drum")
	_bx(m, Vector3(-0.1, hy + 0.15, 0.08), Vector3(0.14, 0.1, 0.08), "woodd")  # crate


# ---- offices, towers, industry --------------------------------------------------------------------------------------

## Five-storey office block: concrete frame, continuous glass bands, mullions, glazed lobby, rooftop plant.
## burnt 1: charred, windows blown out, fire and smoke on the upper floors.
static func _office(m: Array[Prim], burnt: int) -> void:
	var hx := 0.8
	var hy := 0.8
	var st := 0.44  # storey height
	var top := 0.18 + st * 5.0
	_plinth(m, Vector3.ZERO, hx, hy, 0.04)
	_bx(m, Vector3(0, 0, top * 0.5), Vector3(hx, hy, top * 0.5), "t_panel")
	for f in 5:  # glass bands per storey on both visible faces
		var z := 0.18 + st * (float(f) + 0.5)
		var gm := "t_curt" if f % 2 == 0 else "t_curtl"
		if f == 0:
			gm = "t_curtl"
		_fx(m, hx, 0.0, z, hy - 0.06, 0.15, gm, 0.0)
		_fy(m, 0.0, hy, z, hx - 0.06, 0.15, gm, 0.0)
		_fx(m, hx, 0.0, z + 0.2, hy, 0.025, "t_trim", 0.002)  # slab edge
		_fy(m, 0.0, hy, z + 0.2, hx, 0.025, "t_trim", 0.002)
	for i in 8:  # vertical mullions
		var t := -hy + 0.06 + (2.0 * hy - 0.12) * float(i) / 7.0
		_fx(m, hx, t, top * 0.5 + 0.0, 0.012, top * 0.5 - 0.1, "t_trim", 0.006)
		_fy(m, t * hx / hy, hy, top * 0.5, 0.012, top * 0.5 - 0.1, "t_trim", 0.006)
	# lobby with entrance canopy
	_fx(m, hx, 0.0, 0.16, 0.3, 0.14, "t_dark", 0.01)
	_fx(m, hx, 0.0, 0.16, 0.27, 0.12, "glass", 0.014)
	_bx(m, Vector3(hx + 0.12, 0.0, 0.36), Vector3(0.12, 0.34, 0.02), "t_trim")
	_flat(m, Vector3.ZERO, hx, hy, top, "concrete", "t_panel", 0.05)
	_bx(m, Vector3(-0.3, -0.2, top + 0.17), Vector3(0.25, 0.22, 0.11), "t_panelw")
	_ac(m, Vector3(0.25, 0.35, top + 0.06), 1.2)
	_ac(m, Vector3(0.3, -0.4, top + 0.06), 1.2)
	_cy(m, Vector3(-0.45, 0.45, top + 0.2), 0.07, 0.14, "t_wtank")
	_bone(m, Vector3(-0.3, -0.2, top + 0.28), Vector3(-0.3, -0.2, top + 0.65), 0.012, 0.012, "steel")
	if burnt == 0:
		return
	_burn(m)
	# charred shell: windows blown out (dark), fire in the upper floors, soot above them, a collapsed corner
	for f in 3:
		var zf := 0.18 + st * (2.0 + float(f) + 0.5)
		for i in 4:
			var y := -0.55 + 0.37 * float(i)
			if Base._rnd(i, 120 + f) < 0.6:
				_fx(m, hx, y, zf, 0.12, 0.12, "t_dark", 0.014)
				if Base._rnd(i, 130 + f) < 0.55:
					_fx(m, hx, y, zf - 0.04, 0.09, 0.07, "fire", 0.018)
			var x := -0.55 + 0.37 * float(i)
			if Base._rnd(i, 140 + f) < 0.6:
				_fy(m, x, hy, zf, 0.12, 0.12, "t_dark", 0.014)
				if Base._rnd(i, 150 + f) < 0.5:
					_fy(m, x, hy, zf - 0.04, 0.09, 0.07, "fire", 0.018)
	_blob(m, Vector3(0.1, 0.1, top + 0.1), 0.2, "fire")
	_blob(m, Vector3(-0.1, 0.0, top + 0.35), 0.2, "smoke")
	_blob(m, Vector3(-0.05, -0.05, top + 0.65), 0.22, "smoke")
	_blob(m, Vector3(0.05, -0.1, top + 0.95), 0.2, "smoke")
	_rubble(m, Vector2(hx + 0.25, 0.3), 0.2, 0.5, 5, 161, 0.9)
	_rubble(m, Vector2(0.4, hy + 0.2), 0.5, 0.2, 5, 162, 0.9)


## High-rise residential tower: concrete panels, window columns, balcony bands, podium, roof plant and mast.
## dmg 1: the top floors on the +x/+y side have fallen away, leaving slabs, rebar and a rubble skirt.
static func _tower_block(m: Array[Prim], dmg: int) -> void:
	var hx := 0.6
	var hy := 0.6
	var st := 0.42
	var floors := 9
	var top := 0.34 + st * float(floors)
	_plinth(m, Vector3.ZERO, 0.78, 0.7, 0.04)
	_bx(m, Vector3(0, 0, 0.17), Vector3(0.74, 0.66, 0.15), "t_panelw")  # podium
	var fl := floors if dmg == 0 else 5
	var ztop := 0.34 + st * float(fl)
	_bx(m, Vector3(0, 0, 0.17 + (ztop - 0.17) * 0.5), Vector3(hx, hy, (ztop - 0.17) * 0.5), "t_panel")
	for f in fl:
		var z := 0.34 + st * (float(f) + 0.5)
		for i in 4:
			var y := -0.42 + 0.28 * float(i)
			_wx(m, hx, y, z, 0.07, 0.1, "lampglow" if (dmg == 0 and Base._rnd(i + f * 4, 171) < 0.14) else "glass")
			_wy(m, y, hy, z, 0.07, 0.1, "lampglow" if (dmg == 0 and Base._rnd(i + f * 4, 172) < 0.14) else "glass")
		_fx(m, hx, 0.0, z - 0.18, hy, 0.014, "t_panelw", 0.002)  # balcony / slab bands
		_fy(m, 0.0, hy, z - 0.18, hx, 0.014, "t_panelw", 0.002)
	for i in 3:  # coloured infill columns
		_fx(m, hx, -0.42 + 0.56 * float(i), 0.34 + (ztop - 0.34) * 0.5, 0.02, (ztop - 0.34) * 0.5, "t_dblue", 0.004)
	_door_x(m, 0.74, 0.0, 0.12, 0.18, "t_dblue")
	_fx(m, 0.74, -0.35, 0.17, 0.14, 0.09, "glass", 0.0)
	_fx(m, 0.74, 0.35, 0.17, 0.14, 0.09, "glass", 0.0)
	_bx(m, Vector3(0.82, 0.0, 0.36), Vector3(0.1, 0.3, 0.02), "t_trim")
	_fy(m, 0.0, 0.66, 0.17, 0.5, 0.06, "t_curtl", 0.0)
	if dmg == 0:
		_flat(m, Vector3.ZERO, hx, hy, top, "concrete", "t_panel", 0.05)
		_bx(m, Vector3(-0.1, 0.1, top + 0.15), Vector3(0.16, 0.16, 0.1), "t_panelw")
		_bone(m, Vector3(0.3, -0.3, top), Vector3(0.3, -0.3, top + 0.7), 0.012, 0.012, "steel")
		_bx(m, Vector3(0.3, -0.3, top + 0.72), Vector3(0.02, 0.02, 0.02), "red")
		_ac(m, Vector3(-0.3, -0.3, top + 0.06), 1.0)
		return
	# ruin: floors above storey 5 are mostly gone; a few walls and sagging slabs remain on the back side
	_bx(m, Vector3(0, 0, ztop + 0.02), Vector3(hx, hy, 0.025), "concrete")
	_jag(m, Vector2(-hx, -hy), Vector2(-hx, hy), 0.4, 1.6, "t_panel", 181, 6, 0.04, ztop)
	_jag(m, Vector2(-hx, hy), Vector2(hx, hy), 0.1, 1.3, "t_panel", 182, 6, 0.04, ztop)
	_jag(m, Vector2(-hx, -hy), Vector2(hx, -hy), 0.3, 1.5, "t_panel", 183, 6, 0.04, ztop)
	for k in 2:
		_bx(m, Vector3(-0.2, -0.1, ztop + 0.45 + 0.4 * float(k)), Vector3(0.38, 0.5, 0.022), "concrete")
	_bone(m, Vector3(0.2, 0.3, ztop + 0.9), Vector3(0.55, 0.6, ztop + 0.1), 0.2, 0.025, "concretel")  # slab hanging down the face
	for i in 6:
		_rebar(m, Vector3(-0.5 + 0.2 * float(i), -0.5 + 0.18 * float(i), ztop + 0.9 + 0.3 * Base._rnd(i, 190)), i, 0.4)
	# a blown-out hole in the lower storeys and a rubble skirt
	_fx(m, hx, 0.0, 0.34 + st * 2.5, 0.2, 0.18, "t_dark", 0.014)
	_rubble(m, Vector2(0.95, 0.2), 0.35, 0.7, 12, 191, 1.3)
	_rubble(m, Vector2(0.3, 0.95), 0.6, 0.3, 8, 192, 1.2)
	_blob(m, Vector3(0.0, 0.0, ztop + 0.3), 0.18, "smoke")


## Factory: brick hall under a sawtooth roof (glazed faces towards +x), loading doors, pipes and a tall banded chimney.
## dmg 1: roof mostly fallen, jagged walls, the chimney broken off half way.
static func _factory(m: Array[Prim], dmg: int) -> void:
	var hx := 1.4
	var hy := 0.9
	var wz := 0.42
	_plinth(m, Vector3.ZERO, hx, hy, 0.04)
	var chim := Vector3(-1.1, -0.1, 0)
	if dmg == 0:
		_bx(m, Vector3(0, 0, wz), Vector3(hx, hy, wz), "brick")
		_bx(m, Vector3(0, 0, 0.08), Vector3(hx + 0.012, hy + 0.012, 0.08), "stonel")
		# sawtooth: 4 teeth, each rising towards +x, glazed on the vertical face
		var n := 4
		var tw := 2.0 * hx / float(n)
		for i in n:
			var x0 := -hx + tw * float(i)
			var x1 := x0 + tw
			_bone(m, Vector3(x0, 0, wz * 2.0 + 0.02), Vector3(x1, 0, wz * 2.0 + 0.36), hy + 0.03, 0.018, "corrugated")
			_bx(m, Vector3(x1 - 0.01, 0, wz * 2.0 + 0.18), Vector3(0.012, hy, 0.18), "t_curtl")
			for j in 6:
				_bx(m, Vector3(x1, -hy + 0.1 + (2.0 * hy - 0.2) * float(j) / 5.0, wz * 2.0 + 0.18), Vector3(0.014, 0.01, 0.18), "steel")
			_bx(m, Vector3(x1 - 0.03, 0, wz * 2.0 + 0.36), Vector3(0.05, hy + 0.03, 0.012), "steel")
		# +x end: two loading doors and a dock
		_bx(m, Vector3(hx + 0.12, 0.0, 0.1), Vector3(0.12, hy, 0.1), "concrete")
		for k in 2:
			var y := -0.4 + 0.8 * float(k)
			_fx(m, hx, y, 0.3, 0.26, 0.24, "t_trim")
			_fx(m, hx, y, 0.3, 0.23, 0.22, "steel", 0.004)
			for q in 6:
				_fx(m, hx, y, 0.12 + 0.07 * float(q), 0.23, 0.004, "gun", 0.009)
		# +y long face: windows row and a side door, pipe run
		_grid_y(m, hy, -1.1, 0.7, 7, [0.52], 0.08, 0.07)
		_door_y(m, 1.1, hy, 0.09, 0.17, "t_dyellow")
		_bone(m, Vector3(-0.6, hy + 0.1, 0.8), Vector3(0.6, hy + 0.1, 0.8), 0.03, 0.03, "rust")
		_bone(m, Vector3(0.6, hy + 0.1, 0.8), Vector3(0.6, hy + 0.1, 0.1), 0.03, 0.03, "rust")
		_cy(m, Vector3(0.9, hy + 0.2, 0.28), 0.14, 0.28, "tankg")  # storage tank
		_cy(m, Vector3(0.9, hy + 0.2, 0.58), 0.15, 0.015, "steel")
		# chimney
		_cy(m, chim + Vector3(0, 0, 0.04), 0.14, 0.04, "concrete")
		_cy(m, chim + Vector3(0, 0, 0.55), 0.1, 0.5, "brick")
		_cy(m, chim + Vector3(0, 0, 1.5), 0.085, 0.46, "brick")
		for k in 3:
			_cy(m, chim + Vector3(0, 0, 1.62 + 0.12 * float(k)), 0.088, 0.03, "red" if k % 2 == 0 else "whitep")
		_cy(m, chim + Vector3(0, 0, 1.98), 0.1, 0.02, "concrete")
		_bone(m, chim + Vector3(0.09, 0, 0.1), chim + Vector3(0.09, 0, 1.6), 0.012, 0.012, "steel")  # ladder
		return
	# ruin
	_jag(m, Vector2(hx, -hy), Vector2(hx, hy), 0.2, 0.9, "brick", 201, 14, 0.05)
	_jag(m, Vector2(-hx, -hy), Vector2(hx, -hy), 0.3, 0.95, "brick", 202, 16, 0.05)
	_jag(m, Vector2(-hx, hy), Vector2(hx, hy), 0.12, 0.8, "brick", 203, 16, 0.05)
	_jag(m, Vector2(-hx, -hy), Vector2(-hx, hy), 0.3, 1.0, "brick", 204, 10, 0.05)
	_bx(m, Vector3(0, 0, 0.05), Vector3(hx, hy, 0.02), "concrete")
	# two teeth survive at the back, one fallen across the floor
	for i in 2:
		var x0 := -hx + 0.7 * float(i)
		_bone(m, Vector3(x0, 0, 0.86), Vector3(x0 + 0.7, 0, 1.2), hy + 0.03, 0.018, "corrugated")
		_bx(m, Vector3(x0 + 0.69, 0, 1.02), Vector3(0.012, hy, 0.18), "t_curtl")
		for q in 4:
			_bx(m, Vector3(x0 + 0.1 + 0.18 * float(q), -hy + 0.02, 0.4), Vector3(0.04, 0.04, 0.4), "steel")
	_bone(m, Vector3(0.5, -0.6, 0.7), Vector3(1.2, 0.2, 0.15), 0.4, 0.018, "corrugated")
	_rubble(m, Vector2(0.4, 0.0), 0.9, 0.7, 16, 211, 1.2)
	for i in 4:
		_rebar(m, Vector3(-0.9 + 0.5 * float(i), 0.3, 0.9), i + 3, 0.3)
	# broken chimney: stump with a jagged top and bricks around it
	_cy(m, chim + Vector3(0, 0, 0.04), 0.14, 0.04, "concrete")
	_cy(m, chim + Vector3(0, 0, 0.4), 0.1, 0.36, "brick")
	for k in 4:
		var a := float(k) * 1.57
		_bx(m, chim + Vector3(cos(a) * 0.06, sin(a) * 0.06, 0.8 + 0.06 * Base._rnd(k, 215)), Vector3(0.04, 0.04, 0.05 + 0.04 * Base._rnd(k, 216)), "brick")
	_bone(m, chim + Vector3(0.1, 0.0, 0.8), chim + Vector3(0.8, 0.5, 0.06), 0.09, 0.09, "brick")  # the top, lying where it fell
	_bone(m, chim + Vector3(0.7, 0.45, 0.1), chim + Vector3(0.78, 0.5, 0.12), 0.1, 0.1, "red")
	_cy(m, Vector3(0.9, hy + 0.2, 0.28), 0.14, 0.28, "tankg")


## Water tower: banded steel tank on a braced four-leg lattice, with a ladder, catwalk and conical roof.
static func _water_tower(m: Array[Prim]) -> void:
	var zb := 0.9  # tank base height
	for sx in [1.0, -1.0]:
		for sy in [1.0, -1.0]:
			var fx: float = float(sx)
			var fy: float = float(sy)
			_bx(m, Vector3(0.34 * fx, 0.34 * fy, 0.04), Vector3(0.06, 0.06, 0.04), "concrete")
			_bone(m, Vector3(0.34 * fx, 0.34 * fy, 0.04), Vector3(0.24 * fx, 0.24 * fy, zb), 0.025, 0.025, "steel")
	for k in 2:  # X bracing between legs on each level
		var z0 := 0.1 + 0.38 * float(k)
		var z1 := z0 + 0.38
		var w0 := 0.34 - 0.1 * (z0 - 0.04) / (zb - 0.04)
		var w1 := 0.34 - 0.1 * (z1 - 0.04) / (zb - 0.04)
		for s in [1.0, -1.0]:
			var fs: float = float(s)
			_bone(m, Vector3(w0 * fs, w0, z0), Vector3(-w1 * fs, w1, z1), 0.008, 0.008, "rust")
			_bone(m, Vector3(w0, w0 * fs, z0), Vector3(w1, -w1 * fs, z1), 0.008, 0.008, "rust")
			_bone(m, Vector3(w0 * fs, -w0, z0), Vector3(-w1 * fs, -w1, z1), 0.008, 0.008, "rust")
			_bone(m, Vector3(-w0, w0 * fs, z0), Vector3(-w1, -w1 * fs, z1), 0.008, 0.008, "rust")
		_bx(m, Vector3(0, w1, z1), Vector3(w1, 0.012, 0.012), "steel")
		_bx(m, Vector3(0, -w1, z1), Vector3(w1, 0.012, 0.012), "steel")
		_bx(m, Vector3(w1, 0, z1), Vector3(0.012, w1, 0.012), "steel")
		_bx(m, Vector3(-w1, 0, z1), Vector3(0.012, w1, 0.012), "steel")
	_bx(m, Vector3(0, 0, zb + 0.02), Vector3(0.32, 0.32, 0.025), "steel")  # platform
	_cy(m, Vector3(0, 0, zb + 0.34), 0.34, 0.3, "t_wtank")
	for k in 3:
		_cy(m, Vector3(0, 0, zb + 0.14 + 0.18 * float(k)), 0.345, 0.012, "steel")
	_cy(m, Vector3(0, 0, zb + 0.66), 0.36, 0.02, "steel")
	for i in 8:  # roof cone, stepped
		var f := 1.0 - (float(i) + 0.5) / 8.0
		_cy(m, Vector3(0, 0, zb + 0.7 + 0.035 * float(i)), 0.34 * f, 0.02, "t_silor")
	_cy(m, Vector3(0, 0, zb + 1.02), 0.02, 0.04, "steel")
	# ladder and catwalk ring
	_bone(m, Vector3(0.3, 0.1, 0.06), Vector3(0.36, 0.1, zb + 0.6), 0.02, 0.012, "steel")
	_bone(m, Vector3(0.3, 0.17, 0.06), Vector3(0.36, 0.17, zb + 0.6), 0.02, 0.012, "steel")
	for k in 12:
		_bone(m, Vector3(0.31, 0.1, 0.12 + 0.12 * float(k)), Vector3(0.33, 0.17, 0.12 + 0.12 * float(k)), 0.008, 0.008, "steel")
	_bone(m, Vector3(0.0, -0.05, zb + 0.5), Vector3(0.0, -0.05, 0.1), 0.02, 0.02, "steel")  # pipe down the middle


## Two-storey motel strip: room doors and windows along the front, an upper walkway on posts, stairs, an end office, lit pylon sign.
static func _motel(m: Array[Prim]) -> void:
	var hx := 1.5
	var hy := 0.35
	var wz := 0.5
	_plinth(m, Vector3.ZERO, hx, hy + 0.3, 0.04, "t_asph")
	_bx(m, Vector3(0, 0, wz), Vector3(hx, hy, wz), "t_yellow")
	_bx(m, Vector3(0, 0, 0.06), Vector3(hx + 0.012, hy + 0.012, 0.06), "stonel")
	for s in _sides():
		var sg: float = float(s)
		# walkway slab, posts and rail on this side
		_bx(m, Vector3(0, sg * (hy + 0.15), 0.5), Vector3(hx, 0.15, 0.02), "concrete")
		for i in 9:
			var x := -hx + 0.1 + (2.0 * hx - 0.2) * float(i) / 8.0
			_cy(m, Vector3(x, sg * (hy + 0.28), 0.25), 0.015, 0.25, "t_trim")
		_bx(m, Vector3(0, sg * (hy + 0.29), 0.62), Vector3(hx, 0.01, 0.012), "t_trim")
		for i in 24:
			var x2 := -hx + 0.06 + (2.0 * hx - 0.12) * float(i) / 23.0
			_bx(m, Vector3(x2, sg * (hy + 0.29), 0.56), Vector3(0.006, 0.006, 0.05), "t_trim")
	# doors and windows per room (6 rooms), both floors, on the front face(s)
	for i in 6:
		var x4 := -1.2 + 0.46 * float(i) + 0.0
		var dm := "red" if i % 2 == 0 else "t_dblue"
		for fl in 2:
			var z0 := 0.04 if fl == 0 else 0.54
			_door_y(m, x4 - 0.08, hy, 0.065, 0.16, dm, z0)
			_wy(m, x4 + 0.12, hy, z0 + 0.2, 0.08, 0.08)
	_gab(m, Vector3.ZERO, hx, hy, 1.0, 0.1, "t_rustroof", "t_yellow", true)
	# end office (+x)
	_fx(m, hx, 0.0, 0.26, 0.26, 0.2, "t_trim")
	_fx(m, hx, 0.0, 0.26, 0.24, 0.18, "glass", 0.004)
	_wx(m, hx, 0.0, 0.76, 0.12, 0.1)
	_bx(m, Vector3(hx + 0.1, 0.0, 0.5), Vector3(0.1, 0.3, 0.02), "red")  # office awning
	# pylon sign
	_cy(m, Vector3(1.65, 0.0, 0.5), 0.02, 0.5, "steel")
	_bx(m, Vector3(1.65, 0.0, 1.05), Vector3(0.04, 0.26, 0.12), "red")
	_fx(m, 1.69, 0.0, 1.05, 0.23, 0.09, "lampglow", 0.0)
	_fx(m, 1.69, 0.0, 1.05, 0.18, 0.025, "red", 0.006)
