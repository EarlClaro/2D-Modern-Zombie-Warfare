class_name PlaceholderUnit
extends IsoEntity
## Spike placeholder soldier: moves in a straight ground-plane line at constant ground speed, shows its
## 8-way facing as a wedge on the ground. No pathfinding (Milestone 3).

const SPEED_TILES_PER_S: float = 3.0
const ARRIVE_EPS: float = 0.001

var facing: int = IsoProjection.Facing.SE
var _target: Vector2 = Vector2.ZERO
var _moving: bool = false


func is_moving() -> bool:
	return _moving


func move_to(target_ground: Vector2) -> void:
	_target = target_ground
	_moving = ground_pos.distance_to(target_ground) > ARRIVE_EPS


## Simulation step in ground space. Called from _process; public so tests can drive it.
func advance(delta: float) -> void:
	if not _moving:
		return
	var to := _target - ground_pos
	var dist := to.length()
	var step := SPEED_TILES_PER_S * delta
	var f := IsoProjection.facing_from_ground_dir(to)
	if f != -1 and f != facing:
		facing = f
		queue_redraw()
	if step >= dist:
		ground_pos = _target
		_moving = false
	else:
		ground_pos += to / dist * step


func _process(delta: float) -> void:
	advance(delta)


func local_rect() -> Rect2:
	return Rect2(-12.0, -40.0, 24.0, 44.0)


func _draw() -> void:
	# Facing wedge on the ground plane, snapped to one of the 8 principal ground directions.
	var dir := IsoProjection.ground_dir_of_facing(facing)
	var perp := Vector2(-dir.y, dir.x)
	var wedge := PackedVector2Array([
		IsoProjection.ground_to_screen(dir * 0.65),
		IsoProjection.ground_to_screen(dir * 0.2 + perp * 0.28),
		IsoProjection.ground_to_screen(dir * 0.2 - perp * 0.28),
	])
	draw_colored_polygon(wedge, Color("ffd23f"))
	# Body: a simple upright capsule standing on the footprint base point.
	var body := Rect2(-8.0, -30.0, 16.0, 28.0)
	draw_rect(body, Color("3b6fd4"))
	draw_rect(body, Color("172a57"), false, 2.0)
	draw_circle(Vector2(0, -35), 6.0, Color("9bb8f0"))
	draw_arc(Vector2(0, -35), 6.0, 0.0, TAU, 16, Color("172a57"), 2.0)
