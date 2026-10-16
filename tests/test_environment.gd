extends TestCase
## Terrain variety, scenery, the base art and the atmosphere (docs/specs/environment.md).

const DT: float = 1.0 / 60.0

var _db: ContentDb
var _made: Array[BattleController] = []


func _get_db() -> ContentDb:
	if _db == null:
		_db = ContentDb.load_from()
	return _db


func _battle(mission_id: String = "x2_outskirts") -> BattleController:
	var b := BattleController.new()
	b.auto_step = false
	b.setup(_get_db(), _get_db().mission(mission_id), 1)
	_made.append(b)
	return b


func _release() -> void:
	for b in _made:
		b.free()
	_made.clear()


func _has(errs: PackedStringArray, needle: String) -> bool:
	for e in errs:
		if needle in e:
			return true
	return false


func _def(id: String, fp: Vector2i = Vector2i.ONE) -> SceneryDefinition:
	var d := SceneryDefinition.new()
	d.id = id
	d.display_name = id
	d.footprint = fp
	var sheet := SpriteSheet.new()
	sheet.textures = {"SE": PlaceholderTexture2D.new()}
	d.sprite = sheet
	return d


func _map(rows: Array, scenery: Array = []) -> MapDefinition:
	var m := MapDefinition.new()
	m.id = "t_map"
	m.rows = PackedStringArray(rows)
	m.scenery = PackedStringArray(scenery)
	return m


# --- terrain ----------------------------------------------------------------------------------------------

func test_new_terrain_characters_have_the_right_rules() -> void:
	for ch in [",", "p"]:
		assert_true(MapDefinition.char_is_walkable(ch) and MapDefinition.char_is_buildable(ch), "'%s' is open ground" % ch)
	assert_true(MapDefinition.char_is_walkable("x") and not MapDefinition.char_is_buildable("x"), "rubble can be crossed but not built on")
	assert_true(not MapDefinition.char_is_walkable("w") and not MapDefinition.char_is_buildable("w"), "water blocks")
	assert_eq(_map(["..,pxw="]).validate().size(), 0)


func test_tile_variants_are_deterministic_and_variant_zero_is_the_common_look() -> void:
	var counts := [0, 0, 0, 0]
	for y in 50:
		for x in 50:
			var v := IsoTileSet.variant_for(Vector2i(x, y))
			assert_eq(v, IsoTileSet.variant_for(Vector2i(x, y)), "same cell, same variant")
			assert_true(v >= 0 and v < IsoTileSet.VARIANTS)
			counts[v] += 1
	assert_true(counts[0] > counts[1] and counts[0] > counts[2] and counts[0] > counts[3], "plain tiles dominate")
	for c in counts:
		assert_true(c > 0, "every variant shows up")


func test_variants_never_change_the_flags_and_unknown_characters_fall_back_to_grass() -> void:
	var coords := IsoTileSet.coords_for("w", Vector2i(3, 4))
	assert_eq(coords.y, IsoTileSet.terrain_row("w"))
	assert_eq(IsoTileSet.coords_for("?", Vector2i(1, 1)).y, IsoTileSet.terrain_row("."))
	assert_eq(IsoTileSet.terrain_row("?"), -1)


func test_the_generated_atlas_matches_the_layout_the_tileset_expects() -> void:
	var tex := load(IsoTileSet.ATLAS_PATH) as Texture2D
	assert_true(tex != null, "terrain.png loads")
	if tex != null:
		assert_eq(tex.get_size(), Vector2(IsoProjection.TILE_W * IsoTileSet.VARIANTS, IsoProjection.TILE_H * TerrainCatalog.count()))
		var img := tex.get_image()
		for row in TerrainCatalog.count():
			for v in IsoTileSet.VARIANTS:
				assert_true(img.get_pixel(v * 64 + 32, row * 32 + 16).a > 0.9, "tile (%d, %d) is painted in the middle" % [v, row])
				assert_true(img.get_pixel(v * 64, row * 32).a < 0.1, "tile (%d, %d) is transparent in the corner" % [v, row])


# --- scenery data -----------------------------------------------------------------------------------------

