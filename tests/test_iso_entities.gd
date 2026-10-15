extends TestCase
## Spike entities: ground-plane movement, facing, occlusion rule, AoE helper, projection helpers.

const Iso := preload("res://scripts/iso/iso_projection.gd")
const Occlusion := preload("res://scripts/iso/iso_occlusion.gd")
const Unit := preload("res://scripts/iso/placeholder_unit.gd")
const Structure := preload("res://scripts/iso/placeholder_structure.gd")
const Flyer := preload("res://scripts/iso/placeholder_flyer.gd")
const Aoe := preload("res://scripts/iso/iso_aoe_indicator.gd")


# --- projection helpers -------------------------------------------------------------------------

func test_ground_dir_of_facing_round_trips() -> void:
	for f in 8:
		var d := Iso.ground_dir_of_facing(f)
		assert_near(d.length(), 1.0, 1e-6)
		assert_eq(Iso.facing_from_ground_dir(d), f, "facing %d" % f)


func test_cell_screen_rect() -> void:
	var r := Iso.cell_screen_rect(Vector2i(3, 1))
	assert_near(r.size.x, Iso.TILE_W)
	assert_near(r.size.y, Iso.TILE_H)
	# Contains all four projected corners (on the boundary) and the cell centre.
	for corner in [Vector2(3, 1), Vector2(4, 1), Vector2(3, 2), Vector2(4, 2)]:
		assert_true(r.grow(0.001).has_point(Iso.ground_to_screen(corner)), "corner %s" % str(corner))
	assert_true(r.has_point(Iso.ground_to_screen(Iso.cell_center(Vector2i(3, 1)))))


func test_ground_circle_polygon_is_centered_ellipse() -> void:
	var center := Vector2(4, 7)
	var poly := Iso.ground_circle_polygon(center, 2.5, 32)
	assert_eq(poly.size(), 32)
	var sum := Vector2.ZERO
	for p in poly:
		sum += p
	assert_vec_near(sum / poly.size(), Iso.ground_to_screen(center), 1e-3)
	var radii := Iso.ellipse_radii(2.5)
	for p in poly:
		var d: Vector2 = p - Iso.ground_to_screen(center)
		assert_near((d.x / radii.x) * (d.x / radii.x) + (d.y / radii.y) * (d.y / radii.y), 1.0, 1e-4)


func test_altitude_offset_helper() -> void:
	assert_vec_near(Iso.altitude_offset(0.0), Vector2.ZERO)
	assert_vec_near(Iso.altitude_offset(2.0), Vector2(0, -2.0 * Iso.Z_PX_PER_UNIT))


# --- entity base + unit -------------------------------------------------------------------------

func test_entity_position_follows_ground_pos_not_altitude() -> void:
	var u := Unit.new()
	u.ground_pos = Vector2(5, 2)
	assert_vec_near(u.position, Iso.ground_to_screen(Vector2(5, 2)))
	u.altitude = 4.0
	assert_vec_near(u.position, Iso.ground_to_screen(Vector2(5, 2)), 1e-6, "altitude must not move the sort anchor")
	u.free()


func test_unit_moves_at_constant_ground_speed_in_all_8_directions() -> void:
	for f in 8:
		var u := Unit.new()
		u.ground_pos = Vector2(5, 5)
		var dir := Iso.ground_dir_of_facing(f)
		u.move_to(Vector2(5, 5) + dir * 4.0)
		for i in 10:
			u.advance(0.1)  # 1.0 s total
		assert_near(u.ground_pos.distance_to(Vector2(5, 5)), Unit.SPEED_TILES_PER_S, 1e-3, "ground distance, facing %d" % f)
		assert_eq(u.facing, f, "facing while moving")
		assert_true(u.is_moving())
		u.free()


func test_unit_screen_speed_differs_but_ground_speed_does_not() -> void:
	# Moving along ground +X (screen down-right) vs ground (1,-1) (screen right) covers different screen px.
	var a := Unit.new()
	a.ground_pos = Vector2.ZERO
	a.move_to(Vector2(4, 0))
	var b := Unit.new()
	b.ground_pos = Vector2.ZERO
	b.move_to(Vector2(1, -1).normalized() * 4.0)
	for i in 10:
		a.advance(0.1)
		b.advance(0.1)
	assert_near(a.ground_pos.length(), b.ground_pos.length(), 1e-3)
	assert_true(absf(a.position.length() - b.position.length()) > 1.0, "screen distances differ (anisotropic projection)")
	a.free()
	b.free()


func test_unit_arrives_exactly_and_stops() -> void:
	var u := Unit.new()
	u.ground_pos = Vector2(1, 1)
	u.move_to(Vector2(2, 1))
	for i in 20:
		u.advance(0.1)
	assert_vec_near(u.ground_pos, Vector2(2, 1), 1e-6)
	assert_true(not u.is_moving())
	u.advance(1.0)
	assert_vec_near(u.ground_pos, Vector2(2, 1), 1e-6, "stays put after arrival")
	u.free()


func test_unit_move_to_current_position_is_noop() -> void:
	var u := Unit.new()
	u.ground_pos = Vector2(3, 3)
	var facing_before := u.facing
	u.move_to(Vector2(3, 3))
	u.advance(0.5)
	assert_true(not u.is_moving())
	assert_eq(u.facing, facing_before)
	u.free()


