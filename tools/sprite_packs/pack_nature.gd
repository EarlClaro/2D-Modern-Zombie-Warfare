extends RefCounted
## Theme pack: nature (trees, grass, plants, rocks). Loaded by tools/gen_sprites.gd, see docs/specs/art-pack-2.md.
## Pack contract:
##   MATS    extra palette entries (name -> [dark, mid, light] hex), names prefixed `n_` so packs never collide.
##   specs() render specs, one per sprite set. Keys: dir (output folder and scenery id), name (display name),
##           cat (category for counts and the gallery), auto (always true), k (uniform enlargement), ss (supersampling),
##           frames/columns (1/1 for scenery), facings. Optional: foot (Vector2i, overrides the footprint estimated from
##           the model), fades (bool, overrides "taller than 1.0 unit"), glow ([point in model axes, radius px, Color]).
##   build() fills `m` with the model for `unit` at `frame` and returns true, or returns false for a unit it does not own.
## Models are built at authoring scale (1 unit = 32 px, a soldier is about 0.94 tall) and enlarged by `k`.

const Base = preload("res://tools/gen_sprites.gd")
const Prim = Base.Prim

const MATS := {
	"n_birch": ["a9a79c", "d6d4c8", "f2f0e6"],
	"n_birchmark": ["1c1b18", "2c2a26", "3e3b35"],
	"n_birchleaf": ["5a8a3a", "7fb04c", "a3cf6a"],
	"n_moss": ["2c4a24", "416a33", "5c8a46"],
	"n_tuft": ["3c6330", "5a8a42", "86b865"],
	"n_tuftdry": ["6a6030", "93883f", "bfae5e"],
	# trees
	"n_willow": ["426a28", "5f8c36", "86b24e"],
	"n_willowd": ["2e4e22", "46702c", "649a3e"],
	"n_palmleaf": ["24602c", "38883c", "58b050"],
	"n_palmtrunk": ["5a4630", "7e6444", "a08a62"],
	"n_palmring": ["463622", "665034", "86704a"],
	"n_coconut": ["3a2a14", "5a4220", "7a5c30"],
	"n_mapler": ["7a1e14", "b0301c", "dc5a2a"],
	"n_mapleo": ["a04a10", "d27a1c", "f0a838"],
	"n_mapley": ["a07a14", "d4a826", "f2d252"],
	"n_cypress": ["16382a", "245238", "36704c"],
	"n_cypressl": ["1e4632", "2e6444", "428258"],
	"n_cut": ["a88858", "c8a870", "e0c898"],
	"n_cutring": ["7a5a34", "9a7848", "b89460"],
	"n_snow": ["a4b6cc", "d6e3f0", "fafdff"],
	"n_snowneedle": ["183830", "26503e", "386a54"],
	"n_snowneedled": ["12302a", "1e4636", "2e5e48"],
	"n_deadpine": ["46423a", "6a6356", "908673"],
	"n_ember": ["8a2a08", "e05a12", "ffc040"],
	"n_hollow": ["0c0a08", "16120e", "241d16"],
	# plants and ground cover
	"n_tallgrass": ["4a7a30", "6ea43e", "98cc5c"],
	"n_reed": ["5a6a2c", "86973f", "b0bf62"],
	"n_cattail": ["3a2418", "5a3a24", "7a5236"],
	"n_water": ["28586e", "3c7c94", "62a4b8"],
	"n_mud": ["2c2218", "443624", "5e4c34"],
	"n_fern": ["24562a", "38803a", "58ac52"],
	"n_fernl": ["2e6a30", "489a44", "72c46a"],
	"n_flr": ["a82838", "dc4458", "f48a9a"],
	"n_fly": ["b08a14", "e8c030", "fff070"],
	"n_flw": ["b0b0c0", "e8e8f0", "ffffff"],
	"n_flp": ["6a3a98", "9a62c8", "c490e8"],
	"n_mcap": ["8a1c18", "c4302a", "e86050"],
	"n_mcapb": ["5a3a1c", "8a5a2c", "b88048"],
	"n_mstem": ["b0a088", "dccfb4", "f4ecdc"],
	"n_pad": ["246a34", "3a9048", "5eb862"],
	"n_padd": ["1c5428", "2c7a3a", "46a050"],
	"n_lotus": ["b8508a", "e87ab4", "ffb0d6"],
	"n_berry": ["6a1230", "a02050", "d84a80"],
	"n_thorn": ["5a4a2c", "7e6c42", "a4906a"],
	"n_thornd": ["382c1a", "52422a", "6e583a"],
	"n_dryb": ["62482a", "8c6c3a", "b89a58"],
	"n_cactus": ["22563a", "36804a", "58a866"],
	"n_cactusd": ["183e28", "255a36", "36764a"],
	# rocks and landforms
	"n_slate": ["2a2e36", "3e444e", "565e6a"],
	"n_slatel": ["485060", "667080", "8894a6"],
	"n_cliff": ["483e34", "6c5e50", "927f6a"],
	"n_cliffl": ["5c5044", "84725f", "a8957e"],
	"n_dune": ["b2924e", "d2b36c", "efd694"],
	"n_dunel": ["c2a25c", "e4c680", "fbe8b0"],
	"n_dunesh": ["8c6e38", "ac8c4c", "c8a866"],
	"n_ice": ["5486b0", "98c6e8", "d6f0ff"],
	"n_icel": ["80b4dc", "bce2f8", "f0fbff"],
}


