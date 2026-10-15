class_name BattleCore
extends PlaceholderStructure
## The base the player must hold. A 1x1 tall box with a health bar; fades like any structure when
## something is behind it (IsoOcclusion), driven by the BattleController.

const FOOTPRINT: Vector2i = Vector2i.ONE
const HEIGHT_UNITS: float = 1.6

var health: Health


func setup_core(cell: Vector2i, max_hp: float) -> void:
	health = Health.new(max_hp)
	setup(cell, FOOTPRINT, HEIGHT_UNITS)
	base_self_modulate = Color(0.7, 0.85, 1.0)
	self_modulate = base_self_modulate


func is_alive() -> bool:
	return not health.is_dead()


func chest_world() -> Vector2:
	return position + IsoProjection.altitude_offset(height * 0.5)


func _process(_delta: float) -> void:
	if health != null and health.hp < health.max_hp:
		queue_redraw()


func _draw() -> void:
	super._draw()
	if health != null:
		var top_y := IsoProjection.altitude_offset(height).y - IsoProjection.TILE_H * 0.5 - 8.0
		BattleDraw.health_bar(self, top_y, health.fraction(), 44.0)
