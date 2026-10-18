extends SceneTree
## Dev tool (not a test). The pixel-art look of the interface (docs/specs/pixel-ui.md, increment U.2): draws the panel, button,
## checkbox and slider pieces pixel by pixel (stepped corners, 1 px outline, light and dark bevel), at 2 screen pixels per art
## pixel to match the pixel font, writes them to assets/ui/*.png and builds assets/ui/theme.tres, the project theme.
## Run: godot --headless --path . --script tools/gen_ui_kit.gd

const S: int = 2  # screen pixels per art pixel
const BOX: int = 16  # a box is 16 x 16 art pixels; its edge pieces are 5 px wide
const EDGE_ART: int = 5

# The colours of ui/ui_kit.gd's green-grey palette, as pixel-art ramps.
const OUTLINE := Color("070b09")
const ACCENT := Color("7fd48c")
const TEXT := Color(0.9, 0.93, 0.9)
const DIM := Color(0.62, 0.68, 0.63)

var _tex: Dictionary = {}  # name -> ImageTexture


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/ui"))
	# name, fill, light, dark, outline, inverted bevel
	_box("panel", Color("1b2320"), Color("33463a"), Color("121916"), OUTLINE, false)
	_box("button", Color("2b382d"), Color("4d6650"), Color("1b251e"), OUTLINE, false)
	_box("button_hover", Color("3a4e3d"), Color("6a8f6e"), Color("26352a"), ACCENT, false)
	_box("button_pressed", Color("33503a"), Color("6a8f6e"), Color("1b2a1f"), ACCENT, true)
	_box("button_disabled", Color("1d2420"), Color("2a332d"), Color("151b18"), Color("0c110e"), false)
	_box("button_focus", Color("2b382d"), Color("4d6650"), Color("1b251e"), ACCENT, false)
	_check("check_off", false)
	_check("check_on", true)
	_grabber("slider_grabber", Color("8fb496"), Color("c8e6cd"), Color("5d7e63"))
	_grabber("slider_grabber_hover", Color("b4dcb9"), Color("eaf8ec"), Color("7fa886"))
	_cursor()
	_save_theme()
	print("wrote the UI kit and assets/ui/theme.tres")
	quit()


func _px_image(art: Image) -> ImageTexture:
	var big := Image.create(art.get_width() * S, art.get_height() * S, false, Image.FORMAT_RGBA8)
	for y in art.get_height():
		for x in art.get_width():
			big.fill_rect(Rect2i(x * S, y * S, S, S), art.get_pixel(x, y))
	return ImageTexture.create_from_image(big)


func _store(name: String, art: Image) -> void:
	var tex := _px_image(art)
	tex.get_image().save_png(ProjectSettings.globalize_path("res://assets/ui/%s.png" % name))
	_tex[name] = tex


