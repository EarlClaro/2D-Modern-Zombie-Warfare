class_name PixelFont
extends RefCounted
## The UI's pixel font (docs/specs/pixel-ui.md): a bitmap font made by tools/gen_pixel_font.gd, shown at whole-number
## multiples of its native size 8 (a requested size of 14 to 19 gives 2x, 20 to 27 gives 3x, 28 to 35 gives 4x, ...).
## Presentation only.

const PATH: String = "res://assets/fonts/pixel_font.tres"
const NATIVE_SIZE: int = 8

static var _font: Font = null


## The shared pixel font; the engine's default font if the file is missing.
static func font() -> Font:
	if _font == null:
		_font = load(PATH) as Font if ResourceLoader.exists(PATH) else null
		if _font == null:
			_font = ThemeDB.fallback_font
	return _font


## The first character of `text` the pixel font cannot draw, or "" when it can draw all of it.
static func missing_char(text: String) -> String:
	var f := font()
	for i in text.length():
		var ch := text[i]
		if ch != "\n" and ch != "\t" and not f.has_char(ch.unicode_at(0)):
			return ch
	return ""
