extends TestCase

const SOLDIER_PATH := "res://data/units/rifle_soldier.tres"
const SHAMBLER_PATH := "res://data/enemies/shambler.tres"
const MG_NEST_PATH := "res://data/units/mg_nest.tres"
const GATLING_PATH := "res://data/units/gatling_gun.tres"
const TANK_PATH := "res://data/units/tank.tres"
const HELI_PATH := "res://data/units/helicopter.tres"


func test_frame_region_walks_the_grid_row_major() -> void:
	var s := SpriteSheet.new()
	assert_eq(s.frame_region(0), Rect2(0, 0, 32, 32))
	assert_eq(s.frame_region(2), Rect2(64, 0, 32, 32))
	assert_eq(s.frame_region(3), Rect2(0, 32, 32, 32), "wraps to the second row")
	assert_eq(s.frame_region(4), Rect2(32, 32, 32, 32))


func test_walk_frame_cycles_through_walk_frames_only() -> void:
	var s := SpriteSheet.new()
	s.walk_fps = 10.0
	var seen: Dictionary = {}
	for i in 40:
		var f := s.walk_frame(i * 0.1)
		assert_true(f >= s.walk_first and f < s.walk_first + s.walk_count, "frame %d in walk range" % f)
		seen[f] = true
	assert_eq(seen.size(), s.walk_count, "all walk frames appear")
	assert_true(not seen.has(s.idle_frame), "idle frame is not part of the walk cycle")


func test_left_facings_mirror_the_right_facing_art() -> void:
	for f in [IsoProjection.Facing.SW, IsoProjection.Facing.W, IsoProjection.Facing.NW]:
		assert_true(SpriteSheet.faces_left(f), "%s mirrors" % IsoProjection.facing_name(f))
	for f in [IsoProjection.Facing.E, IsoProjection.Facing.SE, IsoProjection.Facing.S,
			IsoProjection.Facing.N, IsoProjection.Facing.NE]:
		assert_true(not SpriteSheet.faces_left(f), "%s is not mirrored" % IsoProjection.facing_name(f))


func test_every_facing_maps_to_an_authored_direction_or_its_mirror() -> void:
	var expected := {
		IsoProjection.Facing.E: "E", IsoProjection.Facing.SE: "SE", IsoProjection.Facing.S: "S",
		IsoProjection.Facing.NE: "NE", IsoProjection.Facing.N: "N",
		IsoProjection.Facing.SW: "SE", IsoProjection.Facing.W: "E", IsoProjection.Facing.NW: "NE",
	}
	for f in expected:
		assert_eq(SpriteSheet.art_direction(f), expected[f], IsoProjection.facing_name(f))
		assert_eq(SpriteSheet.faces_left(f), SpriteSheet.art_direction(f) != "" and f in [
				IsoProjection.Facing.SW, IsoProjection.Facing.W, IsoProjection.Facing.NW],
				"%s mirrored only for left-hand facings" % IsoProjection.facing_name(f))


func test_missing_direction_falls_back_to_se() -> void:
	var s := SpriteSheet.new()
	var se := PlaceholderTexture2D.new()
	s.textures = {"SE": se}
	assert_true(s.texture_for(IsoProjection.Facing.N) == se, "no N art -> SE")
	var n := PlaceholderTexture2D.new()
	s.textures["N"] = n
	assert_true(s.texture_for(IsoProjection.Facing.N) == n, "N art wins when present")
	assert_true(SpriteSheet.new().texture_for(IsoProjection.Facing.E) == null, "empty sheet -> null")


func test_shipped_sprite_sheets_match_their_textures() -> void:
	for path in [SOLDIER_PATH, SHAMBLER_PATH, MG_NEST_PATH, GATLING_PATH, TANK_PATH, HELI_PATH]:
		var def: Resource = load(path)
		var sheet: SpriteSheet = def.sprite
		assert_true(sheet != null, "%s has a sprite" % path)
		if sheet == null:
			continue
		for dir in ["E", "SE", "S", "NE", "N"]:
			var tex: Texture2D = sheet.textures.get(dir, null)
			assert_true(tex != null, "%s has %s art" % [path, dir])
			if tex == null:
				continue
			var last := maxi(maxi(sheet.walk_first + sheet.walk_count - 1, sheet.attack_frame), sheet.death_first + sheet.death_count - 1)
			var needed := sheet.frame_region(last if sheet.walk_count > 1 else sheet.idle_frame)
			assert_true(needed.end.x <= tex.get_width() and needed.end.y <= tex.get_height(),
					"%s %s: last walk frame inside the sheet" % [path, dir])
		assert_true(sheet.origin.x < sheet.frame_size.x and sheet.origin.y < sheet.frame_size.y,
				"%s origin inside a frame" % path)


