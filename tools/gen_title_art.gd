extends SceneTree
## Dev tool (not a test). The picture behind the main menu (docs/specs/art-gaps.md, G.3): a night sky over a ruined skyline, a
## searchlight, sandbags and the command bunker, painted pixel by pixel into 480 x 270 px (the menu shows it 4x, nearest, on the
## 1920 x 1080 base). The middle is left dark so the menu stays readable. Deterministic.
## Run: godot --headless --path . --script tools/gen_title_art.gd   -> assets/ui/title.png

const W := 480
const H := 270
const BAYER: Array = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
const SKY: Array = [Color("070b14"), Color("0b1424"), Color("11203a"), Color("1b3150"), Color("2d4a66"), Color("54606a"), Color("8a6a55")]
const HORIZON_Y := 176

var img: Image


func _init() -> void:
	img = Image.create(W, H, false, Image.FORMAT_RGBA8)
	_sky()
	_stars()
	_moon(396, 46, 15)
	_skyline(Color("1a2638"), 150, 34, 11, 3, 0.35)  # far
	_skyline(Color("111a28"), 168, 46, 9, 7, 0.55)  # near, with broken tops
	_beam()
	_ground()
	_bunker(58, 214)
	_sandbags()
	_tower(420, 196)
	_vignette()
	img.save_png(ProjectSettings.globalize_path("res://assets/ui/title.png"))
	print("wrote assets/ui/title.png")
	quit()


func _hash(a: int, b: int) -> float:
	var n := a * 374761393 + b * 668265263
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 0xFFFF) / 65535.0


