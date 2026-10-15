class_name IsoCamera
extends Camera2D
## Fixed-angle camera: pan (WASD/arrows, middle-mouse drag) and zoom (wheel, toward cursor). Never rotates.

const MIN_ZOOM: float = 0.5
const MAX_ZOOM: float = 3.0
const ZOOM_STEP: float = 1.1
const PAN_SPEED_PX: float = 900.0


func _process(delta: float) -> void:
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1.0
	if dir != Vector2.ZERO:
		position += dir.normalized() * PAN_SPEED_PX * delta / zoom.x


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_MIDDLE) != 0:
		position -= event.relative / zoom.x
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_at_cursor(ZOOM_STEP)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_at_cursor(1.0 / ZOOM_STEP)


## Zoom by `factor` (clamped), keeping the world point under the cursor fixed.
func zoom_at_cursor(factor: float) -> void:
	var new_zoom := clampf(zoom.x * factor, MIN_ZOOM, MAX_ZOOM)
	if is_equal_approx(new_zoom, zoom.x):
		return
	var view := get_viewport()
	var offset_px := view.get_mouse_position() - view.get_visible_rect().size * 0.5
	var world_under_cursor := position + offset_px / zoom.x
	zoom = Vector2(new_zoom, new_zoom)
	position = world_under_cursor - offset_px / new_zoom
