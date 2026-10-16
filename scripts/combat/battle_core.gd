class_name BattleCore
extends PlaceholderStructure
## The base the player must hold. Rules-wise it is one cell with a health bar. Without art it is drawn as a
## tall box; with a command-bunker definition (`MissionDefinition.core_scenery_id`) it is drawn as that sprite,
## whose frame follows the hit points (intact, damaged, burning, ruin). `radius` is how far its walls reach
## from the centre, so enemies attack the walls instead of walking into the building.
## It fades like any structure when something is behind it (IsoOcclusion), driven by the BattleController.

const FOOTPRINT: Vector2i = Vector2i.ONE
const HEIGHT_UNITS: float = 1.6

var health: Health
var radius: float = 0.0
var art: SceneryDefinition


func setup_core(cell: Vector2i, max_hp: float, p_art: SceneryDefinition = null, p_radius: float = 0.0) -> void:
	health = Health.new(max_hp)
	art = p_art
	radius = p_radius
	setup(cell, FOOTPRINT, HEIGHT_UNITS)
	if art == null:
		base_self_modulate = Color(0.7, 0.85, 1.0)
		self_modulate = base_self_modulate


func is_alive() -> bool:
	return not health.is_dead()


## Which of the art's frames shows `hp_fraction` of the hit points: 0 intact, 1 damaged, 2 burning, 3 ruin.
static func frame_for(hp_fraction: float) -> int:
	if hp_fraction <= 0.0:
		return 3
	if hp_fraction <= 0.33:
		return 2
	if hp_fraction <= 0.66:
		return 1
	return 0


func chest_world() -> Vector2:
	return position + IsoProjection.altitude_offset(height * 0.5)


func local_rect() -> Rect2:
	if art != null and art.sprite != null:
		return Rect2(-art.sprite.origin, Vector2(art.sprite.frame_size))
	return super.local_rect()


func _process(_delta: float) -> void:
	if health != null and health.hp < health.max_hp:
		queue_redraw()


func _draw() -> void:
	if art != null and art.sprite != null:
		art.sprite.draw_frame(self, frame_for(health.fraction() if health != null else 1.0), IsoProjection.Facing.SE)
		if health != null:
			BattleDraw.health_bar(self, -art.sprite.origin.y + 4.0, health.fraction(), 56.0)
		return
	super._draw()
	if health != null:
		var top_y := IsoProjection.altitude_offset(height).y - IsoProjection.TILE_H * 0.5 - 8.0
		BattleDraw.health_bar(self, top_y, health.fraction(), 44.0)
