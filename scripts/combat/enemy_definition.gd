class_name EnemyDefinition
extends ContentDefinition
## Enemy (mutant) archetype definition.

@export var display_name: String = ""
@export var max_health: float = 0.0
## Flat damage reduction per hit; DamageService keeps a minimum-damage floor.
@export var armor: float = 0.0
@export var move_speed: float = 0.0  # tiles per second
@export var attack_damage: float = 0.0
@export var attack_interval_s: float = 1.0
@export var attack_range: float = 0.8  # tiles, ground distance
@export var footprint_radius: float = 0.3
@export var placeholder_color: Color = Color.WHITE


func kind() -> String:
	return "enemy"


func validate() -> PackedStringArray:
	var errs := super.validate()
	if display_name.is_empty():
		errs.append(_err("display_name is empty"))
	if max_health <= 0.0:
		errs.append(_err("max_health must be > 0"))
	if armor < 0.0:
		errs.append(_err("armor must be >= 0"))
	if move_speed <= 0.0:
		errs.append(_err("move_speed must be > 0"))
	if attack_damage <= 0.0:
		errs.append(_err("attack_damage must be > 0"))
	if attack_interval_s <= 0.0:
		errs.append(_err("attack_interval_s must be > 0"))
	if attack_range <= 0.0:
		errs.append(_err("attack_range must be > 0"))
	if footprint_radius <= 0.0:
		errs.append(_err("footprint_radius must be > 0"))
	return errs
