extends TestCase
## Wiring tests for BattleFeedback: the battle runs inside the real scene tree (so tweens, effects and
## the audio pool exist) but no frames are processed, so effects appear as nodes without ticking.

const StartUnitRes := preload("res://scripts/missions/start_unit.gd")
const MISSION_ID := "m1_hold_the_crossing"
const DT: float = 1.0 / 60.0

var _db: ContentDb
var _roots: Array[Node] = []


func _get_db() -> ContentDb:
	if _db == null:
		_db = ContentDb.load_from()
	return _db


func _su(unit_id: String, cell: Vector2i) -> StartUnit:
	var su := StartUnitRes.new()
	su.unit_id = unit_id
	su.cell = cell
	return su


func _variant(unit_list: Array) -> MissionDefinition:
	var m: MissionDefinition = _get_db().mission(MISSION_ID).duplicate()
	var arr: Array[StartUnit] = []
	for su in unit_list:
		arr.append(su)
	m.start_units = arr
	return m


## Controller in the tree with a BattleFeedback bound (feedback = true) or without it.
func _battle(mission: MissionDefinition, seed_value: int = 1, feedback: bool = true) -> BattleController:
	var b := BattleController.new()
	b.auto_step = false
	b.setup(_get_db(), mission, seed_value)  # set up first, so _ready doesn't load the default mission
	tree.root.add_child(b)
	_roots.append(b)
	if feedback:
		var fb := BattleFeedback.new()
		fb.name = "Feedback"
		b.add_child(fb)
		fb.bind(b)
	return b


func _release() -> void:
	for r in _roots:
		if is_instance_valid(r):
			r.get_parent().remove_child(r)
			r.free()
	_roots.clear()


func _inject_enemy(b: BattleController, pos: Vector2) -> BattleEnemy:
	b._spawn_enemy(b.mission.waves[0])
	var e: BattleEnemy = b.enemies.back()
	e.ground_pos = pos
	return e


func _count_of(layer: Node, script_class_name: String) -> int:
	var n := 0
	for c in layer.get_children():
		if c.get_script() != null and c.get_script().get_global_name() == script_class_name:
			n += 1
	return n


func _count_nodes(n: Node) -> int:
	var c := 1
	for child in n.get_children():
		c += _count_nodes(child)
	return c


func _summary(b: BattleController) -> Dictionary:
	return {
		"status": b.result().status,
		"elapsed": snappedf(b.elapsed, 0.001),
		"kills": b.stats["kills"],
		"shots": b.stats["shots"],
		"spawned": b.stats["spawned"],
		"units_lost": b.stats["units_lost"],
		"core_hp": snappedf(b.core.health.hp, 0.001),
	}


func test_firing_spawns_tracer_flash_spark_and_recoil() -> void:
	var b := _battle(_variant([_su("mg_nest", Vector2i(8, 14))]))
	var nest: BattleUnit = b.units[0]
	_inject_enemy(b, Vector2(11.5, 13.5))
	var fx := b.fx_layer()
	assert_eq(fx.get_child_count(), 0)
	b.step(DT)
	assert_eq(_count_of(fx, "Tracer"), 1, "tracer")
	assert_eq(_count_of(fx, "MuzzleFlash"), 1, "muzzle flash")
	assert_eq(_count_of(fx, "ImpactSpark"), 1, "impact spark at the target")
	assert_true(nest._recoil != Vector2.ZERO, "shooter kicked back")
	assert_true(nest._recoil.length() <= BattleUnit.KICK_PX + 1e-6)
	_release()


func test_recoil_never_moves_the_sort_anchor() -> void:
	var b := _battle(_variant([_su("mg_nest", Vector2i(8, 14))]))
	var nest: BattleUnit = b.units[0]
	var before := nest.position
	_inject_enemy(b, Vector2(11.5, 13.5))
	b.step(DT)
	assert_vec_near(nest.position, before, 1e-6, "kick is a draw offset only")
	nest._process(0.2)
	assert_eq(nest._recoil, Vector2.ZERO, "recoil recovers")
	_release()


func test_hit_flashes_the_enemy() -> void:
	var b := _battle(_variant([_su("mg_nest", Vector2i(8, 14))]))
	var e := _inject_enemy(b, Vector2(11.5, 13.5))
	assert_eq(e.self_modulate, Color.WHITE)
	b.step(DT)
	assert_true(e.self_modulate.r > 1.0, "flash brightens the enemy")
	assert_true(e.is_alive())
	_release()


func test_enemy_death_leaves_simulation_at_once_and_collapses() -> void:
	var b := _battle(_variant([_su("mg_nest", Vector2i(8, 14))]))
	var e := _inject_enemy(b, Vector2(11.5, 13.5))
	e.health.hp = 1.0
	b.step(DT)
	assert_true(not b.enemies.has(e), "removed from targeting immediately")
	assert_eq(b.stats["kills"], 1)
	assert_true(e.dying, "death collapse started")
	assert_true(is_instance_valid(e) and e.get_parent() != null, "body still shown while it collapses")
	assert_eq(_count_of(b.fx_layer(), "DeathPuff"), 1, "dust puff")
	_release()


