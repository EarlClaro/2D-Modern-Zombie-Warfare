extends TestCase
## EnemyIndex must answer exactly what a full scan answers (TargetingService.pick for "nearest in range", the blast loop for
## "who is hit"), including exact ties, positions outside the map and a stale index after kills.

const DT: float = 1.0 / 60.0
const MAP_W: float = 64.0
const MAP_H: float = 48.0

var _db: ContentDb
var _made: Array[Node] = []


func _get_db() -> ContentDb:
	if _db == null:
		_db = ContentDb.load_from()
	return _db


func _release() -> void:
	for n in _made:
		n.free()
	_made.clear()


func _enemy(uid: int) -> BattleEnemy:
	var e := BattleEnemy.new()
	e.uid = uid
	_made.append(e)
	return e


## Builds an index of enemies at `positions` (uids in the given order), and the matching candidate list for the full scan.
func _build(positions: Array[Vector2], uids: Array[int]) -> Array:
	var index := EnemyIndex.new()
	index.begin(MAP_W, MAP_H)
	var cands: Array[TargetCandidate] = []
	for i in positions.size():
		index.add(_enemy(uids[i]), positions[i])
		cands.append(TargetCandidate.new(uids[i], positions[i]))
	return [index, cands]


func _uid_of(e: BattleEnemy) -> int:
	return e.uid if e != null else TargetingService.NO_TARGET


func _random_positions(rng: RandomNumberGenerator, n: int, outside: bool) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var pad := 4.0 if outside else 0.0
	for i in n:
		out.append(Vector2(rng.randf_range(-pad, MAP_W + pad), rng.randf_range(-pad, MAP_H + pad)))
	return out


func _sequential_uids(n: int) -> Array[int]:
	var out: Array[int] = []
	for i in n:
		out.append(i + 1)
	return out


func test_nearest_matches_the_full_scan_on_random_crowds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var mismatches := 0
	for n in [5, 40, 300, 900]:
		var positions := _random_positions(rng, n, true)
		var built := _build(positions, _sequential_uids(n))
		var index: EnemyIndex = built[0]
		var cands: Array[TargetCandidate] = built[1]
		for q in 150:
			var origin := Vector2(rng.randf_range(-6.0, MAP_W + 6.0), rng.randf_range(-6.0, MAP_H + 6.0))
			var range_tiles: float = [0.5, 1.0, 4.5, 8.0, 14.0, 25.0, 90.0][rng.randi() % 7]
			if _uid_of(index.nearest(origin, range_tiles)) != TargetingService.pick(origin, range_tiles, cands):
				mismatches += 1
	_release()
	assert_eq(mismatches, 0, "every query agrees with TargetingService.pick")


func test_nearest_matches_when_the_crowd_is_dense_and_the_range_short() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var positions: Array[Vector2] = []
	for i in 1500:  # a tight horde: the ring search must stop early yet still be exact
		positions.append(Vector2(rng.randf_range(20.0, 28.0), rng.randf_range(10.0, 18.0)))
	var built := _build(positions, _sequential_uids(positions.size()))
	var index: EnemyIndex = built[0]
	var cands: Array[TargetCandidate] = built[1]
	var mismatches := 0
	for q in 300:
		var origin := Vector2(rng.randf_range(15.0, 33.0), rng.randf_range(5.0, 23.0))
		var range_tiles: float = [0.8, 2.0, 6.0][rng.randi() % 3]
		if _uid_of(index.nearest(origin, range_tiles)) != TargetingService.pick(origin, range_tiles, cands):
			mismatches += 1
	_release()
	assert_eq(mismatches, 0)