func test_scenery_lines_parse_with_and_without_a_facing() -> void:
	var p := SceneryPlacement.parse("oak_tree 12 7")
	assert_true(p != null and p.scenery_id == "oak_tree" and p.cell == Vector2i(12, 7) and p.facing == IsoProjection.Facing.SE)
	var q := SceneryPlacement.parse("  wall 3 4 sw ")
	assert_true(q != null and q.facing == IsoProjection.Facing.SW)
	assert_eq(q.to_line(), "wall 3 4 sw")
	for bad in ["", "oak_tree", "oak_tree 1", "oak_tree x 2", "oak_tree 1 2 up", "a 1 2 se extra"]:
		assert_true(SceneryPlacement.parse(bad) == null, "'%s' is rejected" % bad)


func test_a_map_reports_malformed_and_off_map_scenery() -> void:
	assert_true(_has(_map(["...", "..."], ["oak 1"]).validate(), "malformed"))
	assert_true(_has(_map(["...", "..."], ["oak 5 5"]).validate(), "outside the map"))
	assert_eq(_map(["...", "..."], ["oak 1 1"]).validate().size(), 0)


func test_scenery_definition_needs_art_a_name_and_a_footprint() -> void:
	assert_eq(_def("tree").validate().size(), 0)
	var bad := _def("tree", Vector2i(0, 1))
	bad.sprite = null
	bad.display_name = ""
	var errs := bad.validate()
	for needle in ["sprite", "display_name", "footprint"]:
		assert_true(_has(errs, needle), needle)
	assert_eq(_def("big", Vector2i(2, 3)).cells_at(Vector2i(1, 1)).size(), 6)
	assert_vec_near(_def("big", Vector2i(2, 3)).center_at(Vector2i(1, 1)), Vector2(2.0, 2.5))


func _mini_db(map: MapDefinition, defs: Array) -> ContentDb:
	var db := ContentDb.new()
	for d in defs:
		db.add_scenery(d)
	db.add_map(map)
	return db


func test_content_db_rejects_unknown_overlapping_and_off_map_scenery() -> void:
	var tree := _def("tree")
	var house := _def("house", Vector2i(2, 2))
	var db := _mini_db(_map(["....", "....", "....", "...."], ["ghost 0 0"]), [tree])
	db.validate_references()
	assert_true(_has(db.errors, "unknown scenery id 'ghost'"))
	db = _mini_db(_map(["....", "....", "....", "...."], ["house 0 0", "tree 1 1"]), [tree, house])
	db.validate_references()
	assert_true(_has(db.errors, "overlaps"))
	db = _mini_db(_map(["....", "....", "....", "...."], ["house 3 3"]), [house])
	db.validate_references()
	assert_true(_has(db.errors, "does not fit"))


func test_a_mission_may_not_route_enemies_through_scenery_or_cover_its_core() -> void:
	var tree := _def("tree")
	var m := _map(["......", "......", "......"], ["tree 3 1", "tree 0 0"])
	var mission := MissionDefinition.new()
	mission.id = "t_mission"
	mission.display_name = "Test"
	mission.core_health = 100.0
	mission.duration_s = 60.0
	var wave := WaveEntry.new()
	wave.enemy_id = "shambler"
	mission.waves = [wave]
	mission.map = m
	mission.core_cell = Vector2i(0, 0)
	mission.spawn_cells = [Vector2i(5, 1)]
	mission.path_cells = [Vector2i(0, 0)]
	var db := _mini_db(m, [tree])
	db.add_mission(mission)
	db.validate_references()
	assert_true(_has(db.errors, "crosses scenery"), "the line from (5, 1) to (0, 0) passes the tree at (3, 1)")
	assert_true(_has(db.errors, "covered by scenery"), "the core cell is under a tree")


func test_shipped_scenery_and_the_outskirts_map_are_valid() -> void:
	var db := _get_db()
	assert_true(db.is_valid(), "\n".join(db.errors))
	assert_true(db.scenery_defs.size() >= 70, "the scenery library is there")
	for id in db.scenery_defs:
		var d: SceneryDefinition = db.scenery_defs[id]
		assert_true(d.sprite.frame_size.x > 0 and d.sprite.frame_size.y > 0 and d.sprite.texture_for(IsoProjection.Facing.SE) != null, "%s has art" % id)
	var map := db.map("outskirts")
	assert_true(map != null)
	assert_eq(map.width(), 64)
	assert_eq(map.height(), 48)
	assert_true(map.placements().size() > 200, "a populated map")
	var chars := {}
	for row in map.rows:
		for i in row.length():
			chars[row[i]] = true
	for ch in [".", "=", "#", ",", "p", "x", "w"]:
		assert_true(chars.has(ch), "the map uses terrain '%s'" % ch)


