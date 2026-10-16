extends TestCase
## The Spitter: a ranged acid attacker. It stops at range, hurts from a distance, and its glob is drawn by AcidSpit.

const DT: float = 1.0 / 60.0
const MISSION_ID := "x1_fortified_crossing"

var _db: ContentDb
var _made: Array[BattleController] = []


func _get_db() -> ContentDb:
	if _db == null:
		_db = ContentDb.load_from()
	return _db


func _battle() -> BattleController:
	var b := BattleController.new()
	b.auto_step = false
	b.setup(_get_db(), _get_db().mission(MISSION_ID), 1)
	_made.append(b)
	return b


func _release() -> void:
	for b in _made:
		b.free()
	_made.clear()


func _spitter_at(b: BattleController, pos: Vector2) -> BattleEnemy:
	var w := WaveEntry.new()
	w.enemy_id = "spitter"
	w.count = 1
	b._spawn_enemy(w)
	var e: BattleEnemy = b.enemies.back()
	e.ground_pos = pos
	return e


func _run_for(b: BattleController, seconds: float) -> void:
	for i in int(round(seconds / DT)):
		b.step(DT)


func test_spitter_definition_is_a_ranged_enemy_with_art() -> void:
	var d := _get_db().enemy("spitter")
	assert_true(d != null and d.spits)
	assert_true(d.attack_range > _get_db().enemy("shambler").attack_range * 3.0, "far longer reach than a melee zombie")
	assert_true(d.sprite != null and d.sprite.attack_frame >= 0 and d.sprite.has_death() and d.sprite.textures.size() == 8)
	var bad := EnemyDefinition.new()
	bad.id = "bad"
	bad.display_name = "Bad"
	bad.max_health = 10.0
	bad.move_speed = 1.0
	bad.attack_damage = 1.0
	bad.spits = true
	bad.attack_range = 0.8
	var errs := bad.validate()
	var found := false
	for e in errs:
		if "spitter" in e:
			found = true
	assert_true(found, "a spitter with a melee range is rejected")


func test_spitter_stops_at_range_and_hurts_a_target_it_cannot_touch() -> void:
	var b := _battle()
	var wall := b._spawn_unit_at("concrete_barrier", IsoProjection.cell_center(Vector2i(9, 13)))
	var e := _spitter_at(b, wall.ground_pos + Vector2(4.4, 0.0))
	var pos := e.ground_pos
	var seen: Array = []
	b.enemy_attacked.connect(func(en: BattleEnemy, t: Node): seen.append([en, t]))
	_run_for(b, 3.0)
	assert_vec_near(e.ground_pos, pos, 1e-6, "inside 4.5 tiles it does not walk closer")
	assert_true(wall.health.hp < wall.def.max_health, "the acid reached the wall")
	assert_true(seen.size() >= 1 and seen[0][0] == e and seen[0][1] == wall, "the attack was announced for the effects")
	_release()


func test_a_spitter_walks_until_something_is_in_reach() -> void:
	var b := _battle()
	var wall := b._spawn_unit_at("sandbag_wall", IsoProjection.cell_center(Vector2i(9, 13)))
	var e := _spitter_at(b, wall.ground_pos + Vector2(9.0, 0.0))
	var before := e.ground_pos.distance_to(wall.ground_pos)
	_run_for(b, 2.0)
	assert_true(e.ground_pos.distance_to(wall.ground_pos) < before - 0.5 or wall.health.hp < wall.def.max_health, "it advances toward the lane")
	_release()


func test_acid_glob_flies_an_arc_and_cleans_itself_up() -> void:
	var holder := Node2D.new()
	var s := AcidSpit.spawn(holder, Vector2(0, 0), Vector2(100, 40))
	assert_vec_near(s.glob_at(0.0), Vector2(0, 0))
	assert_vec_near(s.glob_at(1.0), Vector2(100, 40))
	assert_true(s.glob_at(0.5).y < 20.0, "the glob rises above the straight line")
	assert_near(s.lifetime_s(), AcidSpit.FLIGHT_S + AcidSpit.SPLASH_S)
	holder.free()
