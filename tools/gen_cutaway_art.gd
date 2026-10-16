extends SceneTree
## Dev tool (not a test). Paints the pixel art the strike cutaways use (docs/specs/strike-cutaways.md), original art
## drawn from polygons and circles with 3-tone shading and a 1 px outline, deterministic.
## Run: godot --headless --path . --script tools/gen_cutaway_art.gd
## Writes assets/cutaways/<name>.png. Sprites are side views (cutaway art, the 2:1 isometric rules do not apply).
##   howitzer_body.png   a tracked self-propelled howitzer without its barrel (hull, tracks, turret); the barrel pivots at BODY_PIVOT
##   howitzer_barrel.png the 52-calibre barrel with fume extractor and muzzle brake, facing right; it pivots at BARREL_PIVOT
##   battleship.png      an Iowa-class battleship in profile, bow to the right, without its gun barrels (the scene draws them)
##   a10.png             an A-10 Thunderbolt II in profile, nose to the right, with two bombs under the wing

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
const HAZE: Array[Color] = [Color("3a444e"), Color("56636e"), Color("77868f")]  # navy haze grey
const HAZE_DEEP: Array[Color] = [Color("2a323a"), Color("3a444e"), Color("56636e")]
const BOOT: Array[Color] = [Color("2a1210"), Color("4a1c18"), Color("66281f")]
const GHOST_TOP: Array[Color] = [Color("464d55"), Color("5f6770"), Color("7a848d")]  # A-10 "ghost" grey
const GHOST_LOW: Array[Color] = [Color("6b737b"), Color("8a929a"), Color("a8b0b8")]
const GLASS: Array[Color] = [Color("1e3b4a"), Color("2f6a85"), Color("8fd0ea")]
const SHIP_SIZE := Vector2i(384, 112)
const A10_SIZE := Vector2i(112, 40)


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_save(_body(), "howitzer_body")
	_save(_barrel(), "howitzer_barrel")
	_save(_battleship(), "battleship")
	_save(_a10(), "a10")
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


func _line(img: Image, a: Vector2, b: Vector2, c: Color) -> void:
	var n := int(maxf(absf(b.x - a.x), absf(b.y - a.y))) + 1
	for i in n + 1:
		var p := a.lerp(b, float(i) / float(n))
		var x := int(round(p.x))
		var y := int(round(p.y))
		if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
			img.set_pixel(x, y, c)