func test_unit_walk_animation_runs_only_while_moving() -> void:
	var def: UnitDefinition = load(SOLDIER_PATH)
	var weapon: WeaponDefinition = load("res://data/weapons/rifle.tres")
	var u := BattleUnit.new()
	u.setup(1, def, weapon, Vector2i(5, 5))
	u._process(0.5)
	assert_eq(u._frame, def.sprite.idle_frame, "standing still idles")
	assert_true(u.order_move(IsoProjection.cell_center(Vector2i(9, 5))))
	u._process(0.13)
	assert_true(u._frame >= def.sprite.walk_first, "moving switches to a walk frame")
	u._moving = false
	u._process(0.1)
	assert_eq(u._frame, def.sprite.idle_frame, "stopping returns to idle")
	u.free()


func test_enemy_walk_animation_follows_real_movement() -> void:
	var def: EnemyDefinition = load(SHAMBLER_PATH)
	var e := BattleEnemy.new()
	var wps: Array[Vector2] = [Vector2(10, 10)]
	e.setup(1, def, Vector2(4, 4), wps)
	e._process(0.5)
	assert_eq(e._frame, def.sprite.idle_frame, "not moving idles")
	e.advance_path(0.1)
	e._process(0.25)
	assert_true(e._frame >= def.sprite.walk_first, "moved this frame -> walking")
	e._process(0.05)
	assert_eq(e._frame, def.sprite.idle_frame, "no movement since last frame -> idle")
	e.free()


func test_enemy_shows_attack_frame_only_right_after_a_swing() -> void:
	var def: EnemyDefinition = load(SHAMBLER_PATH)
	assert_true(def.sprite.attack_frame >= 0, "shambler has an attack frame")
	var e := BattleEnemy.new()
	var wps: Array[Vector2] = [Vector2(10, 10)]
	e.setup(1, def, Vector2(4, 4), wps)
	e._process(0.1)
	assert_true(not e.is_swinging(), "fresh enemy has not swung")
	assert_true(e.attack_state.tick(0.1, true), "attack lands")
	e._process(0.05)
	assert_true(e.is_swinging(), "swing just landed")
	assert_eq(e._frame, def.sprite.attack_frame, "attack frame while standing and swinging")
	e.attack_state.tick(def.attack_interval_s * 0.5, false)
	assert_true(not e.is_swinging(), "swing pose ends well before the next attack")
	e.free()


func test_mg_nest_is_a_fixed_sprite_that_never_leaves_the_idle_frame() -> void:
	var def: UnitDefinition = load(MG_NEST_PATH)
	var weapon: WeaponDefinition = load("res://data/weapons/mg.tres")
	var u := BattleUnit.new()
	u.setup(1, def, weapon, Vector2i(6, 6))
	u._process(1.0)
	assert_eq(u._frame, def.sprite.idle_frame)
	assert_near(u.chest_world().y - u.position.y, -def.sprite.chest_px, 1e-6, "hit point follows the sprite")
	u.free()


func test_exact_facing_art_is_never_mirrored() -> void:
	var s := SpriteSheet.new()
	var se := PlaceholderTexture2D.new()
	s.textures = {"SE": se}
	assert_true(s.is_mirrored(IsoProjection.Facing.SW), "SW borrows SE art and mirrors it")
	assert_true(s.texture_for(IsoProjection.Facing.SW) == se)
	var sw := PlaceholderTexture2D.new()
	s.textures["SW"] = sw
	assert_true(not s.is_mirrored(IsoProjection.Facing.SW), "own SW art is drawn as is")
	assert_true(s.texture_for(IsoProjection.Facing.SW) == sw)


