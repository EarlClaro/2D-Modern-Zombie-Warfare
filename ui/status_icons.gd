class_name StatusIcons
extends RefCounted
## The small pixel icons for the orders and doctrines in force (docs/specs/art-more.md, N.3): 12 x 12 art pixels in
## `assets/ui/icons/<effect id>.png`, made by tools/gen_icons.gd and drawn at 2x. Presentation only.

static var _cache: Dictionary = {}  # id -> Texture2D or null


## The icon of a state effect (or any id that has a file), or null when there is none.
static func texture(id: String) -> Texture2D:
	if not _cache.has(id):
		var path := "res://assets/ui/icons/%s.png" % id
		_cache[id] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _cache[id]
