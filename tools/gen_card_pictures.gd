extends SceneTree
## Dev tool (not a test). Card pictures (docs/specs/card-loop.md "Card faces", docs/specs/art-polish.md): one 96 x 72 picture per card in
## assets/cards/<card id>.png. A deployment card shows the unit's own sprite (SE facing, idle frame) scaled up by a whole number so its
## pixels match the 2 px grid of the UI; a strike card is a small scene (the strike object over a ground target ring, or a mushroom
## cloud, or water); the cards with no unit (orders, doctrines, mines, lures, supply drops) are drawn here, pixel by pixel, with the
## same outline and three-tone shading as the unit sprites. Deterministic.
## Run: godot --headless --path . --script tools/gen_card_pictures.gd   (then --import)

const W := 96
const H := 72

const BRASS: Array = [Color("f7e08a"), Color("e3b84a"), Color("b98a2c"), Color("7d5a1c")]
const COPPER: Array = [Color("f5b078"), Color("dc8444"), Color("a85a2a"), Color("6e3a1c")]
const STEEL: Array = [Color("e6ecef"), Color("b4c0c6"), Color("7f8c93"), Color("4a555c")]
const FIRE: Array = [Color("fff6c8"), Color("ffd45a"), Color("f58a1f"), Color("c8401a"), Color("6e2012")]
const SMOKE: Array = [Color("8d8a85"), Color("6c6a67"), Color("4c4b49"), Color("302f2e")]
const WOOD: Array = [Color("e6bd7c"), Color("c68f4c"), Color("94622f"), Color("5e3b1c")]
const SILK_RED: Array = [Color("ee6a52"), Color("c8402f"), Color("8c2a22")]
const SILK_WHITE: Array = [Color("fffaee"), Color("e3dccb"), Color("b0a994")]
const TARGET_RED := Color("ff5a3a")
const TARGET_STAIN := Color("7a2a20")

## Cards whose picture is a cutaway image (a strike object) instead of a unit sprite.
const CUTAWAY: Dictionary = {
	"artillery_strike": "res://assets/cutaways/howitzer_body.png",
	"close_air_support": "res://assets/cutaways/f15e.png",
	"missile_strike": "res://assets/cutaways/missile.png",
	"naval_gunfire": "res://assets/cutaways/battleship.png",
	"nuclear_bomb": "res://assets/cutaways/nuke.png",
	"satellite_laser": "res://assets/cutaways/satellite.png",
	"hypersonic_missile": "res://assets/cutaways/hypersonic.png",
}
const UNIT_OF: Dictionary = {"convoy": "supply_truck"}

var _db: ContentDb


func _initialize() -> void:
	_db = ContentDb.load_from()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/cards"))
	var made := 0
	for id in _db.cards.keys():
		var c := _picture(id)
		if c == null:
			continue
		c.outline()
		c.save("res://assets/cards/%s.png" % id)
		made += 1
	print("wrote ", made, " card pictures")
	quit()


func _picture(id: String) -> PixelCanvas:
	var c := PixelCanvas.new(W, H)
	match id:
		"artillery_strike": _artillery(c)
		"close_air_support": _close_air(c)
		"missile_strike": _missile(c, id, 76)
		"hypersonic_missile": _missile(c, id, 80)
		"nuclear_bomb": _nuke(c)
		"naval_gunfire": _naval(c)
		"satellite_laser": _satellite(c)
		"hollow_points": _hollow_points(c)
		"quick_draw": _quick_draw(c)
		"fortify": _fortify(c)
		"supply_drop": _supply_drop(c)
		"minefield": _minefield(c)
		"noise_lure": _noise_lure(c)
		"combat_drones": _drones(c)
		_:
			var img := _unit_image(id)
			if img == null:
				return null
			var fit := _fit(img, 90, 66)
			c.blit(fit, Vector2i((W - fit.get_width()) / 2, (H - fit.get_height()) / 2 + 1), 1)
	return c


# --- sources ----------------------------------------------------------------------------------------------------------------

func _unit_image(card_id: String) -> Image:
	var card: CardDefinition = _db.cards[card_id]
	var uid: String = UNIT_OF.get(card_id, card.unit_id)
	var unit: UnitDefinition = _db.unit(uid) if uid != "" else null
	var sheet: SpriteSheet = unit.sprite if unit != null else null
	if sheet == null or not sheet.textures.has("SE"):
		return null
	var tex: Texture2D = sheet.textures["SE"]
	var whole := Image.load_from_file(ProjectSettings.globalize_path(tex.resource_path))
	whole.convert(Image.FORMAT_RGBA8)
	return _trim(whole.get_region(Rect2i(sheet.frame_region(sheet.idle_frame))))


