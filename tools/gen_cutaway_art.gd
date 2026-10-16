extends SceneTree
## Dev tool (not a test). Paints the pixel art the strike cutaways use (docs/specs/strike-cutaways.md), original art
## drawn from polygons and circles with 3-tone shading and a 1 px outline, deterministic.
## Run: godot --headless --path . --script tools/gen_cutaway_art.gd
## Writes assets/cutaways/<name>.png. Sprites are side views (cutaway art, the 2:1 isometric rules do not apply).
##   howitzer_body.png   a tracked self-propelled howitzer without its barrel (hull, tracks, turret); the barrel pivots at BODY_PIVOT
##   howitzer_barrel.png the 52-calibre barrel with fume extractor and muzzle brake, facing right; it pivots at BARREL_PIVOT
##   battleship.png      an Iowa-class battleship in profile, bow to the right, without its gun barrels (the scene draws them)
##   launcher.png        an 8x8 transporter-erector-launcher (Iskander-M style) facing right, jacks planted, with a bare hinge for the cradle
##   missile.png         a 9M723-style ballistic missile, nose right, tail fins and nozzle at the left edge
##   hypersonic.png      a slim hypersonic cruise missile, nose right
##   nuke.png            a B83-style gravity bomb, nose right
##   satellite.png       a military satellite with a gold bus and two solar wings
##   f15e.png            an F-15E Strike Eagle in profile, nose to the right, with empty weapon pylons under the conformal tanks

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
const F15_SIZE := Vector2i(112, 40)
const TEL_SIZE := Vector2i(140, 46)
const MISSILE_SIZE := Vector2i(76, 13)
const HYPER_SIZE := Vector2i(98, 14)
const NUKE_SIZE := Vector2i(64, 17)
const SAT_SIZE := Vector2i(96, 50)


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_save(_body(), "howitzer_body")
	_save(_barrel(), "howitzer_barrel")
	_save(_battleship(), "battleship")
	_save(_f15e(), "f15e")
	_save(_launcher(), "launcher")
	_save(_missile(), "missile")
	_save(_hypersonic(), "hypersonic")
	_save(_nuke(), "nuke")
	_save(_satellite(), "satellite")
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


## An F-15E Strike Eagle in profile, nose to the right (19.4 m long is 97 px, so 1 px is 0.2 m): the long pointed nose, the
## two-seat bubble canopy, a rectangular intake under the wing root, conformal fuel tanks along the fuselage with four
## weapon pylons under them (the scene hangs the missiles there so they can be released), twin canted fins, a speed brake
## on the spine and two afterburner nozzles. Gunship grey, with a squadron band on the fin.
func _f15e() -> Image:
	var img := _blank(F15_SIZE)
	# the far fin and the near fin with its squadron band
	_poly(img, PackedVector2Array([Vector2(15, 4), Vector2(23, 4), Vector2(31, 22), Vector2(17, 22)]), GHOST_TOP)
	_poly(img, PackedVector2Array([Vector2(8, 7), Vector2(17, 7), Vector2(27, 24), Vector2(8, 24)]), GHOST_LOW)
	_poly(img, PackedVector2Array([Vector2(10, 9), Vector2(15, 9), Vector2(17, 13), Vector2(10, 13)]), [Color("8a6a10"), Color("c49a1c"), Color("e8c030")] as Array[Color])
	# the stabilator and the two nozzles with their glow
	_rect(img, 1, 26, 24, 28, STEEL)
	_rect(img, 2, 21, 9, 31, STEEL)
	_rect(img, 0, 23, 2, 29, [Color("a03c0a"), Color("e8781c"), Color("ffc060")] as Array[Color])
	# the fuselage: grey on top, a lighter belly, a speed brake on the spine
	_poly(img, PackedVector2Array([Vector2(8, 22), Vector2(30, 20), Vector2(56, 19), Vector2(72, 20), Vector2(86, 22), Vector2(104, 26), Vector2(86, 29), Vector2(56, 32), Vector2(30, 31), Vector2(8, 30)]), GHOST_TOP)
	_poly(img, PackedVector2Array([Vector2(8, 28), Vector2(30, 29), Vector2(56, 30), Vector2(86, 28), Vector2(104, 26), Vector2(86, 29), Vector2(56, 32), Vector2(30, 31), Vector2(8, 30)]), GHOST_LOW)
	_rect(img, 44, 17, 54, 20, STEEL)
	# the conformal tank along the side, with the pylons under it
	_poly(img, PackedVector2Array([Vector2(33, 24), Vector2(62, 24), Vector2(66, 28), Vector2(62, 31), Vector2(33, 31)]), GHOST_LOW)
	_line(img, Vector2(36, 27), Vector2(64, 27), GHOST_TOP[1])
	for px in [38, 44, 50, 56]:
		_rect(img, px, 31, px + 1, 33, STEEL)
	# the intake under the wing root
	_poly(img, PackedVector2Array([Vector2(60, 22), Vector2(72, 22), Vector2(77, 26), Vector2(72, 31), Vector2(60, 31)]), GHOST_TOP)
	_rect(img, 70, 23, 74, 30, RUBBER)
	# the canopy over both seats
	_poly(img, PackedVector2Array([Vector2(70, 20), Vector2(75, 14), Vector2(86, 14), Vector2(93, 22)]), GLASS)
	_rect(img, 80, 14, 81, 21, STEEL)
	# the radome and the pitot probe
	_poly(img, PackedVector2Array([Vector2(86, 22), Vector2(105, 26), Vector2(86, 29)]), [STEEL[1], STEEL[2], HUB[1]] as Array[Color])
	_line(img, Vector2(105, 26), Vector2(111, 26), STEEL[2])
	_outline(img)
	return img


