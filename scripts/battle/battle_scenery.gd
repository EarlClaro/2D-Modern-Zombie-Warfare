class_name BattleScenery
extends IsoEntity
## A decoration in the battle: draws one sprite frame, sorted with the other entities by its footprint centre.
## Tall pieces fade (alpha) while something stands behind them; the BattleController decides when.

var def: SceneryDefinition
var origin_cell: Vector2i = Vector2i.ZERO
var facing: int = IsoProjection.Facing.SE
var frame: int = 0
var faded: bool = false  # target state; the alpha follows it a little each frame


func setup_scenery(p_def: SceneryDefinition, cell: Vector2i, p_facing: int) -> void:
	def = p_def
	origin_cell = cell
	facing = p_facing
	ground_pos = p_def.center_at(cell)
	queue_redraw()


func set_frame(f: int) -> void:
	if f != frame:
		frame = f
		queue_redraw()


## Art box in entity-local px (used for the fade test).
func local_rect() -> Rect2:
	if def == null or def.sprite == null:
		return Rect2()
	return Rect2(-def.sprite.origin, Vector2(def.sprite.frame_size))


func update_fade(delta: float) -> void:
	var target_alpha := IsoOcclusion.FADED_ALPHA if faded else 1.0
	if not is_equal_approx(modulate.a, target_alpha):
		modulate.a = IsoOcclusion.next_alpha(modulate.a, faded, delta)


func _draw() -> void:
	if def != null and def.sprite != null:
		def.sprite.draw_frame(self, frame, facing)
