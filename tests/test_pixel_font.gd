extends TestCase
## The pixel font (docs/specs/pixel-ui.md, increment U.1): the file loads, covers the characters the UI shows, and is
## scaled in whole pixels.

var _db: ContentDb


func _get_db() -> ContentDb:
	if _db == null:
		_db = ContentDb.load_from()
	return _db


func test_font_loads_and_is_not_the_fallback() -> void:
	assert_true(PixelFont.font() != ThemeDB.fallback_font)
	assert_true(PixelFont.font() is FontFile)


func test_every_printable_ascii_character_has_a_glyph() -> void:
	var f := PixelFont.font()
	for code in range(32, 127):
		assert_true(f.has_char(code), "no glyph for '%s' (%d)" % [char(code), code])
	assert_true(f.has_char(0x2014), "no em dash")


func test_text_size_scales_in_whole_pixels() -> void:
	var f := PixelFont.font()
	var one := f.get_string_size("Helicopter", HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var two := f.get_string_size("Helicopter", HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var three := f.get_string_size("Helicopter", HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	assert_near(two, one * 2.0)
	assert_near(three, one * 3.0)
	assert_true(one > 0.0)


func test_widths_are_proportional() -> void:
	var f := PixelFont.font()
	assert_true(f.get_string_size("iii", HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x < f.get_string_size("mmm", HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x)


func test_missing_char_reports_what_it_cannot_draw() -> void:
	assert_eq(PixelFont.missing_char("Hold the Crossing (x2)"), "")
	assert_eq(PixelFont.missing_char("caf\u00e9"), "\u00e9")


## Everything a player reads in the cards, missions and upgrades must be drawable.
func test_content_text_is_drawable() -> void:
	var db := _get_db()
	var bad: Array[String] = []
	for c in db.cards.values():
		for s in [c.display_name, c.description]:
			if PixelFont.missing_char(s) != "":
				bad.append("card %s: %s" % [c.id, s])
	for id in db.missions.keys():
		var m: MissionDefinition = db.missions[id]
		for s in [m.display_name]:
			if PixelFont.missing_char(s) != "":
				bad.append("mission %s: %s" % [id, s])
	for u in db.upgrades.values():
		for s in [u.display_name, u.description]:
			if PixelFont.missing_char(s) != "":
				bad.append("upgrade %s: %s" % [u.id, s])
	assert_eq(bad.size(), 0, "undrawable text: %s" % ", ".join(bad))
