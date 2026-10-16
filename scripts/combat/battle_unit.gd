class_name BattleUnit
extends IsoEntity
## A player unit in a battle. Rules state lives in `health`/`weapon_state`; this node also draws a
## placeholder and holds the move order. The BattleController drives it each tick.

const ARRIVE_EPS: float = 0.001
const CHEST_PX: float = 22.0  # body height used for tracer origins (px above the footprint)
const KICK_PX: float = 4.0
const FIRE_FRAME_S: float = 0.09  # how long the recoil frame shows after a shot
const KICK_RECOVER_PX_PER_S: float = 60.0

var uid: int = 0
var def: UnitDefinition
var weapon: WeaponDefinition
var weapon_state: WeaponState
var health: Health
var facing: int = IsoProjection.Facing.SE
var shadow: IsoShadow
var _recoil: Vector2 = Vector2.ZERO  # draw-only offset; never moves the sort anchor
var _move_target: Vector2 = Vector2.ZERO
var _moving: bool = false
var _anim_t: float = 0.0  # walk-cycle clock; only advances while moving
var _frame: int = 0
var _fire_t: float = 0.0


func setup(p_uid: int, p_def: UnitDefinition, p_weapon: WeaponDefinition, cell: Vector2i) -> void:
	uid = p_uid
	def = p_def
	weapon = p_weapon
	weapon_state = WeaponState.from_definition(p_weapon) if p_weapon != null else null  # structures have no weapon
	health = Health.new(p_def.max_health)
	ground_pos = IsoProjection.cell_center(cell)
	queue_redraw()


func is_alive() -> bool:
	return not health.is_dead()


func is_moving() -> bool:
	return _moving


## Mobile units walk a straight ground-plane line at constant speed; fixed units ignore orders.
func order_move(target_ground: Vector2) -> bool:
	if def.is_fixed() or not is_alive():
		return false
	_move_target = target_ground
	_moving = ground_pos.distance_to(target_ground) > ARRIVE_EPS
	return _moving


func face_toward(target_ground: Vector2) -> void:
	var f := IsoProjection.facing_from_ground_dir(target_ground - ground_pos)
	if f != -1 and f != facing:
		facing = f
		queue_redraw()


## Movement step (ground space). Safe to call every tick.
func advance_move(delta: float) -> void:
	if not _moving:
		return
	var to := _move_target - ground_pos
	var dist := to.length()
	var step := def.move_speed * delta
	face_toward(_move_target)
	if step >= dist:
		ground_pos = _move_target
		_moving = false
	else:
		ground_pos += to / dist * step


## World-pixel position bullets leave from.
func muzzle_world() -> Vector2:
	var dir := IsoProjection.ground_dir_of_facing(facing)
	return chest_world() + IsoProjection.ground_to_screen(dir * 0.45)


func local_rect() -> Rect2:
	return Rect2(-12.0, -40.0, 24.0, 44.0)


## Recoil: shove the drawn body a few px opposite to the shot (screen-space direction).
func kick(shot_dir_screen: Vector2) -> void:
	if shot_dir_screen.length_squared() > 0.0001:
		_recoil = -shot_dir_screen.normalized() * KICK_PX
		if def != null and def.sprite != null and def.sprite.fire_frame >= 0:
			_fire_t = FIRE_FRAME_S
		queue_redraw()


func chest_world() -> Vector2:
	return position + Vector2(0, -_chest_px()) + _sprite_lift()


## Screen lift (px) the body is drawn at, on top of the node position. Ground units lift by `altitude`;
## BattleAircraft overrides it because its node is already moved to the lifted position.
func _sprite_lift() -> Vector2:
	return IsoProjection.altitude_offset(altitude)


## Altitude setter for tweens (death fall); aircraft override it to move their node too.
func _set_altitude(value: float) -> void:
	altitude = value


