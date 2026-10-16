extends TestCase
## Lighting pass 2 (docs/specs/lighting-pass-2.md): the pure parts (flicker, light selection, shadow volumes, ground
## tables, rain brightening, time-of-day functions) and that a battle builds with all of it, headless.

var _db: ContentDb
var _made: Array[BattleController] = []


func _get_db() -> ContentDb:
	if _db == null:
		_db = ContentDb.load_from()
	return _db


func _battle(mission_id: String) -> BattleController:
	var b := BattleController.new()
	b.auto_step = false
	b.setup(_get_db(), _get_db().mission(mission_id), 1)
	_made.append(b)
	return b


func _release() -> void:
	for b in _made:
		b.free()
	_made.clear()


func _item(ground: Vector2, r: float = 40.0) -> Dictionary:
	var pr := r * LightingConfig.POOL_SHARE
	return {"ground": ground, "pos": ground, "r": r, "pr": pr, "c": Color(1, 0.9, 0.6), "k": 1.0,
		"bounds": Rect2(ground - Vector2(pr, pr), Vector2(pr, pr) * 2.0)}


# --- config ----------------------------------------------------------------------------------------------------

func test_config_values_are_sane() -> void:
	assert_true(LightingConfig.MAX_LIGHTS > 0 and LightingConfig.MAX_FLASHES > 0 and LightingConfig.GROUND_LIGHTS <= GroundLook.MAX_LIGHTS)
	assert_true(LightingConfig.BLOOM_THRESHOLD > 0.3 and LightingConfig.BLOOM_THRESHOLD < 1.0, "bloom only takes the brightest pixels")
	assert_true(LightingConfig.FLICKER_FIRE > LightingConfig.FLICKER_LAMP, "a fire flickers more than a lamp")
	assert_true(LightingConfig.SMOKE_MAX_PUFFS > 0 and LightingConfig.DUST_MAX_PUFFS > 0)
	assert_true(LightingConfig.RAIN_FAR_ALPHA < LightingConfig.RAIN_NEAR_ALPHA, "far rain is fainter than near rain")


func test_shaders_load() -> void:
	for p in ["post_fx", "post_overlay", "ground", "sway"]:
		assert_true(load("res://assets/shaders/%s.gdshader" % p) is Shader, "%s loads" % p)


# --- time of day -----------------------------------------------------------------------------------------------

func test_sky_and_shadow_scale_are_continuous_and_bounded() -> void:
	var prev_sky := DayNight.sky_at(0.0)
	var prev_len := DayNight.shadow_scale_at(0.0)
	for i in range(1, 101):
		var t := float(i) / 100.0
		var sky := DayNight.sky_at(t)
		var len := DayNight.shadow_scale_at(t)
		assert_true(absf(sky.r - prev_sky.r) < 0.25 and absf(sky.b - prev_sky.b) < 0.25, "no jump in the sky at %d%%" % i)
		assert_true(absf(len - prev_len) < 0.4, "no jump in the shadow length at %d%%" % i)
		assert_true(len > 0.4 and len < 2.5)
		prev_sky = sky
		prev_len = len
	assert_true(DayNight.sky_at(0.0).get_luminance() < 0.15, "the night sky is dark")
	assert_true(DayNight.sky_at(0.5).get_luminance() > 0.5, "the day sky is pale")
	assert_true(DayNight.shadow_scale_at(0.5) < DayNight.shadow_scale_at(0.27), "shadows are shortest at noon, long at dawn")


# --- flicker and selection -------------------------------------------------------------------------------------

func test_flicker_stays_in_range_and_fires_vary_more_than_lamps() -> void:
	var lamp_min := 1.0
	var fire_min := 1.0
	for i in 400:
		var t := float(i) * 0.05
		var l := LightField.flicker_at(false, 1.3, t)
		var f := LightField.flicker_at(true, 1.3, t)
		assert_true(l <= 1.0 and l >= 1.0 - LightingConfig.FLICKER_LAMP - 1e-6)
		assert_true(f <= 1.0 and f >= 1.0 - LightingConfig.FLICKER_FIRE - 1e-6)
		lamp_min = minf(lamp_min, l)
		fire_min = minf(fire_min, f)
	assert_true(fire_min < lamp_min, "the fire dips deeper")
	assert_eq(LightField.flicker_at(true, 2.0, 3.3), LightField.flicker_at(true, 2.0, 3.3), "deterministic")
	assert_true(not is_equal_approx(LightField.flicker_at(true, 0.0, 1.0), LightField.flicker_at(true, 2.0, 1.0)), "neighbours do not pulse together")


func test_fire_colours_are_told_from_lamps() -> void:
	assert_true(LightField.is_fire(Color(1.0, 0.5, 0.15)))
	assert_true(LightField.is_fire(Color(1.0, 0.55, 0.2)))
	assert_true(not LightField.is_fire(Color(1.0, 0.95, 0.8)), "a floodlight is not a fire")
	assert_true(not LightField.is_fire(Color(1.0, 0.25, 0.15)), "a red traffic light is not a fire")
	assert_true(not LightField.is_fire(Color(0.7, 0.9, 1.0)))