static func specs() -> Array:
	return [
		{"dir": "birch_tree", "name": "Birch Tree", "cat": "nature", "auto": true, "k": 1.8, "frames": 1, "columns": 1, "ss": 2, "facings": ["se"]},
		{"dir": "grass_tuft", "name": "Grass Tuft", "cat": "nature", "auto": true, "k": 0.6, "frames": 1, "columns": 1, "ss": 2, "facings": ["se"]},
		{"dir": "mossy_boulder", "name": "Mossy Boulder", "cat": "nature", "auto": true, "k": 1.5, "frames": 1, "columns": 1, "ss": 2, "facings": ["se"]},
		# trees
		{"dir": "willow_tree", "name": "Willow Tree", "cat": "nature", "auto": true, "k": 1.8, "frames": 1, "columns": 1, "ss": 2, "facings": ["se"], "foot": Vector2i(1, 1)},
		{"dir": "palm_tree", "name": "Palm Tree", "cat": "nature", "auto": true, "k": 1.8, "frames": 1, "columns": 1, "ss": 2, "facings": ["se"]},
		{"dir": "maple_autumn", "name": "Autumn Maple", "cat": "nature", "auto": true, "k": 1.8, "frames": 1, "columns": 1, "ss": 2, "facings": ["se"], "foot": Vector2i(1, 1)},
		{"dir": "cypress_tree", "name": "Cypress Tree", "cat": "nature", "auto": true, "k": 1.8, "frames": 1, "columns": 1, "ss": 2, "facings": ["se"]},
		{"dir": "sapling", "name": "Sapling", "cat": "nature", "auto": true, "k": 1.3, "frames": 1, "columns": 1, "ss": 2, "facings": ["se"]},
		{"dir": "tree_stump", "name": "Tree Stump", "cat": "nature", "auto": true, "k": 1.0, "frames": 1, "columns": 1, "ss": 2, "facings": ["se"]},
		{"dir": "snow_pine", "name": "Snowy Pine", "cat": "nature", "auto": true, "k": 1.8, "frames": 1, "columns": 1, "ss": 2, "facings": ["se"], "foot": Vector2i(1, 1)},
		{"dir": "dead_pine", "name": "Dead Pine", "cat": "nature", "auto": true, "k": 1.8, "frames": 1, "columns": 1, "ss": 2, "facings": ["se"]},
		{"dir": "burnt_tree", "name": "Burnt Tree", "cat": "nature", "auto": true, "k": 1.8, "frames": 1, "columns": 1, "ss": 2, "facings": ["se"], "foot": Vector2i(1, 1)},
		{"dir": "giant_oak", "name": "Giant Oak", "cat": "nature", "auto": true, "k": 1.75, "frames": 1, "columns": 1, "ss": 2, "facings": ["se"], "foot": Vector2i(2, 2)},
		# plants and ground cover
		{"dir": "tall_grass", "name": "Tall Grass", "cat": "nature", "auto": true, "k": 0.55, "frames": 1, "columns": 1, "ss": 2, "facings": ["se"], "foot": Vector2i(1, 1)},
		{"dir": "reeds", "name": "Reeds", "cat": "nature", "auto": true, "k": 0.95, "frames": 1, "columns": 1, "ss": 2, "facings": ["se"], "foot": Vector2i(1, 1)},
		{"dir": "fern", "name": "Fern", "cat": "nature", "auto": true, "k": 0.7, "frames": 1, "columns": 1, "ss": 2, "facings": ["se"], "foot": Vector2i(1, 1)},
		{"dir": "flower_patch", "name": "Flower Patch", "cat": "nature", "auto": true, "k": 0.7, "frames": 1, "columns": 1, "ss": 2, "facings": ["se"]},
		{"dir": "mushrooms", "name": "Mushrooms", "cat": "nature", "auto": true, "k": 0.6, "frames": 1, "columns": 1, "ss": 2, "facings": ["se"], "foot": Vector2i(1, 1)},
		{"dir": "lily_pads", "name": "Lily Pads", "cat": "nature", "auto": true, "k": 0.6, "frames": 1, "columns": 1, "ss": 2, "facings": ["se"], "foot": Vector2i(1, 1)},
		{"dir": "berry_bush", "name": "Berry Bush", "cat": "nature", "auto": true, "k": 1.25, "frames": 1, "columns": 1, "ss": 2, "facings": ["se"]},
		{"dir": "thorn_bush", "name": "Thorn Bush", "cat": "nature", "auto": true, "k": 1.1, "frames": 1, "columns": 1, "ss": 2, "facings": ["se"]},
		{"dir": "dry_bush", "name": "Tumbleweed", "cat": "nature", "auto": true, "k": 0.75, "frames": 1, "columns": 1, "ss": 2, "facings": ["se"]},
		{"dir": "cactus", "name": "Cactus", "cat": "nature", "auto": true, "k": 1.5, "frames": 1, "columns": 1, "ss": 2, "facings": ["se"]},
		{"dir": "branch_pile", "name": "Branch Pile", "cat": "nature", "auto": true, "k": 0.7, "frames": 1, "columns": 1, "ss": 2, "facings": ["se", "sw"], "foot": Vector2i(1, 1)},
		# rocks and landforms
		{"dir": "slate_outcrop", "name": "Slate Outcrop", "cat": "nature", "auto": true, "k": 1.6, "frames": 1, "columns": 1, "ss": 2, "facings": ["se"], "foot": Vector2i(1, 1)},
		{"dir": "cliff_chunk", "name": "Cliff Chunk", "cat": "nature", "auto": true, "k": 1.5, "frames": 1, "columns": 1, "ss": 2, "facings": ["se", "sw"], "foot": Vector2i(2, 2)},
		{"dir": "sand_dune", "name": "Sand Dune", "cat": "nature", "auto": true, "k": 1.6, "frames": 1, "columns": 1, "ss": 2, "facings": ["se", "sw"], "foot": Vector2i(3, 2)},
		{"dir": "snow_mound", "name": "Snow Mound", "cat": "nature", "auto": true, "k": 1.6, "frames": 1, "columns": 1, "ss": 2, "facings": ["se"], "foot": Vector2i(1, 1)},
		{"dir": "ice_chunk", "name": "Ice Chunk", "cat": "nature", "auto": true, "k": 1.6, "frames": 1, "columns": 1, "ss": 2, "facings": ["se"], "foot": Vector2i(1, 1)},
		{"dir": "rock_spire", "name": "Rock Spire", "cat": "nature", "auto": true, "k": 1.6, "frames": 1, "columns": 1, "ss": 2, "facings": ["se"], "foot": Vector2i(1, 1)},
		{"dir": "boulder_pair", "name": "Boulder Pair", "cat": "nature", "auto": true, "k": 1.8, "frames": 1, "columns": 1, "ss": 2, "facings": ["se"], "foot": Vector2i(1, 1)},
	]


static func build(_host: Object, m: Array[Prim], unit: String, _frame: int) -> bool:
	match unit:
		"birch_tree":
			_birch(m)
		"grass_tuft":
			_tuft(m)
		"mossy_boulder":
			_mossy_boulder(m)
		"willow_tree":
			_willow(m)
		"palm_tree":
			_palm(m)
		"maple_autumn":
			_maple(m)
		"cypress_tree":
			_cypress(m)
		"sapling":
			_sapling(m)
		"tree_stump":
			_stump(m)
		"snow_pine":
			_snow_pine(m)
		"dead_pine":
			_dead_pine(m)
		"burnt_tree":
			_burnt_tree(m)
		"giant_oak":
			_giant_oak(m)
		"tall_grass":
			_tall_grass(m)
		"reeds":
			_reeds(m)
		"fern":
			_fern(m)
		"flower_patch":
			_flower_patch(m)
		"mushrooms":
			_mushrooms(m)
		"lily_pads":
			_lily_pads(m)
		"berry_bush":
			_berry_bush(m)
		"thorn_bush":
			_thorn_bush(m)
		"dry_bush":
			_dry_bush(m)
		"cactus":
			_cactus(m)
		"branch_pile":
			_branch_pile(m)
		"slate_outcrop":
			_slate(m)
		"cliff_chunk":
			_cliff(m)
		"sand_dune":
			_dune(m)
		"snow_mound":
			_snow_mound(m)
		"ice_chunk":
			_ice(m)
		"rock_spire":
			_spire(m)
		"boulder_pair":
			_boulder_pair(m)
		_:
			return false
	return true


# ---- helpers ------------------------------------------------------------------------------------------

## Foliage lobes: entries [centre, radius, optional z squash], materials cycle through `mats`.
static func _lobes(m: Array[Prim], list: Array, mats: Array) -> void:
	for i in list.size():
		var e: Array = list[i]
		var c: Vector3 = e[0]
		var r: float = e[1]
		var sq: float = 0.85
		if e.size() > 2:
			sq = e[2]
		Base._sp(m, c, Vector3(r, r, r * sq), mats[i % mats.size()])


## `n` grass blades scattered in a disc of radius `r` around `c`, heights h0..h1, leaning by `lean` (fraction of height).
static func _blades(m: Array[Prim], c: Vector3, n: int, r: float, h0: float, h1: float, lean: float, mats: Array, seed_i: int, hw: float = 0.016) -> void:
	for i in n:
		var a: float = TAU * Base._rnd(i, seed_i)
		var rr: float = r * sqrt(Base._rnd(i, seed_i + 1))
		var base := c + Vector3(cos(a) * rr, sin(a) * rr, 0.0)
		var h: float = lerpf(h0, h1, Base._rnd(i, seed_i + 2))
		var la: float = TAU * Base._rnd(i, seed_i + 3)
		var tip := base + Vector3(cos(la) * lean * h, sin(la) * lean * h, h)
		Base._bone(m, base, tip, hw, hw, mats[i % mats.size()])


## A flat ground disc (squashed sphere).
static func _disc(m: Array[Prim], c: Vector3, rx: float, ry: float, rz: float, mat: String) -> void:
	Base._sp(m, c, Vector3(rx, ry, rz), mat)


# ---- trees --------------------------------------------------------------------------------------------