## Is (x, y) inside a BOX x BOX shape with its corners stepped off (2 px)?
func _inside(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= BOX or y >= BOX:
		return false
	var cx := mini(x, BOX - 1 - x)
	var cy := mini(y, BOX - 1 - y)
	return cx + cy >= 2


func _box(name: String, fill: Color, light: Color, dark: Color, outline: Color, inverted: bool) -> void:
	var img := Image.create(BOX, BOX, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var hi := dark if inverted else light
	var lo := light if inverted else dark
	for y in BOX:
		for x in BOX:
			if not _inside(x, y):
				continue
			if not (_inside(x - 1, y) and _inside(x + 1, y) and _inside(x, y - 1) and _inside(x, y + 1)):
				img.set_pixel(x, y, outline)
			elif not _inside(x, y - 1) or not _inside(x - 1, y) or not (_inside(x - 1, y - 1)):
				img.set_pixel(x, y, fill)  # the pixel next to a stepped corner stays plain
			else:
				img.set_pixel(x, y, fill)
	# bevel: the row and column just inside the outline
	for i in range(2, BOX - 2):
		img.set_pixel(i, 1, hi)  # top
		img.set_pixel(1, i, hi)  # left
		img.set_pixel(i, BOX - 2, lo)  # bottom
		img.set_pixel(BOX - 2, i, lo)  # right
	_store(name, img)


func _check(name: String, on: bool) -> void:
	var n := 9
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(OUTLINE)
	img.fill_rect(Rect2i(1, 1, n - 2, n - 2), Color("2b382d") if not on else Color("3f7a4c"))
	img.fill_rect(Rect2i(1, 1, n - 2, 1), Color("1b251e"))  # a sunken look: dark top and left
	img.fill_rect(Rect2i(1, 1, 1, n - 2), Color("1b251e"))
	img.fill_rect(Rect2i(1, n - 2, n - 2, 1), Color("6a8f6e") if not on else Color("7fd48c"))
	img.fill_rect(Rect2i(n - 2, 1, 1, n - 2), Color("6a8f6e") if not on else Color("7fd48c"))
	if on:
		for p in [Vector2i(2, 4), Vector2i(3, 5), Vector2i(4, 6), Vector2i(5, 5), Vector2i(6, 4), Vector2i(7, 3)]:
			img.set_pixel(p.x - 1, p.y, Color("f2fbf3"))
	_store(name, img)


func _grabber(name: String, fill: Color, light: Color, dark: Color) -> void:
	var w := 7
	var h := 11
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(OUTLINE)
	img.fill_rect(Rect2i(1, 1, w - 2, h - 2), fill)
	img.fill_rect(Rect2i(1, 1, w - 2, 1), light)
	img.fill_rect(Rect2i(1, 1, 1, h - 2), light)
	img.fill_rect(Rect2i(1, h - 2, w - 2, 1), dark)
	img.fill_rect(Rect2i(w - 2, 1, 1, h - 2), dark)
	for p in [Vector2i(0, 0), Vector2i(w - 1, 0), Vector2i(0, h - 1), Vector2i(w - 1, h - 1)]:
		img.set_pixel(p.x, p.y, Color(0, 0, 0, 0))
	_store(name, img)


## The mouse arrow: 12 x 18 art pixels, white with a dark outline, drawn at 2 screen px per art pixel; the tip is the hotspot.
func _cursor() -> void:
	var rows := PackedStringArray([
		"X...........",
		"XX..........",
		"XwX.........",
		"XwwX........",
		"XwwwX.......",
		"XwwwwX......",
		"XwwwwwX.....",
		"XwwwwwwX....",
		"XwwwwwwwX...",
		"XwwwwwwwwX..",
		"XwwwwwXXXXX.",
		"XwwXwwX.....",
		"XwX.XwwX....",
		"XX..XwwX....",
		"X....XwwX...",
		".....XwwX...",
		"......XX....",
		"............",
	])
	var img := Image.create(12, rows.size(), false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in rows.size():
		for x in 12:
			match rows[y][x]:
				"X":
					img.set_pixel(x, y, OUTLINE)
				"w":
					img.set_pixel(x, y, Color("eaf5ea"))
	_store("cursor", img)


func _nine(name: String, margins: Vector4i, content: Vector4) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = _tex[name]
	sb.texture_margin_left = margins.x * S
	sb.texture_margin_top = margins.y * S
	sb.texture_margin_right = margins.z * S
	sb.texture_margin_bottom = margins.w * S
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	sb.content_margin_left = content.x
	sb.content_margin_top = content.y
	sb.content_margin_right = content.z
	sb.content_margin_bottom = content.w
	return sb


func _flat(col: Color, edge: Color, border: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.border_color = edge
	sb.set_border_width_all(border)
	sb.set_corner_radius_all(0)
	return sb


func _save_theme() -> void:
	var t := Theme.new()
	var m := Vector4i(EDGE_ART, EDGE_ART, EDGE_ART, EDGE_ART)
	var pad := Vector4(18, 10, 18, 10)  # the same room around the content as the flat boxes had
	t.default_font = load("res://assets/fonts/pixel_font.tres") as Font
	t.default_font_size = 16

	t.set_color("font_color", "Label", TEXT)

	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var tex_name: String = "button" if state == "normal" else "button_" + state
		t.set_stylebox(state, "Button", _nine(tex_name, m, pad))
		t.set_stylebox(state, "OptionButton", _nine(tex_name, m, pad))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_focus_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(DIM, 0.6))

	t.set_stylebox("panel", "PanelContainer", _nine("panel", m, Vector4(20, 14, 20, 14)))
	t.set_stylebox("panel", "Panel", _nine("panel", m, Vector4(20, 14, 20, 14)))

	# lists: the list itself is a panel, a hovered row looks like a hovered button, the selected one like a pressed one
	t.set_stylebox("panel", "ItemList", _nine("panel", m, Vector4(10, 8, 10, 8)))
	t.set_stylebox("focus", "ItemList", StyleBoxEmpty.new())
	t.set_stylebox("hovered", "ItemList", _nine("button_hover", m, Vector4(8, 6, 8, 6)))
	t.set_stylebox("selected", "ItemList", _nine("button_pressed", m, Vector4(8, 6, 8, 6)))
	t.set_stylebox("selected_focus", "ItemList", _nine("button_pressed", m, Vector4(8, 6, 8, 6)))
	t.set_stylebox("hovered_selected", "ItemList", _nine("button_pressed", m, Vector4(8, 6, 8, 6)))
	t.set_stylebox("hovered_selected_focus", "ItemList", _nine("button_pressed", m, Vector4(8, 6, 8, 6)))
	t.set_color("font_color", "ItemList", TEXT)
	t.set_color("font_hovered_color", "ItemList", Color.WHITE)
	t.set_color("font_selected_color", "ItemList", Color.WHITE)
	t.set_color("font_outline_color", "ItemList", Color(0, 0, 0, 0))
	t.set_constant("v_separation", "ItemList", 6)

	for kind in ["CheckButton", "CheckBox"]:
		t.set_icon("checked", kind, _tex["check_on"])
		t.set_icon("unchecked", kind, _tex["check_off"])
		t.set_icon("checked_disabled", kind, _tex["check_on"])
		t.set_icon("unchecked_disabled", kind, _tex["check_off"])
		t.set_icon("checked_mirrored", kind, _tex["check_on"])
		t.set_icon("unchecked_mirrored", kind, _tex["check_off"])
		t.set_icon("checked_disabled_mirrored", kind, _tex["check_on"])
		t.set_icon("unchecked_disabled_mirrored", kind, _tex["check_off"])
		for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			t.set_stylebox(state, kind, StyleBoxEmpty.new())
		t.set_color("font_color", kind, TEXT)
		t.set_color("font_hover_color", kind, Color.WHITE)
		t.set_color("font_pressed_color", kind, TEXT)
		t.set_color("font_hover_pressed_color", kind, Color.WHITE)
		t.set_color("font_focus_color", kind, Color.WHITE)
		t.set_constant("h_separation", kind, 12)

	t.set_stylebox("slider", "HSlider", _flat(Color("131a16"), OUTLINE, 2))
	t.set_stylebox("grabber_area", "HSlider", _flat(Color("3f7a4c"), OUTLINE, 2))
	t.set_stylebox("grabber_area_highlight", "HSlider", _flat(Color("4f9a60"), OUTLINE, 2))
	t.set_icon("grabber", "HSlider", _tex["slider_grabber"])
	t.set_icon("grabber_highlight", "HSlider", _tex["slider_grabber_hover"])
	t.set_icon("grabber_disabled", "HSlider", _tex["slider_grabber"])
	t.set_constant("center_grabber", "HSlider", 0)

	t.set_stylebox("background", "ProgressBar", _flat(Color("131a16"), OUTLINE, 2))
	t.set_stylebox("fill", "ProgressBar", _flat(Color("4f9a60"), OUTLINE, 0))
	t.set_color("font_color", "ProgressBar", TEXT)

	for bar in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", bar, _flat(Color("131a16"), OUTLINE, 2))
		t.set_stylebox("grabber", bar, _flat(Color("4d6650"), OUTLINE, 2))
		t.set_stylebox("grabber_highlight", bar, _flat(Color("6a8f6e"), OUTLINE, 2))
		t.set_stylebox("grabber_pressed", bar, _flat(Color("8fb496"), OUTLINE, 2))

	var err := ResourceSaver.save(t, "res://assets/ui/theme.tres")
	if err != OK:
		push_error("saving the theme failed (%d)" % err)
