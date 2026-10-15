class_name PlaceholderFlyer
extends IsoEntity
## Spike placeholder aircraft: orbits a ground point at constant altitude. Node position stays at its
## ground point (so it sorts by ground position); only the drawing is lifted by altitude. A thin line
## from the ground point to the body gives a height cue; its shadow is an IsoShadow on the Shadows layer.

const FLIGHT_ALTITUDE: float = 3.0

var orbit_center: Vector2 = Vector2(8, 8)
var orbit_radius: float = 5.0
var angular_speed: float = 0.6  # rad/s
var heading_screen: Vector2 = Vector2.RIGHT
var _angle: float = 0.0


func _init() -> void:
	altitude = FLIGHT_ALTITUDE


func _ready() -> void:
	advance(0.0)


func advance(delta: float) -> void:
	_angle += angular_speed * delta
	ground_pos = orbit_center + Vector2(cos(_angle), sin(_angle)) * orbit_radius
	var velocity_dir := Vector2(-sin(_angle), cos(_angle))
	heading_screen = IsoProjection.ground_to_screen(velocity_dir).normalized()
	queue_redraw()


func _process(delta: float) -> void:
	advance(delta)


func _draw() -> void:
	var lift := IsoProjection.altitude_offset(altitude)
	draw_line(Vector2.ZERO, lift, Color(1, 1, 1, 0.3), 1.0)
	var h := heading_screen
	var p := Vector2(-h.y, h.x)
	var body := PackedVector2Array([lift + h * 22.0, lift - h * 12.0 + p * 15.0, lift - h * 5.0, lift - h * 12.0 - p * 15.0])
	draw_colored_polygon(body, Color("e3d46a"))
	var closed := body.duplicate()
	closed.append(closed[0])
	draw_polyline(closed, Color("5a4f10"), 2.0)
