extends TestCase
## Runner and Brute enemies, the RPG team and Howitzer cards, and the `m3_combined_arms` mission that uses them.

const DT: float = 1.0 / 60.0
const MISSION_ID := "m3_combined_arms"
const GOOD := Vector2i(7, 19)  # grass, ~4 tiles from the core
const WAVE_RUNNER: int = 1
const WAVE_BRUTE: int = 3

var _db: ContentDb
var _made: Array[BattleController] = []


func _get_db() -> ContentDb:
	if _db == null:
		_db = ContentDb.load_from()
	return _db


func _battle(seed_value: int = 1) -> BattleController:
	var b := BattleController.new()
	b.auto_step = false
	b.setup(_get_db(), _get_db().mission(MISSION_ID), seed_value)
	_made.append(b)
	return b


func _release() -> void:
	for b in _made:
		b.free()
	_made.clear()


func _inject(b: BattleController, wave: int, pos: Vector2) -> BattleEnemy:
	b._spawn_enemy(b.mission.waves[wave])
	var e: BattleEnemy = b.enemies.back()
	e.ground_pos = pos
	return e


func _run_for(b: BattleController, seconds: float) -> void:
	for i in int(round(seconds / DT)):
		b.step(DT)


# --- content ----------------------------------------------------------------------------------------------

func test_runner_is_fast_and_fragile_and_brute_is_slow_and_armored() -> void:
	var db := _get_db()
	var shambler := db.enemy("shambler")
	var runner := db.enemy("runner")
	var brute := db.enemy("brute")
	assert_true(runner != null and brute != null)
	assert_true(runner.move_speed > shambler.move_speed * 1.5, "runner is much faster")
	assert_true(runner.max_health < shambler.max_health, "runner is fragile")
	assert_true(brute.move_speed < shambler.move_speed, "brute is slower")
	assert_true(brute.max_health >= shambler.max_health * 4.0, "brute is a damage sponge")
	var rifle := db.weapon("rifle")
	assert_true(DamageService.compute(rifle.damage, brute.armor) < DamageService.compute(rifle.damage, 0.0), "rifle fire is blunted by the brute's armor")


func test_new_enemies_and_units_have_complete_sprites() -> void:
	var db := _get_db()
	for id in ["runner", "brute"]:
		var s: SpriteSheet = db.enemy(id).sprite
		assert_true(s != null and s.has_death() and s.attack_frame >= 0 and s.stride_tiles > 0.0, "%s sprite is fully wired" % id)
		assert_eq(s.textures.size(), 8, "%s has all eight facings" % id)
	for id in ["rpg_soldier", "howitzer"]:
		var s: SpriteSheet = db.unit(id).sprite
		assert_true(s != null and s.has_death() and s.fire_frame >= 0, "%s has death and fire frames" % id)
		assert_eq(s.textures.size(), 8, "%s has all eight facings" % id)
	assert_true(db.unit("howitzer").sprite.explosion_px > 0.0, "a destroyed howitzer explodes")


func test_new_cards_point_at_real_units_and_the_new_deck_is_legal() -> void:
	var db := _get_db()
	assert_eq(db.card("rpg_team").unit_id, "rpg_soldier")
	assert_eq(db.card("rpg_team").unit_count, 2)
	assert_eq(db.card("howitzer_battery").unit_id, "howitzer")
	var ids: Array[String] = db.deck("combined_arms").ids()
	assert_true(ids.has("rpg_team") and ids.has("howitzer_battery"))
	assert_eq(db.deck_rules.validate_deck(ids, db.cards).size(), 0, "deck is legal under the rules")


func test_m3_uses_the_new_enemies_and_the_new_deck() -> void:
	var m := _get_db().mission(MISSION_ID)
	var seen := {}
	for w in m.waves:
		seen[w.enemy_id] = true
	assert_true(seen.has("shambler") and seen.has("runner") and seen.has("brute"))
	assert_eq(m.deck_id, "combined_arms")
	assert_eq(m.waves[WAVE_RUNNER].enemy_id, "runner")
	assert_eq(m.waves[WAVE_BRUTE].enemy_id, "brute")


# --- in battle --------------------------------------------------------------------------------------------

func test_a_runner_covers_more_ground_than_a_shambler_in_the_same_time() -> void:
	var b := _battle()
	var far := Vector2(18.0, 5.0)
	var runner := _inject(b, WAVE_RUNNER, far)
	var shambler := _inject(b, 0, far + Vector2(1.0, 0.0))
	var r0 := runner.ground_pos
	var s0 := shambler.ground_pos
	_run_for(b, 2.0)
	assert_true(runner.ground_pos.distance_to(r0) > shambler.ground_pos.distance_to(s0) * 1.5)
	_release()


func test_rpg_team_deploys_two_gunners_whose_rocket_blasts_a_group() -> void:
	var b := _battle()
	b.deck.hand = ["rpg_team"] as Array[String]
	b.points.cp = 10.0
	assert_true(b.play_card(0, GOOD).ok)
	assert_eq(b.units.size(), 2)
	for u in b.units:
		assert_eq(u.def.id, "rpg_soldier")
	var at := IsoProjection.cell_center(GOOD) + Vector2(4.0, 0.0)
	_inject(b, 0, at)
	_inject(b, 0, at + Vector2(0.4, 0.0))
	var blasts: Array = []
	b.blast_landed.connect(func(center: Vector2, r: float): blasts.append(r))
	_run_for(b, 3.0)
	assert_true(blasts.size() >= 1, "a rocket exploded")
	assert_near(blasts[0], b.db.weapon("rpg").blast_radius)
	assert_eq(b.stats["kills"], 2, "70 damage with falloff kills two clustered shamblers")
	_release()


func test_howitzer_is_fixed_and_shells_a_group_beyond_rifle_range() -> void:
	var b := _battle()
	b.deck.hand = ["howitzer_battery"] as Array[String]
	b.points.cp = 10.0
	assert_true(b.play_card(0, GOOD).ok)
	assert_eq(b.units.size(), 1)
	assert_true(b.units[0].def.is_fixed())
	var gun := b.db.weapon("howitzer")
	assert_true(gun.range_tiles > b.db.weapon("rifle").range_tiles * 1.5, "outranges rifles by a lot")
	var at := IsoProjection.cell_center(GOOD) + Vector2(12.0, 0.0)
	var e := _inject(b, 0, at)
	var launched: Array = []
	b.projectile_launched.connect(func(s: BattleUnit, w: WeaponDefinition, f: Vector2, t: Vector2): launched.append(w.id))
	var blasts: Array = []
	b.blast_landed.connect(func(center: Vector2, r: float): blasts.append(r))
	_run_for(b, 4.0)
	assert_eq(launched, ["howitzer"])
	assert_eq(blasts.size(), 1)
	assert_near(blasts[0], gun.blast_radius)
	assert_true(not is_instance_valid(e) or e.health.hp < e.health.max_hp, "the shell hurt the target (a killed enemy is freed)")
	_release()


func test_do_nothing_loses_m3_and_every_enemy_type_spawns() -> void:
	var b := _battle()
	_run_for(b, 40.0)
	var kinds := {}
	for e in b.enemies:
		kinds[e.def.id] = true
	assert_true(kinds.has("shambler") and kinds.has("runner"), "early waves are on the field")
	_release()
