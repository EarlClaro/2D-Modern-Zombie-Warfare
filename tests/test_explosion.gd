extends TestCase
## The ground explosion effect (area weapons: tank cannon, artillery shells, helicopter missiles) and its wiring.

const DT: float = 1.0 / 60.0

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


func test_phase_clamps_between_zero_and_one() -> void:
	assert_near(Explosion.phase(-1.0, 0.5), 0.0)
	assert_near(Explosion.phase(0.25, 0.5), 0.5)
	assert_near(Explosion.phase(9.0, 0.5), 1.0)


func test_the_fireball_swells_then_shrinks_and_never_goes_negative_or_oversize() -> void:
	assert_near(Explosion.fireball_size(0.0), 0.0, 1e-9, "starts as nothing")
	var peak := 0.0
	var peak_t := 0.0
	for k in 101:
		var t := k / 100.0
		var v := Explosion.fireball_size(t)
		assert_true(v >= 0.0 and v <= 1.0 + 1e-9, "size %.3f at %.2f in range" % [v, t])
		if v > peak:
			peak = v
			peak_t = t
	assert_true(peak_t > 0.2 and peak_t < 0.7, "biggest around the middle of its life (%.2f)" % peak_t)
	assert_true(peak > 0.6, "and properly big (%.2f)" % peak)
	assert_true(Explosion.fireball_size(1.0) < peak, "shrinking by the end")


func test_it_appears_at_the_projected_ground_point_and_cleans_itself_up() -> void:
	var holder := Node2D.new()
	tree.root.add_child(holder)
	_roots.append(holder)
	Explosion.spawn(holder, Vector2(10, 4), 1.8)
	assert_eq(holder.get_child_count(), 1)
	var e: Explosion = holder.get_child(0)
	assert_vec_near(e.position, IsoProjection.ground_to_screen(Vector2(10, 4)))
	assert_near(e.radius_tiles, 1.8)
	e._process(Explosion.LIFE_S * 0.5)
	assert_true(not e.is_queued_for_deletion())
	e._process(Explosion.LIFE_S)
	assert_true(e.is_queued_for_deletion(), "frees itself when its smoke has gone")
	_release()


func test_a_degenerate_radius_still_gives_a_visible_explosion() -> void:
	var holder := Node2D.new()
	tree.root.add_child(holder)
	_roots.append(holder)
	Explosion.spawn(holder, Vector2.ZERO, 0.0)
	assert_true((holder.get_child(0) as Explosion).radius_tiles > 0.0)
	_release()


func test_every_area_blast_in_a_battle_shows_an_explosion_of_the_blast_radius() -> void:
	var b := _battle_with_feedback()
	b.blast_landed.emit(Vector2(12, 12), 1.8)
	assert_eq(_count_of(b.fx_layer(), "Explosion"), 1)
	var e: Explosion = null
	for c in b.fx_layer().get_children():
		if c is Explosion:
			e = c
	assert_near(e.radius_tiles, 1.8, 1e-9, "the picture is the area that is hurt")
	assert_vec_near(e.position, IsoProjection.ground_to_screen(Vector2(12, 12)))
	b.blast_landed.emit(Vector2(14, 12), 3.0)
	assert_eq(_count_of(b.fx_layer(), "Explosion"), 2)
	_release()


func test_a_helicopter_missile_landing_produces_that_explosion() -> void:
	var b := _battle_with_feedback()
	var rocket := b.db.weapon("heli_missile")
	var centre := IsoProjection.cell_center(Vector2i(12, 12))
	b.projectiles.spawn(centre + Vector2(-5, 0), centre, 0.4, 0.0, rocket.damage, rocket.blast_radius, 0.0, 3.0, ProjectileSystem.KIND_MISSILE, rocket.projectile_accel, rocket.projectile_drop)
	for i in 40:
		b.step(DT)
	assert_eq(_count_of(b.fx_layer(), "Explosion"), 1, "one explosion where the missile hit")
	_release()


func test_restart_clears_leftover_explosions() -> void:
	var b := _battle_with_feedback()
	b.blast_landed.emit(Vector2(12, 12), 1.8)
	assert_eq(_count_of(b.fx_layer(), "Explosion"), 1)
	b.restart()
	assert_eq(_count_of(b.fx_layer(), "Explosion"), 0)
	_release()
