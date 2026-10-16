extends TestCase
## Strike cutaways (docs/specs/strike-cutaways.md): the definition and its tiers, the pure plan (full first, short
## after, off, skip, restart), content validation, and the battle hooks (request, freeze, input block, no effect on
## the result of a battle).

const DT: float = 1.0 / 60.0
const TARGET := Vector2i(12, 10)

var _db: ContentDb
var _made: Array[BattleController] = []


func _get_db() -> ContentDb:
	if _db == null:
		_db = ContentDb.load_from()
	return _db


func _def(tier: CutawayDefinition.Tier = CutawayDefinition.Tier.LARGE, id: String = "clip") -> CutawayDefinition:
	var d := CutawayDefinition.new()
	d.id = id
	d.display_name = "Clip"
	d.scene = "title_card"
	d.tier = tier
	return d


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


func _has(errs: PackedStringArray, needle: String) -> bool:
	for e in errs:
		if needle in e:
			return true
	return false


# --- definition -----------------------------------------------------------------------------------------------

func test_tiers_set_the_default_durations() -> void:
	assert_near(_def(CutawayDefinition.Tier.EPIC).full_duration(), 2.0)
	assert_near(_def(CutawayDefinition.Tier.EPIC).short_duration(), 1.0)
	assert_near(_def(CutawayDefinition.Tier.LARGE).full_duration(), 1.5)
	assert_near(_def(CutawayDefinition.Tier.LARGE).short_duration(), 0.5)
	assert_near(_def(CutawayDefinition.Tier.SMALL).full_duration(), 0.8)
	assert_near(_def(CutawayDefinition.Tier.SMALL).short_duration(), 0.3)


func test_overrides_replace_the_tier_and_nothing_exceeds_the_hard_cap() -> void:
	var d := _def()
	d.full_s = 2.5
	d.short_s = 0.9
	assert_near(d.full_duration(), 2.5)
	assert_near(d.short_duration(), 0.9)
	d.full_s = 9.0
	assert_near(d.full_duration(), CutawayDefinition.HARD_CAP_S, 1e-6, "capped")
	assert_true(_has(d.validate(), "<= 3"), "an over-long override is reported")


func test_a_valid_definition_has_no_errors_and_bad_ones_are_named() -> void:
	assert_eq(_def().validate().size(), 0)
	var no_name := _def()
	no_name.display_name = ""
	assert_true(_has(no_name.validate(), "display_name"))
	var no_scene := _def()
	no_scene.scene = ""
	assert_true(_has(no_scene.validate(), "scene"))
	var bad_sound := _def()
	bad_sound.sound = "kazoo"
	assert_true(_has(bad_sound.validate(), "unknown sound"))
	var backwards := _def()
	backwards.full_s = 0.4
	backwards.short_s = 0.8
	assert_true(_has(backwards.validate(), "short clip is longer"))
	var negative := _def()
	negative.full_s = -1.0
	assert_true(_has(negative.validate(), ">= 0"))


# --- plan -----------------------------------------------------------------------------------------------------

func test_full_the_first_time_then_short() -> void:
	var plan := CutawayPlan.new()
	var d := _def()
	assert_eq(plan.request(d), CutawayPlan.Mode.FULL)
	assert_near(plan.duration(), 1.5)
	plan.skip()
	assert_eq(plan.request(d), CutawayPlan.Mode.SHORT, "seen once, so short")
	assert_near(plan.duration(), 0.5)


func test_each_support_is_seen_separately() -> void:
	var plan := CutawayPlan.new()
	plan.request(_def(CutawayDefinition.Tier.LARGE, "a"))
	plan.skip()
	plan.tick(0.016)  # a frame later
	assert_eq(plan.request(_def(CutawayDefinition.Tier.LARGE, "b")), CutawayPlan.Mode.FULL, "another support is new")


func test_switched_off_shows_nothing() -> void:
	var plan := CutawayPlan.new()
	plan.enabled = false
	assert_eq(plan.request(_def()), CutawayPlan.Mode.NONE)
	assert_true(not plan.is_playing())
	assert_eq(plan.request(null), CutawayPlan.Mode.NONE, "no definition, no clip")


func test_a_clip_runs_for_its_length_and_reports_the_end_once() -> void:
	var plan := CutawayPlan.new()
	plan.request(_def(CutawayDefinition.Tier.SMALL))
	assert_near(plan.progress(), 0.0)
	assert_true(not plan.tick(0.4))
	assert_near(plan.progress(), 0.5)
	assert_true(plan.is_playing())
	assert_true(plan.tick(0.4), "ends on the tick that reaches the length")
	assert_true(not plan.is_playing())
	assert_true(not plan.tick(0.4), "and only once")


