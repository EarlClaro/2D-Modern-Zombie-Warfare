class_name UiKit
extends RefCounted
## Small shared look for the menus (docs/specs/menus.md): colours, flat buttons, panels, labels. Code-built like the
## rest of `ui/`; final art and animation belong to Milestone 7.

const BG := Color(0.06, 0.08, 0.07)
const PANEL := Color(0.11, 0.14, 0.12, 0.96)
const EDGE := Color(0.3, 0.42, 0.33)
const ACCENT := Color(0.55, 0.88, 0.6)
const TEXT := Color(0.9, 0.93, 0.9)
const DIM := Color(0.62, 0.68, 0.63)
const BUTTON := Color(0.16, 0.21, 0.17)
const BUTTON_HOVER := Color(0.24, 0.33, 0.26)
const BUTTON_DOWN := Color(0.3, 0.45, 0.33)


static func _box(col: Color, edge: Color = EDGE, border: int = 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_border_width_all(border)
	sb.border_color = edge
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 18.0
	sb.content_margin_right = 18.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0
	return sb


static func button(text: String, font_size: int = 28, min_size: Vector2 = Vector2(380, 64)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_stylebox_override("normal", _box(BUTTON))
	b.add_theme_stylebox_override("hover", _box(BUTTON_HOVER, ACCENT))
	b.add_theme_stylebox_override("pressed", _box(BUTTON_DOWN, ACCENT))
	b.add_theme_stylebox_override("focus", _box(BUTTON_HOVER, ACCENT, 3))
	return b


static func label(text: String, font_size: int = 24, col: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", col)
	return l


static func panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _box(PANEL))
	return p


static func background() -> ColorRect:
	var r := ColorRect.new()
	r.color = BG
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## A full-screen container that centres its single child.
static func centered() -> CenterContainer:
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c
