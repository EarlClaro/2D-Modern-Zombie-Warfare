extends TestCase
## The line strike (close air support): a pass that lays missiles down one after another along a strip,
## instead of scattering shells over a circle.

const DT: float = 1.0 / 60.0
const TARGET := Vector2i(12, 10)  # open grass, nothing built on it

var _db: ContentDb
var _made: Array[BattleController] = []


func _get_db() -> ContentDb:
	if _db == null:
		_db = ContentDb.load_from()
	return _db


func _op() -> OperationDefinition:
	return _get_db().operation("close_air_support")


func _battle(seed_value: int = 1) -> BattleController:
	var b := BattleController.new()
	b.auto_step = false
	b.setup(_get_db(), _get_db().mission("m2_card_defense"), seed_value)
	_made.append(b)
	return b


func _release() -> void:
	for b in _made:
		b.free()
	_made.clear()


func _run_for(b: BattleController, seconds: float) -> void:
	for i in int(round(seconds / DT)):
		b.step(DT)


func _inject_enemy(b: BattleController, pos: Vector2) -> BattleEnemy:
	b._spawn_enemy(b.mission.waves[0])
	var e: BattleEnemy = b.enemies.back()
	e.ground_pos = pos
	e.def = e.def.duplicate()
	e.def.move_speed = 0.0
	e.def.max_health = 100000.0
	e.health = Health.new(100000.0)
	return e


func _rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r


# --- data -------------------------------------------------------------------------------------------------------

func test_the_shipped_close_air_support_card_is_valid_and_uses_the_line_pattern() -> void:
	var db := _get_db()
	assert_true(db.is_valid(), "content errors: %s" % ", ".join(db.errors))
	var card := db.card("close_air_support")
	assert_true(card != null and card.card_kind == CardDefinition.CardKind.OPERATION)
	assert_eq(card.effect_id, "close_air_support")
	assert_eq(card.max_copies, 1, "a rare, heavy support")
	var op := _op()
	assert_eq(op.pattern, OperationDefinition.Pattern.LINE)
	assert_eq(op.projectile, OperationDefinition.Projectile.MISSILE)
	assert_eq(op.shell_count, 12, "three jets with four missiles each, like the clip")
	assert_eq(op.cutaway_id, "close_air_support")


func test_a_line_strike_needs_a_length_and_a_direction() -> void:
	var o: OperationDefinition = _op().duplicate()
	o.line_length = 0.0
	assert_true(o.validate().size() > 0, "a zero-length line is refused")
	o = _op().duplicate()
	o.line_direction = Vector2.ZERO
	assert_true(o.validate().size() > 0, "a zero direction is refused")
	o = _op().duplicate()
	o.accel = 1.5
	assert_true(o.validate().size() > 0, "accel above 1 is refused")


func test_the_artillery_strike_is_still_a_circular_scatter_of_shells() -> void:
	var art := _get_db().operation("artillery_strike")
	assert_eq(art.pattern, OperationDefinition.Pattern.SCATTER)
	assert_eq(art.projectile, OperationDefinition.Projectile.SHELL)
	assert_near(art.reach_radius(), art.target_radius + art.blast_radius)


# --- the pattern ------------------------------------------------------------------------------------------------

func test_impacts_run_along_the_line_in_order_and_stay_inside_the_strip() -> void:
	var op := _op()
	var centre := Vector2(20.0, 15.0)
	var pts := op.shell_targets(centre, _rng(7))
	var dir := op.line_dir()
	var side := Vector2(-dir.y, dir.x)
	assert_eq(pts.size(), op.shell_count)
	var prev := -INF
	for p in pts:
		var along := (p - centre).dot(dir)
		assert_true(along > prev, "each missile lands further along the pass than the one before")
		prev = along
		assert_true(absf(along) <= op.line_length * 0.5, "inside the length")
		assert_true(absf((p - centre).dot(side)) <= op.target_radius + 1e-4, "inside the width")


func test_the_pass_is_centred_on_the_target() -> void:
	var op := _op()
	var centre := Vector2(20.0, 15.0)
	var along_sum := 0.0
	for p in op.shell_targets(centre, _rng(3)):
		along_sum += (p - centre).dot(op.line_dir())
	assert_near(along_sum, 0.0, 1e-3, "evenly spaced about the middle")


