extends TestCase
## Structures (walls, barricades, scenery): fixed player entities with hit points and no weapon that stall enemies,
## some of which blow up when destroyed. See docs/specs/props-and-cover.md.

const DT: float = 1.0 / 60.0
const MISSION_ID := "x1_fortified_crossing"
const SPOT := Vector2i(9, 13)  # grass beside the road, in deploy range

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


func _run_for(b: BattleController, seconds: float) -> void:
	for i in int(round(seconds / DT)):
		b.step(DT)


func _enemy_at(b: BattleController, wave: int, pos: Vector2) -> BattleEnemy:
	b._spawn_enemy(b.mission.waves[wave])
	var e: BattleEnemy = b.enemies.back()
	e.ground_pos = pos
	return e


func _has(errs: PackedStringArray, needle: String) -> bool:
	for e in errs:
		if needle in e:
			return true
	return false


func _unit(structure: bool = true) -> UnitDefinition:
	var d := UnitDefinition.new()
	d.id = "thing"
	d.display_name = "Thing"
	d.max_health = 50.0
	d.structure = structure
	return d


# --- definitions ------------------------------------------------------------------------------------------

func test_a_structure_needs_no_weapon_but_everything_else_does() -> void:
	assert_eq(_unit(true).validate().size(), 0)
	assert_true(_has(_unit(false).validate(), "weapon_id"))


func test_a_structure_must_be_fixed_unarmed_and_on_the_ground() -> void:
	var mover := _unit()
	mover.move_speed = 1.0
	assert_true(_has(mover.validate(), "fixed"))
	var armed := _unit()
	armed.weapon_id = "rifle"
	assert_true(_has(armed.validate(), "must not have a weapon"))
	var flyer := _unit()
	flyer.height_class = UnitDefinition.HeightClass.LOW_AIR
	assert_true(_has(flyer.validate(), "ground"))


func test_death_blast_fields_are_set_together_and_not_negative() -> void:
	var half := _unit()
	half.death_blast_damage = 50.0
	assert_true(_has(half.validate(), "set together"))
	var neg := _unit()
	neg.death_blast_radius = -1.0
	assert_true(_has(neg.validate(), ">= 0"))
	var ok := _unit()
	ok.death_blast_damage = 50.0
	ok.death_blast_radius = 2.0
	assert_eq(ok.validate().size(), 0)
	assert_true(ok.has_death_blast())
	assert_true(not _unit().has_death_blast())


func test_shipped_structures_are_complete() -> void:
	var db := _get_db()
	for id in ["sandbag_wall", "concrete_barrier", "crate_stack", "oil_drums", "jeep", "supply_truck"]:
		var d := db.unit(id)
		assert_true(d != null and d.structure and d.weapon_id.is_empty() and d.is_fixed(), "%s is a fixed unarmed structure" % id)
		assert_true(d.sprite != null and d.sprite.has_death() and d.sprite.textures.size() == 8, "%s has art with a destruction sequence" % id)
	assert_true(db.unit("oil_drums").has_death_blast() and db.unit("supply_truck").has_death_blast(), "drums and truck are volatile")
	assert_true(not db.unit("sandbag_wall").has_death_blast())
	assert_true(db.unit("concrete_barrier").armor > 0.0 and db.unit("concrete_barrier").max_health > db.unit("sandbag_wall").max_health)


func test_structure_cards_and_the_fortified_deck_are_valid() -> void:
	var db := _get_db()
	for pair in [["sandbags", "sandbag_wall"], ["barrier", "concrete_barrier"], ["crates", "crate_stack"], ["fuel_drums", "oil_drums"]]:
		assert_eq(db.card(pair[0]).unit_id, pair[1])
		assert_true(db.card(pair[0]).cost <= 2, "%s is a cheap card" % pair[0])
	var ids: Array[String] = db.deck("fortified").ids()
	assert_eq(db.deck_rules.validate_deck(ids, db.cards).size(), 0)
	assert_eq(db.mission(MISSION_ID).start_units.size(), 2)


# --- in battle --------------------------------------------------------------------------------------------

func test_scenery_is_placed_at_the_start_and_faces_the_spawn() -> void:
	var b := _battle()
	assert_eq(b.units.size(), 2)
	var ids := []
	for u in b.units:
		ids.append(u.def.id)
		var want := IsoProjection.facing_from_ground_dir(IsoProjection.cell_center(b.mission.spawn_cells[0]) - u.ground_pos)
		assert_eq(u.facing, want, "%s faces the spawn" % u.def.id)
	assert_eq(ids, ["jeep", "supply_truck"])
	_release()