# --- occlusion ----------------------------------------------------------------------------------

func test_occlusion_requires_behind_and_overlap() -> void:
	var building_ground := Vector2(10, 6)
	var rect := Rect2(-64, -100, 128, 132)
	rect.position += Iso.ground_to_screen(building_ground)
	var behind := Vector2(10, 4)   # smaller x+y, same screen column: behind
	var behind_rect := Rect2(-12, -40, 24, 44)
	behind_rect.position += Iso.ground_to_screen(behind)
	assert_true(Occlusion.is_occluding(building_ground, rect, behind, behind_rect), "behind + overlapping")

	var front := Vector2(10, 8)    # larger x+y: in front of the building
	var front_rect := Rect2(-12, -40, 24, 44)
	front_rect.position += Iso.ground_to_screen(front)
	assert_true(not Occlusion.is_occluding(building_ground, rect, front, front_rect), "in front never fades building")

	var far_behind := Vector2(2, 2)  # behind but nowhere near on screen
	var far_rect := Rect2(-12, -40, 24, 44)
	far_rect.position += Iso.ground_to_screen(far_behind)
	assert_true(not Occlusion.is_occluding(building_ground, rect, far_behind, far_rect), "behind but no overlap")


func test_fade_alpha_progression() -> void:
	var a := 1.0
	a = Occlusion.next_alpha(a, true, Occlusion.FADE_TIME)
	assert_near(a, Occlusion.FADED_ALPHA, 1e-6, "full fade in FADE_TIME")
	a = Occlusion.next_alpha(a, true, 1.0)
	assert_near(a, Occlusion.FADED_ALPHA, 1e-6, "clamped at faded alpha")
	a = Occlusion.next_alpha(a, false, Occlusion.FADE_TIME * 0.5)
	assert_true(a > Occlusion.FADED_ALPHA and a < 1.0, "partial recovery")
	a = Occlusion.next_alpha(a, false, 1.0)
	assert_near(a, 1.0, 1e-6)


func test_structure_rect_and_sorting_on_all_sides() -> void:
	var s := Structure.new()
	s.setup(Vector2i(9, 5), Vector2i(2, 2), 3.0)
	assert_vec_near(s.ground_pos, Vector2(10, 6))
	assert_eq(s.covered_cells().size(), 4)
	var r := s.world_rect()
	# Rect contains the footprint base corners and the top corners.
	assert_true(r.grow(0.01).has_point(Iso.ground_to_screen(Vector2(11, 7))), "front base corner")
	assert_true(r.grow(0.01).has_point(Iso.ground_to_screen_z(Vector2(9, 5), 3.0)), "back top corner")
	# Entities beside / in front (larger x+y than the centre) sort in front; beyond the far edges sort behind.
	assert_true(Iso.sort_key(Vector2(11.5, 5.5)) > s.sort_key(), "+X side in front")
	assert_true(Iso.sort_key(Vector2(9.5, 7.5)) > s.sort_key(), "+Y side in front")
	assert_true(Iso.sort_key(Vector2(10, 4)) < s.sort_key(), "far (-Y) side behind")
	assert_true(Iso.sort_key(Vector2(8, 6)) < s.sort_key(), "far (-X) side behind")
	s.free()


# --- flyer --------------------------------------------------------------------------------------

func test_flyer_altitude_is_separate_from_ground_orbit() -> void:
	var f := Flyer.new()
	f.orbit_center = Vector2(8, 8)
	f.orbit_radius = 5.0
	for i in 30:
		f.advance(0.1)
		assert_near(f.ground_pos.distance_to(Vector2(8, 8)), 5.0, 1e-4, "stays on ground orbit")
		assert_near(f.altitude, Flyer.FLIGHT_ALTITUDE, 1e-6)
		assert_vec_near(f.position, Iso.ground_to_screen(f.ground_pos), 1e-4, "sort anchor stays on the ground")
	f.free()


# --- AoE ----------------------------------------------------------------------------------------

func test_aoe_cells_in_radius_are_ground_distance_based() -> void:
	var center := Vector2(8.0, 8.0)  # a cell corner
	var cells := Aoe.cells_in_radius(center, 1.0)
	# Centres at (7.5|8.5, 7.5|8.5) are sqrt(0.5)=0.707 away: 4 cells. Next ring is >= 1.58 away.
	assert_eq(cells.size(), 4)
	for c in cells:
		assert_true(Iso.cell_center(c).distance_to(center) <= 1.0)
	# Radius 0.5 around a cell centre covers exactly that cell.
	var one := Aoe.cells_in_radius(Vector2(3.5, 3.5), 0.5)
	assert_eq(one, [Vector2i(3, 3)] as Array[Vector2i])
	# Larger radius: every returned cell is inside, and every cell inside is returned (brute-force check).
	var r := 3.3
	var ctr := Vector2(5.2, 6.9)
	var got := Aoe.cells_in_radius(ctr, r)
	var expected := 0
	for cy in range(-5, 20):
		for cx in range(-5, 20):
			if Iso.cell_center(Vector2i(cx, cy)).distance_to(ctr) <= r:
				expected += 1
	assert_eq(got.size(), expected)
