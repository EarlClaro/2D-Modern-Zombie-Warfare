extends SceneTree
## Dev tool (not a test). Headless cost of BattleController.step(): simulation only, no rendering.
## Reports per-step microseconds for several horde sizes, with and without defenders.
## Run: godot --headless --path . --script tools/perf_sim.gd

func _variant(base: MissionDefinition, count: int, defenders: bool) -> MissionDefinition:
	var m: MissionDefinition = base.duplicate()
	var w := WaveEntry.new()
	w.start_s = 1.0
	w.enemy_id = "shambler"
	w.count = count
	w.interval_s = 0.05
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
	var alive_samples := 0
	var alive_total := 0
	var steps := 60 * 40  # 40 simulated seconds
	for i in steps:
		var t0 := Time.get_ticks_usec()
		b.step(1.0 / 60.0)
		times.append(Time.get_ticks_usec() - t0)
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
	b.free()


func _init() -> void:
	var db := ContentDb.load_from()
	var base := db.mission("s1_stress_horde")
	for count in [100, 250, 500, 1000]:
		_measure(db, base, count, true, "%d shamblers, 2 defenders" % count)
		_measure(db, base, count, false, "%d shamblers, no defenders" % count)
	quit()
