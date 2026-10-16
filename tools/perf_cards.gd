extends SceneTree
## Dev tool (not a test). Windowed FPS of the real card mission (`m2_card_defense`) with a scripted player who keeps
## deploying units, calling artillery and flying the helicopter into the horde (CP is topped up so every scheduled card
## is played: a worst case for effects). Reports average FPS, lows, spikes, and the peak enemy / projectile / unit counts.
## Run (NOT headless): godot --path . --resolution 1920x1080 --audio-driver Dummy --script tools/perf_cards.gd

const SAMPLE_S := 120.0

var _b: BattleController
var _db: ContentDb
var _t: float = 0.0
var _boot: int = 0
var _frames: PackedFloat64Array = PackedFloat64Array()
var _m_process: float = 0.0
var _m_physics: float = 0.0
var _m_draws: float = 0.0
var _m_nodes: float = 0.0
var _peak_enemies: int = 0
var _peak_units: int = 0
var _peak_shells: int = 0
var _next_play: float = 3.0
var _step: int = 0
var _worst_sec_fps: float = 1.0e9
var _sec_frames: int = 0
var _sec_t: float = 0.0
var _plays: Dictionary = {}


func _process(delta: float) -> bool:
	if _b == null:
		_db = ContentDb.load_from()
		_b = load("res://scenes/battle/battle.tscn").instantiate()
		root.add_child(_b)
		Engine.max_fps = 0
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		print("ENV | window=%s renderer=%s adapter=%s" % [str(root.size), RenderingServer.get_current_rendering_method(), RenderingServer.get_video_adapter_name()])
		return false
	_boot += 1
	if _boot == 5:
		_b.setup(_db, _db.mission("m2_card_defense"), 1)
		_b.auto_step = true
		_t = 0.0
	if _boot <= 5:
		return false
	_t += delta
	_frames.append(delta)
	_sec_frames += 1
	_sec_t += delta
	if _sec_t >= 1.0:
		_worst_sec_fps = minf(_worst_sec_fps, float(_sec_frames) / _sec_t)
		_sec_frames = 0
		_sec_t = 0.0
	_m_process += Performance.get_monitor(Performance.TIME_PROCESS)
	_m_physics += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
	_m_draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	_m_nodes += Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	_peak_enemies = maxi(_peak_enemies, _b.enemy_count())
	_peak_units = maxi(_peak_units, _b.units.size())
	_peak_shells = maxi(_peak_shells, _b.projectiles.count())
	if _b.elapsed >= _next_play and not _b.is_ended():
		_play_next()
		_next_play += 4.0
	if _b.is_ended() or _t >= SAMPLE_S + 5.0:
		_report()
		quit()
	return false


func _play_next() -> void:
	_b.points.cp = 10.0
	var core := IsoProjection.cell_center(_b.mission.core_cell)
	var order := ["rifle_squad", "gatling_gun", "tank", "artillery_strike", "helicopter_support", "gatling_gun", "artillery_strike", "rifle_squad", "helicopter_support", "tank"]
	var id: String = order[_step % order.size()]
	_step += 1
	_b.deck.hand = [id] as Array[String]
	_b.deck.lockouts.clear()
	var cell := Vector2i(-1, -1)
	if id == "artillery_strike" or id == "helicopter_support":
		var best := 0
		var best_cell := IsoProjection.cell_of(core + Vector2(6, -6))
		for e in _b.enemies:
			var n := 0
			for o in _b.enemies:
				if e.ground_pos.distance_to(o.ground_pos) <= 3.0:
					n += 1
			if n > best:
				best = n
				best_cell = IsoProjection.cell_of(e.ground_pos)
		cell = best_cell
	else:
		var d := 4.0 + float(_step % 5)
		cell = IsoProjection.cell_of(core + Vector2(1, -1).normalized() * d + Vector2(float(_step % 3) - 1.0, 0.0))
	var res := _b.play_card(0, cell)
	if res.ok:
		_plays[id] = int(_plays.get(id, 0)) + 1


func _report() -> void:
	var n := _frames.size()
	var total := 0.0
	for f in _frames:
		total += f
	var sorted := _frames.duplicate()
	sorted.sort()
	var over_20 := 0
	for f in _frames:
		if f > 0.020:
			over_20 += 1
	print("RESULT | m2_card_defense, scripted player, %.0f s simulated, ended=%s" % [_b.elapsed, str(_b.is_ended())])
	print("  frames=%d  avg FPS=%.1f  1%% low=%.1f  0.1%% low=%.1f  worst frame=%.1f ms  worst 1-second average=%.1f FPS  frames>20ms=%d (%.1f%%)" % [
		n, n / total, 1.0 / sorted[int(n * 0.99)], 1.0 / sorted[int(n * 0.999)], sorted[-1] * 1000.0, _worst_sec_fps, over_20, 100.0 * over_20 / n])
	print("  monitors (avg): process=%.2f ms physics=%.2f ms draw calls=%.0f nodes=%.0f | peaks: enemies alive=%d units=%d shells in flight=%d" % [
		_m_process / n * 1000.0, _m_physics / n * 1000.0, _m_draws / n, _m_nodes / n, _peak_enemies, _peak_units, _peak_shells])
	print("  plays: %s | kills=%d of %d spawned, units lost=%d" % [str(_plays), _b.stats["kills"], _b.stats["spawned"], _b.stats["units_lost"]])
