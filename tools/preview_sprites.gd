extends SceneTree
## Dev tool (not a test). Contact sheet of rendered sprite sets for eyeballing: one row per set, one cell per
## facing that exists (se, sw, nw, ne, e, s, w, n), frame 0, bottom-aligned on a grass-coloured ground. Needs the set's assets/sprites/<dir>/frame.json (written by tools/gen_sprites.gd).
## Run: godot --headless --path . --script tools/preview_sprites.gd -- out.png scale dir1 dir2 ...
## `out.png` is a path on disk (a scratch folder, not res://).

const ORDER: Array[String] = ["se", "sw", "nw", "ne", "e", "s", "w", "n"]
const GROUND := Color("56823f")


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 3:
		push_error("usage: -- out.png scale dir1 dir2 ...")
		quit(1)
		return
	var out_path: String = a[0]
	var k := maxi(1, int(a[1]))
	var rows: Array = []  # per set: Array[Image] (frame 0 of each facing)
	var cell := Vector2i(16, 16)
	var cols := 1
	for d in a.slice(2):
		var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites/%s/frame.json" % d))
		if not (meta is Dictionary):
			push_error("no frame.json for %s" % d)
			continue
		var fw := int(meta["frame"][0])
		var fh := int(meta["frame"][1])
		var imgs: Array[Image] = []
		for f in ORDER:
			var path := ProjectSettings.globalize_path("res://assets/sprites/%s/%s.png" % [d, f])
			if not FileAccess.file_exists(path):
				continue
			var img := Image.load_from_file(path)
			imgs.append(img.get_region(Rect2i(0, 0, fw, fh)))
		rows.append(imgs)
		cell = Vector2i(maxi(cell.x, fw), maxi(cell.y, fh))
		cols = maxi(cols, imgs.size())
	var out := Image.create(cell.x * cols * k, cell.y * rows.size() * k, false, Image.FORMAT_RGBA8)
	out.fill(GROUND)
	for r in rows.size():
		for c in rows[r].size():
			var im: Image = rows[r][c].duplicate()
			im.resize(im.get_width() * k, im.get_height() * k, Image.INTERPOLATE_NEAREST)
			var x: int = c * cell.x * k + (cell.x * k - im.get_width()) / 2
			var y: int = r * cell.y * k + (cell.y * k - im.get_height())
			out.blend_rect(im, Rect2i(0, 0, im.get_width(), im.get_height()), Vector2i(x, y))
	var err := out.save_png(out_path)
	print("%s %s (%dx%d)" % ["wrote" if err == OK else "FAILED", out_path, out.get_width(), out.get_height()])
	quit()
