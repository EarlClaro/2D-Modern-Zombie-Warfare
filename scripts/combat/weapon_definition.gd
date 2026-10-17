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
## Artillery (F3): the weapon cannot hit anything closer than `min_range_tiles` (0 = no minimum). It fires `burst_size` shots
## at `shots_per_second` and then reloads for `burst_pause_s` (1 = no bursts). With `needs_spotter` it only fires at enemies
## that a friendly unit (or the core) can see: it shoots at what it is told about, not at what it sees itself.
@export var min_range_tiles: float = 0.0
@export var burst_size: int = 1
@export var burst_pause_s: float = 0.0
@export var needs_spotter: bool = false
## PROJECTILE weapons: each shell lands at a random point within this many tiles of the aimed spot (0 = dead on). A salvo
## of rockets spreads over an area instead of landing on one point.
@export var scatter_tiles: float = 0.0


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
	if min_range_tiles < 0.0 or min_range_tiles >= range_tiles:
		errs.append(_err("min_range_tiles must be >= 0 and below range_tiles"))
	if scatter_tiles < 0.0:
		errs.append(_err("scatter_tiles must be >= 0"))
	if burst_size < 1 or burst_pause_s < 0.0:
		errs.append(_err("burst_size must be >= 1 and burst_pause_s >= 0"))
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