func test_the_outskirts_missions_use_the_base_art_both_spawns_and_the_new_enemies() -> void:
	var db := _get_db()
	for id in ["x2_outskirts", "x3_storm_night"]:
		var m := db.mission(id)
		assert_true(m != null, id)
		assert_eq(m.map.id, "outskirts")
		assert_eq(m.spawn_cells.size(), 2)
		assert_eq(m.core_scenery_id, "hq_bunker")
		assert_true(m.core_radius > 0.0)
		var kinds := {}
		var spawns := {}
		for w in m.waves:
			kinds[w.enemy_id] = true
			spawns[w.spawn_index] = true
		for e in ["shambler", "runner", "brute", "spitter"]:
			assert_true(kinds.has(e), "%s appears in %s" % [e, id])
		assert_eq(spawns.size(), 2, "both spawn points are used")
	assert_eq(db.mission("x3_storm_night").weather, "rain")
	assert_near(db.mission("x3_storm_night").time_of_day, 0.0)


func test_mission_look_settings_are_validated() -> void:
	var m := _get_db().mission("x2_outskirts").duplicate() as MissionDefinition
	m.weather = "tornado"
	assert_true(_has(m.validate(), "weather"))
	m.weather = "fog"
	m.day_length_s = -1.0
	assert_true(_has(m.validate(), "day_length_s"))
	m.day_length_s = 60.0
	m.core_radius = -0.5
	assert_true(_has(m.validate(), "core_radius"))
	m.core_radius = 1.0
	assert_eq(m.validate().size(), 0)


# --- in battle --------------------------------------------------------------------------------------------

func test_scenery_is_spawned_and_blocks_building() -> void:
	var b := _battle()
	assert_eq(b.scenery_nodes.size(), b.mission.map.placements().size())
	var occupied := b.occupied_cells()
	var p := b.mission.map.placements()[0]
	for c in b.db.scenery(p.scenery_id).cells_at(p.cell):
		assert_true(occupied.has(c), "%s covers %s" % [p.scenery_id, str(c)])
	assert_true(occupied.has(Vector2i(6, 32)), "a base tent covers its cells")
	_release()


func test_a_card_cannot_be_placed_on_scenery() -> void:
	var b := _battle()
	b.deck.hand = ["sandbags"] as Array[String]
	b.points.cp = 5.0
	var res := b.check_card(0, Vector2i(6, 33))  # inside the first tent
	assert_true(not res.ok and res.placement == PlacementRules.Reason.OCCUPIED)
	_release()


func test_the_core_reserves_the_cells_under_its_walls() -> void:
	var b := _battle()
	assert_true(b.core.radius > 1.0 and b.core.art != null)
	var occupied := b.occupied_cells()
	for c in [Vector2i(10, 38), Vector2i(12, 38), Vector2i(11, 37), Vector2i(11, 39)]:
		assert_true(occupied.has(c), "%s is under the bunker" % str(c))
	_release()


func test_enemies_attack_the_bunker_walls_instead_of_walking_into_it() -> void:
	var b := _battle()
	for u in b.units:  # no defenders, so nothing shoots the enemy before it swings
		u.health.take_damage(1e6)
	b.step(DT)
	var w := WaveEntry.new()
	w.enemy_id = "shambler"
	b._spawn_enemy(w)
	var e: BattleEnemy = b.enemies.back()
	e.ground_pos = b.core.ground_pos + Vector2(1.2 + 0.6, 0.0)  # 0.6 tiles from the wall, within a melee reach of 0.8
	var at := e.ground_pos
	for i in 180:
		b.step(DT)
	assert_vec_near(e.ground_pos, at, 1e-6, "it stays where it is and attacks")
	assert_true(b.core.health.hp < b.core.health.max_hp, "the core took the hits")
	_release()


func test_core_frame_follows_hit_points() -> void:
	assert_eq(BattleCore.frame_for(1.0), 0)
	assert_eq(BattleCore.frame_for(0.67), 0)
	assert_eq(BattleCore.frame_for(0.5), 1)
	assert_eq(BattleCore.frame_for(0.2), 2)
	assert_eq(BattleCore.frame_for(0.0), 3)


