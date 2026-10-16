class_name SceneryPlacement
extends RefCounted
## One decoration on a map, parsed from a map line `id x y [facing]` (facing is one of e se s sw w nw n ne;
## default se). `facing` only picks which art is drawn (and mirrors single-texture art for sw, w, nw).

var scenery_id: String = ""
var cell: Vector2i = Vector2i.ZERO
var facing: int = IsoProjection.Facing.SE


## Parses one line; returns null when it is malformed (id missing, coordinates not integers, unknown facing).
static func parse(line: String) -> SceneryPlacement:
	var parts := line.strip_edges().split(" ", false)
	if parts.size() < 3 or parts.size() > 4:
		return null
	if not (parts[1].is_valid_int() and parts[2].is_valid_int()):
		return null
	var p := SceneryPlacement.new()
	p.scenery_id = parts[0]
	p.cell = Vector2i(int(parts[1]), int(parts[2]))
	if parts.size() == 4:
		var f := IsoProjection.Facing.keys().find(parts[3].to_upper())
		if f < 0:
			return null
		p.facing = f
	return p


func to_line() -> String:
	return "%s %d %d %s" % [scenery_id, cell.x, cell.y, IsoProjection.facing_name(facing).to_lower()]
