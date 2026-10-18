extends TestCase
## The picture on a card face (docs/specs/card-loop.md "Card faces"): every card has a picture file, and every picture file
## belongs to a card. The pictures are made by tools/gen_card_pictures.gd.

var _db: ContentDb


func _get_db() -> ContentDb:
	if _db == null:
		_db = ContentDb.load_from()
	return _db


func test_every_card_has_a_picture() -> void:
	for id in _get_db().cards.keys():
		assert_true(CardArt.texture(id) != null, "%s has no picture in assets/cards" % id)


func test_pictures_are_96_by_72_and_belong_to_cards() -> void:
	var dir := DirAccess.open("res://assets/cards")
	assert_true(dir != null, "assets/cards exists")
	var n := 0
	for f in dir.get_files():
		if not f.ends_with(".png"):
			continue
		var id := f.get_basename()
		assert_true(_get_db().cards.has(id), "%s is not a card" % f)
		assert_eq(CardArt.texture(id).get_size(), CardArt.PICTURE, f)
		n += 1
	assert_eq(n, _get_db().cards.size())


func test_pictures_have_hard_pixels_and_something_drawn() -> void:
	# the generator keeps edges hard: every pixel is clear, solid, or one of the soft contact shadows (alpha 0.5); and a picture is
	# never empty or a single blob
	for id in _get_db().cards.keys():
		var img := CardArt.texture(id).get_image()
		var solid := 0
		for y in img.get_height():
			for x in img.get_width():
				var a := img.get_pixel(x, y).a
				assert_true(a == 0.0 or a >= 0.49, "%s has a blurry pixel at %d,%d" % [id, x, y])
				if a >= 0.9:
					solid += 1
		assert_true(solid > 400, "%s draws almost nothing (%d solid pixels)" % [id, solid])