## A lattice of enemies, shuffled before insertion: from origins on and between lattice points many enemies are at
## exactly the same distance, both inside one grid cell and across cells. `side` picks the grid or the plain-scan path.
func _lattice_mismatches(side: int, seed_value: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var positions: Array[Vector2] = []
	var uids: Array[int] = []
	var next_uid := 1
	for y in side:
		for x in side:
			positions.append(Vector2(10.0 + x, 10.0 + y))
			uids.append(next_uid)
			next_uid += 1
	var order := range(positions.size())
	for i in range(order.size() - 1, 0, -1):  # shuffle the insertion order
		var j := rng.randi() % (i + 1)
		var t: int = order[i]
		order[i] = order[j]
		order[j] = t
	var shuffled_pos: Array[Vector2] = []
	var shuffled_uid: Array[int] = []
	for i in order:
		shuffled_pos.append(positions[i])
		shuffled_uid.append(uids[i])
	var built := _build(shuffled_pos, shuffled_uid)
	var index: EnemyIndex = built[0]
	var cands: Array[TargetCandidate] = built[1]
	var mismatches := 0
	var checked := 0
	for oy in range(8, 12 + side):
		for ox in range(8, 12 + side):
			for off in [Vector2(0, 0), Vector2(0.5, 0), Vector2(0, 0.5), Vector2(0.5, 0.5)]:
				for range_tiles in [1.0, 3.0, 7.0]:
					var origin: Vector2 = Vector2(float(ox), float(oy)) + (off as Vector2)
					checked += 1
					if _uid_of(index.nearest(origin, range_tiles)) != TargetingService.pick(origin, range_tiles, cands):
						mismatches += 1
	assert_true(checked > 100)
	return mismatches


func test_exact_ties_go_to_the_lowest_uid_on_the_grid_path() -> void:
	assert_eq(_lattice_mismatches(12, 3), 0, "144 enemies: the ring search is used")
	_release()


func test_exact_ties_go_to_the_lowest_uid_on_the_plain_scan_path() -> void:
	assert_eq(_lattice_mismatches(3, 9), 0, "9 enemies: the plain scan is used")
	_release()


func test_no_enemies_or_no_range_gives_no_target() -> void:
	var index := EnemyIndex.new()
	index.begin(MAP_W, MAP_H)
	assert_true(index.nearest(Vector2(5, 5), 10.0) == null, "empty index")
	index.add(_enemy(1), Vector2(5, 5))
	assert_true(index.nearest(Vector2(5, 5), 0.0) == null, "zero range")
	assert_true(index.nearest(Vector2(5, 5), -1.0) == null, "negative range")
	assert_true(index.nearest(Vector2(5, 5), 0.1) != null, "an enemy on the spot is in range")
	_release()


func test_range_is_inclusive_at_the_exact_distance() -> void:
	var index := EnemyIndex.new()
	index.begin(MAP_W, MAP_H)
	index.add(_enemy(7), Vector2(13, 10))
	assert_eq(_uid_of(index.nearest(Vector2(5, 10), 8.0)), 7, "exactly at range counts")
	assert_true(index.nearest(Vector2(5, 10), 7.999) == null)
	_release()


func test_begin_forgets_the_previous_tick() -> void:
	var index := EnemyIndex.new()
	index.begin(MAP_W, MAP_H)
	index.add(_enemy(1), Vector2(5, 5))
	index.begin(MAP_W, MAP_H)
	assert_eq(index.size(), 0)
	assert_true(index.nearest(Vector2(5, 5), 10.0) == null)
	_release()


func test_enemy_at_follows_insertion_order() -> void:
	var index := EnemyIndex.new()
	index.begin(MAP_W, MAP_H)
	var a := _enemy(9)
	var b := _enemy(4)
	index.add(a, Vector2(30, 30))
	index.add(b, Vector2(2, 2))
	assert_true(index.enemy_at(0) == a and index.enemy_at(1) == b)
	_release()


func test_box_candidates_cover_everything_in_the_radius_in_ascending_order() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var missing := 0
	var unordered := 0
	for n in [8, 400, 1200]:
		var positions := _random_positions(rng, n, true)
		var built := _build(positions, _sequential_uids(n))
		var index: EnemyIndex = built[0]
		for q in 120:
			var center := Vector2(rng.randf_range(-6.0, MAP_W + 6.0), rng.randf_range(-6.0, MAP_H + 6.0))
			var radius: float = [0.0, 1.5, 3.0, 7.0, 20.0][rng.randi() % 5]
			var got := index.box_candidates(center, radius)
			var seen: Dictionary = {}
			var prev := -1
			for i in got:
				seen[i] = true
				if i <= prev:
					unordered += 1
				prev = i
			for i in n:
				if positions[i].distance_to(center) <= radius and not seen.has(i):
					missing += 1
	_release()
	assert_eq(missing, 0, "no enemy inside the radius is left out")
	assert_eq(unordered, 0, "indices come back ascending (= `enemies` order)")


func _battle(mission_id: String, seed_value: int = 1) -> BattleController:
	var b := BattleController.new()
	b.auto_step = false
	b.setup(_get_db(), _get_db().mission(mission_id), seed_value)
	_made.append(b)
	return b


func _candidates_of(b: BattleController) -> Array[TargetCandidate]:
	var cands: Array[TargetCandidate] = []
	for e in b.enemies:
		cands.append(TargetCandidate.new(e.uid, e.ground_pos))
	return cands


func test_battle_targeting_matches_the_full_scan_through_kills_and_spawns() -> void:
	var b := _battle("m2_card_defense", 2)
	b.deck.hand = ["rifle_squad", "gatling_gun", "rifle_squad", "gatling_gun", "rifle_squad"] as Array[String]
	b.points.cp = 10.0
	b.play_card(0, Vector2i(7, 19))
	b.points.cp = 10.0
	b.play_card(1, Vector2i(7, 21))
	var rng := RandomNumberGenerator.new()
	rng.seed = 8
	var mismatches := 0
	var checked := 0
	for t in 60 * 40:
		if t % 120 == 0 and b.enemy_count() > 0:  # a kill: the removal makes the index stale until it is rebuilt
			b.enemies[rng.randi() % b.enemy_count()].health.take_damage(1.0e6)
		b.step(DT)
		if t % 20 == 0 and b.enemy_count() > 0:
			var cands := _candidates_of(b)
			for q in 8:
				var origin := Vector2(rng.randf_range(0.0, 30.0), rng.randf_range(0.0, 30.0))
				var range_tiles: float = [3.0, 8.0, 14.0][q % 3]
				checked += 1
				if _uid_of(b._nearest_enemy(origin, range_tiles)) != TargetingService.pick(origin, range_tiles, cands):
					mismatches += 1
	_release()
	assert_true(checked > 100, "queries were actually made (%d)" % checked)
	assert_eq(mismatches, 0)


func test_blast_hits_match_the_full_scan_in_enemy_order() -> void:
	var b := _battle("m2_card_defense", 3)
	for t in 60 * 25:
		b.step(DT)
	assert_true(b.enemy_count() > 20, "a crowd exists (%d)" % b.enemy_count())
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var wrong := 0
	for q in 12:
		var centre := b.enemies[rng.randi() % b.enemy_count()].ground_pos + Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0))
		var radius: float = [0.0, 1.8, 3.0, 8.0][q % 4]
		var expected: Array = []
		for e in b.enemies:
			var f := DamageService.blast_falloff(e.ground_pos.distance_to(centre), radius)
			if f > 0.0:
				expected.append([e, DamageService.compute(50.0, e.def.armor, f)])
		b._pending.clear()
		b._queue_blast(centre, 50.0, radius)
		if b._pending.size() != expected.size():
			wrong += 1
			continue
		for i in expected.size():
			if b._pending[i].target != expected[i][0] or not is_equal_approx(b._pending[i].amount, expected[i][1]):
				wrong += 1
				break
	b._pending.clear()
	_release()
	assert_eq(wrong, 0, "same targets, same amounts, same order as the old loop")


