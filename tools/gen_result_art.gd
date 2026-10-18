extends SceneTree
## Dev tool (not a test). The two pictures at the top of the result panel (docs/specs/art-more.md, N.6): a victory at dawn (the sun
## coming up behind the command bunker, its flag flying, a line of soldiers with rifles raised) and a defeat at dusk (the bunker in
## ruins and burning, smoke over a red sky, zombies on the skyline). 128 x 40 art pixels each, shown at 4x on the result panel.
## Written to assets/ui/result_victory.png and result_defeat.png. Deterministic.
## Run: godot --headless --path . --script tools/gen_result_art.gd   (then --import)

const W := 128
const H := 40
const HORIZON := 28
const DAWN: Array = [Color("162842"), Color("2a4766"), Color("5d7c89"), Color("c98f5c"), Color("f0b45a"), Color("ffd98a")]
const DUSK: Array = [Color("14080c"), Color("2e1016"), Color("57231d"), Color("8a3a22"), Color("c4642b"), Color("e08a3a")]


func _init() -> void:
	_victory()
	_defeat()
	print("wrote assets/ui/result_victory.png and result_defeat.png")
	quit()


func _hash(x: int, y: int, seed_v: int) -> float:
	var n := x * 374761393 + y * 668265263 + seed_v * 2147483647
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 0xFFFF) / 65535.0


func _sky(c: PixelCanvas, ramp: Array) -> void:
	for y in HORIZON + 1:
		var t := clampf(float(y) / float(HORIZON), 0.0, 1.0) * float(ramp.size() - 1)
		var i := mini(int(t), ramp.size() - 2)
		var frac := t - float(i)
		for x in W:
			var pick := i + (1 if frac * 16.0 > float(PixelCanvas.BAYER[(y % 4) * 4 + (x % 4)]) else 0)
			c.px(x, y, ramp[mini(pick, ramp.size() - 1)])


func _skyline(c: PixelCanvas, col: Color, base: int, max_h: int, seed_v: int, windows: Color) -> void:
	var x := -2
	while x < W:
		var w := 5 + int(_hash(x, 0, seed_v) * 8.0)
		var h := 4 + int(_hash(x, 1, seed_v) * float(max_h))
		c.rect(x, base - h, w, h + 1, col)
		for wy in range(base - h + 2, base - 1, 3):
			for wx in range(x + 1, x + w - 1, 3):
				if _hash(wx, wy, seed_v + 3) < 0.18:
					c.px(wx, wy, windows)
		x += w + int(_hash(x, 2, seed_v) * 2.0)


func _ground(c: PixelCanvas, top: Color, bottom: Color) -> void:
	for y in range(HORIZON + 1, H):
		var t := float(y - HORIZON) / float(H - HORIZON)
		for x in W:
			var col := top.lerp(bottom, t)
			if _hash(x, y, 9) < 0.08:
				col = col.lightened(0.08)
			c.px(x, y, col)


func _sandbags(c: PixelCanvas, x0: int, x1: int, y: int) -> void:
	var x := x0
	var row := 0
	while x < x1:
		var shade := Color("8a7348") if (x / 5 + row) % 3 else Color("a08a5c")
		c.rect(x, y, 5, 3, shade)
		c.rect(x, y, 5, 1, shade.lightened(0.15))
		x += 5


func _bunker(c: PixelCanvas, x: int, y: int, alive: bool) -> void:
	# the command bunker, from the front-left: a low block, a roof deck, a mast
	if alive:
		c.rect(x, y, 34, 11, Color("66727c"))
		c.rect(x, y, 34, 2, Color("8a969e"))
		c.rect(x + 4, y - 5, 24, 5, Color("5a666f"))
		c.rect(x + 4, y - 5, 24, 1, Color("7c8890"))
		for wx in range(x + 7, x + 26, 5):
			c.rect(wx, y - 3, 3, 2, Color("6fb7d6"))
		c.rect(x + 14, y + 5, 6, 6, Color("1a1d1f"))  # the door
		c.rect(x + 22, y - 12, 1, 8, Color("2b2f33"))  # mast
		c.rect(x + 4, y + 3, 4, 2, Color("2b2f33"))
	else:
		c.poly(PackedVector2Array([Vector2(x, y + 11), Vector2(x, y + 3), Vector2(x + 8, y + 1), Vector2(x + 14, y + 4), Vector2(x + 22, y), Vector2(x + 34, y + 5), Vector2(x + 34, y + 11)]), Color("2c2e30"))
		c.poly(PackedVector2Array([Vector2(x + 4, y + 3), Vector2(x + 8, y - 4), Vector2(x + 12, y + 2)]), Color("3a3d40"))
		c.rect(x + 20, y - 5, 2, 6, Color("1c1d1e"))  # a broken wall
		for i in 7:
			c.px(x + 3 + i * 4 + int(_hash(i, 0, 5) * 2.0), y + 5 + (i % 3), Color("484b4e"))


