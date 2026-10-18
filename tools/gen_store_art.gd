extends SceneTree
## Dev tool (not a test). The window and store pictures (docs/specs/art-more.md, N.8), all made from the logo (assets/ui/logo.png) and the
## title picture (assets/ui/title.png), scaled by whole numbers so the pixels stay square:
##  - assets/icon/icon.png (256 x 256) and icon.ico (16, 32, 64, 128 and 256 px): a navy badge with a green shield and "LD".
##  - store_art/*.png: the Steam capsules at the sizes of the Steamworks "Graphical assets" page checked on 2026-10-18: header 920 x 430,
##    small 462 x 174, main 1232 x 706, vertical 748 x 896, library capsule 600 x 900, library hero 3840 x 1240 (no text), library logo
##    1280 x 720 (transparent). store_art/ has a .gdignore (not imported) and its pictures are not committed: run this tool to make them.
## Run: godot --headless --path . --script tools/gen_store_art.gd   (then --import)

const STEEL: Array = [Color("e6ecef"), Color("b4c0c6"), Color("7f8c93"), Color("4a555c")]
const NAVY := Color("1b2a47")
const NAVY_LIGHT := Color("28406b")
const GREEN: Array = [Color("c2f59a"), Color("86e07c"), Color("4fbb68"), Color("2f8a52"), Color("1f6340")]
const CREAM := Color("fff6dc")

var _glyphs: Dictionary
var _title: Image
var _logo: Image


func _init() -> void:
	var gs := load("res://tools/gen_pixel_font.gd") as GDScript
	_glyphs = gs.get_script_constant_map()["GLYPHS"]
	_title = Image.load_from_file(ProjectSettings.globalize_path("res://assets/ui/title.png"))
	_title.convert(Image.FORMAT_RGBA8)
	_logo = Image.load_from_file(ProjectSettings.globalize_path("res://assets/ui/logo.png"))
	_logo.convert(Image.FORMAT_RGBA8)
	_icon()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://store_art"))
	_capsule("header_920x430", 920, 430, 2, 3, Vector2(0.5, 0.5), true, 0.5)
	_capsule("small_462x174", 462, 174, 1, 2, Vector2(0.5, 0.5), true, 0.5)
	_capsule("main_1232x706", 1232, 706, 3, 6, Vector2(0.5, 0.5), true, 0.5)
	_capsule("vertical_748x896", 748, 896, 4, 4, Vector2(0.5, 0.36), true, 0.5)
	_capsule("library_capsule_600x900", 600, 900, 4, 3, Vector2(0.5, 0.34), true, 0.5)
	_capsule("library_hero_3840x1240", 3840, 1240, 8, 0, Vector2(0.5, 0.5), false, 0.62)
	_library_logo()
	print("wrote assets/icon/icon.png, icon.ico and store_art/*.png")
	quit()


func _scaled(img: Image, k: int) -> Image:
	var out := img.duplicate() as Image
	out.resize(img.get_width() * k, img.get_height() * k, Image.INTERPOLATE_NEAREST)
	return out


## The title picture scaled by `k` and cropped to the middle (`bias_y` 0..1 picks which band when it is taller than needed).
func _background(w: int, h: int, k: int, bias_y: float) -> Image:
	var big := _scaled(_title, k)
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var sx := maxi(0, (big.get_width() - w) / 2)
	var sy := maxi(0, int(float(big.get_height() - h) * bias_y))
	out.blit_rect(big, Rect2i(sx, sy, mini(w, big.get_width()), mini(h, big.get_height())), Vector2i.ZERO)
	return out


func _capsule(file: String, w: int, h: int, bg_k: int, logo_k: int, logo_at: Vector2, with_logo: bool, bias_y: float) -> void:
	var out := _background(w, h, bg_k, bias_y)
	if with_logo and logo_k > 0:
		var logo := _scaled(_logo, logo_k)
		var pos := Vector2i(int(float(w) * logo_at.x) - logo.get_width() / 2, int(float(h) * logo_at.y) - logo.get_height() / 2)
		out.blend_rect(logo, Rect2i(Vector2i.ZERO, logo.get_size()), pos)
	out.save_png(ProjectSettings.globalize_path("res://store_art/%s.png" % file))


