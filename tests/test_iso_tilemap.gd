extends TestCase
## Verifies Godot's TileMapLayer (DIAMOND_DOWN, 64x32) agrees with IsoProjection (spec criterion 8).

const Iso := preload("res://scripts/iso/iso_projection.gd")
const IsoTiles := preload("res://scripts/iso/iso_tileset.gd")

const SAMPLE_CELLS: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(5, 3), Vector2i(-2, 4), Vector2i(-7, -9), Vector2i(40, 25),
]


func _make_layer() -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.tile_set = IsoTiles.build()
	layer.position = Iso.TILEMAP_LAYER_OFFSET
	return layer


func test_map_to_local_matches_projection() -> void:
	var layer := _make_layer()
	for c in SAMPLE_CELLS:
		var screen: Vector2 = layer.map_to_local(c) + layer.position
		assert_vec_near(screen, Iso.ground_to_screen(Iso.cell_center(c)), 1e-3, "cell %s" % str(c))
	layer.free()


func test_local_to_map_matches_cell_of() -> void:
	var layer := _make_layer()
	# Points strictly inside cells (never on edges), several per cell, including negative cells.
	for c in SAMPLE_CELLS:
		for off in [Vector2(0.1, 0.1), Vector2(0.9, 0.1), Vector2(0.1, 0.9), Vector2(0.9, 0.9), Vector2(0.5, 0.5), Vector2(0.3, 0.7)]:
			var g: Vector2 = Vector2(c) + off
			var screen := Iso.ground_to_screen(g)
			assert_eq(layer.local_to_map(screen - layer.position), Iso.cell_of(g), "cell %s off %s" % [str(c), str(off)])
	layer.free()


func test_placeholder_tile_data() -> void:
	var layer := _make_layer()
	layer.set_cell(Vector2i(0, 0), IsoTiles.SOURCE_ID, IsoTiles.TERRAIN_GRASS)
	layer.set_cell(Vector2i(1, 0), IsoTiles.SOURCE_ID, IsoTiles.TERRAIN_ROAD)
	layer.set_cell(Vector2i(2, 0), IsoTiles.SOURCE_ID, IsoTiles.TERRAIN_ROCK)
	var grass := layer.get_cell_tile_data(Vector2i(0, 0))
	var road := layer.get_cell_tile_data(Vector2i(1, 0))
	var rock := layer.get_cell_tile_data(Vector2i(2, 0))
	assert_true(grass != null and road != null and rock != null, "tile data exists")
	if grass != null and road != null and rock != null:
		assert_eq(grass.get_custom_data("walkable"), true)
		assert_eq(grass.get_custom_data("buildable"), true)
		assert_eq(road.get_custom_data("walkable"), true)
		assert_eq(road.get_custom_data("buildable"), true, "roads can be built on")
		assert_eq(rock.get_custom_data("walkable"), false)
		assert_eq(rock.get_custom_data("buildable"), false)
	assert_true(layer.get_cell_tile_data(Vector2i(9, 9)) == null, "empty cell has no data")
	layer.free()
