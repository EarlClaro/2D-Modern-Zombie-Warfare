class_name CommandPoints
extends RefCounted
## The Command Point pool: continuous regeneration up to a cap; spending is all-or-nothing.

const EPS: float = 1e-6  # float accumulation (1/1.5 per second) must not make a "1.5 s" wait come up short

var cp: float
var cap: float
var regen_per_s: float


func _init(p_start: float, p_cap: float, p_regen_per_s: float) -> void:
	cap = p_cap
	cp = clampf(p_start, 0.0, p_cap)
	regen_per_s = p_regen_per_s


static func from_rules(rules: DeckRules) -> CommandPoints:
	return CommandPoints.new(rules.cp_start, rules.cp_cap, rules.cp_per_second())


func tick(delta: float) -> void:
	cp = minf(cp + regen_per_s * maxf(delta, 0.0), cap)


## Adds Command Points (a supply drop), never above the cap.
func gain(amount: float) -> void:
	cp = minf(cp + maxf(amount, 0.0), cap)


func can_afford(cost: int) -> bool:
	return cp + EPS >= float(cost)


## Spends `cost` if affordable; otherwise changes nothing. Returns whether it was spent.
func spend(cost: int) -> bool:
	if not can_afford(cost):
		return false
	cp = maxf(cp - float(cost), 0.0)
	return true


## Whole points for display.
func whole() -> int:
	return int(floor(cp + EPS))
