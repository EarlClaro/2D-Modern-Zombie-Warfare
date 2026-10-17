extends TestCase
## FlowField (M3.11, ADR-012): the distance map and steering direction over open ground cells. Pure, so these use small
## hand-drawn grids ('.' open, '#' closed) and no battle.


func _field(rows: Array, goal: Vector2i) -> FlowField:
	var h := rows.size()
	var w := String(rows[0]).length()
	var open := PackedByteArray()
	open.resize(w * h)
	for y in h:
		for x in w:
			open[y * w + x] = 1 if String(rows[y])[x] != "#" else 0
	return FlowField.build(w, h, open, goal)


func _center(c: Vector2i) -> Vector2:
	return Vector2(float(c.x) + 0.5, float(c.y) + 0.5)


# --- distances -----------------------------------------------------------------------------------------------------

func test_distance_counts_straight_and_diagonal_steps() -> void:
	var f := _field(["......", "......", "......"], Vector2i(0, 0))
	assert_near(f.distance(Vector2i(0, 0)), 0.0)
	assert_near(f.distance(Vector2i(3, 0)), 3.0)
	assert_near(f.distance(Vector2i(2, 2)), 2.0 * FlowField.DIAGONAL, 1e-4)
	assert_near(f.distance(Vector2i(5, 2)), 2.0 * FlowField.DIAGONAL + 3.0, 1e-4, "two diagonals then straight")


func test_a_wall_is_walked_around_not_through() -> void:
	var f := _field([
		"......",
		".####.",
		"......",
	], Vector2i(0, 0))
	# from (5, 2) the straight way along the bottom row is open, but (2, 1) is a wall cell
	assert_true(not f.is_open(Vector2i(2, 1)))
	assert_eq(f.distance(Vector2i(2, 1)), INF, "a closed cell has no distance")
	assert_true(f.distance(Vector2i(3, 2)) > 3.0 and f.reachable(Vector2i(3, 2)))


func test_a_diagonal_step_may_not_cut_a_corner() -> void:
	var f := _field([
		".#",
		"#.",
	], Vector2i(0, 0))
	# (1, 1) touches the goal only through a diagonal whose two side cells are both closed
	assert_true(not f.reachable(Vector2i(1, 1)), "no squeezing through a pinch")
	var g := _field([
		"..",
		".#",
	], Vector2i(0, 0))
	assert_true(g.reachable(Vector2i(1, 0)) and g.reachable(Vector2i(0, 1)))
	var h := _field([
		"...",
		".#.",
		"...",
	], Vector2i(0, 0))
	assert_near(h.distance(Vector2i(2, 2)), 2.0 + 2.0, 1e-4, "round the block, the diagonal through it is not allowed")


func test_a_cell_closed_off_on_all_sides_is_unreachable() -> void:
	var f := _field([
		"..#..",
		"..#..",
		"..#..",
	], Vector2i(0, 0))
	assert_true(f.reachable(Vector2i(1, 2)))
	assert_true(not f.reachable(Vector2i(3, 1)), "the far side of a full wall")
	assert_eq(f.distance(Vector2i(3, 1)), INF)
	assert_eq(f.direction_at(_center(Vector2i(3, 1))), Vector2.ZERO, "and there is no heading there")


func test_the_goal_is_open_even_when_the_map_says_closed() -> void:
	var f := _field(["#..", "..."], Vector2i(0, 0))
	assert_true(f.is_open(Vector2i(0, 0)))
	assert_true(f.reachable(Vector2i(2, 1)))


func test_bad_inputs_do_not_crash() -> void:
	var off := FlowField.build(3, 3, PackedByteArray([1, 1, 1, 1, 1, 1, 1, 1, 1]), Vector2i(9, 9))
	assert_true(not off.reachable(Vector2i(0, 0)), "a goal outside the grid reaches nothing")
	assert_eq(off.direction_at(Vector2(1, 1)), Vector2.ZERO)
	var empty := FlowField.build(0, 0, PackedByteArray(), Vector2i.ZERO)
	assert_true(not empty.reachable(Vector2i.ZERO))
	assert_eq(empty.trace(Vector2(0.5, 0.5)).size(), 0)
	var short := FlowField.build(4, 4, PackedByteArray([1, 1]), Vector2i(0, 0))
	assert_true(short.reachable(Vector2i(0, 0)), "a short open array is padded with closed cells, not read past its end")
	assert_true(not short.reachable(Vector2i(3, 3)))


# --- steering ------------------------------------------------------------------------------------------------------

func test_the_heading_points_down_the_distance_map() -> void:
	var f := _field(["......", "......", "......"], Vector2i(0, 1))
	var d := f.direction_at(_center(Vector2i(4, 1)))
	assert_vec_near(d, Vector2(-1, 0), 1e-4, "straight back to the goal")
	var up := f.direction_at(_center(Vector2i(2, 2)))
	assert_true(up.x < 0.0 and up.y < 0.0, "diagonally toward the goal")
	assert_near(up.length(), 1.0, 1e-4)


