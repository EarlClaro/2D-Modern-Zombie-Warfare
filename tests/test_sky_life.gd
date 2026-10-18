extends TestCase
## Crows by day and the searchlight at night (docs/specs/art-more.md, N.7).

var _roots: Array[Node] = []


func _release() -> void:
	for r in _roots:
		if is_instance_valid(r):
			r.get_parent().remove_child(r)
			r.free()
	_roots.clear()


func _sky(weather: String, darkness: float) -> SkyLife:
	var db := ContentDb.load_from()
	var b := BattleController.new()
	b.auto_step = false
	b.setup(db, db.mission("m1_hold_the_crossing"), 1)
	tree.root.add_child(b)
	_roots.append(b)
	var s := SkyLife.new()
	b.add_child(s)
	s.bind(b, weather)
	s.set_darkness(darkness)
	return s


func _run(s: SkyLife, seconds: float) -> int:
	var seen := 0
	var t := 0.0
	while t < seconds:
		s._process(0.1)
		seen = maxi(seen, s.flock_count())
		t += 0.1
	return seen


func test_the_beam_sweeps_to_and_fro_and_only_shows_at_night() -> void:
	var lo := 10.0
	var hi := -10.0
	for i in 200:
		var a := SkyLife.beam_angle(float(i) * 0.05)
		lo = minf(lo, a)
		hi = maxf(hi, a)
	assert_true(hi - lo > 1.3 and hi - lo <= SkyLife.BEAM_HALF_ARC * 2.0 + 0.01, "a wide sweep: %f" % (hi - lo))
	assert_true(hi < 0.0 and lo > -PI, "it always points up into the sky")
	assert_near(SkyLife.beam_angle(0.0), SkyLife.beam_angle(SkyLife.BEAM_PERIOD_S), 1e-4, "the sweep repeats every period")
	assert_eq(SkyLife.beam_strength(0.0), 0.0, "none by day")
	assert_eq(SkyLife.beam_strength(SkyLife.BEAM_MIN_DARKNESS), 0.0)
	assert_eq(SkyLife.beam_strength(1.0), 1.0, "full in the dead of night")


func test_crows_fly_by_day_in_clear_weather() -> void:
	var s := _sky("clear", 0.0)
	assert_true(s.crows_allowed())
	var most := _run(s, 90.0)
	assert_true(most >= 1, "a flock crossed in a minute and a half")
	_release()


func test_no_crows_at_night_or_in_a_storm() -> void:
	var night := _sky("clear", 0.9)
	assert_true(not night.crows_allowed())
	assert_eq(_run(night, 120.0), 0, "none at night")
	var storm := _sky("rain", 0.0)
	assert_true(not storm.crows_allowed())
	assert_eq(_run(storm, 120.0), 0, "none in the rain")
	var fog := _sky("fog", 0.0)
	assert_eq(_run(fog, 120.0), 0, "none in the fog")
	_release()


func test_flocks_have_a_few_birds_and_leave_the_list_when_gone() -> void:
	var s := _sky("clear", 0.0)
	_run(s, 30.0)
	for f in s._flocks:
		var n: int = (f["birds"] as Array).size()
		assert_true(n >= SkyLife.FLOCK_MIN and n <= SkyLife.FLOCK_MIN + SkyLife.FLOCK_VAR, "%d birds" % n)
	s.set_darkness(1.0)  # no new flocks, and the old ones fly on and leave
	_run(s, 200.0)
	assert_eq(s.flock_count(), 0, "all gone")
	_release()


func test_the_same_sky_every_run() -> void:
	var a := _sky("clear", 0.0)
	_run(a, 60.0)
	var b := _sky("clear", 0.0)
	_run(b, 60.0)
	assert_eq(a._flock_n, b._flock_n, "the same number of flocks by the same time")
	_release()


func test_the_crow_picture_is_two_frames_and_the_atmosphere_has_a_sky() -> void:
	var tex := load("res://assets/fx/crow.png") as Texture2D
	assert_eq(tex.get_size(), Vector2(28, 10), "two 14 x 10 frames")
	var db := ContentDb.load_from()
	var b := BattleController.new()
	b.auto_step = false
	b.setup(db, db.mission("m1_hold_the_crossing"), 1)
	tree.root.add_child(b)
	_roots.append(b)
	var atm := Atmosphere.new()
	b.add_child(atm)
	atm.bind(b)
	assert_true(b.get_node_or_null("Sky") is SkyLife, "the atmosphere adds the sky")
	_release()
