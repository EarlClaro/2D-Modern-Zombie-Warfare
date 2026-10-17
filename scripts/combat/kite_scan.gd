class_name KiteScan
extends RefCounted
## What one unit sees of the enemy around it for the kiting brain (UnitBrain.kite): filled by EnemyIndex.scan_kite in one
## pass, so no per-enemy objects are made. An enemy is *dangerous* to the unit when the unit stands inside its danger zone:
## its attack reach plus a safety margin plus the ground it covers in a moment (its speed times a reaction time).

## Enemies whose danger zone holds the unit, how many of those the unit can outrun, and the sum of "away" pushes
## (unit minus enemy, over distance squared) used to choose a direction to back off in.
var danger_count: int = 0
var danger_slower: int = 0
var away: Vector2 = Vector2.ZERO
## How far the unit stands outside the worst zone (negative = inside it by that much).
var worst_slack: float = INF
## Enemies within the crowd radius of the unit (how overwhelmed it is) and within its vision.
var crowd: int = 0
var visible: int = 0
## The enemy closest to an enemy spawn among those seen (the one to fight "up front"), if any, with its danger numbers.
var has_upstream: bool = false
var upstream_pos: Vector2 = Vector2.ZERO
var upstream_reach: float = 0.0
var upstream_speed: float = 0.0
var _upstream_d2: float = INF
var _upstream_uid: int = 0


func reset() -> void:
	danger_count = 0
	danger_slower = 0
	away = Vector2.ZERO
	worst_slack = INF
	crowd = 0
	visible = 0
	has_upstream = false
	upstream_pos = Vector2.ZERO
	upstream_reach = 0.0
	upstream_speed = 0.0
	_upstream_d2 = INF
	_upstream_uid = 0
