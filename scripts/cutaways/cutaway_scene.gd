class_name CutawayScene
extends RefCounted
## One cutaway's picture, drawn in code (docs/specs/strike-cutaways.md). A recipe subclass draws one frame into
## `rect` (the letterboxed picture area, screen px) at clip time `t` seconds of `length` seconds. Pure drawing: no
## state that matters between frames except what `t` implies, so the same `t` always gives the same picture.

## Draws the picture. `ci` is the canvas item to draw on (a Control in `_draw`).
func draw(_ci: CanvasItem, _rect: Rect2, _t: float, _length: float) -> void:
	pass


## Screen shake offset (px) at time `t`; recipes override it. Applied by the player to the whole picture.
func shake(_t: float, _length: float) -> Vector2:
	return Vector2.ZERO


## Cheap deterministic hash in 0..1 for stable "random" details (no RNG state to carry between frames).
static func hash01(i: int, k: int = 0) -> float:
	return fposmod(sin(float(i) * 12.9898 + float(k) * 78.233) * 43758.5453, 1.0)
