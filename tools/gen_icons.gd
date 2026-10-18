extends SceneTree
## Dev tool (not a test). The card back and the small status icons (docs/specs/art-more.md, N.3):
##  - assets/cards/_back.png, 66 x 94 art pixels (shown 2x = a hand card, 132 x 188): a steel frame with notched corners, a navy
##    field with a diagonal weave and a gold star in a ring.
##  - assets/ui/icons/<id>.png, 12 x 12 art pixels (shown 2x = 24 px): fortify, hollow_points, quick_draw, supply_drop, noise_lure.
## Painted with PixelCanvas, deterministic.
## Run: godot --headless --path . --script tools/gen_icons.gd   (then --import)

const STEEL: Array = [Color("e6ecef"), Color("b4c0c6"), Color("7f8c93"), Color("4a555c")]
const NAVY := Color("1b2a47")
const NAVY_LIGHT := Color("28406b")
const GOLD := Color("ffd45a")
const GOLD_DARK := Color("c98a3c")
const CREAM := Color("fff6dc")
const BLUE: Array = [Color("6aa0ea"), Color("4c86d6"), Color("2f5fae")]
const BRASS: Array = [Color("f7e08a"), Color("e3b84a"), Color("b98a2c")]
const COPPER: Array = [Color("f5b078"), Color("dc8444"), Color("a85a2a")]
const FIRE: Array = [Color("fff6c8"), Color("ffd45a"), Color("f58a1f")]
const WOOD: Array = [Color("e6bd7c"), Color("c68f4c"), Color("94622f")]
const RED: Array = [Color("ee6a52"), Color("c8402f")]
const WHITE: Array = [Color("fffaee"), Color("d9d2bf")]


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/ui/icons"))
	_card_back()
	_icon("fortify", _fortify)
	_icon("hollow_points", _hollow_points)
	_icon("quick_draw", _quick_draw)
	_icon("supply_drop", _supply_drop)
	_icon("noise_lure", _noise_lure)
	print("wrote assets/cards/_back.png and assets/ui/icons/*.png")
	quit()


func _card_back() -> void:
	var w := 66
	var h := 94
	var c := PixelCanvas.new(w, h)
	c.rect(0, 0, w, h, STEEL[2])  # the frame
	c.rect(1, 1, w - 2, h - 2, STEEL[0])
	c.rect(2, 2, w - 4, h - 4, STEEL[2])
	c.rect(4, 4, w - 8, h - 8, NAVY)
	for y in range(4, h - 4):  # a diagonal weave
		for x in range(4, w - 4):
			if (x + y) % 6 == 0:
				c.px(x, y, NAVY_LIGHT)
			elif (x - y + 400) % 6 == 0 and c.bayer(x, y) < 0.5:
				c.px(x, y, Color("22365c"))
	# the corners are notched, like the front of the card
	for p in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(w - 1, 0), Vector2i(w - 2, 0), Vector2i(w - 1, 1), Vector2i(0, h - 1), Vector2i(1, h - 1), Vector2i(0, h - 2), Vector2i(w - 1, h - 1), Vector2i(w - 2, h - 1), Vector2i(w - 1, h - 2)]:
		c.img.set_pixel(p.x, p.y, Color(0, 0, 0, 0))
	var cx := float(w) * 0.5
	var cy := float(h) * 0.5
	c.ellipse(cx, cy, 17.0, 17.0, GOLD_DARK)  # the ring
	c.ellipse(cx, cy, 15.0, 15.0, GOLD)
	c.ellipse(cx, cy, 12.0, 12.0, NAVY)
	var star := PackedVector2Array([Vector2(cx, cy - 11), Vector2(cx + 3, cy - 3), Vector2(cx + 11, cy), Vector2(cx + 3, cy + 3), Vector2(cx, cy + 11), Vector2(cx - 3, cy + 3), Vector2(cx - 11, cy), Vector2(cx - 3, cy - 3)])
	c.poly_fn(star, func(x: int, _y: int) -> Color: return GOLD if x < int(cx) else GOLD_DARK)
	c.px(int(cx) - 1, int(cy) - 1, CREAM)
	c.px(int(cx), int(cy) - 1, CREAM)
	for sy in [10, h - 14]:  # small chevrons at the top and the bottom
		for k in 3:
			var yy: int = sy + k * 2
			c.line(Vector2(cx - 6.0 + float(k), float(yy)), Vector2(cx, float(yy) - 3.0), GOLD_DARK, 1.0)
			c.line(Vector2(cx + 6.0 - float(k), float(yy)), Vector2(cx, float(yy) - 3.0), GOLD_DARK, 1.0)
	c.save("res://assets/cards/_back.png")


