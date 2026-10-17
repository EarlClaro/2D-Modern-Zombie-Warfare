extends SceneTree
## Dev tool (not a test). F5 "make the game harder": scales the waves of the older missions and adds the new enemies
## (Sprinter, Behemoth, Spewer). Run ONCE per mission: it skips a mission that already has a Sprinter wave.
## Run: godot --headless --path . --script tools/harden_missions.gd
## Rewrites data/missions/<id>.tres for the ids below (the file is re-saved by the engine, so its layout may change).

## id -> [count factor for the existing waves, specials as [start_s, enemy, count, interval_s]]
const PLAN := {
	"m2_card_defense": [2.0, [[75.0, "sprinter", 30, 0.15]]],
	"m3_combined_arms": [1.12, [[30.0, "behemoth", 1, 1.0], [60.0, "sprinter", 30, 0.1], [80.0, "spewer", 6, 1.0]]],
	"x1_fortified_crossing": [1.5, [[30.0, "behemoth", 1, 1.0], [60.0, "sprinter", 30, 0.1], [80.0, "spewer", 6, 1.0]]],
	"x2_outskirts": [1.4, [[5.0, "behemoth", 3, 4.0], [60.0, "sprinter", 80, 0.06], [70.0, "spewer", 14, 0.8]]],
	"x3_storm_night": [1.4, [[5.0, "behemoth", 3, 4.0], [60.0, "sprinter", 80, 0.06], [70.0, "spewer", 14, 0.8]]],
	"x4_field_orders": [1.0, [[30.0, "behemoth", 1, 1.0], [60.0, "sprinter", 30, 0.1], [80.0, "spewer", 6, 1.0]]],
}


func _initialize() -> void:
	var errors := 0
	for id in PLAN:
		var path := "res://data/missions/%s.tres" % id
		var m := load(path) as MissionDefinition
		if m == null:
			push_error("cannot load %s" % path)
			errors += 1
			continue
		var already := false
		for w in m.waves:
			if w.enemy_id == "sprinter":
				already = true
		if already:
			print("%s: already hardened, skipped" % id)
			continue
		var factor: float = PLAN[id][0]
		var waves: Array[WaveEntry] = []
		for w in m.waves:
			var c: WaveEntry = w.duplicate()
			c.count = maxi(1, int(round(float(w.count) * factor)))
			c.interval_s = w.interval_s / factor  # more enemies in the same time
			waves.append(c)
		for sp in PLAN[id][1]:
			var e := WaveEntry.new()
			e.start_s = sp[0]
			e.enemy_id = sp[1]
			e.count = sp[2]
			e.interval_s = sp[3]
			e.spawn_index = 0
			waves.append(e)
		var before := m.total_enemies()
		m.waves = waves
		for err in m.validate():
			push_error(err)
			errors += 1
		if ResourceSaver.save(m, path) != OK:
			push_error("saving %s failed" % path)
			errors += 1
		print("%s: %d -> %d enemies" % [id, before, m.total_enemies()])
	quit(1 if errors > 0 else 0)
