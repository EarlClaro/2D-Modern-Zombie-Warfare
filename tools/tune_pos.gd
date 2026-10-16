extends SceneTree
## Dev tool (not a test). Does where the player parks the soldier change the outcome? Uses the shipped waves;
## the soldier is ordered at t=0 to each cell and 10 seeds are run per cell.
## Since ADR-013 the player gives no move orders: the soldier is placed on each cell at t=0 and then acts on its own
## (Guard). Run: godot --headless --path . --script tools/tune_pos.gd

const SEEDS := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
const CELLS: Array[Vector2i] = [Vector2i(7, 17), Vector2i(8, 15), Vector2i(9, 13), Vector2i(10, 15), Vector2i(6, 14), Vector2i(5, 19), Vector2i(7, 21), Vector2i(12, 16), Vector2i(4, 17)]


func _variant(base: MissionDefinition) -> MissionDefinition:
	var m: MissionDefinition = base.duplicate()
	var arr: Array[WaveEntry] = []
	for w in [[2.0, 6, 0.9], [20.0, 16, 0.65], [45.0, 36, 0.4]]:
		var e := WaveEntry.new()
		e.start_s = w[0]
		e.enemy_id = "shambler"
		e.count = w[1]
		e.interval_s = w[2]
		e.spawn_index = 0
		arr.append(e)
	m.waves = arr
	return m


func _init() -> void:
	var db := ContentDb.load_from()
	var m := _variant(db.mission("m1_hold_the_crossing"))
	print("map walkable check: ", ", ".join(CELLS.map(func(c): return "%s=%s" % [str(c), str(m.map.is_walkable(c))])))
	for cell in CELLS:
		var wins := 0
		var core_sum := 0.0
		for s in SEEDS:
			var b := BattleController.new()
			b.auto_step = false
			b.setup(db, m, s)
			for u in b.units:
				if not u.def.is_fixed():
					u.ground_pos = IsoProjection.cell_center(cell)
					u.anchor = u.ground_pos
			var steps := 0
			while not b.is_ended() and steps < 20000:
				b.step(1.0 / 60.0)
				steps += 1
			wins += 1 if b.result().status == MissionRules.Status.WON else 0
			core_sum += b.core.health.hp / b.core.health.max_hp
			b.free()
		print("soldier -> %-8s wins %2d/%d  core left avg %3.0f%%" % [str(cell), wins, SEEDS.size(), core_sum / SEEDS.size() * 100.0])
	quit()
