class_name BattleEnemy
extends IsoEntity
## An enemy in a battle. Walks straight segments through the mission waypoints (plus a small constant
## lane offset so a horde doesn't stack on one line) and attacks the nearest player entity in range.

const CHEST_PX: float = 18.0

var uid: int = 0
var def: EnemyDefinition
var health: Health
var attack_state: WeaponState
var facing: int = IsoProjection.Facing.W
var shadow: IsoShadow
var _waypoints: Array[Vector2] = []
var _wp_index: int = 0


func setup(p_uid: int, p_def: EnemyDefinition, start_ground: Vector2, waypoints: Array[Vector2]) -> void:
	uid = p_uid
	def = p_def
	health = Health.new(p_def.max_health)
	attack_state = WeaponState.new(p_def.attack_interval_s)
	_waypoints = waypoints
	_wp_index = 0
	ground_pos = start_ground
	queue_redraw()


func is_alive() -> bool:
	return not health.is_dead()


func face_toward(target_ground: Vector2) -> void:
	var f := IsoProjection.facing_from_ground_dir(target_ground - ground_pos)
	if f != -1 and f != facing:
		facing = f
		queue_redraw()


func has_reached_end() -> bool:
	return _wp_index >= _waypoints.size()


## Walk toward the current waypoint at `def.move_speed` (ground space).
func advance_path(delta: float) -> void:
	if has_reached_end():
		return
	var target := _waypoints[_wp_index]
	var to := target - ground_pos
	var dist := to.length()
	var step := def.move_speed * delta
	face_toward(target)
	if step >= dist:
		ground_pos = target
		_wp_index += 1
	else:
		ground_pos += to / dist * step


func chest_world() -> Vector2:
	return position + Vector2(0, -CHEST_PX)


func local_rect() -> Rect2:
	return Rect2(-11.0, -38.0, 22.0, 42.0)


func _process(_delta: float) -> void:
	if health != null and health.hp < health.max_hp:
		queue_redraw()


func _draw() -> void:
	if def == null:
		return
	var dir := IsoProjection.ground_dir_of_facing(facing)
	var perp := Vector2(-dir.y, dir.x)
	var wedge := PackedVector2Array([
		IsoProjection.ground_to_screen(dir * 0.55),
		IsoProjection.ground_to_screen(dir * 0.2 + perp * 0.2),
		IsoProjection.ground_to_screen(dir * 0.2 - perp * 0.2),
	])
	draw_colored_polygon(wedge, Color(0.15, 0.05, 0.05, 0.9))
	var base := def.placeholder_color
	var dark := base.darkened(0.6)
	# Hunched silhouette: wider/shorter body than the soldiers, head forward-low.
	var body := PackedVector2Array([Vector2(-9, -3), Vector2(9, -3), Vector2(7, -24), Vector2(-7, -24)])
	draw_colored_polygon(body, base)
	body.append(body[0])
	draw_polyline(body, dark, 2.0)
	draw_circle(Vector2(0, -28), 6.0, base.lightened(0.15))
	draw_arc(Vector2(0, -28), 6.0, 0.0, TAU, 16, dark, 2.0)
	BattleDraw.health_bar(self, -40.0, health.fraction() if health != null else 1.0, 24.0, Color(0.9, 0.3, 0.25))
