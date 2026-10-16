extends SceneTree
## Dev tool (not a test). Paints the terrain atlas `assets/tiles/terrain.png`: 4 look-variants (columns) for each
## terrain (rows, in TerrainCatalog order), every tile a 64x32 isometric diamond. Pure per-pixel noise, ground-plane
## patterns (u along ground x, v along ground y, so seams and lines meet the neighbouring tile) and a few hand-placed
## features per variant, deterministic, original art. The first seven terrains are the original look, the rest were
## added by docs/specs/art-pack-2.md.
## Run: godot --headless --path . --script tools/gen_tiles.gd

const TW := 64
const TH := 32
const VARIANTS := 4
var ROWS: PackedStringArray = TerrainCatalog.ids()


static func _h(x: int, y: int, seed_v: int) -> float:
	var n: int = x * 374761393 + y * 668265263 + seed_v * 2147483647
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 0xffff) / 65535.0


## Smooth value noise at a given cell size (px).
static func _vn(x: float, y: float, size: float, seed_v: int) -> float:
	var gx := x / size
	var gy := y / size
	var x0 := floori(gx)
	var y0 := floori(gy)
	var fx := gx - float(x0)
	var fy := gy - float(y0)
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	var a := _h(x0, y0, seed_v)
	var b := _h(x0 + 1, y0, seed_v)
	var c := _h(x0, y0 + 1, seed_v)
	var d := _h(x0 + 1, y0 + 1, seed_v)
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)


static func _ramp(t: float, dark: Color, mid: Color, light: Color) -> Color:
	t = clampf(t, 0.0, 1.0)
	return dark.lerp(mid, t * 2.0) if t < 0.5 else mid.lerp(light, (t - 0.5) * 2.0)


static func _in_diamond(x: int, y: int) -> bool:
	return absf(float(x) + 0.5 - 32.0) / 32.0 + absf(float(y) + 0.5 - 16.0) / 16.0 <= 1.0


func _initialize() -> void:
	var atlas := Image.create(TW * VARIANTS, TH * ROWS.size(), false, Image.FORMAT_RGBA8)
	atlas.fill(Color(0, 0, 0, 0))
	for r in ROWS.size():
		for v in VARIANTS:
			var tile := _paint(ROWS[r], v)
			atlas.blit_rect(tile, Rect2i(0, 0, TW, TH), Vector2i(v * TW, r * TH))
	DirAccess.make_dir_recursive_absolute("res://assets/tiles")
	var err := atlas.save_png("res://assets/tiles/terrain.png")
	print("%s assets/tiles/terrain.png (%dx%d)" % ["wrote" if err == OK else "FAILED", atlas.get_width(), atlas.get_height()])
	quit()


