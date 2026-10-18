class_name FxSheet
extends RefCounted
## Pixel-art frame strips for the combat effects (assets/fx/*.png, made by tools/gen_fx_sheets.gd): square frames side by side.
## The effect nodes pick the frame from their age and draw it scaled to the size they need. Presentation only.

static var _cache: Dictionary = {}  # name -> Texture2D


static func texture(sheet: String) -> Texture2D:
	if not _cache.has(sheet):
		var path := "res://assets/fx/%s.png" % sheet
		_cache[sheet] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _cache[sheet]


static func frame_count(sheet: String) -> int:
	var t := texture(sheet)
	return 0 if t == null else int(t.get_width() / maxi(1, t.get_height()))


## The frame of `sheet` for progress 0..1 through frames `first` .. `last` (inclusive).
static func frame_at(progress: float, first: int, last: int) -> int:
	return clampi(first + int(clampf(progress, 0.0, 0.9999) * float(last - first + 1)), first, last)


## Draws frame `i` of `sheet` into `rect` (local coordinates of `ci`). Does nothing when the sheet is missing.
static func draw(ci: CanvasItem, sheet: String, i: int, rect: Rect2, tint: Color = Color.WHITE) -> bool:
	var t := texture(sheet)
	if t == null:
		return false
	var fh := t.get_height()
	var f := clampi(i, 0, frame_count(sheet) - 1)
	ci.draw_texture_rect_region(t, rect, Rect2(f * fh, 0, fh, fh), tint)
	return true


## Draws frame `i` centred on `center`, `size` px square.
static func draw_centered(ci: CanvasItem, sheet: String, i: int, center: Vector2, size: float, tint: Color = Color.WHITE) -> bool:
	return draw(ci, sheet, i, Rect2((center - Vector2(size, size) * 0.5).round(), Vector2(size, size)), tint)