func _px(x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < W and y < H:
		img.set_pixel(x, y, c)


func _rect(x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			_px(xx, yy, c)


func _sky() -> void:
	for y in H:
		var t := clampf(float(y) / float(HORIZON_Y), 0.0, 1.0) * float(SKY.size() - 1)
		var i := mini(int(t), SKY.size() - 2)
		var frac := t - float(i)
		for x in W:
			var pick := i + (1 if frac * 16.0 > float(BAYER[(y % 4) * 4 + (x % 4)]) else 0)
			img.set_pixel(x, y, SKY[mini(pick, SKY.size() - 1)])


func _stars() -> void:
	for i in 150:
		var x := int(_hash(i, 1) * W)
		var y := int(_hash(i, 2) * 110.0)
		var b := 0.5 + _hash(i, 3) * 0.5
		_px(x, y, Color(0.85 * b, 0.9 * b, 1.0 * b))


func _moon(cx: int, cy: int, r: int) -> void:
	for y in range(cy - r - 6, cy + r + 7):
		for x in range(cx - r - 6, cx + r + 7):
			var d := Vector2(x - cx, y - cy).length()
			if d <= float(r):
				var c := Color("e8e4c8")
				if Vector2(x - cx + 5, y - cy + 3).length() < 4.0 or Vector2(x - cx - 6, y - cy - 5).length() < 3.0 or Vector2(x - cx - 2, y - cy + 8).length() < 2.5:
					c = Color("c4c0a2")
				_px(x, y, c)
			elif d <= float(r) + 5.0 and BAYER[(y % 4) * 4 + (x % 4)] as int < int((float(r) + 5.0 - d) * 2.6):
				_px(x, y, Color("3a4a62"))  # a dithered halo


func _skyline(col: Color, base_y: int, max_h: int, min_w: int, broken: int, lit: float) -> void:
	var x := -4
	var seed_v := int(col.r * 255.0)
	while x < W:
		var w := min_w + int(_hash(x, seed_v) * 14.0)
		var h := 10 + int(_hash(x, seed_v + 1) * float(max_h))
		for xx in range(x, x + w):
			var top := base_y - h
			if broken > 0 and _hash(xx, seed_v + 2) < 0.18:
				top += int(_hash(xx, seed_v + 3) * float(broken))  # a bitten roofline
			for yy in range(top, base_y + 30):
				_px(xx, yy, col)
		# a few lit windows, in a grid
		for wy in range(base_y - h + 4, base_y - 3, 5):
			for wx in range(x + 2, x + w - 2, 4):
				if _hash(wx, wy + seed_v) < lit * 0.22:
					_px(wx, wy, Color("e7b45a") if _hash(wx + 9, wy) < 0.6 else Color("c98a3c"))
		x += w + int(_hash(x, seed_v + 4) * 3.0)


func _beam() -> void:
	# a searchlight from the bunker, up and to the right, dithered so it stays see-through
	var origin := Vector2(60, 196)
	var dir := Vector2(0.55, -1.0).normalized()
	for y in range(0, 200):
		for x in range(0, W):
			var p := Vector2(x, y) - origin
			var along := p.dot(dir)
			if along < 6.0:
				continue
			var across := absf(p.x * dir.y - p.y * dir.x)
			var half := 2.0 + along * 0.11
			if across < half:
				var k := (1.0 - across / half) * clampf(1.0 - along / 300.0, 0.0, 1.0)
				if float(BAYER[(y % 4) * 4 + (x % 4)]) / 16.0 < k * 0.55:
					var c := img.get_pixel(x, y)
					img.set_pixel(x, y, c.lerp(Color("cfe6f0"), 0.35))


func _ground() -> void:
	for y in range(HORIZON_Y + 18, H):
		var t := float(y - HORIZON_Y - 18) / float(H - HORIZON_Y - 18)
		for x in W:
			var shade := 0.10 - t * 0.05 + (_hash(x, y) - 0.5) * 0.02
			_px(x, y, Color("1b2418").lerp(Color("0a0e0a"), clampf(t, 0.0, 1.0)) + Color(shade * 0.2, shade * 0.2, shade * 0.1, 0.0))
	for y in range(HORIZON_Y + 12, HORIZON_Y + 18):  # a low strip of far ground
		for x in W:
			_px(x, y, Color("161e17"))
	# a road running toward the horizon
	for y in range(HORIZON_Y + 18, H):
		var t := float(y - HORIZON_Y - 18) / float(H - HORIZON_Y - 18)
		var half := 4 + int(t * 70.0)
		for x in range(W / 2 - half, W / 2 + half):
			_px(x, y, Color("232826") if ((x + y) % 7 != 0) else Color("2a302d"))


func _bunker(x: int, y: int) -> void:
	_rect(x - 26, y - 20, 52, 20, Color("0c110e"))
	_rect(x - 22, y - 28, 44, 8, Color("0c110e"))
	_rect(x - 14, y - 10, 28, 3, Color("e7b45a"))  # a lit firing slit
	_rect(x - 14, y - 10, 28, 1, Color("ffd88a"))
	_px(x + 2, y - 31, Color("0c110e")); _rect(x, y - 38, 2, 10, Color("0c110e"))  # mast
	_rect(x + 2, y - 38, 6, 3, Color("a8322a"))  # a flag


func _sandbags() -> void:
	for row in 3:
		for i in 26:
			var x := i * 19 + (row % 2) * 9 - 6
			if x > 150 and x < 330:
				continue
			var y := 232 + row * 7
			var c := Color("6b5b3c") if (i + row) % 3 else Color("7a6a48")
			_rect(x, y, 18, 6, c)
			_rect(x, y, 18, 1, Color("8e7d58"))
			_rect(x, y + 5, 18, 1, Color("3f3624"))


func _tower(x: int, y: int) -> void:
	_rect(x - 2, y - 40, 4, 40, Color("0c110e"))
	_rect(x - 9, y - 50, 18, 10, Color("0c110e"))
	_rect(x - 8, y - 46, 16, 2, Color("e7b45a"))
	_rect(x - 11, y - 52, 22, 3, Color("0c110e"))


func _vignette() -> void:
	for y in H:
		for x in W:
			var dx := (float(x) - W * 0.5) / (W * 0.5)
			var dy := (float(y) - H * 0.5) / (H * 0.5)
			var d := sqrt(dx * dx + dy * dy)
			# darker at the edges, and a soft dark patch in the middle where the menu sits
			var edge := clampf((d - 0.65) * 1.2, 0.0, 0.7)
			var mid := clampf(1.0 - Vector2(dx / 0.4, (dy - 0.05) / 0.85).length(), 0.0, 1.0) * 0.55
			var k := clampf(edge + mid, 0.0, 0.85)
			if float(BAYER[(y % 4) * 4 + (x % 4)]) / 16.0 < k:
				img.set_pixel(x, y, img.get_pixel(x, y).lerp(Color("04060a"), 0.7))
