extends TestCase
## The title picture and the map thumbnails (docs/specs/art-gaps.md, G.3).

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
		var img := MissionThumbnail.render(m)
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
