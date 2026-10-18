extends SceneTree
## Dev tool (not a test). The game logo (docs/specs/art-polish.md, P.2): the title in chunky block letters built from the UI pixel
## font's own glyph bitmaps, scaled up by whole numbers, with a banded green gradient, a lit top-left edge, a stepped extrusion,
## chipped corners, two stars and a strip of hazard tape. 160 x 56 art pixels; the main menu shows it at 4x, nearest.
## The name is two lines (LINES); a new title is one edit and one run. Deterministic.
## Run: godot --headless --path . --script tools/gen_logo.gd   -> assets/ui/logo.png   (then --import)

const W := 160
const H := 56
## [text, glyph scale] per line, top to bottom.
const LINES: Array = [["LAST", 2], ["DEFENSE", 3]]
const DEPTH := 2
const RAMP: Array = [Color("f4ffd8"), Color("c2f59a"), Color("86e07c"), Color("4fbb68"), Color("2f8a52"), Color("1f6340")]
const EXTRUDE := Color("123a2b")
const LIT := Color("ffffff")
const STAR := Color("ffd45a")
const TAPE_A := Color("f5cc4e")
const TAPE_B := Color("22262a")

var _glyphs: Dictionary


func _init() -> void:
	var gs := load("res://tools/gen_pixel_font.gd") as GDScript
	_glyphs = gs.get_script_constant_map()["GLYPHS"]
	var c := PixelCanvas.new(W, H)
	var y := 5
	var widest := 0
	for line in LINES:
		var text: String = line[0]
		var k: int = line[1]
		var mask := _text_mask(text, k)
		var x := (W - mask.get_width()) / 2 - DEPTH / 2
		_letters(c, mask, Vector2i(x, y), k)
		if text == "LAST":
			_star(c, x - 12, y + 7 * k / 2 + 1)
			_star(c, x + mask.get_width() + 8, y + 7 * k / 2 + 1)
		widest = maxi(widest, mask.get_width())
		y += mask.get_height() + 4
	_tape(c, (W - widest) / 2 - 1, y + 1, widest + DEPTH + 2, 4)
	c.outline()
	c.save("res://assets/ui/logo.png")
	print("wrote assets/ui/logo.png ", W, "x", H)
	quit()


## The text as a mask image (white = ink), glyphs from the UI font scaled by `k`, one `k`-wide gap between letters.
func _text_mask(text: String, k: int) -> Image:
	var rows: Array = []
	var width := 0
	for ch in text:
		var g: String = _glyphs[ch]
		var gr := g.split("/")
		rows.append(gr)
		width += gr[0].length() * k + k
	width -= k
	var mask := Image.create(width, 7 * k, false, Image.FORMAT_L8)
	var x0 := 0
	for gr in rows:
		var gw: int = gr[0].length()
		for r in 7:
			for cc in gw:
				if gr[r][cc] == "#":
					for j in k:
						for i in k:
							mask.set_pixel(x0 + cc * k + i, r * k + j, Color.WHITE)
		x0 += gw * k + k
	return mask


func _on(mask: Image, x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < mask.get_width() and y < mask.get_height() and mask.get_pixel(x, y).r > 0.5


func _letters(c: PixelCanvas, mask: Image, at: Vector2i, k: int) -> void:
	var mw := mask.get_width()
	var mh := mask.get_height()
	# the extrusion first, stepping down and to the right
	for d in range(DEPTH, 0, -1):
		for y in mh:
			for x in mw:
				if _on(mask, x, y):
					c.px(at.x + x + d, at.y + y + d, EXTRUDE)
	for y in mh:
		for x in mw:
			if not _on(mask, x, y):
				continue
			var band := clampi(int(float(y) / float(mh) * float(RAMP.size())), 0, RAMP.size() - 1)
			var col: Color = RAMP[band]
			if not _on(mask, x, y - 1) or not _on(mask, x - 1, y):
				col = RAMP[maxi(band - 1, 0)].lerp(LIT, 0.35)  # the lit top and left edges
			elif not _on(mask, x, y + 1) or not _on(mask, x + 1, y):
				col = RAMP[mini(band + 1, RAMP.size() - 1)]  # the shaded bottom and right edges
			c.px(at.x + x, at.y + y, col)
	# chips bitten out of the letters: a few single pixels turned to the extrusion colour, picked by a hash
	for y in mh:
		for x in mw:
			if _on(mask, x, y) and (not _on(mask, x, y - 1) or not _on(mask, x + 1, y)):
				var h := (x * 73856093) ^ (y * 19349663)
				if (h & 63) == 0 and x > 1 and y > 1:
					c.px(at.x + x, at.y + y, EXTRUDE)


func _star(c: PixelCanvas, cx: int, cy: int) -> void:
	# a four-pointed sparkle
	c.rect(cx - 4, cy, 9, 1, STAR)
	c.rect(cx, cy - 4, 1, 9, STAR)
	c.rect(cx - 1, cy - 1, 3, 3, STAR)
	c.rect(cx - 2, cy - 2, 1, 1, Color("c98a3c"))
	c.rect(cx + 2, cy - 2, 1, 1, Color("c98a3c"))
	c.rect(cx - 2, cy + 2, 1, 1, Color("c98a3c"))
	c.rect(cx + 2, cy + 2, 1, 1, Color("c98a3c"))
	c.px(cx, cy, LIT)
	c.px(cx - 1, cy, LIT)
	c.px(cx, cy - 1, LIT)


func _tape(c: PixelCanvas, x: int, y: int, tw: int, th: int) -> void:
	for j in th:
		for i in tw:
			c.px(x + i, y + j, TAPE_A if ((i + j) / 3) % 2 == 0 else TAPE_B)
