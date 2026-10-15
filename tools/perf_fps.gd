extends SceneTree
## Dev tool (not a test). Windowed FPS measurement of the real battle scene under horde load.
## Prints average FPS, 1% / 0.1% lows, frame-time spikes and engine monitors. Results vary run to run on a laptop
## (power/thermal state), so repeat it and record ranges.
## Run (NOT headless): godot --path . --resolution 1920x1080 --audio-driver Dummy --script tools/perf_fps.gd

const WARMUP_S := 7.0
const SAMPLE_S := 12.0

var scenarios := [
	{"label": "100 shamblers + 2 defenders (stress mission)", "count": 100, "defenders": true, "vsync": false},
	{"label": "100 shamblers, no defenders (all stay alive)", "count": 100, "defenders": false, "vsync": false},
	{"label": "250 shamblers, no defenders", "count": 250, "defenders": false, "vsync": false},
	{"label": "500 shamblers, no defenders", "count": 500, "defenders": false, "vsync": false},
	{"label": "100 shamblers + 2 defenders, vsync ON (60 Hz cap)", "count": 100, "defenders": true, "vsync": true},
]

var _b: BattleController
var _db: ContentDb
var _idx: int = -1
var _t: float = 0.0
var _phase: String = "boot"
var _frames: PackedFloat64Array = PackedFloat64Array()
var _m_process: float = 0.0
var _m_physics: float = 0.0
var _m_draws: float = 0.0
var _m_nodes: float = 0.0
var _m_objects: float = 0.0
var _boot_frames: int = 0


func _variant(sc: Dictionary) -> MissionDefinition:
	var m: MissionDefinition = _db.mission("s1_stress_horde").duplicate()
	var w := WaveEntry.new()
	w.start_s = 1.0
	w.enemy_id = "shambler"
	w.count = sc["count"]
	w.interval_s = 5.0 / sc["count"]
	w.spawn_index = 0
	m.waves = [w] as Array[WaveEntry]
	m.core_health = 1.0e7  # the core never falls during a measurement
	m.duration_s = 600.0
	if not sc["defenders"]:
		m.start_units = [] as Array[StartUnit]
	return m


func _start_scenario() -> void:
	_idx += 1
	if _idx >= scenarios.size():
		quit()
		return
	var sc: Dictionary = scenarios[_idx]
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if sc["vsync"] else DisplayServer.VSYNC_DISABLED)
	_b.setup(_db, _variant(sc), 1)
	_b.auto_step = true
	_t = 0.0
	_frames.clear()
	_m_process = 0.0
	_m_physics = 0.0
	_m_draws = 0.0
	_m_nodes = 0.0
	_m_objects = 0.0
	_phase = "warmup"


func _report() -> void:
	var sc: Dictionary = scenarios[_idx]
	var n := _frames.size()
	var total := 0.0
	for f in _frames:
		total += f
	var sorted := _frames.duplicate()
	sorted.sort()
	var p99 := sorted[int(n * 0.99)]
	var p999 := sorted[int(n * 0.999)]
	var over_20ms := 0
	for f in _frames:
		if f > 0.020:
			over_20ms += 1
	print("RESULT | %s" % sc["label"])
	print("  frames=%d  avg FPS=%.1f  1%% low FPS=%.1f  0.1%% low FPS=%.1f  worst frame=%.1f ms  frames>20ms=%d (%.1f%%)" % [
		n, n / total, 1.0 / p99, 1.0 / p999, sorted[-1] * 1000.0, over_20ms, 100.0 * over_20ms / n])
	print("  engine monitors (avg): process=%.2f ms  physics=%.2f ms  draw calls=%.0f  nodes=%.0f  objects drawn=%.0f | enemies alive at end=%d" % [
		_m_process / n * 1000.0, _m_physics / n * 1000.0, _m_draws / n, _m_nodes / n, _m_objects / n, _b.enemy_count()])


func _process(delta: float) -> bool:
	if _phase == "boot":
		_boot_frames += 1
		if _b == null:
			_db = ContentDb.load_from()
			_b = load("res://scenes/battle/battle.tscn").instantiate()
			root.add_child(_b)
			Engine.max_fps = 0
			print("ENV | window=%s screen=%s renderer=%s adapter=%s" % [str(root.size), str(DisplayServer.screen_get_size()),
				RenderingServer.get_current_rendering_method(), RenderingServer.get_video_adapter_name()])
		elif _boot_frames > 5:
			_start_scenario()
		return false
	_t += delta
	if _phase == "warmup":
		if _t >= WARMUP_S:
			_phase = "sample"
			_t = 0.0
			_frames.clear()
		return false
	if _phase == "sample":
		_frames.append(delta)
		_m_process += Performance.get_monitor(Performance.TIME_PROCESS)
		_m_physics += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
		_m_draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		_m_nodes += Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
		_m_objects += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
		if _t >= SAMPLE_S:
			_report()
			_start_scenario()
	return false