## An Iowa-class battleship in profile, bow to the right (270 m is 368 px, so 1 px is about 0.73 m): a long low hull
## with a rising sheer, three triple turrets (two forward, the second raised, one aft; barrels are drawn by the scene),
## the fire-control tower with its radars and tripod mast, two raked funnels, an aft mast, the aft director tower,
## box launchers for Tomahawk and Harpoon and the twin 5-inch mounts along the deck. The waterline is at y = 100.
func _battleship() -> Image:
	var img := _blank(SHIP_SIZE)
	# hull and the red boot topping at the waterline
	_poly(img, PackedVector2Array([Vector2(10, 83), Vector2(120, 81), Vector2(250, 80), Vector2(335, 78), Vector2(380, 71), Vector2(364, 100), Vector2(6, 100)]), HAZE)
	_poly(img, PackedVector2Array([Vector2(6, 97), Vector2(364, 97), Vector2(366, 100), Vector2(6, 100)]), BOOT)
	for hx in range(24, 350, 14):  # the row of portholes and plating seams
		img.set_pixel(hx, 88, HAZE_DEEP[0])
		img.set_pixel(hx + 1, 88, HAZE_DEEP[0])
		_line(img, Vector2(hx + 7, 84), Vector2(hx + 7, 96), HAZE_DEEP[1])
	_line(img, Vector2(10, 83), Vector2(335, 78), HAZE[2])  # the deck edge catches the light
	# the Tomahawk and Harpoon boxes amidships, the twin 5-inch mounts along the deck
	_rect(img, 112, 71, 150, 80, HAZE_DEEP)
	for bx in range(114, 148, 6):
		_rect(img, bx, 72, bx + 4, 79, HAZE)
	for mx in [96, 214, 232]:
		_poly(img, PackedVector2Array([Vector2(mx - 6, 80), Vector2(mx - 5, 74), Vector2(mx + 5, 74), Vector2(mx + 6, 80)]), HAZE)
	# the aft group: turret 3 with its director tower
	_turret(img, 62, 80, 0)
	_rect(img, 92, 62, 104, 80, HAZE)
	_rect(img, 94, 56, 102, 62, HAZE_DEEP)
	_rect(img, 90, 54, 106, 58, HAZE)
	# the aft funnel, the aft mast in front of it, the forward funnel and the tower
	_funnel(img, 118, 148, 52)
	_poly(img, PackedVector2Array([Vector2(150, 80), Vector2(151, 38), Vector2(157, 38), Vector2(158, 80)]), HAZE_DEEP)
	_rect(img, 146, 34, 162, 38, HAZE)
	_line(img, Vector2(154, 20), Vector2(154, 34), HAZE[1])
	_rect(img, 150, 21, 158, 24, STEEL)
	_funnel(img, 166, 200, 44)
	# the fire-control tower: stacked bridge decks, the director on top and a tripod mast carrying the radars
	_poly(img, PackedVector2Array([Vector2(204, 80), Vector2(204, 62), Vector2(250, 62), Vector2(252, 80)]), HAZE)
	_poly(img, PackedVector2Array([Vector2(210, 62), Vector2(210, 50), Vector2(244, 50), Vector2(246, 62)]), HAZE)
	_poly(img, PackedVector2Array([Vector2(216, 50), Vector2(216, 41), Vector2(240, 41), Vector2(242, 50)]), HAZE_DEEP)
	for wx in range(218, 240, 4):
		_rect(img, wx, 44, wx + 2, 47, GLASS)
	_rect(img, 222, 26, 234, 41, HAZE)
	_rect(img, 218, 18, 238, 27, HAZE_DEEP)  # the Mk 38 director
	_rect(img, 214, 21, 242, 23, STEEL)  # its rangefinder arms
	_rect(img, 226, 14, 230, 18, STEEL)
	_line(img, Vector2(228, 14), Vector2(220, 40), STEEL[1])  # the tripod legs
	_line(img, Vector2(228, 14), Vector2(236, 40), STEEL[1])
	_rect(img, 221, 5, 235, 11, STEEL)  # the air-search radar
	_line(img, Vector2(228, 11), Vector2(228, 14), STEEL[1])
	_line(img, Vector2(228, 5), Vector2(228, 0), STEEL[1])
	# the two forward turrets: turret 2 stands on a taller barbette (superfiring over turret 1)
	_rect(img, 254, 66, 292, 80, HAZE_DEEP)
	_turret(img, 273, 66, 1)
	_turret(img, 311, 80, 2)
	_poly(img, PackedVector2Array([Vector2(346, 77), Vector2(347, 70), Vector2(356, 70), Vector2(358, 76)]), HAZE)  # the anchor winch and forecastle fittings
	_line(img, Vector2(378, 71), Vector2(378, 62), STEEL[2])  # the jackstaff
	_outline(img)
	return img


## One triple 16-inch turret house seen from the side, standing on `base_y` at `cx`: a sloped front, a flat roof and
## the rangefinder hoods. `which` only varies the details a little.
func _turret(img: Image, cx: int, base_y: int, which: int) -> void:
	var k := 1.4  # a 16-inch turret house is about 30 m across: 40 px
	var pts := PackedVector2Array()
	for q in [Vector2(-14, 0), Vector2(-14, -8), Vector2(-10, -12), Vector2(10, -12), Vector2(14, -8), Vector2(14, 0)]:
		pts.append(Vector2(cx, base_y) + q * k)
	_poly(img, pts, HAZE)
	_rect(img, int(cx - 9 * k), int(base_y - 12 * k), int(cx + 9 * k), int(base_y - 12 * k) + 2, [HAZE[1], HAZE[2], HAZE[2]] as Array[Color])
	_rect(img, int(cx - 17 * k), int(base_y - 9 * k), int(cx - 13 * k), int(base_y - 5 * k), HAZE_DEEP)
	_rect(img, int(cx + 13 * k), int(base_y - 9 * k), int(cx + 17 * k), int(base_y - 5 * k), HAZE_DEEP)
	_rect(img, int(cx - 4 * k) + which, int(base_y - 15 * k), int(cx + 3 * k) + which, int(base_y - 12 * k), STEEL)  # the roof sighting hood