func _load(path: String) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	img.convert(Image.FORMAT_RGBA8)
	return _trim(img)


func _trim(img: Image) -> Image:
	var used := img.get_used_rect()
	return img.get_region(used) if used.size.x > 0 else img


## Largest whole-number scale that fits `max_w` x `max_h`; an image already too big is shrunk instead, edges kept hard.
func _fit(img: Image, max_w: int, max_h: int) -> Image:
	var k := minf(float(max_w) / float(img.get_width()), float(max_h) / float(img.get_height()))
	var out := img.duplicate() as Image
	if k >= 1.0:
		var n := int(floorf(k))
		out.resize(img.get_width() * n, img.get_height() * n, Image.INTERPOLATE_NEAREST)
	else:
		out.resize(maxi(1, int(float(img.get_width()) * k)), maxi(1, int(float(img.get_height()) * k)), Image.INTERPOLATE_BILINEAR)
		_harden(out)
	return out


## After a smooth shrink: alpha becomes all or nothing, so the picture keeps hard pixel edges.
func _harden(img: Image) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			img.set_pixel(x, y, Color(c.r, c.g, c.b, 1.0) if c.a >= 0.5 else Color(0, 0, 0, 0))


func _scaled_to(img: Image, width: int) -> Image:
	var out := img.duplicate() as Image
	out.resize(width, maxi(1, int(round(float(img.get_height()) * float(width) / float(img.get_width())))), Image.INTERPOLATE_BILINEAR)
	_harden(out)
	return out


# --- strike scenes ----------------------------------------------------------------------------------------------------------

## A target on the ground: a dithered stain and two iso rings with ticks.
func _target(c: PixelCanvas, centre: Vector2, rx: float) -> void:
	var ry := rx * 0.5
	c.ellipse_dither(centre.x, centre.y, rx, ry, TARGET_STAIN, 0.7, true)
	c.ring(centre.x, centre.y, rx, ry, TARGET_RED, 1.6)
	c.ring(centre.x, centre.y, rx * 0.5, ry * 0.5, TARGET_RED, 1.4)
	for s in [-1.0, 1.0]:
		c.rect(int(centre.x + s * (rx - 1.0)) - (3 if s < 0.0 else 0), int(centre.y), 4, 1, TARGET_RED)
		c.rect(int(centre.x), int(centre.y + s * (ry - 1.0)) - (2 if s < 0.0 else 0), 1, 3, TARGET_RED)
	c.px(int(centre.x), int(centre.y), TARGET_RED)


func _artillery(c: PixelCanvas) -> void:
	_target(c, Vector2(48, 57), 30.0)
	var img := _load(CUTAWAY["artillery_strike"])
	c.blit(img, Vector2i((W - img.get_width()) / 2, 4), 1)


func _close_air(c: PixelCanvas) -> void:
	_target(c, Vector2(48, 58), 27.0)
	var jet := _scaled_to(_load(CUTAWAY["close_air_support"]), 84)
	c.blit(jet, Vector2i(6, 8), 1)
	for x in [34, 52]:  # two bombs on the way down
		c.ellipse(float(x), 44.0, 2.0, 4.5, Color("5d6a57"))
		c.rect(x - 1, 39, 1, 7, Color("8e9c86"))
		c.rect(x - 2, 36, 4, 2, Color("3a4438"))


## A rocket exhaust trailing to the left of `tail`: banded from hot at the nozzle to dark smoke.
func _flame(c: PixelCanvas, tail: Vector2, length: float, thick: float) -> void:
	for i in int(length):
		var t := float(i) / length
		var r := thick * 0.5 * (1.0 - t * 0.55)
		var col: Color = FIRE[mini(int(t * 4.0), 3)] if t < 0.7 else SMOKE[mini(int((t - 0.7) / 0.3 * 3.0), 3)]
		if c.bayer(i, int(tail.y)) < 1.2 - t * 0.7:
			c.ellipse(tail.x - float(i), tail.y, 1.2, maxf(r, 0.8), col)


func _missile(c: PixelCanvas, id: String, width: int) -> void:
	_target(c, Vector2(52, 56), 26.0)
	var img := _scaled_to(_load(CUTAWAY[id]), width)
	var x := W - width - 3
	var y := 14
	_flame(c, Vector2(float(x), float(y) + float(img.get_height()) * 0.5), 16.0, 7.0)
	c.blit(img, Vector2i(x, y), 1)


