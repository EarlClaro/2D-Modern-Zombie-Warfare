extends TestCase

const Iso := preload("res://scripts/iso/iso_projection.gd")


func test_known_values() -> void:
	assert_vec_near(Iso.ground_to_screen(Vector2(1, 0)), Vector2(32, 16))
	assert_vec_near(Iso.ground_to_screen(Vector2(0, 1)), Vector2(-32, 16))
	assert_vec_near(Iso.ground_to_screen(Vector2(1, 1)), Vector2(0, 32))
	assert_vec_near(Iso.ground_to_screen(Vector2.ZERO), Vector2.ZERO)


func test_round_trip() -> void:
	var samples: Array[Vector2] = [
		Vector2.ZERO, Vector2(1, 0), Vector2(0, 1), Vector2(-3.25, 7.5), Vector2(-100, -100),
		Vector2(10000, -10000), Vector2(-10000, 9999.5), Vector2(0.001, -0.002),
	]
	for p in samples:
		assert_vec_near(Iso.screen_to_ground(Iso.ground_to_screen(p)), p, 1e-3, "ground %s" % str(p))
		assert_vec_near(Iso.ground_to_screen(Iso.screen_to_ground(p)), p, 1e-2, "screen %s" % str(p))


func test_cell_of_edges() -> void:
	assert_eq(Iso.cell_of(Vector2(0, 0)), Vector2i(0, 0))
	assert_eq(Iso.cell_of(Vector2(0.999, 0.999)), Vector2i(0, 0))
	assert_eq(Iso.cell_of(Vector2(1, 1)), Vector2i(1, 1))
	assert_eq(Iso.cell_of(Vector2(-0.0001, 0)), Vector2i(-1, 0))
	assert_eq(Iso.cell_of(Vector2(-1, -1)), Vector2i(-1, -1))
	assert_eq(Iso.cell_of(Vector2(-1.0001, 2.5)), Vector2i(-2, 2))


func test_cell_center_and_screen_pick() -> void:
	var c := Vector2i(3, -2)
	assert_eq(Iso.cell_of(Iso.cell_center(c)), c)
	# Picking the screen position of a cell centre returns that cell.
	var s := Iso.ground_to_screen(Iso.cell_center(c))
	assert_eq(Iso.cell_of(Iso.screen_to_ground(s)), c)
	# Screen points just inside each diamond corner still resolve to the same cell.
	var half_w := Iso.TILE_W * 0.5
	var half_h := Iso.TILE_H * 0.5
	for off in [Vector2(half_w - 1.0, 0), Vector2(-half_w + 1.0, 0), Vector2(0, half_h - 0.5), Vector2(0, -half_h + 0.5)]:
		assert_eq(Iso.cell_of(Iso.screen_to_ground(s + off)), c, "offset %s" % str(off))


func test_ellipse_matches_ground_circle() -> void:
	var r := 3.0
	var radii := Iso.ellipse_radii(r)
	var center := Vector2(5, 2)
	var center_s := Iso.ground_to_screen(center)
	assert_near(radii.x / radii.y, 2.0, 1e-6, "2:1 ratio")
	for i in 16:
		var ang := TAU * i / 16.0
		var p := center + Vector2(cos(ang), sin(ang)) * r
		var d := Iso.ground_to_screen(p) - center_s
		var v := (d.x / radii.x) * (d.x / radii.x) + (d.y / radii.y) * (d.y / radii.y)
		assert_near(v, 1.0, 1e-4, "angle %d" % i)


func test_altitude_offset() -> void:
	var g := Vector2(4, 1)
	var base := Iso.ground_to_screen(g)
	var up := Iso.ground_to_screen_z(g, 2.0)
	assert_near(up.x, base.x, 1e-6)
	assert_near(up.y, base.y - 2.0 * Iso.Z_PX_PER_UNIT, 1e-6)
	assert_vec_near(Iso.ground_to_screen_z(g, 0.0), base)
	# Ground position is unchanged by altitude: round-trip of the z=0 point.
	assert_vec_near(Iso.screen_to_ground(base), g)


func test_facing_principal_directions() -> void:
	assert_eq(Iso.facing_from_ground_dir(Vector2(1, 0)), Iso.Facing.SE)
	assert_eq(Iso.facing_from_ground_dir(Vector2(1, 1)), Iso.Facing.S)
	assert_eq(Iso.facing_from_ground_dir(Vector2(0, 1)), Iso.Facing.SW)
	assert_eq(Iso.facing_from_ground_dir(Vector2(-1, 1)), Iso.Facing.W)
	assert_eq(Iso.facing_from_ground_dir(Vector2(-1, 0)), Iso.Facing.NW)
	assert_eq(Iso.facing_from_ground_dir(Vector2(-1, -1)), Iso.Facing.N)
	assert_eq(Iso.facing_from_ground_dir(Vector2(0, -1)), Iso.Facing.NE)
	assert_eq(Iso.facing_from_ground_dir(Vector2(1, -1)), Iso.Facing.E)
	assert_eq(Iso.facing_from_ground_dir(Vector2.ZERO), -1)
	# Screen consistency: E facing moves right on screen, S moves down, etc.
	assert_true(Iso.ground_to_screen(Vector2(1, -1)).x > 0 and absf(Iso.ground_to_screen(Vector2(1, -1)).y) < 1e-6)
	assert_true(Iso.ground_to_screen(Vector2(1, 1)).y > 0 and absf(Iso.ground_to_screen(Vector2(1, 1)).x) < 1e-6)


func test_facing_sector_boundaries() -> void:
	# Slightly off a principal direction stays in the same sector.
	assert_eq(Iso.facing_from_ground_dir(Vector2(1, 0.2)), Iso.Facing.SE)
	assert_eq(Iso.facing_from_ground_dir(Vector2(1, -0.2)), Iso.Facing.SE)
	assert_eq(Iso.facing_from_ground_dir(Vector2(1, 0.6)), Iso.Facing.S)


func test_sort_key() -> void:
	# Greater ground x+y is lower on screen and drawn in front.
	assert_true(Iso.sort_key(Vector2(3, 3)) > Iso.sort_key(Vector2(1, 2)))
	assert_true(Iso.ground_to_screen(Vector2(3, 3)).y > Iso.ground_to_screen(Vector2(1, 2)).y)
	assert_near(Iso.sort_key(Vector2(2, 1)), Iso.sort_key(Vector2(1, 2)), 1e-9)
