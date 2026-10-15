class_name IsoOcclusion
extends RefCounted
## Occlusion by fading (ADR-005): a tall occluder fades when a subject is behind it AND their screen
## rects overlap. Pure functions so the rule is unit-testable.

const FADED_ALPHA: float = 0.4
const FADE_TIME: float = 0.15


## `*_ground` are sort anchors in ground space; `*_rect` are screen-space (world px) bounding boxes.
static func is_occluding(occluder_ground: Vector2, occluder_rect: Rect2, subject_ground: Vector2, subject_rect: Rect2) -> bool:
	var subject_is_behind := IsoProjection.sort_key(subject_ground) < IsoProjection.sort_key(occluder_ground)
	return subject_is_behind and occluder_rect.intersects(subject_rect)


## Moves alpha toward the faded/opaque target at a rate that spans the full range in FADE_TIME.
static func next_alpha(current: float, faded: bool, delta: float) -> float:
	var target := FADED_ALPHA if faded else 1.0
	return move_toward(current, target, (1.0 - FADED_ALPHA) * delta / FADE_TIME)
