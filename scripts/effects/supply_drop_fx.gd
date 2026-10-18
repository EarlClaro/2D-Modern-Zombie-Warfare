class_name SupplyDropFx
extends Node2D
## The Supply Drop card seen on the field (docs/specs/art-more.md, N.4): a crate on a red and white parachute floats down onto the ground
## near the core, lands in a puff of dust, the canopy settles beside it, and after a few seconds the whole thing fades away. Pictures from
## assets/fx/ (tools/gen_supply_fx.gd). Presentation only: the card's effect (Command Points, reloads) happens at once, as before.

const FALL_S: float = 1.9
const LANDED_S: float = 2.6
const FADE_S: float = 0.7
const START_HEIGHT_PX: float = 380.0
const SWAY_PX: float = 14.0
const CHUTE_GAP_PX: float = 2.0  # the canopy's lines end on the lid of the crate

var _age: float = 0.0
var _chute: Texture2D
var _chute_down: Texture2D
var _crate: Texture2D
var _puffed: bool = false


## `ground_pos` is where the crate comes down (tiles). `parent` is the effects layer.
static func spawn(parent: Node, ground_pos: Vector2) -> SupplyDropFx:
	var f := SupplyDropFx.new()
	f._chute = load("res://assets/fx/chute.png") as Texture2D
	f._chute_down = load("res://assets/fx/chute_down.png") as Texture2D
	f._crate = load("res://assets/fx/crate.png") as Texture2D
	f.position = IsoProjection.ground_to_screen(ground_pos)
	parent.add_child(f)
	return f


func total_s() -> float:
	return FALL_S + LANDED_S + FADE_S


## How high the crate is above the ground at `age` seconds, in px: a slow, slowing descent.
static func height_at(age: float) -> float:
	var t := clampf(age / FALL_S, 0.0, 1.0)
	return START_HEIGHT_PX * (1.0 - t) * (1.0 - t * 0.25)


func _process(delta: float) -> void:
	_age += delta
	if _age >= FALL_S and not _puffed:
		_puffed = true
		DeathPuff.spawn(get_parent(), position)  # the dust of the landing
	if _age >= total_s():
		queue_free()
		return
	modulate.a = clampf((total_s() - _age) / FADE_S, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	if _crate == null:
		return
	var h := height_at(_age)
	var sway := sin(_age * 2.6) * SWAY_PX * clampf(h / START_HEIGHT_PX, 0.0, 1.0)
	var base := Vector2(sway, -h)
	# the crate's shadow on the ground, small when high
	var shade := 1.0 - clampf(h / START_HEIGHT_PX, 0.0, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 11.0 * (0.4 + 0.6 * shade), Color(0, 0, 0, 0.28 * (0.3 + 0.7 * shade)))
	draw_set_transform(Vector2.ZERO)
	var crate_pos := (base - Vector2(_crate.get_width() * 0.5, _crate.get_height())).round()
	draw_texture(_crate, crate_pos)
	if _age < FALL_S and _chute != null:
		draw_texture(_chute, (base + Vector2(-_chute.get_width() * 0.5, -_crate.get_height() - _chute.get_height() + CHUTE_GAP_PX)).round())
	elif _chute_down != null:
		draw_texture(_chute_down, Vector2(-_chute_down.get_width() * 0.5 - 18.0, -_chute_down.get_height() + 2.0).round())