func test_the_same_seed_gives_the_same_pass_and_another_seed_a_different_one() -> void:
	var op := _op()
	var a := op.shell_targets(Vector2(10, 10), _rng(5))
	var b := op.shell_targets(Vector2(10, 10), _rng(5))
	var c := op.shell_targets(Vector2(10, 10), _rng(6))
	assert_eq(a, b)
	assert_true(a != c)


func test_the_reach_of_a_line_covers_its_far_corner() -> void:
	var op := _op()
	assert_true(op.reach_radius() >= op.line_length * 0.5 + op.blast_radius - 1e-6)


func test_a_ground_strip_projects_to_four_corners_about_its_centre() -> void:
	var poly := IsoProjection.ground_strip_polygon(Vector2(10, 10), Vector2(1, -1).normalized(), 5.0, 2.0)
	assert_eq(poly.size(), 4)
	var mid := (poly[0] + poly[2]) * 0.5
	assert_near(mid.distance_to(IsoProjection.ground_to_screen(Vector2(10, 10))), 0.0, 1e-3)


# --- in a battle ------------------------------------------------------------------------------------------------

func test_playing_the_card_queues_every_missile_launches_them_from_altitude_and_shows_a_strip() -> void:
	var b := _battle()
	b.deck.hand = ["close_air_support"] as Array[String]
	b.points.cp = 10.0
	var seen: Array[String] = []
	b.cutaway_requested.connect(func(id: String) -> void: seen.append(id))
	assert_true(b.play_card(0, TARGET).ok)
	assert_eq(b.projectiles.count(), 12)
	assert_eq(seen, ["close_air_support"] as Array[String])
	assert_eq(b.strikes.size(), 1)
	assert_near(b.strikes[0].line_half_len, _op().line_length * 0.5)
	assert_near(b.strikes[0].line_dir.length(), 1.0, 1e-4)
	assert_eq(b.projectiles.kind_of(0), ProjectileSystem.KIND_MISSILE)
	_release()


func test_enemies_on_the_strip_are_hit_and_those_off_to_the_side_are_not() -> void:
	var b := _battle()
	b.deck.hand = ["close_air_support"] as Array[String]
	b.points.cp = 10.0
	var op := _op()
	var centre := IsoProjection.cell_center(TARGET)
	var dir := op.line_dir()
	var side := Vector2(-dir.y, dir.x)
	var under := _inject_enemy(b, centre + dir * (op.line_length * 0.25))
	var off := _inject_enemy(b, centre + side * (op.target_radius + op.blast_radius + 2.0))
	var past := _inject_enemy(b, centre + dir * (op.line_length * 0.5 + op.blast_radius + 2.0))
	b.play_card(0, TARGET)
	_run_for(b, op.total_duration_s() + 0.2)
	assert_true(under.health.hp < under.health.max_hp, "an enemy on the line is hit")
	assert_near(off.health.hp, off.health.max_hp, 1e-9, "beside the strip: untouched")
	assert_near(past.health.hp, past.health.max_hp, 1e-9, "beyond its end: untouched")
	_release()


func test_the_first_missile_lands_at_the_tail_and_the_last_at_the_head() -> void:
	var op := _op()
	var b := _battle()
	b.deck.hand = ["close_air_support"] as Array[String]
	b.points.cp = 10.0
	var centre := IsoProjection.cell_center(TARGET)
	var dir := op.line_dir()
	var tail := _inject_enemy(b, centre - dir * (op.line_length * 0.45))
	var head := _inject_enemy(b, centre + dir * (op.line_length * 0.45))
	b.play_card(0, TARGET)
	var tail_hit_at := -1.0
	var head_hit_at := -1.0
	var t := 0.0
	while t < op.total_duration_s() + 0.2:
		b.step(DT)
		t += DT
		if tail_hit_at < 0.0 and tail.health.hp < tail.health.max_hp:
			tail_hit_at = t
		if head_hit_at < 0.0 and head.health.hp < head.health.max_hp:
			head_hit_at = t
	assert_true(tail_hit_at > 0.0 and head_hit_at > tail_hit_at, "the pass sweeps from the tail to the head (%.2f then %.2f)" % [tail_hit_at, head_hit_at])
	_release()
