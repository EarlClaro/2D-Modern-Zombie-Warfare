class_name OperationDefinition
extends ContentDefinition
## Parameters of an Operation card's battle effect (a card names one through `CardDefinition.effect_id`).
## Two shapes: a barrage of arcing shells scattered over a ground circle (SCATTER), or a pass that lays them
## down one after another along a line (LINE, close air support). All distances are ground tiles; times are
## seconds; `arc_height` is altitude in tile-height units (separate from ground position).
##
## Timeline from the moment the card is played: a telegraph (circle, or a strip for LINE) is shown for
## `warning_s`, then one shell is fired every `shell_interval_s` (SCATTER: random order; LINE: from one end of
## the line to the other), and each lands `flight_time_s` after it was fired.

enum Pattern { SCATTER, LINE }
enum Projectile { SHELL, MISSILE }

const GOLDEN_ANGLE: float = 2.399963229728653

@export var display_name: String = ""
@export var pattern: Pattern = Pattern.SCATTER
@export var shell_count: int = 5
## SCATTER: shells land inside this circle around the target cell centre. LINE: half the width of the strip.
@export var target_radius: float = 3.0
## LINE only: length of the strip (tiles), centred on the target, and the ground direction of the pass
## (the first shell lands at the tail, the last at the head). The default runs screen left to right.
@export var line_length: float = 12.0
@export var line_direction: Vector2 = Vector2(1.0, -1.0)
## What flies: artillery shells, or missiles (drawn small and bright, with a smoke trail).
@export var projectile: Projectile = Projectile.SHELL
## Altitude (tile-height units) the projectiles are released at; falls linearly to the ground on top of the arc.
@export var launch_altitude: float = 0.0
## Missiles only: 0 = constant speed, 1 = accelerates from rest; and altitude lost to the launch dip.
@export var accel: float = 0.0
@export var drop: float = 0.0
@export var warning_s: float = 2.0
@export var shell_interval_s: float = 0.35
@export var flight_time_s: float = 0.9
@export var arc_height: float = 6.0
@export var shell_damage: float = 60.0
## Blast radius of each shell (damage falls off to DamageService.MIN_FALLOFF at the edge).
@export var blast_radius: float = 1.8
## Ground offset from an impact point to where its shell is fired from (the battery is off to one side).
@export var launch_offset: Vector2 = Vector2(-10.0, 10.0)
## Optional full-screen clip shown when the card is played (a CutawayDefinition id; empty = none).
@export var cutaway_id: String = ""


func kind() -> String:
	return "operation"


func validate() -> PackedStringArray:
	var errs := super.validate()
	if display_name.is_empty():
		errs.append(_err("display_name is empty"))
	if shell_count < 1:
		errs.append(_err("shell_count must be >= 1"))
	if pattern == Pattern.LINE:
		if line_length <= 0.0:
			errs.append(_err("line_length must be > 0 for a line strike"))
		if line_direction.length() < 0.001:
			errs.append(_err("line_direction must not be zero"))
	if launch_altitude < 0.0 or drop < 0.0:
		errs.append(_err("launch_altitude and drop must be >= 0"))
	if accel < 0.0 or accel > 1.0:
		errs.append(_err("accel must be between 0 and 1"))
	if target_radius < 0.0:
		errs.append(_err("target_radius must be >= 0"))
	if warning_s < 0.0:
		errs.append(_err("warning_s must be >= 0"))
	if shell_interval_s < 0.0:
		errs.append(_err("shell_interval_s must be >= 0"))
	if flight_time_s <= 0.0:
		errs.append(_err("flight_time_s must be > 0"))
	if arc_height < 0.0:
		errs.append(_err("arc_height must be >= 0"))
	if shell_damage <= 0.0:
		errs.append(_err("shell_damage must be > 0"))
	if blast_radius <= 0.0:
		errs.append(_err("blast_radius must be > 0"))
	return errs


## Outer edge of everything the barrage can hurt: where a shell can land plus its blast.
func reach_radius() -> float:
	if pattern == Pattern.LINE:
		return Vector2(line_length * 0.5, target_radius).length() + blast_radius
	return target_radius + blast_radius


## Unit vector of the pass for a LINE strike.
func line_dir() -> Vector2:
	return line_direction.normalized() if line_direction.length() >= 0.001 else Vector2.RIGHT


## Seconds from the card being played until the last shell lands.
func total_duration_s() -> float:
	return warning_s + float(shell_count - 1) * shell_interval_s + flight_time_s


## Impact points. SCATTER: an even (Vogel spiral) spread over the target circle with a random turn, then a
## random firing order. LINE: evenly along the pass with a random sideways offset. Both come from the injected
## RNG so the same seed gives the same strike.
func shell_targets(center: Vector2, rng: RandomNumberGenerator) -> Array[Vector2]:
	var pts: Array[Vector2] = []
	if pattern == Pattern.LINE:
		# Even steps along the pass (tail first), each pushed sideways a random amount inside the strip.
		var dir := line_dir()
		var side := Vector2(-dir.y, dir.x)
		for i in shell_count:
			var along := (float(i) + 0.5) / float(shell_count) - 0.5
			pts.append(center + dir * (along * line_length) + side * rng.randf_range(-target_radius, target_radius))
		return pts
	var turn := rng.randf() * TAU
	for i in shell_count:
		var r := target_radius * sqrt((float(i) + 0.5) / float(shell_count))
		var a := turn + float(i) * GOLDEN_ANGLE
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	for i in range(pts.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := pts[i]
		pts[i] = pts[j]
		pts[j] = tmp
	return pts
