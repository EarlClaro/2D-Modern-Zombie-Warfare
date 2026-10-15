class_name BattleAircraft
extends BattleUnit
## A sortie aircraft. Same rules as any unit (health, weapon, move orders); the difference is presentation:
## its node sits at the *lifted* screen position (ground position + altitude) so the body, health bar, tracer
## origin and flashes all show in the air, while `ground_pos` stays the ground-plane truth. It lives on the Air
## layer (not y-sorted), and its shadow stays on the ground (IsoShadow uses ground_pos).


## Optional second weapon (e.g. missiles) with its own cooldown; the BattleController fires it.
var secondary: WeaponDefinition
var secondary_state: WeaponState
## Missiles left (-1 = unlimited). Counts down with every launch; at 0 the second weapon is silent.
var secondary_ammo: int = -1
## Missiles leave from alternating wing pylons (-1 left, +1 right of the nose).
var pylon_side: int = 1
const PYLON_OFFSET: float = 0.35  # tiles, sideways from the fuselage


## Ground position of the next missile pylon, then switches to the other wing.
func next_pylon_ground() -> Vector2:
	var dir := IsoProjection.ground_dir_of_facing(facing)
	var perp := Vector2(-dir.y, dir.x)
	pylon_side = -pylon_side
	return ground_pos + perp * PYLON_OFFSET * float(pylon_side)


func setup_secondary(p_weapon: WeaponDefinition) -> void:
	secondary = p_weapon
	secondary_state = WeaponState.from_definition(p_weapon)
	secondary_ammo = p_weapon.ammo if p_weapon.ammo > 0 else -1


func secondary_ready_to_fire() -> bool:
	return secondary != null and secondary_ammo != 0


func setup(p_uid: int, p_def: UnitDefinition, p_weapon: WeaponDefinition, cell: Vector2i) -> void:
	super(p_uid, p_def, p_weapon, cell)
	altitude = p_def.flight_altitude()
	lift()


func advance_move(delta: float) -> void:
	super(delta)
	lift()


func _process(delta: float) -> void:
	super(delta)
	lift()


## Moves the node to the lifted screen position. Altitude only moves things up on screen.
func lift() -> void:
	position = IsoProjection.ground_to_screen_z(ground_pos, altitude)


## The node is already at the lifted position, so the sprite must not be lifted a second time.
func _sprite_lift() -> Vector2:
	return Vector2.ZERO


func _set_altitude(value: float) -> void:
	altitude = value
	lift()