func _nuke(c: PixelCanvas) -> void:
	# a mushroom cloud, and the bomb that made it falling in from the top left
	var ramp: Array = [FIRE[1], FIRE[2], FIRE[3], FIRE[4]]
	c.shadow(60.0, 67.0, 24.0, 3.5, 0.9)
	c.vcyl(55, 46, 11, 20, ramp)
	c.ellipse_ramp(60.0, 58.0, 17.0, 6.0, ramp)
	c.ellipse_ramp(45.0, 42.0, 11.0, 8.0, ramp)
	c.ellipse_ramp(75.0, 42.0, 11.0, 8.0, ramp)
	c.ellipse_ramp(60.0, 35.0, 17.0, 11.0, FIRE)
	c.ellipse_ramp(60.0, 44.0, 12.0, 5.0, [FIRE[2], FIRE[3], FIRE[4], FIRE[4]])
	var bomb := _load(CUTAWAY["nuclear_bomb"])
	c.blit(bomb, Vector2i(4, 5), 1)


func _naval(c: PixelCanvas) -> void:
	# open water with wave dashes, a battleship, and a salvo of shells over it
	for y in range(40, H):
		for x in W:
			var d := float(y - 40) / float(H - 40)
			var base := Color("27567e").lerp(Color("14344f"), d)
			var wave := ((x + y * 3) % 11 == 0 or (x * 2 + y) % 17 == 0) and (y % 3 == 0)
			c.px(x, y, base.lightened(0.18) if wave else base)
	var ship := _scaled_to(_load(CUTAWAY["naval_gunfire"]), 90)
	c.blit(ship, Vector2i(3, 46 - ship.get_height()), 1)
	c.rect(3, 47, 90, 1, Color("3a7aa8"))  # a foam line at the waterline
	for i in 3:  # shells arcing up and over
		var sx := 20 + i * 24
		var sy := 10 + i * 3
		c.ellipse(float(sx), float(sy), 1.6, 2.4, Color("f4d27a"))
		c.px(sx, sy + 4, FIRE[2])
		c.px(sx, sy + 6, FIRE[3])


func _satellite(c: PixelCanvas) -> void:
	_target(c, Vector2(48, 60), 20.0)
	var sat := _scaled_to(_load(CUTAWAY["satellite_laser"]), 66)
	c.blit(sat, Vector2i((W - sat.get_width()) / 2, 4), 1)
	var y0 := 4 + sat.get_height()
	for y in range(y0, 59):  # the beam, with a dithered glow either side
		for dx in range(-4, 5):
			var a := absi(dx)
			if a <= 1:
				c.px(48 + dx, y, Color("ffffff") if a == 0 else Color("ff8a70"))
			elif a == 2:
				c.px(48 + dx, y, TARGET_RED)
			elif c.bayer(48 + dx, y) < 0.5:
				c.px(48 + dx, y, Color("b3382a"))
	c.ellipse(48.0, 60.0, 5.0, 2.5, Color("fff0c8"))


# --- the cards with no unit --------------------------------------------------------------------------------------------------

func _hollow_points(c: PixelCanvas) -> void:
	for i in 3:
		var cx := 22 + i * 26
		var base := 64
		var lift: int = [0, 4, -2][i]
		c.shadow(float(cx), float(base) + 2.0, 12.0, 3.0, 0.95)
		# the case, with the groove and the rim
		var top := base - 24 + lift
		c.vcyl(cx - 7, top, 14, 24, BRASS)
		c.rect(cx - 7, top + 17, 14, 1, BRASS[3])
		c.rect(cx - 8, top + 22, 16, 3, BRASS[2])
		c.rect(cx - 8, top + 22, 16, 1, BRASS[0])
		# the bullet: an ogive with a flat nose
		for xi in 12:
			var nx := (float(xi) + 0.5) / 12.0 * 2.0 - 1.0
			var y_top := maxf(float(top - 19), float(top) - 24.0 * sqrt(maxf(0.0, 1.0 - nx * nx)))
			var idx := int(clampf(nx * 0.55 + 0.35, 0.0, 0.999) * 4.0)
			for y in range(int(y_top), top):
				c.px(cx - 6 + xi, y, COPPER[idx])
		c.ellipse(float(cx), float(top - 18), 3.6, 1.7, Color("2a1a14"))  # the hollow
		c.rect(cx - 6, top - 2, 12, 1, COPPER[3])
	# sparks to show the bonus
	for p in [Vector2(10, 12), Vector2(86, 10), Vector2(89, 32)]:
		_spark(c, int(p.x), int(p.y))


