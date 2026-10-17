extends TestCase
## The five field-command missions and maps (docs/specs/field-command.md, F4): valid data, really different maps, routes
## on buildable ground, decks that use the new roster, a short battle on each, and the mission list order.

const DT: float = 1.0 / 60.0
const MISSIONS: Array[String] = ["x7_bridge_line", "x8_dead_highway", "x9_last_airfield", "x10_town_siege", "x11_mountain_pass"]
const MAPS: Array[String] = ["bridge_line", "dead_highway", "last_airfield", "town_siege", "mountain_pass"]

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


func test_the_five_missions_load_and_are_valid() -> void:
	var db := _get_db()
	assert_true(db.is_valid(), "content errors: %s" % ", ".join(db.errors))
	for id in MISSIONS:
		var m := db.mission(id)
		assert_true(m != null, id)
		assert_eq(m.validate().size(), 0, id)
		assert_eq(m.deploy_radius, 0.0, "%s: build anywhere" % id)
		assert_true(m.total_enemies() >= 700, "%s is a long fight (%d enemies)" % [id, m.total_enemies()])
		assert_true(m.spawn_cells.size() == 2, "%s has two spawns" % id)


func test_every_mission_has_its_own_map_and_they_differ_in_shape() -> void:
	var db := _get_db()
	var sizes: Dictionary = {}
	var seen_maps: Dictionary = {}
	for id in MISSIONS:
		var m := db.mission(id)
		assert_true(MAPS.has(m.map.id), "%s uses one of the new maps" % id)
		assert_true(not seen_maps.has(m.map.id), "no two missions share a map")
		seen_maps[m.map.id] = true
		sizes[Vector2i(m.map.width(), m.map.height())] = true
	assert_eq(sizes.size(), 5, "five different map sizes")
	var weathers: Dictionary = {}
	for id in MISSIONS:
		weathers[db.mission(id).weather] = true
	assert_true(weathers.size() >= 3, "rain, dust, clear and fog are all used")


func test_the_enemy_route_runs_over_buildable_roads() -> void:
	var db := _get_db()
	for id in MISSIONS:
		var m := db.mission(id)
		var route := m.spawn_cells[0]
		var cells: Array[Vector2i] = [m.core_cell]
		cells.append_array(m.path_cells)
		for c in cells:
			assert_true(m.map.is_walkable(c), "%s %s walkable" % [id, str(c)])
		var bridge_or_road := 0
		for i in range(1, m.path_cells.size()):
			var a := Vector2(m.path_cells[i - 1])
			var b := Vector2(m.path_cells[i])
			for k in 11:
				var p := a.lerp(b, float(k) / 10.0)
				if m.map.is_buildable(Vector2i(roundi(p.x), roundi(p.y))):
					bridge_or_road += 1
		assert_true(bridge_or_road > 0, "%s: the player can build on the road" % id)
		assert_true(route != m.core_cell)


func test_the_bridge_is_planks_and_the_broken_bridge_has_a_gap() -> void:
	var map := _get_db().mission("x7_bridge_line").map
	assert_eq(map.terrain_char(Vector2i(26, 22)), "z", "the working bridge is wood planks (walkable, buildable)")
	assert_true(map.is_walkable(Vector2i(26, 22)) and map.is_buildable(Vector2i(26, 22)))
	assert_eq(map.terrain_char(Vector2i(26, 9)), "w", "the northern bridge is out")
	assert_true(not map.is_walkable(Vector2i(26, 9)))


func test_the_pass_has_walls_and_open_ground_behind_them() -> void:
	var m := _get_db().mission("x11_mountain_pass")
	var rocks := 0
	for y in m.map.height():
		for x in m.map.width():
			if m.map.terrain_char(Vector2i(x, y)) == "#":
				rocks += 1
	assert_true(rocks > 200, "ridges of rock line the pass (%d rock cells)" % rocks)
	assert_true(m.map.is_buildable(Vector2i(2, 30)) and m.map.is_buildable(Vector2i(40, 30)), "the highlands behind the ridges can be built on")


func test_the_decks_are_legal_and_bring_the_new_roster() -> void:
	var db := _get_db()
	for id in ["field_arms", "field_siege"]:
		var deck := db.deck(id)
		assert_true(deck != null, id)
		var ids: Array[String] = []
		ids.assign(deck.card_ids)
		assert_eq(db.deck_rules.validate_deck(ids, db.cards).size(), 0, id)
		for card in ["marksman_team", "mortar_team", "rocket_launcher"]:
			assert_true(ids.has(card), "%s holds %s" % [id, card])
	assert_true(db.deck("field_arms").card_ids.has("ifv") and db.deck("field_arms").card_ids.has("scout_jeep"))
	for id in MISSIONS:
		assert_true(["field_arms", "field_siege"].has(db.mission(id).deck_id), id)


func test_mission_select_lists_them_in_number_order() -> void:
	var ids: Array[String] = []
	for e in MissionListing.entries(_get_db()):
		if e.group == MissionListing.GROUP_MISSIONS:
			ids.append(e.id)
	assert_true(ids.find("x10_town_siege") > ids.find("x9_last_airfield"), "x10 after x9")
	assert_true(ids.find("x10_town_siege") > ids.find("x5_field_works") if ids.has("x5_field_works") else true)
	assert_true(MissionListing.id_less("x2_a", "x10_a") and not MissionListing.id_less("x10_a", "x2_a"))
	assert_true(MissionListing.id_less("m1_a", "x1_a"))


func test_a_battle_on_each_map_runs_and_the_horde_arrives() -> void:
	for id in MISSIONS:
		var b := BattleController.new()
		b.auto_step = false
		b.setup(_get_db(), _get_db().mission(id), 1)
		_made.append(b)
		assert_true(b.units.size() >= 4, "%s: defenders stand around the core" % id)
		for u in b.units:
			assert_true(b.mission.map.is_walkable(IsoProjection.cell_of(u.ground_pos)))
		for i in int(round(12.0 / DT)):
			b.step(DT)
		assert_true(b.enemies.size() > 20, "%s: the horde is on the field" % id)
		assert_true(b.core.health.hp > 0.0)
	_release()


func test_the_town_route_is_long_and_winding() -> void:
	var m := _get_db().mission("x10_town_siege")
	var pts := PackedVector2Array()
	pts.append(IsoProjection.cell_center(m.spawn_cells[0]))
	for c in m.path_cells:
		pts.append(IsoProjection.cell_center(c))
	var r := Route.from_points(pts)
	assert_true(r.length() > 70.0, "a long walk through the streets (%.0f tiles)" % r.length())
