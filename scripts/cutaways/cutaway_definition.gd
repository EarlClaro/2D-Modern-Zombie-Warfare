class_name CutawayDefinition
extends ContentDefinition
## A short full-screen clip shown when a big support is called in (docs/specs/strike-cutaways.md). Pure data: which
## recipe draws it (`scene`), its banner, its size tier (which sets how long it runs) and its sound. Cards reach it
## through `OperationDefinition.cutaway_id` or `CardDefinition.cutaway_id`.

enum Tier { EPIC, LARGE, SMALL }

## No clip may run longer than this, whatever its data says.
const HARD_CAP_S: float = 3.0
## Default {full, short} durations per tier, in seconds.
const TIER_FULL_S: Dictionary = {Tier.EPIC: 2.0, Tier.LARGE: 1.5, Tier.SMALL: 0.8}
const TIER_SHORT_S: Dictionary = {Tier.EPIC: 1.0, Tier.LARGE: 0.5, Tier.SMALL: 0.3}

@export var display_name: String = ""
@export var tier: Tier = Tier.LARGE
## Overrides of the tier's durations; 0 = use the tier's.
@export var full_s: float = 0.0
@export var short_s: float = 0.0
## Id of the code-built scene recipe that draws the clip (see CutawayScenes).
@export var scene: String = ""
## An `SfxFactory` sound id played when the clip starts (empty = none).
@export var sound: String = ""


func kind() -> String:
	return "cutaway"


## Length of the first showing in a mission, capped.
func full_duration() -> float:
	return minf(full_s if full_s > 0.0 else float(TIER_FULL_S[tier]), HARD_CAP_S)


## Length of every later showing, capped.
func short_duration() -> float:
	return minf(short_s if short_s > 0.0 else float(TIER_SHORT_S[tier]), HARD_CAP_S)


func validate() -> PackedStringArray:
	var errs := super.validate()
	if display_name.is_empty():
		errs.append(_err("display_name is empty"))
	if scene.is_empty():
		errs.append(_err("scene is empty"))
	if full_s < 0.0 or short_s < 0.0:
		errs.append(_err("durations must be >= 0"))
	if full_s > HARD_CAP_S or short_s > HARD_CAP_S:
		errs.append(_err("durations must be <= %s s" % str(HARD_CAP_S)))
	if short_duration() > full_duration():
		errs.append(_err("short clip is longer than the full clip"))
	if not sound.is_empty() and not SfxFactory.ALL_SOUNDS.has(sound):
		errs.append(_err("unknown sound '%s'" % sound))
	return errs
