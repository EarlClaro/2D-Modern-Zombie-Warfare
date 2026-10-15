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
