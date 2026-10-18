extends TestCase
## The victory and defeat pictures on the result panel (docs/specs/art-more.md, N.6).

var _roots: Array[Node] = []


func _release() -> void:
	for r in _roots:
		if is_instance_valid(r):
			r.get_parent().remove_child(r)
			r.free()
	_roots.clear()


func test_both_pictures_exist_at_128_by_40() -> void:
	for path in [ResultPanel.ART_VICTORY, ResultPanel.ART_DEFEAT]:
		var tex := load(path) as Texture2D
		assert_true(tex != null, path)
		assert_eq(tex.get_size(), Vector2(128, 40), path)
		assert_eq(tex.get_size() * 4.0, Vector2(512, 160), "4x is the panel's picture size")
	assert_eq(ResultPanel.ART_SIZE, Vector2(512, 160))
	assert_true((load(ResultPanel.ART_VICTORY) as Texture2D).get_image().get_data() != (load(ResultPanel.ART_DEFEAT) as Texture2D).get_image().get_data(), "two different scenes")


func test_the_panel_shows_the_picture_that_fits_the_outcome() -> void:
	var db := ContentDb.load_from()
	var b := BattleController.new()
	b.auto_step = false
	b.setup(db, db.mission("m1_hold_the_crossing"), 1)
	tree.root.add_child(b)
	_roots.append(b)
	var panel := ResultPanel.new()
	panel.bind(b)
	tree.root.add_child(panel)
	_roots.append(panel)
	var art: TextureRect = panel.find_child("ResultArt", true, false)
	assert_true(art != null)
	panel._on_ended(MissionRules.Result.new(MissionRules.Status.WON, "held"))
	assert_eq(art.texture.resource_path, ResultPanel.ART_VICTORY)
	panel._on_ended(MissionRules.Result.new(MissionRules.Status.FAILED, "overrun", "core"))
	assert_eq(art.texture.resource_path, ResultPanel.ART_DEFEAT)
	_release()