static func _birch(m: Array[Prim]) -> void:
	Base._cy(m, Vector3(0, 0, 0.35), 0.05, 0.35, "n_birch")
	for z in [0.15, 0.32, 0.5, 0.62]:
		Base._bx(m, Vector3(0.0, 0.0, z), Vector3(0.052, 0.052, 0.012), "n_birchmark")
	Base._bone(m, Vector3(0, 0, 0.6), Vector3(0.1, 0.06, 0.95), 0.02, 0.02, "n_birch")
	Base._bone(m, Vector3(0, 0, 0.55), Vector3(-0.1, -0.08, 0.9), 0.02, 0.02, "n_birch")
	var blobs: Array = [[Vector3(0.0, 0.0, 0.95), 0.28], [Vector3(0.14, 0.08, 0.82), 0.2], [Vector3(-0.13, -0.1, 0.86), 0.21], [Vector3(0.02, -0.13, 1.05), 0.19], [Vector3(-0.04, 0.12, 1.1), 0.18]]
	for i in blobs.size():
		Base._sp(m, blobs[i][0], Vector3(blobs[i][1], blobs[i][1], blobs[i][1] * 0.9), "n_birchleaf" if i % 2 == 0 else "leaf")


## Willow: short thick trunk, rounded dome crown, and a skirt of long curved hanging strands (drooping silhouette).
static func _willow(m: Array[Prim]) -> void:
	Base._cy(m, Vector3(0, 0, 0.26), 0.075, 0.26, "bark")
	Base._bone(m, Vector3(0, 0, 0.45), Vector3(0.12, 0.06, 0.85), 0.035, 0.035, "bark")
	Base._bone(m, Vector3(0, 0, 0.45), Vector3(-0.12, -0.07, 0.8), 0.03, 0.03, "bark")
	var crown: Array = [
		[Vector3(0, 0, 1.0), 0.28, 0.85], [Vector3(0.15, 0.08, 0.92), 0.2, 0.85], [Vector3(-0.15, -0.08, 0.95), 0.2, 0.85],
		[Vector3(-0.06, 0.17, 1.0), 0.19, 0.85], [Vector3(0.07, -0.16, 1.0), 0.19, 0.85], [Vector3(0.0, 0.0, 1.14), 0.18, 0.85],
	]
	_lobes(m, crown, ["n_willowd", "n_willow", "n_willow"])
	var mats: Array = ["n_willowd", "n_willow", "n_willow", "n_willowd"]
	var rings: Array = [[0.3, 14], [0.22, 18], [0.14, 10]]
	for ri in rings.size():
		var cnt: int = rings[ri][1]
		var r0: float = rings[ri][0]
		for i in cnt:
			var a: float = TAU * float(i) / float(cnt) + 0.3 * Base._rnd(i, 7 + ri)
			var rr: float = r0 + 0.03 * Base._rnd(i, 1)
			var zt: float = 0.92 - 0.05 * float(ri)
			var zb: float = 0.06 + 0.3 * Base._rnd(i, 2 + ri) + 0.15 * float(ri)
			var zm: float = (zt + zb) * 0.5
			var p0 := Vector3(cos(a) * rr, sin(a) * rr, zt)
			var p1 := Vector3(cos(a) * (rr + 0.07), sin(a) * (rr + 0.07), zm)
			var p2 := Vector3(cos(a) * (rr + 0.06), sin(a) * (rr + 0.06), zb)
			Base._bone(m, p0, p1, 0.018, 0.012, mats[(i + ri) % 4])
			Base._bone(m, p1, p2, 0.016, 0.01, mats[(i + ri + 1) % 4])


## Palm: curved ringed trunk leaning toward +x, ten arching fronds with leaflets, coconuts.
static func _palm(m: Array[Prim]) -> void:
	var seg := 7
	var pts: Array[Vector3] = []
	for i in seg + 1:
		var t: float = float(i) / float(seg)
		pts.append(Vector3(0.26 * t * t, 0.08 * t, 1.2 * t))
	for i in seg:
		var th: float = 0.06 - 0.022 * float(i) / float(seg)
		Base._bone(m, pts[i], pts[i + 1], th, th, "n_palmtrunk" if i % 2 == 0 else "n_palmring")
	var top: Vector3 = pts[seg]
	Base._sp(m, top + Vector3(0, 0, 0.02), Vector3(0.08, 0.08, 0.06), "n_palmleaf")
	for i in 10:
		var a: float = TAU * float(i) / 10.0 + 0.3
		var d := Vector3(cos(a), sin(a), 0.0)
		var perp := Vector3(-d.y, d.x, 0.0)
		var pa := top + d * 0.2 + Vector3(0, 0, 0.12 + 0.05 * Base._rnd(i, 2))
		var pb := pa + d * 0.2 + Vector3(0, 0, -0.01)
		var pc := pb + d * 0.15 + Vector3(0, 0, -0.17 - 0.08 * Base._rnd(i, 3))
		var mat: String = "n_palmleaf" if i % 2 == 0 else "n_willow"
		Base._bone(m, top, pa, 0.05, 0.012, mat)
		Base._bone(m, pa, pb, 0.055, 0.012, mat)
		Base._bone(m, pb, pc, 0.04, 0.012, mat)
		for sg in [1.0, -1.0]:
			Base._bone(m, pa + d * 0.08, pa + d * 0.14 + perp * sg * 0.12 + Vector3(0, 0, -0.08), 0.03, 0.01, mat)
			Base._bone(m, pb + d * 0.04, pb + d * 0.08 + perp * sg * 0.1 + Vector3(0, 0, -0.1), 0.026, 0.01, mat)
	for i in 3:
		var a: float = TAU * float(i) / 3.0 + 0.9
		Base._sp(m, top + Vector3(cos(a) * 0.07, sin(a) * 0.07, -0.06), Vector3(0.045, 0.045, 0.045), "n_coconut")


## Autumn maple: dense round crown in orange, red and yellow lobes, leaf litter on the ground.
static func _maple(m: Array[Prim]) -> void:
	Base._cy(m, Vector3(0, 0, 0.25), 0.08, 0.25, "bark")
	Base._bone(m, Vector3(0, 0, 0.45), Vector3(0.14, 0.1, 0.78), 0.03, 0.03, "bark")
	Base._bone(m, Vector3(0, 0, 0.45), Vector3(-0.12, -0.13, 0.74), 0.028, 0.028, "bark")
	var crown: Array = [
		[Vector3(0.0, 0.0, 0.98), 0.34], [Vector3(0.22, 0.12, 0.84), 0.25], [Vector3(-0.2, -0.1, 0.86), 0.26],
		[Vector3(0.08, -0.22, 1.0), 0.24], [Vector3(-0.1, 0.2, 1.06), 0.24], [Vector3(0.12, 0.02, 1.2), 0.22],
		[Vector3(-0.22, 0.14, 0.9), 0.2], [Vector3(0.2, -0.16, 0.9), 0.2],
	]
	_lobes(m, crown, ["n_mapleo", "n_mapler", "n_mapley", "n_mapler", "n_mapleo"])
	for i in 7:
		var a: float = TAU * float(i) / 7.0 + 0.4
		var r: float = 0.18 + 0.14 * Base._rnd(i, 5)
		Base._sp(m, Vector3(cos(a) * r, sin(a) * r, 0.01), Vector3(0.07, 0.06, 0.014), "n_mapler" if i % 2 == 0 else "n_mapleo")


## Cypress: tall narrow flame-shaped column built from stacked tapering lobes.
static func _cypress(m: Array[Prim]) -> void:
	Base._cy(m, Vector3(0, 0, 0.08), 0.045, 0.08, "bark")
	var levels: Array = [[0.22, 0.17, 0.22], [0.45, 0.19, 0.24], [0.68, 0.17, 0.24], [0.9, 0.14, 0.22], [1.1, 0.1, 0.2], [1.26, 0.06, 0.16]]
	for i in levels.size():
		var e: Array = levels[i]
		var z: float = e[0]
		var r: float = e[1]
		var hz: float = e[2]
		Base._sp(m, Vector3(0, 0, z), Vector3(r, r, hz), "n_cypress" if i % 2 == 0 else "n_cypressl")
		Base._sp(m, Vector3(r * 0.45, r * 0.35, z + 0.05), Vector3(r * 0.6, r * 0.55, hz * 0.8), "n_cypressl" if i % 2 == 0 else "n_cypress")
	Base._sp(m, Vector3(0, 0, 1.4), Vector3(0.035, 0.035, 0.08), "n_cypress")


