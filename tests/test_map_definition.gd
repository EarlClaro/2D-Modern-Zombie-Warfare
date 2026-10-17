extends TestCase

const MapDef := preload("res://scripts/missions/map_definition.gd")
const IsoTiles := preload("res://scripts/iso/iso_tileset.gd")


func _map(rows: Array) -> MapDef:
	var m := MapDef.new()
	m.id = "t_map"
	m.rows = PackedStringArray(rows)
	return m


func _has(errs: PackedStringArray, needle: String) -> bool:
	for e in errs:
		if needle in e:
			return true
	return false


func test_dimensions_and_cells() -> void:
	var m := _map(["..=", "#.."])
	assert_eq(m.width(), 3)
	assert_eq(m.height(), 2)
	assert_eq(m.terrain_char(Vector2i(2, 0)), "=")
	assert_eq(m.terrain_char(Vector2i(0, 1)), "#", "x is the column, y is the row")
	assert_eq(m.terrain_char(Vector2i(3, 0)), "", "outside the map")


func test_bounds() -> void:
	var m := _map(["...", "..."])
	assert_true(m.in_bounds(Vector2i(0, 0)))
	assert_true(m.in_bounds(Vector2i(2, 1)))
	assert_true(not m.in_bounds(Vector2i(3, 1)))
	assert_true(not m.in_bounds(Vector2i(0, 2)))
	assert_true(not m.in_bounds(Vector2i(-1, 0)))
	assert_true(not m.in_bounds(Vector2i(0, -1)))


func test_walkable_and_buildable() -> void:
	var m := _map([".=#"])
	assert_true(m.is_walkable(Vector2i(0, 0)) and m.is_buildable(Vector2i(0, 0)), "grass")
	assert_true(m.is_walkable(Vector2i(1, 0)) and m.is_buildable(Vector2i(1, 0)), "road")
	assert_true(not m.is_walkable(Vector2i(2, 0)) and not m.is_buildable(Vector2i(2, 0)), "rock")
	assert_true(not m.is_walkable(Vector2i(5, 5)), "outside is not walkable")


func test_valid_map_has_no_errors() -> void:
	assert_eq(_map(["..=", "#.."]).validate().size(), 0)


func test_empty_and_ragged_and_unknown_char_errors() -> void:
	assert_true(_has(_map([]).validate(), "rows is empty"))
	assert_true(_has(_map(["..", "..."]).validate(), "rectangular"))
	assert_true(_has(_map(["..", ".?"]).validate(), "unknown terrain character '?' at (1, 1)"))
	assert_true(_has(_map([""]).validate(), "row 0 is empty"))


func test_oversize_map_is_rejected() -> void:
	var big: Array = []
	for i in MapDef.MAX_SIZE + 1:
		big.append(".")
	assert_true(_has(_map(big).validate(), "exceeds the maximum"))


func test_segment_walkable_straight_lines() -> void:
	var m := _map(["....", "....", "....", "...."])
	assert_true(m.segment_is_walkable(Vector2(0.5, 0.5), Vector2(3.5, 3.5)))
	assert_true(m.segment_is_walkable(Vector2(0.5, 0.5), Vector2(0.5, 0.5)), "zero-length segment")


func test_segment_blocked_by_rock_and_by_leaving_the_map() -> void:
	var m := _map(["....", ".#..", "....", "...."])
	assert_true(not m.segment_is_walkable(Vector2(0.5, 1.5), Vector2(3.5, 1.5)), "straight through the rock")
	assert_true(m.segment_is_walkable(Vector2(0.5, 0.5), Vector2(3.5, 0.5)), "row 0 is clear")
	assert_true(not m.segment_is_walkable(Vector2(0.5, 0.5), Vector2(5.5, 0.5)), "leaves the map")


func test_segment_diagonal_through_a_gap() -> void:
	# A wall with a one-cell gap; the diagonal line must pass the gap cell only.
	var m := _map(["#..", "...", "..#"])
	assert_true(m.segment_is_walkable(Vector2(1.5, 0.5), Vector2(1.5, 2.5)))
	assert_true(not m.segment_is_walkable(Vector2(0.5, 0.5), Vector2(2.5, 2.5)), "corner-to-corner hits both rocks")


func test_terrain_flags_match_iso_tileset_tile_data() -> void:
	# The map legend must agree with the placeholder TileSet used to draw it.
	var layer := TileMapLayer.new()
	layer.tile_set = IsoTiles.build()
	for ch in MapDef.LEGEND:  # every terrain, every look-variant
		for v in IsoTiles.VARIANTS:
			layer.set_cell(Vector2i.ZERO, IsoTiles.SOURCE_ID, Vector2i(v, IsoTiles.terrain_row(ch)))
			var data := layer.get_cell_tile_data(Vector2i.ZERO)
			assert_true(data != null, "tile exists for '%s' variant %d" % [ch, v])
			if data == null:
				continue
			assert_eq(data.get_custom_data("walkable"), MapDef.char_is_walkable(ch), "walkable for '%s' v%d" % [ch, v])
			assert_eq(data.get_custom_data("buildable"), MapDef.char_is_buildable(ch), "buildable for '%s' v%d" % [ch, v])
	layer.free()


func test_shipped_crossing_map() -> void:
	var m: MapDef = load("res://data/maps/crossing.tres")
	assert_true(m != null)
	assert_eq(m.validate().size(), 0, "\n".join(m.validate()))
	assert_eq(m.width(), 24)
	assert_eq(m.height(), 24)
