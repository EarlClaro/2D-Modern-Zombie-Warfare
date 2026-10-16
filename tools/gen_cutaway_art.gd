extends SceneTree
## Dev tool (not a test). Paints the pixel art the strike cutaways use (docs/specs/strike-cutaways.md), original art
## drawn from polygons and circles with 3-tone shading and a 1 px outline, deterministic.
## Run: godot --headless --path . --script tools/gen_cutaway_art.gd
## Writes assets/cutaways/<name>.png. Sprites are side views (cutaway art, the 2:1 isometric rules do not apply).
##   howitzer_body.png   carriage, wheel, trail legs, gun shield and recoil housing; the barrel pivots at BODY_PIVOT
##   howitzer_barrel.png the barrel with breech and muzzle brake, facing right; it pivots at BARREL_PIVOT

const OUT_DIR := "res://assets/cutaways"
const INK := Color("12140f")
const BODY_SIZE := Vector2i(64, 44)
const BARREL_SIZE := Vector2i(60, 10)
const BODY_PIVOT := Vector2i(40, 15)  # where the barrel's pivot sits on the body (the cutaway scene reads the same numbers)
const BARREL_PIVOT := Vector2i(5, 5)

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


func _body() -> Image:
	var img := _blank(BODY_SIZE)
	# trail legs spread back along the ground, each ending in a spade
	_poly(img, PackedVector2Array([Vector2(24, 26), Vector2(31, 29), Vector2(9, 41), Vector2(3, 40)]), OLIVE_DEEP)
	_rect(img, 2, 39, 6, 43, STEEL)
	_poly(img, PackedVector2Array([Vector2(28, 28), Vector2(34, 29), Vector2(22, 41), Vector2(17, 40)]), OLIVE)
	# carriage and cradle
	_poly(img, PackedVector2Array([Vector2(17, 22), Vector2(43, 19), Vector2(46, 29), Vector2(19, 32)]), OLIVE)
	_rect(img, 20, 20, 40, 23, OLIVE_DEEP)
	# the recoil housing the barrel slides in
	_rect(img, 31, 11, 47, 18, STEEL)
	_rect(img, 31, 13, 47, 14, [STEEL[1], STEEL[2], HUB[2]] as Array[Color])
	# the wheel
	_disc(img, 27.0, 34.0, 9.0, RUBBER)
	_disc(img, 27.0, 34.0, 5.0, HUB)
	_disc(img, 27.0, 34.0, 1.6, STEEL)
	# the gun shield, a little proud of the cradle, with rivets
	_poly(img, PackedVector2Array([Vector2(37, 8), Vector2(43, 8), Vector2(46, 28), Vector2(39, 29)]), OLIVE)
	for ry in [11, 16, 21, 26]:
		img.set_pixel(41 + (ry - 11) / 8, ry, OLIVE[2])
	# elevating wheel and sight
	_disc(img, 33.0, 25.0, 2.6, STEEL)
	_rect(img, 34, 6, 38, 9, STEEL)
	_outline(img)
	return img


func _barrel() -> Image:
	var img := _blank(BARREL_SIZE)
	_rect(img, 0, 2, 7, 9, STEEL)  # breech block
	_rect(img, 7, 3, 47, 8, [OLIVE_DEEP[0], OLIVE_DEEP[1], OLIVE[1]] as Array[Color])  # tube
	_rect(img, 7, 4, 47, 5, [OLIVE[1], OLIVE[2], HUB[2]] as Array[Color])  # a highlight along the top
	_rect(img, 22, 2, 25, 9, STEEL)  # a collar
	_rect(img, 47, 1, 58, 9, STEEL)  # muzzle brake
	for sx in [49, 52, 55]:
		_rect(img, sx, 1, sx + 1, 9, [RUBBER[0], RUBBER[1], RUBBER[1]] as Array[Color])
	_outline(img)
	return img
