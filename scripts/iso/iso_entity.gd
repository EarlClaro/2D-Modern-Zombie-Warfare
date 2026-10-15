class_name IsoEntity
extends Node2D
## Base for anything placed on the battlefield. Authoritative position is `ground_pos` (tiles) plus
## `altitude` (z). The node's own `position` is the projected footprint base point = the y-sort anchor,
## so aircraft sort by their ground position and only their *drawing* is lifted by altitude.
## Also carries small presentation helpers (hit flash, death collapse) that never touch game rules.

const CHEST_DEFAULT_PX: float = 20.0

var ground_pos: Vector2 = Vector2.ZERO:
	set(v):
		ground_pos = v
		position = IsoProjection.ground_to_screen(v)

var altitude: float = 0.0:
	set(v):
		altitude = v
		queue_redraw()

## Resting self_modulate (tint) that a flash returns to.
var base_self_modulate: Color = Color.WHITE
## True once the death collapse has started; the entity is already out of the simulation by then.
var dying: bool = false

var _flash_tween: Tween


func sort_key() -> float:
	return IsoProjection.sort_key(ground_pos)


## Bounding box of what this entity draws, in entity-local px. Override.
func local_rect() -> Rect2:
	return Rect2()


## Same box in world px (used for occlusion tests).
func world_rect() -> Rect2:
	var r := local_rect()
	r.position += position
	return r


## World-pixel point where hits land / tracers end. Override for taller or shorter bodies.
func chest_world() -> Vector2:
	return position + Vector2(0.0, -CHEST_DEFAULT_PX)


## Brief colour flash (values above 1 brighten). Needs the scene tree; a no-op otherwise.
func flash(color: Color, duration: float) -> void:
	if not is_inside_tree() or dying:
		return
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	self_modulate = color
	_flash_tween = create_tween()
	_flash_tween.tween_property(self, "self_modulate", base_self_modulate, duration)


## Collapse (squash toward the feet) and fade, then free this node and its shadow.
## Call after the entity has been removed from the simulation lists. Requires the scene tree.
func play_death(duration: float, shadow_node: Node = null) -> void:
	dying = true
	set_process(false)
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	self_modulate = base_self_modulate
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, duration)
	tw.tween_property(self, "scale", Vector2(1.25, 0.25), duration)
	if shadow_node != null and is_instance_valid(shadow_node):
		tw.tween_property(shadow_node, "modulate:a", 0.0, duration)
	tw.chain().tween_callback(_finish_death.bind(shadow_node))


## Sprite death: play the sheet's death frames once, hold the last, fade, then free node and shadow.
## Same contract as play_death (call after leaving the simulation, needs the scene tree).
func play_sprite_death(sheet: SpriteSheet, shadow_node: Node = null) -> void:
	dying = true
	set_process(false)
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	self_modulate = base_self_modulate
	_set_death_frame(sheet.death_first)
	var anim_s := float(sheet.death_count) / sheet.death_fps
	var tw := create_tween()
	tw.tween_method(_play_death_frame.bind(sheet), 0.0, anim_s, anim_s)
	tw.tween_interval(sheet.death_hold_s)
	tw.tween_property(self, "modulate:a", 0.0, sheet.death_fade_s)
	if shadow_node != null and is_instance_valid(shadow_node):
		tw.parallel().tween_property(shadow_node, "modulate:a", 0.0, sheet.death_fade_s)
	tw.tween_callback(_finish_death.bind(shadow_node))


func _play_death_frame(t: float, sheet: SpriteSheet) -> void:
	_set_death_frame(sheet.death_first + mini(floori(t * sheet.death_fps), sheet.death_count - 1))


## Override: show this sheet frame (the body draws from its own frame index).
func _set_death_frame(_frame_index: int) -> void:
	pass


func _finish_death(shadow_node: Node) -> void:
	if shadow_node != null and is_instance_valid(shadow_node):
		shadow_node.queue_free()
	queue_free()
