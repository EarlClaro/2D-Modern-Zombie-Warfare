extends TestCase
## Snow and lightning (docs/specs/art-more.md, N.2): the weather name is known, the storm strikes on a fixed schedule, the flash
## has the right shape, and the thunder sound exists.


func _storm(seconds: float) -> Array[Dictionary]:
	var view := WeatherView.new()
	view.set_weather("rain")
	var strikes: Array[Dictionary] = []
	view.lightning_struck.connect(func(delay: float) -> void: strikes.append({"t": view._t, "delay": delay}))
	var t := 0.0
	while t < seconds:
		view._process(0.1)
		t += 0.1
	view.free()
	return strikes


func test_snow_is_a_known_weather_with_its_own_tint() -> void:
	assert_true(DayNight.is_weather("snow"))
	assert_true(DayNight.weather_tint("snow") != Color.WHITE)
	var db := ContentDb.load_from()
	var m: MissionDefinition = db.mission("m1_hold_the_crossing").duplicate()
	m.weather = "snow"
	assert_true(not _has(m.validate(), "weather"), "a snow mission is valid")


func _has(errors: PackedStringArray, part: String) -> bool:
	for e in errors:
		if e.contains(part):
			return true
	return false


func test_the_storm_strikes_now_and_then_on_a_fixed_schedule() -> void:
	var a := _storm(120.0)
	assert_true(a.size() >= 4 and a.size() <= 14, "%d strikes in two minutes" % a.size())
	assert_true(float(a[0]["t"]) >= WeatherView.FIRST_STRIKE_S - 0.01, "the first strike waits for a few seconds")
	for i in range(1, a.size()):
		var gap := float(a[i]["t"]) - float(a[i - 1]["t"])
		assert_true(gap >= WeatherView.STRIKE_GAP_MIN_S - 0.2 and gap <= WeatherView.STRIKE_GAP_MIN_S + WeatherView.STRIKE_GAP_VAR_S + 0.2, "gap %f" % gap)
	for s in a:
		assert_true(float(s["delay"]) >= 0.35 and float(s["delay"]) <= 2.3, "thunder follows the flash within a few seconds")
	var b := _storm(120.0)
	assert_eq(a.size(), b.size(), "the same storm every time")
	for i in a.size():
		assert_eq(a[i]["t"], b[i]["t"])


func test_only_rain_has_lightning() -> void:
	for w in ["snow", "fog", "dust", "clear"]:
		var view := WeatherView.new()
		view.set_weather(w)
		var n := [0]
		view.lightning_struck.connect(func(_d: float) -> void: n[0] += 1)
		for i in 1200:
			view._process(0.1)
		view.free()
		assert_eq(n[0], 0, "no lightning in %s" % w)


func test_the_flash_is_hard_then_dips_then_flickers_then_fades() -> void:
	assert_eq(WeatherView.flash_level(-1.0), 0.0)
	var first := WeatherView.flash_level(0.02)
	var dip := WeatherView.flash_level(0.07)
	var second := WeatherView.flash_level(0.12)
	var tail := WeatherView.flash_level(0.3)
	assert_true(first > second and second > tail and tail > 0.0, "bright, flicker, fade")
	assert_true(dip < tail, "a dark gap between the two flashes")
	assert_eq(WeatherView.flash_level(WeatherView.FLASH_S + 0.01), 0.0, "gone after the fade")


func test_thunder_is_a_long_low_sound_in_the_library() -> void:
	var lib := SfxFactory.build_library()
	assert_true(lib.has("thunder"))
	var wav: AudioStreamWAV = lib["thunder"]
	var seconds := float(wav.data.size()) / 2.0 / float(SfxFactory.MIX_RATE)
	assert_true(seconds > 2.0 and seconds < 3.2, "%f s" % seconds)
	assert_eq(SfxFactory.SETTINGS["thunder"]["category"], "blast")
