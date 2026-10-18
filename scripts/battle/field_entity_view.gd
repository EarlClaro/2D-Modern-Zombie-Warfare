class_name FieldEntityView
extends Node2D
## Draws the mines and noise lures that lie on the ground (ground-plane shapes projected through IsoProjection, on the
## decal layer under the units). Presentation only; it reads BattleController.mines / .lures.

const MINE_LIGHT := Color(1.0, 0.25, 0.2)
const LURE := Color(0.42, 0.78, 1.0)
## The mine and the beacon are sprites (tools/sprite_packs/pack_gameplay.gd); the blink and the pulse stay drawn on top.
const MINE_TEX: Texture2D = preload("res://assets/sprites/field_mine/se.png")
const MINE_ORIGIN := Vector2(24.0, 14.0)  # the ground point of the mine in its sprite
const BEACON_TEX: Texture2D = preload("res://assets/sprites/field_beacon/se.png")
const BEACON_ORIGIN := Vector2(18.0, 32.0)

var _battle: BattleController
var _had_content: bool = false


func bind(battle: BattleController) -> void:
	_battle = battle


func _process(_delta: float) -> void:
	if _battle == null:
		return
	var has := _battle.mines.count() > 0 or not _battle.lures.is_empty()
	if has or _had_content:
		queue_redraw()
	_had_content = has


func _draw() -> void:
	if _battle == null:
		return
	var blink := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 5.0)
	for m in _battle.mines.mines:
		var s := IsoProjection.ground_to_screen(m.pos)
		draw_texture(MINE_TEX, (s - MINE_ORIGIN).round())
		draw_circle(s + Vector2(0.0, -6.0), 2.0, Color(MINE_LIGHT.r, MINE_LIGHT.g, MINE_LIGHT.b, 0.35 + 0.55 * blink))
	for l in _battle.lures.lures:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 4.0)
		_ring(l.pos, l.radius, 0.04 + 0.03 * pulse, 0.35 + 0.25 * pulse)
		_ring(l.pos, l.radius * (1.0 - fposmod(Time.get_ticks_msec() / 1500.0, 1.0)), 0.0, 0.5)  # a ring that shrinks toward the beacon
		var base := IsoProjection.ground_to_screen(l.pos)
		draw_texture(BEACON_TEX, (base - BEACON_ORIGIN).round())
		draw_circle(base + Vector2(-5.0, -34.0), 3.0 + 3.0 * pulse, Color(LURE.r, LURE.g, LURE.b, 0.35 + 0.35 * pulse))  # pulsing glow at the aerial tip


func _ring(ground_center: Vector2, radius: float, fill_alpha: float, edge_alpha: float) -> void:
	if radius <= 0.01:
		return
	var poly := IsoProjection.ground_circle_polygon(ground_center, radius, 64)
	if fill_alpha > 0.0:
		draw_colored_polygon(poly, Color(LURE.r, LURE.g, LURE.b, fill_alpha))
	poly.append(poly[0])
	draw_polyline(poly, Color(LURE.r, LURE.g, LURE.b, edge_alpha), 2.0)
