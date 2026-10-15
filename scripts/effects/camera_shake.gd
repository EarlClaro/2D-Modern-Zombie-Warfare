class_name CameraShake
extends Node
## Light screen shake via Camera2D.offset (so it never disturbs panning). Strength is capped, and a
## weaker shake never cuts short a stronger one in progress. Presentation only.

const MAX_PX: float = 4.0

var camera: Camera2D
var _strength: float = 0.0
var _duration: float = 0.0001
var _left: float = 0.0


## Offset magnitude (px) for a shake of `strength` with `left` of `duration` seconds remaining.
static func amplitude(strength: float, left: float, duration: float) -> float:
	if left <= 0.0 or duration <= 0.0:
		return 0.0
	return minf(strength, MAX_PX) * clampf(left / duration, 0.0, 1.0)


func current_amplitude() -> float:
	return amplitude(_strength, _left, _duration)


func trigger(strength_px: float, duration_s: float) -> void:
	if duration_s <= 0.0 or strength_px <= 0.0:
		return
	if strength_px >= current_amplitude():
		_strength = minf(strength_px, MAX_PX)
		_duration = duration_s
		_left = duration_s


func _process(delta: float) -> void:
	if camera == null or not is_instance_valid(camera):
		return
	if _left > 0.0:
		_left -= delta
		var a := current_amplitude()
		camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * a
	elif camera.offset != Vector2.ZERO:
		camera.offset = Vector2.ZERO
