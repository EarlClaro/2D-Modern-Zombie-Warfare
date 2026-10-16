extends RefCounted
## Theme pack: props (urban, rural and roadside clutter). Loaded by tools/gen_sprites.gd, see docs/specs/art-pack-2.md.
## Contract as in pack_nature.gd: MATS (prefix `p_`), specs() (cat "prop"), build() (returns false for a unit it does not own).
## Models are authored at about 0.3 to 1.0 units tall and enlarged by the spec's `k`. The camera sees the +x face, +y face and
## top of the model. Lit faces (windows, lenses, lamps) use the `p_lit*` materials whose three tones are all bright.

const Base = preload("res://tools/gen_sprites.gd")
const Prim = Base.Prim

const MATS := {
	"p_pallet": ["8a6a3c", "b08a52", "cfae72"],
	"p_palletd": ["5e4426", "7e5e36", "9a7848"],
	"p_card": ["8a6a3a", "b8924e", "dcb878"],
	"p_tape": ["a89a78", "c8b890", "e4d8b0"],
	"p_cone": ["b03a08", "f06a14", "ff9a40"],
	"p_conebase": ["16181a", "24272a", "34383c"],
	"p_yellow": ["a88a10", "e8c020", "fff060"],
	"p_redbox": ["7a1410", "b82418", "e64a38"],
	"p_blue": ["1c3a6a", "2c5ca8", "4a82d8"],
	"p_green": ["1c4426", "2b7a3e", "46a85c"],
	"p_greend": ["163820", "225a30", "34804a"],
	"p_poster0": ["b0ac9e", "d6d2c4", "f0ece0"],
	"p_poster1": ["1e5a66", "2e8a9a", "58bccc"],
	"p_poster2": ["a8480e", "e07a22", "ffa850"],
	"p_poster3": ["5a2a6a", "8a4aa0", "b878d0"],
	"p_utilpole": ["3a2a1c", "54402c", "6e563c"],
	"p_insul": ["2c5a50", "3f8a78", "66b8a0"],
	"p_utilgreen": ["243a2a", "365a42", "4c7a5a"],
	"p_chrome": ["5a666a", "8fa0a6", "c8d6da"],
	"p_hay": ["a8842c", "d4aa44", "f0cc6a"],
	"p_hayd": ["7a5e1c", "a07e30", "c09e48"],
	"p_water": ["3a7aa8", "5aa8d4", "9ad6f0"],
	"p_tarp": ["1c4a7a", "2c70b0", "4a96d8"],
	"p_tarpd": ["163a62", "225a90", "3a7cb8"],
	"p_rope": ["5a4a2a", "8a7448", "b0a070"],
	"p_bronze": ["2a4a40", "4a8070", "7ab8a0"],
	"p_burlap": ["8a7048", "b09462", "d0b87c"],
	"p_lit": ["c8dcea", "e4f2ff", "ffffff"],
	"p_litw": ["e0c070", "f8e090", "fff8d0"],
	"p_lred": ["d02a1c", "ff3a28", "ff9080"],
	"p_lamberoff": ["3a2a0a", "5a3e0c", "7a5410"],
	"p_lgreenoff": ["0e2a14", "163e20", "1f5a2e"],
	"p_lgreen": ["28a050", "40e070", "a0ffb8"],
	"p_vendred": ["6a1410", "a82418", "d84a36"],
	"p_ash": ["1c1a18", "2c2a26", "3e3a34"],
	"p_cable": ["1a1c1e", "2c3033", "44494d"],
	"p_bistro": ["3a5a50", "5a8a78", "8ab8a4"],
	"p_busgrey": ["3a4248", "5a666e", "8090a0"],
}


static func _spec(dir: String, display: String, k: float, facings: Array = ["se"], extra: Dictionary = {}) -> Dictionary:
	var d := {"dir": dir, "name": display, "cat": "prop", "auto": true, "k": k, "frames": 1, "columns": 1, "ss": 2, "facings": facings}
	d.merge(extra, true)
	return d


static func specs() -> Array:
	var both := ["se", "sw"]
	return [
		_spec("pallet_stack", "Pallet Stack", 1.4),
		_spec("cardboard_boxes", "Cardboard Boxes", 1.5),
		_spec("traffic_cone", "Traffic Cones", 1.27, ["se"], {"foot": Vector2i(1, 1)}),
		_spec("road_barricade", "Road Barricade", 1.12, both, {"glow": [Vector3(-0.3, 0, 0.5), 22.0, Color(1.0, 0.7, 0.2)]}),
		_spec("mailbox", "Mailbox", 1.27),
		_spec("phone_booth", "Phone Booth", 1.5),
		_spec("bus_stop", "Bus Stop", 1.4, both),
		_spec("vending_machine", "Vending Machine", 1.6, ["se"], {"glow": [Vector3(0.14, 0, 0.34), 40.0, Color(0.7, 0.9, 1.0)]}),
		_spec("fire_hydrant", "Fire Hydrant", 1.44),
		_spec("billboard", "Billboard", 1.3, both, {"foot": Vector2i(2, 1)}),
		_spec("traffic_light", "Traffic Light", 1.8, ["se"], {"glow": [Vector3(0.3, 0.046, 0.86), 30.0, Color(1.0, 0.25, 0.15)]}),
		_spec("power_pole", "Power Pole", 1.4, both),
		_spec("transformer", "Transformer", 1.6),
		_spec("ac_unit", "AC Unit", 1.7),
		_spec("satellite_dish", "Satellite Dish", 1.6),
		_spec("wheelie_bin", "Wheelie Bins", 1.7),
		_spec("shopping_cart", "Shopping Cart", 1.14),
		_spec("petrol_pump", "Petrol Pumps", 1.5, both),
		_spec("fountain", "Fountain", 1.3),
		_spec("gravestone", "Graveyard", 1.42, ["se"], {"foot": Vector2i(1, 1)}),
		_spec("picnic_table", "Picnic Table", 1.5, both),
		_spec("swing_set", "Swing Set", 1.5, both),
		_spec("hay_bale", "Hay Bales", 1.6),
		_spec("water_well", "Water Well", 1.6),
		_spec("scarecrow", "Scarecrow", 1.5),
		_spec("tarp_pile", "Tarp Pile", 1.6, ["se"], {"foot": Vector2i(1, 1)}),
		_spec("newspaper_stand", "Newspaper Stand", 1.33),
		_spec("park_statue", "Park Statue", 1.4),
		_spec("cable_drum", "Cable Drum", 1.6),
		_spec("market_stall", "Market Stall", 1.3, both),
		_spec("lawn_chairs", "Lawn Chairs", 1.36, ["se"], {"foot": Vector2i(1, 1)}),
		_spec("campfire", "Campfire", 1.7, ["se"], {"glow": [Vector3(0, 0, 0.2), 56.0, Color(1.0, 0.55, 0.2)]}),
		_spec("bike_rack", "Bike Rack", 1.7, both, {"foot": Vector2i(1, 1)}),
		_spec("street_cafe_table", "Street Cafe Table", 1.4, ["se"], {"foot": Vector2i(1, 1)}),
	]


static func build(_host: Object, m: Array[Prim], unit: String, _frame: int) -> bool:
	match unit:
		"pallet_stack":
			_pallets(m)
		"cardboard_boxes":
			_boxes(m)
		"traffic_cone":
			_cones(m)
		"road_barricade":
			_barricade(m)
		"mailbox":
			_mailbox(m)
		"phone_booth":
			_phone_booth(m)
		"bus_stop":
			_bus_stop(m)
		"vending_machine":
			_vending(m)
		"fire_hydrant":
			_hydrant(m)
		"billboard":
			_billboard(m)
		"traffic_light":
			_traffic_light(m)
		"power_pole":
			_power_pole(m)
		"transformer":
			_transformer(m)
		"ac_unit":
			_ac_unit(m)
		"satellite_dish":
			_dish(m)
		"wheelie_bin":
			_bins(m)
		"shopping_cart":
			_cart(m)
		"petrol_pump":
			_petrol(m)
		"fountain":
			_fountain(m)
		"gravestone":
			_graves(m)
		"picnic_table":
			_picnic(m)
		"swing_set":
			_swings(m)
		"hay_bale":
			_hay(m)
		"water_well":
			_well(m)
		"scarecrow":
			_scarecrow(m)
		"tarp_pile":
			_tarp(m)
		"newspaper_stand":
			_news(m)
		"park_statue":
			_statue(m)
		"cable_drum":
			_drum(m)
		"market_stall":
			_stall(m)
		"lawn_chairs":
			_lawn_chairs(m)
		"campfire":
			_campfire(m)
		"bike_rack":
			_bike_rack(m)
		"street_cafe_table":
			_cafe(m)
		_:
			return false
	return true


# ---- helpers -----------------------------------------------------------------------------------------

static func _bx(m: Array[Prim], c: Vector3, h: Vector3, mat: String, yaw: float = 0.0) -> void:
	Base._bx(m, c, h, mat, yaw)


static func _cy(m: Array[Prim], c: Vector3, r: float, hz: float, mat: String) -> void:
	Base._cy(m, c, r, hz, mat)


static func _sp(m: Array[Prim], c: Vector3, r: Vector3, mat: String) -> void:
	Base._sp(m, c, r, mat)


static func _bn(m: Array[Prim], p0: Vector3, p1: Vector3, hy: float, hz: float, mat: String) -> void:
	Base._bone(m, p0, p1, hy, hz, mat)


## Cylinder lying along the local x axis (half length `hl`), turned by `yaw` (PI/2 lays it along y).
static func _cyx(m: Array[Prim], c: Vector3, r: float, hl: float, mat: String, yaw: float = 0.0) -> void:
	m.append(Prim.new(Base.CYL, c, Vector3(r, 0.0, hl), mat, yaw, 0.0, PI * 0.5))


## Box tilted about the x axis by `ang` (positive raises the +y side).
static func _bxt(m: Array[Prim], c: Vector3, h: Vector3, mat: String, ang: float) -> void:
	var p := Prim.new(Base.BOX, c, h, mat)
	p.basis = Basis(Vector3(1, 0, 0), ang)
	m.append(p)


## Ring of `n` boxes round a circle of radius r (an octagon-like wall); `th` radial half thickness, `hz` half height.
static func _ring(m: Array[Prim], c: Vector3, r: float, n: int, th: float, hz: float, mat: String, mat2: String = "") -> void:
	for i in n:
		var a := TAU * float(i) / float(n)
		var mt := mat if (mat2 == "" or i % 2 == 0) else mat2
		var len := r * sin(PI / float(n)) * 1.04
		_bx(m, c + Vector3(cos(a) * r, sin(a) * r, 0.0), Vector3(len, th, hz), mt, a + PI * 0.5)


## Moves a finished group by yaw about the origin then a shift, and adds it to the model.
static func _put(m: Array[Prim], g: Array[Prim], yaw: float, shift: Vector3) -> void:
	Base._xform_about(g, Vector3.ZERO, Basis(Vector3(0, 0, 1), yaw), shift)
	m.append_array(g)


