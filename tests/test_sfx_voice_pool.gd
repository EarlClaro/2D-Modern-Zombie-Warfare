extends TestCase

const Pool := preload("res://scripts/core/sfx_voice_pool.gd")


func test_pool_size() -> void:
	assert_eq(Pool.new(12).voice_count(), 12)
	assert_eq(Pool.new(3).voice_count(), 3)


func test_voice_is_used_and_expires() -> void:
	var p := Pool.new(12)
	var v := p.request("shot", 0.0, 0.5)
	assert_true(v >= 0)
	assert_eq(p.active_count("shot", 0.2), 1)
	assert_eq(p.active_count("shot", 0.5), 0, "ends exactly at now + duration")


func test_shot_cap_drops_extra_shots() -> void:
	var p := Pool.new(12)
	for i in 4:
		assert_true(p.request("shot", 0.0, 1.0) >= 0, "shot %d" % i)
	assert_eq(p.request("shot", 0.1, 1.0), -1, "5th simultaneous shot is dropped")
	assert_eq(p.active_count("shot", 0.1), 4)


func test_caps_per_category_are_independent() -> void:
	var p := Pool.new(12)
	for i in 4:
		p.request("shot", 0.0, 1.0)
	assert_true(p.request("impact", 0.0, 1.0) >= 0, "impacts unaffected by shot cap")
	for i in 3:
		assert_true(p.request("death", 0.0, 1.0) >= 0)
	assert_eq(p.request("death", 0.0, 1.0), -1, "death cap is 3")


func test_cap_frees_up_as_sounds_end() -> void:
	var p := Pool.new(12)
	for i in 4:
		p.request("shot", 0.0, 0.2)
	assert_eq(p.request("shot", 0.1, 0.2), -1)
	assert_true(p.request("shot", 0.25, 0.2) >= 0, "earlier shots have ended")


func test_alert_is_never_lost_to_gunfire() -> void:
	var p := Pool.new(12)
	# Saturate every other category completely.
	for i in 4:
		p.request("shot", 0.0, 5.0)
	for i in 4:
		p.request("impact", 0.0, 5.0)
	for i in 3:
		p.request("death", 0.0, 5.0)
	assert_true(p.request("alert", 0.0, 1.0) >= 0, "alert plays even with 11 voices busy")


func test_alert_retriggers_instead_of_dropping_at_its_cap() -> void:
	var p := Pool.new(12)
	var first := p.request("alert", 0.0, 1.0)
	var second := p.request("alert", 0.3, 1.0)
	assert_true(first >= 0 and second >= 0, "second alert still plays")
	assert_eq(second, first, "it replaces the playing alert voice")
	assert_eq(p.active_count("alert", 0.4), 1, "never more than one alert at once")


func test_alert_steals_a_lower_priority_voice_when_the_pool_is_full() -> void:
	var p := Pool.new(3)
	p.request("shot", 0.0, 2.0)
	p.request("impact", 0.0, 2.0)
	p.request("death", 0.0, 2.0)
	var v := p.request("alert", 0.1, 1.0)
	assert_true(v >= 0, "alert stole a voice")
	assert_eq(p.active_count("death", 0.2), 1, "death (higher priority) survived")
	assert_eq(p.active_count("alert", 0.2), 1)


func test_equal_or_higher_priority_voices_are_not_stolen() -> void:
	var p := Pool.new(2)
	p.request("death", 0.0, 2.0)
	p.request("death", 0.0, 2.0)
	assert_eq(p.request("shot", 0.1, 1.0), -1, "shots can't steal from deaths")
	assert_eq(p.request("impact", 0.1, 1.0), -1)
	assert_eq(p.active_count("death", 0.2), 2)


func test_steals_oldest_lowest_priority_voice() -> void:
	var p := Pool.new(2)
	var older := p.request("shot", 0.0, 1.0)
	var newer := p.request("shot", 0.0, 2.0)
	assert_true(older != newer)
	var stolen := p.request("death", 0.1, 1.0)
	assert_eq(stolen, older, "earliest-ending shot voice is taken")


func test_unknown_category_uses_defaults() -> void:
	var p := Pool.new(12)
	for i in Pool.DEFAULT_CAP:
		assert_true(p.request("mystery", 0.0, 1.0) >= 0)
	assert_eq(p.request("mystery", 0.0, 1.0), -1)


func test_zero_duration_sound_frees_immediately() -> void:
	var p := Pool.new(1)
	assert_true(p.request("shot", 1.0, 0.0) >= 0)
	assert_true(p.request("shot", 1.0, 0.0) >= 0, "voice is free again at once")
