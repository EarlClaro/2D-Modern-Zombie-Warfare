class_name BattleEnemy
extends IsoEntity
## An enemy in a battle. Walks straight segments through the mission waypoints (plus a small constant
## lane offset so a horde doesn't stack on one line) and attacks the nearest player entity in range.

const CHEST_PX: float = 18.0
const ATTACK_ANIM_S: float = 0.25  # how long the attack frame shows after a swing
const STAGGER_PX: float = 2.5
const STAGGER_RECOVER_PX_PER_S: float = 40.0

var uid: int = 0
var def: EnemyDefinition
var health: Health
var attack_state: WeaponState
var facing: int = IsoProjection.Facing.W
var shadow: IsoShadow
## Noise lure (ADR-013): whether the straight walk to the lure that pulls this enemy was clear when last checked.
var lure_clear: bool = false
var _waypoints: Array[Vector2] = []
var _wp_index: int = 0
var _anim_t: float = 0.0  # walk-cycle clock; only advances while the enemy actually moves
var _frame: int = 0
var _prev_ground: Vector2 = Vector2.ZERO
var _stagger: Vector2 = Vector2.ZERO  # draw-only offset from being shot; never moves the sort anchor


func setup(p_uid: int, p_def: EnemyDefinition, start_ground: Vector2, waypoints: Array[Vector2]) -> void:
	uid = p_uid
	def = p_def
	health = Health.new(p_def.max_health)
	attack_state = WeaponState.new(p_def.attack_interval_s)
	_waypoints = waypoints
	_wp_index = 0
	ground_pos = start_ground
	_prev_ground = start_ground
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


## Walks straight toward `point` at `def.move_speed` without touching the path progress; returns the distance left.
func advance_toward(point: Vector2, delta: float) -> float:
	var to := point - ground_pos
	var dist := to.length()
	var step := def.move_speed * delta
	face_toward(point)
	if step >= dist:
		ground_pos = point
		return 0.0
	ground_pos += to / dist * step
	return dist - step


## True for a short moment after the attack cooldown restarts (the swing that just landed).
func is_swinging() -> bool:
	return attack_state.cooldown_remaining() > def.attack_interval_s - ATTACK_ANIM_S


## World-pixel point a spat glob leaves from: the head, a little toward the facing.
func mouth_world() -> Vector2:
	var top := def.sprite.top_px() if def != null and def.sprite != null else 30.0
	return position + Vector2(0, -top * 0.8) + IsoProjection.ground_to_screen(IsoProjection.ground_dir_of_facing(facing) * 0.25)


func chest_world() -> Vector2:
	return position + Vector2(0, -(def.sprite.chest_px if def != null and def.sprite != null else CHEST_PX))


func local_rect() -> Rect2:
	return Rect2(-11.0, -38.0, 22.0, 42.0)


func _process(delta: float) -> void:
	if _stagger != Vector2.ZERO:
		_stagger = _stagger.move_toward(Vector2.ZERO, STAGGER_RECOVER_PX_PER_S * delta)
		queue_redraw()
	if def != null and def.sprite != null:
		_update_sprite_frame(delta)
	if health != null and health.hp < health.max_hp:
		queue_redraw()


func play_death(duration: float, shadow_node: Node = null) -> void:
	if def != null and def.sprite != null and def.sprite.has_death():
		play_sprite_death(def.sprite, shadow_node)
	else:
		super.play_death(duration, shadow_node)


## Jerks the drawn body a couple of px along the shot (screen-space direction); it settles back by itself.
func stagger(shot_dir_screen: Vector2) -> void:
	if shot_dir_screen.length_squared() > 0.0001 and not dying:
		_stagger = shot_dir_screen.normalized() * STAGGER_PX
		queue_redraw()


func _set_death_frame(frame_index: int) -> void:
	_frame = frame_index
	queue_redraw()


## Walk animation follows real movement (an enemy that stops to attack idles); redraws on frame change.
func _update_sprite_frame(delta: float) -> void:
	var moved := ground_pos != _prev_ground
	_prev_ground = ground_pos
	var frame := def.sprite.idle_frame
	if moved:
		_anim_t += delta
		frame = def.sprite.walk_frame(_anim_t, def.move_speed)
	else:
		_anim_t = 0.0
		if def.sprite.attack_frame >= 0 and is_swinging():
			frame = def.sprite.attack_frame
	if frame != _frame:
		_frame = frame
		queue_redraw()


func _draw() -> void:
	if def == null:
		return
	if def.sprite != null:  # the art shows the facing; the placeholder wedge is only for unsprited enemies
		def.sprite.draw_frame(self, _frame, facing, _stagger)
		if not dying:
			BattleDraw.health_bar(self, -def.sprite.top_px() - 6.0, health.fraction() if health != null else 1.0, 24.0, Color(0.9, 0.3, 0.25))
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
