class_name ProjectileView
extends Node2D
## Draws every shell in flight from ProjectileSystem in a single node (no node per shell): a ground shadow
## that follows the ground position, and the shell itself lifted by its altitude with a short trail.
## Presentation only.

const TRAIL_STEPS: int = 4
const TRAIL_SPAN: float = 0.07  # fraction of the flight covered by the trail

var _battle: BattleController
var _had_shells: bool = false


func bind(battle: BattleController) -> void:
	_battle = battle


func _process(_delta: float) -> void:
	if _battle == null:
		return
	var has := _battle.projectiles.count() > 0
	if has or _had_shells:
		queue_redraw()
	_had_shells = has


func _draw() -> void:
	if _battle == null:
		return
	var sys := _battle.projectiles
	for i in sys.count():
		if not sys.is_flying(i):
			continue
		var g := sys.ground_pos_of(i)
		draw_colored_polygon(IsoProjection.ground_circle_polygon(g, 0.22, 16), Color(0, 0, 0, 0.35))
		var s := sys.progress_of(i)
		var prev := IsoProjection.ground_to_screen_z(g, sys.altitude_of(i))
		for k in range(1, TRAIL_STEPS + 1):
			var sk := maxf(s - TRAIL_SPAN * k / TRAIL_STEPS, 0.0)
			var pt := IsoProjection.ground_to_screen_z(sys.ground_pos_at(i, sk), sys.altitude_at(i, sk))
			draw_line(prev, pt, Color(1.0, 0.8, 0.4, 0.7 * (1.0 - float(k) / (TRAIL_STEPS + 1))), 2.5)
			prev = pt
		var head := IsoProjection.ground_to_screen_z(g, sys.altitude_of(i))
		draw_circle(head, 4.0, Color(0.2, 0.18, 0.15))
		draw_circle(head, 2.2, Color(1.0, 0.75, 0.3))
