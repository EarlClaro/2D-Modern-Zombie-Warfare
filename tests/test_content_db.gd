extends TestCase

const Db := preload("res://scripts/core/content_db.gd")
const WeaponDef := preload("res://scripts/combat/weapon_definition.gd")
const UnitDef := preload("res://scripts/combat/unit_definition.gd")
const EnemyDef := preload("res://scripts/combat/enemy_definition.gd")


func _weapon(id: String = "test_gun") -> WeaponDef:
	var w := WeaponDef.new()
	w.id = id
	w.damage = 10.0
	w.shots_per_second = 2.0
	w.range_tiles = 6.0
	return w


func _unit(id: String = "test_unit", weapon_id: String = "test_gun") -> UnitDef:
	var u := UnitDef.new()
	u.id = id
	u.display_name = "Test Unit"
	u.max_health = 50.0
	u.move_speed = 2.0
	u.weapon_id = weapon_id
	return u


func _enemy(id: String = "test_enemy") -> EnemyDef:
	var e := EnemyDef.new()
	e.id = id
	e.display_name = "Test Enemy"
	e.max_health = 30.0
	e.move_speed = 1.0
	e.attack_damage = 5.0
	return e


func _has_error(db: ContentDb, needle: String) -> bool:
	for e in db.errors:
		if needle in e:
			return true
	return false


# --- shipped data -------------------------------------------------------------------------------

func test_shipped_data_is_valid() -> void:
	var db := Db.load_from("res://data")
	assert_true(db.is_valid(), "shipped data errors:\n" + "\n".join(db.errors))
	for id in ["rifle", "mg"]:
		assert_true(db.weapon(id) != null, "weapon %s present" % id)
	for id in ["rifle_soldier", "mg_nest"]:
		assert_true(db.unit(id) != null, "unit %s present" % id)
	assert_true(db.enemy("shambler") != null, "shambler present")


func test_shipped_data_relations_not_values() -> void:
	# Relations only, so balance tuning doesn't break tests.
	var db := Db.load_from("res://data")
	assert_true(db.unit("mg_nest").is_fixed(), "MG nest is fixed")
	assert_true(not db.unit("rifle_soldier").is_fixed(), "soldier is mobile")
	assert_true(db.weapon("mg").shots_per_second > db.weapon("rifle").shots_per_second, "MG fires faster than rifle")
	assert_true(db.weapon(db.unit("mg_nest").weapon_id) != null)


func test_missing_directory_is_reported() -> void:
	var db := Db.load_from("res://data_does_not_exist")
	assert_true(not db.is_valid())
	assert_true(_has_error(db, "data directory missing"))


# --- registration & validation ------------------------------------------------------------------

func test_valid_definitions_register() -> void:
	var db := Db.new()
	assert_true(db.add_weapon(_weapon()))
	assert_true(db.add_unit(_unit()))
	assert_true(db.add_enemy(_enemy()))
	db.validate_references()
	assert_true(db.is_valid(), "\n".join(db.errors))
	assert_true(db.weapon("test_gun") != null)


func test_unknown_ids_resolve_to_null() -> void:
	var db := Db.new()
	assert_true(db.weapon("nope") == null)
	assert_true(db.unit("nope") == null)
	assert_true(db.enemy("nope") == null)


func test_invalid_weapon_reports_field_and_is_not_registered() -> void:
	var db := Db.new()
	var w := _weapon("broken_gun")
	w.damage = 0.0
	w.shots_per_second = -1.0
	assert_true(not db.add_weapon(w))
	assert_true(_has_error(db, "weapon 'broken_gun': damage must be > 0"))
	assert_true(_has_error(db, "shots_per_second"))
	assert_true(db.weapon("broken_gun") == null, "invalid definitions never reach the battle")


func test_bad_ids_are_rejected() -> void:
	var db := Db.new()
	var empty := _weapon("")
	assert_true(not db.add_weapon(empty))
	assert_true(_has_error(db, "id is empty"))
	for bad in ["Bad Id", "UPPER", "1starts_with_digit", "has-dash"]:
		assert_true(not db.add_weapon(_weapon(bad)), "'%s' rejected" % bad)
	assert_true(db.weapons.is_empty())


func test_duplicate_id_is_reported_and_first_wins() -> void:
	var db := Db.new()
	var first := _weapon("dup")
	first.damage = 11.0
	var second := _weapon("dup")
	second.damage = 99.0
	assert_true(db.add_weapon(first))
	assert_true(not db.add_weapon(second))
	assert_true(_has_error(db, "weapon 'dup': duplicate id"))
	assert_near(db.weapon("dup").damage, 11.0)


