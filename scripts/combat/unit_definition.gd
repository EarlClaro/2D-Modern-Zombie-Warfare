class_name UnitDefinition
extends ContentDefinition
## Player unit/structure definition. `move_speed == 0` means fixed (e.g. a gun nest).

enum HeightClass { GROUND, LOW_AIR, HIGH_AIR }

@export var display_name: String = ""
@export var max_health: float = 0.0
@export var move_speed: float = 0.0  # tiles per second
@export var footprint_radius: float = 0.3  # tiles, ground plane
@export var height_class: HeightClass = HeightClass.GROUND
@export var weapon_id: String = ""
@export var placeholder_color: Color = Color.WHITE


func kind() -> String:
	return "unit"


func validate() -> PackedStringArray:
	var errs := super.validate()
	if display_name.is_empty():
		errs.append(_err("display_name is empty"))
	if max_health <= 0.0:
		errs.append(_err("max_health must be > 0"))
	if move_speed < 0.0:
		errs.append(_err("move_speed must be >= 0 (0 = fixed)"))
	if footprint_radius <= 0.0:
		errs.append(_err("footprint_radius must be > 0"))
	if weapon_id.is_empty():
		errs.append(_err("weapon_id is empty"))
	return errs


func is_fixed() -> bool:
	return move_speed <= 0.0
