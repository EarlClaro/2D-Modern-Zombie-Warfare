class_name OperationDefinition
extends ContentDefinition
## Parameters of an Operation card's battle effect (a card names one through `CardDefinition.effect_id`).
## Currently one shape: a barrage of arcing shells scattered over a ground circle. All distances are ground
## tiles; times are seconds; `arc_height` is altitude in tile-height units (separate from ground position).
##
## Timeline from the moment the card is played: a telegraph circle is shown for `warning_s`, then one shell
## is fired every `shell_interval_s` (in random order), and each lands `flight_time_s` after it was fired.

const GOLDEN_ANGLE: float = 2.399963229728653

@export var display_name: String = ""
@export var shell_count: int = 5
## Shells land inside this circle around the target cell centre.
@export var target_radius: float = 3.0
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
	return target_radius + blast_radius


## Seconds from the card being played until the last shell lands.
func total_duration_s() -> float:
	return warning_s + float(shell_count - 1) * shell_interval_s + flight_time_s


## Impact points: an even (Vogel spiral) spread over the target circle with a random turn, then a random
## firing order, both from the injected RNG so the same seed gives the same barrage.
func shell_targets(center: Vector2, rng: RandomNumberGenerator) -> Array[Vector2]:
	var pts: Array[Vector2] = []
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
