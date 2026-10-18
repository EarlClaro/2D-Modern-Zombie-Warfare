class_name GroundMark
extends Node2D
## A mark that stays on the ground after a fight (docs/specs/art-more.md, N.1): a crater where a big blast landed, a blood stain where
## a zombie died. A pixel picture from assets/fx/marks/ drawn flat on the ground plane under the units. Craters stay for the battle;
## blood fades slowly to a faint stain. Each kind is capped per layer, the oldest going first, so a long fight stays cheap.
## Presentation only: it never touches the simulation.

const CRATER := "crater"
const BLOOD := "blood"
const CAPS: Dictionary = {"crater": 60, "blood": 140}
const VARIANTS := 3
const FADE_IN_S: float = 0.2
const BLOOD_FADE_S: float = 80.0
const BLOOD_FLOOR: float = 0.4
const BLOOD_SHARE: float = 0.65  # the share of deaths that leave a stain (picked by the position, not by chance)
const CRATER_LARGE_RADIUS: float = 4.0
const CRATER_MEDIUM_RADIUS: float = 2.2

static var _textures: Dictionary = {}  # "crater_1" -> Texture2D or null

var _tex: Texture2D


## The picture `<kind>_<variant>`, or null when its file is missing.
static func texture_of(kind: String, variant: int) -> Texture2D:
	var key := "%s_%d" % [kind, variant]
	if not _textures.has(key):
		var path := "res://assets/fx/marks/%s.png" % key
		_textures[key] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _textures[key]


## A stable 0..1 number for a ground position: the same place always gets the same variant and the same decision.
static func unit_hash(p: Vector2) -> float:
	return fposmod(sin(p.x * 12.9898 + p.y * 78.233) * 43758.5453, 1.0)


## Which crater picture a blast of this radius (tiles) leaves.
static func crater_variant(radius: float) -> int:
	if radius >= CRATER_LARGE_RADIUS:
		return 2
	return 1 if radius >= CRATER_MEDIUM_RADIUS else 0


## True when the zombie that died at `ground_pos` leaves a stain.
static func leaves_blood(ground_pos: Vector2) -> bool:
	return unit_hash(ground_pos * 1.37) < BLOOD_SHARE


## Puts a mark on `layer` (the Decals layer) at `ground_pos` (tiles). Returns null when the picture is missing.
static func spawn(layer: Node, ground_pos: Vector2, kind: String, variant: int) -> GroundMark:
	var tex := texture_of(kind, variant)
	if tex == null:
		return null
	var m := GroundMark.new()
	m._tex = tex
	m.position = IsoProjection.ground_to_screen(ground_pos)
	m.modulate.a = 0.0
	layer.add_child(m)
	var tw := m.create_tween()
	tw.tween_property(m, "modulate:a", 1.0, FADE_IN_S)
	if kind == BLOOD:
		tw.tween_property(m, "modulate:a", BLOOD_FLOOR, BLOOD_FADE_S)
	_remember(layer, kind, m)
	return m


static func _remember(layer: Node, kind: String, m: GroundMark) -> void:
	var key := "marks_" + kind
	var list: Array = layer.get_meta(key, [])
	list.append(m)
	while list.size() > int(CAPS[kind]):
		var old: Variant = list.pop_front()
		if is_instance_valid(old):
			(old as Node).queue_free()
	layer.set_meta(key, list)


## Forgets the marks of a layer (the nodes themselves are freed by whoever clears the layer).
static func forget(layer: Node) -> void:
	for kind in CAPS.keys():
		layer.set_meta("marks_" + kind, [])


func _draw() -> void:
	draw_texture(_tex, -_tex.get_size() * 0.5)