## An 8x8 transporter-erector-launcher in side view, facing right, after the Iskander-M's MZKT-7930 chassis (about 13 m
## long, four axles with the front two close together, a boxy cab, 1 px about 0.1 m): olive drab, the rear stabiliser
## jacks planted, and a bare cradle hinge at CRADLE_HINGE for the scene to erect the missile on.
func _launcher() -> Image:
	var img := _blank(TEL_SIZE)
	# the chassis rails and the rear equipment deck
	_rect(img, 4, 27, 134, 34, STEEL)
	_poly(img, PackedVector2Array([Vector2(6, 22), Vector2(100, 22), Vector2(100, 28), Vector2(6, 28)]), OLIVE_DEEP)
	for sx in [28, 52, 76]:
		_rect(img, sx, 23, sx + 1, 27, OLIVE)
	# the stabiliser jacks, planted
	_rect(img, 3, 28, 6, 42, STEEL)
	_rect(img, 0, 42, 10, 44, HUB)
	_rect(img, 94, 28, 97, 42, STEEL)
	_rect(img, 91, 42, 101, 44, HUB)
	# the cab: a tall box with a sloped windscreen and a sun visor
	_poly(img, PackedVector2Array([Vector2(102, 34), Vector2(102, 11), Vector2(124, 11), Vector2(133, 21), Vector2(136, 24), Vector2(136, 34)]), OLIVE)
	_poly(img, PackedVector2Array([Vector2(118, 14), Vector2(124, 14), Vector2(131, 22), Vector2(118, 22)]), GLASS)
	_rect(img, 105, 14, 115, 22, GLASS)
	_rect(img, 118, 10, 126, 12, OLIVE_DEEP)
	_rect(img, 102, 25, 112, 27, OLIVE_DEEP)  # a panel line and a step
	_rect(img, 134, 28, 138, 32, STEEL)  # the front bumper
	# four axles: two close together under the cab, two at the rear
	for wx in [118, 99, 52, 33]:
		_disc(img, float(wx), 37.0, 7.0, RUBBER)
		_disc(img, float(wx), 37.0, 3.4, HUB)
		_disc(img, float(wx), 37.0, 1.2, STEEL)
	# the cradle hinge at the back of the deck
	_rect(img, 10, 18, 18, 23, STEEL)
	_disc(img, 14.0, 20.0, 2.4, HUB)
	_outline(img)
	return img


## A 9M723-style ballistic missile in side view, nose to the right (7.3 m long, 0.92 m across: 73 x 9 px at 1 px
## 0.1 m, drawn a little fatter to read on screen): a pale body with a dark band, a tapering dark ogive nose and four
## small tail fins, the nozzle at the left edge. Origin of the scene's flight is MISSILE_TAIL.
func _missile() -> Image:
	var img := _blank(MISSILE_SIZE)
	var white: Array[Color] = [Color("8a9096"), Color("b4bac0"), Color("dde1e4")]
	# the fins at the tail (the near pair, drawn behind the body)
	_poly(img, PackedVector2Array([Vector2(0, 0), Vector2(12, 3), Vector2(12, 6), Vector2(0, 6)]), STEEL)
	_poly(img, PackedVector2Array([Vector2(0, 12), Vector2(12, 9), Vector2(12, 6), Vector2(0, 6)]), STEEL)
	# the body and the ogive nose
	_poly(img, PackedVector2Array([Vector2(2, 2), Vector2(56, 2), Vector2(56, 10), Vector2(2, 10)]), white)
	_rect(img, 18, 2, 22, 10, [BOOT[0], BOOT[1], BOOT[2]] as Array[Color])
	_rect(img, 40, 2, 42, 10, [STEEL[0], STEEL[1], STEEL[2]] as Array[Color])
	_poly(img, PackedVector2Array([Vector2(56, 2), Vector2(66, 3), Vector2(73, 5), Vector2(75, 6), Vector2(73, 7), Vector2(66, 9), Vector2(56, 10)]), [STEEL[1], STEEL[2], HUB[1]] as Array[Color])
	# the nozzle
	_rect(img, 0, 3, 3, 9, [STEEL[0], STEEL[0], STEEL[1]] as Array[Color])
	_outline(img)
	return img