func _library_logo() -> void:
	var logo := _scaled(_logo, 8)  # 1280 x 448, on a clear 1280 x 720
	var out := Image.create(1280, 720, false, Image.FORMAT_RGBA8)
	out.blend_rect(logo, Rect2i(Vector2i.ZERO, logo.get_size()), Vector2i(0, (720 - logo.get_height()) / 2))
	out.save_png(ProjectSettings.globalize_path("res://store_art/library_logo_1280x720.png"))


# --- the window icon ---------------------------------------------------------------------------------------------------------

func _icon() -> void:
	var c := PixelCanvas.new(32, 32)
	c.rect(0, 0, 32, 32, STEEL[2])
	c.rect(1, 1, 30, 30, STEEL[0])
	c.rect(2, 2, 28, 28, STEEL[2])
	c.rect(3, 3, 26, 26, NAVY)
	for y in range(3, 29):
		for x in range(3, 29):
			if (x + y) % 6 == 0:
				c.px(x, y, NAVY_LIGHT)
	for p in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(31, 0), Vector2i(30, 0), Vector2i(31, 1), Vector2i(0, 31), Vector2i(1, 31), Vector2i(0, 30), Vector2i(31, 31), Vector2i(30, 31), Vector2i(31, 30)]:
		c.img.set_pixel(p.x, p.y, Color(0, 0, 0, 0))
	# the shield: a lit left half and a shaded right half, with a dark edge
	var shield := PackedVector2Array([Vector2(16, 5), Vector2(26, 8), Vector2(26, 17), Vector2(16, 28), Vector2(6, 17), Vector2(6, 8)])
	c.poly(shield, Color("0e1a14"))
	var inner := PackedVector2Array([Vector2(16, 6.5), Vector2(24.6, 9.1), Vector2(24.6, 16.6), Vector2(16, 26.2), Vector2(7.4, 16.6), Vector2(7.4, 9.1)])
	c.poly_fn(inner, func(x: int, y: int) -> Color:
		var band := clampi(int(float(y - 6) / 20.0 * 4.0), 0, 3)
		return GREEN[band] if x < 16 else GREEN[mini(band + 1, 4)])
	# "LD" in the project's pixel font, with a dark shadow
	_text(c, "LD", 10, 11, Color("0e1a14"), 1)
	_text(c, "LD", 10, 10, CREAM, 0)
	c.save("res://assets/icon/icon.png")
	_ico(c.img)


func _text(c: PixelCanvas, text: String, x: int, y: int, col: Color, shadow: int) -> void:
	var cx := x
	for ch in text:
		var rows: PackedStringArray = (_glyphs[ch] as String).split("/")
		for r in 7:
			for i in rows[0].length():
				if rows[r][i] == "#":
					c.px(cx + i + shadow, y + r, col)
		cx += rows[0].length() + 1


## An .ico with 16, 32, 64, 128 and 256 px pictures stored as PNG (the format Windows has accepted since Vista).
func _ico(art: Image) -> void:
	var sizes := [16, 32, 64, 128, 256]
	var blobs: Array[PackedByteArray] = []
	for s: int in sizes:
		var im := art.duplicate() as Image
		im.resize(s, s, Image.INTERPOLATE_NEAREST)
		blobs.append(im.save_png_to_buffer())
	var head := PackedByteArray()
	head.resize(6 + 16 * sizes.size())
	head.encode_u16(0, 0)
	head.encode_u16(2, 1)
	head.encode_u16(4, sizes.size())
	var offset := head.size()
	for i in sizes.size():
		var e := 6 + 16 * i
		var s: int = sizes[i]
		head.encode_u8(e, 0 if s >= 256 else s)
		head.encode_u8(e + 1, 0 if s >= 256 else s)
		head.encode_u8(e + 2, 0)
		head.encode_u8(e + 3, 0)
		head.encode_u16(e + 4, 1)
		head.encode_u16(e + 6, 32)
		head.encode_u32(e + 8, blobs[i].size())
		head.encode_u32(e + 12, offset)
		offset += blobs[i].size()
	var out := head
	for b in blobs:
		out.append_array(b)
	var f := FileAccess.open(ProjectSettings.globalize_path("res://assets/icon/icon.ico"), FileAccess.WRITE)
	f.store_buffer(out)
	f.close()
	# the 256 px picture is also written as a PNG for the project icon
	var big := art.duplicate() as Image
	big.resize(256, 256, Image.INTERPOLATE_NEAREST)
	big.save_png(ProjectSettings.globalize_path("res://assets/icon/icon.png"))
