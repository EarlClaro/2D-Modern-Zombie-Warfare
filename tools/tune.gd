extends SceneTree
## Dev tool (not a test). Balance sweep: candidate wave sets vs the default loadout (passive: soldier + MG nest,
## no orders) over several seeds. Prints win rate, core damage and losses. Edit `candidates` to explore.
## Run: godot --headless --path . --script tools/tune.gd

const SEEDS := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]

# name -> {waves: [[start_s, count, interval_s], ...], core_hp, duration}
var candidates := {
	"shipped (6/16/36 = 58)": {"waves": [[2.0, 6, 0.9], [20.0, 16, 0.65], [45.0, 36, 0.4]], "core": 500.0},
	"wave 3 = 34": {"waves": [[2.0, 6, 0.9], [20.0, 16, 0.65], [45.0, 34, 0.4]], "core": 500.0},
	"wave 3 = 38": {"waves": [[2.0, 6, 0.9], [20.0, 16, 0.65], [45.0, 38, 0.4]], "core": 500.0},
}


func _variant(base: MissionDefinition, cfg: Dictionary, defenders: bool) -> MissionDefinition:
	var m: MissionDefinition = base.duplicate()
	var arr: Array[WaveEntry] = []
	for w in cfg["waves"]:
		var e := WaveEntry.new()
		e.start_s = w[0]
		e.enemy_id = "shambler"
		e.count = w[1]
		e.interval_s = w[2]
		e.spawn_index = 0
		arr.append(e)
	m.waves = arr
	m.core_health = cfg["core"]
	if not defenders:
		m.start_units = [] as Array[StartUnit]
	return m


func _run(db: ContentDb, m: MissionDefinition, seed_value: int) -> Dictionary:
	var b := BattleController.new()
	b.auto_step = false
	b.setup(db, m, seed_value)
	var first_loss := -1.0
	var steps := 0
	while not b.is_ended() and steps < 20000:
		b.step(1.0 / 60.0)
		steps += 1
		if first_loss < 0.0 and b.stats["units_lost"] > 0:
			first_loss = b.elapsed
	var out := {
		"won": b.result().status == MissionRules.Status.WON,
		"t": b.elapsed,
		"core": b.core.health.hp / b.core.health.max_hp,
		"lost": b.stats["units_lost"],
		"kills": b.stats["kills"],
		"spawned": b.stats["spawned"],
		"first_loss": first_loss,
	}
	b.free()
	return out


func _init() -> void:
	var db := ContentDb.load_from()
	var base := db.mission("m1_hold_the_crossing")
	for name in candidates:
		var cfg: Dictionary = candidates[name]
		var wins := 0
		var core_sum := 0.0
		var lost_sum := 0
		var kill_frac := 0.0
		var t_sum := 0.0
		var core_min := 2.0
		var core_max := -1.0
		for s in SEEDS:
			var r := _run(db, _variant(base, cfg, true), s)
			wins += 1 if r["won"] else 0
			core_sum += r["core"]
			core_min = minf(core_min, r["core"])
			core_max = maxf(core_max, r["core"])
			lost_sum += r["lost"]
			kill_frac += float(r["kills"]) / maxf(r["spawned"], 1)
			t_sum += r["t"]
		var n := float(SEEDS.size())
		# bounds: no defenders (must lose) and twelve nests (should win comfortably)
		var none := _run(db, _variant(base, cfg, false), 1)
		print("%-24s wins %2d/%d | core left avg %3.0f%% (min %3.0f%%, max %3.0f%%) | units lost avg %.1f | kills avg %3.0f%% | avg end %.0fs | no-defenders: %s at %.0fs" % [
			name, wins, SEEDS.size(), core_sum / n * 100.0, core_min * 100.0, core_max * 100.0, lost_sum / n, kill_frac / n * 100.0, t_sum / n,
			"WON" if none["won"] else "lost", none["t"]])
	quit()
