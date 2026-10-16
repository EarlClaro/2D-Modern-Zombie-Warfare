class_name IsoShadow
extends Node2D
## Ground shadow for an entity: a ground-plane circle (drawn as a 2:1 ellipse) at the entity's ground
## position, shifted toward screen bottom-right (light from top-left). Higher entities cast a smaller,
## fainter, more displaced shadow. Lives on the Shadows layer so it never sorts above ground entities.

const LIGHT_SHIFT_DIR: Vector2 = Vector2(1, 0)  # ground +X = screen down-right
const BASE_ALPHA: float = 0.4

var target: IsoEntity
var radius_tiles: float = 0.4

var _drawn_altitude: float = -1.0  # altitude the current polygon was built for (-1 = never drawn)
## How many times a rebuild was requested (observable so tests can verify shadows aren't redrawn every frame).
var redraw_requests: int = 0


func _process(_delta: float) -> void:
	if target == null or not is_instance_valid(target):
		queue_free()
		return
	position = IsoProjection.ground_to_screen(target.ground_pos)  # the shadow stays on the ground even if the node is lifted
	# The polygon only depends on altitude and radius, so ground shadows are built once, not every frame.
	if not is_equal_approx(target.altitude, _drawn_altitude):
		_drawn_altitude = target.altitude
		redraw_requests += 1
		queue_redraw()


func _draw() -> void:
	if target == null or not is_instance_valid(target):
		return
	var scale_by_height := 1.0 / (1.0 + target.altitude * 0.15)
	var shift := LIGHT_SHIFT_DIR * (0.1 + 0.05 * target.altitude)
	var poly := IsoProjection.ground_circle_polygon(shift, radius_tiles * scale_by_height, 24)
	draw_colored_polygon(poly, Color(LightingConfig.UNIT_SHADOW_COLOR, BASE_ALPHA * scale_by_height))