## Lowest point of a group (corner bound), used to drop tipped objects onto the ground.
static func _lowest(g: Array[Prim]) -> float:
	var lo := INF
	for p in g:
		var ext := p.h
		if p.kind == Base.CYL:
			ext = Vector3(p.h.x, p.h.x, p.h.z)
		for sx: float in [-1.0, 1.0]:
			for sy: float in [-1.0, 1.0]:
				for sz: float in [-1.0, 1.0]:
					var q: Vector3 = p.c + p.basis * Vector3(ext.x * sx, ext.y * sy, ext.z * sz)
					lo = minf(lo, q.z)
	return lo


# ---- models ------------------------------------------------------------------------------------------

## One wooden pallet (0.52 x 0.4 x 0.068): bearers, bottom boards, spaced deck boards.
static func _pallet(m: Array[Prim], c: Vector3, yaw: float, mat: String) -> void:
	var g: Array[Prim] = []
	for y: float in [-0.17, 0.0, 0.17]:
		_bx(g, Vector3(0, y, 0.03), Vector3(0.25, 0.026, 0.018), "p_palletd")
	for i in 3:
		_bx(g, Vector3(-0.22 + 0.22 * float(i), 0, 0.008), Vector3(0.03, 0.2, 0.008), mat)
	for i in 6:
		_bx(g, Vector3(-0.22 + 0.088 * float(i), 0, 0.058), Vector3(0.034, 0.2, 0.01), mat)
	_put(m, g, yaw, c)


## Five pallets stacked slightly out of true, one more leaning against the +x side.
static func _pallets(m: Array[Prim]) -> void:
	var offs: Array[Vector2] = [Vector2(0, 0), Vector2(0.02, -0.015), Vector2(-0.015, 0.02), Vector2(0.025, 0.01), Vector2(-0.01, -0.02)]
	var yaws: Array[float] = [0.0, 0.07, -0.05, 0.1, -0.08]
	for i in 5:
		_pallet(m, Vector3(offs[i].x, offs[i].y, 0.068 * float(i)), yaws[i], "p_pallet" if i % 2 == 0 else "p_palletd")
	var g: Array[Prim] = []
	_pallet(g, Vector3.ZERO, 0.0, "p_pallet")
	var pivot := Vector3(0, 0, 0.034)
	Base._xform_about(g, pivot, Basis(Vector3(0, 1, 0), -1.42), Vector3(0.33, 0.02, 0.26) - pivot)
	m.append_array(g)


## One cardboard box with a tape strip; `open` leaves the top dark with four flaps.
static func _cbox(m: Array[Prim], c: Vector3, h: Vector3, yaw: float, open: bool) -> void:
	var g: Array[Prim] = []
	_bx(g, Vector3(0, 0, h.z), h, "p_card")
	if open:
		_bx(g, Vector3(0, 0, h.z * 2.0 + 0.002), Vector3(h.x - 0.012, h.y - 0.012, 0.002), "woodc")
		_bn(g, Vector3(0, h.y, h.z * 2.0), Vector3(0, h.y + 0.07, h.z * 2.0 + 0.05), h.x * 0.8, 0.005, "p_card")
		_bn(g, Vector3(0, -h.y, h.z * 2.0), Vector3(0, -h.y - 0.06, h.z * 2.0 + 0.06), h.x * 0.8, 0.005, "p_tape")
		_bn(g, Vector3(h.x, 0, h.z * 2.0), Vector3(h.x + 0.05, 0, h.z * 2.0 + 0.07), h.y * 0.8, 0.005, "p_card")
	else:
		_bx(g, Vector3(0, 0, h.z * 2.0 + 0.003), Vector3(h.x * 0.96, 0.014, 0.004), "p_tape")
		_bx(g, Vector3(h.x + 0.003, 0, h.z * 1.5), Vector3(0.003, h.y * 0.5, h.z * 0.4), "whitep")  # shipping label
	_put(m, g, yaw, c)


static func _boxes(m: Array[Prim]) -> void:
	_cbox(m, Vector3(0.0, 0.0, 0.0), Vector3(0.14, 0.12, 0.09), 0.15, false)
	_cbox(m, Vector3(0.0, 0.0, 0.18), Vector3(0.1, 0.09, 0.07), -0.2, false)
	_cbox(m, Vector3(-0.04, 0.24, 0.0), Vector3(0.09, 0.08, 0.075), 0.3, true)
	_cbox(m, Vector3(0.22, -0.16, 0.0), Vector3(0.1, 0.075, 0.06), 0.5, false)
	_cbox(m, Vector3(0.2, 0.14, 0.0), Vector3(0.06, 0.06, 0.05), -0.4, false)
	_cbox(m, Vector3(0.0, 0.0, 0.32), Vector3(0.07, 0.06, 0.05), 0.6, false)


## One traffic cone: square base and six stacked rings (orange, white reflective band, orange tip).
static func _cone(m: Array[Prim], c: Vector3, s: float) -> void:
	var g: Array[Prim] = []
	_bx(g, Vector3(0, 0, 0.012), Vector3(0.1, 0.1, 0.012), "p_conebase")
	var radii: Array[float] = [0.082, 0.072, 0.062, 0.051, 0.04, 0.03]
	var mats: Array[String] = ["p_cone", "p_cone", "p_cone", "whitep", "whitep", "p_cone"]
	for i in 6:
		_cy(g, Vector3(0, 0, 0.049 + 0.04 * float(i)), radii[i], 0.02, mats[i])
	_cy(g, Vector3(0, 0, 0.3), 0.022, 0.01, "p_cone")
	for p in g:
		p.c *= s
		p.h *= s
	for p in g:
		p.c += c
	m.append_array(g)


static func _cones(m: Array[Prim]) -> void:
	_cone(m, Vector3(0.0, 0.0, 0.0), 1.0)
	_cone(m, Vector3(0.2, 0.13, 0.0), 0.88)
	_cone(m, Vector3(-0.06, 0.24, 0.0), 0.94)


## Striped A-frame road barricade with an amber lamp on top, long axis along x.
static func _barricade(m: Array[Prim]) -> void:
	for i in 8:
		var x := -0.35 + 0.1 * float(i)
		var mt := "red" if i % 2 == 0 else "whitep"
		_bx(m, Vector3(x + 0.05, 0, 0.35), Vector3(0.05, 0.014, 0.05), mt)
		_bx(m, Vector3(x + 0.05, 0, 0.2), Vector3(0.05, 0.014, 0.04), "whitep" if i % 2 == 0 else "red")
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			_bn(m, Vector3(0.31 * sx, 0.15 * sy, 0.0), Vector3(0.3 * sx, 0.02 * sy, 0.4), 0.014, 0.014, "p_chrome")
		_bx(m, Vector3(0.3 * sx, 0, 0.1), Vector3(0.012, 0.06, 0.008), "p_chrome")
	_bx(m, Vector3(-0.3, 0, 0.42), Vector3(0.04, 0.04, 0.012), "gun")
	_cy(m, Vector3(-0.3, 0, 0.47), 0.03, 0.035, "p_litw")
	_cy(m, Vector3(-0.3, 0, 0.51), 0.034, 0.008, "gun")


## US-style blue collection box: arched top, drop door, pedestal.
static func _mailbox(m: Array[Prim]) -> void:
	_bx(m, Vector3(0, 0, 0.015), Vector3(0.1, 0.085, 0.015), "concrete")
	_cy(m, Vector3(0, 0, 0.09), 0.04, 0.075, "steel")
	_bx(m, Vector3(0, 0, 0.29), Vector3(0.095, 0.075, 0.125), "p_blue")
	_sp(m, Vector3(0, 0, 0.415), Vector3(0.095, 0.075, 0.05), "p_blue")
	_bx(m, Vector3(0, 0, 0.17), Vector3(0.1, 0.08, 0.012), "gun")  # base band
	_bx(m, Vector3(0.098, 0, 0.36), Vector3(0.006, 0.055, 0.02), "gun")  # drop slot
	_bx(m, Vector3(0.099, 0, 0.36), Vector3(0.004, 0.045, 0.008), "woodc")
	_bx(m, Vector3(0.098, 0, 0.27), Vector3(0.006, 0.05, 0.05), "whitep")  # collection plate
	_bx(m, Vector3(0.1, 0, 0.29), Vector3(0.004, 0.03, 0.006), "red")
	_bx(m, Vector3(0.1, 0, 0.25), Vector3(0.004, 0.035, 0.004), "gun")
	_bx(m, Vector3(0.0, 0.078, 0.3), Vector3(0.05, 0.005, 0.045), "whitep")  # side decal
	_bx(m, Vector3(0.0, 0.08, 0.3), Vector3(0.03, 0.004, 0.012), "red")
	_bn(m, Vector3(0.1, 0.0, 0.2), Vector3(0.13, 0.0, 0.2), 0.012, 0.01, "steel")  # pull handle


## Red telephone box: red frame, 3 x 4 glass panes on the two visible faces, roof sign.
static func _phone_booth(m: Array[Prim]) -> void:
	_bx(m, Vector3(0, 0, 0.015), Vector3(0.16, 0.16, 0.015), "concrete")
	_bx(m, Vector3(0, 0, 0.35), Vector3(0.13, 0.13, 0.32), "p_redbox")
	_bx(m, Vector3(0, 0, 0.66), Vector3(0.15, 0.15, 0.022), "p_redbox")
	_bx(m, Vector3(0, 0, 0.7), Vector3(0.12, 0.12, 0.018), "p_redbox")
	_bx(m, Vector3(0.0, 0.0, 0.72), Vector3(0.08, 0.08, 0.008), "p_redbox")
	_bx(m, Vector3(0.152, 0, 0.665), Vector3(0.004, 0.1, 0.015), "p_litw")  # lit TELEPHONE sign
	_bx(m, Vector3(0, 0.152, 0.665), Vector3(0.1, 0.004, 0.015), "p_litw")
	for ci in 3:
		var u := (float(ci) - 1.0) * 0.082
		for ri in 4:
			var z := 0.25 + 0.1 * float(ri)
			_bx(m, Vector3(0.132, u, z), Vector3(0.004, 0.032, 0.04), "glass")
			_bx(m, Vector3(u, 0.132, z), Vector3(0.032, 0.004, 0.04), "glass")
	_bx(m, Vector3(0.133, 0, 0.1), Vector3(0.004, 0.11, 0.07), "p_redbox")  # solid door base
	_bx(m, Vector3(0.136, 0, 0.1), Vector3(0.003, 0.02, 0.005), "brass")