func test_a_stale_index_is_rebuilt_from_the_current_positions() -> void:
	var b := _battle("m2_card_defense", 5)
	for t in 60 * 8:
		b.step(DT)
	assert_true(b.enemy_count() > 3)
	var mover: BattleEnemy = b.enemies[0]
	var far := Vector2(45.0, 40.0)
	assert_true(b._nearest_enemy(far, 1.5) == null, "nobody is standing at the far corner yet")
	b._enemy_index_valid = false  # what a change to `enemies` leaves behind
	mover.ground_pos = far
	assert_true(b._nearest_enemy(far, 1.5) == mover, "the rebuilt index sees where the enemy stands now")
	_release()


func test_an_enemy_between_two_equally_near_units_hits_the_lower_id() -> void:
	var b := _battle("m2_card_defense", 6)
	var first := b._spawn_unit_at("rifle_soldier", Vector2(14.5, 10.0))
	var second := b._spawn_unit_at("rifle_soldier", Vector2(15.5, 10.0))
	assert_true(first.uid < second.uid)
	var w := WaveEntry.new()
	w.enemy_id = "shambler"
	b._spawn_enemy(w)
	b.enemies[0].ground_pos = Vector2(15.0, 10.0)  # exactly 0.5 tiles from both
	b.step(DT)
	assert_true(first.health.hp < first.health.max_hp, "the lower id was attacked")
	assert_eq(second.health.hp, second.health.max_hp, "the other was not")
	_release()
