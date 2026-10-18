class_name CardArt
extends RefCounted
## The picture on a card face (docs/specs/card-loop.md "Card faces"): a 96x72 image from `assets/cards/<card id>.png`
## (made by tools/gen_card_pictures.gd from art the game already has), or, for the few cards that have no art anywhere
## (orders, doctrines, mines, lures, supply drops, the barracks and the combat drone), a small emblem drawn in code.
## Presentation only.

const PICTURE := Vector2(96, 72)

## Cards that have no picture file and get an emblem drawn in code instead.
const EMBLEMS: Array[String] = ["barracks", "combat_drones", "fortify", "hollow_points", "minefield", "noise_lure", "quick_draw", "supply_drop"]

static var _cache: Dictionary = {}  # card id -> Texture2D or null


## The picture file of a card, or null when it has none.
static func texture(card_id: String) -> Texture2D:
	if not _cache.has(card_id):
		var path := "res://assets/cards/%s.png" % card_id
		_cache[card_id] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _cache[card_id]


## Draws the picture (or the emblem) centred in `area`. `tint` is the card's kind colour, used by the emblems only.
static func draw_in(ci: CanvasItem, card_id: String, area: Rect2, tint: Color) -> void:
	var tex := texture(card_id)
	var origin := area.get_center() - PICTURE * 0.5
	if tex != null:
		ci.draw_texture_rect(tex, Rect2(origin.round(), tex.get_size()), false)
		return
	match card_id:
		"barracks": _barracks(ci, origin)
		"combat_drones": _drones(ci, origin)
		"fortify": _fortify(ci, origin)
		"hollow_points": _bullets(ci, origin)
		"minefield": _mines(ci, origin)
		"noise_lure": _lure(ci, origin)
		"quick_draw": _quick_draw(ci, origin)
		"supply_drop": _supply_drop(ci, origin)
		_:
			pass


static func _poly(ci: CanvasItem, o: Vector2, pts: Array, col: Color) -> void:
	var v := PackedVector2Array()
	for p in pts:
		v.append(o + Vector2(p[0], p[1]))
	ci.draw_colored_polygon(v, col)


static func _ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color) -> void:
	var v := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		v.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	ci.draw_colored_polygon(v, col)


static func _barracks(ci: CanvasItem, o: Vector2) -> void:
	ci.draw_rect(Rect2(o + Vector2(20, 34), Vector2(56, 30)), Color("d6bb82"))
	ci.draw_rect(Rect2(o + Vector2(66, 34), Vector2(10, 30)), Color("a68f58"))
	_poly(ci, o, [[12, 36], [30, 14], [66, 14], [84, 36]], Color("566330"))
	_poly(ci, o, [[30, 14], [66, 14], [72, 22], [24, 22]], Color("7f8c4b"))
	ci.draw_rect(Rect2(o + Vector2(42, 42), Vector2(13, 22)), Color("8d6038"))
	ci.draw_rect(Rect2(o + Vector2(26, 42), Vector2(10, 8)), Color("4f8da4"))
	ci.draw_rect(Rect2(o + Vector2(61, 42), Vector2(10, 8)), Color("4f8da4"))
	ci.draw_line(o + Vector2(48, 14), o + Vector2(48, 2), Color("47524f"), 2.0)
	ci.draw_rect(Rect2(o + Vector2(49, 2), Vector2(12, 8)), Color("ee6f58"))


static func _drones(ci: CanvasItem, o: Vector2) -> void:
	var arms := [Vector2(20, 14), Vector2(76, 14), Vector2(20, 58), Vector2(76, 58)]
	for a in arms:
		ci.draw_line(o + Vector2(48, 36), o + a, Color("6b7878"), 3.0)
		_ellipse(ci, o + a, 15.0, 7.0, Color("c3cbc8", 0.55))
		_ellipse(ci, o + a, 5.0, 2.5, Color("47524f"))
	_ellipse(ci, o + Vector2(48, 36), 11.0, 7.0, Color("47524f"))
	_ellipse(ci, o + Vector2(46, 34), 7.0, 4.0, Color("97a3a2"))
	ci.draw_circle(o + Vector2(48, 38), 2.0, Color("ee6f58"))


static func _fortify(ci: CanvasItem, o: Vector2) -> void:
	_poly(ci, o, [[48, 6], [78, 14], [75, 42], [48, 66], [21, 42], [18, 14]], Color("2a4580"))
	_poly(ci, o, [[48, 11], [72, 18], [70, 40], [48, 59], [26, 40], [24, 18]], Color("6293d6"))
	for dy in [0.0, 14.0]:
		ci.draw_polyline(PackedVector2Array([o + Vector2(32, 34 + dy), o + Vector2(48, 22 + dy), o + Vector2(64, 34 + dy)]), Color("fbf4e0") if dy == 0.0 else Color("e9ecea"), 5.0)


