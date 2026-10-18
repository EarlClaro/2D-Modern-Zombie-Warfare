extends TestCase
## The effect sprite strips (docs/specs/art-gaps.md, G.2): present, square frames, and the frame picker stays in range.


func test_strips_exist_with_square_frames() -> void:
	for sheet in ["explosion", "smoke", "flash"]:
		var t := FxSheet.texture(sheet)
		assert_true(t != null, sheet)
		assert_eq(t.get_width() % t.get_height(), 0, "%s frames are square" % sheet)
		assert_true(FxSheet.frame_count(sheet) >= 4, sheet)


func test_frame_at_covers_the_range_and_never_overruns() -> void:
	assert_eq(FxSheet.frame_at(0.0, 0, 4), 0)
	assert_eq(FxSheet.frame_at(0.5, 0, 4), 2)
	assert_eq(FxSheet.frame_at(1.0, 0, 4), 4)
	assert_eq(FxSheet.frame_at(5.0, 0, 4), 4)
	assert_eq(FxSheet.frame_at(-1.0, 2, 5), 2)


func test_missing_sheet_is_not_drawn() -> void:
	var n := Node2D.new()
	assert_true(not FxSheet.draw_centered(n, "no_such_sheet", 0, Vector2.ZERO, 10.0))
	n.free()


func test_effects_survive_a_full_life_with_the_sprites() -> void:
	var parent := Node2D.new()
	tree.root.add_child(parent)
	Explosion.spawn(parent, Vector2(5, 5), 2.0)
	VehicleExplosion.spawn(parent, Vector2.ZERO, 24.0)
	DeathPuff.spawn(parent, Vector2.ZERO)
	MuzzleFlash.spawn(parent, Vector2.ZERO, Vector2.RIGHT)
	for child in parent.get_children():
		child.call("_process", 0.05)
	assert_true(parent.get_child_count() == 4)
	parent.queue_free()
