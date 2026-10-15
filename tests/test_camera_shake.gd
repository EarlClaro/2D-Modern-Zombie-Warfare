extends TestCase

const Shake := preload("res://scripts/effects/camera_shake.gd")


func test_amplitude_is_capped_at_the_spec_limit_of_4_px() -> void:
	# Literal values on purpose: the cap is a design requirement (spec: shake <= 4 px), not an implementation detail.
	assert_true(Shake.MAX_PX <= 4.0, "MAX_PX is at most 4 px")
	assert_near(Shake.amplitude(50.0, 1.0, 1.0), 4.0)
	assert_near(Shake.amplitude(3.0, 1.0, 1.0), 3.0)


func test_amplitude_decays_linearly_to_zero() -> void:
	assert_near(Shake.amplitude(4.0, 0.15, 0.15), 4.0)
	assert_near(Shake.amplitude(4.0, 0.075, 0.15), 2.0, 1e-6)
	assert_near(Shake.amplitude(4.0, 0.0, 0.15), 0.0)
	assert_near(Shake.amplitude(4.0, -1.0, 0.15), 0.0)
	assert_near(Shake.amplitude(4.0, 0.1, 0.0), 0.0, 1e-6, "degenerate duration")


func test_trigger_ignores_invalid_values() -> void:
	var s := Shake.new()
	s.trigger(0.0, 0.2)
	s.trigger(3.0, 0.0)
	s.trigger(-2.0, 0.2)
	assert_near(s.current_amplitude(), 0.0)
	s.free()


func test_weaker_shake_does_not_cut_a_stronger_one() -> void:
	var s := Shake.new()
	s.trigger(4.0, 0.2)
	s.trigger(1.0, 0.1)
	assert_near(s.current_amplitude(), 4.0, 1e-6)
	s.trigger(100.0, 0.2)
	assert_near(s.current_amplitude(), 4.0, 1e-6, "strong requests are capped at 4 px")
	s.free()


func test_process_keeps_offset_within_amplitude_and_then_resets() -> void:
	var cam := Camera2D.new()
	var s := Shake.new()
	s.camera = cam
	s.trigger(3.0, 0.15)
	for i in 5:
		s._process(0.01)
		var limit := Shake.amplitude(3.0, 0.15 - 0.01 * (i + 1), 0.15)
		assert_true(absf(cam.offset.x) <= limit + 1e-6 and absf(cam.offset.y) <= limit + 1e-6, "step %d within %s" % [i, limit])
	for i in 30:
		s._process(0.01)
	assert_eq(cam.offset, Vector2.ZERO, "offset returns to zero after the shake")
	s.free()
	cam.free()


func test_process_without_a_camera_is_safe() -> void:
	var s := Shake.new()
	s.trigger(3.0, 0.1)
	s._process(0.05)
	assert_true(true, "no crash")
	s.free()