func _icon(id: String, painter: Callable) -> void:
	var c := PixelCanvas.new(12, 12)
	painter.call(c)
	c.outline()
	c.save("res://assets/ui/icons/%s.png" % id)


func _fortify(c: PixelCanvas) -> void:
	var rim := PackedVector2Array([Vector2(6, 1), Vector2(11, 2), Vector2(11, 6), Vector2(6, 11), Vector2(1, 6), Vector2(1, 2)])
	c.poly_fn(rim, func(x: int, _y: int) -> Color: return STEEL[0] if x < 6 else STEEL[1])
	var field := PackedVector2Array([Vector2(6, 2.5), Vector2(10, 3.2), Vector2(10, 6), Vector2(6, 10), Vector2(2, 6), Vector2(2, 3.2)])
	c.poly_fn(field, func(x: int, _y: int) -> Color: return BLUE[1] if x < 6 else BLUE[2])
	c.line(Vector2(3.5, 6.0), Vector2(6.0, 4.0), CREAM, 1.0)
	c.line(Vector2(6.0, 4.0), Vector2(8.5, 6.0), CREAM, 1.0)
	c.line(Vector2(3.5, 8.0), Vector2(6.0, 6.0), CREAM, 1.0)
	c.line(Vector2(6.0, 6.0), Vector2(8.5, 8.0), CREAM, 1.0)


func _hollow_points(c: PixelCanvas) -> void:
	c.vcyl(4, 6, 4, 5, BRASS)
	c.rect(3, 10, 6, 1, BRASS[2])
	for xi in 4:  # the ogive
		var top: int = [3, 2, 2, 3][xi]
		for y in range(top, 6):
			c.px(4 + xi, y, COPPER[0] if xi == 0 else (COPPER[1] if xi < 3 else COPPER[2]))
	c.px(5, 2, Color("2a1a14"))
	c.px(6, 2, Color("2a1a14"))


func _quick_draw(c: PixelCanvas) -> void:
	var bolt := PackedVector2Array([Vector2(8.5, 0.5), Vector2(2, 6.8), Vector2(5.4, 6.8), Vector2(3.6, 11.5), Vector2(10.4, 4.6), Vector2(6.8, 4.6), Vector2(10, 0.5)])
	c.poly_fn(bolt, func(x: int, _y: int) -> Color: return FIRE[0] if x < 6 else FIRE[1])
	c.px(7, 2, FIRE[0])


func _supply_drop(c: PixelCanvas) -> void:
	for y in range(1, 6):  # the canopy
		for x in range(1, 11):
			var dx := (float(x) + 0.5 - 6.0) / 5.0
			var dy := (float(y) + 0.5 - 5.0) / 4.0
			if dx * dx + dy * dy <= 1.0:
				var band := (x - 1) / 3
				c.px(x, y, RED[0] if band % 2 == 0 else WHITE[0])
	c.line(Vector2(1.5, 5.5), Vector2(5.0, 8.0), WHITE[1], 1.0)
	c.line(Vector2(10.5, 5.5), Vector2(7.0, 8.0), WHITE[1], 1.0)
	c.rect(4, 8, 4, 3, WOOD[1])
	c.rect(4, 8, 4, 1, WOOD[0])
	c.px(4, 10, WOOD[2])
	c.px(7, 10, WOOD[2])


func _noise_lure(c: PixelCanvas) -> void:
	c.rect(2, 4, 3, 4, Color("6b7878"))  # the speaker box and cone
	c.poly(PackedVector2Array([Vector2(5, 4), Vector2(7.5, 2.5), Vector2(7.5, 9.5), Vector2(5, 8)]), Color("97a3a2"))
	c.px(2, 4, Color("c3cbc8"))
	for r in [3.0, 5.0]:  # sound arcs
		for a in range(-40, 41, 8):
			var ang := deg_to_rad(float(a))
			c.px(int(7.5 + cos(ang) * r * 0.9), int(6.0 + sin(ang) * r), FIRE[1] if r < 4.0 else FIRE[2])