## Sapling: thin whippy trunk tied to a wooden stake, a small leafy tuft.
static func _sapling(m: Array[Prim]) -> void:
	Base._bone(m, Vector3(0, 0, 0.0), Vector3(0.03, 0.01, 0.5), 0.016, 0.016, "bark")
	Base._bone(m, Vector3(0.01, 0, 0.3), Vector3(0.12, 0.05, 0.46), 0.01, 0.01, "bark")
	Base._bone(m, Vector3(0.01, 0, 0.34), Vector3(-0.1, -0.04, 0.5), 0.01, 0.01, "bark")
	Base._bx(m, Vector3(-0.07, 0.06, 0.22), Vector3(0.012, 0.012, 0.22), "wood")
	Base._bx(m, Vector3(-0.034, 0.03, 0.3), Vector3(0.044, 0.008, 0.01), "woodd", -0.7)
	var crown: Array = [
		[Vector3(0.03, 0.0, 0.58), 0.12], [Vector3(0.13, 0.05, 0.5), 0.08], [Vector3(-0.1, -0.04, 0.54), 0.08], [Vector3(0.0, 0.07, 0.66), 0.07],
	]
	_lobes(m, crown, ["leaf", "leafl", "leafd"])
	Base._sp(m, Vector3(0, 0, 0.01), Vector3(0.1, 0.1, 0.025), "n_moss")


## Stump: cut top with growth rings, flared roots, a couple of shoots.
static func _stump(m: Array[Prim]) -> void:
	Base._cy(m, Vector3(0, 0, 0.1), 0.14, 0.1, "bark")
	Base._cy(m, Vector3(0, 0, 0.205), 0.135, 0.006, "n_cut")
	Base._cy(m, Vector3(0.01, 0, 0.214), 0.095, 0.004, "n_cutring")
	Base._cy(m, Vector3(0.01, 0, 0.22), 0.07, 0.004, "n_cut")
	Base._cy(m, Vector3(0.01, 0, 0.226), 0.04, 0.004, "n_cutring")
	Base._cy(m, Vector3(0.01, 0, 0.232), 0.015, 0.004, "n_cut")
	for i in 6:
		var a: float = TAU * float(i) / 6.0 + 0.3
		Base._bone(m, Vector3(cos(a) * 0.09, sin(a) * 0.09, 0.1), Vector3(cos(a) * 0.24, sin(a) * 0.24, 0.015), 0.04, 0.035, "bark")
	Base._bone(m, Vector3(-0.1, 0.06, 0.1), Vector3(-0.15, 0.1, 0.34), 0.012, 0.012, "n_moss")
	Base._sp(m, Vector3(-0.15, 0.1, 0.36), Vector3(0.06, 0.06, 0.04), "leafl")
	Base._sp(m, Vector3(0.1, 0.12, 0.15), Vector3(0.07, 0.05, 0.05), "n_moss")


## Snowy pine: five tiers of dark needles, each capped with a white snow layer; snow drift at the foot.
static func _snow_pine(m: Array[Prim]) -> void:
	Base._cy(m, Vector3(0, 0, 0.2), 0.055, 0.2, "bark")
	for i in 6:
		var z: float = 0.28 + 0.17 * float(i)
		var r: float = 0.42 - 0.058 * float(i)
		Base._cy(m, Vector3(0, 0, z), r, 0.055, "n_snowneedled" if i % 2 == 0 else "n_snowneedle")
		Base._cy(m, Vector3(0.0, 0.0, z + 0.07), r * 0.9, 0.02, "n_snow")
		Base._sp(m, Vector3(r * 0.3, r * 0.3, z + 0.08), Vector3(r * 0.3, r * 0.26, 0.035), "n_snow")
	Base._sp(m, Vector3(0, 0, 1.25), Vector3(0.05, 0.05, 0.13), "n_snowneedle")
	Base._sp(m, Vector3(0, 0, 1.32), Vector3(0.05, 0.05, 0.05), "n_snow")
	Base._sp(m, Vector3(0, 0, 0.02), Vector3(0.34, 0.3, 0.05), "n_snow")


## Dead pine: tall bare silvery trunk with drooping stub branches and a snapped top.
static func _dead_pine(m: Array[Prim]) -> void:
	Base._cy(m, Vector3(0, 0, 0.65), 0.05, 0.65, "n_deadpine")
	Base._cy(m, Vector3(0, 0, 0.07), 0.08, 0.07, "n_deadpine")
	for i in 12:
		var z: float = 0.3 + 0.082 * float(i)
		var a: float = float(i) * 2.4 + 0.5
		var len: float = 0.34 - 0.024 * float(i)
		Base._bone(m, Vector3(cos(a) * 0.03, sin(a) * 0.03, z), Vector3(cos(a) * len, sin(a) * len, z - 0.1 + 0.03 * Base._rnd(i, 3)), 0.016, 0.016, "n_deadpine")
		if i % 2 == 0:
			var a2: float = a + 0.35
			Base._bone(m, Vector3(cos(a) * len * 0.5, sin(a) * len * 0.5, z - 0.05), Vector3(cos(a2) * len * 0.8, sin(a2) * len * 0.8, z - 0.15), 0.01, 0.01, "n_deadpine")
	Base._bone(m, Vector3(0, 0, 1.2), Vector3(0.07, 0.04, 1.44), 0.03, 0.03, "n_deadpine")
	Base._bone(m, Vector3(0, 0, 1.22), Vector3(-0.05, -0.03, 1.36), 0.025, 0.025, "n_deadpine")


## Burnt tree: charred snapped trunk, blackened stubs, glowing embers and a wisp of smoke over an ash patch.
static func _burnt_tree(m: Array[Prim]) -> void:
	_disc(m, Vector3(0.02, 0.0, 0.0), 0.34, 0.3, 0.02, "charhi")
	Base._cy(m, Vector3(0, 0, 0.35), 0.075, 0.35, "char")
	Base._cy(m, Vector3(0, 0, 0.08), 0.1, 0.08, "charhi")
	Base._bone(m, Vector3(0, 0, 0.62), Vector3(0.1, 0.05, 0.98), 0.055, 0.055, "char")
	Base._bone(m, Vector3(0, 0, 0.7), Vector3(-0.07, -0.02, 0.84), 0.045, 0.045, "charhi")
	Base._bone(m, Vector3(0, 0, 0.5), Vector3(0.3, 0.18, 0.7), 0.026, 0.026, "char")
	Base._bone(m, Vector3(0, 0, 0.45), Vector3(-0.28, -0.14, 0.6), 0.024, 0.024, "charhi")
	Base._bone(m, Vector3(0.02, 0, 0.35), Vector3(0.1, -0.26, 0.5), 0.022, 0.022, "char")
	Base._bone(m, Vector3(0.18, 0.1, 0.6), Vector3(0.34, 0.26, 0.78), 0.014, 0.014, "char")
	Base._sp(m, Vector3(0.075, 0.03, 0.3), Vector3(0.012, 0.03, 0.05), "n_ember")
	Base._sp(m, Vector3(0.07, -0.04, 0.5), Vector3(0.012, 0.025, 0.04), "n_ember")
	Base._sp(m, Vector3(0.1, 0.05, 0.96), Vector3(0.025, 0.025, 0.025), "n_ember")
	Base._sp(m, Vector3(0.3, 0.17, 0.69), Vector3(0.018, 0.018, 0.018), "n_ember")
	Base._blob(m, Vector3(0.08, 0.04, 1.08), 0.06, "smoke")
	Base._blob(m, Vector3(0.12, 0.08, 1.2), 0.075, "smoke")
	Base._blob(m, Vector3(0.1, 0.1, 1.33), 0.06, "smoke")