func test_the_heading_blends_smoothly_across_a_cell_border() -> void:
	var f := _field(["........", "........", "........", "........"], Vector2i(0, 3))
	var a := f.direction_at(Vector2(4.49, 0.5))
	var b := f.direction_at(Vector2(4.51, 0.5))
	assert_true(a.distance_to(b) < 0.05, "no jump at a border")


func test_the_heading_goes_around_an_obstacle() -> void:
	var f := _field([
		".......",
		".......",
		".#####.",
		".......",
		".......",
	], Vector2i(3, 4))
	# standing above the wall in the middle, the way down is sideways first
	var d := f.direction_at(_center(Vector2i(3, 1)))
	assert_true(absf(d.x) > 0.3, "it heads sideways round the wall (%s)" % str(d))
	assert_true(d.y >= -1e-6 or absf(d.x) > absf(d.y), "not straight into it")


func test_a_heading_never_leads_into_a_closed_cell() -> void:
	var rows := [
		"........",
		".##..#..",
		".#....#.",
		"...##...",
		"........",
	]
	var f := _field(rows, Vector2i(7, 4))
	for y in rows.size():
		for x in String(rows[0]).length():
			var c := Vector2i(x, y)
			if not f.reachable(c):
				continue
			var d := f.direction_at(_center(c))
			if c == Vector2i(7, 4):
				continue
			assert_near(d.length(), 1.0, 1e-3, "a unit heading at %s" % str(c))
			var next := Vector2i(floori(_center(c).x + d.x * 0.6), floori(_center(c).y + d.y * 0.6))
			assert_true(f.is_open(next), "%s heads into a closed cell %s" % [str(c), str(next)])


func test_the_field_is_deterministic() -> void:
	var rows := ["........", ".##..#..", ".#....#.", "...##...", "........"]
	var a := _field(rows, Vector2i(7, 4))
	var b := _field(rows, Vector2i(7, 4))
	for y in rows.size():
		for x in 8:
			var c := Vector2i(x, y)
			assert_eq(a.distance(c), b.distance(c))
			assert_eq(a.direction_at(_center(c)), b.direction_at(_center(c)))


# --- tracing -------------------------------------------------------------------------------------------------------

func test_a_trace_reaches_the_goal_and_stays_on_open_ground() -> void:
	var rows := [
		"..........",
		".########.",
		"..........",
		".########.",
		"..........",
	]
	var f := _field(rows, Vector2i(9, 4))
	var pts := f.trace(_center(Vector2i(0, 0)), 0.5)
	assert_true(pts.size() > 10)
	assert_vec_near(pts[pts.size() - 1], _center(Vector2i(9, 4)), 1e-4, "ends on the goal")
	assert_vec_near(pts[0], _center(Vector2i(0, 0)), 1e-4, "starts where asked")
	for p in pts:
		assert_true(f.is_open(Vector2i(floori(p.x), floori(p.y))), "%s is on open ground" % str(p))


func test_a_trace_is_about_as_long_as_the_distance() -> void:
	var f := _field(["..........", "..........", ".........."], Vector2i(9, 1))
	var from := _center(Vector2i(0, 1))
	var pts := f.trace(from, 0.25)
	var len := 0.0
	for i in pts.size() - 1:
		len += pts[i].distance_to(pts[i + 1])
	assert_near(len, 9.0, 0.5)


func test_a_trace_from_an_unreachable_cell_is_empty() -> void:
	var f := _field(["..#..", "..#..", "..#.."], Vector2i(0, 0))
	assert_eq(f.trace(_center(Vector2i(4, 1))).size(), 0)
	assert_eq(f.trace(Vector2(-3, -3)).size(), 0, "nor from outside the map")


# --- the open grid of a map ----------------------------------------------------------------------------------------

func test_the_open_grid_follows_terrain_and_blocked_cells() -> void:
	var m := MapDefinition.new()
	m.id = "t"
	m.rows = PackedStringArray(["gggg", "gwwg", "gggg"])  # g = meadow (walkable), w = water (not)
	var grid := FlowField.open_grid(m, {Vector2i(3, 2): true})
	assert_eq(grid.size(), 12)
	assert_eq(grid[0], 1, "meadow is open")
	assert_eq(grid[1 * 4 + 1], 0, "water is closed")
	assert_eq(grid[2 * 4 + 3], 0, "a blocked cell is closed")
	assert_eq(grid[2 * 4 + 2], 1)
	var f := FlowField.build(m.width(), m.height(), grid, Vector2i(0, 0))
	assert_true(f.reachable(Vector2i(3, 0)), "round the water along the top")


# --- sliding along walls and ties ----------------------------------------------------------------------------------

func test_a_step_into_open_ground_is_taken_whole() -> void:
	var f := _field(["....", "....", "...."], Vector2i(3, 1))
	assert_vec_near(f.slide(Vector2(1.5, 1.5), Vector2(0.4, -0.3)), Vector2(1.9, 1.2), 1e-6)


