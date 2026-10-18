class_name CardFace
extends Control
## One portrait card as a Control (docs/specs/deck-screen.md): kind colour, cost badge, picture, name banner and a small
## badge text (copies in the deck). A locked card (one the player does not own yet) is drawn in grey with a padlock. Looks like the
## cards in the hand (ui/hand_ui.gd) at a smaller size. Presentation only: it reports clicks and nothing else.

signal picked(card_id: String)
signal activated(card_id: String)

const SIZE := Vector2(116, 160)

var card_id: String = ""
var locked: bool = false
var selected: bool = false
var emphasised: bool = true  # the grid holding the card has the focus: the selection outline is bright
var badge: String = ""

var _def: CardDefinition
var _font: Font
var _hover: bool = false

static var _grey: ShaderMaterial


## The material that turns everything drawn with it grey and dark (locked cards and the picture of a locked card).
static func grey_material() -> ShaderMaterial:
	if _grey == null:
		var sh := Shader.new()
		sh.code = "shader_type canvas_item;\nvoid fragment() {\n\tfloat g = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114));\n\tCOLOR.rgb = vec3(g * 0.62 + 0.03);\n}\n"
		_grey = ShaderMaterial.new()
		_grey.shader = sh
	return _grey


func setup(def: CardDefinition, is_locked: bool, badge_text: String = "") -> void:
	_def = def
	card_id = def.id if def != null else ""
	locked = is_locked
	badge = badge_text
	_apply_look()
	queue_redraw()


func set_badge(text: String) -> void:
	badge = text
	queue_redraw()


func set_selected(on: bool, bright: bool) -> void:
	selected = on
	emphasised = bright
	queue_redraw()


func _apply_look() -> void:
	material = grey_material() if locked else null
	tooltip_text = "%s (locked)" % _def.display_name if locked and _def != null else (_def.display_name if _def != null else "")


func _init() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	_font = PixelFont.font()
	mouse_entered.connect(func() -> void:
		_hover = true
		queue_redraw())
	mouse_exited.connect(func() -> void:
		_hover = false
		queue_redraw())


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		picked.emit(card_id)
		if mb.double_click:
			activated.emit(card_id)
		accept_event()


func _draw() -> void:
	var w := size.x
	var kind_col: Color = HandUi.KIND_COLOR.get(_def.card_kind if _def != null else 0, Color.GRAY)
	var rect := Rect2(Vector2.ZERO, size)
	if selected:
		_notched(rect.grow(4.0), Color(1.0, 0.9, 0.3) if emphasised else Color(0.75, 0.72, 0.5))
	elif _hover:
		_notched(rect.grow(3.0), Color(1, 1, 1, 0.55))
	_box(rect, Color(0.09, 0.10, 0.12), kind_col.darkened(0.25), 2)
	var head := Rect2(Vector2(3, 3), Vector2(w - 6, 24))
	draw_rect(head, kind_col.darkened(0.45))
	draw_rect(Rect2(head.position, Vector2(head.size.x, 3)), kind_col)
	_text(HandUi.KIND_LABEL.get(_def.card_kind if _def != null else 0, ""), Vector2(w - 8, 20), 11, Color(1, 1, 1, 0.8), HORIZONTAL_ALIGNMENT_RIGHT)
	var badge_c := Vector2(22, 22)
	_box(Rect2(badge_c - Vector2(16, 16), Vector2(32, 32)), kind_col.darkened(0.2), Color(0.03, 0.04, 0.04), 2)
	_text("%d" % (_def.cost if _def != null else 0), badge_c + Vector2(0, 6), 15, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	# the picture
	var art := Rect2(Vector2(8, 38), Vector2(w - 16, 78))
	draw_rect(art, kind_col.darkened(0.75))
	draw_rect(Rect2(art.position, Vector2(art.size.x, art.size.y * 0.5)), Color(1, 1, 1, 0.04))
	CardArt.draw_in(self, card_id, art.grow(-2.0), kind_col)
	draw_rect(art, kind_col.darkened(0.3), false, 2.0)
	if locked:
		_padlock(art.get_center())
	elif not badge.is_empty():
		var bw := _font.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 10.0
		var br := Rect2(Vector2(art.end.x - bw - 3.0, art.end.y - 20.0), Vector2(bw, 17.0))
		draw_rect(br, Color(0, 0, 0, 0.72))
		_text(badge, Vector2(br.get_center().x, br.end.y - 3.0), 14, Color(1.0, 0.92, 0.55), HORIZONTAL_ALIGNMENT_CENTER)
	# the name on a banner, up to two lines
	var banner := Rect2(Vector2(6, 120), Vector2(w - 12, 36))
	draw_rect(banner, Color(0, 0, 0, 0.4))
	var lines := HandUi._wrap(_def.display_name if _def != null else "?")
	var ny := banner.position.y + (15.0 if lines.size() > 1 else 23.0)
	for line in lines:
		_text(line, Vector2(w * 0.5, ny), 13 if lines.size() > 1 else 15, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		ny += 15.0


## A padlock (body, shackle and keyhole) on the picture, so the grey card reads as "locked" and not just "dim".
func _padlock(at: Vector2) -> void:
	var body := Rect2(at + Vector2(-11, -2), Vector2(22, 17))
	draw_rect(Rect2(body.position + Vector2(3, -13), Vector2(4, 12)), Color(0.78, 0.8, 0.82))
	draw_rect(Rect2(body.position + Vector2(15, -13), Vector2(4, 12)), Color(0.78, 0.8, 0.82))
	draw_rect(Rect2(body.position + Vector2(3, -15), Vector2(16, 4)), Color(0.78, 0.8, 0.82))
	draw_rect(body.grow(2.0), Color(0, 0, 0, 0.85))
	draw_rect(body, Color(0.82, 0.84, 0.86))
	draw_rect(Rect2(body.position, Vector2(22, 3)), Color(1, 1, 1, 0.55))
	draw_rect(Rect2(body.position + Vector2(9, 5), Vector2(4, 5)), Color(0.15, 0.16, 0.18))
	draw_rect(Rect2(body.position + Vector2(10, 9), Vector2(2, 5)), Color(0.15, 0.16, 0.18))


func _box(r: Rect2, fill: Color, border: Color, border_w: int) -> void:
	_notched(r, border)
	_notched(r.grow(-float(border_w)), fill)


## One filled shape with the corners cut in two 2-pixel steps.
func _notched(r: Rect2, col: Color) -> void:
	var x := r.position.x
	var y := r.position.y
	var w := r.size.x
	var h := r.size.y
	draw_rect(Rect2(x + 4, y, w - 8, 2), col)
	draw_rect(Rect2(x + 2, y + 2, w - 4, 2), col)
	draw_rect(Rect2(x, y + 4, w, h - 8), col)
	draw_rect(Rect2(x + 2, y + h - 4, w - 4, 2), col)
	draw_rect(Rect2(x + 4, y + h - 2, w - 8, 2), col)


func _text(s: String, pos: Vector2, font_size: int, col: Color, align: HorizontalAlignment) -> void:
	var width := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var x := pos.x
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		x -= width * 0.5
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		x -= width
	var at := Vector2(roundf(x), roundf(pos.y))
	draw_string(_font, at + Vector2(1, 1), s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0, col.a * 0.85))
	draw_string(_font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)
