class_name HandUi
extends CanvasLayer
## The player's hand: five card slots, the Command Point bar, the draw timer and pile counts, a refusal toast
## and a tooltip that says why the card under the cursor can't go there. Presentation only: it reads
## BattleController state and sends clicks back through select_slot() / cancel_selection().

const SLOT_COUNT: int = 5
const SLOT_SIZE := Vector2(168, 118)
const SLOT_GAP: float = 10.0
const HAND_TOP: float = 898.0
const SELECT_RAISE: float = 14.0
const BASE_SIZE := Vector2(1920, 1080)  # matches project.godot's base resolution
const TOAST_S: float = 1.6
const SHAKE_S: float = 0.35

const KIND_COLOR: Dictionary = {
	CardDefinition.CardKind.DEPLOYMENT: Color(0.30, 0.58, 0.38),
	CardDefinition.CardKind.OPERATION: Color(0.86, 0.52, 0.2),
	CardDefinition.CardKind.SORTIE: Color(0.38, 0.55, 0.88),
	CardDefinition.CardKind.ORDER: Color(0.78, 0.68, 0.25),
	CardDefinition.CardKind.SUPPLY: Color(0.35, 0.72, 0.72),
	CardDefinition.CardKind.DECK: Color(0.66, 0.5, 0.82),
	CardDefinition.CardKind.DOCTRINE: Color(0.55, 0.55, 0.6),
	CardDefinition.CardKind.TRAP: Color(0.72, 0.38, 0.30),
	CardDefinition.CardKind.INTEL: Color(0.42, 0.62, 0.78),
	CardDefinition.CardKind.REINFORCEMENT: Color(0.40, 0.66, 0.46),
}
const KIND_LABEL: Dictionary = {
	CardDefinition.CardKind.DEPLOYMENT: "DEPLOY",
	CardDefinition.CardKind.OPERATION: "STRIKE",
	CardDefinition.CardKind.SORTIE: "AIR",
	CardDefinition.CardKind.ORDER: "ORDER",
	CardDefinition.CardKind.SUPPLY: "SUPPLY",
	CardDefinition.CardKind.DECK: "DECK",
	CardDefinition.CardKind.DOCTRINE: "DOCTRINE",
	CardDefinition.CardKind.TRAP: "TRAP",
	CardDefinition.CardKind.INTEL: "LURE",
	CardDefinition.CardKind.REINFORCEMENT: "CONVOY",
}

var _battle: BattleController
var _surface: Control
var _font: Font
var _toast: String = ""
var _toast_t: float = 0.0
var _shake_slot: int = -1
var _shake_t: float = 0.0


## Top-left of slot `i` in UI (base-resolution) coordinates, before selection raise.
static func slot_rect(i: int) -> Rect2:
	var total := SLOT_COUNT * SLOT_SIZE.x + (SLOT_COUNT - 1) * SLOT_GAP
	var x0 := (BASE_SIZE.x - total) * 0.5
	return Rect2(Vector2(x0 + i * (SLOT_SIZE.x + SLOT_GAP), HAND_TOP), SLOT_SIZE)


## Which slot (0..SLOT_COUNT-1) is under `pos`, or -1.
static func slot_at(pos: Vector2) -> int:
	for i in SLOT_COUNT:
		if slot_rect(i).grow(2.0).has_point(pos):
			return i
	return -1


## The area that captures mouse clicks (hand, CP bar, draw timer); the rest of the screen passes clicks to the field.
static func capture_rect() -> Rect2:
	var first := slot_rect(0)
	var last := slot_rect(SLOT_COUNT - 1)
	return Rect2(first.position.x - 6.0, HAND_TOP - 56.0, last.end.x - first.position.x + 12.0, SLOT_SIZE.y + 56.0 + 36.0)


func bind(battle: BattleController) -> void:
	_battle = battle
	battle.card_rejected.connect(_on_rejected)
	battle.card_played.connect(_on_played)


func _ready() -> void:
	layer = 6
	_font = ThemeDB.fallback_font
	_surface = Control.new()
	_surface.name = "Surface"
	var r := capture_rect()
	_surface.position = r.position
	_surface.size = r.size
	_surface.mouse_filter = Control.MOUSE_FILTER_STOP
	_surface.draw.connect(_draw_surface)
	_surface.gui_input.connect(_on_gui_input)
	add_child(_surface)


func _process(delta: float) -> void:
	_toast_t = maxf(_toast_t - delta, 0.0)
	_shake_t = maxf(_shake_t - delta, 0.0)
	_surface.queue_redraw()


func _on_gui_input(event: InputEvent) -> void:
	if _battle == null or not (event is InputEventMouseButton) or not event.pressed:
		return
	var pos: Vector2 = event.position + _surface.position
	if event.button_index == MOUSE_BUTTON_LEFT:
		var slot := slot_at(pos)
		if slot >= 0:
			_battle.select_slot(slot)
		_surface.accept_event()
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		_battle.cancel_selection()
		_surface.accept_event()


