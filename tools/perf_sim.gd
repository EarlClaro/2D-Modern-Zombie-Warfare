extends SceneTree
## Dev tool (not a test). Headless cost of BattleController.step(): simulation only, no rendering.
## Reports per-step microseconds for several horde sizes, with and without defenders.
## Run: godot --headless --path . --script tools/perf_sim.gd [-- --counts=100,250 --interval=0.05 --defenders=0]
## `--counts` / `--interval` / `--defenders` (0 or 1, default both) narrow the runs; with a small `--interval` a big count
## builds a crowd of 1000+ alive. The second line of each run gives the average step cost by number of enemies alive.
var _interval: float = 0.05


func _variant(base: MissionDefinition, count: int, defenders: bool) -> MissionDefinition:
	var m: MissionDefinition = base.duplicate()
	var w := WaveEntry.new()
	w.start_s = 1.0
	w.enemy_id = "shambler"
	w.count = count
	w.interval_s = _interval
	w.spawn_index = 0
	m.waves = [w] as Array[WaveEntry]
	if not defenders:
		m.start_units = [] as Array[StartUnit]
	return m


func _measure(db: ContentDb, base: MissionDefinition, count: int, defenders: bool, label: String) -> void:
	var b := BattleController.new()
	b.auto_step = false
	b.setup(db, _variant(base, count, defenders), 1)
	var times: Array[int] = []
	var by_alive: Dictionary = {}  # bucket (alive / 250 * 250) -> [sum us, steps]
	var alive_samples := 0
	var alive_total := 0
	var steps := 60 * 40  # 40 simulated seconds
	for i in steps:
		var t0 := Time.get_ticks_usec()
		b.step(1.0 / 60.0)
		var step_us := Time.get_ticks_usec() - t0
		times.append(step_us)
		var bucket := b.enemy_count() / 250 * 250
		var acc: Array = by_alive.get(bucket, [0, 0])
		acc[0] += step_us
		acc[1] += 1
		by_alive[bucket] = acc
		if i % 60 == 0:
			alive_samples += 1
			alive_total += b.enemy_count()
		if b.is_ended():
			break
	var sorted := times.duplicate()
	sorted.sort()
	var sum := 0
	for t in times:
		sum += t
	var peak_alive := 0
	print("%-34s steps=%d avg=%6.1f us  p99=%6d us  max=%6d us  avg alive=%.0f  ended=%s" % [
		label, times.size(), float(sum) / times.size(), sorted[int(sorted.size() * 0.99)], sorted[-1],
		float(alive_total) / alive_samples, str(b.is_ended())])
	var keys := by_alive.keys()
	keys.sort()
	var parts: PackedStringArray = []
	for k in keys:
		var a: Array = by_alive[k]
		parts.append("%d-%d: %.1f ms (%d steps)" % [k, k + 249, float(a[0]) / a[1] / 1000.0, a[1]])
	print("    avg step by enemies alive | " + " | ".join(parts))
	b.free()


func _init() -> void:
	var db := ContentDb.load_from()
	var base := db.mission("s1_stress_horde")
	var counts: Array[int] = [100, 250, 500, 1000]
	var modes: Array[bool] = [true, false]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--counts="):
			counts = []
			for c in a.substr(9).split(","):
				counts.append(int(c))
		elif a.begins_with("--interval="):
			_interval = float(a.substr(11))
		elif a.begins_with("--defenders="):
			modes = [a.substr(12) == "1"]
	for count in counts:
		for defenders in modes:
			_measure(db, base, count, defenders, "%d shamblers, %s" % [count, "2 defenders" if defenders else "no defenders"])
	quit()