## Giant oak: old and massive, thick fluted trunk with root flare and a hollow, very wide layered crown.
static func _giant_oak(m: Array[Prim]) -> void:
	Base._cy(m, Vector3(0, 0, 0.3), 0.17, 0.3, "bark")
	Base._cy(m, Vector3(0, 0, 0.62), 0.14, 0.04, "bark")
	for i in 7:
		var a: float = TAU * float(i) / 7.0 + 0.2
		Base._bone(m, Vector3(cos(a) * 0.12, sin(a) * 0.12, 0.26), Vector3(cos(a) * 0.32, sin(a) * 0.32, 0.015), 0.05, 0.035, "bark")
	Base._bone(m, Vector3(0, 0, 0.5), Vector3(0.38, 0.2, 0.92), 0.06, 0.06, "bark")
	Base._bone(m, Vector3(0, 0, 0.5), Vector3(-0.34, -0.22, 0.88), 0.055, 0.055, "bark")
	Base._bone(m, Vector3(0, 0, 0.52), Vector3(-0.2, 0.36, 0.9), 0.05, 0.05, "bark")
	Base._bone(m, Vector3(0, 0, 0.52), Vector3(0.18, -0.38, 0.9), 0.05, 0.05, "bark")
	Base._sp(m, Vector3(0.16, 0.0, 0.22), Vector3(0.03, 0.07, 0.1), "n_hollow")
	Base._sp(m, Vector3(0.13, 0.12, 0.42), Vector3(0.05, 0.07, 0.06), "n_moss")
	var crown: Array = [
		[Vector3(0.0, 0.0, 1.05), 0.44, 0.8], [Vector3(0.4, 0.2, 0.92), 0.32], [Vector3(-0.36, -0.22, 0.9), 0.33],
		[Vector3(-0.22, 0.38, 0.92), 0.3], [Vector3(0.2, -0.4, 0.92), 0.3], [Vector3(0.5, -0.1, 1.02), 0.24],
		[Vector3(-0.5, 0.1, 1.0), 0.24], [Vector3(0.14, 0.12, 1.3), 0.32], [Vector3(-0.2, -0.1, 1.28), 0.28],
		[Vector3(0.3, 0.34, 1.12), 0.26], [Vector3(-0.3, -0.34, 1.1), 0.26],
	]
	_lobes(m, crown, ["leafd", "leaf", "leafl", "leaf"])


# ---- plants and ground cover --------------------------------------------------------------------------

static func _tuft(m: Array[Prim]) -> void:
	for i in 9:
		var a := float(i) * 0.7
		var r := 0.03 + 0.07 * Base._rnd(i, 3)
		var tip := Vector3(cos(a) * (r + 0.07), sin(a) * (r + 0.07), 0.2 + 0.16 * Base._rnd(i, 4))
		Base._bone(m, Vector3(cos(a) * r, sin(a) * r, 0.0), tip, 0.012, 0.012, "n_tuft" if i % 2 == 0 else "n_tuftdry")


## Tall grass: a big dense clump of long arching blades with a dark core.
static func _tall_grass(m: Array[Prim]) -> void:
	Base._sp(m, Vector3(0, 0, 0.1), Vector3(0.17, 0.16, 0.12), "n_tuft")
	_blades(m, Vector3.ZERO, 52, 0.2, 0.3, 0.7, 0.45, ["n_tallgrass", "n_tuft", "n_tuftdry", "n_tallgrass"], 11, 0.012)
	_blades(m, Vector3.ZERO, 18, 0.1, 0.55, 0.85, 0.3, ["n_tallgrass", "n_tuftdry", "n_tuft"], 31, 0.01)


## Reeds: slender stalks with cattail heads standing in a patch of mud and shallow water.
static func _reeds(m: Array[Prim]) -> void:
	_disc(m, Vector3(0, 0, 0.0), 0.4, 0.34, 0.025, "n_mud")
	_disc(m, Vector3(0.1, 0.08, 0.02), 0.26, 0.2, 0.012, "n_water")
	for i in 16:
		var a: float = TAU * Base._rnd(i, 1)
		var r: float = 0.2 * sqrt(Base._rnd(i, 2))
		var base := Vector3(cos(a) * r - 0.04, sin(a) * r - 0.04, 0.0)
		var h: float = 0.65 + 0.4 * Base._rnd(i, 3)
		var la: float = TAU * Base._rnd(i, 4)
		var tip := base + Vector3(cos(la) * 0.12, sin(la) * 0.12, h)
		Base._bone(m, base, tip, 0.013, 0.013, "n_reed" if i % 3 != 0 else "n_tuftdry")
		if i % 4 == 1:
			var up := (tip - base).normalized()
			Base._bone(m, tip - up * 0.1, tip + up * 0.06, 0.026, 0.026, "n_cattail")
	_blades(m, Vector3(-0.05, -0.05, 0.0), 10, 0.16, 0.3, 0.5, 0.5, ["n_tallgrass", "n_reed"], 41, 0.018)


## Fern: a rosette of arching, tapering fronds with leaflet pairs, plus a few upright young fronds.
static func _fern(m: Array[Prim]) -> void:
	Base._sp(m, Vector3(0, 0, 0.06), Vector3(0.1, 0.1, 0.07), "n_fern")
	for i in 11:
		var a: float = TAU * float(i) / 11.0 + 0.2 * Base._rnd(i, 1)
		var d := Vector3(cos(a), sin(a), 0.0)
		var perp := Vector3(-d.y, d.x, 0.0)
		var reach: float = 0.34 + 0.1 * Base._rnd(i, 2)
		var p0 := Vector3(0, 0, 0.07)
		var p1 := d * reach * 0.4 + Vector3(0, 0, 0.19 + 0.05 * Base._rnd(i, 3))
		var p2 := d * reach * 0.8 + Vector3(0, 0, 0.2 + 0.04 * Base._rnd(i, 3))
		var p3 := d * reach * 1.05 + Vector3(0, 0, 0.12)
		var mat: String = "n_fern" if i % 2 == 0 else "n_fernl"
		var mat2: String = "n_fernl" if i % 2 == 0 else "n_fern"
		Base._bone(m, p0, p1, 0.03, 0.01, mat)
		Base._bone(m, p1, p2, 0.035, 0.01, mat)
		Base._bone(m, p2, p3, 0.025, 0.01, mat2)
		for sg in [1.0, -1.0]:
			Base._bone(m, p1, p1 + d * 0.06 + perp * sg * 0.1 + Vector3(0, 0, -0.04), 0.02, 0.008, mat2)
			Base._bone(m, p2, p2 + d * 0.05 + perp * sg * 0.08 + Vector3(0, 0, -0.05), 0.018, 0.008, mat)
	for i in 4:
		var a: float = TAU * float(i) / 4.0 + 0.7
		Base._bone(m, Vector3(0, 0, 0.07), Vector3(cos(a) * 0.1, sin(a) * 0.1, 0.38 + 0.05 * Base._rnd(i, 5)), 0.022, 0.01, "n_fernl")


## Flower patch: low leafy mat with many stems topped by red, yellow, white and violet flower heads.
static func _flower_patch(m: Array[Prim]) -> void:
	Base._sp(m, Vector3(0, 0, 0.04), Vector3(0.26, 0.22, 0.07), "n_tuft")
	Base._sp(m, Vector3(0.08, 0.06, 0.06), Vector3(0.16, 0.14, 0.07), "n_tallgrass")
	var cols: Array = ["n_flr", "n_fly", "n_flw", "n_flp", "n_flr", "n_fly"]
	for i in 16:
		var a: float = TAU * Base._rnd(i, 1)
		var r: float = 0.22 * sqrt(Base._rnd(i, 2))
		var base := Vector3(cos(a) * r, sin(a) * r * 0.9, 0.04)
		var h: float = 0.14 + 0.14 * Base._rnd(i, 3)
		var tip := base + Vector3(cos(a) * 0.03, sin(a) * 0.03, h)
		Base._bone(m, base, tip, 0.008, 0.008, "n_tallgrass")
		Base._sp(m, tip + Vector3(0, 0, 0.012), Vector3(0.036, 0.036, 0.03), cols[i % cols.size()])
		Base._sp(m, tip + Vector3(0, 0, 0.032), Vector3(0.014, 0.014, 0.012), "n_fly" if i % 3 != 1 else "n_flr")


