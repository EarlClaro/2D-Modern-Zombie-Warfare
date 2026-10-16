extends SceneTree
## Dev tool (not a test). Paints the terrain atlas `assets/tiles/terrain.png`: 4 look-variants (columns) for each
## terrain (rows, same order as IsoTileSet.TERRAIN_ROWS), every tile a 64x32 isometric diamond. Pure per-pixel
## noise and a few hand-placed features per variant, deterministic, original art.
## Run: godot --headless --path . --script tools/gen_tiles.gd

const TW := 64
const TH := 32
const VARIANTS := 4
const ROWS := ["grass", "road", "rock", "dirt", "paved", "rubble", "water"]


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
				c2 = c2.lerp(Color("3d3c3c"), smoothstep(0.55, 0.75, _vn(fx, fy, 12.0, s + 4)) * 0.8)
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
				c5 = c5.lerp(Color("6c6a60"), smoothstep(0.55, 0.75, _vn(fx, fy, 13.0, s + 8)) * 0.7)
			return c5
		"rubble":
			var t6 := n1 * 0.3 + n2 * 0.3 + n3 * 0.4
			return _ramp(t6, Color("45423d"), Color("5d5a53"), Color("77746b"))
		"water":
			var t7 := n1 * 0.6 + n2 * 0.4
			return _ramp(t7, Color("27546f"), Color("2f6785"), Color("3f7f9c"))
	return Color.MAGENTA


func _dot(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < TW and y < TH and _in_diamond(x, y):
		img.set_pixel(x, y, c)


func _features(img: Image, terrain: String, v: int, s: int) -> void:
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
