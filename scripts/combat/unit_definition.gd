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
## A structure is a fixed player entity with hit points and no weapon (wall, barricade, scenery). Enemies attack it
## like any unit, so it stalls them; it never moves or shoots. `weapon_id` may be empty only for a structure.
@export var structure: bool = false
## Area blast that goes off where this entity dies (explosive barrels, a fuel truck); both 0 = none.
@export var death_blast_damage: float = 0.0
@export var death_blast_radius: float = 0.0
## What the unit does on its own once played (ADR-013, see UnitBrain). Fixed units and structures always hold; sortie
## aircraft follow their flight plan. `leash`: how far a GUARD may stray from its anchor; `advance_limit`: how far from
## the core an ADVANCE unit may go; `follow_range`: how far a SUPPORT unit looks for a friend to follow (tiles).
@export var behavior: UnitBrain.Behavior = UnitBrain.Behavior.GUARD
@export var leash: float = 6.0
@export var advance_limit: float = 12.0
@export var follow_range: float = 8.0
## Habits (ADR-013), each switchable: a GUARD that has to move takes a spot behind a friendly structure when one is in
## reach; a mobile unit below `retreat_below` of its health falls back toward the core while enemies are near; a unit
## shoots the most dangerous enemy in range first instead of the nearest.
@export var seeks_cover: bool = true
@export var retreats: bool = true
@export_range(0.0, 1.0) var retreat_below: float = 0.35
@export var focus_fire: bool = true
## Kiting (UnitBrain.KITE): how far the unit sees enemies, how far from the enemy spawn along the route it waits while
## scouting, how many enemies around it it fights before falling back, and how bold it is (multiplies the safety
## margin kept from an enemy's reach: a heavily armoured tank can be bolder than a rifleman).
@export var vision: float = 16.0
@export var scout_post: float = 12.0
@export var courage: int = 14
@export var danger_margin: float = 1.0
## Optional second weapon (aircraft only for now), fired independently of the first.
@export var secondary_weapon_id: String = ""
@export var placeholder_color: Color = Color.WHITE
## Optional pixel-art sheet; units without one keep drawing the placeholder.
@export var sprite: SpriteSheet


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
	if weapon_id.is_empty() and not structure:
		errs.append(_err("weapon_id is empty (only a structure may have no weapon)"))
	if structure:
		if move_speed != 0.0:
			errs.append(_err("a structure must be fixed (move_speed 0)"))
		if not weapon_id.is_empty() or not secondary_weapon_id.is_empty():
			errs.append(_err("a structure must not have a weapon"))
		if is_air():
			errs.append(_err("a structure must be a ground entity"))
	if retreat_below < 0.0 or retreat_below >= 1.0:
		errs.append(_err("retreat_below must be within 0..1 (exclusive of 1)"))
	if vision <= 0.0 or scout_post < 0.0 or courage < 1 or danger_margin < 0.0:
		errs.append(_err("vision must be > 0, scout_post >= 0, courage >= 1 and danger_margin >= 0"))
	if leash <= 0.0 or advance_limit <= 0.0 or follow_range <= 0.0:
		errs.append(_err("leash, advance_limit and follow_range must be > 0"))
	if death_blast_damage < 0.0 or death_blast_radius < 0.0:
		errs.append(_err("death_blast_damage and death_blast_radius must be >= 0"))
	if (death_blast_damage > 0.0) != (death_blast_radius > 0.0):
		errs.append(_err("death_blast_damage and death_blast_radius must be set together"))
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


func has_death_blast() -> bool:
	return death_blast_damage > 0.0 and death_blast_radius > 0.0


func is_fixed() -> bool:
	return move_speed <= 0.0


## The behaviour that actually runs: anything fixed or without a weapon holds, whatever `behavior` says.
func effective_behavior() -> UnitBrain.Behavior:
	if is_fixed() or structure:
		return UnitBrain.Behavior.HOLD
	return behavior
