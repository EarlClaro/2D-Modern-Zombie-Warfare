class_name DamageService
extends RefCounted
## Pure damage math, separate from projectile visuals. All distances are ground-plane tiles.
##   final = max(base - armor, base * MIN_DAMAGE_FRACTION) * falloff
## Armor is applied before blast falloff. Damage-type resistances arrive with the Brute (Milestone 3).

const MIN_DAMAGE_FRACTION: float = 0.1
## Fraction of damage dealt at the very edge of a blast radius.
const MIN_FALLOFF: float = 0.25


static func compute(base: float, armor: float = 0.0, falloff: float = 1.0) -> float:
	if base <= 0.0:
		return 0.0
	var after_armor := maxf(base - maxf(armor, 0.0), base * MIN_DAMAGE_FRACTION)
	return after_armor * clampf(falloff, 0.0, 1.0)


## 1.0 at the centre, linearly down to MIN_FALLOFF at `radius`, 0.0 beyond it.
static func blast_falloff(distance: float, radius: float) -> float:
	var d := maxf(distance, 0.0)
	if radius <= 0.0:
		return 1.0 if d <= 0.0 else 0.0
	if d > radius:
		return 0.0
	return lerpf(1.0, MIN_FALLOFF, d / radius)