func _chest_px() -> float:
	if def.sprite != null:
		return def.sprite.chest_px
	return CHEST_PX if not def.is_fixed() else 14.0


func _process(delta: float) -> void:
	if def != null and def.sprite != null:
		_update_sprite_frame(delta)
	if _recoil != Vector2.ZERO:
		_recoil = _recoil.move_toward(Vector2.ZERO, KICK_RECOVER_PX_PER_S * delta)
		queue_redraw()
	elif health != null and health.hp < health.max_hp:
		queue_redraw()


func play_death(duration: float, shadow_node: Node = null) -> void:
	if def != null and def.sprite != null and def.sprite.has_death():
		play_sprite_death(def.sprite, shadow_node)
		if altitude > 0.0 and def.sprite.death_fall_frames > 0:  # a shot-down aircraft drops to the ground
			var fall_s := float(def.sprite.death_fall_frames) / def.sprite.death_fps
			create_tween().tween_method(_set_altitude, altitude, 0.0, fall_s)
	else:
		super.play_death(duration, shadow_node)


func _set_death_frame(frame_index: int) -> void:
	_frame = frame_index
	queue_redraw()


## Advances the walk clock while moving and redraws only when the visible frame changes.
func _update_sprite_frame(delta: float) -> void:
	var frame := def.sprite.idle_frame
	if _moving or def.sprite.always_animate:
		_anim_t += delta
		frame = def.sprite.walk_frame(_anim_t, def.move_speed)
	else:
		_anim_t = 0.0
	if _fire_t > 0.0:
		_fire_t -= delta
		if not _moving and def.sprite.fire_frame >= 0:
			frame = def.sprite.fire_frame
	if frame != _frame:
		_frame = frame
		queue_redraw()


func _draw() -> void:
	if def == null:
		return
	if def.sprite != null:  # the art shows the facing; the placeholder wedge is only for unsprited units
		var lift := _sprite_lift()
		def.sprite.draw_frame(self, _frame, facing, _recoil + lift)
		if not dying:
			BattleDraw.health_bar(self, -def.sprite.top_px() - 6.0 + lift.y, health.fraction() if health != null else 1.0)
		return
	var dir := IsoProjection.ground_dir_of_facing(facing)
	var perp := Vector2(-dir.y, dir.x)
	var wedge := PackedVector2Array([
		IsoProjection.ground_to_screen(dir * 0.7),
		IsoProjection.ground_to_screen(dir * 0.25 + perp * 0.26),
		IsoProjection.ground_to_screen(dir * 0.25 - perp * 0.26),
	])
	draw_colored_polygon(wedge, Color("ffd23f"))
	draw_set_transform(_recoil)
	var base := def.placeholder_color
	var dark := base.darkened(0.55)
	var top: float
	if def.is_fixed():
		# Squat emplacement with a barrel pointing along the facing.
		var box := Rect2(-15.0, -16.0, 30.0, 14.0)
		draw_rect(box, base)
		draw_rect(box, dark, false, 2.0)
		var chest := Vector2(0, -14.0)
		draw_line(chest, chest + IsoProjection.ground_to_screen(dir * 0.5), Color(0.1, 0.1, 0.1), 4.0)
		top = -22.0
	else:
		var body := Rect2(-8.0, -30.0, 16.0, 28.0)
		draw_rect(body, base)
		draw_rect(body, dark, false, 2.0)
		draw_circle(Vector2(0, -35), 6.0, base.lightened(0.45))
		draw_arc(Vector2(0, -35), 6.0, 0.0, TAU, 16, dark, 2.0)
		var chest := Vector2(0, -CHEST_PX)
		draw_line(chest, chest + IsoProjection.ground_to_screen(dir * 0.45), Color(0.08, 0.08, 0.08), 3.0)
		top = -46.0
	draw_set_transform(Vector2.ZERO)
	BattleDraw.health_bar(self, top, health.fraction() if health != null else 1.0)
