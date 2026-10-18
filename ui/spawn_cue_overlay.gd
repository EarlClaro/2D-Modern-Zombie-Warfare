class_name SpawnCueOverlay
extends CanvasLayer
## Tells the player where the next wave comes from: a ring on the ground at each spawn point shortly before a wave starts and
## while it comes out, and an arrow on the edge of the screen (with the seconds to go) when that point is off-screen.
## Presentation only. When to show comes from SpawnCue (mission data and the battle clock), where to put the arrow from
## EdgeArrow; the ring is a ground circle drawn through IsoProjection.

const SOON_COLOR := Color(1.0, 0.8, 0.3)
const ACTIVE_COLOR := Color(1.0, 0.4, 0.3)
const RING_RADIUS: float = 1.6
const EDGE_MARGIN: float = 56.0
const ARROW_SIZE: float = 28.0

var _battle: BattleController
var _canvas: _Canvas


## Draws on a Control because a CanvasLayer cannot draw itself.
class _Canvas:
	extends Control
	var overlay: SpawnCueOverlay

	func _draw() -> void:
		if overlay != null:
			overlay._paint(self)


func bind(battle: BattleController) -> void:
	_battle = battle


func _ready() -> void:
	layer = 4
	_canvas = _Canvas.new()
	_canvas.overlay = self
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)


func _process(_delta: float) -> void:
	if _canvas != null:
		_canvas.queue_redraw()


## The cues that are on right now: [spawn index, SpawnCue.Cue] (for tests and for the painter).
func active_cues() -> Array:
	var out: Array = []
	if _battle == null or _battle.mission == null or _battle.is_ended():
		return out
	for i in _battle.mission.spawn_cells.size():
		var c := SpawnCue.cue(_battle.mission, i, _battle.elapsed)
		if c.state != SpawnCue.State.NONE:
			out.append([i, c])
	return out


func _paint(on: Control) -> void:
	var view := Rect2(Vector2.ZERO, on.size)
	var to_screen := on.get_viewport().get_canvas_transform()
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * TAU * 1.5)
	var font := ThemeDB.fallback_font
	for entry in active_cues():
		var cue: SpawnCue.Cue = entry[1]
		var ground := IsoProjection.cell_center(_battle.mission.spawn_cells[entry[0]])
		var color := ACTIVE_COLOR if cue.state == SpawnCue.State.ACTIVE else SOON_COLOR
		var screen := to_screen * IsoProjection.ground_to_screen(ground)
		var place := EdgeArrow.place(screen, view, EDGE_MARGIN)
		if place.on_screen:
			var ring := PackedVector2Array()
			for p in IsoProjection.ground_circle_polygon(ground, RING_RADIUS):
				ring.append(to_screen * p)
			on.draw_colored_polygon(ring, Color(color, 0.10 + 0.12 * pulse))
			ring.append(ring[0])
			on.draw_polyline(ring, Color(color, 0.55 + 0.4 * pulse), 3.0)
			if cue.state == SpawnCue.State.SOON:
				_label(on, font, screen + Vector2(0.0, -34.0), "%d" % ceili(cue.in_s), color)
		else:
			var dir := Vector2.from_angle(place.angle)
			var side := dir.orthogonal()
			var tip := place.pos + dir * ARROW_SIZE
			var tri := PackedVector2Array([tip, place.pos - dir * ARROW_SIZE * 0.4 + side * ARROW_SIZE * 0.7, place.pos - dir * ARROW_SIZE * 0.4 - side * ARROW_SIZE * 0.7])
			on.draw_colored_polygon(tri, Color(color, 0.75 + 0.25 * pulse))
			on.draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), Color.BLACK, 2.0)
			if cue.state == SpawnCue.State.SOON:
				_label(on, font, place.pos - dir * (ARROW_SIZE * 1.6) - Vector2(8.0, -8.0), "%d" % ceili(cue.in_s), color)


func _label(on: Control, font: Font, at: Vector2, text: String, color: Color) -> void:
	on.draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 26, 6, Color.BLACK)
	on.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 26, color)
