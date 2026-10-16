extends SceneTree
## Dev tool (not a test). Paints the pixel art the strike cutaways use (docs/specs/strike-cutaways.md), original art
## drawn from polygons and circles with 3-tone shading and a 1 px outline, deterministic.
## Run: godot --headless --path . --script tools/gen_cutaway_art.gd
## Writes assets/cutaways/<name>.png. Sprites are side views (cutaway art, the 2:1 isometric rules do not apply).
##   howitzer_body.png   a tracked self-propelled howitzer without its barrel (hull, tracks, turret); the barrel pivots at BODY_PIVOT
##   howitzer_barrel.png the 52-calibre barrel with fume extractor and muzzle brake, facing right; it pivots at BARREL_PIVOT

const OUT_DIR := "res://assets/cutaways"
const INK := Color("12140f")
const BODY_SIZE := Vector2i(100, 50)
const BARREL_SIZE := Vector2i(100, 14)
const BODY_PIVOT := Vector2i(60, 15)  # where the barrel's pivot sits on the body (the cutaway scene reads the same numbers)
const BARREL_PIVOT := Vector2i(6, 7)

# olive drab, three tones (dark, mid, light)
const OLIVE: Array[Color] = [Color("3b4a2a"), Color("55683a"), Color("6f8650")]
const OLIVE_DEEP: Array[Color] = [Color("2a3520"), Color("3a4a2a"), Color("4d6236")]
const STEEL: Array[Color] = [Color("24272a"), Color("3f4448"), Color("636a70")]
const RUBBER: Array[Color] = [Color("151618"), Color("1f2124"), Color("2e3033")]
const HUB: Array[Color] = [Color("50555a"), Color("7a8087"), Color("a4abb2")]


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_save(_body(), "howitzer_body")
	_save(_barrel(), "howitzer_barrel")
	quit()


func _save(img: Image, base: String) -> void:
	var path := "%s/%s.png" % [OUT_DIR, base]
	img.save_png(ProjectSettings.globalize_path(path))
	print("wrote %s (%dx%d)" % [path, img.get_width(), img.get_height()])


func _blank(size: Vector2i) -> Image:
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img


## Fills a polygon, lit from above: the top third light, the middle mid, the bottom dark.
func _poly(img: Image, pts: PackedVector2Array, tones: Array[Color]) -> void:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in pts:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	for y in range(int(floor(lo.y)), int(ceil(hi.y)) + 1):
		for x in range(int(floor(lo.x)), int(ceil(hi.x)) + 1):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			if not Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), pts):
				continue
			var f := (float(y) + 0.5 - lo.y) / maxf(hi.y - lo.y, 1.0)
			img.set_pixel(x, y, tones[2] if f < 0.34 else (tones[1] if f < 0.7 else tones[0]))


func _rect(img: Image, x0: int, y0: int, x1: int, y1: int, tones: Array[Color]) -> void:
	_poly(img, PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)]), tones)


## A disc lit from the top left.
func _disc(img: Image, cx: float, cy: float, r: float, tones: Array[Color]) -> void:
	for y in range(int(cy - r) - 1, int(cy + r) + 2):
		for x in range(int(cx - r) - 1, int(cx + r) + 2):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			var d := Vector2(x + 0.5 - cx, y + 0.5 - cy)
			if d.length() > r:
				continue
			var lit := (-d.x - d.y) / (r * 1.4)
			img.set_pixel(x, y, tones[2] if lit > 0.25 else (tones[1] if lit > -0.35 else tones[0]))


func _outline(img: Image) -> void:
	var edge: Array[Vector2i] = []
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.5:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = Vector2i(x, y) + d
				if n.x >= 0 and n.y >= 0 and n.x < img.get_width() and n.y < img.get_height() and img.get_pixel(n.x, n.y).a > 0.5 and img.get_pixel(n.x, n.y) != INK:
					edge.append(Vector2i(x, y))
					break
	for e in edge:
		img.set_pixel(e.x, e.y, INK)