func test_ids_may_repeat_across_kinds() -> void:
	var db := Db.new()
	assert_true(db.add_weapon(_weapon("same")))
	assert_true(db.add_unit(_unit("same", "same")))
	db.validate_references()
	assert_true(db.is_valid(), "\n".join(db.errors))


func test_unit_with_unknown_weapon_is_a_reference_error_naming_both() -> void:
	var db := Db.new()
	assert_true(db.add_unit(_unit("orphan", "ghost_weapon")))
	db.validate_references()
	assert_true(_has_error(db, "unit 'orphan': unknown weapon_id 'ghost_weapon'"))
	assert_true(not db.is_valid())


func test_projectile_delivery_needs_speed_and_a_blast() -> void:
	var db := Db.new()
	var w := _weapon("shell")
	w.delivery = WeaponDef.Delivery.PROJECTILE
	assert_true(not db.add_weapon(w))
	assert_true(_has_error(db, "projectile_speed"))
	assert_true(_has_error(db, "blast_radius"))


func test_invalid_unit_and_enemy_fields() -> void:
	var db := Db.new()
	var u := _unit("bad_unit")
	u.max_health = 0.0
	u.move_speed = -1.0
	u.footprint_radius = 0.0
	u.display_name = ""
	u.weapon_id = ""
	assert_true(not db.add_unit(u))
	for needle in ["max_health", "move_speed", "footprint_radius", "display_name", "weapon_id"]:
		assert_true(_has_error(db, needle), "unit error mentions " + needle)
	var e := _enemy("bad_enemy")
	e.max_health = -5.0
	e.armor = -1.0
	e.move_speed = 0.0
	e.attack_damage = 0.0
	e.attack_interval_s = 0.0
	e.attack_range = 0.0
	assert_true(not db.add_enemy(e))
	for needle in ["max_health", "armor", "move_speed", "attack_damage", "attack_interval_s", "attack_range"]:
		assert_true(_has_error(db, "enemy 'bad_enemy': " + needle), "enemy error mentions " + needle)


func test_fixed_unit_zero_speed_is_valid() -> void:
	var db := Db.new()
	var u := _unit("nest")
	u.move_speed = 0.0
	assert_true(db.add_unit(u), "\n".join(db.errors))
	assert_true(db.unit("nest").is_fixed())


func test_fire_interval() -> void:
	var w := _weapon()
	w.shots_per_second = 4.0
	assert_near(w.fire_interval_s(), 0.25)


func test_a_complete_projectile_weapon_is_valid() -> void:
	var w := _weapon("rocket")
	w.delivery = WeaponDef.Delivery.PROJECTILE
	w.projectile_speed = 10.0
	w.blast_radius = 1.0
	assert_eq(w.validate().size(), 0)
	w.projectile_arc = -1.0
	assert_true(_has_error_in(w.validate(), "projectile_arc"))


func _has_error_in(errs: PackedStringArray, needle: String) -> bool:
	for e in errs:
		if needle in e:
			return true
	return false


func test_unit_with_an_unknown_secondary_weapon_is_a_reference_error() -> void:
	var db := Db.new()
	db.add_weapon(_weapon("main_gun"))
	var u := _unit("two_guns", "main_gun")
	u.secondary_weapon_id = "ghost_rocket"
	db.add_unit(u)
	db.validate_references()
	assert_true(_has_error(db, "unknown secondary_weapon_id 'ghost_rocket'"))


func test_projectile_accel_and_drop_are_validated() -> void:
	var w := _weapon("rocket")
	w.delivery = WeaponDef.Delivery.PROJECTILE
	w.projectile_speed = 10.0
	w.blast_radius = 1.0
	w.projectile_accel = 1.5
	w.projectile_drop = -1.0
	var errs := w.validate()
	assert_true(_has_error_in(errs, "projectile_accel"))
	assert_true(_has_error_in(errs, "projectile_drop"))
	w.projectile_accel = 0.8
	w.projectile_drop = 0.3
	assert_eq(w.validate().size(), 0)


func test_the_shipped_missile_is_a_motor_driven_weapon() -> void:
	var db := Db.load_from("res://data")
	var m := db.weapon("heli_missile")
	assert_true(m.projectile_accel > 0.5, "accelerates like a rocket, not a thrown shell")
	assert_true(m.projectile_drop > 0.0, "drops off the pylon first")

