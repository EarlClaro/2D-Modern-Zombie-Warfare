extends TestCase
## The card back and the status icons (docs/specs/art-more.md, N.3).


func test_the_card_back_is_a_hand_card_at_half_size_with_notched_corners() -> void:
	var back := CardArt.back()
	assert_true(back != null)
	assert_eq(back.get_size(), CardArt.BACK_SIZE)
	assert_eq(back.get_size() * 2.0, HandUi.SLOT_SIZE, "at 2x it is exactly a hand slot")
	var img := back.get_image()
	assert_eq(img.get_pixel(0, 0).a, 0.0, "a notched corner")
	assert_eq(img.get_pixel(int(back.get_width()) / 2, int(back.get_height()) / 2).a, 1.0, "solid in the middle")


func test_every_state_effect_has_a_12_by_12_icon() -> void:
	var db := ContentDb.load_from()
	assert_true(db.effects.size() >= 4)
	for id in db.effects.keys():
		var tex := StatusIcons.texture(id)
		assert_true(tex != null, "icon for effect %s" % id)
		if tex != null:
			assert_eq(tex.get_size(), Vector2(12, 12), id)


func test_the_noise_lure_has_an_icon_and_an_unknown_id_has_none() -> void:
	assert_true(StatusIcons.texture("noise_lure") != null)
	assert_true(StatusIcons.texture("no_such_effect") == null)


func test_icons_are_drawn_not_empty() -> void:
	for id in ["fortify", "hollow_points", "quick_draw", "supply_drop", "noise_lure"]:
		var img := StatusIcons.texture(id).get_image()
		var solid := 0
		for y in 12:
			for x in 12:
				if img.get_pixel(x, y).a > 0.9:
					solid += 1
		assert_true(solid >= 25, "%s has %d solid pixels" % [id, solid])
