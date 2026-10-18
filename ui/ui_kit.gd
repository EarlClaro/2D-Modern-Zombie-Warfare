class_name UiKit
extends RefCounted
## Small shared helpers for the menus (docs/specs/menus.md): colours, buttons, panels, labels. The pixel-art look (font, panels,
## buttons, lists, checkboxes, sliders) lives in the project theme assets/ui/theme.tres (docs/specs/pixel-ui.md).

const BG := Color(0.06, 0.08, 0.07)
const EDGE := Color(0.3, 0.42, 0.33)
const ACCENT := Color(0.55, 0.88, 0.6)
const TEXT := Color(0.9, 0.93, 0.9)
const DIM := Color(0.62, 0.68, 0.63)


static func button(text: String, font_size: int = 28, min_size: Vector2 = Vector2(380, 64)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", font_size)
	return b


static func label(text: String, font_size: int = 24, col: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", col)
	return l


static func panel() -> PanelContainer:
	return PanelContainer.new()  # the pixel panel comes from the project theme (assets/ui/theme.tres)


## The picture behind the main menu (assets/ui/title.png, made by tools/gen_title_art.gd), shown in whole pixels and cropped
## to fill the screen; a plain dark rectangle if the file is missing.
static func title_background() -> Control:
	var path := "res://assets/ui/title.png"
	if not ResourceLoader.exists(path):
		return background()
	var r := TextureRect.new()
	r.texture = load(path) as Texture2D
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


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
