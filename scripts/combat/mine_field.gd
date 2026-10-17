class_name MineField
extends RefCounted
## The mines lying on the battlefield (Minefield card, ADR-013). Pure: no nodes, no randomness. A mine goes off the
## moment an enemy is within its trigger radius, once, and is gone; friendly units never set it off.

const GOLDEN_ANGLE: float = 2.399963229728653


class Mine:
	extends RefCounted
	var pos: Vector2
	var trigger_radius: float
	var damage: float
	var blast_radius: float

	func _init(p_pos: Vector2, p_trigger: float, p_damage: float, p_blast: float) -> void:
		pos = p_pos
		trigger_radius = p_trigger
		damage = p_damage
		blast_radius = p_blast


var mines: Array[Mine] = []


## Where the `count` mines of a patch lie: an even spread (sunflower pattern) inside `spread_radius` of `center`.
## One mine sits in the middle, so a patch of one is a single mine on the aimed cell.
static func patch_positions(center: Vector2, count: int, spread_radius: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for i in maxi(count, 0):
		var r := spread_radius * sqrt((float(i) + 0.5) / float(count)) if count > 1 else 0.0
		var a := float(i) * GOLDEN_ANGLE
		out.append(center + Vector2(cos(a), sin(a)) * r)
	return out


func add_patch(center: Vector2, def: FieldEntityDefinition) -> void:
	for p in patch_positions(center, def.mine_count, def.spread_radius):
		mines.append(Mine.new(p, def.trigger_radius, def.mine_damage, def.mine_blast_radius))


func count() -> int:
	return mines.size()


func clear() -> void:
	mines.clear()


## Removes and returns the mines that go off now, in the order they were laid. `enemy_near` is
## `func(pos: Vector2, radius: float) -> bool`: is a living enemy within `radius` of `pos`?
func detonate(enemy_near: Callable) -> Array[Mine]:
	var out: Array[Mine] = []
	for i in range(mines.size() - 1, -1, -1):
		var m := mines[i]
		if enemy_near.call(m.pos, m.trigger_radius):
			out.push_front(m)
			mines.remove_at(i)
	return out