## A hypersonic cruise missile in side view, nose to the right (about 9.6 m long, a slim needle: a long conical nose, a
## bronze-dark body of heat-resistant skin, four small swept fins, the nozzle at the left edge). The scene adds the
## white-hot glow at the nose and the shock cone.
func _hypersonic() -> Image:
	var img := _blank(HYPER_SIZE)
	var skin: Array[Color] = [Color("2c2a2e"), Color("46424a"), Color("6a646e")]
	var band: Array[Color] = [Color("5a3a1c"), Color("86592a"), Color("b07c3c")]
	# the far fins and the near fins, short and swept back
	_poly(img, PackedVector2Array([Vector2(4, 1), Vector2(18, 4), Vector2(18, 7), Vector2(4, 7)]), STEEL)
	_poly(img, PackedVector2Array([Vector2(4, 13), Vector2(18, 10), Vector2(18, 7), Vector2(4, 7)]), STEEL)
	# the body, then the long nose cone
	_poly(img, PackedVector2Array([Vector2(2, 3), Vector2(50, 3), Vector2(50, 11), Vector2(2, 11)]), skin)
	_rect(img, 22, 3, 25, 11, band)
	_rect(img, 40, 3, 42, 11, band)
	_poly(img, PackedVector2Array([Vector2(50, 3), Vector2(72, 4.5), Vector2(94, 6.4), Vector2(95, 7), Vector2(94, 7.6), Vector2(72, 9.5), Vector2(50, 11)]), [skin[1], skin[2], HUB[1]] as Array[Color])
	_rect(img, 0, 4, 3, 10, [STEEL[0], STEEL[0], STEEL[1]] as Array[Color])
	_outline(img)
	return img


## A B83-style gravity bomb in side view, nose to the right (3.7 m long, 0.46 m across, drawn a little fat): an olive
## body with a yellow band, a dark ogive nose and a cruciform fin box at the tail.
func _nuke() -> Image:
	var img := _blank(NUKE_SIZE)
	var yellow: Array[Color] = [Color("8a6a10"), Color("c49a1c"), Color("e8c030")]
	# the tail fin box (near and far fins)
	_poly(img, PackedVector2Array([Vector2(0, 0), Vector2(14, 4), Vector2(14, 8), Vector2(0, 8)]), STEEL)
	_poly(img, PackedVector2Array([Vector2(0, 16), Vector2(14, 12), Vector2(14, 8), Vector2(0, 8)]), STEEL)
	_rect(img, 2, 3, 4, 13, [STEEL[1], STEEL[2], HUB[1]] as Array[Color])  # the box ring
	# the body, the band and the ogive nose
	_poly(img, PackedVector2Array([Vector2(8, 3), Vector2(44, 3), Vector2(44, 13), Vector2(8, 13)]), OLIVE)
	_rect(img, 24, 3, 28, 13, yellow)
	_poly(img, PackedVector2Array([Vector2(44, 3), Vector2(54, 4), Vector2(62, 7), Vector2(63, 8), Vector2(62, 9), Vector2(54, 12), Vector2(44, 13)]), STEEL)
	_rect(img, 14, 3, 15, 13, OLIVE_DEEP)
	_outline(img)
	return img


## A military satellite for the laser clip: a gold-foil bus, two solar wings made of blue cells with grid lines, a
## dish on a boom and a sensor block. The scene draws the emitter barrel and its glow.
func _satellite() -> Image:
	var img := _blank(SAT_SIZE)
	var foil: Array[Color] = [Color("8a6a1c"), Color("c9a03a"), Color("f0d070")]
	var cell: Array[Color] = [Color("14264a"), Color("234a8a"), Color("4a82c8")]
	# the solar wings
	for side in [0, 1]:
		var x0 := 0 if side == 0 else 66
		_rect(img, x0, 24, x0 + 29, 40, cell)
		for gx in range(x0 + 5, x0 + 29, 6):
			_line(img, Vector2(gx, 24), Vector2(gx, 40), STEEL[1])
		_line(img, Vector2(x0, 32), Vector2(x0 + 29, 32), STEEL[1])
	_rect(img, 29, 31, 66, 33, STEEL)  # the yoke through the bus
	# the bus
	_poly(img, PackedVector2Array([Vector2(30, 18), Vector2(65, 18), Vector2(65, 46), Vector2(30, 46)]), foil)
	_rect(img, 34, 22, 61, 24, [foil[0], foil[1], foil[2]] as Array[Color])
	_rect(img, 34, 38, 61, 40, [foil[0], foil[0], foil[1]] as Array[Color])
	# the dish on a boom and a sensor block
	_line(img, Vector2(40, 18), Vector2(40, 10), STEEL[2])
	_poly(img, PackedVector2Array([Vector2(33, 6), Vector2(47, 6), Vector2(44, 11), Vector2(36, 11)]), [HUB[0], HUB[1], HUB[2]] as Array[Color])
	_rect(img, 54, 11, 62, 18, STEEL)
	_disc(img, 58.0, 14.0, 2.2, [GLASS[0], GLASS[1], GLASS[2]] as Array[Color])
	_outline(img)
	return img