func test_pick_culls_off_screen_lights_and_keeps_the_nearest_within_the_cap() -> void:
	var items: Array[Dictionary] = []
	for i in 10:
		items.append(_item(Vector2(100.0 * i, 0.0)))
	items.append(_item(Vector2(100000.0, 0.0)))
	var view := Rect2(-100, -100, 1000, 200)
	var all := LightField.pick(items, view, Vector2(0, 0), 50)
	assert_true(all.size() >= 9 and all.size() <= 10, "the far light is culled (%d kept)" % all.size())
	var few := LightField.pick(items, view, Vector2(0, 0), 3)
	assert_eq(few.size(), 3)
	for f in few:
		assert_true((f["ground"] as Vector2).x <= 200.0, "nearest first")


# --- shadow volumes --------------------------------------------------------------------------------------------

func test_a_wall_shades_the_ground_behind_it_away_from_the_light() -> void:
	var box := Rect2(10.0, 10.0, 1.0, 1.0)
	var light := Vector2(7.0, 10.5)
	var poly := LightShadows.volume(box, 1.5, light, 2.4, 6.0)
	assert_true(poly.size() >= 3, "a shadow exists")
	var far := -INF
	for p in poly:
		far = maxf(far, p.x)
	assert_true(far > 11.5, "it reaches beyond the wall's far side (%.2f)" % far)
	for p in poly:
		assert_true(p.distance_to(light) <= 6.01, "and stays inside the light's reach")


func test_no_shadow_when_the_light_is_inside_or_the_wall_is_out_of_reach() -> void:
	assert_true(LightShadows.volume(Rect2(10, 10, 2, 2), 2.0, Vector2(11, 11), 2.4, 6.0).is_empty(), "light inside the box")
	assert_true(LightShadows.volume(Rect2(40, 40, 1, 1), 2.0, Vector2(7, 7), 2.4, 6.0).is_empty(), "out of reach")


func test_a_lower_wall_throws_a_shorter_shadow() -> void:
	var box := Rect2(10.0, 10.0, 1.0, 1.0)
	var light := Vector2(6.0, 10.5)
	var tall := LightShadows.volume(box, 2.2, light, 4.0, 20.0)
	var low := LightShadows.volume(box, 0.9, light, 4.0, 20.0)
	var tall_x := -INF
	var low_x := -INF
	for p in tall:
		tall_x = maxf(tall_x, p.x)
	for p in low:
		low_x = maxf(low_x, p.x)
	assert_true(tall_x > low_x, "tall %.2f beyond low %.2f" % [tall_x, low_x])


func test_thin_and_low_pieces_do_not_block_lamps_but_buildings_do() -> void:
	var db := _get_db()
	assert_true(not LightShadows.blocks_light(db.scenery("street_lamp")), "a lamp post is too thin")
	assert_true(not LightShadows.blocks_light(db.scenery("rubble_field")), "rubble is too low")
	assert_true(LightShadows.blocks_light(db.scenery("house_small")), "a house blocks the light")


func test_light_shadows_are_capped_per_light() -> void:
	var b := _battle("x3_storm_night")
	for s in b.scenery_nodes:
		if s.def.glow_radius > 0.0:
			var vols := LightShadows.around(s.ground_pos, 2.4, 6.0, b.scenery_nodes, s, 3)
			assert_true(vols.size() <= 3, "at most the cap")
	_release()


# --- ground, rain, foam ----------------------------------------------------------------------------------------

func test_ground_tables_follow_the_terrain_catalog() -> void:
	assert_true(TerrainCatalog.count() <= GroundLook.MAX_ROWS)
	var wet := GroundLook.wet_table()
	var water := GroundLook.water_table()
	assert_eq(wet.size(), GroundLook.MAX_ROWS)
	assert_true(wet[TerrainCatalog.row_of("a")] > 0.5, "asphalt is slick")
	assert_eq(wet[TerrainCatalog.row_of(".")], 0.0, "grass soaks it up")
	assert_eq(water[TerrainCatalog.row_of("w")], 1.0)
	assert_eq(water[TerrainCatalog.row_of("~")], 1.0)
	assert_eq(water[TerrainCatalog.row_of("a")], 0.0)


func test_pack_lights_takes_the_nearest_and_pads_the_arrays() -> void:
	var lights: Array[Dictionary] = []
	for i in 12:
		lights.append(_item(Vector2(50.0 * i, 0.0)))
	var off := _item(Vector2(5.0, 0.0))
	off["k"] = 0.0
	lights.append(off)
	var p := GroundLook.pack_lights(lights, Vector2.ZERO, 8)
	assert_eq(p["count"], GroundLook.MAX_LIGHTS, "never more than the shader holds")
	assert_eq((p["a"] as PackedVector4Array).size(), GroundLook.MAX_LIGHTS)
	assert_true(not is_equal_approx((p["a"] as PackedVector4Array)[0].x, 5.0), "a light that is off is skipped")
	var few := GroundLook.pack_lights([_item(Vector2.ZERO)] as Array[Dictionary], Vector2.ZERO, 8)
	assert_eq(few["count"], 1)


