class_name SceneryDefinition
extends ContentDefinition
## A piece of decoration (tree, trash, building, wall, ...). Static art only: no hit points, no behaviour.
## It occupies `footprint` cells (origin cell = lowest x and y, extending +x/+y), which nobody can build on and
## which enemy paths must not cross. Tall pieces fade when something stands behind them (IsoOcclusion).

@export var display_name: String = ""
@export var sprite: SpriteSheet
@export var footprint: Vector2i = Vector2i.ONE
## True for pieces tall enough to hide units behind them (trees, buildings): they fade then.
@export var fades: bool = false
## Height of the piece in tiles (from the rendered art): how long a shadow it casts. 0 = unknown, estimated from the art.
@export var height_units: float = 0.0
## Optional night glow (lamp, searchlight, fire): offset from the piece's anchor in px, radius in px (0 = none)
## and colour. Drawn by Atmosphere when it is dark.
@export var glow_offset: Vector2 = Vector2.ZERO
@export var glow_radius: float = 0.0
@export var glow_color: Color = Color(1.0, 0.85, 0.5, 1.0)


func kind() -> String:
	return "scenery"


func validate() -> PackedStringArray:
	var errs := super.validate()
	if display_name.is_empty():
		errs.append(_err("display_name is empty"))
	if sprite == null:
		errs.append(_err("sprite is not set"))
	elif sprite.textures.is_empty():
		errs.append(_err("sprite has no textures"))
	if footprint.x < 1 or footprint.y < 1:
		errs.append(_err("footprint must be at least 1x1"))
	if glow_radius < 0.0:
		errs.append(_err("glow_radius must be >= 0"))
	if height_units < 0.0:
		errs.append(_err("height_units must be >= 0"))
	return errs


## The cells this piece covers when placed with its origin at `origin`.
func cells_at(origin: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in footprint.y:
		for x in footprint.x:
			out.append(origin + Vector2i(x, y))
	return out


## Height used for the shadow: the stored value, else about what the art's height above its base point suggests.
func shadow_height() -> float:
	if height_units > 0.0:
		return height_units
	if sprite == null:
		return 0.0
	return sprite.origin.y / IsoProjection.Z_PX_PER_UNIT


## Ground position of the piece's centre (its y-sort anchor and the origin pixel of its art).
func center_at(origin: Vector2i) -> Vector2:
	return Vector2(origin) + Vector2(footprint) * 0.5