func test_skip_ends_it_at_once_and_a_second_request_cannot_stack() -> void:
	var plan := CutawayPlan.new()
	plan.request(_def())
	assert_eq(plan.request(_def(CutawayDefinition.Tier.EPIC, "other")), CutawayPlan.Mode.NONE, "one clip at a time")
	plan.skip()
	assert_true(not plan.is_playing())
	assert_near(plan.progress(), 1.0, 1e-6, "nothing running counts as finished")


func test_a_request_in_the_tick_a_clip_ended_is_short() -> void:
	var plan := CutawayPlan.new()
	plan.request(_def(CutawayDefinition.Tier.SMALL, "a"))
	assert_true(plan.tick(5.0))
	assert_eq(plan.request(_def(CutawayDefinition.Tier.LARGE, "b")), CutawayPlan.Mode.SHORT, "same tick as an end: short even though new")
	plan.skip()
	plan.tick(0.016)
	var plan2 := CutawayPlan.new()
	plan2.request(_def(CutawayDefinition.Tier.SMALL, "a"))
	plan2.tick(5.0)
	plan2.tick(0.016)
	assert_eq(plan2.request(_def(CutawayDefinition.Tier.LARGE, "b")), CutawayPlan.Mode.FULL, "a tick later it is new again")


func test_reset_forgets_what_was_seen_and_drops_the_running_clip() -> void:
	var plan := CutawayPlan.new()
	var d := _def()
	plan.request(d)
	plan.reset()
	assert_true(not plan.is_playing())
	assert_eq(plan.request(d), CutawayPlan.Mode.FULL, "a restart shows the full version again")


func test_a_clip_never_outlasts_the_hard_cap() -> void:
	var d := _def(CutawayDefinition.Tier.EPIC)
	d.full_s = 99.0
	var plan := CutawayPlan.new()
	plan.request(d)
	assert_true(plan.duration() <= CutawayDefinition.HARD_CAP_S)


# --- content --------------------------------------------------------------------------------------------------

func test_shipped_content_is_valid_and_artillery_has_a_clip() -> void:
	var db := _get_db()
	assert_true(db.is_valid(), "content errors: %s" % ", ".join(db.errors))
	var op := db.operation("artillery_strike")
	assert_eq(op.cutaway_id, "artillery_barrage")
	var c := db.cutaway("artillery_barrage")
	assert_true(c != null)
	assert_eq(c.tier, CutawayDefinition.Tier.SMALL, "the barrage is a small clip")
	assert_true(CutawayScenes.has(c.scene))


func test_unknown_cutaway_and_scene_references_are_reported() -> void:
	var db := ContentDb.new()
	var op := OperationDefinition.new()
	op.id = "op"
	op.display_name = "Op"
	op.cutaway_id = "nope"
	db.add_operation(op)
	var c := _def()
	c.scene = "no_such_scene"
	db.add_cutaway(c)
	var card := CardDefinition.new()
	card.id = "sortie_card"
	card.display_name = "S"
	card.card_kind = CardDefinition.CardKind.SORTIE
	card.unit_id = "x"
	card.station_time_s = 1.0
	card.cutaway_id = "also_nope"
	db.add_card(card)
	db.validate_references()
	var text := "\n".join(db.errors)
	assert_true("operation 'op': unknown cutaway_id 'nope'" in text, text)
	assert_true("cutaway 'clip': unknown scene 'no_such_scene'" in text, text)
	assert_true("card 'sortie_card': unknown cutaway_id 'also_nope'" in text, text)


func test_every_scene_recipe_builds() -> void:
	for id in CutawayScenes.ids():
		assert_true(CutawayScenes.build(id) != null, "%s builds" % id)
	assert_true(CutawayScenes.build("nope") == null)


func test_launch_option_switches_cutaways_off() -> void:
	assert_eq(BattleController.parse_user_args(PackedStringArray(["--cutaways=off"])), {"cutaways": false})
	assert_eq(BattleController.parse_user_args(PackedStringArray(["--cutaways=on", "--seed=3"])), {"cutaways": true, "seed": 3})
	assert_eq(BattleController.parse_user_args(PackedStringArray(["--cutaways=maybe"])), {})


# --- battle ---------------------------------------------------------------------------------------------------

func _arm(b: BattleController) -> void:
	b.deck.hand = ["artillery_strike", "artillery_strike"] as Array[String]
	b.points.cp = 10.0