## Bus shelter, long axis along x: roof on four posts, glass back with an ad, bench, flag sign at the +x end.
static func _bus_stop(m: Array[Prim]) -> void:
	_bx(m, Vector3(0, 0, 0.012), Vector3(0.5, 0.27, 0.012), "concrete")
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			_bx(m, Vector3(0.46 * sx, 0.21 * sy, 0.31), Vector3(0.014, 0.014, 0.3), "p_busgrey")
	_bx(m, Vector3(0, 0, 0.64), Vector3(0.52, 0.26, 0.018), "p_busgrey")
	_bx(m, Vector3(0, 0.262, 0.64), Vector3(0.52, 0.01, 0.03), "p_blue")
	_bx(m, Vector3(0.522, 0, 0.64), Vector3(0.01, 0.26, 0.03), "p_blue")
	_bx(m, Vector3(0, -0.21, 0.34), Vector3(0.45, 0.006, 0.26), "glass")
	for x: float in [-0.15, 0.15]:
		_bx(m, Vector3(x, -0.2, 0.34), Vector3(0.01, 0.01, 0.26), "p_busgrey")
	_bx(m, Vector3(-0.3, -0.198, 0.34), Vector3(0.1, 0.006, 0.17), "p_poster1")
	_bx(m, Vector3(-0.3, -0.19, 0.4), Vector3(0.07, 0.004, 0.05), "p_poster2")
	_bx(m, Vector3(0.28, -0.198, 0.34), Vector3(0.1, 0.006, 0.17), "p_poster3")
	_bx(m, Vector3(0.28, -0.19, 0.3), Vector3(0.07, 0.004, 0.05), "p_poster0")
	_bx(m, Vector3(-0.05, -0.1, 0.17), Vector3(0.32, 0.075, 0.012), "wood")
	_bx(m, Vector3(-0.05, -0.1, 0.1), Vector3(0.3, 0.012, 0.07), "p_busgrey")
	for x: float in [-0.3, 0.2]:
		_bx(m, Vector3(x, -0.1, 0.08), Vector3(0.012, 0.06, 0.08), "p_busgrey")
	_cy(m, Vector3(0.62, 0.12, 0.4), 0.014, 0.4, "p_busgrey")
	_bx(m, Vector3(0.62, 0.12, 0.8), Vector3(0.01, 0.1, 0.1), "p_blue")
	_bx(m, Vector3(0.63, 0.12, 0.8), Vector3(0.006, 0.06, 0.06), "whitep")
	_bx(m, Vector3(0.635, 0.12, 0.8), Vector3(0.004, 0.035, 0.015), "p_blue")
	_cy(m, Vector3(0.62, 0.12, 0.01), 0.04, 0.01, "concrete")


## Cola-red vending machine with a lit product window (front on +x) and a logo disc on the side.
static func _vending(m: Array[Prim]) -> void:
	_bx(m, Vector3(0, 0, 0.02), Vector3(0.14, 0.15, 0.02), "gun")
	_bx(m, Vector3(0, 0, 0.29), Vector3(0.13, 0.14, 0.25), "p_vendred")
	_bx(m, Vector3(0, 0, 0.55), Vector3(0.135, 0.145, 0.014), "gun")
	_bx(m, Vector3(0.132, -0.02, 0.36), Vector3(0.005, 0.095, 0.15), "p_lit")
	var prods: Array[String] = ["red", "p_blue", "p_yellow", "p_poster2", "p_green", "p_poster3"]
	for r in 3:
		for c in 4:
			var mt := prods[(r * 2 + c) % prods.size()]
			_bx(m, Vector3(0.138, -0.02 + (float(c) - 1.5) * 0.045, 0.45 - 0.09 * float(r)), Vector3(0.004, 0.017, 0.028), mt)
		_bx(m, Vector3(0.137, -0.02, 0.405 - 0.09 * float(r)), Vector3(0.003, 0.095, 0.004), "gun")
	_bx(m, Vector3(0.132, 0.105, 0.36), Vector3(0.004, 0.02, 0.15), "gun")  # keypad column
	for r in 4:
		_bx(m, Vector3(0.137, 0.105, 0.44 - 0.06 * float(r)), Vector3(0.003, 0.012, 0.012), "p_litw")
	_bx(m, Vector3(0.132, 0.0, 0.1), Vector3(0.005, 0.1, 0.03), "gun")  # delivery flap
	_bx(m, Vector3(0.136, 0.0, 0.1), Vector3(0.003, 0.08, 0.018), "woodc")
	_bx(m, Vector3(0.0, 0.142, 0.3), Vector3(0.1, 0.004, 0.19), "whitep")  # side panel
	_sp(m, Vector3(0.0, 0.147, 0.32), Vector3(0.065, 0.006, 0.065), "red")
	_bx(m, Vector3(0.0, 0.148, 0.32), Vector3(0.05, 0.004, 0.012), "whitep")


## Fire hydrant: base, barrel, bonnet and three outlets with steel caps.
static func _hydrant(m: Array[Prim]) -> void:
	_cy(m, Vector3(0, 0, 0.02), 0.07, 0.02, "red")
	_cy(m, Vector3(0, 0, 0.14), 0.048, 0.1, "red")
	_cy(m, Vector3(0, 0, 0.1), 0.058, 0.012, "p_chrome")
	_sp(m, Vector3(0, 0, 0.245), Vector3(0.056, 0.056, 0.05), "red")
	_cy(m, Vector3(0, 0, 0.3), 0.02, 0.02, "p_chrome")
	_cyx(m, Vector3(0, 0.075, 0.17), 0.027, 0.04, "red", PI * 0.5)
	_cyx(m, Vector3(0, -0.075, 0.17), 0.027, 0.04, "red", PI * 0.5)
	_cyx(m, Vector3(0, 0.12, 0.17), 0.033, 0.012, "p_chrome", PI * 0.5)
	_cyx(m, Vector3(0, -0.12, 0.17), 0.033, 0.012, "p_chrome", PI * 0.5)
	_cyx(m, Vector3(0.075, 0, 0.15), 0.036, 0.04, "red")
	_cyx(m, Vector3(0.12, 0, 0.15), 0.042, 0.012, "p_chrome")
	_bx(m, Vector3(0.0, 0.0, 0.07), Vector3(0.05, 0.05, 0.004), "p_yellow")


## Billboard on two posts, long axis along x: blank-ish poster with colour blocks, lamps on top.
static func _billboard(m: Array[Prim]) -> void:
	for sx: float in [-1.0, 1.0]:
		_bx(m, Vector3(0.28 * sx, 0, 0.4), Vector3(0.035, 0.035, 0.4), "concrete")
		_bn(m, Vector3(0.28 * sx, 0.0, 0.3), Vector3(0.42 * sx, 0.0, 0.66), 0.014, 0.014, "steel")
		_bx(m, Vector3(0.28 * sx, 0, 0.02), Vector3(0.07, 0.07, 0.02), "concrete")
	_bx(m, Vector3(0, 0, 0.9), Vector3(0.52, 0.026, 0.25), "gun")
	for s: float in [1.0, -1.0]:  # both faces carry a poster (the sw render sees the -y face)
		var fx := s  # the second poster is mirrored along x so the blocks differ
		_bx(m, Vector3(0, 0.03 * s, 0.9), Vector3(0.49, 0.006, 0.22), "p_poster0")
		_bx(m, Vector3(-0.22 * fx, 0.037 * s, 1.0), Vector3(0.24, 0.004, 0.1), "p_poster1" if s > 0.0 else "p_poster3")
		_bx(m, Vector3(0.17 * fx, 0.037 * s, 0.8), Vector3(0.28, 0.004, 0.08), "p_poster2")
		_bx(m, Vector3(0.28 * fx, 0.037 * s, 1.0), Vector3(0.1, 0.004, 0.08), "p_poster3" if s > 0.0 else "p_poster1")
		for i in 3:
			_bx(m, Vector3((-0.3 + 0.08 * float(i)) * fx, 0.038 * s, 0.8), Vector3(0.03, 0.004, 0.012), "gun")
			_bx(m, Vector3((-0.28 + 0.06 * float(i)) * fx, 0.038 * s, 0.74), Vector3(0.02, 0.004, 0.008), "gun")
	_bx(m, Vector3(0, 0.05, 0.64), Vector3(0.52, 0.06, 0.008), "steel")  # catwalk
	for i in 3:
		var x := -0.3 + 0.3 * float(i)
		_bn(m, Vector3(x, 0.03, 1.15), Vector3(x, 0.14, 1.22), 0.01, 0.01, "steel")
		_bx(m, Vector3(x, 0.14, 1.23), Vector3(0.035, 0.022, 0.014), "gun")
		_bx(m, Vector3(x, 0.15, 1.22), Vector3(0.028, 0.012, 0.006), "p_litw")


## One traffic-signal head: dark body, yellow back plate (optional), three lenses on the +y or +x face, lens `lit` glows.
static func _tl_head(m: Array[Prim], c: Vector3, on_y: bool, lit: int, plate: bool) -> void:
	var g: Array[Prim] = []
	_bx(g, Vector3.ZERO, Vector3(0.04, 0.04, 0.105), "gun")
	var on := ["p_lred", "p_lamberoff", "p_lgreen"]
	var off := ["p_lred", "p_lamberoff", "p_lgreenoff"]
	var lens: Array[String] = []
	for i in 3:
		lens.append(on[i] if i == lit else (off[i] if i != 0 else "p_lamberoff"))
	if plate:
		_bx(g, Vector3(0, -0.032, 0), Vector3(0.056, 0.008, 0.12), "p_yellow")
	for i in 3:
		var z := 0.065 - 0.065 * float(i)
		_bx(g, Vector3(0, 0.043, z), Vector3(0.026, 0.004, 0.026), lens[i])
		_bx(g, Vector3(0, 0.054, z + 0.03), Vector3(0.034, 0.018, 0.006), "gun")
	if not on_y:
		Base._xform_about(g, Vector3.ZERO, Basis(Vector3(0, 0, 1), -PI * 0.5), Vector3.ZERO)
	for p in g:
		p.c += c
	m.append_array(g)


## Signal pole with a mast arm and two heads (red lit on the arm, green on the pole).
static func _traffic_light(m: Array[Prim]) -> void:
	_cy(m, Vector3(0, 0, 0.03), 0.055, 0.03, "concrete")
	_cy(m, Vector3(0, 0, 0.45), 0.024, 0.45, "p_busgrey")
	_cy(m, Vector3(0, 0, 0.1), 0.032, 0.05, "p_busgrey")
	_bn(m, Vector3(0, 0, 0.88), Vector3(0.32, 0, 0.93), 0.014, 0.014, "p_busgrey")
	_bn(m, Vector3(0, 0, 0.7), Vector3(0.2, 0, 0.9), 0.01, 0.01, "p_busgrey")
	_bx(m, Vector3(0, 0, 0.9), Vector3(0.03, 0.03, 0.03), "p_busgrey")
	_cy(m, Vector3(0.3, 0, 0.9), 0.012, 0.03, "p_busgrey")
	_tl_head(m, Vector3(0.3, 0, 0.77), true, 0, true)
	_tl_head(m, Vector3(0.038, 0, 0.52), false, 2, false)
	_bx(m, Vector3(0.03, 0.0, 0.3), Vector3(0.014, 0.03, 0.05), "gun")  # pedestrian push button box
	_bx(m, Vector3(0.045, 0.0, 0.31), Vector3(0.004, 0.02, 0.02), "p_yellow")


