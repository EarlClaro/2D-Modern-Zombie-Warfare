extends TestCase

const Factory := preload("res://scripts/core/sfx_factory.gd")
const Pool := preload("res://scripts/core/sfx_voice_pool.gd")
const WeaponDef := preload("res://scripts/combat/weapon_definition.gd")


func _peak(wav: AudioStreamWAV) -> int:
	var peak := 0
	for i in range(0, wav.data.size(), 2):
		peak = maxi(peak, absi(wav.data.decode_s16(i)))
	return peak


func test_library_has_every_declared_sound() -> void:
	var lib := Factory.build_library()
	assert_eq(lib.size(), Factory.ALL_SOUNDS.size())
	for name in Factory.ALL_SOUNDS:
		assert_true(lib.has(name), "has " + name)
		assert_true(Factory.SETTINGS.has(name), "settings for " + name)


func test_streams_are_16bit_mono_at_mix_rate() -> void:
	var lib := Factory.build_library()
	for name in lib:
		var wav: AudioStreamWAV = lib[name]
		assert_eq(wav.format, AudioStreamWAV.FORMAT_16_BITS, name)
		assert_eq(wav.mix_rate, Factory.MIX_RATE, name)
		assert_true(not wav.stereo, name)
		assert_eq(wav.data.size() % 2, 0, name + " has whole samples")


func test_lengths_are_sensible() -> void:
	var lib := Factory.build_library()
	var expected := {"shot_rifle": 0.16, "shot_mg": 0.075, "impact": 0.06, "death": 0.26, "alert": 0.28}
	for name in expected:
		var wav: AudioStreamWAV = lib[name]
		assert_near(wav.get_length(), expected[name], 0.01, name)


func test_streams_are_normalised_and_not_silent() -> void:
	var lib := Factory.build_library()
	for name in lib:
		var peak := _peak(lib[name])
		assert_true(peak > 0, name + " is not silent")
		assert_true(peak <= 32767, name + " does not clip")
		assert_true(peak >= int(32767 * Factory.PEAK * 0.98), name + " is normalised to the target peak")


func test_generation_is_deterministic() -> void:
	var a := Factory.build_library()
	var b := Factory.build_library()
	for name in a:
		assert_true((a[name] as AudioStreamWAV).data == (b[name] as AudioStreamWAV).data, name + " identical across builds")


func test_sounds_differ_from_each_other() -> void:
	var lib := Factory.build_library()
	assert_true((lib["shot_rifle"] as AudioStreamWAV).data != (lib["shot_mg"] as AudioStreamWAV).data)
	assert_true((lib["impact"] as AudioStreamWAV).data != (lib["death"] as AudioStreamWAV).data)


func test_every_sound_maps_to_a_known_mixer_category() -> void:
	for name in Factory.ALL_SOUNDS:
		var cat: String = Factory.SETTINGS[name]["category"]
		assert_true(Pool.CAPS.has(cat), "%s -> %s has a cap" % [name, cat])
		assert_true(Pool.PRIORITY.has(cat), "%s -> %s has a priority" % [name, cat])


func test_shot_sound_helper_and_weapon_validation() -> void:
	assert_true(Factory.is_shot_sound("shot_rifle"))
	assert_true(Factory.is_shot_sound("shot_mg"))
	assert_true(not Factory.is_shot_sound("impact"), "non-shot sounds are not valid weapon sounds")
	assert_true(not Factory.is_shot_sound("nonsense"))
	var w := WeaponDef.new()
	w.id = "t_gun"
	w.damage = 1.0
	w.shots_per_second = 1.0
	w.range_tiles = 1.0
	assert_eq(w.validate().size(), 0, "default sfx_id is valid")
	w.sfx_id = "kaboom"
	var errs := w.validate()
	assert_eq(errs.size(), 1)
	assert_true("sfx_id 'kaboom'" in errs[0], errs[0])


func test_explosion_is_a_long_deep_sound_in_the_blast_category() -> void:
	var lib := Factory.build_library()
	var boom: AudioStreamWAV = lib["explosion"]
	var blast: AudioStreamWAV = lib["blast"]
	assert_true(boom.get_length() > blast.get_length(), "longer than the artillery blast")
	assert_true(boom.data != blast.data)
	assert_eq(Factory.SETTINGS["explosion"]["category"], "blast")
	assert_true(not Factory.is_shot_sound("explosion"), "weapons cannot use it as a shot sound")


func test_every_strike_clip_has_its_own_sound_and_it_is_long_enough_to_cover_the_clip() -> void:
	var lib := Factory.build_library()
	for name in Factory.STRIKE_SOUNDS:
		assert_true(lib.has(name), name)
		assert_eq(Factory.SETTINGS[name]["category"], "strike", name)
		assert_true(_peak(lib[name]) > 8000, "%s is audible" % name)
	assert_true((lib["strike_artillery"] as AudioStreamWAV).get_length() >= 0.8, "covers the small clip")
	for name in ["strike_naval", "strike_air", "strike_missile"]:
		assert_true((lib[name] as AudioStreamWAV).get_length() >= 1.5, "%s covers a large clip" % name)
	for name in ["strike_hypersonic", "strike_nuclear", "strike_laser"]:
		assert_true((lib[name] as AudioStreamWAV).get_length() >= 2.0, "%s covers an epic clip" % name)


func test_the_strike_sounds_are_all_different_and_deterministic() -> void:
	var a := Factory.build_library()
	var b := Factory.build_library()
	for i in Factory.STRIKE_SOUNDS.size():
		var name: String = Factory.STRIKE_SOUNDS[i]
		assert_true((a[name] as AudioStreamWAV).data == (b[name] as AudioStreamWAV).data, "%s is identical on every run" % name)
		for j in range(i + 1, Factory.STRIKE_SOUNDS.size()):
			assert_true((a[name] as AudioStreamWAV).data != (a[Factory.STRIKE_SOUNDS[j]] as AudioStreamWAV).data, "%s differs from %s" % [name, Factory.STRIKE_SOUNDS[j]])


func test_the_nuclear_bomb_is_quiet_just_before_the_blast_then_loud() -> void:
	var wav: AudioStreamWAV = Factory.build_library()["strike_nuclear"]
	var rate := float(Factory.MIX_RATE)
	var before := 0
	var after := 0
	for i in range(int(0.97 * rate), int(0.995 * rate)):
		before = maxi(before, absi(wav.data.decode_s16(i * 2)))
	for i in range(int(1.0 * rate), int(1.06 * rate)):
		after = maxi(after, absi(wav.data.decode_s16(i * 2)))
	assert_true(after > before * 4, "the boom (%d) dwarfs the breath before it (%d)" % [after, before])