func test_playing_a_wall_card_deploys_one_unarmed_structure() -> void:
	var b := _battle()
	b.deck.hand = ["sandbags"] as Array[String]
	b.points.cp = 5.0
	var res := b.play_card(0, SPOT)
	assert_true(res.ok)
	assert_eq(b.units.size(), 3)
	var wall: BattleUnit = b.units.back()
	assert_eq(wall.def.id, "sandbag_wall")
	assert_true(wall.weapon == null and wall.weapon_state == null)
	assert_near(b.points.cp, 5.0 - float(b.db.card("sandbags").cost), 1e-9)
	_run_for(b, 2.0)  # no weapon to fire, no crash
	assert_eq(b.stats["shots"], 0)
	_release()


func test_enemies_stop_to_attack_a_structure_in_reach_and_armor_helps() -> void:
	var b := _battle()
	var wall := b._spawn_unit_at("sandbag_wall", IsoProjection.cell_center(SPOT))
	var barrier := b._spawn_unit_at("concrete_barrier", IsoProjection.cell_center(Vector2i(5, 17)))
	var e1 := _enemy_at(b, 0, wall.ground_pos + Vector2(0.5, 0.0))
	var e2 := _enemy_at(b, 0, barrier.ground_pos + Vector2(0.5, 0.0))
	var p1 := e1.ground_pos
	var p2 := e2.ground_pos
	_run_for(b, 3.0)
	assert_vec_near(e1.ground_pos, p1, 1e-6, "the enemy holds position while the wall stands")
	assert_vec_near(e2.ground_pos, p2, 1e-6)
	var shambler := b.db.enemy("shambler")
	var hit_wall := wall.def.max_health - wall.health.hp
	var hit_barrier := barrier.def.max_health - barrier.health.hp
	assert_true(hit_wall > 0.0 and hit_barrier > 0.0, "both took damage")
	assert_true(hit_barrier < hit_wall, "armor 3 turns 10-damage swings into 7")
	assert_near(fmod(hit_wall, shambler.attack_damage), 0.0, 1e-6, "damage comes in whole swings")
	assert_true(hit_wall >= 3.0 * shambler.attack_damage, "at least three swings in three seconds at 1/s")
	_release()


func test_a_destroyed_wall_lets_the_enemy_walk_on() -> void:
	var b := _battle()
	var wall := b._spawn_unit_at("crate_stack", IsoProjection.cell_center(SPOT))
	var e := _enemy_at(b, 0, wall.ground_pos + Vector2(0.5, 0.0))
	wall.health.take_damage(wall.def.max_health)
	var before := e.ground_pos
	_run_for(b, 1.0)
	assert_eq(b.units.size(), 2, "the dead structure left the battle (only the scenery remains)")
	assert_true(e.ground_pos.distance_to(before) > 0.5, "nothing in reach, so it walks on")
	assert_eq(b.stats["units_lost"], 1)
	_release()


func test_a_volatile_structure_blasts_the_crowd_when_it_dies_and_spares_the_rest() -> void:
	var b := _battle()
	var drums := b._spawn_unit_at("oil_drums", IsoProjection.cell_center(SPOT))
	var centre := drums.ground_pos
	var near := _enemy_at(b, 0, centre + Vector2(0.4, 0.0))
	var side := _enemy_at(b, 0, centre + Vector2(1.2, 0.0))
	var far := _enemy_at(b, 0, centre + Vector2(4.0, 0.0))
	var blasts: Array = []
	b.blast_landed.connect(func(c: Vector2, r: float): blasts.append([c, r]))
	drums.health.take_damage(1000.0)
	var far_hp := far.health.hp
	b.step(DT)
	assert_eq(blasts.size(), 1)
	assert_vec_near(blasts[0][0], centre)
	assert_near(blasts[0][1], 1.8)
	assert_true(not is_instance_valid(near) or near.health.hp < near.health.max_hp, "the nearest enemy is hurt or dead")
	assert_true(not is_instance_valid(side) or side.health.hp < side.health.max_hp, "inside the radius too")
	assert_near(far.health.hp, far_hp, 1e-9, "outside the radius takes nothing")
	_release()


func test_the_blast_of_a_dying_structure_never_hurts_player_entities() -> void:
	var b := _battle()
	var drums := b._spawn_unit_at("oil_drums", IsoProjection.cell_center(SPOT))
	var neighbour := b._spawn_unit_at("supply_truck", drums.ground_pos + Vector2(0.8, 0.0))
	drums.health.take_damage(1000.0)
	b.step(DT)
	assert_eq(neighbour.health.hp, neighbour.def.max_health)
	assert_true(b.units.has(neighbour))
	_release()


func test_the_truck_goes_up_with_a_big_blast() -> void:
	var b := _battle()
	var truck: BattleUnit = null
	for u in b.units:
		if u.def.id == "supply_truck":
			truck = u
	var radius := [0.0]
	b.blast_landed.connect(func(c: Vector2, r: float): radius[0] = r)
	truck.health.take_damage(10000.0)
	b.step(DT)
	assert_near(radius[0], 2.4)
	_release()