## Wooden utility pole, cross-arms along y: insulators, braces, a cable stub hanging off each end.
static func _power_pole(m: Array[Prim]) -> void:
	_cy(m, Vector3(0, 0, 0.035), 0.045, 0.035, "p_utilpole")
	_cy(m, Vector3(0, 0, 0.7), 0.028, 0.7, "p_utilpole")
	_bx(m, Vector3(0, 0, 1.27), Vector3(0.026, 0.3, 0.022), "woodd")
	_bx(m, Vector3(0, 0, 1.05), Vector3(0.026, 0.2, 0.02), "woodd")
	for sy: float in [-1.0, 1.0]:
		_bn(m, Vector3(0, 0, 1.12), Vector3(0, 0.24 * sy, 1.26), 0.012, 0.012, "woodd")
	for y: float in [-0.26, 0.0, 0.26]:
		_cy(m, Vector3(0, y, 1.325), 0.018, 0.026, "p_insul")
		_sp(m, Vector3(0, y, 1.355), Vector3(0.02, 0.02, 0.014), "p_insul")
	for y: float in [-0.17, 0.17]:
		_cy(m, Vector3(0, y, 1.1), 0.016, 0.022, "p_insul")
	_bn(m, Vector3(0, 0.26, 1.36), Vector3(0, 0.37, 1.25), 0.012, 0.012, "gun")
	_bn(m, Vector3(0, 0.37, 1.25), Vector3(0, 0.42, 1.02), 0.012, 0.012, "gun")
	_bn(m, Vector3(0, -0.26, 1.36), Vector3(0, -0.34, 1.28), 0.012, 0.012, "gun")
	_bn(m, Vector3(0, 0.0, 1.36), Vector3(0.0, 0.0, 1.45), 0.012, 0.012, "gun")
	_bx(m, Vector3(0.03, 0, 0.9), Vector3(0.006, 0.03, 0.04), "p_yellow")  # pole tag
	for i in 4:
		_bx(m, Vector3(0.034, 0.0, 0.3 + 0.12 * float(i)), Vector3(0.008, 0.012, 0.006), "steel")  # climbing steps
	_bx(m, Vector3(0, -0.05, 0.62), Vector3(0.05, 0.003, 0.05), "whitep")


## Pad-mounted transformer: green cabinet, bushings on top, radiator fins on the +y side, warning plate.
static func _transformer(m: Array[Prim]) -> void:
	_bx(m, Vector3(0, 0, 0.025), Vector3(0.32, 0.28, 0.025), "concrete")
	_bx(m, Vector3(0, 0, 0.26), Vector3(0.17, 0.14, 0.2), "p_utilgreen")
	_bx(m, Vector3(0, 0, 0.47), Vector3(0.18, 0.15, 0.014), "p_greend")
	for i in 5:
		_bx(m, Vector3(-0.1 + 0.05 * float(i), 0.17, 0.27), Vector3(0.018, 0.026, 0.17), "p_utilgreen")
	_bx(m, Vector3(0.0, 0.15, 0.27), Vector3(0.12, 0.012, 0.18), "p_greend")
	for x: float in [-0.08, 0.0, 0.08]:
		_cy(m, Vector3(x, -0.04, 0.52), 0.022, 0.04, "p_insul")
		_sp(m, Vector3(x, -0.04, 0.565), Vector3(0.022, 0.022, 0.016), "p_insul")
	_bx(m, Vector3(0.172, 0, 0.28), Vector3(0.005, 0.1, 0.12), "p_greend")  # door
	_bx(m, Vector3(0.176, 0, 0.3), Vector3(0.004, 0.05, 0.035), "p_yellow")  # warning plate
	_bx(m, Vector3(0.178, 0, 0.3), Vector3(0.003, 0.03, 0.006), "gun")
	_bx(m, Vector3(0.176, 0.06, 0.17), Vector3(0.004, 0.012, 0.02), "steel")  # padlock hasp
	_cy(m, Vector3(-0.14, -0.2, 0.25), 0.02, 0.25, "steel")  # conduit
	_bn(m, Vector3(-0.14, -0.2, 0.5), Vector3(-0.1, -0.1, 0.52), 0.015, 0.015, "steel")


## Condenser unit on a pad: round fan grille on the front, louvres on the side, copper pipes, controller conduit.
static func _ac_unit(m: Array[Prim]) -> void:
	_bx(m, Vector3(0, 0, 0.02), Vector3(0.26, 0.2, 0.02), "concrete")
	_bx(m, Vector3(0, 0, 0.16), Vector3(0.18, 0.13, 0.12), "whitep")
	_bx(m, Vector3(0, 0, 0.285), Vector3(0.19, 0.14, 0.012), "steel")
	_cyx(m, Vector3(0.18, 0, 0.17), 0.09, 0.006, "gun")
	_cyx(m, Vector3(0.186, 0, 0.17), 0.05, 0.003, "steel")
	_cyx(m, Vector3(0.19, 0, 0.17), 0.016, 0.003, "gun")
	for a in 4:
		var t := PI * 0.25 * float(a)
		_bn(m, Vector3(0.186, cos(t) * 0.09, 0.17 + sin(t) * 0.09), Vector3(0.186, -cos(t) * 0.09, 0.17 - sin(t) * 0.09), 0.004, 0.004, "steel")
	for i in 7:
		_bx(m, Vector3(-0.02, 0.132, 0.07 + 0.03 * float(i)), Vector3(0.13, 0.004, 0.008), "steel")
	_bx(m, Vector3(-0.13, 0.13, 0.12), Vector3(0.03, 0.006, 0.07), "plasterw")
	_bn(m, Vector3(-0.08, 0.14, 0.04), Vector3(-0.08, 0.24, 0.04), 0.01, 0.01, "brass")
	_bn(m, Vector3(-0.05, 0.14, 0.05), Vector3(-0.05, 0.24, 0.05), 0.014, 0.014, "whitep")
	_bn(m, Vector3(-0.08, 0.24, 0.04), Vector3(-0.08, 0.24, 0.3), 0.01, 0.01, "brass")
	_bn(m, Vector3(-0.05, 0.24, 0.05), Vector3(-0.05, 0.24, 0.3), 0.014, 0.014, "whitep")
	for sx: float in [-1.0, 1.0]:
		_bx(m, Vector3(0.12 * sx, 0, 0.05), Vector3(0.03, 0.14, 0.012), "gun")


## Satellite dish on a tripod mast: tilted dish with a lighter inner face, feed arm and horn.
static func _dish(m: Array[Prim]) -> void:
	for a in 3:
		var t := TAU * float(a) / 3.0 + 0.5
		_bn(m, Vector3(cos(t) * 0.17, sin(t) * 0.17, 0.0), Vector3(0, 0, 0.24), 0.014, 0.014, "steel")
	_cy(m, Vector3(0, 0, 0.04), 0.03, 0.04, "concrete")
	_cy(m, Vector3(0, 0, 0.3), 0.022, 0.26, "p_chrome")
	var th := 0.85
	var n := Vector3(sin(th), 0, cos(th))
	var dc := Vector3(0.0, 0, 0.62)
	m.append(Prim.new(Base.SPH, dc, Vector3(0.2, 0.2, 0.04), "whitep", 0.0, 0.0, th))
	m.append(Prim.new(Base.SPH, dc + n * 0.016, Vector3(0.18, 0.18, 0.034), "p_poster0", 0.0, 0.0, th))
	_bn(m, Vector3(0, 0, 0.52), dc - n * 0.03, 0.02, 0.02, "steel")
	_bn(m, dc + n * 0.02, dc + n * 0.26, 0.008, 0.008, "steel")
	_bx(m, dc + n * 0.27, Vector3(0.02, 0.02, 0.02), "gun")
	_bn(m, dc + Vector3(0, 0.19, 0) + n * 0.01, dc + n * 0.26, 0.006, 0.006, "steel")
	_bn(m, dc + Vector3(0, -0.19, 0) + n * 0.01, dc + n * 0.26, 0.006, 0.006, "steel")


## One wheelie bin facing +x: stepped body, lid with front lip, rear wheels, label.
static func _bin(m: Array[Prim], c: Vector3, yaw: float, body: String, lid: String) -> void:
	var g: Array[Prim] = []
	_bx(g, Vector3(0, 0, 0.07), Vector3(0.078, 0.07, 0.07), body)
	_bx(g, Vector3(0, 0, 0.19), Vector3(0.088, 0.08, 0.052), body)
	_bx(g, Vector3(0, 0, 0.28), Vector3(0.096, 0.09, 0.042), body)
	_bx(g, Vector3(0, 0, 0.325), Vector3(0.103, 0.097, 0.012), lid)
	_bx(g, Vector3(0.1, 0, 0.31), Vector3(0.012, 0.09, 0.02), lid)
	_bx(g, Vector3(-0.1, 0, 0.345), Vector3(0.01, 0.07, 0.008), lid)  # hinge handle
	_bx(g, Vector3(0.097, 0, 0.22), Vector3(0.004, 0.045, 0.05), "whitep")
	_bx(g, Vector3(0.1, 0, 0.23), Vector3(0.003, 0.03, 0.012), "gun")
	_bx(g, Vector3(0.1, 0, 0.2), Vector3(0.003, 0.025, 0.006), "gun")
	for s: float in [-1.0, 1.0]:
		_sp(g, Vector3(-0.07, 0.085 * s, 0.04), Vector3(0.04, 0.012, 0.04), "track")
	_put(m, g, yaw, c)


static func _bins(m: Array[Prim]) -> void:
	_bin(m, Vector3(0.0, 0.12, 0.0), 0.05, "p_green", "p_greend")
	_bin(m, Vector3(0.05, -0.14, 0.0), -0.3, "p_greend", "p_yellow")