func _funnel(img: Image, x0: int, x1: int, top: int) -> void:
	_poly(img, PackedVector2Array([Vector2(x0, 80), Vector2(x0 + 6, top), Vector2(x1 - 2, top), Vector2(x1, 80)]), HAZE)
	_poly(img, PackedVector2Array([Vector2(x0 + 5, top), Vector2(x0 + 6, top - 4), Vector2(x1 - 3, top - 4), Vector2(x1 - 2, top)]), RUBBER)  # the black cap
	_rect(img, x0 + 8, top + 8, x1 - 6, top + 10, HAZE_DEEP)
	_rect(img, x0 + 4, top + 14, x1 - 3, top + 15, HAZE_DEEP)


## An A-10 Thunderbolt II in profile, nose to the right (16 m is 80 px, so 1 px is 0.2 m): the 30 mm cannon in the nose,
## the bubble canopy, a straight low wing with two empty bomb pylons and a pod, the two turbofans high on the rear fuselage,
## twin fins, in the grey "ghost" scheme with the shark mouth some squadrons painted.
func _a10() -> Image:
	var img := _blank(A10_SIZE)
	# the fin and tailplane at the back
	_poly(img, PackedVector2Array([Vector2(8, 3), Vector2(16, 3), Vector2(22, 15), Vector2(10, 15)]), GHOST_TOP)
	_rect(img, 4, 14, 24, 16, STEEL)
	# the tail boom behind the engines
	_poly(img, PackedVector2Array([Vector2(6, 14), Vector2(26, 15), Vector2(26, 23), Vector2(8, 18)]), GHOST_TOP)
	# the far engine peeks out above the near one
	_poly(img, PackedVector2Array([Vector2(34, 7), Vector2(38, 5), Vector2(60, 5), Vector2(62, 7)]), GHOST_LOW)
	# the fuselage: grey on top, a lighter belly
	_poly(img, PackedVector2Array([Vector2(22, 17), Vector2(42, 15), Vector2(70, 14), Vector2(86, 16), Vector2(98, 20), Vector2(98, 27), Vector2(70, 28), Vector2(40, 27), Vector2(22, 23)]), GHOST_TOP)
	_poly(img, PackedVector2Array([Vector2(24, 23), Vector2(42, 24), Vector2(72, 24), Vector2(98, 24), Vector2(98, 27), Vector2(70, 28), Vector2(40, 27), Vector2(22, 24)]), GHOST_LOW)
	# the turbofan nacelle on its pylon, with a dark intake ring and the exhaust
	_poly(img, PackedVector2Array([Vector2(30, 10), Vector2(34, 7), Vector2(58, 7), Vector2(62, 10), Vector2(62, 15), Vector2(30, 15)]), GHOST_TOP)
	_rect(img, 30, 9, 33, 15, RUBBER)
	_rect(img, 60, 10, 63, 15, STEEL)
	_rect(img, 38, 14, 54, 16, GHOST_TOP)
	_rect(img, 36, 8, 56, 9, [GHOST_TOP[1], GHOST_TOP[2], GHOST_LOW[2]] as Array[Color])
	# the bubble canopy
	_poly(img, PackedVector2Array([Vector2(74, 15), Vector2(78, 9), Vector2(88, 9), Vector2(94, 17)]), GLASS)
	_rect(img, 80, 9, 81, 15, STEEL)
	# the straight wing, edge-on, with pylons, two bombs and an ECM pod
	_rect(img, 36, 25, 70, 27, GHOST_LOW)
	for bx in [42, 54]:  # the pylons the bombs hang from (the cutaway draws the bombs, so they can drop)
		_rect(img, bx, 27, bx + 1, 29, STEEL)
	_rect(img, 63, 27, 64, 29, STEEL)
	_rect(img, 60, 29, 70, 33, GHOST_LOW)
	# the nose: the cannon barrels stick out in front, the shark mouth is painted on the nose
	_rect(img, 98, 21, 110, 26, STEEL)
	for rx in [100, 104, 108]:
		_rect(img, rx, 21, rx + 1, 26, RUBBER)
	_rect(img, 86, 20, 98, 25, GHOST_TOP)
	_poly(img, PackedVector2Array([Vector2(84, 21), Vector2(98, 22), Vector2(98, 26), Vector2(86, 26)]), [Color("7a1818"), Color("a02424"), Color("b83030")] as Array[Color])
	for tx in range(87, 98, 3):
		_poly(img, PackedVector2Array([Vector2(tx, 22), Vector2(tx + 2, 22), Vector2(tx + 1, 25)]), [Color("d8d8d0"), Color("ece8e4"), Color("ffffff")] as Array[Color])
	_rect(img, 90, 16, 94, 18, STEEL)  # the Pave Penny pod
	_outline(img)
	return img
