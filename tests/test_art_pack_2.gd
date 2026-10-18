extends TestCase
## The sprite sets of the theme packs (tools/sprite_packs/pack_*.gd) and the scenery definitions made from them
## (docs/specs/art-pack-2.md): files exist and have art, definitions are valid, the category minimums are met.

const MINIMUMS: Dictionary = {
	"building": 20, "prop": 20, "vehicle": 10, "aircraft": 10, "emplacement": 10, "infantry": 10, "base": 20, "nature": 20,
}

var _specs: Array = []
var _db: ContentDb


func _all_specs() -> Array:
	if _specs.is_empty():
		var dir := DirAccess.open("res://tools/sprite_packs")
		var files := Array(dir.get_files())
		files.sort()
		for f in files:
			if f.begins_with("pack_") and f.ends_with(".gd"):
				var pk: GDScript = load("res://tools/sprite_packs/%s" % f)
				for spec in pk.specs():
					if spec.get("cat", "") != "unit":  # unit sets (pack_gameplay.gd) are not scenery
						_specs.append(spec)
	return _specs


func _get_db() -> ContentDb:
	if _db == null:
		_db = ContentDb.load_from()
	return _db


func _frame_info(dir: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites/%s/frame.json" % dir))
	return parsed if parsed is Dictionary else {}


func _has_art(img: Image) -> bool:
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.5:
				return true
	return false


func _edge_has_art(img: Image) -> bool:
	for x in img.get_width():
		if img.get_pixel(x, 0).a > 0.5 or img.get_pixel(x, img.get_height() - 1).a > 0.5:
			return true
	for y in img.get_height():
		if img.get_pixel(0, y).a > 0.5 or img.get_pixel(img.get_width() - 1, y).a > 0.5:
			return true
	return false


func test_category_minimums_are_met_and_dirs_are_unique() -> void:
	var counts: Dictionary = {}
	var seen: Dictionary = {}
	for spec in _all_specs():
		var d: String = spec["dir"]
		assert_true(not seen.has(d), "dir %s appears once" % d)
		seen[d] = true
		counts[spec["cat"]] = int(counts.get(spec["cat"], 0)) + 1
	for cat in MINIMUMS:
		assert_true(int(counts.get(cat, 0)) >= MINIMUMS[cat], "%s: %d sets, need %d" % [cat, counts.get(cat, 0), MINIMUMS[cat]])
	for cat in counts:
		assert_true(MINIMUMS.has(cat), "category %s is one of the known ones" % cat)


func test_every_set_has_its_facings_with_art_and_nothing_clipped() -> void:
	for spec in _all_specs():
		var d: String = spec["dir"]
		var meta := _frame_info(d)
		assert_true(not meta.is_empty(), "%s has frame.json" % d)
		if meta.is_empty():
			continue
		var size := Vector2i(int(meta["frame"][0]) * int(meta["columns"]), int(meta["frame"][1]) * ceili(float(meta["frames"]) / int(meta["columns"])))
		for f in spec["facings"]:
			var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/sprites/%s/%s.png" % [d, f]))
			assert_true(img != null, "%s/%s.png loads" % [d, f])
			if img == null:
				continue
			assert_eq(img.get_size(), size, "%s/%s size matches frame.json" % [d, f])
			assert_true(_has_art(img), "%s/%s has art" % [d, f])
			assert_true(not _edge_has_art(img), "%s/%s is not clipped by the frame edge" % [d, f])


func test_every_set_has_valid_scenery_definitions_with_sane_footprints() -> void:
	var db := _get_db()
	assert_eq(db.errors.size(), 0, "\n".join(db.errors))
	for spec in _all_specs():
		var d: String = spec["dir"]
		var def := db.scenery(d)
		assert_true(def != null, "scenery %s exists" % d)
		if def == null:
			continue
		assert_eq(def.validate().size(), 0, "%s: %s" % [d, "\n".join(def.validate())])
		assert_true(def.footprint.x >= 1 and def.footprint.y >= 1 and def.footprint.x <= 6 and def.footprint.y <= 6, "%s footprint %s is 1x1 to 6x6" % [d, str(def.footprint)])
		assert_true(not def.display_name.is_empty())
		var has_y: bool = "sw" in spec["facings"] or "ne" in spec["facings"]
		var def_y := db.scenery(d + "_y")
		assert_eq(def_y != null, has_y, "%s: a _y definition exists exactly when an sw/ne facing was rendered" % d)
		if def_y != null:
			assert_eq(def_y.footprint, Vector2i(def.footprint.y, def.footprint.x), "%s_y has the swapped footprint" % d)
		if "nw" in spec["facings"]:
			assert_true(def.sprite.has_exact(IsoProjection.Facing.NW), "%s has its own nw art" % d)


func test_lit_sets_carry_a_glow() -> void:
	var db := _get_db()
	var lit := 0
	for spec in _all_specs():
		if spec.has("glow"):
			lit += 1
			assert_true(db.scenery(spec["dir"]).glow_radius > 0.0, "%s glows" % spec["dir"])
	assert_true(lit >= 10, "at least ten lit sets, got %d" % lit)


func test_the_inspection_mission_loads_and_shows_every_definition() -> void:
	var db := _get_db()
	var m := db.mission("dev_showcase")
	assert_true(m != null, "dev_showcase exists")
	if m == null:
		return
	var placed: Dictionary = {}
	for p in m.map.placements():
		placed[p.scenery_id] = true
	for id in db.scenery_defs:
		if id != "hq_bunker":
			assert_true(placed.has(id), "showcase places %s" % id)
	for ch in TerrainCatalog.LEGEND:
		var found := false
		for row in m.map.rows:
			if ch in row:
				found = true
				break
		assert_true(found, "showcase has a chip of '%s'" % ch)


# --- scale sanity: a soldier is about 0.94 tiles tall, so ground cover must stay far below that -------------------

const HEIGHT_LIMITS: Dictionary = {
	"grass_tuft": [0.1, 0.35], "tall_grass": [0.2, 0.6], "fern": [0.15, 0.45], "flower_patch": [0.1, 0.4], "mushrooms": [0.05, 0.3],
	"lily_pads": [0.02, 0.2], "branch_pile": [0.1, 0.4], "dry_bush": [0.2, 0.55], "tree_stump": [0.2, 0.6], "reeds": [0.6, 1.2],
	"berry_bush": [0.3, 0.7], "thorn_bush": [0.3, 0.7], "bush": [0.3, 0.7],
	"traffic_cone": [0.2, 0.5], "fire_hydrant": [0.25, 0.55], "mailbox": [0.3, 0.7], "shopping_cart": [0.3, 0.6], "wheelie_bin": [0.35, 0.7],
	"inf_sentry": [0.7, 1.1], "inf_officer": [0.7, 1.1], "inf_fallen": [0.1, 0.4], "inf_sniper_prone": [0.1, 0.4],
	"oak_tree": [1.8, 3.2], "pine_tree": [1.8, 3.2], "birch_tree": [1.8, 3.2], "willow_tree": [1.8, 3.2],
}


func test_ground_cover_and_small_props_keep_a_believable_size() -> void:
	var db := _get_db()
	for id in HEIGHT_LIMITS:
		var def := db.scenery(id)
		assert_true(def != null, "%s exists" % id)
		if def == null:
			continue
		var h := def.shadow_height()
		assert_true(h >= HEIGHT_LIMITS[id][0] and h <= HEIGHT_LIMITS[id][1], "%s is %.2f tiles tall, expected %.2f to %.2f" % [id, h, HEIGHT_LIMITS[id][0], HEIGHT_LIMITS[id][1]])
	for id in ["lily_pads", "grass_tuft", "tall_grass", "fern", "flower_patch", "mushrooms"]:
		var def := db.scenery(id)
		assert_eq(def.footprint, Vector2i.ONE, "%s occupies one cell" % id)
		assert_true(def.sprite.frame_size.x <= 64, "%s is narrower than a tile (%d px)" % [id, def.sprite.frame_size.x])


# --- night look and shadows ----------------------------------------------------------------------------------------

func test_night_is_dark_but_still_readable() -> void:
	var night := DayNight.tint_at(0.0)
	var lum := (night.r + night.g + night.b) / 3.0
	assert_true(lum > 0.45 and lum < 0.62, "night luminance %.2f keeps colours visible without turning to day" % lum)
	assert_true(night.b > night.r, "moonlight is blue")
	assert_near(DayNight.darkness_at(0.0), 1.0, 0.02)
	assert_near(DayNight.darkness_at(0.5), 0.0, 0.001)
	assert_true(DayNight.weather_tint("rain").r > 0.8, "rain no longer muddies the night")


func test_tall_pieces_cast_shadows_and_flat_ones_do_not() -> void:
	var db := _get_db()
	var tree := SceneryShadows.polygon_for(db.scenery("oak_tree"), Vector2i(10, 10))
	assert_true(tree.size() >= 3, "a tree casts a shadow")
	var rubble := SceneryShadows.polygon_for(db.scenery("rubble_field"), Vector2i(10, 10))
	assert_true(rubble.is_empty(), "rubble is too low to cast one")
	var house := SceneryShadows.polygon_for(db.scenery("house_small"), Vector2i(10, 10))
	var lowest_x := INF
	for p in house:
		lowest_x = minf(lowest_x, p.x)
	# the shadow falls toward the screen's right: it reaches further right than the house's own footprint corner
	var footprint_right := IsoProjection.ground_to_screen(Vector2(12.6, 10.4)).x  # the footprint's right corner, shrunk a little
	var shadow_right := -INF
	for p in house:
		shadow_right = maxf(shadow_right, p.x)
	assert_true(shadow_right > footprint_right, "the shadow extends to the lower right")


func test_a_battle_builds_scenery_shadows_and_the_atmosphere_dims_them_by_day_and_night() -> void:
	var b := BattleController.new()
	b.auto_step = false
	b.setup(_get_db(), _get_db().mission("x2_outskirts"), 1)
	assert_true(b.scenery_shadows != null and b.scenery_shadows.polygon_count() > 100, "shadows exist for the tall pieces")
	var atm := Atmosphere.new()
	atm.bind(b)
	atm._process(0.0)
	assert_true(b.scenery_shadows.modulate.a <= 1.0)
	atm.free()
	b.free()
