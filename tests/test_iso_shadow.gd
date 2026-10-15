extends TestCase

const Shadow := preload("res://scripts/iso/iso_shadow.gd")
const Entity := preload("res://scripts/iso/iso_entity.gd")


func test_shadow_follows_its_target_position_every_tick() -> void:
	var e := Entity.new()
	var s := Shadow.new()
	s.target = e
	e.ground_pos = Vector2(3, 4)
	s._process(0.016)
	assert_vec_near(s.position, e.position)
	e.ground_pos = Vector2(5, 1)
	s._process(0.016)
	assert_vec_near(s.position, e.position, 1e-6, "tracks movement without needing a redraw")
	s.free()
	e.free()


func test_polygon_is_only_rebuilt_when_altitude_changes() -> void:
	# Perf (measured in M1.6): rebuilding every shadow's polygon each frame was the main CPU cost of a
	# large horde. Ground shadows must be built once; only a changing altitude forces a rebuild.
	var e := Entity.new()
	var s := Shadow.new()
	s.target = e
	s._process(0.016)
	assert_eq(s.redraw_requests, 1, "first tick builds the polygon once")
	assert_near(s._drawn_altitude, 0.0, 1e-9)
	for i in 60:
		e.ground_pos = Vector2(9, 9) + Vector2(i * 0.1, 0.0)
		s._process(0.016)
	assert_eq(s.redraw_requests, 1, "60 ticks of ground movement cause no rebuilds")
	e.altitude = 3.0
	s._process(0.016)
	assert_eq(s.redraw_requests, 2, "a new altitude triggers exactly one rebuild")
	assert_near(s._drawn_altitude, 3.0, 1e-9)
	s._process(0.016)
	s._process(0.016)
	assert_eq(s.redraw_requests, 2, "unchanged altitude: no more rebuilds")
	s.free()
	e.free()


func test_shadow_removes_itself_when_its_target_is_gone() -> void:
	var e := Entity.new()
	var s := Shadow.new()
	s.target = e
	e.free()
	s._process(0.016)
	assert_true(s.is_queued_for_deletion(), "orphaned shadow queues itself for deletion")
	s.free()
