class_name IsoTileSet
extends RefCounted
## Builds the placeholder isometric TileSet (colored diamonds) in code. No art files needed.
## Tile data: custom layers `walkable` and `buildable` (bool).

const SOURCE_ID: int = 0
const TERRAIN_GRASS: Vector2i = Vector2i(0, 0)
const TERRAIN_ROAD: Vector2i = Vector2i(1, 0)
const TERRAIN_ROCK: Vector2i = Vector2i(2, 0)

const _TERRAINS: Array[Dictionary] = [
	{"coords": TERRAIN_GRASS, "color": Color("5d8a4a"), "walkable": true, "buildable": true},
	{"coords": TERRAIN_ROAD, "color": Color("8c8472"), "walkable": true, "buildable": false},
	{"coords": TERRAIN_ROCK, "color": Color("4a4a52"), "walkable": false, "buildable": false},
]


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
	src.texture = _make_atlas(tile_size)
	src.texture_region_size = tile_size
	ts.add_source(src, SOURCE_ID)
	for t in _TERRAINS:
		var coords: Vector2i = t["coords"]
		src.create_tile(coords)
		var data := src.get_tile_data(coords, 0)
		data.set_custom_data("walkable", t["walkable"])
		data.set_custom_data("buildable", t["buildable"])
	return ts


static func _make_atlas(tile_size: Vector2i) -> ImageTexture:
	var img := Image.create(tile_size.x * _TERRAINS.size(), tile_size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var hw := tile_size.x * 0.5
	var hh := tile_size.y * 0.5
	for i in _TERRAINS.size():
		var base: Color = _TERRAINS[i]["color"]
		var x0: int = (_TERRAINS[i]["coords"] as Vector2i).x * tile_size.x
		for y in tile_size.y:
			for x in tile_size.x:
				var d := absf(x + 0.5 - hw) / hw + absf(y + 0.5 - hh) / hh
				if d <= 1.0:
					# Light from top-left: brighten the upper-left edges, darken lower-right edges.
					var shade := 1.0
					if d > 0.88:
						var upper_left := (x + 0.5 - hw) + (y + 0.5 - hh) * 2.0 < 0.0
						shade = 1.25 if upper_left else 0.7
					img.set_pixel(x0 + x, y, Color(base.r * shade, base.g * shade, base.b * shade, 1.0))
	return ImageTexture.create_from_image(img)
