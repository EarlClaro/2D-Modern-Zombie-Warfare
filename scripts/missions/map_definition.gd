class_name MapDefinition
extends ContentDefinition
## Terrain grid as ASCII rows. Cell (x, y) is rows[y][x]; ground +X is screen down-right, +Y down-left.
## Legend: the map characters of TerrainCatalog (the one list of ground types and their rules), e.g. '.' grass
## (walkable, buildable), ',' dirt, 'p' paved, '=' road (walkable only), 'x' rubble, '#' rock and 'w' water (blocked).

const GRASS: String = "."
const ROAD: String = "="
const ROCK: String = "#"
const DIRT: String = ","
const PAVED: String = "p"
const RUBBLE: String = "x"
const WATER: String = "w"
const LEGEND: String = TerrainCatalog.LEGEND
const MAX_SIZE: int = 128

@export var rows: PackedStringArray = PackedStringArray()
## Decorations, one line each: `scenery_id x y [facing]` (see SceneryPlacement). Checked against the scenery
## definitions by ContentDb (footprints in bounds, no overlaps, nothing on an enemy path).
@export var scenery: PackedStringArray = PackedStringArray()


func kind() -> String:
	return "map"


func width() -> int:
	return rows[0].length() if not rows.is_empty() else 0


func height() -> int:
	return rows.size()


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.y < rows.size() and cell.x < rows[cell.y].length()


## The parsed scenery lines (malformed lines are skipped here and reported by validate()).
func placements() -> Array[SceneryPlacement]:
	var out: Array[SceneryPlacement] = []
	for line in scenery:
		var p := SceneryPlacement.parse(line)
		if p != null:
			out.append(p)
	return out


## The terrain character at `cell`, or "" outside the map.
func terrain_char(cell: Vector2i) -> String:
	return rows[cell.y][cell.x] if in_bounds(cell) else ""


static func char_is_walkable(ch: String) -> bool:
	return TerrainCatalog.is_walkable(ch)


static func char_is_buildable(ch: String) -> bool:
	return TerrainCatalog.is_buildable(ch)


func is_walkable(cell: Vector2i) -> bool:
	return char_is_walkable(terrain_char(cell))


func is_buildable(cell: Vector2i) -> bool:
	return char_is_buildable(terrain_char(cell))


## True if every sampled point of the straight ground-plane segment a→b lies on a walkable cell.
## Used to validate waypoint paths, since enemies walk straight lines (no pathfinding until M3).
func segment_is_walkable(a: Vector2, b: Vector2, step: float = 0.2) -> bool:
	var samples := maxi(1, ceili(a.distance_to(b) / step))
	for i in samples + 1:
		var p := a.lerp(b, float(i) / samples)
		if not is_walkable(Vector2i(floori(p.x), floori(p.y))):
			return false
	return true


func validate() -> PackedStringArray:
	var errs := super.validate()
	if rows.is_empty():
		errs.append(_err("rows is empty"))
		return errs
	var w := rows[0].length()
	if w == 0:
		errs.append(_err("row 0 is empty"))
	if w > MAX_SIZE or rows.size() > MAX_SIZE:
		errs.append(_err("size %dx%d exceeds the maximum %d" % [w, rows.size(), MAX_SIZE]))
	for i in scenery.size():
		var p := SceneryPlacement.parse(scenery[i])
		if p == null:
			errs.append(_err("scenery line %d is malformed: '%s' (expected 'id x y [facing]')" % [i, scenery[i]]))
		elif not in_bounds(p.cell):
			errs.append(_err("scenery '%s' at (%d, %d) is outside the map" % [p.scenery_id, p.cell.x, p.cell.y]))
	for y in rows.size():
		if rows[y].length() != w:
			errs.append(_err("row %d has length %d, expected %d (rows must be rectangular)" % [y, rows[y].length(), w]))
		for x in rows[y].length():
			var ch := rows[y][x]
			if not LEGEND.contains(ch):
				errs.append(_err("unknown terrain character '%s' at (%d, %d)" % [ch, x, y]))
	return errs