## Mushrooms: a cluster of red-capped toadstools (white spots) and a few brown ones, on a mossy base.
static func _mushrooms(m: Array[Prim]) -> void:
	Base._sp(m, Vector3(0, 0, 0.02), Vector3(0.26, 0.22, 0.04), "n_moss")
	var shrooms: Array = [
		[Vector3(0.0, 0.0, 0.0), 0.2, 0.15, true], [Vector3(0.2, 0.1, 0.0), 0.12, 0.09, true], [Vector3(-0.16, 0.1, 0.0), 0.14, 0.1, false],
		[Vector3(0.06, -0.18, 0.0), 0.1, 0.08, true], [Vector3(-0.1, -0.14, 0.0), 0.08, 0.06, false], [Vector3(0.2, -0.1, 0.0), 0.07, 0.06, false],
	]
	for i in shrooms.size():
		var e: Array = shrooms[i]
		var c: Vector3 = e[0]
		var h: float = e[1]
		var cr: float = e[2]
		var red: bool = e[3]
		Base._cy(m, c + Vector3(0, 0, h * 0.5), cr * 0.28, h * 0.5, "n_mstem")
		Base._sp(m, c + Vector3(0, 0, h), Vector3(cr, cr, cr * 0.62), "n_mcap" if red else "n_mcapb")
		if red:
			for j in 4:
				var a: float = TAU * float(j) / 4.0 + float(i)
				var rr: float = cr * 0.55
				Base._sp(m, c + Vector3(cos(a) * rr, sin(a) * rr, h + cr * 0.48), Vector3(cr * 0.14, cr * 0.14, cr * 0.1), "n_mstem")
			Base._sp(m, c + Vector3(0, 0, h + cr * 0.6), Vector3(cr * 0.16, cr * 0.16, cr * 0.1), "n_mstem")


## Lily pads: a wide low pond patch with floating pads (some notched) and pink lotus flowers.
static func _lily_pads(m: Array[Prim]) -> void:
	_disc(m, Vector3(0, 0, 0.0), 0.5, 0.4, 0.02, "n_mud")
	_disc(m, Vector3(0, 0, 0.012), 0.46, 0.36, 0.02, "n_water")
	var pads: Array = [
		[-0.22, 0.05, 0.12], [0.0, -0.1, 0.14], [0.2, 0.08, 0.11], [-0.05, 0.16, 0.1], [0.28, -0.12, 0.09], [-0.28, -0.12, 0.09], [0.08, 0.22, 0.07],
	]
	for i in pads.size():
		var e: Array = pads[i]
		var x: float = e[0]
		var y: float = e[1]
		var r: float = e[2]
		var mat: String = "n_pad" if i % 2 == 0 else "n_padd"
		Base._cy(m, Vector3(x, y, 0.03), r, 0.008, mat)
		Base._bx(m, Vector3(x + r * 0.5, y, 0.04), Vector3(r * 0.5, 0.012, 0.004), "n_water", 0.6 * float(i))
	for p in [[-0.02, -0.1], [0.22, 0.08]]:
		var c := Vector3(p[0], p[1], 0.05)
		for j in 5:
			var a: float = TAU * float(j) / 5.0
			Base._sp(m, c + Vector3(cos(a) * 0.04, sin(a) * 0.04, 0.02), Vector3(0.035, 0.035, 0.03), "n_lotus")
		Base._sp(m, c + Vector3(0, 0, 0.05), Vector3(0.03, 0.03, 0.03), "n_fly")


## Berry bush: dense leafy mound dotted with ripe berries sitting on the lobe surfaces.
static func _berry_bush(m: Array[Prim]) -> void:
	var lobes: Array = [
		[Vector3(0, 0, 0.16), 0.24, 0.7], [Vector3(0.14, 0.1, 0.2), 0.17, 0.8], [Vector3(-0.12, -0.08, 0.22), 0.17, 0.8],
		[Vector3(-0.06, 0.14, 0.2), 0.15, 0.8], [Vector3(0.1, -0.14, 0.18), 0.15, 0.8], [Vector3(0.02, -0.02, 0.32), 0.12, 0.8],
	]
	_lobes(m, lobes, ["leafd", "leaf", "leafl"])
	for i in lobes.size():
		var e: Array = lobes[i]
		var c: Vector3 = e[0]
		var r: float = e[1]
		var sq: float = e[2]
		for j in 3:
			var a: float = -0.4 + 2.4 * Base._rnd(i * 3 + j, 1)
			var el: float = 0.15 + 0.8 * Base._rnd(i * 3 + j, 2)
			var p := c + Vector3(cos(a) * cos(el) * r, sin(a) * cos(el) * r, sin(el) * r * sq * 0.96)
			Base._sp(m, p, Vector3(0.036, 0.036, 0.036), "n_berry")


## Thorn bush: dry dark tangle bristling with spikes in every direction.
static func _thorn_bush(m: Array[Prim]) -> void:
	Base._sp(m, Vector3(0, 0, 0.14), Vector3(0.17, 0.16, 0.12), "n_thornd")
	for i in 30:
		var a: float = TAU * Base._rnd(i, 1)
		var el: float = -0.1 + 1.4 * Base._rnd(i, 2)
		var L: float = 0.22 + 0.14 * Base._rnd(i, 3)
		var c := Vector3(0, 0, 0.14)
		var tip := c + Vector3(cos(a) * cos(el) * L, sin(a) * cos(el) * L, sin(el) * L)
		Base._bone(m, c, tip, 0.016, 0.016, "n_thorn" if i % 3 != 0 else "n_thornd")
		if i % 2 == 0:
			var mid := c + (tip - c) * 0.55
			var a2: float = a + 0.9
			Base._bone(m, mid, mid + Vector3(cos(a2) * 0.1, sin(a2) * 0.1, 0.08), 0.01, 0.01, "n_thorn")
	for i in 5:
		var a: float = TAU * float(i) / 5.0 + 0.5
		Base._sp(m, Vector3(cos(a) * 0.18, sin(a) * 0.18, 0.02), Vector3(0.04, 0.03, 0.015), "n_tuftdry")


## Tumbleweed: a loose ball of criss-crossing dry stems.
static func _dry_bush(m: Array[Prim]) -> void:
	var c := Vector3(0, 0, 0.25)
	Base._sp(m, c, Vector3(0.11, 0.11, 0.1), "n_dryb")
	for i in 34:
		var a: float = TAU * Base._rnd(i, 1)
		var el: float = asin(2.0 * Base._rnd(i, 2) - 1.0)
		var a2: float = a + PI * (0.7 + 0.6 * Base._rnd(i, 3))
		var el2: float = asin(2.0 * Base._rnd(i, 4) - 1.0)
		var r: float = 0.23
		var p0 := c + Vector3(cos(a) * cos(el), sin(a) * cos(el), sin(el)) * r
		var p1 := c + Vector3(cos(a2) * cos(el2), sin(a2) * cos(el2), sin(el2)) * r
		Base._bone(m, p0, p1, 0.011, 0.011, "n_dryb")
	for i in 5:
		var a: float = TAU * float(i) / 5.0
		Base._bone(m, Vector3(cos(a) * 0.1, sin(a) * 0.1, 0.1), Vector3(cos(a) * 0.2, sin(a) * 0.2, 0.2), 0.012, 0.012, "n_thornd")


