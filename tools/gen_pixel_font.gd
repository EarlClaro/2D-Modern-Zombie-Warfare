extends SceneTree
## Dev tool (not a test). The UI's pixel font (docs/specs/pixel-ui.md, increment U.1): original 5 x 7 glyph bitmaps
## (descenders use 2 more rows) packed into a bitmap `FontFile`, saved as assets/fonts/pixel_font.tres, plus
## assets/fonts/pixel_font.png (the atlas, for looking at).
## Glyph widths are proportional. The font's native size is 8 and it is shown at whole-number multiples of that:
## a requested size of 14 to 19 gives 2x, 20 to 27 gives 3x, and so on (Godot rounds to the nearest multiple).
## Run: godot --headless --path . --script tools/gen_pixel_font.gd

const NATIVE: int = 8  # the font's fixed size: requested size / 8 = the pixel scale
const ASCENT: int = 7  # rows above the baseline (capitals are 7 rows tall)
const DESCENT: int = 2  # rows below it (descenders)
const ROWS: int = ASCENT + DESCENT
const ATLAS_W: int = 256

## char -> rows top to bottom, separated by "/": 7 rows for glyphs that sit on the baseline, 9 when they descend.
## `#` is ink, anything else is empty. The first row's length is the glyph width.
const GLYPHS: Dictionary = {
	" ": ".../.../.../.../.../.../...",
	"!": "#/#/#/#/#/./#",
	"\"": "#.#/#.#/.../.../.../.../...",
	"#": ".#.#./.#.#./#####/.#.#./#####/.#.#./.#.#.",
	"$": "..#../.####/#.#../.###./..#.#/####./..#..",
	"%": "##..#/##..#/...#./..#../.#.../#..##/#..##",
	"&": ".##../#..#./#.#../.#.../#.#.#/#..#./.##.#",
	"'": "#/#/././././.",
	"(": "..#/.#./#../#../#../.#./..#",
	")": "#../.#./..#/..#/..#/.#./#..",
	"*": "...../#.#.#/.###./..#../.###./#.#.#/.....",
	"+": "...../..#../..#../#####/..#../..#../.....",
	",": "../../../../../.#/.#/#.",
	"-": "..../..../..../####/..../..../....",
	".": "././././././#",
	"/": "....#/....#/...#./..#../.#.../#..../#....",
	"0": ".###./#...#/#..##/#.#.#/##..#/#...#/.###.",
	"1": "..#../.##../..#../..#../..#../..#../.###.",
	"2": ".###./#...#/....#/...#./..#../.#.../#####",
	"3": "####./....#/....#/.###./....#/....#/####.",
	"4": "...#./..##./.#.#./#..#./#####/...#./...#.",
	"5": "#####/#..../####./....#/....#/#...#/.###.",
	"6": ".###./#..../#..../####./#...#/#...#/.###.",
	"7": "#####/....#/...#./..#../.#.../.#.../.#...",
	"8": ".###./#...#/#...#/.###./#...#/#...#/.###.",
	"9": ".###./#...#/#...#/.####/....#/....#/.###.",
	":": "././#/././#/.",
	";": "../../.#/../../.#/.#/#./..",
	"<": "...#./..#../.#.../#..../.#.../..#../...#.",
	"=": "...../...../#####/...../#####/...../.....",
	">": ".#.../..#../...#./....#/...#./..#../.#...",
	"?": ".###./#...#/....#/...#./..#../...../..#..",
	"@": ".###./#...#/#.###/#.#.#/#.###/#..../.####",
	"A": ".###./#...#/#...#/#####/#...#/#...#/#...#",
	"B": "####./#...#/#...#/####./#...#/#...#/####.",
	"C": ".####/#..../#..../#..../#..../#..../.####",
	"D": "####./#...#/#...#/#...#/#...#/#...#/####.",
	"E": "#####/#..../#..../####./#..../#..../#####",
	"F": "#####/#..../#..../####./#..../#..../#....",
	"G": ".####/#..../#..../#..##/#...#/#...#/.###.",
	"H": "#...#/#...#/#...#/#####/#...#/#...#/#...#",
	"I": "###/.#./.#./.#./.#./.#./###",
	"J": "..###/...#./...#./...#./...#./#..#./.##..",
	"K": "#...#/#..#./#.#../##.../#.#../#..#./#...#",
	"L": "#..../#..../#..../#..../#..../#..../#####",
	"M": "#...#/##.##/#.#.#/#.#.#/#...#/#...#/#...#",
	"N": "#...#/##..#/#.#.#/#..##/#...#/#...#/#...#",
	"O": ".###./#...#/#...#/#...#/#...#/#...#/.###.",
	"P": "####./#...#/#...#/####./#..../#..../#....",
	"Q": ".###./#...#/#...#/#...#/#.#.#/#..#./.##.#",
	"R": "####./#...#/#...#/####./#.#../#..#./#...#",
	"S": ".####/#..../#..../.###./....#/....#/####.",
	"T": "#####/..#../..#../..#../..#../..#../..#..",
	"U": "#...#/#...#/#...#/#...#/#...#/#...#/.###.",
	"V": "#...#/#...#/#...#/#...#/#...#/.#.#./..#..",
	"W": "#...#/#...#/#...#/#.#.#/#.#.#/##.##/#...#",
	"X": "#...#/#...#/.#.#./..#../.#.#./#...#/#...#",
	"Y": "#...#/#...#/.#.#./..#../..#../..#../..#..",
	"Z": "#####/....#/...#./..#../.#.../#..../#####",
	"[": "###/#../#../#../#../#../###",
	"\\": "#..../#..../.#.../..#../...#./....#/....#",
	"]": "###/..#/..#/..#/..#/..#/###",
	"^": "..#../.#.#./#...#/...../...../...../.....",
	"_": "...../...../...../...../...../...../...../#####",
	"`": "#./.#/../../../../..",
	"a": "...../...../.###./....#/.####/#...#/.####",
	"b": "#..../#..../####./#...#/#...#/#...#/####.",
	"c": "...../...../.###./#..../#..../#...#/.###.",
	"d": "....#/....#/.####/#...#/#...#/#...#/.####",
	"e": "...../...../.###./#...#/#####/#..../.###.",
	"f": ".##/#../###/#../#../#../#..",
	"g": "...../...../.####/#...#/#...#/#...#/.####/....#/.###.",
	"h": "#..../#..../####./#...#/#...#/#...#/#...#",
	"i": "#/././#/#/#/#",
	"j": ".#/../.#/.#/.#/.#/.#/.#/#.",
	"k": "#..../#..../#..#./#.#../##.../#.#../#..#.",
	"l": "#/#/#/#/#/#/#",
	"m": "...../...../##.#./#.#.#/#.#.#/#.#.#/#.#.#",
	"n": "...../...../####./#...#/#...#/#...#/#...#",
	"o": "...../...../.###./#...#/#...#/#...#/.###.",
	"p": "...../...../####./#...#/#...#/#...#/####./#..../#....",
	"q": "...../...../.####/#...#/#...#/#...#/.####/....#/....#",
	"r": "..../..../#.##/##../#.../#.../#...",
	"s": "...../...../.####/#..../.###./....#/####.",
	"t": "#../#../###/#../#../#../.##",
	"u": "...../...../#...#/#...#/#...#/#...#/.####",
	"v": "...../...../#...#/#...#/#...#/.#.#./..#..",
	"w": "...../...../#...#/#...#/#.#.#/#.#.#/.#.#.",
	"x": "...../...../#...#/.#.#./..#../.#.#./#...#",
	"y": "...../...../#...#/#...#/#...#/#...#/.####/....#/.###.",
	"z": "...../...../#####/...#./..#../.#.../#####",
	"{": "..##/.#../.#../#.../.#../.#../..##",
	"|": "#/#/#/#/#/#/#/#/#",
	"}": "##../..#./..#./...#/..#./..#./##..",
	"~": "...../...../.#..#/#.##./...../...../.....",
	"—": "#######/......./......./#######/......./......./.......",
}

