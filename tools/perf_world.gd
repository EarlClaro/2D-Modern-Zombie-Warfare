extends SceneTree
## Dev tool (not a test). Windowed FPS of the big map: ~290 pieces of scenery, night, rain, glows, and a horde.
## Prints average FPS, 1% low, worst frame and draw calls for two camera views. Results vary run to run on a
## laptop (power/thermal state), so repeat it and record ranges.
## Run (NOT headless): godot --path . --resolution 1920x1080 --audio-driver Dummy --script tools/perf_world.gd -- [--enemies=250] [--mission=x3_storm_night]

const WARMUP_S := 5.0
const SAMPLE_S := 10.0

var _b: BattleController
var _enemies: int = 250
var _mission_id: String = "x3_storm_night"
var _views := [
	{"label": "base, zoom 1.5", "at": Vector2(12, 38), "zoom": 1.5},
	{"label": "whole map, zoom 0.5", "at": Vector2(32, 24), "zoom": 0.5},
]
var _view: int = -1
var _t: float = 0.0
var _frames: PackedFloat64Array = PackedFloat64Array()
var _draws: float = 0.0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--enemies="):
			_enemies = int(a.substr(10))
		elif a.begins_with("--mission="):
			_mission_id = a.substr(10)
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)


func _process(delta: float) -> bool:
	if _b == null:
		var db := ContentDb.load_from()
		_b = load("res://scenes/battle/battle.tscn").instantiate()
		root.add_child(_b)
		_b.setup(db, db.mission(_mission_id), 1)
		_b.auto_step = true
		var w := WaveEntry.new()
		w.enemy_id = "shambler"
		for i in _enemies:
			_b._spawn_enemy(w)
			_b.enemies.back().ground_pos = IsoProjection.cell_center(Vector2i(24, 38)) + Vector2(randf_range(-4.0, 4.0), randf_range(-3.0, 3.0))
		_next_view()
		return false
	_t += delta
	var v: Dictionary = _views[_view]
	var cam := _b.camera_node()
	cam.zoom = Vector2(v["zoom"], v["zoom"])
	cam.position = IsoProjection.ground_to_screen(v["at"])
	if _t > WARMUP_S:
		_frames.append(delta)
		_draws += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	if _t > WARMUP_S + SAMPLE_S:
		_report(v["label"])
		_next_view()
	return false


func _next_view() -> void:
	_view += 1
	_t = 0.0
	_frames.clear()
	_draws = 0.0
	if _view >= _views.size():
		quit()


func _report(label: String) -> void:
	var sorted := _frames.duplicate()
	sorted.sort()
	var total := 0.0
	for f in _frames:
		total += f
	var n := _frames.size()
	var avg_fps := float(n) / total
	var worst := sorted[n - 1]
	var low_idx := int(floor(float(n) * 0.99))
	var one_pct_low_fps := 1.0 / sorted[mini(low_idx, n - 1)]
	print("%s | %s, %d enemies: avg %.0f FPS, 1%% low %.0f FPS, worst frame %.1f ms, ~%.0f draw calls, %d scenery pieces" % [
		_mission_id, label, _b.enemies.size(), avg_fps, one_pct_low_fps, worst * 1000.0, _draws / float(n), _b.scenery_nodes.size()])