## Cactus (saguaro): ribbed trunk, domed top, two up-curved arms, a small red flower.
static func _cactus(m: Array[Prim]) -> void:
	Base._cy(m, Vector3(0, 0, 0.42), 0.085, 0.42, "n_cactus")
	Base._sp(m, Vector3(0, 0, 0.84), Vector3(0.085, 0.085, 0.09), "n_cactus")
	for i in 10:
		var a: float = TAU * float(i) / 10.0
		Base._bx(m, Vector3(cos(a) * 0.082, sin(a) * 0.082, 0.42), Vector3(0.008, 0.005, 0.4), "n_cactusd", a)
	# right arm (+y side) and left arm (-y side)
	for s in [1.0, -1.0]:
		var z0: float = 0.34 if s > 0.0 else 0.5
		var up: float = 0.3 if s > 0.0 else 0.22
		Base._bone(m, Vector3(0, s * 0.06, z0), Vector3(0.02, s * 0.22, z0), 0.05, 0.05, "n_cactus")
		Base._cy(m, Vector3(0.02, s * 0.25, z0 + up * 0.5 + 0.02), 0.05, up * 0.5 + 0.03, "n_cactus")
		Base._sp(m, Vector3(0.02, s * 0.25, z0 + up + 0.06), Vector3(0.05, 0.05, 0.06), "n_cactus")
		Base._bx(m, Vector3(0.07, s * 0.25, z0 + up * 0.5 + 0.02), Vector3(0.006, 0.006, up * 0.5), "n_cactusd")
	Base._sp(m, Vector3(0.02, 0, 0.94), Vector3(0.04, 0.04, 0.03), "n_lotus")
	Base._sp(m, Vector3(0.02, 0, 0.965), Vector3(0.02, 0.02, 0.02), "n_fly")


## Branch pile: crisscrossed fallen branches stacked low with a few twigs; mirror differs between se and sw.
static func _branch_pile(m: Array[Prim]) -> void:
	var mats: Array = ["bark", "wood", "woodd", "deadwood", "bark"]
	for i in 11:
		var a: float = PI * Base._rnd(i, 1)
		var L: float = 0.26 + 0.2 * Base._rnd(i, 2)
		var off := Vector3(0.22 * (Base._rnd(i, 3) - 0.5), 0.22 * (Base._rnd(i, 4) - 0.5), 0.0)
		var z: float = 0.04 + 0.022 * float(i)
		var d := Vector3(cos(a), sin(a), 0.0)
		var th: float = 0.022 + 0.014 * Base._rnd(i, 5)
		Base._bone(m, off - d * L + Vector3(0, 0, z - 0.02), off + d * L + Vector3(0, 0, z + 0.05 * Base._rnd(i, 6)), th, th, mats[i % mats.size()])
		if i % 3 == 0:
			var a2: float = a + 0.6
			var mid := off + d * L * 0.3 + Vector3(0, 0, z)
			Base._bone(m, mid, mid + Vector3(cos(a2) * 0.14, sin(a2) * 0.14, 0.06), 0.01, 0.01, mats[(i + 1) % mats.size()])
	Base._sp(m, Vector3(-0.12, 0.2, 0.01), Vector3(0.06, 0.05, 0.015), "n_tuftdry")
	Base._sp(m, Vector3(0.2, -0.18, 0.01), Vector3(0.05, 0.04, 0.014), "n_moss")


# ---- rocks and landforms ------------------------------------------------------------------------------

static func _mossy_boulder(m: Array[Prim]) -> void:
	Base._sp(m, Vector3(0, 0, 0.17), Vector3(0.3, 0.26, 0.2), "stone")
	Base._sp(m, Vector3(0.1, 0.12, 0.26), Vector3(0.15, 0.13, 0.12), "stonel")
	Base._sp(m, Vector3(-0.08, -0.02, 0.33), Vector3(0.2, 0.17, 0.07), "n_moss")
	Base._sp(m, Vector3(0.2, -0.12, 0.12), Vector3(0.1, 0.08, 0.06), "n_moss")


## Slate outcrop: stacked thin rotated slabs in two tones plus a leaning slab and a chip of scree.
static func _slate(m: Array[Prim]) -> void:
	var slabs: Array = [
		[Vector3(0.0, 0.0, 0.05), Vector3(0.4, 0.31, 0.05), 0.2], [Vector3(0.03, -0.02, 0.15), Vector3(0.34, 0.27, 0.045), -0.15],
		[Vector3(-0.04, 0.02, 0.24), Vector3(0.28, 0.23, 0.045), 0.32], [Vector3(0.0, 0.0, 0.33), Vector3(0.2, 0.17, 0.04), -0.1],
		[Vector3(-0.02, 0.0, 0.4), Vector3(0.12, 0.1, 0.035), 0.4],
	]
	for i in slabs.size():
		var e: Array = slabs[i]
		Base._bx(m, e[0], e[1], "n_slate" if i % 2 == 0 else "n_slatel", e[2])
	Base._bone(m, Vector3(0.26, 0.2, 0.02), Vector3(0.16, 0.12, 0.42), 0.12, 0.035, "n_slatel")
	Base._bone(m, Vector3(-0.3, -0.22, 0.02), Vector3(-0.2, -0.14, 0.26), 0.09, 0.03, "n_slate")
	Base._bx(m, Vector3(0.38, -0.2, 0.025), Vector3(0.08, 0.06, 0.025), "n_slate", 0.6)
	Base._bx(m, Vector3(-0.1, 0.34, 0.02), Vector3(0.06, 0.05, 0.02), "n_slatel", 0.2)
	Base._sp(m, Vector3(-0.3, 0.2, 0.01), Vector3(0.07, 0.06, 0.02), "n_tuft")


## Cliff chunk: a 4x4 grid of rough rock columns rising toward the back, grassy top, scree at the foot.
static func _cliff(m: Array[Prim]) -> void:
	var mats: Array = ["n_cliff", "n_cliffl", "stone", "n_cliff", "n_cliffl"]
	for ix in 4:
		for iy in 4:
			var x: float = -0.45 + 0.3 * float(ix)
			var y: float = -0.45 + 0.3 * float(iy)
			var back: float = clampf((-x - y) / 0.9 * 0.5 + 0.5, 0.0, 1.0)
			var seed_i: int = ix * 4 + iy
			var h: float = 0.28 + 0.55 * back + 0.14 * Base._rnd(seed_i, 1)
			var j := Vector3(0.04 * (Base._rnd(seed_i, 2) - 0.5), 0.04 * (Base._rnd(seed_i, 3) - 0.5), 0.0)
			Base._bx(m, Vector3(x, y, h * 0.5) + j, Vector3(0.17, 0.17, h * 0.5), mats[(ix + iy * 2) % mats.size()], 0.3 * (Base._rnd(seed_i, 4) - 0.5))
			if h > 0.78:
				Base._bx(m, Vector3(x, y, h + 0.01) + j, Vector3(0.17, 0.17, 0.014), "n_tuft")
	Base._sp(m, Vector3(-0.35, -0.38, 0.9), Vector3(0.14, 0.12, 0.05), "n_tuft")
	Base._sp(m, Vector3(-0.1, -0.5, 0.82), Vector3(0.1, 0.08, 0.04), "n_tuftdry")
	for i in 5:
		var a: float = float(i) * 0.7 + 0.1
		var rx: float = 0.66 + 0.08 * Base._rnd(i, 1)
		Base._sp(m, Vector3(cos(a) * rx * 0.9 + 0.1, sin(a) * rx * 0.9 + 0.1, 0.05), Vector3(0.1, 0.09, 0.07), "stone" if i % 2 == 0 else "stonel")


