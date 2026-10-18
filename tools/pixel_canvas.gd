class_name PixelCanvas
extends RefCounted
## Dev-tool helper for the generated pixel art (docs/specs/art-polish.md): a small RGBA canvas with hard-edged shapes (no
## anti-aliasing), banded shading, ordered-dither fills, an outline pass and integer blits. Used by tools/gen_card_pictures.gd and
## tools/gen_logo.gd. Deterministic: no randomness, only hashes of the pixel position.

const BAYER: Array = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
const OUTLINE := Color("1a120f")

var img: Image
var w: int
var h: int


func _init(width: int, height: int) -> void:
	w = width
	h = height
	img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))


func px(x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < w and y < h:
		img.set_pixel(x, y, c)


func get_px(x: int, y: int) -> Color:
	if x < 0 or y < 0 or x >= w or y >= h:
		return Color(0, 0, 0, 0)
	return img.get_pixel(x, y)


func rect(x: int, y: int, rw: int, rh: int, c: Color) -> void:
	for yy in range(y, y + rh):
		for xx in range(x, x + rw):
			px(xx, yy, c)


func bayer(x: int, y: int) -> float:
	return float(BAYER[(y & 3) * 4 + (x & 3)]) / 16.0


## A filled ellipse (centre in pixel units, may be fractional).
func ellipse(cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
	for y in range(int(floorf(cy - ry)), int(ceilf(cy + ry)) + 1):
		for x in range(int(floorf(cx - rx)), int(ceilf(cx + rx)) + 1):
			var dx := (float(x) + 0.5 - cx) / rx
			var dy := (float(y) + 0.5 - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				px(x, y, c)


## An ellipse shaded in hard bands, light from the upper left. `ramp` runs light to dark.
func ellipse_ramp(cx: float, cy: float, rx: float, ry: float, ramp: Array) -> void:
	for y in range(int(floorf(cy - ry)), int(ceilf(cy + ry)) + 1):
		for x in range(int(floorf(cx - rx)), int(ceilf(cx + rx)) + 1):
			var dx := (float(x) + 0.5 - cx) / rx
			var dy := (float(y) + 0.5 - cy) / ry
			var d2 := dx * dx + dy * dy
			if d2 <= 1.0:
				var lit := clampf(0.42 + (dx * 0.55 + dy * 0.75) * 0.5 + d2 * 0.18, 0.0, 0.999)
				px(x, y, ramp[int(lit * float(ramp.size()))])


## A dithered ellipse: pixels are set where the ordered-dither threshold is below `density` (0..1), fading to the rim.
func ellipse_dither(cx: float, cy: float, rx: float, ry: float, c: Color, density: float, fade: bool = true) -> void:
	for y in range(int(floorf(cy - ry)), int(ceilf(cy + ry)) + 1):
		for x in range(int(floorf(cx - rx)), int(ceilf(cx + rx)) + 1):
			var dx := (float(x) + 0.5 - cx) / rx
			var dy := (float(y) + 0.5 - cy) / ry
			var d2 := dx * dx + dy * dy
			if d2 <= 1.0:
				var k := density * ((1.0 - d2) * 1.6 if fade else 1.0)
				if bayer(x, y) < k:
					px(x, y, c)


## A ring (an iso circle) one pixel thick, optionally only the part where `keep.call(x, y)` is true.
func ring(cx: float, cy: float, rx: float, ry: float, c: Color, thick: float = 1.0) -> void:
	for y in range(int(floorf(cy - ry - thick)), int(ceilf(cy + ry + thick)) + 1):
		for x in range(int(floorf(cx - rx - thick)), int(ceilf(cx + rx + thick)) + 1):
			var dx := (float(x) + 0.5 - cx) / rx
			var dy := (float(y) + 0.5 - cy) / ry
			var d := sqrt(dx * dx + dy * dy)
			var half := thick / ((rx + ry) * 0.5)
			if absf(d - 1.0) <= half * 0.5:
				px(x, y, c)


func poly(pts: PackedVector2Array, c: Color) -> void:
	var lo := Vector2(1e9, 1e9)
	var hi := Vector2(-1e9, -1e9)
	for p in pts:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	for y in range(int(floorf(lo.y)), int(ceilf(hi.y)) + 1):
		for x in range(int(floorf(lo.x)), int(ceilf(hi.x)) + 1):
			if Geometry2D.is_point_in_polygon(Vector2(float(x) + 0.5, float(y) + 0.5), pts):
				px(x, y, c)


## A polygon shaded by a function of the pixel: `shade.call(x, y)` returns the colour.
func poly_fn(pts: PackedVector2Array, shade: Callable) -> void:
	var lo := Vector2(1e9, 1e9)
	var hi := Vector2(-1e9, -1e9)
	for p in pts:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	for y in range(int(floorf(lo.y)), int(ceilf(hi.y)) + 1):
		for x in range(int(floorf(lo.x)), int(ceilf(hi.x)) + 1):
			if Geometry2D.is_point_in_polygon(Vector2(float(x) + 0.5, float(y) + 0.5), pts):
				px(x, y, shade.call(x, y) as Color)


## A line of whole pixels, `thick` px wide.
func line(a: Vector2, b: Vector2, c: Color, thick: float = 1.0) -> void:
	var n := int(maxf(absf(b.x - a.x), absf(b.y - a.y))) + 1
	for i in n + 1:
		var p := a.lerp(b, float(i) / float(maxi(n, 1)))
		var r := thick * 0.5
		for y in range(int(floorf(p.y - r)), int(ceilf(p.y + r)) + 1):
			for x in range(int(floorf(p.x - r)), int(ceilf(p.x + r)) + 1):
				if Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(p) <= r + 0.25:
					px(x, y, c)


## A vertical cylinder (`x`..`x + cw`, `y`..`y + ch`) shaded across its width, light on the left.
func vcyl(x: int, y: int, cw: int, ch: int, ramp: Array) -> void:
	for i in cw:
		var nx := (float(i) + 0.5) / float(cw) * 2.0 - 1.0
		var idx := int(clampf(nx * 0.55 + 0.35, 0.0, 0.999) * float(ramp.size()))
		for j in ch:
			px(x + i, y + j, ramp[idx])


## Puts a 1 px outline around everything opaque. Pixels that are empty or only a soft shadow (alpha < 0.9) take the outline.
func outline(c: Color = OUTLINE) -> void:
	var src := img.duplicate() as Image
	for y in h:
		for x in w:
			if src.get_pixel(x, y).a >= 0.9:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx >= 0 and ny >= 0 and nx < w and ny < h and src.get_pixel(nx, ny).a >= 0.9:
					img.set_pixel(x, y, c)
					break


## A soft contact shadow: a dithered dark ellipse. Draw it before the object.
func shadow(cx: float, cy: float, rx: float, ry: float, density: float = 0.8) -> void:
	ellipse_dither(cx, cy, rx, ry, Color(0.0, 0.0, 0.0, 0.5), density, true)


## Copies `src` (any size) onto the canvas at `at`, scaled by a whole number, transparent pixels skipped.
func blit(src: Image, at: Vector2i, k: int = 1) -> void:
	for y in src.get_height():
		for x in src.get_width():
			var c := src.get_pixel(x, y)
			if c.a < 0.5:
				continue
			for j in k:
				for i in k:
					px(at.x + x * k + i, at.y + y * k + j, c)


func save(path: String) -> void:
	img.save_png(ProjectSettings.globalize_path(path))
