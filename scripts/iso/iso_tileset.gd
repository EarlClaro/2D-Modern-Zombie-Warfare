class_name IsoTileSet
extends RefCounted
## Builds the isometric TileSet in code from the generated atlas `assets/tiles/terrain.png` (tools/gen_tiles.gd):
## one row per terrain, `VARIANTS` look-alike columns per row (cosmetic only, picked by a hash of the cell).
## When the atlas is missing the same layout is made from flat colours. Tile data: custom layers `walkable` and
## `buildable` (bool), identical for every variant of a terrain.

const SOURCE_ID: int = 0
const ATLAS_PATH: String = "res://assets/tiles/terrain.png"
const VARIANTS: int = 4
## Variant 0 of each terrain (the constants older code and tests use).
const TERRAIN_GRASS: Vector2i = Vector2i(0, 0)
const TERRAIN_ROAD: Vector2i = Vector2i(0, 1)
const TERRAIN_ROCK: Vector2i = Vector2i(0, 2)
const TERRAIN_DIRT: Vector2i = Vector2i(0, 3)
const TERRAIN_PAVED: Vector2i = Vector2i(0, 4)
const TERRAIN_RUBBLE: Vector2i = Vector2i(0, 5)
const TERRAIN_WATER: Vector2i = Vector2i(0, 6)

## Row order must match tools/gen_tiles.gd. `ch` is the MapDefinition terrain character.
const _TERRAINS: Array[Dictionary] = [
	{"row": 0, "ch": ".", "color": Color("56823f"), "walkable": true, "buildable": true},
	{"row": 1, "ch": "=", "color": Color("6e6d6a"), "walkable": true, "buildable": false},
	{"row": 2, "ch": "#", "color": Color("4c4d55"), "walkable": false, "buildable": false},
	{"row": 3, "ch": ",", "color": Color("80613c"), "walkable": true, "buildable": true},
	{"row": 4, "ch": "p", "color": Color("92928b"), "walkable": true, "buildable": true},
	{"row": 5, "ch": "x", "color": Color("5d5a53"), "walkable": true, "buildable": false},
	{"row": 6, "ch": "w", "color": Color("2f6785"), "walkable": false, "buildable": false},
]


## Atlas coordinates of the tile to draw for terrain character `ch` at `cell`. The variant depends only on the
## cell, so the same map always looks the same; variant 0 is the most common.
static func coords_for(ch: String, cell: Vector2i) -> Vector2i:
	var row := terrain_row(ch)
	if row < 0:
		return TERRAIN_GRASS
	return Vector2i(variant_for(cell), row)


static func terrain_row(ch: String) -> int:
	for t in _TERRAINS:
		if t["ch"] == ch:
			return t["row"]
	return -1


static func variant_for(cell: Vector2i) -> int:
	var n: int = ((cell.x * 73856093) ^ (cell.y * 19349663)) & 0x7fffffff
	n = ((n ^ (n >> 15)) * 40503) & 0x7fffffff
	var r := n % 100
	if r < 55:
		return 0
	if r < 75:
		return 1
	if r < 90:
		return 2
	return 3


static func build() -> TileSet:
	var tile_size := Vector2i(int(IsoProjection.TILE_W), int(IsoProjection.TILE_H))
	var ts := TileSet.new()
	ts.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	ts.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	ts.tile_size = tile_size
	ts.add_custom_data_layer()
	ts.set_custom_data_layer_name(0, "walkable")
	ts.set_custom_data_layer_type(0, TYPE_BOOL)
	ts.add_custom_data_layer()
	ts.set_custom_data_layer_name(1, "buildable")
	ts.set_custom_data_layer_type(1, TYPE_BOOL)

	var src := TileSetAtlasSource.new()
	src.texture = _atlas(tile_size)
	src.texture_region_size = tile_size
	ts.add_source(src, SOURCE_ID)
	for t in _TERRAINS:
		for v in VARIANTS:
			var coords := Vector2i(v, t["row"])
			src.create_tile(coords)
			var data := src.get_tile_data(coords, 0)
			data.set_custom_data("walkable", t["walkable"])
			data.set_custom_data("buildable", t["buildable"])
	return ts


static func _atlas(tile_size: Vector2i) -> Texture2D:
	if ResourceLoader.exists(ATLAS_PATH):
		var tex := load(ATLAS_PATH) as Texture2D
		if tex != null and tex.get_size() == Vector2(tile_size.x * VARIANTS, tile_size.y * _TERRAINS.size()):
			return tex
	return _make_flat_atlas(tile_size)


static func _make_flat_atlas(tile_size: Vector2i) -> ImageTexture:
	var img := Image.create(tile_size.x * VARIANTS, tile_size.y * _TERRAINS.size(), false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var hw := tile_size.x * 0.5
	var hh := tile_size.y * 0.5
	for t in _TERRAINS:
		var base: Color = t["color"]
		for v in VARIANTS:
			var x0 := v * tile_size.x
			var y0: int = int(t["row"]) * tile_size.y
			for y in tile_size.y:
				for x in tile_size.x:
					if absf(x + 0.5 - hw) / hw + absf(y + 0.5 - hh) / hh <= 1.0:
						img.set_pixel(x0 + x, y0 + y, base)
	return ImageTexture.create_from_image(img)
