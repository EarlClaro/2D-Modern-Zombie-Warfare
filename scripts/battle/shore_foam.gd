class_name ShoreFoam
extends Node2D
## Foam along the banks: a thin, lapping white line on the water side of every edge where water meets land.
## The edges are found once from the map; only the brightness animates. Presentation only.

const DASHES: int = 4  # each bank edge is drawn as this many short dashes that breathe independently
const REDRAW_S: float = 0.1

var _edges: Array[Dictionary] = []  # {a, b: screen points, phase}
var _t: float = 0.0
var _since_draw: float = 0.0


## Water cells are those whose map character belongs to a terrain in GroundLook.WATER.
static func water_chars() -> Dictionary:
	var out := {}
	for t in TerrainCatalog.ALL:
		if GroundLook.WATER.has(t["id"]):
			out[t["ch"]] = true
	return out


## Bank edges of `map` as pairs of ground-space points (between two cells: one water, one land).
static func bank_edges(map: MapDefinition) -> Array[PackedVector2Array]:
	var water := water_chars()
	var out: Array[PackedVector2Array] = []
	for y in map.height():
		for x in map.width():
			if not water.has(map.terrain_char(Vector2i(x, y))):
				continue
			for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = Vector2i(x, y) + dir
				if n.x < 0 or n.y < 0 or n.x >= map.width() or n.y >= map.height() or water.has(map.terrain_char(n)):
					continue
				var a: Vector2
				var b: Vector2
				if dir.x != 0:  # a vertical line of the grid at x (+1 on the right side)
					var gx := float(x + (1 if dir.x > 0 else 0))
					a = Vector2(gx, float(y))
					b = Vector2(gx, float(y + 1))
				else:
					var gy := float(y + (1 if dir.y > 0 else 0))
					a = Vector2(float(x), gy)
					b = Vector2(float(x + 1), gy)
				# nudge toward the water side so the foam lies on the water, not on the bank
				var inward := Vector2(-dir) * 0.06
				out.append(PackedVector2Array([a + inward, b + inward]))
	return out


func build(map: MapDefinition) -> void:
	_edges.clear()
	var i := 0
	for e in bank_edges(map):
		_edges.append({"a": IsoProjection.ground_to_screen(e[0]), "b": IsoProjection.ground_to_screen(e[1]), "phase": float(i) * 1.7})
		i += 1
	set_process(not _edges.is_empty())
	queue_redraw()


func edge_count() -> int:
	return _edges.size()


func _process(delta: float) -> void:
	_t += delta
	_since_draw += delta
	if _since_draw >= REDRAW_S:
		_since_draw = 0.0
		queue_redraw()


func _draw() -> void:
	for e in _edges:
		var a: Vector2 = e["a"]
		var b: Vector2 = e["b"]
		for d in DASHES:
			var u0 := float(d) / DASHES + 0.04
			var u1 := float(d + 1) / DASHES - 0.04
			var pulse := 0.5 + 0.5 * sin(_t * 1.6 + float(e["phase"]) + float(d) * 1.9)
			var alpha := LightingConfig.FOAM_ALPHA * (0.25 + 0.75 * pulse)
			draw_line(a.lerp(b, u0), a.lerp(b, u1), Color(0.92, 0.97, 1.0, alpha), LightingConfig.FOAM_WIDTH_PX)