func _victory() -> void:
	var c := PixelCanvas.new(W, H)
	_sky(c, DAWN)
	# the sun coming up, with a dithered halo and rays
	var sun := Vector2(88.0, float(HORIZON))
	c.ellipse_dither(sun.x, sun.y, 34.0, 26.0, Color("ffd98a"), 0.5, true)
	c.ellipse(sun.x, sun.y, 10.0, 10.0, Color("f5a742"))
	c.ellipse(sun.x, sun.y, 8.0, 8.0, Color("ffe8a0"))
	for k in 7:
		var a := deg_to_rad(200.0 + float(k) * 23.0)
		for r in range(13, 22):
			if (r + k) % 3 != 0:
				c.px(int(sun.x + cos(a) * float(r)), int(sun.y + sin(a) * float(r) * 0.9), Color("ffe8a0"))
	_skyline(c, Color("2c4155"), HORIZON, 9, 4, Color("e7b45a"))
	_skyline(c, Color("1f2f3d"), HORIZON + 1, 6, 8, Color("c98a3c"))
	_ground(c, Color("26382c"), Color("141f19"))
	c.rect(0, HORIZON + 1, W, 1, Color("3c5542"))
	_bunker(c, 14, 20, true)
	# the flag flying from the mast
	c.rect(37, 9, 1, 2, Color("2b2f33"))
	c.rect(38, 9, 8, 4, Color("e8f0e4"))
	c.rect(38, 9, 8, 1, Color("ffffff"))
	c.rect(40, 10, 4, 2, Color("3a9a5a"))
	_sandbags(c, 8, 54, 31)
	# soldiers on the right, rifles raised, in silhouette against the light
	for i in 6:
		var sx := 66 + i * 9
		var sy := 33
		c.rect(sx, sy - 6, 3, 6, Color("16221b"))  # body
		c.rect(sx, sy - 8, 3, 2, Color("1d2b22"))  # head
		c.rect(sx - 1, sy - 5, 1, 2, Color("16221b"))
		c.rect(sx + 3, sy - 11 - (i % 2), 1, 7, Color("16221b"))  # an arm and the rifle going up
		c.rect(sx + 3, sy - 12 - (i % 2), 1, 1, Color("ffe8a0"))  # the light on the barrel
		c.rect(sx, sy, 1, 3, Color("16221b"))
		c.rect(sx + 2, sy, 1, 3, Color("16221b"))
	# a few birds
	for p in [Vector2i(44, 6), Vector2i(50, 9), Vector2i(36, 4)]:
		c.px(p.x, p.y, Color("162842"))
		c.px(p.x + 1, p.y + 1, Color("162842"))
		c.px(p.x + 2, p.y, Color("162842"))
	c.save("res://assets/ui/result_victory.png")


func _defeat() -> void:
	var c := PixelCanvas.new(W, H)
	_sky(c, DUSK)
	_skyline(c, Color("261418"), HORIZON, 11, 12, Color("a8482a"))
	_skyline(c, Color("180c10"), HORIZON + 1, 7, 15, Color("7a3a24"))
	# smoke from the ruin, drifting to the right
	for col in 3:
		for i in 26:
			var t := float(i) / 26.0
			var x := 30.0 + float(col) * 6.0 + t * 38.0 + sin(t * 6.0 + float(col)) * 3.0
			var y := 22.0 - t * 21.0
			var r := 3.0 + t * 7.0
			c.ellipse_dither(x, y, r, r * 0.8, Color("1a1214"), 0.75 - t * 0.35, false)
	_ground(c, Color("1d1618"), Color("0e0a0b"))
	c.rect(0, HORIZON + 1, W, 1, Color("3a2420"))
	_bunker(c, 14, 20, false)
	# fire in the ruin
	for k in 9:
		var fx := 20 + k * 3
		var fh := 2 + int(_hash(k, 1, 6) * 4.0)
		c.rect(fx, 22 - fh, 2, fh, Color("f58a1f"))
		c.px(fx, 22 - fh, Color("ffd45a"))
	c.ellipse_dither(30.0, 22.0, 18.0, 9.0, Color("f58a1f"), 0.35, true)
	# a flag down on the ground
	c.rect(44, 33, 7, 1, Color("2b2f33"))
	c.rect(44, 34, 5, 2, Color("8a2a22"))
	# zombies on the skyline, hunched, with red eyes
	for i in 9:
		var zx := 62 + i * 7 + int(_hash(i, 2, 3) * 3.0)
		var zy := 30 + (i % 3)
		c.rect(zx, zy - 6, 3, 6, Color("0e0a0b"))
		c.rect(zx + 1, zy - 8, 3, 2, Color("0e0a0b"))
		c.rect(zx + 3, zy - 5, 3, 1, Color("0e0a0b"))  # an arm reaching out
		c.px(zx + 3, zy - 8 + 1, Color("ff3a2a"))
		c.rect(zx, zy, 1, 2, Color("0e0a0b"))
		c.rect(zx + 2, zy, 1, 2, Color("0e0a0b"))
	c.save("res://assets/ui/result_defeat.png")