func test_rain_is_brighter_where_it_passes_through_a_light() -> void:
	var lights: Array[Dictionary] = [{"c": Vector2(500, 500), "b": Vector2(500, 380), "r": 120.0, "k": 1.0}]
	assert_true(WeatherView.light_amount(Vector2(500, 500), lights) > 0.8, "in the pool")
	assert_true(WeatherView.light_amount(Vector2(500, 440), lights) > 0.3, "in the cone under the bulb")
	assert_eq(WeatherView.light_amount(Vector2(900, 500), lights), 0.0, "far away")
	assert_eq(WeatherView.light_amount(Vector2(500, 500), [] as Array[Dictionary]), 0.0)


func test_the_outskirts_river_has_foam_edges() -> void:
	var map := _get_db().mission("x2_outskirts").map
	var edges := ShoreFoam.bank_edges(map)
	assert_true(edges.size() > 10, "%d bank edges" % edges.size())
	for e in edges:
		assert_true(e[0].x >= -0.2 and e[0].y >= -0.2 and e[0].x <= map.width() + 0.2 and e[0].y <= map.height() + 0.2)


# --- post pass numbers -----------------------------------------------------------------------------------------

func test_mist_and_clouds_follow_the_hour_and_weather() -> void:
	assert_true(PostFx.mist_for(1.0, "clear") > PostFx.mist_for(0.0, "clear"), "more mist at night")
	assert_true(PostFx.mist_for(1.0, "rain") > PostFx.mist_for(1.0, "clear"), "and in rain")
	assert_true(PostFx.cloud_for("clear") > PostFx.cloud_for("rain"), "fewer cloud shadows under an overcast sky")


# --- a battle with all of it -----------------------------------------------------------------------------------

func test_a_night_battle_builds_every_layer_of_the_pass() -> void:
	var b := _battle("x3_storm_night")
	var atm := Atmosphere.new()
	atm.bind(b)
	var glow := b.get_node("Glows") as LightField
	assert_true(glow.item_count() >= 10, "lights collected (%d)" % glow.item_count())
	assert_true(glow.shadow_count() > 0, "walls shade the lights")
	assert_true(atm.get_node_or_null("PostFx") != null)
	assert_true(b.get_node_or_null("Ground") != null and (b.get_node("Ground") as TileMapLayer).material is ShaderMaterial, "the ground has its shader")
	glow.add_flash(Vector2.ZERO, 60.0, 0.1, Color.WHITE)
	assert_eq(glow.flash_count(), 1)
	for i in 100:
		glow.add_flash(Vector2.ZERO, 60.0, 0.1, Color.WHITE)
	assert_true(glow.flash_count() <= LightingConfig.MAX_FLASHES, "flashes are capped")
	atm.free()
	_release()


func test_a_day_battle_keeps_lights_off_and_still_has_fires_for_smoke() -> void:
	var b := _battle("x2_outskirts")
	var atm := Atmosphere.new()
	atm.bind(b)
	assert_true(not (b.get_node("Glows") as LightField).visible, "no lamps by day")
	assert_true((b.get_node("Ambient") as AmbientFx).fire_count() > 0, "burning pieces smoke")
	atm.free()
	_release()


func test_sun_scale_lengthens_the_shadows() -> void:
	var db := _get_db()
	var noon := SceneryShadows.polygon_for(db.scenery("oak_tree"), Vector2i(10, 10), 0.6)
	var dusk := SceneryShadows.polygon_for(db.scenery("oak_tree"), Vector2i(10, 10), 2.0)
	var noon_x := -INF
	var dusk_x := -INF
	for p in noon:
		noon_x = maxf(noon_x, p.x)
	for p in dusk:
		dusk_x = maxf(dusk_x, p.x)
	assert_true(dusk_x > noon_x, "longer at dusk")


func test_trees_sway_and_lamps_do_not() -> void:
	var db := _get_db()
	assert_true(db.scenery("oak_tree").sway > 0.0)
	assert_true(db.scenery("willow_tree").sway > 0.0)
	assert_eq(db.scenery("street_lamp").sway, 0.0)
	var node := BattleScenery.new()
	node.setup_scenery(db.scenery("oak_tree"), Vector2i(3, 3), IsoProjection.Facing.SE)
	assert_true(node.material is ShaderMaterial, "a tree uses the sway material")
	var lamp := BattleScenery.new()
	lamp.setup_scenery(db.scenery("street_lamp"), Vector2i(3, 3), IsoProjection.Facing.SE)
	assert_true(lamp.material == null)
	node.free()
	lamp.free()
