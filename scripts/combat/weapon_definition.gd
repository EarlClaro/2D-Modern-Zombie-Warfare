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
## PROJECTILE delivery only: flight speed (tiles/s) and extra arc height (tile-height units; 0 = flies straight).
@export var projectile_speed: float = 0.0
@export var projectile_arc: float = 0.0
## Rounds carried per battle; 0 = unlimited. A weapon that runs dry stays silent for the rest of the battle.
@export var ammo: int = 0
## True: may fire while its carrier is moving (otherwise units must stand still to fire).
@export var can_fire_moving: bool = false
## True for a weapon made for armour (rocket launcher, tank gun): its carrier's focus fire prefers armoured targets.
@export var anti_armor: bool = false
## 0 = constant speed; 1 = accelerates from rest like a rocket motor. `projectile_speed` stays the AVERAGE speed.
@export var projectile_accel: float = 0.0
## Altitude (tile-height units) the projectile falls away from its pylon before the motor takes over.
@export var projectile_drop: float = 0.0
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
	if ammo < 0:
		errs.append(_err("ammo must be >= 0 (0 = unlimited)"))
	if blast_radius < 0.0:
		errs.append(_err("blast_radius must be >= 0"))
	if not SfxFactory.is_shot_sound(sfx_id):
		errs.append(_err("sfx_id '%s' is not a known shot sound (%s)" % [sfx_id, ", ".join(SfxFactory.SHOT_SOUNDS)]))
	if delivery == Delivery.PROJECTILE:
		if projectile_speed <= 0.0:
			errs.append(_err("projectile_speed must be > 0 for PROJECTILE delivery"))
		if blast_radius <= 0.0:
			errs.append(_err("PROJECTILE delivery needs blast_radius > 0 (it explodes on arrival)"))
		if projectile_arc < 0.0:
			errs.append(_err("projectile_arc must be >= 0"))
		if projectile_accel < 0.0 or projectile_accel > 1.0:
			errs.append(_err("projectile_accel must be 0..1"))
		if projectile_drop < 0.0:
			errs.append(_err("projectile_drop must be >= 0"))
	return errs


func fire_interval_s() -> float:
	return 1.0 / shots_per_second