func test_rendered_sheets_have_all_eight_facings() -> void:
	for path in [SOLDIER_PATH, SHAMBLER_PATH, GATLING_PATH, TANK_PATH, HELI_PATH]:
		var sheet: SpriteSheet = load(path).sprite
		for f in 8:
			assert_true(sheet.has_exact(f), "%s has %s" % [path, IsoProjection.facing_name(f)])
			assert_true(not sheet.is_mirrored(f), "%s %s needs no mirroring" % [path, IsoProjection.facing_name(f)])


func test_helicopter_rotor_spins_while_hovering_and_altitude_lifts_the_hit_point() -> void:
	var def: UnitDefinition = load(HELI_PATH)
	var weapon: WeaponDefinition = load("res://data/weapons/heli_gun.tres")
	var u := BattleUnit.new()
	u.setup(1, def, weapon, Vector2i(6, 6))
	u._process(0.0)
	var seen: Dictionary = {}
	for i in 20:
		u._process(0.03)
		seen[u._frame] = true
	assert_true(seen.size() >= 3, "rotor frames cycle although the helicopter is not moving")
	var ground_chest := u.chest_world()
	u.altitude = 2.0
	assert_near(u.chest_world().y, ground_chest.y + IsoProjection.altitude_offset(2.0).y, 1e-6, "hit point rises with altitude")
	u.free()


func test_tank_walk_cycle_only_runs_while_moving() -> void:
	var def: UnitDefinition = load(TANK_PATH)
	var weapon: WeaponDefinition = load("res://data/weapons/tank_cannon.tres")
	var u := BattleUnit.new()
	u.setup(1, def, weapon, Vector2i(6, 6))
	u._process(0.5)
	assert_eq(u._frame, def.sprite.idle_frame, "parked tank shows the idle frame")
	assert_true(u.order_move(IsoProjection.cell_center(Vector2i(9, 6))))
	u._process(0.2)
	assert_true(u._frame >= def.sprite.walk_first, "moving tank scrolls its tracks")
	u.free()


func test_sprite_death_plays_frames_holds_the_last_and_keeps_the_body_shown() -> void:
	for path in [SOLDIER_PATH, SHAMBLER_PATH]:
		var def: Resource = load(path)
		var sheet: SpriteSheet = def.sprite
		assert_true(sheet.has_death(), "%s has death frames" % path)
		var node: IsoEntity
		if def is EnemyDefinition:
			var e := BattleEnemy.new()
			var wps: Array[Vector2] = [Vector2(10, 10)]
			e.setup(1, def, Vector2(4, 4), wps)
			node = e
		else:
			var u := BattleUnit.new()
			u.setup(1, def, load("res://data/weapons/rifle.tres"), Vector2i(5, 5))
			node = u
		tree.root.add_child(node)
		node.play_death(0.3, null)
		assert_true(node.dying, "dying flag set")
		assert_eq(node._frame, sheet.death_first, "starts on the first death frame")
		node._play_death_frame(0.0, sheet)
		assert_eq(node._frame, sheet.death_first)
		node._play_death_frame(1000.0, sheet)
		assert_eq(node._frame, sheet.death_first + sheet.death_count - 1, "never runs past the last death frame")
		node.free()


func test_a_definition_without_death_frames_keeps_the_squash_and_fade() -> void:
	var def: UnitDefinition = load(TANK_PATH).duplicate()
	def.sprite = def.sprite.duplicate()
	def.sprite.death_first = -1  # as if no wreck art existed
	assert_true(not def.sprite.has_death())
	var u := BattleUnit.new()
	u.setup(1, def, load("res://data/weapons/tank_cannon.tres"), Vector2i(5, 5))
	tree.root.add_child(u)
	u.play_death(0.3, null)
	assert_true(u.dying)
	assert_true(u._frame == def.sprite.idle_frame, "no sprite death frame was selected")
	u.free()


func test_every_sprited_machine_has_wreck_frames_and_an_explosion() -> void:
	for path in [MG_NEST_PATH, GATLING_PATH, TANK_PATH, HELI_PATH]:
		var sheet: SpriteSheet = load(path).sprite
		assert_true(sheet.has_death(), "%s has wreck frames" % path)
		assert_true(sheet.explosion_px > 0.0, "%s explodes" % path)
	for path in [SOLDIER_PATH, SHAMBLER_PATH]:
		assert_near((load(path) as Resource).sprite.explosion_px, 0.0, 1e-9, "infantry do not explode")
	var heli: SpriteSheet = load(HELI_PATH).sprite
	assert_true(heli.death_fall_frames > 0 and heli.fall_time_s() > 0.0, "the helicopter falls before it explodes")
	assert_near(SpriteSheet.new().fall_time_s(), 0.0, 1e-9, "ground units explode at once")


