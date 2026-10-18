extends TestCase
## The picture on a card face (docs/specs/card-loop.md "Card faces"): every card has a picture file or an emblem, and every
## picture file belongs to a card.

var _db: ContentDb


func _get_db() -> ContentDb:
	if _db == null:
		_db = ContentDb.load_from()
	return _db


func test_every_card_has_a_picture_or_an_emblem() -> void:
	for id in _get_db().cards.keys():
		var has_file := CardArt.texture(id) != null
		var has_emblem := CardArt.EMBLEMS.has(id)
		assert_true(has_file != has_emblem, "%s needs exactly one of: a picture file, an emblem" % id)


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
	assert_true(n >= 20)


func test_emblem_cards_are_real_cards() -> void:
	for id in CardArt.EMBLEMS:
		assert_true(_get_db().cards.has(id), "%s is not a card" % id)
