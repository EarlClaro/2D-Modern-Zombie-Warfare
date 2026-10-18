extends TestCase
## The music (docs/specs/art-gaps.md, G.4): four tracks, right lengths and loops, audible but not clipped, identical on every run,
## and the music volume setting round-trips.

var _lib: Dictionary


func _get_lib() -> Dictionary:
	if _lib.is_empty():
		_lib = MusicFactory.build_library()
	return _lib


func _peak_and_rms(s: AudioStreamWAV) -> Vector2:
	var peak := 0.0
	var sum := 0.0
	var n := s.data.size() / 2
	for i in n:
		var v := float(s.data.decode_s16(i * 2)) / 32767.0
		peak = maxf(peak, absf(v))
		sum += v * v
	return Vector2(peak, sqrt(sum / float(maxi(n, 1))))


func test_four_tracks_with_the_right_shape() -> void:
	var lib := _get_lib()
	for t in MusicFactory.TRACKS:
		assert_true(lib.has(t), t)
	assert_true((lib["menu"] as AudioStreamWAV).get_length() > 20.0)
	assert_true((lib["battle"] as AudioStreamWAV).get_length() > 15.0)
	assert_true((lib["victory"] as AudioStreamWAV).get_length() < 4.0)
	assert_eq((lib["menu"] as AudioStreamWAV).loop_mode, AudioStreamWAV.LOOP_FORWARD)
	assert_eq((lib["battle"] as AudioStreamWAV).loop_mode, AudioStreamWAV.LOOP_FORWARD)
	assert_eq((lib["victory"] as AudioStreamWAV).loop_mode, AudioStreamWAV.LOOP_DISABLED)
	assert_eq((lib["defeat"] as AudioStreamWAV).loop_mode, AudioStreamWAV.LOOP_DISABLED)


func test_loops_end_exactly_where_their_data_ends() -> void:
	for t in ["menu", "battle"]:
		var s: AudioStreamWAV = _get_lib()[t]
		assert_eq(s.loop_end, s.data.size() / 2, t)


func test_tracks_are_audible_and_not_clipped() -> void:
	for t in MusicFactory.TRACKS:
		var pr := _peak_and_rms(_get_lib()[t])
		assert_true(pr.x > 0.5 and pr.x <= 0.85, "%s peak %f" % [t, pr.x])
		assert_true(pr.y > 0.03, "%s is not silent (rms %f)" % [t, pr.y])


func test_building_twice_gives_the_same_bytes() -> void:
	var a := MusicFactory.build("victory")
	var b := MusicFactory.build("victory")
	assert_true(a.data == b.data)
	var n := MusicFactory.build("battle").data.size()
	assert_eq(n, (_get_lib()["battle"] as AudioStreamWAV).data.size())


func test_unknown_track_is_null() -> void:
	assert_true(MusicFactory.build("nope") == null)


func test_midi_pitch() -> void:
	assert_near(MusicFactory.midi_hz(69), 440.0)
	assert_near(MusicFactory.midi_hz(57), 220.0, 0.01)


func test_no_music_in_the_headless_runner() -> void:
	assert_true(not MusicService.enabled())


func test_music_volume_setting_round_trips_and_clamps() -> void:
	var s := GameSettings.new()
	assert_near(s.music_volume, 0.5)
	s.music_volume = 0.25
	var back := GameSettings.new()
	back.from_config(s.to_config())
	assert_near(back.music_volume, 0.25)
	back.music_volume = 3.0
	back.clamp_all()
	assert_near(back.music_volume, 1.0)
	back.reset()
	assert_near(back.music_volume, 0.5)


func test_music_bus_exists_after_apply() -> void:
	GameSettings.new().apply()
	assert_true(AudioServer.get_bus_index("Music") >= 0)