## Wire shopping cart standing upright: flared basket of crossed wire rods (thin boxes), rim bars, handle with a red grip,
## a hinged child-seat flap at the back, a base frame and four small wheels (an abandoned cart).
static func _cart(m: Array[Prim]) -> void:
	var g: Array[Prim] = []
	var w := 0.012  # wire half thickness
	var r := 0.013  # rim / frame half thickness
	var bz := 0.15  # basket floor
	var tz := 0.3  # basket rim
	# basket corners: bottom (x, y) and the wider top
	var b00 := Vector3(-0.15, -0.105, bz)  # back, -y
	var b10 := Vector3(0.17, -0.105, bz)  # front, -y
	var b01 := Vector3(-0.15, 0.105, bz)
	var b11 := Vector3(0.17, 0.105, bz)
	var t00 := Vector3(-0.2, -0.15, tz)
	var t10 := Vector3(0.26, -0.15, tz)
	var t01 := Vector3(-0.2, 0.15, tz)
	var t11 := Vector3(0.26, 0.15, tz)
	_mesh(g, b01, b11, t01, t11, 6, 2, w)  # +y side
	_mesh(g, b00, b10, t00, t10, 6, 2, w)  # -y side
	_mesh(g, b10, b11, t10, t11, 3, 2, w)  # front
	_mesh(g, b00, b01, t00, t01, 3, 2, w)  # back
	_mesh(g, b00, b10, b01, b11, 4, 3, w)  # floor
	for pr: Array in [[t00, t10], [t01, t11], [t00, t01], [t10, t11]]:  # rim
		_bn(g, pr[0], pr[1], r, r, "p_chrome")
	# dark liner just inside the far walls and floor, so the gaps in the wire read as gaps
	_bx(g, Vector3(0.01, 0.0, bz + 0.004), Vector3(0.15, 0.1, 0.004), "p_conebase")
	for j in 3:
		var t: float = (0.025 + 0.05 * float(j)) / 0.15
		var zc: float = bz + 0.025 + 0.05 * float(j)
		_bn(g, Vector3(-0.15 - 0.05 * t + 0.01, -0.105 - 0.045 * t + 0.006, zc), Vector3(0.17 + 0.09 * t - 0.01, -0.105 - 0.045 * t + 0.006, zc), 0.003, 0.028, "p_conebase")
		_bn(g, Vector3(-0.15 - 0.05 * t + 0.006, -0.105 - 0.045 * t + 0.01, zc), Vector3(-0.15 - 0.05 * t + 0.006, 0.105 + 0.045 * t - 0.01, zc), 0.003, 0.028, "p_conebase")
	# base frame and wheels
	var wx: Array = [-0.12, 0.15]
	for sy: float in [-1.0, 1.0]:
		_bn(g, Vector3(wx[0], 0.1 * sy, 0.075), Vector3(wx[1], 0.1 * sy, 0.075), r, r, "steel")
		for x: float in wx:
			_bn(g, Vector3(x, 0.1 * sy, bz), Vector3(x, 0.1 * sy, 0.075), r, r, "steel")
			_sp(g, Vector3(x, 0.115 * sy, 0.042), Vector3(0.042, 0.014, 0.042), "p_conebase")
			_sp(g, Vector3(x, 0.115 * sy, 0.042), Vector3(0.02, 0.016, 0.02), "p_chrome")
	_bn(g, Vector3(wx[0], -0.1, 0.075), Vector3(wx[0], 0.1, 0.075), r, r, "steel")
	_bn(g, Vector3(wx[1], -0.1, 0.075), Vector3(wx[1], 0.1, 0.075), r, r, "steel")
	# handle: two posts rising from the back rim, grip across the top
	for sy: float in [-1.0, 1.0]:
		_bn(g, Vector3(-0.2, 0.15 * sy, tz), Vector3(-0.3, 0.14 * sy, 0.42), r, r, "p_chrome")
	_bn(g, Vector3(-0.3, -0.14, 0.42), Vector3(-0.3, 0.14, 0.42), r, r, "p_chrome")
	_bx(g, Vector3(-0.3, 0, 0.42), Vector3(0.02, 0.1, 0.02), "red")  # grip
	# child-seat flap folded down inside the back, with a plastic seat
	var flap := Prim.new(Base.BOX, Vector3(-0.16, 0, 0.25), Vector3(0.006, 0.12, 0.055), "p_chrome")
	flap.basis = Basis(Vector3(0, 1, 0), 0.5)
	g.append(flap)
	var seat := Prim.new(Base.BOX, Vector3(-0.145, 0, 0.215), Vector3(0.055, 0.1, 0.007), "p_blue")
	seat.basis = Basis(Vector3(0, 1, 0), -0.35)
	g.append(seat)
	Base._xform_about(g, Vector3.ZERO, Basis(Vector3(0, 0, 1), 0.5), Vector3(0, 0, -_lowest(g)))
	m.append_array(g)


## Wire mesh over a quad: p00-p10 is the bottom edge, p01-p11 the top edge; `nu` vertical rods and `nv` crossing rails.
static func _mesh(m: Array[Prim], p00: Vector3, p10: Vector3, p01: Vector3, p11: Vector3, nu: int, nv: int, w: float) -> void:
	for i in nu + 1:
		var t := float(i) / float(nu)
		_bn(m, p00.lerp(p10, t), p01.lerp(p11, t), w, w, "p_chrome")
	for j in nv + 1:
		var t := float(j) / float(nv)
		_bn(m, p00.lerp(p01, t), p10.lerp(p11, t), w, w, "p_chrome")


## One fuel pump: red body, white display head with a screen on the +y face, hose and holster on the +x face.
static func _pump(m: Array[Prim], c: Vector3) -> void:
	var g: Array[Prim] = []
	_bx(g, Vector3(0, 0, 0.15), Vector3(0.075, 0.06, 0.12), "red")
	_bx(g, Vector3(0, 0, 0.065), Vector3(0.082, 0.066, 0.008), "gun")
	_bx(g, Vector3(0, 0, 0.32), Vector3(0.08, 0.064, 0.062), "whitep")
	_bx(g, Vector3(0, 0, 0.395), Vector3(0.086, 0.07, 0.016), "red")
	_bx(g, Vector3(0, 0.066, 0.335), Vector3(0.05, 0.004, 0.026), "glass")  # screen
	_bx(g, Vector3(0, 0.066, 0.287), Vector3(0.05, 0.004, 0.008), "p_yellow")
	_bx(g, Vector3(0, -0.066, 0.335), Vector3(0.05, 0.004, 0.026), "glass")  # screen on the far face too
	_bx(g, Vector3(0, -0.066, 0.287), Vector3(0.05, 0.004, 0.008), "p_yellow")
	_bx(g, Vector3(0, -0.063, 0.18), Vector3(0.05, 0.004, 0.04), "gun")
	_bx(g, Vector3(0, 0.063, 0.18), Vector3(0.05, 0.004, 0.04), "gun")  # nozzle bay
	_bx(g, Vector3(0, 0.065, 0.15), Vector3(0.04, 0.004, 0.012), "p_yellow")
	_bx(g, Vector3(0.078, 0, 0.32), Vector3(0.004, 0.05, 0.03), "p_yellow")  # side stripe
	_bn(g, Vector3(0.076, 0.0, 0.29), Vector3(0.12, 0.03, 0.2), 0.012, 0.012, "gun")  # hose
	_bn(g, Vector3(0.12, 0.03, 0.2), Vector3(0.1, 0.04, 0.1), 0.012, 0.012, "gun")
	_bn(g, Vector3(0.1, 0.04, 0.1), Vector3(0.15, 0.05, 0.14), 0.014, 0.014, "steel")
	_bx(g, Vector3(0.078, 0.0, 0.18), Vector3(0.006, 0.03, 0.03), "gun")
	for p in g:
		p.c += c
	m.append_array(g)


## Two fuel pumps on a kerbed concrete island, long axis along x, yellow bollards at the ends.
static func _petrol(m: Array[Prim]) -> void:
	_bx(m, Vector3(0, 0, 0.03), Vector3(0.4, 0.15, 0.03), "concretel")
	for sx: float in [-1.0, 1.0]:
		_bx(m, Vector3(0.4 * sx, 0, 0.03), Vector3(0.012, 0.15, 0.033), "p_yellow")
		_cy(m, Vector3(0.34 * sx, 0.08, 0.1), 0.025, 0.07, "p_yellow")
		_cy(m, Vector3(0.34 * sx, 0.08, 0.17), 0.027, 0.01, "gun")
	_bx(m, Vector3(0, 0.152, 0.03), Vector3(0.4, 0.012, 0.033), "p_yellow")
	_pump(m, Vector3(-0.17, -0.02, 0.06))
	_pump(m, Vector3(0.17, -0.02, 0.06))


## Round stone fountain: octagonal rim, water, tiered pedestal with two bowls and jets.
static func _fountain(m: Array[Prim]) -> void:
	_cy(m, Vector3(0, 0, 0.02), 0.56, 0.02, "stone")
	_ring(m, Vector3(0, 0, 0.1), 0.5, 12, 0.055, 0.085, "stonel", "concretel")
	_cy(m, Vector3(0, 0, 0.07), 0.46, 0.05, "p_water")
	_cy(m, Vector3(0, 0, 0.18), 0.09, 0.15, "stone")
	_cy(m, Vector3(0, 0, 0.35), 0.21, 0.025, "stonel")
	_cy(m, Vector3(0, 0, 0.385), 0.18, 0.012, "p_water")
	_cy(m, Vector3(0, 0, 0.5), 0.045, 0.1, "stone")
	_cy(m, Vector3(0, 0, 0.62), 0.12, 0.02, "stonel")
	_cy(m, Vector3(0, 0, 0.645), 0.1, 0.01, "p_water")
	_cy(m, Vector3(0, 0, 0.74), 0.016, 0.1, "p_water")
	_sp(m, Vector3(0, 0, 0.85), Vector3(0.03, 0.03, 0.03), "p_water")
	for a in 6:
		var t := TAU * float(a) / 6.0 + 0.3
		_bn(m, Vector3(cos(t) * 0.2, sin(t) * 0.2, 0.37), Vector3(cos(t) * 0.38, sin(t) * 0.38, 0.14), 0.014, 0.014, "p_water")
	for a in 4:
		var t := TAU * float(a) / 4.0 + 0.8
		_bn(m, Vector3(cos(t) * 0.1, sin(t) * 0.1, 0.65), Vector3(cos(t) * 0.18, sin(t) * 0.18, 0.4), 0.012, 0.012, "p_water")


## One headstone facing +x: slab, rounded top, a carved cross and text lines.
static func _stone(m: Array[Prim], c: Vector3, h: Vector3, yaw: float, mat: String) -> void:
	var g: Array[Prim] = []
	_bx(g, Vector3(0, 0, h.z * 0.5), Vector3(h.x * 1.4, h.y * 1.25, h.z * 0.04), "stone")
	_bx(g, Vector3(0, 0, h.z * 0.5 + 0.03), Vector3(h.x, h.y, h.z * 0.5), mat)
	_sp(g, Vector3(0, 0, h.z + 0.03), Vector3(h.x, h.y, h.y * 0.9), mat)
	_bx(g, Vector3(h.x + 0.003, 0, h.z * 0.8), Vector3(0.003, h.y * 0.12, h.z * 0.14), "stone")
	_bx(g, Vector3(h.x + 0.003, 0, h.z * 0.85), Vector3(0.003, h.y * 0.4, h.z * 0.04), "stone")
	_bx(g, Vector3(h.x + 0.003, 0, h.z * 0.45), Vector3(0.003, h.y * 0.55, 0.005), "stone")
	_bx(g, Vector3(h.x + 0.003, 0, h.z * 0.33), Vector3(0.003, h.y * 0.4, 0.005), "stone")
	_put(m, g, yaw, c)


static func _graves(m: Array[Prim]) -> void:
	_stone(m, Vector3(-0.1, -0.12, 0.0), Vector3(0.018, 0.07, 0.2), 0.1, "stonel")
	_stone(m, Vector3(0.1, 0.1, 0.0), Vector3(0.018, 0.065, 0.15), -0.15, "stone")
	_stone(m, Vector3(-0.14, 0.14, 0.0), Vector3(0.018, 0.06, 0.24), 0.05, "concretel")
	_bx(m, Vector3(0.2, -0.12, 0.2), Vector3(0.024, 0.024, 0.2), "stonel", 0.1)  # stone cross
	_bx(m, Vector3(0.2, -0.12, 0.28), Vector3(0.024, 0.085, 0.026), "stonel", 0.1)
	_bx(m, Vector3(0.2, -0.12, 0.03), Vector3(0.07, 0.07, 0.03), "stone", 0.1)
	_sp(m, Vector3(0.12, 0.1, 0.02), Vector3(0.14, 0.09, 0.04), "leafd")  # grave mounds
	_sp(m, Vector3(-0.06, -0.1, 0.02), Vector3(0.16, 0.09, 0.04), "leafd")
	_sp(m, Vector3(-0.02, 0.14, 0.02), Vector3(0.12, 0.08, 0.04), "leaf")
	_sp(m, Vector3(0.16, 0.2, 0.05), Vector3(0.016, 0.016, 0.016), "red")  # flowers
	_sp(m, Vector3(-0.2, 0.0, 0.045), Vector3(0.016, 0.016, 0.016), "p_yellow")
	_sp(m, Vector3(0.0, 0.0, 0.045), Vector3(0.016, 0.016, 0.016), "whitep")


