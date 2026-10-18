extends SceneTree
## Dev tool (not a test). Ground marks that stay after a fight (docs/specs/art-more.md, N.1): three craters (small, medium, large)
## and three blood splats, pixel art on the 2:1 ground plane, light from the upper left. Written to assets/fx/marks/ as
## crater_0..2.png and blood_0..2.png; GroundMark draws them. Deterministic (hashes of the pixel position).
## Run: godot --headless --path . --script tools/gen_ground_marks.gd   (then --import)

const DIRT_LIGHT := Color("a08a6a")
const DIRT_MID := Color("74604a")
const DIRT_DARK := Color("4a3c2c")
const PIT: Array = [Color("1b1510"), Color("2a2018"), Color("43372a")]
const SOOT := Color(0.05, 0.045, 0.04, 0.6)
const BLOOD: Array = [Color("7c2424"), Color("5b1818"), Color("3d0f0f")]
const SHEEN := Color("b04848")

const CRATERS: Array = [Vector2i(80, 40), Vector2i(128, 64), Vector2i(192, 96)]
const SPLATS: Array = [Vector2i(44, 22), Vector2i(56, 28), Vector2i(48, 24)]


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/fx/marks"))
	for i in CRATERS.size():
		_crater(i, CRATERS[i])
	for i in SPLATS.size():
		_splat(i, SPLATS[i])
	print("wrote assets/fx/marks/{crater,blood}_0..2.png")
	quit()


func _hash(x: int, y: int, seed_v: int) -> float:
	var n := x * 374761393 + y * 668265263 + seed_v * 2147483647
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 0xFFFF) / 65535.0


func _crater(idx: int, size: Vector2i) -> void:
	var c := PixelCanvas.new(size.x, size.y)
	var cx := float(size.x) * 0.5
	var cy := float(size.y) * 0.5
	var rx := float(size.x) * 0.5 - 1.0
	var ry := float(size.y) * 0.5 - 1.0
	var rim: Array = [Color("b9a27c"), DIRT_LIGHT, DIRT_MID, Color("5d4c39"), DIRT_DARK]
	# the burnt, blown-out ground round about: a dithered soot ring, fading outwards
	c.ellipse_dither(cx, cy, rx, ry, SOOT, 0.9, true)
	c.ellipse_dither(cx, cy, rx * 0.86, ry * 0.86, Color(0.12, 0.1, 0.08, 0.7), 0.7, true)
	for y in size.y:
		for x in size.x:
			var dx := (float(x) + 0.5 - cx) / (rx * 0.66)
			var dy := (float(y) + 0.5 - cy) / (ry * 0.66)
			var ang := atan2(dy, dx)
			var lump := 1.0 + 0.07 * sin(ang * 3.0 + float(idx)) + 0.05 * sin(ang * 7.0 + float(idx) * 2.0)
			var d := sqrt(dx * dx + dy * dy) / lump
			if d > 1.0:
				continue
			var grain := _hash(x, y, 20 + idx)
			# the pit, a little low and to the right of the middle
			var px := dx - 0.04
			var py := dy - 0.1
			var pd := sqrt(px * px + py * py) / (0.7 * lump)
			if pd <= 1.0:
				var lit := clampf(0.5 + (px * 0.5 + py * 0.7) * 0.55 + (grain - 0.5) * 0.18, 0.0, 0.999)
				c.px(x, y, PIT[int(lit * float(PIT.size()))])
			else:
				var lit := clampf(0.45 + (dx * 0.5 + dy * 0.7) * 0.5 + (d - 0.7) * 0.25 + (grain - 0.5) * 0.45, 0.0, 0.999)
				c.px(x, y, rim[int(lit * float(rim.size()))])
	# clods and stones thrown onto the rim and beyond, by hash of the position
	for i in 16 + idx * 10:
		var a := _hash(i, idx, 3) * TAU
		var d := 0.55 + _hash(i, idx, 4) * 0.45
		var x := int(cx + cos(a) * rx * d)
		var y := int(cy + sin(a) * ry * d)
		var col: Color = DIRT_LIGHT if _hash(i, idx, 5) < 0.4 else (DIRT_DARK if _hash(i, idx, 5) < 0.75 else Color("8a8a84"))
		c.px(x, y, col)
		if idx > 0 and _hash(i, idx, 6) < 0.4:
			c.px(x + 1, y, col)
	c.save("res://assets/fx/marks/crater_%d.png" % idx)


func _splat(idx: int, size: Vector2i) -> void:
	var c := PixelCanvas.new(size.x, size.y)
	var cx := float(size.x) * 0.5
	var cy := float(size.y) * 0.5
	var rx := float(size.x) * 0.5 - 1.0
	var ry := float(size.y) * 0.5 - 1.0
	# the main pool: a lumpy blob (smooth bumps by angle), banded dark at the rim, lighter inside
	for y in size.y:
		for x in size.x:
			var dx := (float(x) + 0.5 - cx) / (rx * 0.62)
			var dy := (float(y) + 0.5 - cy) / (ry * 0.62)
			var ang := atan2(dy, dx)
			var lump := 1.0 + 0.28 * sin(ang * 3.0 + float(idx) * 1.7) + 0.16 * sin(ang * 5.0 + float(idx) * 0.6)
			var d := sqrt(dx * dx + dy * dy) / lump
			if d <= 1.0:
				var band := 2 if d > 0.78 else (1 if d > 0.4 else 0)
				c.px(x, y, BLOOD[band])
	# a wet highlight, and spatter drops thrown outwards
	c.px(int(cx - rx * 0.18), int(cy - ry * 0.16), SHEEN)
	c.px(int(cx - rx * 0.18) + 1, int(cy - ry * 0.16), SHEEN)
	for i in 6 + idx * 2:
		var a := _hash(i, idx, 11) * TAU
		var d := 0.62 + _hash(i, idx, 12) * 0.34
		var x := int(cx + cos(a) * rx * d)
		var y := int(cy + sin(a) * ry * d)
		c.px(x, y, BLOOD[1] if _hash(i, idx, 13) < 0.6 else BLOOD[2])
		if _hash(i, idx, 14) < 0.35:
			c.px(x + 1, y, BLOOD[2])
	# a slight transparency so the ground shows through: one level lighter on edge pixels is not needed; keep the pool solid
	c.save("res://assets/fx/marks/blood_%d.png" % idx)