func test_core_hit_flashes_red_and_shakes_within_the_cap() -> void:
	var b := _battle(_variant([]))
	var fb: BattleFeedback = b.get_node("Feedback")
	var core := b.core
	_inject_enemy(b, core.ground_pos + Vector2(0.5, 0.0))
	b.step(DT)
	assert_true(core.health.hp < core.health.max_hp, "core took damage")
	assert_true(core.self_modulate.r > core.base_self_modulate.r + 0.5, "core flashed red")
	assert_true(core.self_modulate.g < 1.0)
	var amp := fb.shake.current_amplitude()
	assert_true(amp > 0.0 and amp <= 4.0, "shake active and within the 4 px limit: %s" % amp)
	assert_eq(_count_of(b.fx_layer(), "ImpactSpark"), 1)
	_release()


func test_feedback_never_changes_the_simulation() -> void:
	var with_fb := _battle(_get_db().mission(MISSION_ID), 21, true)
	var without_fb := _battle(_get_db().mission(MISSION_ID), 21, false)
	for i in int(40.0 / DT):
		with_fb.step(DT)
		without_fb.step(DT)
	assert_true(with_fb.stats["shots"] > 0, "the comparison covers real combat")
	assert_eq(_summary(with_fb), _summary(without_fb), "identical outcome with and without feedback")
	_release()


func test_restart_clears_effects_and_dying_bodies() -> void:
	var b := _battle(_variant([_su("mg_nest", Vector2i(8, 14))]))
	var baseline := _count_nodes(b)
	var e := _inject_enemy(b, Vector2(11.5, 13.5))
	e.health.hp = 1.0
	for i in 30:
		b.step(DT)
	assert_true(b.fx_layer().get_child_count() > 0)
	assert_true(_count_nodes(b) > baseline)
	b.restart()
	assert_eq(b.fx_layer().get_child_count(), 0, "effects cleared")
	assert_eq(_count_nodes(b), baseline, "no leaked effect or corpse nodes")
	_release()


func test_weapon_sound_comes_from_weapon_data() -> void:
	var db := _get_db()
	assert_eq(db.weapon("mg").sfx_id, "shot_mg")
	assert_eq(db.weapon("rifle").sfx_id, "shot_rifle")


func test_a_destroyed_vehicle_explodes_instead_of_dropping_a_dust_puff() -> void:
	var b := _battle(_variant([]))
	var u := b._spawn_unit_at("tank", Vector2(9.5, 12.5))
	assert_eq(b.units.size(), 1)
	u.health.hp = 0.0
	b.step(DT)
	assert_true(u.dying, "tank collapses into its wreck")
	assert_eq(_count_of(b.fx_layer(), "VehicleExplosion"), 1, "fireball")
	assert_eq(_count_of(b.fx_layer(), "DeathPuff"), 0, "no dust puff for an explosive death")
	_release()


func test_a_destroyed_rifleman_still_drops_a_dust_puff_and_no_explosion() -> void:
	var b := _battle(_variant([]))
	var u := b._spawn_unit_at("rifle_soldier", Vector2(9.5, 12.5))
	u.health.hp = 0.0
	b.step(DT)
	assert_eq(_count_of(b.fx_layer(), "VehicleExplosion"), 0)
	assert_eq(_count_of(b.fx_layer(), "DeathPuff"), 1)
	_release()


func test_explosion_waits_for_its_delay_then_cleans_itself_up() -> void:
	var holder := Node2D.new()
	tree.root.add_child(holder)
	var e := VehicleExplosion.spawn(holder, Vector2.ZERO, 20.0, 0.4)
	e._process(0.1)
	assert_true(not e.is_queued_for_deletion(), "alive during the delay")
	e._process(e.lifetime_s())
	assert_true(e.is_queued_for_deletion(), "frees itself after the smoke has gone")
	holder.free()


func test_a_wreck_leaves_a_scorch_mark_that_restart_removes() -> void:
	var b := _battle(_variant([]))
	var u := b._spawn_unit_at("tank", Vector2(9.5, 12.5))
	u.health.hp = 0.0
	b.step(DT)
	assert_eq(_count_of(b.decal_layer(), "ScorchMark"), 1, "burnt ground under the wreck")
	b.restart()
	assert_eq(_count_of(b.decal_layer(), "ScorchMark"), 0, "restart clears it")
	_release()


func test_infantry_leave_no_scorch_mark() -> void:
	var b := _battle(_variant([]))
	var u := b._spawn_unit_at("rifle_soldier", Vector2(9.5, 12.5))
	u.health.hp = 0.0
	b.step(DT)
	assert_eq(_count_of(b.decal_layer(), "ScorchMark"), 0)
	_release()


func test_being_shot_staggers_the_enemy_without_moving_it() -> void:
	var b := _battle(_variant([_su("mg_nest", Vector2i(8, 14))]))
	var e := _inject_enemy(b, Vector2(11.5, 13.5))
	var anchor := e.position
	for i in 90:
		b.step(DT)
		if e.is_alive() and e._stagger != Vector2.ZERO:
			break
	assert_true(e._stagger != Vector2.ZERO or not e.is_alive(), "the MG shot staggered it")
	if e.is_alive():
		assert_near(e.position.x, anchor.x, 60.0, "only the drawing jerks; movement is the sim's")
	_release()

