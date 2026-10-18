class_name BattleDraw
extends RefCounted
## Small shared drawing helpers for placeholder battle entities (presentation only).


## Health bar centred above an entity; drawn only once damaged. `y` is the bar's local y (px).
const DEFAULT_FILL := Color(0.35, 0.9, 0.4)


static func health_bar(ci: CanvasItem, y: float, fraction: float, width: float = 28.0, fill: Color = DEFAULT_FILL) -> void:
	if fraction >= 0.999:
		return
	# a pixel bar: a dark outline, a dark trough, a fill that goes green, yellow, red as it drains, a light top row and a notch every quarter
	var w := roundf(width)
	var x0 := roundf(-w * 0.5)
	var f := clampf(fraction, 0.0, 1.0)
	var col := fill
	if fill == DEFAULT_FILL:
		col = DEFAULT_FILL if f > 0.6 else (Color(0.95, 0.8, 0.25) if f > 0.3 else Color(0.92, 0.28, 0.22))
	ci.draw_rect(Rect2(x0 - 1.0, y - 1.0, w + 2.0, 6.0), Color(0.04, 0.05, 0.05, 0.9))
	ci.draw_rect(Rect2(x0, y, w, 4.0), Color(0.16, 0.2, 0.18))
	var fw := roundf(w * f)
	if fw > 0.0:
		ci.draw_rect(Rect2(x0, y, fw, 4.0), col.darkened(0.25))
		ci.draw_rect(Rect2(x0, y, fw, 2.0), col)
		ci.draw_rect(Rect2(x0, y, fw, 1.0), col.lightened(0.35))
	for q in [1, 2, 3]:
		ci.draw_rect(Rect2(x0 + roundf(w * float(q) / 4.0), y, 1.0, 4.0), Color(0.04, 0.05, 0.05, 0.55))