## Sand dune: one big smooth mound with wind ripples running along its length (dark lines hugging the surface).
static func _dune(m: Array[Prim]) -> void:
	var rx := 0.8
	var ry := 0.44
	var rz := 0.3
	Base._sp(m, Vector3(0, 0, 0.0), Vector3(rx, ry, rz), "n_dune")
	Base._sp(m, Vector3(-0.1, -0.08, 0.0), Vector3(rx * 0.72, ry * 0.6, rz * 1.04), "n_dunel")
	for k in 9:
		var y: float = -0.3 + 0.075 * float(k)
		var lim: float = 0.93 * rx * sqrt(maxf(0.0, 1.0 - pow(y / ry, 2.0))) * 0.9
		var prev := Vector3.ZERO
		for q in 7:
			var x: float = -lim + 2.0 * lim * float(q) / 6.0 + 0.05 * sin(float(q) * 2.0 + float(k))
			var zz: float = rz * sqrt(maxf(0.0, 1.0 - pow(x / rx, 2.0) - pow(y / ry, 2.0))) + 0.006
			var pt := Vector3(x, y + 0.012 * sin(float(q) * 1.7 + float(k) * 2.0), zz)
			if q > 0:
				Base._bone(m, prev, pt, 0.012, 0.008, "n_dunesh")
			prev = pt
	Base._sp(m, Vector3(0.5, 0.3, 0.02), Vector3(0.05, 0.04, 0.03), "n_tuftdry")
	Base._sp(m, Vector3(-0.58, 0.22, 0.02), Vector3(0.06, 0.05, 0.03), "stonel")
	_blades(m, Vector3(0.5, 0.3, 0.0), 6, 0.04, 0.1, 0.22, 0.3, ["n_tuftdry"], 21, 0.01)


## Snow mound: irregular heaped drift with a rock tip and a few dry grass stalks poking out.
static func _snow_mound(m: Array[Prim]) -> void:
	Base._sp(m, Vector3(0, 0, 0.0), Vector3(0.42, 0.32, 0.14), "n_snow")
	Base._sp(m, Vector3(0.1, 0.06, 0.0), Vector3(0.26, 0.2, 0.22), "n_snow")
	Base._sp(m, Vector3(-0.2, -0.1, 0.0), Vector3(0.22, 0.17, 0.17), "n_snow")
	Base._sp(m, Vector3(-0.02, 0.2, 0.0), Vector3(0.24, 0.12, 0.1), "n_snow")
	Base._sp(m, Vector3(0.3, -0.12, 0.0), Vector3(0.16, 0.12, 0.09), "n_snow")
	Base._sp(m, Vector3(-0.14, 0.0, 0.1), Vector3(0.12, 0.1, 0.12), "n_snow")
	Base._sp(m, Vector3(0.2, 0.14, 0.14), Vector3(0.09, 0.07, 0.06), "stone")
	Base._sp(m, Vector3(0.26, 0.18, 0.1), Vector3(0.06, 0.05, 0.05), "stonel")
	_blades(m, Vector3(-0.3, -0.18, 0.1), 6, 0.04, 0.12, 0.22, 0.35, ["n_tuftdry"], 51, 0.01)


## Ice chunk: jagged pale-blue blocks and leaning shards with bright top edges, a little snow at the base.
static func _ice(m: Array[Prim]) -> void:
	Base._sp(m, Vector3(0, 0, 0.0), Vector3(0.4, 0.34, 0.04), "n_snow")
	Base._bx(m, Vector3(0.0, 0.0, 0.17), Vector3(0.24, 0.2, 0.17), "n_ice", 0.3)
	Base._bx(m, Vector3(0.0, 0.0, 0.35), Vector3(0.17, 0.14, 0.014), "n_icel", 0.3)
	Base._bx(m, Vector3(0.22, 0.16, 0.12), Vector3(0.14, 0.12, 0.12), "n_icel", -0.4)
	Base._bx(m, Vector3(-0.2, -0.16, 0.14), Vector3(0.13, 0.12, 0.14), "n_ice", 0.8)
	Base._bx(m, Vector3(-0.2, -0.16, 0.285), Vector3(0.1, 0.09, 0.012), "n_icel", 0.8)
	Base._bone(m, Vector3(0.0, 0.0, 0.2), Vector3(0.05, 0.02, 0.62), 0.09, 0.06, "n_icel")
	Base._bone(m, Vector3(0.05, 0.02, 0.5), Vector3(0.07, 0.03, 0.72), 0.04, 0.03, "n_ice")
	Base._bone(m, Vector3(-0.1, 0.12, 0.1), Vector3(-0.16, 0.2, 0.46), 0.07, 0.045, "n_ice")
	Base._bone(m, Vector3(0.18, -0.16, 0.08), Vector3(0.24, -0.22, 0.34), 0.06, 0.04, "n_icel")
	Base._sp(m, Vector3(0.0, -0.3, 0.02), Vector3(0.12, 0.08, 0.04), "n_snow")
	Base._bx(m, Vector3(0.32, -0.02, 0.04), Vector3(0.06, 0.05, 0.04), "n_ice", 0.5)


## Rock spire: tall twisting stack of shrinking slabs ending in a point, with leaning blades and scree.
static func _spire(m: Array[Prim]) -> void:
	var mats: Array = ["stone", "stonel", "n_cliff", "stonel"]
	var steps := 12
	for i in steps:
		var t: float = float(i) / float(steps)
		var hw: float = 0.23 * pow(1.0 - t, 0.85) + 0.02
		var z: float = 0.07 + 0.11 * float(i)
		Base._bx(m, Vector3(0.012 * float(i % 3), -0.01 * float(i % 2), z), Vector3(hw, hw * 0.88, 0.065), mats[i % mats.size()], 0.22 * float(i))
	Base._sp(m, Vector3(0.0, 0.0, 1.38), Vector3(0.025, 0.025, 0.06), "stonel")
	Base._bone(m, Vector3(0.24, 0.1, 0.04), Vector3(0.05, 0.02, 0.85), 0.07, 0.05, "n_cliffl")
	Base._bone(m, Vector3(-0.22, -0.12, 0.04), Vector3(-0.04, -0.02, 0.62), 0.07, 0.05, "stone")
	Base._bone(m, Vector3(0.1, -0.22, 0.04), Vector3(0.03, -0.04, 0.45), 0.06, 0.04, "n_cliff")
	for i in 5:
		var a: float = float(i) * 1.3 + 0.2
		var r: float = 0.27 + 0.08 * Base._rnd(i, 1)
		Base._sp(m, Vector3(cos(a) * r, sin(a) * r, 0.05), Vector3(0.09, 0.08, 0.07), "stonel" if i % 2 == 0 else "stone")


## Boulder pair: a big faceted grey boulder with a smaller brown-grey one beside it, tufts of grass between.
static func _boulder_pair(m: Array[Prim]) -> void:
	Base._sp(m, Vector3(-0.12, -0.06, 0.18), Vector3(0.3, 0.27, 0.2), "stone")
	Base._bx(m, Vector3(-0.08, -0.02, 0.2), Vector3(0.19, 0.16, 0.19), "stonel", 0.55)
	Base._sp(m, Vector3(-0.2, 0.12, 0.2), Vector3(0.15, 0.13, 0.15), "stone")
	Base._sp(m, Vector3(0.08, -0.14, 0.12), Vector3(0.14, 0.12, 0.12), "stonel")
	Base._sp(m, Vector3(0.3, 0.2, 0.11), Vector3(0.17, 0.15, 0.12), "n_cliff")
	Base._bx(m, Vector3(0.32, 0.22, 0.12), Vector3(0.1, 0.09, 0.11), "n_cliffl", 0.3)
	Base._bx(m, Vector3(0.06, 0.34, 0.04), Vector3(0.08, 0.06, 0.05), "stone", 0.5)
	Base._sp(m, Vector3(0.14, 0.08, 0.02), Vector3(0.1, 0.08, 0.03), "n_tuft")
	Base._sp(m, Vector3(-0.2, -0.12, 0.34), Vector3(0.08, 0.06, 0.03), "n_moss")
