class_name WeaponDefinition
extends ContentDefinition
## Shared weapon configuration; units reference weapons by id so several units can share one weapon.

enum Delivery { HITSCAN, PROJECTILE }

@export var damage: float = 0.0
@export var shots_per_second: float = 0.0
@export var range_tiles: float = 0.0
@export var delivery: Delivery = Delivery.HITSCAN
## Ground radius of the explosion in tiles; 0 = single-target.
@export var blast_radius: float = 0.0
## Which generated shot sound to play (see SfxFactory.SHOT_SOUNDS).
@export var sfx_id: String = "shot_rifle"


func kind() -> String:
	return "weapon"


func validate() -> PackedStringArray:
	var errs := super.validate()
	if damage <= 0.0:
		errs.append(_err("damage must be > 0"))
	if shots_per_second <= 0.0:
		errs.append(_err("shots_per_second must be > 0"))
	if range_tiles <= 0.0:
		errs.append(_err("range_tiles must be > 0"))
	if blast_radius < 0.0:
		errs.append(_err("blast_radius must be >= 0"))
	if not SfxFactory.is_shot_sound(sfx_id):
		errs.append(_err("sfx_id '%s' is not a known shot sound (%s)" % [sfx_id, ", ".join(SfxFactory.SHOT_SOUNDS)]))
	if delivery == Delivery.PROJECTILE:
		errs.append(_err("PROJECTILE delivery is reserved and not implemented yet"))
	return errs


func fire_interval_s() -> float:
	return 1.0 / shots_per_second
