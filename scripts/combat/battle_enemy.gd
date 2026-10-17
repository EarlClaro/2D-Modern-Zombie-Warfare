class_name BattleEnemy
extends IsoEntity
## An enemy in a battle. Walks straight segments through the mission waypoints (plus a small constant
## lane offset so a horde doesn't stack on one line) and attacks the nearest player entity in range.

const CHEST_PX: float = 18.0
const ATTACK_ANIM_S: float = 0.25  # how long the attack frame shows after a swing
const STAGGER_PX: float = 2.5
const STAGGER_RECOVER_PX_PER_S: float = 40.0
## A flow-field walker looks up its heading only every STEER_EVERY-th tick (staggered by uid): the field changes slowly and
## the lookup is the most expensive part of the walk (ADR-012).
const STEER_EVERY: int = 4

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
var _flow: FlowField = null  # set for missions with flow routing; then the waypoints are unused
var _lane: Vector2 = Vector2.ZERO  # the fixed sideways offset of this walker's lane, so a column spreads instead of stacking
var _heading: Vector2 = Vector2.ZERO
var push: Vector2 = Vector2.ZERO  # separation: extra velocity (tiles per second) away from overlapping enemies, refreshed on the steering schedule
var sep_index: int = -1  # this enemy's slot in the controller's separation snapshot (-1 = not in it yet)
var steer_lookups: int = 0  # how many times the heading was looked up (the stagger keeps this near ticks / STEER_EVERY)
var _anim_t: float = 0.0  # walk-cycle clock; only advances while the enemy actually moves
var _frame: int = 0
var _prev_ground: Vector2 = Vector2.ZERO
var _stagger: Vector2 = Vector2.ZERO  # draw-only offset from being shot; never moves the sort anchor


func setup(p_uid: int, p_def: EnemyDefinition, start_ground: Vector2, waypoints: Array[Vector2], p_flow: FlowField = null, p_lane: Vector2 = Vector2.ZERO) -> void:
	uid = p_uid
	def = p_def
	_flow = p_flow
	_lane = p_lane
	_heading = Vector2.ZERO
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


## One tick of walking: down the flow field if the mission has one, else along the waypoints. `tick` is the battle's tick
## counter (it staggers the heading lookups).
func advance(delta: float, tick: int) -> void:
	if _flow != null:
		advance_flow(delta, tick)
	else:
		advance_path(delta)


## Walks down the flow field at `def.move_speed`; never into a closed cell (it slides along an obstacle instead).
func advance_flow(delta: float, tick: int) -> void:
	if _heading == Vector2.ZERO or (tick + uid) % STEER_EVERY == 0:
		_heading = _look_up_heading()
	if _heading == Vector2.ZERO:
		return
	var step := (_heading * def.move_speed + push) * delta
	var to := _flow.slide(ground_pos, step)
	if to.distance_squared_to(ground_pos) < step.length_squared() * 0.25:
		# the heading runs into an obstacle with no way along it: take the heading of the cell stood in, which always
		# leads to open ground
		_heading = _flow.direction_at(Vector2(floorf(ground_pos.x) + 0.5, floorf(ground_pos.y) + 0.5))
		step = (_heading * def.move_speed + push) * delta
		to = _flow.slide(ground_pos, step)
	face_toward(ground_pos + _heading)
	ground_pos = to


## The heading at this walker's lane. The lane offset (less than a cell) is dropped when it would reach into an obstacle
## (the open cells beyond a wall point somewhere else), so the lane only ever spreads a column over ground that is open.
func _look_up_heading() -> Vector2:
	steer_lookups += 1
	var at := ground_pos + _lane
	if not _flow.open_at(at):
		at = ground_pos
	var h := _flow.direction_at(at)
	if h == Vector2.ZERO:
		h = _flow.direction_at(ground_pos)
	return h


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