func test_a_step_into_a_wall_slides_along_it() -> void:
	var f := _field(["....", ".##.", "...."], Vector2i(3, 2))
	# from (1.9, 0.9) a step down-right would enter the wall cell (2, 1) / (1, 1): it keeps the open axis
	var p := Vector2(1.9, 0.9)
	var along_x := f.slide(p, Vector2(0.3, 0.3))
	assert_vec_near(along_x, Vector2(2.2, 0.9), 1e-6, "slides along x (the row stays open)")
	var q := Vector2(0.9, 1.9)
	assert_vec_near(f.slide(q, Vector2(0.3, -0.3)), Vector2(0.9, 1.6), 1e-6, "x is blocked on this row, so it keeps y beside the wall")
	var corner := Vector2(0.9, 0.9)
	assert_vec_near(f.slide(corner, Vector2(0.3, 0.3)), Vector2(1.2, 0.9), 1e-6, "into the corner of the wall: x stays open on the top row")


func test_a_walker_blocked_on_both_axes_stays_put() -> void:
	var f := _field(["..#", "..#", "###"], Vector2i(0, 0))
	var p := Vector2(1.9, 1.9)
	assert_vec_near(f.slide(p, Vector2(0.3, 0.3)), p, 1e-9)


func test_two_equal_ways_round_an_obstacle_still_give_a_heading() -> void:
	var f := _field([
		".......",
		".#####.",
		".#####.",
		".......",
	], Vector2i(3, 3))
	# on the middle column above the block the left and right detours are the same length
	var d := f.direction_at(_center(Vector2i(3, 0)))
	assert_near(d.length(), 1.0, 1e-4, "a real heading, not the cancelled sum")
	assert_true(absf(d.x) > 0.9, "sideways: %s" % str(d))


func test_a_walker_on_the_symmetry_axis_gets_round_the_block() -> void:
	var f := _field([
		".......",
		".#####.",
		".#####.",
		".......",
	], Vector2i(3, 3))
	var p := _center(Vector2i(3, 0))
	var steps := 0
	while steps < 400 and p.distance_to(_center(Vector2i(3, 3))) > 0.6:
		p = f.slide(p, f.direction_at(p) * 0.1)
		steps += 1
	assert_true(steps < 400, "it arrives (took %d steps, ended at %s)" % [steps, str(p)])


# --- the parts that only show in odd cases -------------------------------------------------------------------------

func test_the_goal_cell_itself_has_no_heading() -> void:
	var f := _field(["...", "..."], Vector2i(1, 0))
	assert_eq(f.direction_at(_center(Vector2i(1, 0))), Vector2.ZERO)


func test_a_blend_that_cancels_falls_back_to_the_cells_own_heading() -> void:
	var f := _field(["....", "...."], Vector2i(0, 0))
	# two neighbouring cells forced to opposite headings: sampled on their shared border the blend cancels
	f._dir[1] = Vector2(1, 0)
	f._dir[2] = Vector2(-1, 0)
	var d := f.direction_at(Vector2(2.0, 0.5))
	assert_vec_near(d, Vector2(-1, 0), 1e-6, "the cell the point is in (cell 2) decides")


func test_a_trace_that_cannot_move_stops_instead_of_running_on() -> void:
	var f := _field(["..#", "..#", "###"], Vector2i(0, 0))
	f._dir[1 * 3 + 1] = Vector2(1, 1).normalized()  # into the corner: blocked on both axes
	var pts := f.trace(Vector2(1.9, 1.9), 0.5, 4000)
	assert_true(pts.size() < 10, "gave up after %d points" % pts.size())


func test_a_trace_moves_in_steps_no_longer_than_asked() -> void:
	var f := _field(["..........", "..........", ".........."], Vector2i(9, 1))
	var pts := f.trace(_center(Vector2i(0, 1)), 0.5)
	for i in pts.size() - 1:
		assert_true(pts[i].distance_to(pts[i + 1]) <= 0.5 + 1e-4, "step %d is %f long" % [i, pts[i].distance_to(pts[i + 1])])


func test_the_heap_hands_out_the_smallest_key_first() -> void:
	var f := FlowField.new()
	var keys := [5.0, 1.0, 3.0, 2.0, 4.0, 0.5, 9.0, 7.0]
	for i in keys.size():
		f._push(keys[i], i)
	var last := -1.0
	var n := 0
	while not f._heap_val.is_empty():
		var k := f._heap_key[0]
		f._pop()
		assert_true(k >= last, "popped %f after %f" % [k, last])
		last = k
		n += 1
	assert_eq(n, keys.size())


func test_open_at_tells_open_ground_from_walls_and_outside() -> void:
	var f := _field(["..#", "..."], Vector2i(0, 0))
	assert_true(f.open_at(Vector2(0.5, 0.5)))
	assert_true(f.open_at(Vector2(1.99, 1.99)))
	assert_true(not f.open_at(Vector2(2.5, 0.5)), "a wall cell")
	assert_true(not f.open_at(Vector2(-0.1, 0.5)), "outside the map")
	assert_true(not f.open_at(Vector2(0.5, 5.0)), "outside the map")