## Picnic table, long axis along x: three table boards, two benches, A-frame ends.
static func _picnic(m: Array[Prim]) -> void:
	for y: float in [-0.12, 0.0, 0.12]:
		_bx(m, Vector3(0, y, 0.275), Vector3(0.33, 0.053, 0.012), "wood")
	for sy: float in [-1.0, 1.0]:
		_bx(m, Vector3(0, 0.235 * sy, 0.16), Vector3(0.33, 0.05, 0.012), "woodd")
		for sx: float in [-1.0, 1.0]:
			_bn(m, Vector3(0.22 * sx, 0.31 * sy, 0.0), Vector3(0.22 * sx, 0.1 * sy, 0.27), 0.016, 0.016, "woodd")
	for sx: float in [-1.0, 1.0]:
		_bx(m, Vector3(0.22 * sx, 0, 0.245), Vector3(0.016, 0.12, 0.014), "woodd")
	_bx(m, Vector3(0.02, 0.0, 0.287), Vector3(0.012, 0.012, 0.012), "p_poster2")
	_cy(m, Vector3(-0.1, 0.05, 0.3), 0.016, 0.012, "red")


## A-frame swing set, bar along x, two swings on chains (one pulled forward).
static func _swings(m: Array[Prim]) -> void:
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			_bn(m, Vector3(0.33 * sx, 0.22 * sy, 0.0), Vector3(0.33 * sx, 0.0, 0.72), 0.018, 0.018, "p_blue")
		_bx(m, Vector3(0.33 * sx, 0, 0.3), Vector3(0.012, 0.11, 0.012), "p_blue")
	_bx(m, Vector3(0, 0, 0.73), Vector3(0.38, 0.02, 0.02), "red")
	var seats: Array[Vector3] = [Vector3(-0.12, 0.0, 0.2), Vector3(0.12, 0.12, 0.24)]
	for st in seats:
		for sx: float in [-1.0, 1.0]:
			_bn(m, Vector3(st.x + 0.045 * sx, 0, 0.72), Vector3(st.x + 0.045 * sx, st.y, st.z), 0.008, 0.008, "p_chrome")
		_bx(m, Vector3(st.x, st.y, st.z - 0.01), Vector3(0.065, 0.03, 0.012), "woodd")
		_bx(m, Vector3(st.x, st.y, st.z - 0.002), Vector3(0.06, 0.026, 0.004), "p_yellow")
	_cy(m, Vector3(0.33, 0.22, 0.01), 0.03, 0.01, "concrete")
	_cy(m, Vector3(-0.33, -0.22, 0.01), 0.03, 0.01, "concrete")
	_cy(m, Vector3(0.33, -0.22, 0.01), 0.03, 0.01, "concrete")
	_cy(m, Vector3(-0.33, 0.22, 0.01), 0.03, 0.01, "concrete")


## Round bale lying on its side (axis along x, concentric rings on the face) plus two stacked square bales.
static func _hay(m: Array[Prim]) -> void:
	_cyx(m, Vector3(0.0, 0.14, 0.17), 0.17, 0.15, "p_hay", 0.1)
	for ring in 3:
		var r := 0.13 - 0.045 * float(ring)
		var g: Array[Prim] = []
		_cyx(g, Vector3(0.153, 0, 0), r, 0.003, "p_hayd" if ring % 2 == 0 else "p_hay")
		Base._xform_about(g, Vector3.ZERO, Basis(Vector3(0, 0, 1), 0.1), Vector3(0.0, 0.14, 0.17))
		m.append_array(g)
	for x: float in [-0.08, 0.08]:
		var g: Array[Prim] = []
		_cyx(g, Vector3(x, 0, 0), 0.175, 0.008, "p_hayd")
		Base._xform_about(g, Vector3.ZERO, Basis(Vector3(0, 0, 1), 0.1), Vector3(0.0, 0.14, 0.17))
		m.append_array(g)
	var b: Array[Prim] = []
	_bx(b, Vector3(0, 0, 0.085), Vector3(0.16, 0.1, 0.085), "p_hay")
	for x: float in [-0.08, 0.08]:
		_bx(b, Vector3(x, 0, 0.085), Vector3(0.008, 0.103, 0.088), "p_hayd")
		_bx(b, Vector3(x, 0, 0.085), Vector3(0.01, 0.1, 0.087), "p_hayd")
	for x: float in [-0.12, 0.0, 0.12]:
		_bx(b, Vector3(x, 0.0, 0.171), Vector3(0.012, 0.1, 0.003), "p_hayd")
	_bx(b, Vector3(0.161, 0, 0.085), Vector3(0.003, 0.09, 0.075), "p_hayd")
	_put(m, b, -0.1, Vector3(0.0, -0.22, 0.0))
	var c: Array[Prim] = []
	_bx(c, Vector3(0, 0, 0.255), Vector3(0.15, 0.095, 0.08), "p_hay")
	for x: float in [-0.07, 0.07]:
		_bx(c, Vector3(x, 0, 0.255), Vector3(0.009, 0.097, 0.082), "p_hayd")
	_put(m, c, 0.25, Vector3(0.0, -0.22, 0.0))


## Stone well: ring wall with a dark pit, two posts, cross beam with a crank, small shingle roof, bucket on a rope.
static func _well(m: Array[Prim]) -> void:
	_cy(m, Vector3(0, 0, 0.012), 0.27, 0.012, "dirt")
	_ring(m, Vector3(0, 0, 0.095), 0.19, 10, 0.05, 0.085, "stone", "stonel")
	_cy(m, Vector3(0, 0, 0.12), 0.16, 0.01, "gun")
	for sy: float in [-1.0, 1.0]:
		_bx(m, Vector3(0, 0.25 * sy, 0.3), Vector3(0.02, 0.02, 0.3), "woodd")
	_bx(m, Vector3(0, 0, 0.4), Vector3(0.018, 0.27, 0.018), "wood")
	Base._gable(m, Vector3(0, 0, 0), 0.15, 0.27, 0.55, 0.13, "p_utilpole", "wood")
	_bn(m, Vector3(0, 0.0, 0.4), Vector3(0, 0, 0.3), 0.007, 0.007, "p_rope")
	_cy(m, Vector3(0, 0, 0.255), 0.04, 0.036, "woodd")
	_cy(m, Vector3(0, 0, 0.235), 0.044, 0.006, "steel")
	_cy(m, Vector3(0, 0, 0.275), 0.044, 0.006, "steel")
	_bn(m, Vector3(0, 0.27, 0.4), Vector3(0.0, 0.34, 0.4), 0.012, 0.012, "woodd")
	_bn(m, Vector3(0, 0.34, 0.4), Vector3(0.0, 0.34, 0.31), 0.012, 0.012, "woodd")


## Scarecrow on a cross post: burlap head, wide-brim hat, plaid shirt, straw cuffs, a crow on one arm.
static func _scarecrow(m: Array[Prim]) -> void:
	_bx(m, Vector3(0, 0, 0.36), Vector3(0.016, 0.016, 0.36), "woodd")
	_cy(m, Vector3(0, 0, 0.012), 0.05, 0.012, "dirt")
	for s: float in [-1.0, 1.0]:
		_bx(m, Vector3(0, 0.032 * s, 0.31), Vector3(0.028, 0.026, 0.095), "pants")
		_bx(m, Vector3(0, 0.032 * s, 0.205), Vector3(0.03, 0.028, 0.02), "p_hay")
	_bx(m, Vector3(0, 0, 0.5), Vector3(0.05, 0.085, 0.105), "rshirt")
	_bx(m, Vector3(0.051, 0, 0.52), Vector3(0.002, 0.06, 0.012), "rshirt")
	_bx(m, Vector3(0, 0, 0.56), Vector3(0.06, 0.012, 0.012), "shirt")
	_bx(m, Vector3(0, 0, 0.56), Vector3(0.012, 0.09, 0.012), "shirt")
	_bx(m, Vector3(0, 0, 0.62), Vector3(0.016, 0.3, 0.014), "woodd")
	for s: float in [-1.0, 1.0]:
		_bx(m, Vector3(0, 0.19 * s, 0.6), Vector3(0.026, 0.12, 0.034), "rshirt")
		for i in 4:
			var d := (float(i) - 1.5) * 0.02
			_bn(m, Vector3(0.0, 0.3 * s, 0.6), Vector3(d, 0.38 * s, 0.6 + d * 1.5), 0.008, 0.008, "p_hay")
	_sp(m, Vector3(0, 0, 0.7), Vector3(0.06, 0.058, 0.064), "p_burlap")
	for s: float in [-1.0, 1.0]:
		_bx(m, Vector3(0.056, 0.026 * s, 0.71), Vector3(0.006, 0.01, 0.01), "gun")
	_bx(m, Vector3(0.058, 0, 0.665), Vector3(0.004, 0.03, 0.004), "gun")
	_cy(m, Vector3(0, 0, 0.76), 0.1, 0.008, "woodd")
	_cy(m, Vector3(0, 0, 0.805), 0.056, 0.04, "bark")
	_cy(m, Vector3(0, 0, 0.775), 0.058, 0.008, "red")
	for i in 3:
		_bn(m, Vector3(0.0, 0.0, 0.66), Vector3(0.05, (float(i) - 1.0) * 0.04, 0.63), 0.008, 0.008, "p_hay")
	_sp(m, Vector3(0.0, -0.32, 0.66), Vector3(0.036, 0.022, 0.03), "gun")  # crow
	_bx(m, Vector3(0.04, -0.32, 0.66), Vector3(0.014, 0.008, 0.008), "p_yellow")
	_bn(m, Vector3(-0.02, -0.32, 0.66), Vector3(-0.08, -0.32, 0.64), 0.014, 0.01, "gun")


static func _tarp_z(p: Vector2) -> float:
	var q := (p.x + 0.05) / 0.29
	var r := p.y / 0.22
	return 0.1 + 0.13 * sqrt(maxf(0.0, 1.0 - q * q - r * r)) + 0.012


