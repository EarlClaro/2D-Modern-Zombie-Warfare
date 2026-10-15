class_name BattleUnit
extends IsoEntity
## A player unit in a battle. Rules state lives in `health`/`weapon_state`; this node also draws a
## placeholder and holds the move order. The BattleController drives it each tick.

const ARRIVE_EPS: float = 0.001
const CHEST_PX: float = 22.0  # body height used for tracer origins (px above the footprint)

var uid: int = 0
var def: UnitDefinition
var weapon: WeaponDefinition
var weapon_state: WeaponState
var health: Health
var facing: int = IsoProjection.Facing.SE
var shadow: IsoShadow
var _move_target: Vector2 = Vector2.ZERO
var _moving: bool = false


func setup(p_uid: int, p_def: UnitDefinition, p_weapon: WeaponDefinition, cell: Vector2i) -> void:
	uid = p_uid
	def = p_def
	weapon = p_weapon
	weapon_state = WeaponState.from_definition(p_weapon)
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
	return position + Vector2(0, -CHEST_PX if not def.is_fixed() else -14.0) + IsoProjection.ground_to_screen(dir * 0.45)


func local_rect() -> Rect2:
	return Rect2(-12.0, -40.0, 24.0, 44.0)


func _process(_delta: float) -> void:
	if health != null and health.hp < health.max_hp:
		queue_redraw()


func _draw() -> void:
	if def == null:
		return
	var dir := IsoProjection.ground_dir_of_facing(facing)
	var perp := Vector2(-dir.y, dir.x)
	var wedge := PackedVector2Array([
		IsoProjection.ground_to_screen(dir * 0.7),
		IsoProjection.ground_to_screen(dir * 0.25 + perp * 0.26),
		IsoProjection.ground_to_screen(dir * 0.25 - perp * 0.26),
	])
	draw_colored_polygon(wedge, Color("ffd23f"))
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
	BattleDraw.health_bar(self, top, health.fraction() if health != null else 1.0)