func test_playing_the_strike_requests_its_clip_after_the_card_is_played() -> void:
	var b := _battle()
	_arm(b)
	var seen: Array[String] = []
	b.cutaway_requested.connect(func(id: String) -> void: seen.append(id))
	assert_true(b.play_card(0, TARGET).ok)
	assert_eq(seen, ["artillery_barrage"] as Array[String])
	assert_eq(b.strikes.size(), 1, "the strike itself started as before")
	_release()


func test_a_card_without_a_clip_requests_nothing() -> void:
	var b := _battle()
	b.deck.hand = ["rifle_squad"] as Array[String]
	b.points.cp = 10.0
	var seen: Array[String] = []
	b.cutaway_requested.connect(func(id: String) -> void: seen.append(id))
	var cell := IsoProjection.cell_of(b.core.ground_pos) + Vector2i(2, 0)
	b.play_card(0, cell)
	assert_eq(seen.size(), 0)
	_release()


func test_frozen_stops_ticks_and_card_input() -> void:
	var b := _battle()
	_arm(b)
	b.step(DT)
	var t := b.elapsed
	b.frozen = true
	for i in 30:
		b.step(DT)
	assert_near(b.elapsed, t, 1e-9, "no time passes while frozen")
	b.select_slot(0)
	assert_true(not b.targeting.is_selecting(), "no card can be picked")
	assert_true(b.confirm_at(TARGET) == null, "and none played")
	b.frozen = false
	b.step(DT)
	assert_true(b.elapsed > t, "it runs again after")
	_release()


func test_a_restart_unfreezes_the_battle() -> void:
	var b := _battle()
	b.frozen = true
	b.restart()
	assert_true(not b.frozen)
	_release()


func test_the_player_freezes_during_a_clip_and_releases_it_when_it_ends() -> void:
	var b := _battle()
	_arm(b)
	var player := CutawayPlayer.new()
	tree.root.add_child(b)
	b.add_child(player)
	player.bind(b)
	assert_eq(player.play("artillery_barrage"), CutawayPlan.Mode.FULL)
	assert_true(b.frozen and player.is_playing())
	player._process(0.5)
	assert_true(b.frozen)
	player._process(0.5)  # a small clip is 0.8 s
	assert_true(not b.frozen and not player.is_playing(), "released when the clip ends")
	assert_eq(player.play("artillery_barrage"), CutawayPlan.Mode.SHORT, "short the second time")
	player.skip()
	assert_true(not b.frozen, "skip releases at once")
	player.plan.enabled = false
	assert_eq(player.play("artillery_barrage"), CutawayPlan.Mode.NONE)
	assert_true(not b.frozen, "off means never frozen")
	b.restart()
	player.plan.enabled = true
	assert_eq(player.play("artillery_barrage"), CutawayPlan.Mode.FULL, "restart forgets what was seen")
	b.restart()
	assert_true(not b.frozen and not player.is_playing(), "and cancels a running clip")
	tree.root.remove_child(b)
	_release()


func test_a_battle_with_clips_gives_the_same_result_as_one_without() -> void:
	var plain := _battle(7)
	var clipped := _battle(7)
	var player := CutawayPlayer.new()
	tree.root.add_child(clipped)
	clipped.add_child(player)
	player.bind(clipped)
	for b in [plain, clipped]:
		_arm(b)
		b.points.cp = 10.0
	for i in 600:
		if i == 60:
			plain.play_card(0, TARGET)
			clipped.play_card(0, TARGET)  # requests the clip, which freezes `clipped`
			assert_true(clipped.frozen)
		plain.step(DT)
		if clipped.frozen:
			clipped.step(DT)  # frozen: a no-op, as it would be while the real clip runs
			if i >= 90:
				player.skip()
		else:
			clipped.step(DT)
	# the clipped battle lost the frozen ticks: run the plain one the same number of ticks to compare like with like
	var lost := int(round((plain.elapsed - clipped.elapsed) / DT))
	assert_true(lost > 0 and lost < 60, "some ticks were frozen (%d)" % lost)
	for i in lost:
		clipped.step(DT)
	assert_near(plain.elapsed, clipped.elapsed, 1e-6)
	assert_eq(plain.enemies.size(), clipped.enemies.size(), "same enemies alive")
	assert_eq(plain.stats, clipped.stats, "same kills and spawns")
	assert_near(plain.core.health.hp, clipped.core.health.hp, 1e-6, "same core hit points")
	tree.root.remove_child(clipped)
	_release()
