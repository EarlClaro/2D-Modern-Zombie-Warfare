extends TestCase
## The title picture, the logo and the map thumbnails (docs/specs/art-gaps.md, G.3; docs/specs/art-polish.md, P.2).

var _db: ContentDb


func _get_db() -> ContentDb:
	if _db == null:
		_db = ContentDb.load_from()
	return _db


func test_title_picture_exists_and_has_the_expected_size() -> void:
	var tex := load("res://assets/ui/title.png") as Texture2D
	assert_true(tex != null)
	assert_eq(tex.get_size(), Vector2(480, 270), "480 x 270 shows 4x on the 1920 x 1080 base")


func test_title_background_is_a_texture_rect() -> void:
	var bg := UiKit.title_background()
	assert_true(bg is TextureRect)
	bg.free()


func test_every_mission_has_a_thumbnail_with_its_core_and_spawns_marked() -> void:
	for id in _get_db().missions.keys():
		var m: MissionDefinition = _get_db().missions[id]
		var img := MissionThumbnail.render(m, _get_db())
		assert_eq(img.get_size(), MissionThumbnail.size_of(m.map), id)
		var core_px := 0
		var spawn_px := 0
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if c == MissionThumbnail.CORE_COLOR:
					core_px += 1
				elif c == MissionThumbnail.SPAWN_COLOR:
					spawn_px += 1
		assert_true(core_px > 0, "%s: the core is marked" % id)
		assert_true(spawn_px > 0 or m.spawn_cells.is_empty(), "%s: the spawns are marked" % id)


func test_thumbnail_is_cached_per_mission() -> void:
	var m: MissionDefinition = _get_db().mission("m1_hold_the_crossing")
	assert_true(MissionThumbnail.texture(m) == MissionThumbnail.texture(m))
	assert_true(MissionThumbnail.texture(null) == null)


func test_logo_is_drawn_and_the_menu_shows_it_at_4x() -> void:
	var tex := load("res://assets/ui/logo.png") as Texture2D
	assert_true(tex != null)
	assert_eq(tex.get_size(), Vector2(160, 56))
	var img := tex.get_image()
	var solid := 0
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a >= 0.9:
				solid += 1
	assert_true(solid > 2000, "the logo has letters in it (%d solid pixels)" % solid)
	var menu := MainMenu.new()
	var logo := menu._logo()
	assert_true(logo is TextureRect)
	assert_eq(logo.custom_minimum_size, tex.get_size() * float(MainMenu.LOGO_SCALE))
	logo.free()
	menu.free()


func test_thumbnail_shows_the_scenery_and_each_map_looks_different() -> void:
	var db := _get_db()
	var m: MissionDefinition = db.mission("x2_outskirts")
	var bare := MissionThumbnail.render(m)
	var full := MissionThumbnail.render(m, db)
	assert_eq(bare.get_size(), full.get_size())
	var differing := 0
	for y in full.get_height():
		for x in full.get_width():
			if bare.get_pixel(x, y) != full.get_pixel(x, y):
				differing += 1
	assert_true(differing > 300, "the buildings and trees change %d pixels" % differing)
	var other := MissionThumbnail.render(db.mission("x7_bridge_line"), db)
	assert_true(other.get_size() != full.get_size() or other.get_data() != full.get_data(), "two maps give two pictures")


func test_thumbnail_has_a_clear_background_and_a_dark_outline() -> void:
	var m: MissionDefinition = _get_db().mission("m1_hold_the_crossing")
	var img := MissionThumbnail.render(m, _get_db())
	assert_eq(img.get_pixel(0, 0).a, 0.0, "the corner is empty")
	var solid := 0
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.9:
				solid += 1
	assert_true(solid > 1500, "the map fills the picture (%d solid pixels)" % solid)