func _paint(terrain: String, v: int) -> Image:
	var img := Image.create(TW, TH, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var seed_v := ROWS.find(terrain) * 17 + v * 5 + 3
	for y in TH:
		for x in TW:
			if not _in_diamond(x, y):
				continue
			img.set_pixel(x, y, _pixel(terrain, v, x, y, seed_v))
	_features(img, terrain, v, seed_v)
	return img


func _pixel(terrain: String, v: int, x: int, y: int, s: int) -> Color:
	var fx := float(x)
	var fy := float(y) * 2.0  # sample in ground-ish space so the texture is not squashed
	var n1 := _vn(fx, fy, 14.0, s)
	var n2 := _vn(fx, fy, 5.0, s + 1)
	var n3 := _h(x, y, s + 2)
	match terrain:
		"grass":
			var t := n1 * 0.45 + n2 * 0.35 + n3 * 0.2
			var c := _ramp(t, Color("446f35"), Color("56823f"), Color("6e9a52"))
			if v == 3:  # dry patches
				var dry := smoothstep(0.52, 0.7, _vn(fx, fy, 11.0, s + 9))
				c = c.lerp(Color("8a8f48"), dry * 0.75)
			return c
		"road":
			var t2 := n1 * 0.3 + n2 * 0.3 + n3 * 0.4
			var c2 := _ramp(t2, Color("5f5e5c"), Color("6e6d6a"), Color("807f7a"))
			if v == 3:  # oil stain
				c2 = c2.lerp(Color("4a4949"), smoothstep(0.55, 0.75, _vn(fx, fy, 12.0, s + 4)) * 0.5)
			return c2
		"rock":
			var t3 := n1 * 0.5 + n2 * 0.3 + n3 * 0.2
			return _ramp(t3, Color("3c3d44"), Color("4c4d55"), Color("66676f"))
		"dirt":
			var t4 := n1 * 0.4 + n2 * 0.3 + n3 * 0.3
			var c4 := _ramp(t4, Color("6d5233"), Color("80613c"), Color("98774a"))
			if v == 3:  # damp patch
				c4 = c4.lerp(Color("4f3b25"), smoothstep(0.5, 0.72, _vn(fx, fy, 10.0, s + 6)) * 0.7)
			return c4
		"paved":
			var t5 := n1 * 0.2 + n2 * 0.2 + n3 * 0.6
			var c5 := _ramp(t5, Color("85857f"), Color("92928b"), Color("a2a29a"))
			if v == 3:  # stained slab
				c5 = c5.lerp(Color("7a786f"), smoothstep(0.55, 0.75, _vn(fx, fy, 13.0, s + 8)) * 0.5)
			return c5
		"rubble":
			var t6 := n1 * 0.3 + n2 * 0.3 + n3 * 0.4
			return _ramp(t6, Color("45423d"), Color("5d5a53"), Color("77746b"))
		"water":
			var t7 := n1 * 0.6 + n2 * 0.4
			return _ramp(t7, Color("27546f"), Color("2f6785"), Color("3f7f9c"))
	return _pixel_new(terrain, v, x, y, s, n1, n2, n3)


func _dot(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < TW and y < TH and _in_diamond(x, y):
		img.set_pixel(x, y, c)


func _features(img: Image, terrain: String, v: int, s: int) -> void:
	if ROWS.find(terrain) >= 7:
		_features_new(img, terrain, v, s)
		return
	match terrain:
		"grass":
			var tufts: int = [0, 14, 8, 6][v]
			for i in tufts:
				var x := 6 + int(_h(i, 1, s + 20) * (TW - 12))
				var y := 4 + int(_h(i, 2, s + 20) * (TH - 8))
				var dark := Color("3c6330")
				var light := Color("7fb35e")
				_dot(img, x, y, dark)
				_dot(img, x, y - 1, light)
				_dot(img, x + 1, y - 2, light)
			if v == 2:  # flowers
				for i in 9:
					var x := 8 + int(_h(i, 3, s + 30) * (TW - 16))
					var y := 5 + int(_h(i, 4, s + 30) * (TH - 10))
					var col: Color = [Color("e9e3c4"), Color("e8c84a"), Color("d8789a"), Color("f2f2ee")][i % 4]
					_dot(img, x, y, col)
		"road":
			if v == 1 or v == 2:  # cracks (v 1) and a patched repair (v 2)
				if v == 1:
					var x := 14 + int(_h(0, 0, s) * 10)
					var y := 8
					for i in 26:
						_dot(img, x, y, Color("34332f"))
						x += 1 if _h(i, 1, s + 40) > 0.35 else 0
						y += 1 if _h(i, 2, s + 40) > 0.62 else 0
						if y > 24:
							break
				else:
					for yy in range(10, 20):
						for xx in range(22, 42):
							if _in_diamond(xx, yy):
								var px := img.get_pixel(xx, yy)
								img.set_pixel(xx, yy, px.darkened(0.14))
		"rock":
			for i in [3, 5, 4, 6][v]:
				var cx := 10 + int(_h(i, 5, s + 50) * 44.0)
				var cy := 6 + int(_h(i, 6, s + 50) * 20.0)
				var r := 2 + int(_h(i, 7, s + 50) * 3.0)
				for yy in range(-r, r + 1):
					for xx in range(-r * 2, r * 2 + 1):
						if float(xx * xx) / float(4 * r * r) + float(yy * yy) / float(r * r) <= 1.0:
							var lit := (xx + yy * 2) < 0
							_dot(img, cx + xx, cy + yy, Color("7d7e86") if lit else Color("34353c"))
		"dirt":
			var pebbles: int = [0, 10, 4, 5][v]
			for i in pebbles:
				var x := 7 + int(_h(i, 8, s + 60) * (TW - 14))
				var y := 5 + int(_h(i, 9, s + 60) * (TH - 10))
				_dot(img, x, y, Color("a89880"))
				_dot(img, x + 1, y, Color("5b4a36"))
			if v == 2:  # tyre ruts
				for i in 30:
					_dot(img, 10 + i * 2, 20 - i / 2, Color("4a3a26"))
					_dot(img, 10 + i * 2, 23 - i / 2, Color("4a3a26"))
		"paved":
			# Slab seams: one line along each ground axis through the middle of the tile.
			for i in 64:
				var xa := i
				var ya := 8 + i / 2
				_dot(img, xa, ya, Color("5f5f59"))
				_dot(img, xa, 24 - i / 2, Color("5f5f59"))
			if v == 1:
				var x := 20
				var y := 9
				for i in 22:
					_dot(img, x, y, Color("3f3f3a"))
					x += 1
					y += 1 if _h(i, 4, s + 70) > 0.5 else 0
		"rubble":
			for i in [14, 18, 12, 20][v]:
				var cx := 8 + int(_h(i, 10, s + 80) * 48.0)
				var cy := 4 + int(_h(i, 11, s + 80) * 24.0)
				var w := 1 + int(_h(i, 12, s + 80) * 3.0)
				var col := Color("8a867c") if _h(i, 13, s + 80) > 0.5 else Color("5c5850")
				for yy in 2:
					for xx in w + 1:
						_dot(img, cx + xx, cy + yy, col)
				_dot(img, cx, cy + 2, Color("2e2c28"))
			if v == 3:  # rebar
				for i in 12:
					_dot(img, 24 + i, 14 - i / 3, Color("6b3a22"))
		"water":
			for i in [5, 8, 6, 9][v]:
				var cx := 8 + int(_h(i, 14, s + 90) * 40.0)
				var cy := 6 + int(_h(i, 15, s + 90) * 20.0)
				for k in 6:
					_dot(img, cx + k, cy + (k % 2), Color("8fc3d9"))


# ---- terrains added by art pack 2 ---------------------------------------------------------------------------

## Ground-plane coordinates of a pixel in the tile: u along ground +x (screen down-right), v along ground +y
## (screen down-left), both 0..1 across the cell.
static func _uv(x: int, y: int) -> Vector2:
	var sx := float(x) + 0.5
	var sy := float(y) + 0.5
	return Vector2(clampf((sy / 16.0 + (sx - 32.0) / 32.0) * 0.5, 0.0, 1.0), clampf((sy / 16.0 - (sx - 32.0) / 32.0) * 0.5, 0.0, 1.0))


## Per-pixel base colour of the terrains after the original seven. n1..n3 are the noise samples `_pixel` made.
func _pixel_new(t: String, v: int, x: int, y: int, s: int, n1: float, n2: float, n3: float) -> Color:
	var uv := _uv(x, y)
	var u := uv.x
	var g := uv.y
	var fx := float(x)
	var fy := float(y) * 2.0
	match t:
		"meadow":
			var c := _ramp(n1 * 0.4 + n2 * 0.35 + n3 * 0.25, Color("3f6b2c"), Color("4f7e36"), Color("6ea34a"))
			if v == 3:
				c = c.lerp(Color("8fae4e"), smoothstep(0.5, 0.7, _vn(fx, fy, 12.0, s + 9)) * 0.7)
			return c
		"dry_grass":
			var c := _ramp(n1 * 0.4 + n2 * 0.3 + n3 * 0.3, Color("7d7a3c"), Color("98914a"), Color("b8ae62"))
			if v == 3:
				c = c.lerp(Color("8a7048"), smoothstep(0.5, 0.7, _vn(fx, fy, 11.0, s + 9)) * 0.8)
			return c
		"leaf_litter":
			var c := _ramp(n1 * 0.4 + n2 * 0.3 + n3 * 0.3, Color("5b4527"), Color("6e5430"), Color("86683a"))
			if v == 3:
				c = c.lerp(Color("3f301c"), smoothstep(0.5, 0.72, _vn(fx, fy, 10.0, s + 6)) * 0.7)
			return c
		"moss":
			var c := _ramp(n1 * 0.4 + n2 * 0.3 + n3 * 0.3, Color("2f4d2b"), Color("3f6a38"), Color("58884a"))
			if v == 3:
				c = c.lerp(Color("26402a"), smoothstep(0.5, 0.72, _vn(fx, fy, 10.0, s + 6)) * 0.7)
			return c
		"mud":
			var c := _ramp(n1 * 0.4 + n2 * 0.3 + n3 * 0.3, Color("4a3624"), Color("5c452d"), Color("735838"))
			var thr: float = [0.95, 0.68, 0.58, 0.5][v]
			var puddle := smoothstep(thr, thr + 0.1, _vn(fx, fy, 9.0, s + 5))
			if puddle > 0.0:
				var wc := _ramp(n2, Color("56646b"), Color("6c7c83"), Color("8a9aa0"))
				c = c.lerp(wc, puddle * 0.85)
			return c
		"sand":
			var c := _ramp(n1 * 0.3 + n2 * 0.3 + n3 * 0.4, Color("c9b27a"), Color("d9c48c"), Color("ebd9a5"))
			var rip := sin((g * 14.0 + _vn(fx, fy, 22.0, s) * 3.0) * PI)
			if rip > 0.82:
				c = c.darkened(0.09)
			return c
		"snow":
			var c := _ramp(n1 * 0.3 + n2 * 0.3 + n3 * 0.4, Color("c3d0dc"), Color("dfe9f2"), Color("f6fafd"))
			if n3 > 0.94:
				c = Color("ffffff")
			if v == 2:
				c = c.lerp(Color("a9b4be"), smoothstep(0.55, 0.75, _vn(fx, fy, 12.0, s + 7)) * 0.6)
			if v == 3:
				c = c.lerp(Color("9cb2c4"), smoothstep(0.5, 0.7, _vn(fx, fy, 10.0, s + 8)) * 0.7)
			return c
		"ice":
			var c := _ramp(n1 * 0.5 + n2 * 0.3 + n3 * 0.2, Color("9fc4d8"), Color("b8dcec"), Color("dff3fa"))
			var band := smoothstep(0.55, 0.8, _vn(fx * 0.6, fy * 1.4, 18.0, s + 3))
			return c.lerp(Color("eef9fd"), band * 0.5)
		"gravel":
			return _ramp(n1 * 0.15 + n2 * 0.15 + n3 * 0.7, Color("6f6a64"), Color("857f77"), Color("a09a90"))
		"asphalt", "lane_x", "lane_y", "cracked_asphalt":
			var c := _ramp(n1 * 0.2 + n2 * 0.2 + n3 * 0.6, Color("3d3d40"), Color("48484c"), Color("57575b"))
			if t == "cracked_asphalt":
				c = c.lerp(Color("525256"), smoothstep(0.55, 0.75, _vn(fx, fy, 12.0, s + 2)) * 0.4)
			elif v == 2 and t == "asphalt":
				c = c.lerp(Color("37373a"), smoothstep(0.55, 0.72, _vn(fx, fy, 13.0, s + 4)) * 0.55)
			elif v == 3 and t == "asphalt":
				c = c.lerp(Color("5c5c60"), smoothstep(0.5, 0.7, _vn(fx, fy, 12.0, s + 5)) * 0.4)
			if t == "lane_x" or t == "lane_y":
				var along := u if t == "lane_x" else g
				var across := absf(g - 0.5) if t == "lane_x" else absf(u - 0.5)
				if along > 0.12 and along < 0.88:
					var white := Color("d9d9d2")
					var yellow := Color("d8b32c")
					var worn := v == 3 and _h(x, y, s + 11) < 0.35
					if v == 0 and across < 0.04:
						c = white
					elif v == 1 and across < 0.04:
						c = yellow
					elif v == 2 and across > 0.025 and across < 0.07:
						c = yellow
					elif v == 3 and across < 0.04 and not worn:
						c = white.darkened(0.12)
			return c
		"cobble":
			var rv := g * 6.0
			var row := floori(rv)
			var off := 0.5 if row % 2 == 1 else 0.0
			var cu := u * 5.0 + off
			var col := floori(cu)
			var fu := cu - float(col)
			var fv := rv - float(row)
			var sh := _h(posmod(col, 5), row, s + 12)
			var base := _ramp(sh * 0.7 + n3 * 0.3, Color("5f5c57"), Color("77746d"), Color("97948b"))
			if fu < 0.1 or fu > 0.92 or fv < 0.12 or fv > 0.9:
				return Color("3a3834")
			if fv < 0.25 or fu < 0.2:
				return base.lightened(0.08)
			return base
		"brick":
			var rv := g * 8.0
			var row := floori(rv)
			var off := 0.5 if row % 2 == 1 else 0.0
			var cu := u * 4.0 + off
			var col := floori(cu)
			var fu := cu - float(col)
			var fv := rv - float(row)
			var sh := _h(posmod(col, 4), row, s + 13)
			var base := _ramp(sh, Color("7a3d2e"), Color("8f4c39"), Color("a95e47"))
			if v == 3:
				base = base.lerp(Color("5a5047"), 0.4)
			if fu < 0.07 or fu > 0.95 or fv < 0.14 or fv > 0.92:
				return Color("a79f90")
			return base
		"concrete_tile":
			var si := (1 if u >= 0.5 else 0) + (2 if g >= 0.5 else 0)
			var shade := _h(si, 1, s + 14)
			var c := _ramp(n3 * 0.5 + shade * 0.5, Color("959790"), Color("a2a49e"), Color("b3b5ae"))
			if absf(u - 0.5) < 0.014 or absf(g - 0.5) < 0.014:
				return Color("6f716c")
			if v == 1:
				c = c.lerp(Color("7a7c72"), smoothstep(0.55, 0.75, _vn(fx, fy, 12.0, s + 15)) * 0.7)
			return c
		"hazard":
			var base := _ramp(n1 * 0.2 + n2 * 0.2 + n3 * 0.6, Color("7d7b72"), Color("8c8a80"), Color("9d9b90"))
			var edge := minf(minf(u, 1.0 - u), minf(g, 1.0 - g))
			var stripe := int(floorf((u + g) * 9.0)) % 2 == 0
			var inside := false
			if v == 0 or v == 3:
				inside = edge < 0.08
			elif v == 1:
				inside = true
			else:
				inside = absf(u - g) < 0.22
			if inside:
				if v == 3 and _h(x, y, s + 16) < 0.3:
					return base
				return Color("dcb024") if stripe else Color("26241f")
			return base
		"steel_deck":
			var c := _ramp(n1 * 0.15 + n2 * 0.15 + n3 * 0.7, Color("4b535c"), Color("57606a"), Color("6a747e"))
			if absf(u - 0.5) < 0.012 or absf(g - 0.5) < 0.012:
				return Color("2c3238")
			if v == 1 and (int(floorf(u * 12.0)) + int(floorf(g * 12.0))) % 2 == 0:
				c = c.lightened(0.1)
			if v == 2 and int(floorf(g * 16.0)) % 2 == 0:
				c = Color("20252a")
			if v == 3:
				c = c.lerp(Color("7a4a2a"), smoothstep(0.5, 0.7, _vn(fx, fy, 11.0, s + 17)) * 0.8)
			return c
		"wood_planks":
			var rv := g * 6.0
			var row := floori(rv)
			var fv := rv - float(row)
			var joint := _h(row, 2, s + 18)
			var seg := 0 if u < joint else 1
			var sh := _h(row * 2 + seg, 3, s + 18)
			var pal: Array = [Color("6a4a2a"), Color("86613a"), Color("a08050")]
			if v == 1:
				pal = [Color("5e5a52"), Color("77736a"), Color("918c80")]
			elif v == 2:
				pal = [Color("46301c"), Color("5c4128"), Color("735536")]
			var c := _ramp(sh * 0.7 + n3 * 0.3, pal[0], pal[1], pal[2])
			if fv < 0.1 or absf(u - joint) < 0.014:
				return Color("2b1d10")
			if v == 3 and row == 3:
				return Color("1c140c")
			return c
		"farmland":
			var c := _ramp(n1 * 0.3 + n2 * 0.3 + n3 * 0.4, Color("5a3f24"), Color("6a4d2c"), Color("7d5d38"))
			var ridge := sin(g * 6.0 * TAU)
			if ridge < -0.2:
				c = c.darkened(0.22)
			elif ridge > 0.5:
				c = c.lightened(0.08)
			return c
		"ash":
			return _ramp(n1 * 0.3 + n2 * 0.3 + n3 * 0.4, Color("3a3835"), Color("4a4743"), Color("5e5a55"))
		"crater":
			var dx := u - 0.5
			var dy := g - 0.5
			var cx: float = [0.0, 0.06, -0.05, 0.04][v]
			var scale: float = [1.0, 0.85, 1.05, 0.75][v]
			var r := sqrt((dx - cx) * (dx - cx) + dy * dy) / scale
			var soil := _ramp(n1 * 0.4 + n2 * 0.3 + n3 * 0.3, Color("6a523a"), Color("7c6244"), Color("8f7450"))
			if r < 0.2:
				return _ramp(n3, Color("1f1a15"), Color("2b241c"), Color("3a3127"))
			if r < 0.32:
				return soil.darkened(0.45 - (r - 0.2) * 1.2)
			if r < 0.4:
				return soil.lightened(0.14)
			return soil
		"shallows":
			var c := _ramp(n1 * 0.5 + n2 * 0.5, Color("4f8f9a"), Color("64a6af"), Color("7fc0c4"))
			if n3 > 0.9:
				c = c.lerp(Color("ccb98a"), 0.5)
			return c
		"hardpan":
			var cell := 5
			var px := u * float(cell)
			var py := g * float(cell)
			var ci := floori(px)
			var cj := floori(py)
			var d1 := 9.0
			var d2 := 9.0
			var nearest := 0
			for oj in range(-1, 2):
				for oi in range(-1, 2):
					var gi := ci + oi
					var gj := cj + oj
					var wi := posmod(gi, cell)
					var wj := posmod(gj, cell)
					var fpx := float(gi) + 0.2 + 0.6 * _h(wi, wj, s + 19)
					var fpy := float(gj) + 0.2 + 0.6 * _h(wi, wj, s + 20)
					var d := Vector2(px - fpx, py - fpy).length()
					if d < d1:
						d2 = d1
						d1 = d
						nearest = wj * 8 + wi
					elif d < d2:
						d2 = d
			if d2 - d1 < 0.1:
				return Color("6c5438")
			var shade := _h(nearest, 5, s + 21)
			return _ramp(shade * 0.6 + n3 * 0.4, Color("9c7f58"), Color("ae9066"), Color("c4a679"))
		"runway_x", "runway_y":
			var c := _ramp(n1 * 0.2 + n2 * 0.2 + n3 * 0.6, Color("6a6c6e"), Color("7a7c7e"), Color("8c8e90"))
			var along := u if t == "runway_x" else g
			var across := g if t == "runway_x" else u
			if absf(along - 0.5) < 0.012:
				return Color("56585a")
			var streak := smoothstep(0.55, 0.75, _vn(along * 40.0, across * 90.0, 9.0, s + 22))
			if (across > 0.12 and across < 0.3) or (across > 0.7 and across < 0.88):
				c = c.lerp(Color("3c3e40"), streak * (0.9 if v == 1 else 0.5))
			var on_dash := along > 0.1 and along < 0.9
			if (v == 0 or v == 2) and absf(across - 0.5) < 0.05 and on_dash:
				return Color("e4e4de") if (v == 0 or _h(x, y, s + 23) > 0.3) else c
			if v == 3 and on_dash and across > 0.2 and across < 0.8 and int(floorf(across * 10.0)) % 2 == 0:
				return Color("e4e4de")
			return c
	return Color.MAGENTA


## Hand-placed marks on top of the base colour (specks, cracks, leaves, footprints). `v` is the look-variant.
func _features_new(img: Image, t: String, v: int, s: int) -> void:
	match t:
		"meadow":
			for i in [10, 16, 12, 8][v]:
				var x := 6 + int(_h(i, 1, s + 20) * (TW - 12))
				var y := 4 + int(_h(i, 2, s + 20) * (TH - 8))
				_dot(img, x, y, Color("33592a"))
				_dot(img, x, y - 1, Color("86c05c"))
				_dot(img, x + 1, y - 2, Color("86c05c"))
				_dot(img, x - 1, y - 2, Color("6ea34a"))
			if v == 1:
				for i in 7:
					var x := 8 + int(_h(i, 3, s + 30) * (TW - 16))
					var y := 5 + int(_h(i, 4, s + 30) * (TH - 10))
					var cols: Array[Color] = [Color("f2f2ee"), Color("e8c84a"), Color("c9609a")]
					_dot(img, x, y, cols[i % 3])
		"dry_grass":
			for i in [12, 18, 8, 6][v]:
				var x := 6 + int(_h(i, 1, s + 20) * (TW - 12))
				var y := 4 + int(_h(i, 2, s + 20) * (TH - 8))
				_dot(img, x, y, Color("6b6232"))
				_dot(img, x, y - 1, Color("cdbf72"))
				_dot(img, x + 1, y - 2, Color("cdbf72"))
		"leaf_litter":
			var leaf_cols: Array[Color] = [Color("b5622a"), Color("d08a2c"), Color("8a3d22"), Color("c9b04a")]
			for i in [10, 18, 14, 22][v]:
				var x := 6 + int(_h(i, 5, s + 20) * (TW - 12))
				var y := 4 + int(_h(i, 6, s + 20) * (TH - 8))
				var col := leaf_cols[i % 4]
				_dot(img, x, y, col)
				_dot(img, x + 1, y, col)
				_dot(img, x + 1, y + 1, col.darkened(0.3))
		"moss":
			for i in [8, 16, 12, 24][v]:
				var x := 6 + int(_h(i, 7, s + 20) * (TW - 12))
				var y := 4 + int(_h(i, 8, s + 20) * (TH - 8))
				_dot(img, x, y, Color("8fb86a"))
				_dot(img, x + 1, y, Color("6d9a52"))
		"mud":
			for i in [4, 8, 6, 10][v]:
				var x := 7 + int(_h(i, 8, s + 60) * (TW - 14))
				var y := 5 + int(_h(i, 9, s + 60) * (TH - 10))
				_dot(img, x, y, Color("8a7a60"))
				_dot(img, x + 1, y, Color("3c2c1c"))
			if v == 2:
				for i in 30:
					_dot(img, 10 + i * 2, 22 - i / 2, Color("33261a"))
					_dot(img, 10 + i * 2, 25 - i / 2, Color("33261a"))
		"sand":
			if v == 3:
				for i in 10:
					var x := 8 + int(_h(i, 10, s + 61) * (TW - 16))
					var y := 5 + int(_h(i, 11, s + 61) * (TH - 10))
					_dot(img, x, y, Color("f0e6cc"))
					_dot(img, x + 1, y + 1, Color("8c7a4a"))
		"snow":
			if v == 1:
				for i in 6:
					var x := 14 + i * 7
					var y := 22 - i * 2 + (i % 2) * 2
					_dot(img, x, y, Color("8ea4b8"))
					_dot(img, x + 1, y, Color("8ea4b8"))
					_dot(img, x, y - 1, Color("a9bccd"))
		"ice":
			for i in [2, 4, 3, 5][v]:
				var x := 8 + int(_h(i, 12, s + 62) * 30.0)
				var y := 6 + int(_h(i, 13, s + 62) * 18.0)
				for k in 14:
					_dot(img, x, y, Color("eefaff"))
					_dot(img, x + 1, y + 1, Color("6d98b0"))
					x += 1 if _h(k, i, s + 63) > 0.3 else 0
					y += 1 if _h(k, i, s + 64) > 0.6 else (-1 if _h(k, i, s + 65) > 0.85 else 0)
		"gravel":
			for i in [26, 40, 32, 50][v]:
				var x := 5 + int(_h(i, 14, s + 66) * (TW - 10))
				var y := 4 + int(_h(i, 15, s + 66) * (TH - 8))
				var lit := _h(i, 16, s + 66) > 0.5
				_dot(img, x, y, Color("b3ada2") if lit else Color("4e4a45"))
				if lit:
					_dot(img, x + 1, y, Color("77726a"))
		"asphalt":
			if v == 1:
				for i in 30:
					var x := 5 + int(_h(i, 17, s + 67) * (TW - 10))
					var y := 4 + int(_h(i, 18, s + 67) * (TH - 8))
					_dot(img, x, y, Color("707074"))
		"cracked_asphalt":
			for i in [3, 5, 4, 6][v]:
				var x := 6 + int(_h(i, 19, s + 68) * 48.0)
				var y := 4 + int(_h(i, 20, s + 68) * 10.0)
				for k in 22:
					_dot(img, x, y, Color("1c1c1f"))
					x += 1 if _h(k, i, s + 69) > 0.45 else (-1 if _h(k, i, s + 70) > 0.85 else 0)
					y += 1 if _h(k, i, s + 71) > 0.55 else 0
			if v == 3:
				for yy in range(14, 21):
					for xx in range(24, 40):
						if _in_diamond(xx, yy):
							img.set_pixel(xx, yy, Color("1b1b1d"))
		"ash":
			for i in [10, 16, 12, 20][v]:
				var x := 6 + int(_h(i, 21, s + 72) * (TW - 12))
				var y := 4 + int(_h(i, 22, s + 72) * (TH - 8))
				_dot(img, x, y, Color("8a8680"))
				_dot(img, x + 1, y, Color("6a6661"))
			if v == 3:
				for i in 5:
					var x := 14 + int(_h(i, 23, s + 73) * 36.0)
					var y := 8 + int(_h(i, 24, s + 73) * 16.0)
					_dot(img, x, y, Color("e8761c"))
					_dot(img, x + 1, y, Color("a8420e"))
		"farmland":
			if v == 1 or v == 2:
				for i in 7:
					for j in 6:
						var gu := (float(i) + 0.4 + 0.3 * _h(i, j, s + 74)) / 7.0
						var gv := (float(j) + 0.25) / 6.0
						var px := int(32.0 + 32.0 * (gu - gv))
						var py := int(16.0 * (gu + gv))
						if v == 1:
							_dot(img, px, py, Color("5ea03c"))
							_dot(img, px, py - 1, Color("86c85a"))
						else:
							_dot(img, px, py, Color("c4a850"))
							_dot(img, px + 1, py, Color("8c7a36"))
			if v == 3:
				for i in 6:
					var x := 8 + int(_h(i, 25, s + 75) * (TW - 16))
					var y := 5 + int(_h(i, 26, s + 75) * (TH - 10))
					_dot(img, x, y, Color("8a7e70"))
					_dot(img, x + 1, y, Color("3a2e20"))
		"crater":
			for i in 12:
				var x := 10 + int(_h(i, 27, s + 76) * 44.0)
				var y := 6 + int(_h(i, 28, s + 76) * 20.0)
				_dot(img, x, y, Color("a38a64") if _h(i, 29, s + 76) > 0.5 else Color("3a2e22"))
		"shallows":
			for i in [4, 7, 5, 8][v]:
				var cx := 8 + int(_h(i, 30, s + 77) * 40.0)
				var cy := 6 + int(_h(i, 31, s + 77) * 20.0)
				for k in 5:
					_dot(img, cx + k, cy + (k % 2), Color("c9f0ee"))
		"steel_deck":  # rivets at the corners of the four plates
			for p in [Vector2(0.1, 0.1), Vector2(0.4, 0.1), Vector2(0.6, 0.1), Vector2(0.9, 0.1), Vector2(0.1, 0.9), Vector2(0.4, 0.9), Vector2(0.6, 0.9), Vector2(0.9, 0.9)]:
				_dot(img, int(32.0 + 32.0 * (p.x - p.y)), int(16.0 * (p.x + p.y)), Color("85909a"))
		"concrete_tile":
			if v == 2:  # a crack
				var x := 18
				var y := 10
				for i in 24:
					_dot(img, x, y, Color("3d3f3a"))
					x += 1 if _h(i, 32, s + 78) > 0.35 else 0
					y += 1 if _h(i, 33, s + 78) > 0.6 else 0
			if v == 3:  # drain grate
				for yy in range(12, 20):
					for xx in range(26, 38):
						if _in_diamond(xx, yy) and (xx + yy) % 3 != 0:
							img.set_pixel(xx, yy, Color("2a2c2a"))
		"hardpan":
			if v == 2:
				for i in 6:
					var x := 8 + int(_h(i, 34, s + 79) * (TW - 16))
					var y := 5 + int(_h(i, 35, s + 79) * (TH - 10))
					_dot(img, x, y, Color("d8c498"))
		"brick":
			if v == 2:  # a missing brick
				for yy in range(14, 18):
					for xx in range(26, 34):
						if _in_diamond(xx, yy):
							img.set_pixel(xx, yy, Color("5a4a3c"))
