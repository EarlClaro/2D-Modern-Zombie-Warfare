class_name BattleDraw
extends RefCounted
## Small shared drawing helpers for placeholder battle entities (presentation only).


## Health bar centred above an entity; drawn only once damaged. `y` is the bar's local y (px).
static func health_bar(ci: CanvasItem, y: float, fraction: float, width: float = 28.0, fill: Color = Color(0.35, 0.9, 0.4)) -> void:
	if fraction >= 0.999:
		return
	var bg := Rect2(-width * 0.5, y, width, 4.0)
	ci.draw_rect(bg.grow(1.0), Color(0, 0, 0, 0.75))
	ci.draw_rect(Rect2(bg.position, Vector2(width * clampf(fraction, 0.0, 1.0), bg.size.y)), fill)
