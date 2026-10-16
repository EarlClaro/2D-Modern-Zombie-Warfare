class_name TitleCardScene
extends CutawayScene
## The plain fallback cutaway: a dusk gradient with speed streaks sweeping across. Used by supports that do not have
## their own scene yet, and as the reference for how a recipe draws.

const SKY_TOP: Color = Color(0.07, 0.09, 0.16)
const SKY_HORIZON: Color = Color(0.62, 0.36, 0.24)
const STREAKS: int = 14


func draw(ci: CanvasItem, rect: Rect2, t: float, length: float) -> void:
	var bands := 24
	for i in bands:
		var f := float(i) / float(bands - 1)
		var y0 := rect.position.y + rect.size.y * float(i) / bands
		ci.draw_rect(Rect2(rect.position.x, y0, rect.size.x, rect.size.y / bands + 1.0), SKY_TOP.lerp(SKY_HORIZON, f * f))
	var u := t / maxf(length, 0.001)
	for i in STREAKS:
		var y := rect.position.y + rect.size.y * (0.15 + 0.7 * hash01(i, 1))
		var speed := 0.8 + 1.6 * hash01(i, 2)
		var x := fposmod(hash01(i, 3) + u * speed, 1.0)
		var w := rect.size.x * (0.12 + 0.2 * hash01(i, 4))
		var a := 0.25 + 0.5 * hash01(i, 5)
		var px := rect.position.x + rect.size.x * (1.0 - x) * 1.2 - w * 0.2
		ci.draw_rect(Rect2(px, y, w, 2.0), Color(1.0, 0.85, 0.6, a))
