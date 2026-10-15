class_name StrikeTelegraph
extends Node2D
## The danger circle of a called-in strike, drawn on the ground (ground circle projected through IsoProjection,
## so the on-screen ellipse is the true zone). While the warning runs a ring shrinks toward the centre as a
## countdown; once shells are landing the zone stays lit until the last one hits. Presentation only.

const DANGER := Color(1.0, 0.3, 0.25)

var _battle: BattleController
var _had_strikes: bool = false


func bind(battle: BattleController) -> void:
	_battle = battle


func _process(_delta: float) -> void:
	if _battle == null:
		return
	var has := not _battle.strikes.is_empty()
	if has or _had_strikes:
		queue_redraw()
	_had_strikes = has


func _draw() -> void:
	if _battle == null:
		return
	for s in _battle.strikes:
		var age := s.duration - s.time_left
		var warning_left := maxf(s.warning_s - age, 0.0)
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * (10.0 if warning_left > 0.0 else 4.0))
		_ring(s.center, s.reach, 0.10 + 0.05 * pulse, 0.55 + 0.35 * pulse, 3.0)
		_ring(s.center, s.scatter, 0.0, 0.3, 1.5)
		if warning_left > 0.0 and s.warning_s > 0.0:
			var frac := warning_left / s.warning_s
			_ring(s.center, s.reach * frac, 0.0, 0.8, 2.0)


func _ring(ground_center: Vector2, radius: float, fill_alpha: float, edge_alpha: float, width: float) -> void:
	if radius <= 0.01:
		return
	var poly := IsoProjection.ground_circle_polygon(ground_center, radius, 64)
	if fill_alpha > 0.0:
		draw_colored_polygon(poly, Color(DANGER.r, DANGER.g, DANGER.b, fill_alpha))
	poly.append(poly[0])
	draw_polyline(poly, Color(DANGER.r, DANGER.g, DANGER.b, edge_alpha), width)