func test_tall_scenery_fades_when_a_unit_stands_behind_it_and_returns_when_it_leaves() -> void:
	var b := _battle()
	var piece: BattleScenery = null
	for s in b.scenery_nodes:
		if s.def.fades and s.def.id == "oak_tree":
			piece = s
			break
	assert_true(piece != null, "the map has an oak")
	var unit := b._spawn_unit_at("rifle_soldier", piece.ground_pos + Vector2(-0.35, -0.35))
	for i in 20:
		b.update_scenery_fade(0.05)
	assert_true(piece.faded and piece.modulate.a < 0.5, "the oak is see-through with a soldier behind it")
	unit.ground_pos = piece.ground_pos + Vector2(6.0, 6.0)  # in front, far away
	for i in 20:
		b.update_scenery_fade(0.05)
	assert_true(not piece.faded and piece.modulate.a > 0.99, "and solid again afterwards")
	_release()


# --- atmosphere -------------------------------------------------------------------------------------------

func test_time_of_day_wraps_and_freezes() -> void:
	assert_near(DayNight.time_at(0.9, 100.0, 20.0), 0.1, 1e-9)
	assert_near(DayNight.time_at(0.4, 0.0, 9999.0), 0.4, 1e-9)
	assert_near(DayNight.time_at(1.0, 0.0, 5.0), 0.0, 1e-9)


func test_noon_is_white_midnight_is_dark_blue_and_the_loop_is_seamless() -> void:
	var noon := DayNight.tint_at(0.5)
	assert_true(noon.r > 0.98 and noon.g > 0.98 and noon.b > 0.98)
	var night := DayNight.tint_at(0.0)
	assert_true(night.b > night.r and night.r < 0.4, "bluish and dark")
	assert_true(DayNight.tint_at(0.0).is_equal_approx(DayNight.tint_at(1.0)))
	var prev := DayNight.tint_at(0.0)
	for i in range(1, 101):
		var c := DayNight.tint_at(float(i) / 100.0)
		assert_true(absf(c.r - prev.r) < 0.2 and absf(c.g - prev.g) < 0.2 and absf(c.b - prev.b) < 0.2, "no jump at %d%%" % i)
		prev = c
	assert_true(DayNight.tint_at(0.27).r > DayNight.tint_at(0.27).b, "sunrise is warm")


func test_darkness_is_zero_at_noon_and_one_at_midnight() -> void:
	assert_near(DayNight.darkness_at(0.5), 0.0, 1e-9)
	assert_near(DayNight.darkness_at(0.0), 1.0, 0.05)
	assert_true(DayNight.darkness_at(0.76) > 0.0 and DayNight.darkness_at(0.76) < 1.0, "dusk is in between")


func test_weather_names_and_tints() -> void:
	for w in ["clear", "rain", "fog", "dust"]:
		assert_true(DayNight.is_weather(w))
	assert_true(not DayNight.is_weather("hail"))
	assert_true(DayNight.weather_tint("clear").is_equal_approx(Color.WHITE))
	assert_true(DayNight.weather_tint("rain").r < 1.0, "rain dims the light")


func test_atmosphere_tints_the_world_and_keeps_effects_bright() -> void:
	var b := _battle("x3_storm_night")
	var atm := Atmosphere.new()
	atm.bind(b)
	var tint: CanvasModulate = b.get_node("Tint")
	var want := DayNight.tint_at(0.0) * DayNight.weather_tint("rain")
	assert_true(absf(tint.color.r - want.r) < 0.01 and absf(tint.color.b - want.b) < 0.01, "the night tint is applied")
	var fx := b.fx_layer()
	assert_near(fx.modulate.r * tint.color.r, 1.0, 0.02, "effects cancel the tint on their own layer")
	atm.free()
	_release()


func test_night_lights_the_lamps_and_day_does_not() -> void:
	var night := _battle("x3_storm_night")
	var atm_n := Atmosphere.new()
	atm_n.bind(night)
	assert_true((night.get_node("Glows") as Node2D).visible, "glows are on at midnight")
	var day := _battle("x2_outskirts")
	var atm_d := Atmosphere.new()
	atm_d.bind(day)
	assert_true(not (day.get_node("Glows") as Node2D).visible, "and off at 10 in the morning")
	atm_n.free()
	atm_d.free()
	_release()


func test_lamps_and_fires_have_glow_data() -> void:
	var db := _get_db()
	for id in ["street_lamp", "floodlight", "watchtower", "gate_post", "house_burnt", "apartment_burnt"]:
		assert_true(db.scenery(id).glow_radius > 0.0, "%s glows" % id)
	assert_true(db.scenery("oak_tree").glow_radius == 0.0)
