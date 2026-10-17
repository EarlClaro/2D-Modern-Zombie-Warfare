class_name DifficultyDefinition
extends ContentDefinition
## A difficulty level (ADR-013): it changes only how many enemies every wave sends. Economy, core health, enemy stats and
## the cards stay as they are, so the value of a card does not shift between levels. `normal` must multiply by exactly 1
## and leave every mission as it was.

const MAX_MULT: float = 10.0

@export var display_name: String = ""
@export var enemy_count_mult: float = 1.0
## Position in the menu, easiest first.
@export var order: int = 1
## 0 = no limit. Otherwise a mission that sends more enemies than this at normal is not made bigger by this level, and one
## below it grows only up to this many in total (about 2,000 alive is what a step can afford, docs/BALANCE.md F5).
@export var max_total_enemies: int = 0


func kind() -> String:
	return "difficulty"


func validate() -> PackedStringArray:
	var errs := super.validate()
	if display_name.is_empty():
		errs.append(_err("display_name is empty"))
	if enemy_count_mult <= 0.0 or enemy_count_mult > MAX_MULT:
		errs.append(_err("enemy_count_mult must be > 0 and <= %s" % str(MAX_MULT)))
	if max_total_enemies < 0:
		errs.append(_err("max_total_enemies must be >= 0"))
	return errs


## The multiplier used for a mission that sends `base_total` enemies at normal (0 = unknown, no cap). Only a level that makes
## things bigger is capped, and never below 1, so a level cannot make a mission easier than normal.
func effective_mult(base_total: int = 0) -> float:
	if enemy_count_mult <= 1.0 or max_total_enemies <= 0 or base_total <= 0:
		return enemy_count_mult
	return minf(enemy_count_mult, maxf(1.0, float(max_total_enemies) / float(base_total)))


## How many enemies a wave entry of `count` sends: rounded, and never below 1 for an entry that sends any.
func scaled_count(count: int, base_total: int = 0) -> int:
	if count <= 0:
		return count
	return maxi(1, roundi(float(count) * effective_mult(base_total)))


## The gap between enemies of that entry once the count is scaled. The first and the last enemy keep their times (a harder
## wave is denser, not longer, and still ends inside the mission); an unscaled entry keeps its interval exactly.
func scaled_interval(count: int, interval_s: float, base_total: int = 0) -> float:
	var n := scaled_count(count, base_total)
	if interval_s <= 0.0 or n == count or count <= 1 or n <= 1:
		return interval_s
	return interval_s * float(count - 1) / float(n - 1)
