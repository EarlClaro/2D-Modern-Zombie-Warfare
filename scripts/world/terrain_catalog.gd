class_name TerrainCatalog
extends RefCounted
## The one list of ground types. Each has a map character (MapDefinition rows), the atlas row it is drawn from
## (the index in ALL, see tools/gen_tiles.gd and IsoTileSet) and the two rules: can enemies and units cross it,
## can a card be placed on it (everything a unit can stand on is buildable except the shallows; rock and deep water block). Looks (variants) never change the rules. `color` is the flat fallback tint.
## The first seven entries keep the rows and characters the older maps and tests use.

const LEGEND: String = ".=#,pxwgyfomsnivalLkcbthezrqu~dRY"
const ALL: Array[Dictionary] = [
	{"id": "grass", "ch": ".", "walkable": true, "buildable": true, "color": Color("56823f")},
	{"id": "road", "ch": "=", "walkable": true, "buildable": true, "color": Color("6e6d6a")},
	{"id": "rock", "ch": "#", "walkable": false, "buildable": false, "color": Color("4c4d55")},
	{"id": "dirt", "ch": ",", "walkable": true, "buildable": true, "color": Color("80613c")},
	{"id": "paved", "ch": "p", "walkable": true, "buildable": true, "color": Color("92928b")},
	{"id": "rubble", "ch": "x", "walkable": true, "buildable": true, "color": Color("5d5a53")},
	{"id": "water", "ch": "w", "walkable": false, "buildable": false, "color": Color("2f6785")},
	{"id": "meadow", "ch": "g", "walkable": true, "buildable": true, "color": Color("4f7e36")},
	{"id": "dry_grass", "ch": "y", "walkable": true, "buildable": true, "color": Color("98914a")},
	{"id": "leaf_litter", "ch": "f", "walkable": true, "buildable": true, "color": Color("6e5430")},
	{"id": "moss", "ch": "o", "walkable": true, "buildable": true, "color": Color("3f6a38")},
	{"id": "mud", "ch": "m", "walkable": true, "buildable": true, "color": Color("5c452d")},
	{"id": "sand", "ch": "s", "walkable": true, "buildable": true, "color": Color("d9c48c")},
	{"id": "snow", "ch": "n", "walkable": true, "buildable": true, "color": Color("dfe9f2")},
	{"id": "ice", "ch": "i", "walkable": true, "buildable": true, "color": Color("b8dcec")},
	{"id": "gravel", "ch": "v", "walkable": true, "buildable": true, "color": Color("857f77")},
	{"id": "asphalt", "ch": "a", "walkable": true, "buildable": true, "color": Color("48484c")},
	{"id": "lane_x", "ch": "l", "walkable": true, "buildable": true, "color": Color("48484c")},
	{"id": "lane_y", "ch": "L", "walkable": true, "buildable": true, "color": Color("48484c")},
	{"id": "cracked_asphalt", "ch": "k", "walkable": true, "buildable": true, "color": Color("45454a")},
	{"id": "cobble", "ch": "c", "walkable": true, "buildable": true, "color": Color("7d7a74")},
	{"id": "brick", "ch": "b", "walkable": true, "buildable": true, "color": Color("8a4f3c")},
	{"id": "concrete_tile", "ch": "t", "walkable": true, "buildable": true, "color": Color("a2a49e")},
	{"id": "hazard", "ch": "h", "walkable": true, "buildable": true, "color": Color("8c8a80")},
	{"id": "steel_deck", "ch": "e", "walkable": true, "buildable": true, "color": Color("57606a")},
	{"id": "wood_planks", "ch": "z", "walkable": true, "buildable": true, "color": Color("86613a")},
	{"id": "farmland", "ch": "r", "walkable": true, "buildable": true, "color": Color("6a4d2c")},
	{"id": "ash", "ch": "q", "walkable": true, "buildable": true, "color": Color("4a4743")},
	{"id": "crater", "ch": "u", "walkable": true, "buildable": true, "color": Color("4d3f30")},
	{"id": "shallows", "ch": "~", "walkable": true, "buildable": false, "color": Color("64a6af")},
	{"id": "hardpan", "ch": "d", "walkable": true, "buildable": true, "color": Color("ae9066")},
	{"id": "runway_x", "ch": "R", "walkable": true, "buildable": true, "color": Color("7a7c7e")},
	{"id": "runway_y", "ch": "Y", "walkable": true, "buildable": true, "color": Color("7a7c7e")},
]

static var _by_char: Dictionary = {}


static func count() -> int:
	return ALL.size()


## Atlas row of the terrain with map character `ch`, or -1 for an unknown character.
static func row_of(ch: String) -> int:
	return _entry_index(ch)


static func has_char(ch: String) -> bool:
	return _entry_index(ch) >= 0


static func is_walkable(ch: String) -> bool:
	var i := _entry_index(ch)
	return i >= 0 and ALL[i]["walkable"]


static func is_buildable(ch: String) -> bool:
	var i := _entry_index(ch)
	return i >= 0 and ALL[i]["buildable"]


## Terrain ids in atlas row order (tools/gen_tiles.gd paints one row per id).
static func ids() -> PackedStringArray:
	var out := PackedStringArray()
	for t in ALL:
		out.append(t["id"])
	return out


static func _entry_index(ch: String) -> int:
	if _by_char.is_empty():
		for i in ALL.size():
			_by_char[ALL[i]["ch"]] = i
	return _by_char.get(ch, -1)