var _errors: int = 0


func _init() -> void:
	var codes: Array = []
	for ch in GLYPHS.keys():
		codes.append(ch.unicode_at(0))
	codes.sort()
	# Pack the glyphs left to right, top to bottom, one pixel apart.
	var placed: Dictionary = {}  # code -> Rect2i in the atlas
	var x := 1
	var y := 1
	for code in codes:
		var rows: PackedStringArray = (GLYPHS[char(code)] as String).split("/")
		var w := rows[0].length()
		if x + w + 1 > ATLAS_W:
			x = 1
			y += ROWS + 1
		placed[code] = Rect2i(x, y, w, ROWS)
		x += w + 1
	var height := y + ROWS + 1
	var img := Image.create(ATLAS_W, height, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for code in codes:
		var rows: PackedStringArray = (GLYPHS[char(code)] as String).split("/")
		var r: Rect2i = placed[code]
		if rows.size() < ASCENT or rows.size() > ROWS:
			push_error("glyph '%s' has %d rows (need %d to %d)" % [char(code), rows.size(), ASCENT, ROWS])
			_errors += 1
		for j in rows.size():
			if rows[j].length() != r.size.x:
				push_error("glyph '%s' row %d is %d wide, row 0 is %d" % [char(code), j, rows[j].length(), r.size.x])
				_errors += 1
				continue
			for i in rows[j].length():
				if rows[j][i] == "#":
					img.set_pixel(r.position.x + i, r.position.y + j, Color.WHITE)
	img.save_png(ProjectSettings.globalize_path("res://assets/fonts/pixel_font.png"))

	var f := FontFile.new()
	f.fixed_size = NATIVE
	f.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	f.allow_system_fallback = false
	f.font_name = "Last Defense Pixel"
	var sz := Vector2i(NATIVE, 0)
	f.set_cache_ascent(0, NATIVE, float(ASCENT))
	f.set_cache_descent(0, NATIVE, float(DESCENT))
	f.set_texture_image(0, sz, 0, img)
	for code in codes:
		var r: Rect2i = placed[code]
		f.set_glyph_advance(0, NATIVE, code, Vector2(r.size.x + 1, 0))
		f.set_glyph_offset(0, sz, code, Vector2(0, -ASCENT))
		f.set_glyph_size(0, sz, code, Vector2(r.size))
		f.set_glyph_uv_rect(0, sz, code, Rect2(r))
		f.set_glyph_texture_idx(0, sz, code, 0)
	var err := ResourceSaver.save(f, "res://assets/fonts/pixel_font.tres")
	if err != OK:
		push_error("saving the font failed (%d)" % err)
		_errors += 1
	print("wrote ", codes.size(), " glyphs, atlas ", img.get_size())
	quit(1 if _errors > 0 else 0)