## Blue tarp thrown over a lumpy load: ridges, hem flaps, rope and weights.
static func _tarp(m: Array[Prim]) -> void:
	_bx(m, Vector3(-0.05, 0.0, 0.05), Vector3(0.2, 0.15, 0.05), "woodd")
	_sp(m, Vector3(-0.05, 0.0, 0.1), Vector3(0.29, 0.22, 0.13), "p_tarp")
	_sp(m, Vector3(0.17, 0.08, 0.08), Vector3(0.16, 0.14, 0.08), "p_tarp")
	_sp(m, Vector3(-0.12, -0.02, 0.16), Vector3(0.14, 0.12, 0.08), "p_tarpd")
	_sp(m, Vector3(0.0, 0.0, 0.2), Vector3(0.1, 0.09, 0.05), "p_tarp")
	var ridges: Array = [[Vector2(-0.3, 0.02), Vector2(-0.12, -0.01), Vector2(0.1, 0.0), Vector2(0.3, 0.08)], [Vector2(-0.2, 0.16), Vector2(-0.1, 0.07), Vector2(0.0, 0.02)], [Vector2(-0.2, -0.17), Vector2(-0.12, -0.08), Vector2(-0.05, -0.02)]]
	for rd in ridges:  # creases following the lumpy surface
		for i in rd.size() - 1:
			var p0: Vector2 = rd[i]
			var p1: Vector2 = rd[i + 1]
			_bn(m, Vector3(p0.x, p0.y, _tarp_z(p0)), Vector3(p1.x, p1.y, _tarp_z(p1)), 0.016, 0.014, "p_tarpd" if i % 2 == 0 else "p_tarp")
	for i in 7:
		var a := TAU * float(i) / 7.0 + 0.2
		var r := 0.28 + 0.06 * Base._rnd(i, 5)
		_bx(m, Vector3(cos(a) * r - 0.04, sin(a) * r * 0.78, 0.02), Vector3(0.07, 0.04, 0.02), "p_tarpd" if i % 2 == 0 else "p_tarp", a)
	_bn(m, Vector3(-0.16, 0.22, 0.04), Vector3(0.1, 0.2, 0.05), 0.01, 0.01, "p_poster2")  # rope
	_bn(m, Vector3(0.1, 0.2, 0.05), Vector3(0.26, 0.07, 0.04), 0.01, 0.01, "p_poster2")
	_sp(m, Vector3(-0.16, 0.22, 0.045), Vector3(0.022, 0.022, 0.022), "p_yellow")
	_sp(m, Vector3(0.26, 0.07, 0.04), Vector3(0.022, 0.022, 0.022), "p_yellow")
	_bx(m, Vector3(-0.26, -0.14, 0.05), Vector3(0.05, 0.04, 0.04), "brick", 0.4)  # weight brick
	_bx(m, Vector3(0.1, -0.2, 0.04), Vector3(0.05, 0.04, 0.04), "brick", -0.3)


## Newspaper box: yellow body on a pedestal, window with a paper stack, coin slot, side decal.
static func _news(m: Array[Prim]) -> void:
	_cy(m, Vector3(0, 0, 0.012), 0.08, 0.012, "concrete")
	_cy(m, Vector3(0, 0, 0.1), 0.04, 0.09, "steel")
	_bx(m, Vector3(0, 0, 0.3), Vector3(0.12, 0.105, 0.115), "p_yellow")
	_bx(m, Vector3(0, 0, 0.424), Vector3(0.128, 0.112, 0.01), "gun")
	_bx(m, Vector3(0.119, 0, 0.34), Vector3(0.004, 0.08, 0.065), "glass")
	for i in 4:
		_bx(m, Vector3(0.123, 0.0, 0.29 + 0.027 * float(i)), Vector3(0.002, 0.07, 0.012), "whitep")
		_bx(m, Vector3(0.124, -0.03, 0.29 + 0.027 * float(i)), Vector3(0.002, 0.028, 0.003), "gun")
	_bx(m, Vector3(0.125, 0.0, 0.225), Vector3(0.003, 0.09, 0.03), "red")
	_bx(m, Vector3(0.128, 0.06, 0.225), Vector3(0.003, 0.012, 0.018), "gun")  # coin slot
	_bx(m, Vector3(0.128, -0.02, 0.225), Vector3(0.003, 0.04, 0.006), "gun")
	_bx(m, Vector3(0.0, 0.108, 0.31), Vector3(0.085, 0.004, 0.075), "whitep")  # side decal
	_bx(m, Vector3(0.0, 0.111, 0.335), Vector3(0.065, 0.003, 0.02), "p_blue")
	_bx(m, Vector3(0.0, 0.111, 0.28), Vector3(0.065, 0.003, 0.005), "gun")


## Park statue: stepped stone plinth with bronze plaques and a plain standing figure, one arm raised, a book in the other.
static func _statue(m: Array[Prim]) -> void:
	_bx(m, Vector3(0, 0, 0.03), Vector3(0.2, 0.2, 0.03), "stone")
	_bx(m, Vector3(0, 0, 0.09), Vector3(0.16, 0.16, 0.03), "stonel")
	_bx(m, Vector3(0, 0, 0.17), Vector3(0.115, 0.115, 0.05), "concretel")
	_bx(m, Vector3(0, 0, 0.235), Vector3(0.14, 0.14, 0.015), "stone")
	_bx(m, Vector3(0.118, 0, 0.17), Vector3(0.004, 0.06, 0.03), "p_bronze")
	_bx(m, Vector3(0, 0.118, 0.17), Vector3(0.06, 0.004, 0.03), "p_bronze")
	for s: float in [-1.0, 1.0]:
		_bx(m, Vector3(0.0, 0.038 * s, 0.345), Vector3(0.036, 0.034, 0.095), "p_bronze")
	_bx(m, Vector3(-0.05, 0, 0.52), Vector3(0.03, 0.1, 0.15), "p_bronze")  # cloak
	_bx(m, Vector3(0.0, 0, 0.54), Vector3(0.06, 0.09, 0.1), "p_bronze")
	_bx(m, Vector3(0.0, 0, 0.445), Vector3(0.062, 0.094, 0.012), "p_bronze")
	_sp(m, Vector3(0, 0, 0.7), Vector3(0.056, 0.056, 0.062), "p_bronze")
	_bn(m, Vector3(0, 0.09, 0.6), Vector3(0.1, 0.2, 0.8), 0.026, 0.026, "p_bronze")
	_bn(m, Vector3(0, -0.09, 0.6), Vector3(0.08, -0.12, 0.5), 0.026, 0.026, "p_bronze")
	_bx(m, Vector3(0.1, -0.12, 0.48), Vector3(0.034, 0.045, 0.018), "p_bronze")
	_bx(m, Vector3(0.1, -0.12, 0.5), Vector3(0.03, 0.04, 0.004), "p_litw")


## Wooden cable drum lying on its side (axis along x): two plank flanges, a hub, a wound black cable and a loose end.
static func _drum(m: Array[Prim]) -> void:
	_cyx(m, Vector3(0, 0, 0.24), 0.07, 0.14, "woodd")
	_cyx(m, Vector3(0, 0, 0.24), 0.2, 0.12, "p_cable")
	for i in 5:
		_cyx(m, Vector3(-0.1 + 0.05 * float(i), 0, 0.24), 0.204, 0.004, "gun")
	for s: float in [-1.0, 1.0]:
		_cyx(m, Vector3(0.14 * s, 0, 0.24), 0.24, 0.016, "wood")
	for dz: float in [-0.16, -0.08, 0.0, 0.08, 0.16]:
		var hy := sqrt(maxf(0.0576 - dz * dz, 0.0)) * 0.97
		_bx(m, Vector3(0.158, 0, 0.24 + dz), Vector3(0.004, hy, 0.004), "woodd")
	_bx(m, Vector3(0.158, 0, 0.24), Vector3(0.004, 0.2, 0.012), "woodd")
	_cyx(m, Vector3(0.16, 0, 0.24), 0.035, 0.006, "steel")
	_cyx(m, Vector3(0.166, 0, 0.24), 0.012, 0.004, "gun")
	_bx(m, Vector3(0.158, 0, 0.24), Vector3(0.004, 0.012, 0.2), "woodd")
	_bn(m, Vector3(0.06, 0.0, 0.44), Vector3(0.02, 0.18, 0.3), 0.022, 0.022, "p_cable")
	_bn(m, Vector3(0.02, 0.18, 0.3), Vector3(0.06, 0.28, 0.03), 0.022, 0.022, "p_cable")
	_bx(m, Vector3(0.06, 0.29, 0.02), Vector3(0.03, 0.03, 0.02), "p_cable")


## Market stall, long axis along x, open on both long sides (so both ground orientations show a front): counter in the
## middle, a striped gable awning, scalloped valances, produce crates, chalkboards.
static func _stall(m: Array[Prim]) -> void:
	_bx(m, Vector3(0, 0, 0.1), Vector3(0.4, 0.12, 0.1), "wood")
	_bx(m, Vector3(0, 0, 0.21), Vector3(0.43, 0.15, 0.014), "woodd")
	for i in 5:
		for s: float in [-1.0, 1.0]:
			_bx(m, Vector3(-0.32 + 0.16 * float(i), 0.121 * s, 0.1), Vector3(0.004, 0.003, 0.09), "woodd")
	for s: float in [-1.0, 1.0]:
		_bx(m, Vector3(0.0, 0.125 * s, 0.1), Vector3(0.12, 0.004, 0.065), "gun")  # chalkboards
		_bx(m, Vector3(-0.03, 0.129 * s, 0.12), Vector3(0.06, 0.003, 0.006), "whitep")
		_bx(m, Vector3(0.0, 0.129 * s, 0.09), Vector3(0.07, 0.003, 0.006), "whitep")
		_bx(m, Vector3(0.0, 0.129 * s, 0.06), Vector3(0.045, 0.003, 0.006), "whitep")
	for sx: float in [-1.0, 1.0]:
		_bx(m, Vector3(0.43 * sx, 0, 0.35), Vector3(0.014, 0.014, 0.35), "woodd")  # ridge posts
		for sy: float in [-1.0, 1.0]:
			_bx(m, Vector3(0.43 * sx, 0.27 * sy, 0.25), Vector3(0.014, 0.014, 0.25), "woodd")
	var a := atan2(0.19, 0.3)
	var ln := sqrt(0.3 * 0.3 + 0.19 * 0.19) * 0.5
	for i in 8:
		var x := -0.385 + 0.11 * float(i)
		for s: float in [-1.0, 1.0]:
			_bxt(m, Vector3(x, 0.15 * s, 0.6), Vector3(0.055, ln + 0.015, 0.008), "red" if i % 2 == 0 else "whitep", a * s)
			_bx(m, Vector3(x, 0.31 * s, 0.485), Vector3(0.055, 0.007, 0.032), "whitep" if i % 2 == 0 else "red")
	var fruit: Array[String] = ["red", "p_yellow", "p_cone"]
	for s: float in [-1.0, 1.0]:
		for i in 3:
			var x := -0.25 + 0.25 * float(i)
			var ci := i if s > 0.0 else (i + 1) % 3
			_bx(m, Vector3(x, 0.07 * s, 0.255), Vector3(0.085, 0.055, 0.03), "wood")
			_bx(m, Vector3(x, 0.07 * s, 0.28), Vector3(0.088, 0.058, 0.004), "woodd")
			for k in 6:
				var fx := x + (float(k % 3) - 1.0) * 0.045
				var fy := 0.07 * s + (float(k / 3) - 0.5) * 0.05
				_sp(m, Vector3(fx, fy, 0.305), Vector3(0.024, 0.024, 0.024), fruit[ci])
	Base._crate(m, Vector3(0.53, 0.1, 0.07), 0.07, 0.3)
	Base._crate(m, Vector3(0.53, -0.07, 0.07), 0.07, -0.2)
	Base._crate(m, Vector3(0.53, 0.02, 0.2), 0.06, 0.1)
	_sp(m, Vector3(0.53, 0.1, 0.17), Vector3(0.03, 0.03, 0.03), "leaf")
	_sp(m, Vector3(0.51, 0.13, 0.17), Vector3(0.03, 0.03, 0.03), "leafl")


