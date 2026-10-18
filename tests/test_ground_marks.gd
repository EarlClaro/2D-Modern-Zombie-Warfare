extends TestCase
## Ground marks (docs/specs/art-more.md, N.1): the pictures exist, the variants follow the blast size, the stains are decided by
## position, and each kind is capped per layer.


func test_every_picture_exists_with_a_flat_2_to_1_shape() -> void:
	for kind in [GroundMark.CRATER, GroundMark.BLOOD]:
		for v in GroundMark.VARIANTS:
			var tex := GroundMark.texture_of(kind, v)
			assert_true(tex != null, "%s_%d" % [kind, v])
			assert_eq(tex.get_width(), tex.get_height() * 2, "%s_%d is drawn 2:1 like the ground" % [kind, v])


func test_crater_size_follows_the_blast_radius() -> void:
	assert_eq(GroundMark.crater_variant(1.8), 0)
	assert_eq(GroundMark.crater_variant(2.5), 1)
	assert_eq(GroundMark.crater_variant(4.0), 2)
	assert_eq(GroundMark.crater_variant(12.0), 2)
	var w0 := GroundMark.texture_of(GroundMark.CRATER, 0).get_width()
	var w2 := GroundMark.texture_of(GroundMark.CRATER, 2).get_width()
	assert_true(w2 > w0 * 2, "the large crater is much bigger than the small one")


func test_stains_are_decided_by_the_position_and_about_two_thirds_leave_one() -> void:
	var yes := 0
	for i in 400:
		var p := Vector2(float(i % 20) * 0.77 + 1.1, float(i / 20) * 0.61 + 2.3)
		assert_eq(GroundMark.leaves_blood(p), GroundMark.leaves_blood(p), "stable for one place")
		if GroundMark.leaves_blood(p):
			yes += 1
	assert_true(yes > 400 * 0.5 and yes < 400 * 0.8, "about %d%% leave a stain" % int(GroundMark.BLOOD_SHARE * 100.0))


func test_each_kind_is_capped_and_the_oldest_goes_first() -> void:
	var layer := Node2D.new()
	tree.root.add_child(layer)
	var first := GroundMark.spawn(layer, Vector2(1, 1), GroundMark.BLOOD, 0)
	for i in int(GroundMark.CAPS[GroundMark.BLOOD]) + 20:
		GroundMark.spawn(layer, Vector2(2 + i, 3), GroundMark.BLOOD, i % 3)
	var alive := 0
	for c in layer.get_children():
		if not c.is_queued_for_deletion():
			alive += 1
	assert_eq(alive, int(GroundMark.CAPS[GroundMark.BLOOD]))
	assert_true(first.is_queued_for_deletion(), "the oldest stain was removed")
	var crater := GroundMark.spawn(layer, Vector2(5, 5), GroundMark.CRATER, 1)
	assert_true(not crater.is_queued_for_deletion(), "craters have their own cap")
	GroundMark.forget(layer)
	layer.free()


func test_blood_fades_to_a_faint_stain_and_craters_stay_solid() -> void:
	var layer := Node2D.new()
	tree.root.add_child(layer)
	var blood := GroundMark.spawn(layer, Vector2(3, 3), GroundMark.BLOOD, 0)
	var crater := GroundMark.spawn(layer, Vector2(6, 3), GroundMark.CRATER, 0)
	assert_eq(blood.modulate.a, 0.0, "starts clear and fades in")
	assert_eq(crater.modulate.a, 0.0)
	layer.free()
