extends TestCase
## The Supply Drop seen on the field and the pixel missile smoke (docs/specs/art-more.md, N.4).

var _roots: Array[Node] = []


func _release() -> void:
	for r in _roots:
		if is_instance_valid(r):
			r.get_parent().remove_child(r)
			r.free()
	_roots.clear()


func _count_of(layer: Node, script_class_name: String) -> int:
	var n := 0
	for c in layer.get_children():
		if c.get_script() != null and c.get_script().get_global_name() == script_class_name:
			n += 1
	return n


func _battle_with_feedback() -> BattleController:
	var db := ContentDb.load_from()
	var b := BattleController.new()
	b.auto_step = false
	b.setup(db, db.mission("m2_card_defense"), 1)
	tree.root.add_child(b)
	_roots.append(b)
	var fb := BattleFeedback.new()
	fb.name = "Feedback"
	b.add_child(fb)
	fb.bind(b)
	return b


func test_the_crate_comes_down_slowing_and_lands_at_ground_level() -> void:
	assert_near(SupplyDropFx.height_at(0.0), SupplyDropFx.START_HEIGHT_PX)
	assert_eq(SupplyDropFx.height_at(SupplyDropFx.FALL_S), 0.0)
	assert_eq(SupplyDropFx.height_at(SupplyDropFx.FALL_S + 5.0), 0.0, "stays on the ground")
	var last := SupplyDropFx.START_HEIGHT_PX + 1.0
	var steps := 20
	for i in steps + 1:
		var h := SupplyDropFx.height_at(SupplyDropFx.FALL_S * float(i) / float(steps))
		assert_true(h < last, "always falling")
		last = h
	var early := SupplyDropFx.height_at(0.0) - SupplyDropFx.height_at(0.3)
	var late := SupplyDropFx.height_at(SupplyDropFx.FALL_S - 0.3) - SupplyDropFx.height_at(SupplyDropFx.FALL_S)
	assert_true(late < early, "it slows towards the ground")


func test_playing_a_supply_card_drops_a_crate_near_the_core_and_it_cleans_itself_up() -> void:
	var b := _battle_with_feedback()
	var card: CardDefinition = b.db.card("supply_drop")
	b.card_played.emit(card, Vector2i.ZERO)
	assert_eq(_count_of(b.fx_layer(), "SupplyDropFx"), 1, "a parachute crate")
	var fx: SupplyDropFx = null
	for c in b.fx_layer().get_children():
		if c is SupplyDropFx:
			fx = c
	assert_true(fx.position.distance_to(IsoProjection.ground_to_screen(b.core.ground_pos)) < 400.0, "near the core")
	fx._age = SupplyDropFx.FALL_S - 0.01
	fx._process(0.02)
	assert_eq(_count_of(b.fx_layer(), "DeathPuff"), 1, "dust where it lands")
	fx._process(fx.total_s())
	assert_true(fx.is_queued_for_deletion(), "gone after the fade")
	_release()


func test_other_cards_drop_no_crate_and_restart_clears_one_in_the_air() -> void:
	var b := _battle_with_feedback()
	b.card_played.emit(b.db.card("tank"), Vector2i(8, 8))
	assert_eq(_count_of(b.fx_layer(), "SupplyDropFx"), 0)
	b.card_played.emit(b.db.card("supply_drop"), Vector2i.ZERO)
	assert_eq(_count_of(b.fx_layer(), "SupplyDropFx"), 1)
	b.restart()
	assert_eq(_count_of(b.fx_layer(), "SupplyDropFx"), 0, "restart clears it")
	_release()


func test_the_crate_pictures_exist() -> void:
	for name in ["chute", "chute_down", "crate"]:
		assert_true(load("res://assets/fx/%s.png" % name) != null, name)
	assert_true(FxSheet.texture("smoke") != null, "the missile smoke uses the smoke strip")