## Two striped folding lawn chairs facing each other across a small round table with a drink.
static func _lawn_chair(m: Array[Prim], c: Vector3, yaw: float) -> void:
	var g: Array[Prim] = []
	for i in 3:
		var y := (float(i) - 1.0) * 0.05
		var mt := "p_blue" if i % 2 == 0 else "whitep"
		_bx(g, Vector3(0, y, 0.15), Vector3(0.08, 0.023, 0.008), mt)
		_bn(g, Vector3(-0.08, y, 0.155), Vector3(-0.15, y, 0.36), 0.023, 0.008, mt)
	for s: float in [-1.0, 1.0]:
		_bn(g, Vector3(0.08, 0.075 * s, 0.15), Vector3(0.1, 0.082 * s, 0.0), 0.011, 0.011, "p_chrome")
		_bn(g, Vector3(-0.08, 0.075 * s, 0.15), Vector3(-0.15, 0.082 * s, 0.0), 0.011, 0.011, "p_chrome")
		_bn(g, Vector3(-0.15, 0.078 * s, 0.37), Vector3(0.07, 0.078 * s, 0.22), 0.011, 0.011, "wood")
		_bn(g, Vector3(0.07, 0.078 * s, 0.22), Vector3(0.07, 0.078 * s, 0.155), 0.011, 0.011, "wood")
	_put(m, g, yaw, c)


static func _lawn_chairs(m: Array[Prim]) -> void:
	_lawn_chair(m, Vector3(0.02, 0.25, 0.0), -PI * 0.5 + 0.1)
	_lawn_chair(m, Vector3(-0.03, -0.25, 0.0), PI * 0.5 - 0.1)
	_cy(m, Vector3(0, 0, 0.014), 0.06, 0.012, "p_chrome")
	_cy(m, Vector3(0, 0, 0.1), 0.014, 0.1, "p_chrome")
	_cy(m, Vector3(0, 0, 0.205), 0.11, 0.012, "wood")
	_cy(m, Vector3(0, 0, 0.222), 0.095, 0.006, "woodd")
	_cy(m, Vector3(0.03, 0.02, 0.255), 0.022, 0.032, "glass")
	_cy(m, Vector3(-0.04, -0.03, 0.245), 0.026, 0.022, "red")
	_cy(m, Vector3(-0.04, -0.03, 0.272), 0.02, 0.004, "whitep")


## Campfire: ash bed, ring of stones, leaning logs charred at the top, layered flame blobs, embers, a wisp of smoke.
static func _campfire(m: Array[Prim]) -> void:
	_cy(m, Vector3(0, 0, 0.008), 0.26, 0.008, "p_ash")
	for i in 9:
		var a := TAU * float(i) / 9.0 + 0.2 * Base._rnd(i, 7)
		var r := 0.24 + 0.02 * Base._rnd(i, 8)
		_sp(m, Vector3(cos(a) * r, sin(a) * r, 0.042), Vector3(0.062, 0.055, 0.045), "stone" if i % 2 == 0 else "stonel")
	_bn(m, Vector3(-0.18, -0.04, 0.07), Vector3(0.14, 0.06, 0.08), 0.032, 0.03, "wood")
	_bn(m, Vector3(0.04, -0.17, 0.07), Vector3(-0.02, 0.17, 0.08), 0.03, 0.028, "woodd")
	for i in 4:
		var a := TAU * float(i) / 4.0 + 0.6
		_bn(m, Vector3(cos(a) * 0.19, sin(a) * 0.19, 0.04), Vector3(cos(a) * 0.04, sin(a) * 0.04, 0.26), 0.028, 0.026, "bark" if i % 2 == 0 else "woodd")
		_sp(m, Vector3(cos(a) * 0.04, sin(a) * 0.04, 0.26), Vector3(0.03, 0.03, 0.03), "char")
	_sp(m, Vector3(0.0, 0.0, 0.2), Vector3(0.09, 0.09, 0.17), "fire")
	_sp(m, Vector3(0.07, 0.04, 0.14), Vector3(0.055, 0.05, 0.1), "fire")
	_sp(m, Vector3(-0.06, 0.06, 0.15), Vector3(0.05, 0.05, 0.11), "fire")
	_sp(m, Vector3(0.0, -0.07, 0.13), Vector3(0.05, 0.05, 0.09), "fire")
	_sp(m, Vector3(0.01, 0.0, 0.2), Vector3(0.05, 0.05, 0.12), "flash")
	_sp(m, Vector3(0.0, 0.0, 0.34), Vector3(0.03, 0.03, 0.05), "fire")
	_sp(m, Vector3(0.1, -0.08, 0.04), Vector3(0.02, 0.02, 0.014), "flash")
	_sp(m, Vector3(-0.1, 0.0, 0.035), Vector3(0.02, 0.02, 0.014), "fire")
	_sp(m, Vector3(0.0, 0.0, 0.5), Vector3(0.04, 0.04, 0.04), "smoke")


## Wheel standing in the y-z plane (axis along x): tyre ring, rim ring, hub.
static func _wheel(m: Array[Prim], c: Vector3, r: float) -> void:
	var n := 16
	for i in n:
		var t0 := TAU * float(i) / float(n)
		var t1 := TAU * float(i + 1) / float(n)
		_bn(m, c + Vector3(0, cos(t0) * r, sin(t0) * r), c + Vector3(0, cos(t1) * r, sin(t1) * r), 0.012, 0.012, "track")
		_bn(m, c + Vector3(0, cos(t0) * (r - 0.02), sin(t0) * (r - 0.02)), c + Vector3(0, cos(t1) * (r - 0.02), sin(t1) * (r - 0.02)), 0.005, 0.006, "p_chrome")
	_sp(m, c, Vector3(0.016, 0.016, 0.016), "p_chrome")
	for i in 3:
		var t := PI * float(i) / 3.0 + 0.3
		_bn(m, c + Vector3(0, cos(t) * (r - 0.02), sin(t) * (r - 0.02)), c - Vector3(0, cos(t) * (r - 0.02), sin(t) * (r - 0.02)), 0.003, 0.004, "p_chrome")


## Bike stand: three inverted-U hoops in a row (along x) and a red bicycle parked in the middle slot.
static func _bike_rack(m: Array[Prim]) -> void:
	for x: float in [-0.14, 0.14]:
		for s: float in [-1.0, 1.0]:
			_bn(m, Vector3(x, 0.11 * s, 0.0), Vector3(x, 0.11 * s, 0.2), 0.015, 0.015, "p_chrome")
			_bn(m, Vector3(x, 0.11 * s, 0.2), Vector3(x, 0.07 * s, 0.26), 0.015, 0.015, "p_chrome")
		_bn(m, Vector3(x, -0.07, 0.26), Vector3(x, 0.07, 0.26), 0.015, 0.015, "p_chrome")
		_bx(m, Vector3(x, 0, 0.008), Vector3(0.03, 0.14, 0.008), "concrete")
	var bx := 0.0
	var rear := Vector3(bx, -0.2, 0.12)
	var front := Vector3(bx, 0.2, 0.12)
	_wheel(m, rear, 0.115)
	_wheel(m, front, 0.115)
	var bb := Vector3(bx, -0.02, 0.1)
	var seat := Vector3(bx, -0.08, 0.31)
	var head := Vector3(bx, 0.14, 0.31)
	var hb := Vector3(bx, 0.14, 0.27)
	_bn(m, rear, bb, 0.012, 0.012, "red")
	_bn(m, bb, seat, 0.012, 0.012, "red")
	_bn(m, rear, seat, 0.01, 0.01, "red")
	_bn(m, seat, head, 0.012, 0.012, "red")
	_bn(m, bb, hb, 0.014, 0.014, "red")
	_bn(m, hb, front, 0.01, 0.01, "p_chrome")
	_bn(m, head + Vector3(0, 0.015, 0.0), Vector3(bx, 0.17, 0.18), 0.008, 0.008, "p_chrome")
	_bx(m, Vector3(bx, 0.13, 0.34), Vector3(0.075, 0.012, 0.012), "gun")  # handlebar
	_bx(m, Vector3(bx, -0.1, 0.33), Vector3(0.022, 0.05, 0.014), "gun")  # saddle
	_bn(m, bb, Vector3(bx + 0.03, -0.02, 0.06), 0.01, 0.01, "p_chrome")
	_bn(m, bb, Vector3(bx - 0.03, -0.02, 0.14), 0.01, 0.01, "p_chrome")
	_bx(m, Vector3(bx + 0.03, -0.02, 0.055), Vector3(0.025, 0.02, 0.006), "gun")


## One cafe chair facing +x: round wooden seat, four legs, hooped back.
static func _cafe_chair(m: Array[Prim], c: Vector3, yaw: float) -> void:
	var g: Array[Prim] = []
	_cy(g, Vector3(0, 0, 0.14), 0.055, 0.008, "wood")
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			_bn(g, Vector3(0.04 * sx, 0.04 * sy, 0.0), Vector3(0.04 * sx, 0.04 * sy, 0.135), 0.008, 0.008, "p_bistro")
	for s: float in [-1.0, 1.0]:
		_bn(g, Vector3(-0.045, 0.04 * s, 0.14), Vector3(-0.06, 0.042 * s, 0.31), 0.008, 0.008, "p_bistro")
	_bx(g, Vector3(-0.062, 0, 0.3), Vector3(0.008, 0.052, 0.012), "p_bistro")
	_bx(g, Vector3(-0.058, 0, 0.23), Vector3(0.006, 0.045, 0.01), "p_bistro")
	_put(m, g, yaw, c)


## Round bistro table with a striped parasol (stacked discs), three chairs and two cups.
static func _cafe(m: Array[Prim]) -> void:
	_cy(m, Vector3(0, 0, 0.01), 0.08, 0.01, "p_bistro")
	_cy(m, Vector3(0, 0, 0.14), 0.014, 0.13, "p_bistro")
	_cy(m, Vector3(0, 0, 0.275), 0.15, 0.01, "whitep")
	_cy(m, Vector3(0, 0, 0.268), 0.152, 0.004, "p_bistro")
	_cy(m, Vector3(0, 0, 0.45), 0.01, 0.2, "steel")
	var radii: Array[float] = [0.31, 0.26, 0.2, 0.14, 0.08]
	var zs: Array[float] = [0.56, 0.585, 0.61, 0.635, 0.655]
	for i in 5:
		_cy(m, Vector3(0, 0, zs[i]), radii[i], 0.018, "red" if i % 2 == 0 else "whitep")
	_sp(m, Vector3(0, 0, 0.68), Vector3(0.02, 0.02, 0.02), "steel")
	var ang: Array[float] = [0.15, 1.35, 3.7]
	for a in ang:
		_cafe_chair(m, Vector3(cos(a) * 0.36, sin(a) * 0.36, 0.0), a + PI)
	_cy(m, Vector3(0.05, 0.03, 0.3), 0.022, 0.018, "red")
	_cy(m, Vector3(-0.06, -0.04, 0.3), 0.022, 0.018, "whitep")
