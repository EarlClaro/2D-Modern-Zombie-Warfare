extends TestCase
## The terrain list (scripts/world/terrain_catalog.gd), the atlas painted from it and the map rules built on it
## (docs/specs/art-pack-2.md).

const ORIGINAL: Array[String] = [".", "=", "#", ",", "p", "x", "w"]


func test_catalog_is_consistent_with_the_legend() -> void:
	var chars := ""
	var seen: Dictionary = {}
	for i in TerrainCatalog.count():
		var t := TerrainCatalog.ALL[i]
		var ch: String = t["ch"]
		assert_eq(ch.length(), 1, "'%s' is one character" % t["id"])
		assert_true(not seen.has(ch), "character '%s' is unique" % ch)
		assert_true(not seen.has(t["id"]), "id %s is unique" % t["id"])
		seen[ch] = true
		seen[t["id"]] = true
		assert_eq(TerrainCatalog.row_of(ch), i, "row of '%s'" % ch)
		chars += ch
	assert_eq(TerrainCatalog.LEGEND, chars, "LEGEND lists every character in row order")
	assert_eq(MapDefinition.LEGEND, TerrainCatalog.LEGEND)
	assert_true(not ('"' in chars) and not ("\\" in chars) and not (" " in chars), "characters are safe inside a map text row")


func test_the_original_terrains_keep_their_rows_and_rules() -> void:
	for i in ORIGINAL.size():
		assert_eq(TerrainCatalog.row_of(ORIGINAL[i]), i, "row of original '%s'" % ORIGINAL[i])
	for ch in [".", ",", "p"]:
		assert_true(TerrainCatalog.is_walkable(ch) and TerrainCatalog.is_buildable(ch), "'%s' open ground" % ch)
	assert_true(TerrainCatalog.is_walkable("=") and TerrainCatalog.is_buildable("="), "road")
	assert_true(TerrainCatalog.is_walkable("x") and TerrainCatalog.is_buildable("x"), "rubble")
	for ch in ["#", "w"]:
		assert_true(not TerrainCatalog.is_walkable(ch) and not TerrainCatalog.is_buildable(ch), "'%s' blocks" % ch)
	assert_true(not TerrainCatalog.is_walkable("?") and not TerrainCatalog.is_buildable("?"), "unknown characters are blocked")
	assert_eq(TerrainCatalog.row_of("?"), -1)


func test_there_are_at_least_twenty_new_terrains_and_nothing_buildable_is_unwalkable() -> void:
	assert_true(TerrainCatalog.count() - ORIGINAL.size() >= 20, "20+ new terrains, got %d" % (TerrainCatalog.count() - ORIGINAL.size()))
	for t in TerrainCatalog.ALL:
		if t["buildable"]:
			assert_true(t["walkable"], "%s: a buildable cell must be walkable" % t["id"])
	var blocking := 0
	for t in TerrainCatalog.ALL:
		if not t["walkable"]:
			blocking += 1
	assert_eq(blocking, 2, "only rock and water block; every new ground can be crossed")


func test_every_catalog_map_row_validates_and_flags_follow_the_catalog() -> void:
	var m := MapDefinition.new()
	m.id = "t"
	m.rows = PackedStringArray([TerrainCatalog.LEGEND])
	assert_eq(m.validate().size(), 0, "\n".join(m.validate()))
	for i in TerrainCatalog.count():
		var t := TerrainCatalog.ALL[i]
		assert_eq(MapDefinition.char_is_walkable(t["ch"]), t["walkable"], "walkable %s" % t["id"])
		assert_eq(MapDefinition.char_is_buildable(t["ch"]), t["buildable"], "buildable %s" % t["id"])


func test_atlas_has_one_row_per_terrain_with_art_in_every_variant() -> void:
	var tex := load(IsoTileSet.ATLAS_PATH) as Texture2D
	assert_true(tex != null, "atlas loads")
	if tex == null:
		return
	assert_eq(tex.get_size(), Vector2(64 * IsoTileSet.VARIANTS, 32 * TerrainCatalog.count()), "atlas size follows the catalog")
	var img := tex.get_image()
	for row in TerrainCatalog.count():
		for v in IsoTileSet.VARIANTS:
			var ox := v * 64
			var oy := row * 32
			assert_true(img.get_pixel(ox + 32, oy + 16).a > 0.99, "%s v%d centre is opaque" % [TerrainCatalog.ALL[row]["id"], v])
			assert_true(img.get_pixel(ox, oy).a < 0.01 and img.get_pixel(ox + 63, oy + 31).a < 0.01, "%s v%d corners are clear" % [TerrainCatalog.ALL[row]["id"], v])
			assert_true(img.get_pixel(ox + 32, oy + 1).a > 0.99 and img.get_pixel(ox + 32, oy + 30).a > 0.99, "%s v%d reaches the diamond tips" % [TerrainCatalog.ALL[row]["id"], v])


func test_each_new_terrain_has_variants_that_differ() -> void:
	var tex := load(IsoTileSet.ATLAS_PATH) as Texture2D
	if tex == null:
		return
	var img := tex.get_image()
	for row in range(ORIGINAL.size(), TerrainCatalog.count()):
		var differing := 0
		for v in range(1, IsoTileSet.VARIANTS):
			var diff := 0
			for y in 32:
				for x in 64:
					if img.get_pixel(x, row * 32 + y) != img.get_pixel(v * 64 + x, row * 32 + y):
						diff += 1
			if diff > 40:
				differing += 1
		assert_true(differing >= 2, "%s: at least two variants look different from variant 0" % TerrainCatalog.ALL[row]["id"])


func test_coords_for_picks_the_row_of_every_catalog_character() -> void:
	for i in TerrainCatalog.count():
		var c := IsoTileSet.coords_for(TerrainCatalog.ALL[i]["ch"], Vector2i(5, 9))
		assert_eq(c.y, i, "row for %s" % TerrainCatalog.ALL[i]["id"])
		assert_true(c.x >= 0 and c.x < IsoTileSet.VARIANTS)
