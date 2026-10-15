class_name ScorchMark
extends Node2D
## Burnt ground left under a wreck. Drawn as irregular blotches on the ground plane (true iso ellipses),
## it fades in when the explosion goes off and then stays until the battle restarts. Presentation only.

const FADE_IN_S: float = 0.5
const BLOTS: int = 6
const COLOR := Color(0.04, 0.035, 0.03, 0.32)

var delay_s: float = 0.0
var _age: float = 0.0
var _blots: PackedVector3Array = PackedVector3Array()  # (ground offset x, y, radius) in tiles


## `ground_pos` is the wreck's ground position (tiles); the layer should sit under the shadows.
static func spawn(parent: Node, ground_pos: Vector2, radius_tiles: float, delay: float = 0.0) -> ScorchMark:
	var m := ScorchMark.new()
	m.position = IsoProjection.ground_to_screen(ground_pos)
	m.delay_s = delay
	m.modulate.a = 0.0
	# Deterministic shape from the position, so the same wreck always leaves the same mark.
	var seed_a := ground_pos.x * 12.9898 + ground_pos.y * 78.233
	m._blots.append(Vector3(0.0, 0.0, radius_tiles))
	for i in BLOTS:
		var a := fposmod(sin(seed_a + i * 3.7) * 43758.5453, 1.0) * TAU
		var d := radius_tiles * (0.35 + 0.5 * fposmod(sin(seed_a * 1.7 + i * 9.1) * 24634.6345, 1.0))
		var r := radius_tiles * (0.28 + 0.3 * fposmod(sin(seed_a * 2.3 + i * 5.3) * 31415.9265, 1.0))
		m._blots.append(Vector3(cos(a) * d, sin(a) * d, r))
	parent.add_child(m)
	return m


func _process(delta: float) -> void:
	_age += delta
	var f := clampf((_age - delay_s) / FADE_IN_S, 0.0, 1.0)
	modulate.a = f
	if f >= 1.0:
		set_process(false)  # permanent from here on: no more per-frame work


func _draw() -> void:
	for b in _blots:
		draw_colored_polygon(IsoProjection.ground_circle_polygon(Vector2(b.x, b.y), b.z, 18), COLOR)
	# Darker core where the wreck sits.
	draw_colored_polygon(IsoProjection.ground_circle_polygon(Vector2.ZERO, _blots[0].z * 0.55, 18), Color(0.02, 0.02, 0.02, 0.3))