static func _bullets(ci: CanvasItem, o: Vector2) -> void:
	for x in [24.0, 48.0, 72.0]:
		ci.draw_rect(Rect2(o + Vector2(x - 7, 38), Vector2(14, 28)), Color("c98f2b"))
		ci.draw_rect(Rect2(o + Vector2(x - 7, 38), Vector2(5, 28)), Color("f5cc4e"))
		_poly(ci, o, [[x - 7, 38], [x - 7, 24], [x - 3, 14], [x + 3, 14], [x + 7, 24], [x + 7, 38]], Color("c75b2b"))
		_poly(ci, o, [[x - 7, 38], [x - 7, 24], [x - 3, 14], [x - 2, 14], [x - 2, 38]], Color("f28d3b"))
		ci.draw_rect(Rect2(o + Vector2(x - 3, 14), Vector2(6, 8)), Color("2b2f33"))


static func _mines(ci: CanvasItem, o: Vector2) -> void:
	for c in [Vector2(28, 22), Vector2(66, 32), Vector2(36, 52)]:
		_ellipse(ci, o + c + Vector2(0, 3), 17.0, 8.0, Color("47524f"))
		_ellipse(ci, o + c, 17.0, 8.0, Color("97a3a2"))
		_ellipse(ci, o + c + Vector2(0, -1), 10.0, 4.5, Color("6b7878"))
		ci.draw_circle(o + c + Vector2(0, -1), 2.0, Color("ee6f58"))


static func _lure(ci: CanvasItem, o: Vector2) -> void:
	ci.draw_rect(Rect2(o + Vector2(36, 34), Vector2(24, 28)), Color("47524f"))
	ci.draw_rect(Rect2(o + Vector2(36, 34), Vector2(6, 28)), Color("6b7878"))
	ci.draw_circle(o + Vector2(48, 50), 7.0, Color("2b2f33"))
	ci.draw_circle(o + Vector2(48, 50), 3.0, Color("97a3a2"))
	ci.draw_line(o + Vector2(48, 34), o + Vector2(48, 22), Color("6b7878"), 2.0)
	ci.draw_circle(o + Vector2(48, 20), 3.0, Color("ee6f58"))
	for r in [12.0, 22.0, 32.0]:
		ci.draw_arc(o + Vector2(48, 20), r, PI * 1.15, PI * 1.85, 16, Color("f28d3b"), 3.0)


static func _quick_draw(ci: CanvasItem, o: Vector2) -> void:
	_poly(ci, o, [[14, 18], [34, 10], [48, 56], [28, 64]], Color("c3cbc8"))
	_poly(ci, o, [[62, 10], [82, 18], [68, 64], [48, 56]], Color("fbf4e0"))
	_poly(ci, o, [[30, 8], [66, 8], [66, 62], [30, 62]], Color("e9ecea"))
	_poly(ci, o, [[52, 10], [40, 36], [50, 36], [42, 62], [62, 30], [51, 30], [58, 10]], Color("f5cc4e"))
	_poly(ci, o, [[52, 10], [58, 10], [51, 30], [45, 30]], Color("f28d3b"))


static func _supply_drop(ci: CanvasItem, o: Vector2) -> void:
	_ellipse(ci, o + Vector2(48, 24), 36.0, 20.0, Color("bf403b"))
	_ellipse(ci, o + Vector2(48, 24), 24.0, 20.0, Color("fbf4e0"))
	_ellipse(ci, o + Vector2(48, 24), 10.0, 20.0, Color("ee6f58"))
	ci.draw_rect(Rect2(o + Vector2(0, 26), Vector2(96, 20)), Color(0, 0, 0, 0))
	for x in [14.0, 48.0, 82.0]:
		ci.draw_line(o + Vector2(x, 26), o + Vector2(48, 50), Color("c3cbc8"), 1.5)
	ci.draw_rect(Rect2(o + Vector2(34, 48), Vector2(28, 20)), Color("d9a96a"))
	ci.draw_rect(Rect2(o + Vector2(34, 48), Vector2(28, 5)), Color("b98550"))
	ci.draw_rect(Rect2(o + Vector2(34, 48), Vector2(28, 20)), Color("8d6038"), false, 2.0)
	ci.draw_line(o + Vector2(34, 48), o + Vector2(62, 68), Color("8d6038"), 2.0)
