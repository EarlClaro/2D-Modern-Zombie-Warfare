class_name CardArt
extends RefCounted
## The picture on a card face (docs/specs/card-loop.md "Card faces", docs/specs/art-polish.md): a 96x72 image from
## `assets/cards/<card id>.png`, made by tools/gen_card_pictures.gd (unit sprites, strike scenes and hand-drawn pixel pictures).
## Every card has one. Presentation only.

const PICTURE := Vector2(96, 72)
const BACK_SIZE := Vector2(66, 94)

static var _cache: Dictionary = {}  # card id -> Texture2D or null


## The picture file of a card, or null when it has none.
static func texture(card_id: String) -> Texture2D:
	if not _cache.has(card_id):
		var path := "res://assets/cards/%s.png" % card_id
		_cache[card_id] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _cache[card_id]


## The back of a card (assets/cards/_back.png, 66 x 94 art pixels: shown at 2x it is a hand card), or null if it is missing.
static func back() -> Texture2D:
	if not _cache.has("_back"):
		var path := "res://assets/cards/_back.png"
		_cache["_back"] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _cache["_back"]


## Draws the picture centred in `area`. `tint` (the card's kind colour) is kept for callers; the pictures need none.
static func draw_in(ci: CanvasItem, card_id: String, area: Rect2, _tint: Color) -> void:
	var tex := texture(card_id)
	if tex != null:
		ci.draw_texture_rect(tex, Rect2((area.get_center() - PICTURE * 0.5).round(), tex.get_size()), false)
