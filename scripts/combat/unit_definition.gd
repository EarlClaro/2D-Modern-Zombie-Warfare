class_name UnitDefinition
extends ContentDefinition
## Player unit/structure definition. `move_speed == 0` means fixed (e.g. a gun nest).

enum HeightClass { GROUND, LOW_AIR, HIGH_AIR }

## Cruise altitude (tile-height units) of aircraft by height class; ground units are at 0.
const LOW_AIR_ALTITUDE: float = 3.0
const HIGH_AIR_ALTITUDE: float = 6.0

@export var display_name: String = ""
@export var max_health: float = 0.0
## Flat damage reduction against every hit (DamageService keeps a minimum-damage floor).
@export var armor: float = 0.0
@export var move_speed: float = 0.0  # tiles per second
@export var footprint_radius: float = 0.3  # tiles, ground plane
@export var height_class: HeightClass = HeightClass.GROUND
@export var weapon_id: String = ""
## Optional second weapon (aircraft only for now), fired independently of the first.
@export var secondary_weapon_id: String = ""
@export var placeholder_color: Color = Color.WHITE


func kind() -> String:
	return "unit"


func validate() -> PackedStringArray:
	var errs := super.validate()
	if display_name.is_empty():
		errs.append(_err("display_name is empty"))
	if max_health <= 0.0:
		errs.append(_err("max_health must be > 0"))
	if armor < 0.0:
		errs.append(_err("armor must be >= 0"))
	if move_speed < 0.0:
		errs.append(_err("move_speed must be >= 0 (0 = fixed)"))
	if footprint_radius <= 0.0:
		errs.append(_err("footprint_radius must be > 0"))
	if weapon_id.is_empty():
		errs.append(_err("weapon_id is empty"))
	return errs


func is_air() -> bool:
	return height_class != HeightClass.GROUND


func flight_altitude() -> float:
	match height_class:
		HeightClass.LOW_AIR:
			return LOW_AIR_ALTITUDE
		HeightClass.HIGH_AIR:
			return HIGH_AIR_ALTITUDE
	return 0.0


func is_fixed() -> bool:
	return move_speed <= 0.0