func _on_rejected(slot: int, result: CardPlayService.Result) -> void:
	_toast = CardTargeting.message_for(result, _battle.deck)
	_toast_t = TOAST_S
	_shake_slot = slot
	_shake_t = SHAKE_S


func _on_played(card: CardDefinition, _cell: Vector2i) -> void:
	_toast = ""
	_toast_t = 0.0


# --- drawing (surface-local coordinates; `o` converts from UI coordinates) -------------------------------------

func _draw_surface() -> void:
	if _battle == null or _battle.deck == null:
		return
	var o := -_surface.position
	_draw_cp_bar(o)
	_draw_active_effects(o)
	for i in SLOT_COUNT:
		_draw_slot(i, o)
	_draw_draw_timer(o)
	_draw_toast(o)
	_draw_tooltip()


func _draw_cp_bar(o: Vector2) -> void:
	var points := _battle.points
	var first := slot_rect(0)
	var total_w := slot_rect(SLOT_COUNT - 1).end.x - first.position.x
	var pips := int(points.cap)
	var gap := 6.0
	var w := (total_w - gap * (pips - 1)) / pips
	var y := HAND_TOP - 30.0
	var whole := points.whole()
	var spend := 0
	if _battle.preview != null and _battle.preview.card != null:
		spend = _battle.preview.card.cost
	_text("CP  %d / %d" % [whole, pips], Vector2(first.position.x, y - 6.0) + o, 22, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	for i in pips:
		var rect := Rect2(Vector2(first.position.x + i * (w + gap), y) + o, Vector2(w, 16.0))
		_surface.draw_rect(rect, Color(0.08, 0.09, 0.11, 0.9))
		var fill := 0.0
		if i < whole:
			fill = 1.0
		elif i == whole:
			fill = clampf(points.cp - float(whole), 0.0, 1.0)
		if fill > 0.0:
			_surface.draw_rect(Rect2(rect.position, Vector2(rect.size.x * fill, rect.size.y)), Color(0.4, 0.85, 1.0) if fill >= 1.0 else Color(0.25, 0.5, 0.65))
		if spend > 0 and i < whole and i >= whole - spend:
			_surface.draw_rect(rect, Color(1.0, 0.85, 0.2), false, 2.0)  # these pips would be spent
		else:
			_surface.draw_rect(rect, Color(0, 0, 0, 0.8), false, 1.0)


## Orders and doctrines in force, one line each above the CP bar: name and seconds left (doctrines have none).
func _draw_active_effects(o: Vector2) -> void:
	var y := HAND_TOP - 62.0
	for a in _battle.modifiers.active():
		var label := a.effect.display_name if a.is_permanent() else "%s  %ds" % [a.effect.display_name, ceili(a.time_left)]
		_text(label, Vector2(slot_rect(0).position.x, y) + o, 20, Color(1.0, 0.9, 0.45), HORIZONTAL_ALIGNMENT_LEFT)
		y -= 24.0


func _draw_slot(i: int, o: Vector2) -> void:
	var rect := slot_rect(i)
	rect.position += o
	var cid := _battle.deck.card_at(i)
	if cid.is_empty():
		_surface.draw_rect(rect, Color(1, 1, 1, 0.07), false, 2.0)
		_text("%d" % (i + 1), rect.get_center() + Vector2(0, 8), 28, Color(1, 1, 1, 0.12), HORIZONTAL_ALIGNMENT_CENTER)
		return
	var def: CardDefinition = _battle.cards_by_id().get(cid)
	var selected := _battle.targeting.selected_slot == i
	if selected:
		rect.position.y -= SELECT_RAISE
	if i == _shake_slot and _shake_t > 0.0:
		rect.position.x += sin(_shake_t * 60.0) * 7.0 * (_shake_t / SHAKE_S)
	var kind_col: Color = KIND_COLOR.get(def.card_kind if def != null else 0, Color.GRAY)
	var locked := _battle.deck.is_locked(cid)
	var affordable := def != null and _battle.points.can_afford(def.cost)
	_surface.draw_rect(rect, Color(0.11, 0.12, 0.14, 0.94))
	_surface.draw_rect(Rect2(rect.position, Vector2(rect.size.x, 10.0)), kind_col)
	var flash := (_shake_t / SHAKE_S) if i == _shake_slot and _shake_t > 0.0 else 0.0
	if flash > 0.0:
		_surface.draw_rect(rect, Color(1.0, 0.2, 0.2, 0.35 * flash))
	_text("[%d]" % (i + 1), rect.position + Vector2(8, 32), 16, Color(1, 1, 1, 0.6), HORIZONTAL_ALIGNMENT_LEFT)
	# cost badge
	var badge := rect.position + Vector2(rect.size.x - 24.0, 34.0)
	_surface.draw_circle(badge, 17.0, kind_col.darkened(0.2) if affordable else Color(0.55, 0.12, 0.12))
	_surface.draw_arc(badge, 17.0, 0.0, TAU, 24, Color(0, 0, 0, 0.7), 2.0)
	_text("%d" % (def.cost if def != null else 0), badge + Vector2(0, 8), 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	# name on up to two lines
	var lines := _wrap(def.display_name if def != null else "?")
	var two_lines := lines.size() > 1
	var ny := rect.position.y + (62.0 if two_lines else 68.0)
	for line in lines:
		_text(line, Vector2(rect.position.x + rect.size.x * 0.5, ny), 18 if two_lines else 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		ny += 20.0
	_text(KIND_LABEL.get(def.card_kind if def != null else 0, ""), Vector2(rect.position.x + rect.size.x * 0.5, rect.end.y - 8.0), 14, Color(1, 1, 1, 0.5), HORIZONTAL_ALIGNMENT_CENTER)
	if locked:
		_surface.draw_rect(rect, Color(0, 0, 0, 0.62))
		_text("%ds" % ceili(_battle.deck.lockout_remaining(cid)), rect.get_center() + Vector2(0, 12), 36, Color(1, 0.85, 0.4), HORIZONTAL_ALIGNMENT_CENTER)
	elif not affordable:
		_surface.draw_rect(rect, Color(0, 0, 0, 0.38))
	_surface.draw_rect(rect, Color(1.0, 0.9, 0.3) if selected else Color(0, 0, 0, 0.85), false, 3.0 if selected else 1.5)


func _draw_draw_timer(o: Vector2) -> void:
	var first := slot_rect(0)
	var total_w := slot_rect(SLOT_COUNT - 1).end.x - first.position.x
	var y := HAND_TOP + SLOT_SIZE.y + 8.0
	var deck := _battle.deck
	var full := deck.hand.size() >= deck.rules.hand_cap
	var frac := 0.0 if full else clampf(deck.draw_timer / deck.rules.draw_interval_s, 0.0, 1.0)
	var bar := Rect2(Vector2(first.position.x, y) + o, Vector2(total_w * 0.45, 8.0))
	_surface.draw_rect(bar, Color(0.08, 0.09, 0.11, 0.9))
	_surface.draw_rect(Rect2(bar.position, Vector2(bar.size.x * frac, bar.size.y)), Color(0.75, 0.75, 0.8))
	_text("HAND FULL" if full else "NEXT CARD", Vector2(bar.end.x + 10.0, y + 9.0 + o.y), 14, Color(1, 1, 1, 0.6), HORIZONTAL_ALIGNMENT_LEFT)
	_text("Draw %d   Discard %d" % [deck.draw_pile.size(), deck.discard.size()], Vector2(first.position.x + total_w, y + 10.0) + o, 16, Color(1, 1, 1, 0.7), HORIZONTAL_ALIGNMENT_RIGHT)


func _draw_toast(o: Vector2) -> void:
	if _toast_t <= 0.0 or _toast.is_empty():
		return
	var a := clampf(_toast_t / 0.5, 0.0, 1.0)
	var centre_x := (slot_rect(0).position.x + slot_rect(SLOT_COUNT - 1).end.x) * 0.5
	_text(_toast, Vector2(centre_x, HAND_TOP - 46.0) + o, 26, Color(1.0, 0.45, 0.4, a), HORIZONTAL_ALIGNMENT_CENTER)


## Next to the cursor: why the selected card can't go on this cell (nothing when it can).
func _draw_tooltip() -> void:
	var p := _battle.preview
	if p == null or p.valid or p.message.is_empty():
		return
	var mouse := _surface.get_local_mouse_position() + Vector2(18, -14)
	var size := _font.get_string_size(p.message, HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
	_surface.draw_rect(Rect2(mouse + Vector2(-6, -22), size + Vector2(12, 8)), Color(0, 0, 0, 0.75))
	_text(p.message, mouse, 20, Color(1.0, 0.5, 0.45), HORIZONTAL_ALIGNMENT_LEFT)


func _text(s: String, pos: Vector2, size: int, col: Color, align: HorizontalAlignment) -> void:
	var width := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var x := pos.x
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		x -= width * 0.5
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		x -= width
	_surface.draw_string_outline(_font, Vector2(x, pos.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0, 0, 0, col.a))
	_surface.draw_string(_font, Vector2(x, pos.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


## Splits a card name into at most two lines at the space nearest the middle.
static func _wrap(name_text: String) -> Array[String]:
	var out: Array[String] = []
	if name_text.length() <= 11 or not name_text.contains(" "):
		out.append(name_text)
		return out
	var best := -1
	var mid := name_text.length() / 2
	for i in name_text.length():
		if name_text[i] == " " and (best == -1 or absi(i - mid) < absi(best - mid)):
			best = i
	out.append(name_text.substr(0, best))
	out.append(name_text.substr(best + 1))
	return out