## A modern tracked 155 mm self-propelled howitzer in side view, facing right (proportions after the M109A6 Paladin
## and the PzH 2000: a low hull with the engine in front, a big turret over the rear half with a sloped roof and a
## bustle, seven road wheels, a front sprocket and a rear spade, 1 px about 0.1 m). The barrel is a separate sprite.
func _body() -> Image:
	var img := _blank(BODY_SIZE)
	# the rear spade, dug in
	_poly(img, PackedVector2Array([Vector2(1, 49), Vector2(6, 37), Vector2(9, 38), Vector2(7, 49)]), STEEL)
	# tracks: a dark belt, the road wheels, the idler at the back and the sprocket at the front
	_poly(img, PackedVector2Array([Vector2(7, 40), Vector2(81, 38), Vector2(86, 43), Vector2(82, 49), Vector2(7, 49), Vector2(3, 45)]), RUBBER)
	for wx in [15, 23, 31, 39, 47, 55, 63]:
		_disc(img, float(wx), 43.5, 4.6, STEEL)
		_disc(img, float(wx), 43.5, 1.8, RUBBER)
	_disc(img, 9.0, 42.0, 4.2, STEEL)
	_disc(img, 9.0, 42.0, 1.6, RUBBER)
	_disc(img, 77.0, 42.0, 5.4, HUB)
	_disc(img, 77.0, 42.0, 2.2, STEEL)
	# the side skirt over the top of the track
	_poly(img, PackedVector2Array([Vector2(8, 33), Vector2(80, 33), Vector2(80, 39), Vector2(8, 39)]), OLIVE_DEEP)
	for sx in [20, 34, 48, 62]:
		_rect(img, sx, 34, sx + 1, 38, OLIVE)
	# the hull with its sloped front and the engine deck
	_poly(img, PackedVector2Array([Vector2(7, 36), Vector2(7, 29), Vector2(12, 27), Vector2(70, 27), Vector2(80, 31), Vector2(84, 37), Vector2(80, 39), Vector2(8, 39)]), OLIVE)
	_poly(img, PackedVector2Array([Vector2(60, 27), Vector2(61, 23), Vector2(72, 23), Vector2(79, 29)]), OLIVE_DEEP)
	for gx in [64, 67, 70]:
		_rect(img, gx, 24, gx + 1, 27, STEEL)
	# the turret: a bustle at the back, a roof that slopes down to the front and the gun mantlet
	_poly(img, PackedVector2Array([Vector2(8, 28), Vector2(8, 12), Vector2(13, 8), Vector2(44, 8), Vector2(51, 10), Vector2(58, 13), Vector2(59, 24), Vector2(55, 28)]), OLIVE)
	_rect(img, 14, 8, 44, 10, [OLIVE[1], OLIVE[2], OLIVE[2]] as Array[Color])
	_rect(img, 9, 17, 19, 26, OLIVE_DEEP)  # a stowage bin on the side
	_rect(img, 22, 14, 44, 16, OLIVE_DEEP)  # a panel line
	_rect(img, 22, 20, 50, 22, OLIVE_DEEP)
	_rect(img, 55, 11, 62, 21, STEEL)  # the mantlet the barrel passes through
	_rect(img, 56, 12, 58, 20, [STEEL[1], STEEL[2], HUB[2]] as Array[Color])
	# hatches, the commander's cupola with its machine gun, and the radio mast
	_rect(img, 23, 6, 31, 9, STEEL)
	_rect(img, 36, 4, 44, 9, STEEL)
	_rect(img, 38, 2, 42, 5, OLIVE_DEEP)
	_rect(img, 44, 3, 50, 4, STEEL)
	_rect(img, 12, 0, 13, 9, STEEL)
	_outline(img)
	return img


## The barrel: a 52-calibre tube (about 8 m, 80 px) with the breech end inside the mantlet, a fume extractor two thirds
## of the way along and a multi-baffle muzzle brake. Facing right, pivots at BARREL_PIVOT.
func _barrel() -> Image:
	var img := _blank(BARREL_SIZE)
	_rect(img, 0, 3, 12, 10, STEEL)  # breech and recoil cylinder
	_rect(img, 12, 4, 40, 9, [OLIVE_DEEP[0], OLIVE_DEEP[1], OLIVE[1]] as Array[Color])  # the thick part of the tube
	_rect(img, 40, 5, 88, 8, [OLIVE_DEEP[0], OLIVE_DEEP[1], OLIVE[1]] as Array[Color])  # the long, thinner part
	_rect(img, 12, 5, 40, 6, [OLIVE[1], OLIVE[2], HUB[2]] as Array[Color])  # highlights along the top
	_rect(img, 40, 5, 88, 6, [OLIVE[1], OLIVE[2], HUB[2]] as Array[Color])
	_rect(img, 58, 3, 70, 10, STEEL)  # the fume extractor
	_rect(img, 59, 4, 69, 5, [STEEL[1], STEEL[2], HUB[2]] as Array[Color])
	_rect(img, 86, 2, 97, 11, STEEL)  # the muzzle brake
	for sx in [88, 91, 94]:
		_rect(img, sx, 2, sx + 1, 11, [RUBBER[0], RUBBER[1], RUBBER[1]] as Array[Color])
	_outline(img)
	return img
