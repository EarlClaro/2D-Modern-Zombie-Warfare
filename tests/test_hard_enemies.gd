extends TestCase
## The three harder enemies of F5 (docs/specs/field-command.md): Sprinter, Behemoth, Spewer.

var _db: ContentDb


func _get_db() -> ContentDb:
	if _db == null:
		_db = ContentDb.load_from()
	return _db


func test_the_new_enemies_exist_and_are_valid() -> void:
	var db := _get_db()
	assert_true(db.is_valid(), "content errors: %s" % ", ".join(db.errors))
	for id in ["sprinter", "behemoth", "spewer"]:
		assert_true(db.enemy(id) != null, id)
		assert_true(db.enemy(id).sprite != null, "%s has a sprite sheet" % id)


func test_the_sprinter_outruns_every_soldier_so_the_army_must_stand_and_fight() -> void:
	var db := _get_db()
	var sprinter := db.enemy("sprinter")
	for id in ["rifle_soldier", "rpg_soldier", "marksman", "mortar_team"]:
		assert_true(sprinter.move_speed > db.unit(id).move_speed, "faster than %s" % id)
	assert_true(sprinter.move_speed < db.unit("scout").move_speed, "but a scout jeep still outruns it")


func test_the_behemoth_shrugs_off_rifles_and_not_anti_armour() -> void:
	var db := _get_db()
	var b := db.enemy("behemoth")
	var rifle := DamageService.compute(db.weapon("rifle").damage, b.armor)
	var rpg := DamageService.compute(db.weapon("rpg").damage, b.armor)
	var marksman := DamageService.compute(db.weapon("marksman_rifle").damage, b.armor)
	assert_true(rifle < db.weapon("rifle").damage * 0.5, "a rifle round loses more than half to the plates")
	assert_true(rpg > db.weapon("rpg").damage * 0.85, "a rocket barely notices them")
	assert_true(marksman > db.weapon("marksman_rifle").damage * 0.8)
	assert_true(b.max_health > db.enemy("brute").max_health * 3.0 and b.move_speed < db.enemy("brute").move_speed)


func test_the_spewer_outranges_the_soldiers_reach_zone() -> void:
	var db := _get_db()
	var s := db.enemy("spewer")
	assert_true(s.spits and s.attack_range >= 6.0)
	assert_true(s.attack_range > db.enemy("spitter").attack_range)
	assert_true(s.threat > db.enemy("brute").threat, "the army shoots it first")
	# a rifleman cannot stand outside its danger zone and still hit it, so the brain leaves it to long-range weapons
	var zone := s.attack_range + UnitBrain.KITE_MARGIN * db.unit("rifle_soldier").danger_margin + s.move_speed * UnitBrain.KITE_REACT_S
	assert_true(zone > db.weapon("rifle").range_tiles)
	assert_true(db.weapon("marksman_rifle").range_tiles > zone or db.weapon("tank_cannon").range_tiles > zone)