func test_aircraft_sprite_is_not_lifted_twice_and_a_dead_aircraft_drops_to_the_ground() -> void:
	var def: UnitDefinition = load(HELI_PATH)
	var weapon: WeaponDefinition = load("res://data/weapons/heli_gun.tres")
	var a := BattleAircraft.new()
	a.setup(1, def, weapon, Vector2i(8, 8))
	tree.root.add_child(a)
	assert_true(a.altitude > 0.0)
	assert_vec_near(a._sprite_lift(), Vector2.ZERO, 1e-9, "node is already lifted")
	assert_near(a.chest_world().y, a.position.y - def.sprite.chest_px, 1e-6, "hit point not lifted twice")
	var gp := a.ground_pos
	a._set_altitude(0.0)
	assert_vec_near(a.position, IsoProjection.ground_to_screen(gp), 1e-6, "falling keeps the node on its ground point")
	a.free()


func test_walk_animation_speed_follows_move_speed_when_a_stride_is_set() -> void:
	var s := SpriteSheet.new()
	s.stride_tiles = 0.5  # one 4-frame cycle per 0.5 tiles
	s.walk_fps = 8.0
	# At 1 tile/s the cycle takes 0.5 s, i.e. 8 frames/s; at 2 tiles/s it takes 0.25 s (16 frames/s).
	assert_eq(s.walk_frame(0.124, 1.0), s.walk_first, "just under one frame at 8 fps")
	assert_eq(s.walk_frame(0.126, 1.0), s.walk_first + 1)
	assert_eq(s.walk_frame(0.126, 2.0), s.walk_first + 2, "twice the speed, twice the frame rate")
	s.stride_tiles = 0.0
	assert_eq(s.walk_frame(0.126, 2.0), s.walk_first + 1, "no stride -> fixed walk_fps")


func test_shipped_walkers_have_speed_synced_strides_and_the_soldier_a_fire_frame() -> void:
	for path in [SOLDIER_PATH, SHAMBLER_PATH, TANK_PATH]:
		assert_true((load(path) as Resource).sprite.stride_tiles > 0.0, "%s sets a stride" % path)
	var soldier: SpriteSheet = load(SOLDIER_PATH).sprite
	assert_true(soldier.fire_frame >= 0, "soldier has a recoil frame")
	var needed := soldier.frame_region(soldier.fire_frame)
	var tex: Texture2D = soldier.textures["E"]
	assert_true(needed.end.y <= tex.get_height(), "the fire frame lies inside the sheet")


func test_a_shot_shows_the_fire_frame_briefly_and_only_while_standing() -> void:
	var def: UnitDefinition = load(SOLDIER_PATH)
	var u := BattleUnit.new()
	u.setup(1, def, load("res://data/weapons/rifle.tres"), Vector2i(5, 5))
	u.kick(Vector2(1, 0.5))
	u._process(0.02)
	assert_eq(u._frame, def.sprite.fire_frame, "recoil frame right after the shot")
	u._process(BattleUnit.FIRE_FRAME_S + 0.05)
	u._process(0.01)
	assert_eq(u._frame, def.sprite.idle_frame, "back to idle once the moment has passed")
	u.free()


func test_enemy_stagger_is_draw_only_and_settles() -> void:
	var def: EnemyDefinition = load(SHAMBLER_PATH)
	var e := BattleEnemy.new()
	var wps: Array[Vector2] = [Vector2(10, 10)]
	e.setup(1, def, Vector2(6, 6), wps)
	var anchor := e.position
	var key := e.sort_key()
	e.stagger(Vector2(3, 0))
	assert_near(e._stagger.length(), BattleEnemy.STAGGER_PX, 1e-6)
	assert_vec_near(e.position, anchor, 1e-9, "the sort anchor never moves")
	e._process(1.0)
	assert_vec_near(e._stagger, Vector2.ZERO, 1e-9, "settles back")
	assert_near(e.sort_key(), key, 1e-9)
	e.stagger(Vector2.ZERO)
	assert_vec_near(e._stagger, Vector2.ZERO, 1e-9, "a zero direction does nothing")
	e.free()