func _spark(c: PixelCanvas, x: int, y: int) -> void:
	c.rect(x - 2, y, 5, 1, FIRE[1])
	c.rect(x, y - 2, 1, 5, FIRE[1])
	c.px(x, y, FIRE[0])


func _card_poly(centre: Vector2, size: Vector2, angle: float, inset: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for p in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		pts.append(centre + Vector2(p.x * (size.x * 0.5 - inset), p.y * (size.y * 0.5 - inset)).rotated(angle))
	return pts


func _quick_draw(c: PixelCanvas) -> void:
	# two cards fanned out, the front one carrying a lightning bolt
	c.shadow(48.0, 67.0, 30.0, 4.0, 0.9)
	var back := Vector2(35, 38)
	var front := Vector2(60, 37)
	c.poly(_card_poly(back, Vector2(30, 44), -0.3, 0.0), Color("1d3a73"))
	c.poly(_card_poly(back, Vector2(30, 44), -0.3, 2.0), Color("3568b8"))
	c.poly(_card_poly(back, Vector2(30, 44), -0.3, 5.0), Color("274e93"))
	c.poly(_card_poly(front, Vector2(30, 44), 0.2, 0.0), Color("8a8576"))
	c.poly(_card_poly(front, Vector2(30, 44), 0.2, 1.0), Color("f2ecd8"))
	c.poly(_card_poly(front, Vector2(30, 44), 0.2, 3.0), Color("e0d9c0"))
	var bolt := PackedVector2Array([Vector2(64, 14), Vector2(50, 40), Vector2(59, 40), Vector2(53, 62), Vector2(73, 32), Vector2(63, 32), Vector2(70, 14)])
	c.poly_fn(bolt, func(x: int, _y: int) -> Color: return FIRE[1] if x < 62 else FIRE[2])
	c.poly(PackedVector2Array([Vector2(64, 14), Vector2(61, 24), Vector2(64, 24), Vector2(68, 14)]), FIRE[0])
	for y in [18, 30, 44]:  # speed lines
		c.rect(6 + (y % 7), y, 12, 1, Color("c3cbc8"))


func _fortify(c: PixelCanvas) -> void:
	# a heater shield, steel rim, blue field, two chevrons
	c.shadow(48.0, 68.0, 24.0, 3.5, 0.9)
	var rim := PackedVector2Array([Vector2(48, 4), Vector2(78, 11), Vector2(78, 36), Vector2(66, 54), Vector2(48, 67), Vector2(30, 54), Vector2(18, 36), Vector2(18, 11)])
	c.poly_fn(rim, func(x: int, y: int) -> Color: return STEEL[0] if (x < 40 and y < 30) else (STEEL[1] if x < 56 else STEEL[2]))
	var field := PackedVector2Array([Vector2(48, 9), Vector2(73, 15), Vector2(73, 35), Vector2(63, 51), Vector2(48, 61), Vector2(33, 51), Vector2(23, 35), Vector2(23, 15)])
	c.poly_fn(field, func(x: int, _y: int) -> Color: return Color("4c86d6") if x < 48 else Color("2f5fae"))
	for dy in [0, 13]:
		var chev := PackedVector2Array([Vector2(32, 27 + dy), Vector2(48, 17 + dy), Vector2(64, 27 + dy), Vector2(64, 34 + dy), Vector2(48, 24 + dy), Vector2(32, 34 + dy)])
		c.poly_fn(chev, func(x: int, _y: int) -> Color: return Color("fff6dc") if x < 48 else Color("d9cfae"))
	for p in [Vector2(23, 15), Vector2(73, 15), Vector2(48, 9)]:  # rivets
		c.px(int(p.x), int(p.y) + 1, STEEL[3])


func _supply_drop(c: PixelCanvas) -> void:
	# a parachute over a wooden crate
	c.shadow(48.0, 69.0, 14.0, 2.5, 0.9)
	var cx := 48.0
	var cy := 26.0
	var rx := 36.0
	var ry := 21.0
	for y in range(int(cy - ry), int(cy) + 3):
		for x in range(int(cx - rx), int(cx + rx) + 1):
			var dx := (float(x) + 0.5 - cx) / rx
			var dy := (float(y) + 0.5 - cy) / ry
			if dx * dx + dy * dy > 1.0:
				continue
			var gore := int(floorf((dx + 1.0) * 3.5))
			var ramp: Array = SILK_RED if gore % 2 == 0 else SILK_WHITE
			var shade := 0 if dx < -0.35 else (1 if dx < 0.45 else 2)
			if dy > 0.78:
				shade = mini(shade + 1, 2)
			c.px(x, y, ramp[shade])
	for i in 7:  # the scalloped skirt under the canopy
		var x0 := int(cx - rx) + i * 10 + 1
		c.ellipse(float(x0 + 5), cy + 3.0, 5.0, 2.5, SILK_RED[2] if i % 2 == 0 else SILK_WHITE[2])
	var crate_top := 50
	for x in [14.0, 34.0, 62.0, 82.0]:
		c.line(Vector2(x, cy + 4.0), Vector2(48.0 + (x - 48.0) * 0.28, float(crate_top)), Color("d8d2c0"), 1.0)
	c.rect(35, crate_top, 26, 17, WOOD[1])
	c.rect(35, crate_top, 26, 4, WOOD[0])
	c.rect(35, crate_top + 13, 26, 4, WOOD[2])
	c.rect(35, crate_top, 2, 17, WOOD[0])
	c.rect(59, crate_top, 2, 17, WOOD[3])
	c.line(Vector2(37, crate_top + 4), Vector2(58, crate_top + 13), WOOD[3], 1.0)
	c.line(Vector2(58, crate_top + 4), Vector2(37, crate_top + 13), WOOD[3], 1.0)
	c.rect(46, crate_top + 6, 4, 4, Color("e24a3a"))  # a red cross on the lid
	c.rect(47, crate_top + 5, 2, 6, Color("fff6dc"))
	c.rect(45, crate_top + 7, 6, 2, Color("fff6dc"))


func _entity(entity: String) -> Image:
	return _load("res://assets/sprites/%s/se.png" % entity)


func _minefield(c: PixelCanvas) -> void:
	# dug-over ground with mines scattered on it
	c.ellipse_dither(48.0, 42.0, 46.0, 26.0, Color("5c4630"), 0.85, true)
	c.ellipse_dither(48.0, 42.0, 34.0, 18.0, Color("7a5f3e"), 0.5, true)
	var mine := _entity("field_mine")
	for p in [Vector2i(10, 20), Vector2i(52, 12), Vector2i(30, 36), Vector2i(8, 46), Vector2i(60, 40)]:
		c.blit(mine, p, 1)
	# a hazard sign on a stick
	c.rect(84, 38, 1, 22, Color("6b4a2a"))
	c.poly(PackedVector2Array([Vector2(77, 28), Vector2(91, 28), Vector2(84, 40)]), Color("f5cc4e"))
	c.poly(PackedVector2Array([Vector2(80, 30), Vector2(88, 30), Vector2(84, 37)]), Color("2b2f33"))


func _noise_lure(c: PixelCanvas) -> void:
	# a decoy speaker with sound waves going out
	c.shadow(48.0, 62.0, 22.0, 4.0, 0.9)
	var beacon := _entity("field_beacon")
	var at := Vector2i((W - beacon.get_width() * 2) / 2, 66 - beacon.get_height() * 2)
	c.blit(beacon, at, 2)
	var mid := Vector2(float(at.x) + float(beacon.get_width()), float(at.y) + 16.0)
	for i in 3:  # arcs going out to both sides, the outer ones dimmer
		var r := 19.0 + float(i) * 8.5
		var col: Color = FIRE[1] if i == 0 else (FIRE[2] if i == 1 else FIRE[3])
		for side in [-1.0, 1.0]:
			for a in range(-32, 33):
				var ang := deg_to_rad(float(a))
				var p := mid + Vector2(side * cos(ang) * r, sin(ang) * r * 0.9)
				c.px(int(p.x), int(p.y), col)
				c.px(int(p.x) + (1 if side > 0.0 else -1), int(p.y), col)


func _drones(c: PixelCanvas) -> void:
	# two far drones, one near and bigger: a depth cue
	var sheet := Image.load_from_file(ProjectSettings.globalize_path("res://assets/sprites/combat_drone/se.png"))
	sheet.convert(Image.FORMAT_RGBA8)
	var drone := _trim(sheet.get_region(Rect2i(0, 0, 45, 27)))  # the first rotor frame
	c.shadow(48.0, 69.0, 26.0, 2.5, 0.8)
	c.blit(drone, Vector2i(22 - drone.get_width() / 2, 3), 1)
	c.blit(drone, Vector2i(74 - drone.get_width() / 2, 3), 1)
	c.blit(drone, Vector2i(48 - drone.get_width(), 66 - drone.get_height() * 2), 2)
