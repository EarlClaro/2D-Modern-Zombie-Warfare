extends TestCase
## BattleModifiers (orders and doctrines in force), StateEffectDefinition, and the small economy/deck helpers the
## state cards use (CommandPoints.gain, DeckState.draw).


func _effect(id: String = "e", duration: float = 10.0, armor: float = 0.0, mult: float = 1.0, weapons: Array[String] = []) -> StateEffectDefinition:
	var e := StateEffectDefinition.new()
	e.id = id
	e.display_name = "Effect"
	e.duration_s = duration
	e.armor_bonus = armor
	e.damage_mult = mult
	e.weapon_ids = PackedStringArray(weapons)
	return e


func _has(errs: PackedStringArray, needle: String) -> bool:
	for e in errs:
		if needle in e:
			return true
	return false


# --- StateEffectDefinition ---------------------------------------------------------------------------------

func test_a_modifier_effect_is_valid_and_reports_what_it_is() -> void:
	var e := _effect("fort", 20.0, 4.0)
	assert_eq(e.validate().size(), 0)
	assert_true(e.is_modifier())
	assert_true(e.does_something())
	assert_true(_effect("dmg", 0.0, 0.0, 1.15).is_modifier())


func test_an_effect_that_does_nothing_is_an_error() -> void:
	assert_true(_has(_effect("idle").validate(), "does nothing"))


func test_effect_field_errors_name_the_effect_and_field() -> void:
	var e := _effect("bad_one", -1.0, -2.0, 0.0)
	e.cp_gain = -1.0
	e.draw_count = -1
	e.display_name = ""
	var errs := e.validate()
	for needle in ["display_name", "duration_s", "armor_bonus", "damage_mult", "cp_gain", "draw_count"]:
		assert_true(_has(errs, needle), needle)
	assert_true(_has(errs, "bad_one"))


func test_supply_and_draw_effects_are_not_modifiers() -> void:
	var supply := _effect("sup", 0.0)
	supply.cp_gain = 3.0
	assert_eq(supply.validate().size(), 0)
	assert_true(not supply.is_modifier())
	var draw := _effect("drw", 0.0)
	draw.draw_count = 2
	assert_eq(draw.validate().size(), 0)
	assert_true(not draw.is_modifier())
	var ammo := _effect("amm", 0.0)
	ammo.refill_ammo = true
	assert_eq(ammo.validate().size(), 0)


# --- BattleModifiers ------------------------------------------------------------------------------------------

func test_nothing_active_changes_nothing() -> void:
	var m := BattleModifiers.new()
	assert_near(m.armor_bonus(), 0.0)
	assert_near(m.damage_mult("rifle"), 1.0)
	assert_eq(m.active().size(), 0)


func test_an_armor_order_adds_armor_until_it_runs_out() -> void:
	var m := BattleModifiers.new()
	assert_true(m.apply(_effect("fort", 10.0, 4.0)))
	assert_near(m.armor_bonus(), 4.0)
	assert_true(m.is_active("fort"))
	m.tick(9.9)
	assert_near(m.armor_bonus(), 4.0, 1e-6, "still on just before the end")
	assert_near(m.time_left("fort"), 0.1, 1e-6)
	m.tick(0.1)
	assert_near(m.armor_bonus(), 0.0)
	assert_true(not m.is_active("fort"))
	assert_near(m.time_left("fort"), 0.0)


func test_many_small_ticks_end_an_order_on_time() -> void:
	var m := BattleModifiers.new()
	m.apply(_effect("fort", 20.0, 4.0))
	for i in 1200:
		m.tick(1.0 / 60.0)
	assert_true(not m.is_active("fort"), "20 s of 60 Hz ticks ends a 20 s order")


func test_float_error_does_not_keep_an_order_alive_a_tick_too_long() -> void:
	var m := BattleModifiers.new()
	m.apply(_effect("fort", 1.0, 4.0))
	for i in 10:
		m.tick(0.1)  # 1.0 - ten times 0.1 leaves about 1.4e-16 in doubles
	assert_true(not m.is_active("fort"))


func test_a_zero_duration_effect_is_permanent() -> void:
	var m := BattleModifiers.new()
	m.apply(_effect("doc", 0.0, 0.0, 1.15, ["rifle"] as Array[String]))
	assert_near(m.time_left("doc"), -1.0)
	m.tick(100000.0)
	assert_true(m.is_active("doc"))
	assert_near(m.damage_mult("rifle"), 1.15)


func test_playing_the_same_order_again_refreshes_it_instead_of_stacking() -> void:
	var m := BattleModifiers.new()
	var fort := _effect("fort", 10.0, 4.0)
	m.apply(fort)
	m.tick(7.0)
	m.apply(fort)
	assert_near(m.armor_bonus(), 4.0, 1e-9, "not 8")
	assert_near(m.time_left("fort"), 10.0, 1e-9, "the timer starts over")
	assert_eq(m.active().size(), 1)


func test_different_orders_add_up() -> void:
	var m := BattleModifiers.new()
	m.apply(_effect("a", 10.0, 4.0))
	m.apply(_effect("b", 5.0, 2.0))
	assert_near(m.armor_bonus(), 6.0)
	m.tick(5.0)
	assert_near(m.armor_bonus(), 4.0, 1e-9, "the shorter one ended")


func test_damage_multipliers_apply_only_to_the_listed_weapons() -> void:
	var m := BattleModifiers.new()
	m.apply(_effect("hp", 0.0, 0.0, 1.15, ["rifle"] as Array[String]))
	assert_near(m.damage_mult("rifle"), 1.15)
	assert_near(m.damage_mult("gatling"), 1.0)
	m.apply(_effect("all", 0.0, 0.0, 2.0))
	assert_near(m.damage_mult("gatling"), 2.0, 1e-9, "an effect with no weapon list covers every weapon")
	assert_near(m.damage_mult("rifle"), 2.3, 1e-9, "multipliers multiply")


func test_effects_that_are_not_modifiers_are_ignored() -> void:
	var m := BattleModifiers.new()
	var supply := _effect("sup", 0.0)
	supply.cp_gain = 3.0
	assert_true(not m.apply(supply))
	assert_true(not m.apply(null))
	assert_eq(m.active().size(), 0)


func test_clear_removes_everything_and_non_positive_ticks_do_nothing() -> void:
	var m := BattleModifiers.new()
	m.apply(_effect("a", 10.0, 4.0))
	m.tick(0.0)
	m.tick(-5.0)
	assert_near(m.time_left("a"), 10.0)
	m.clear()
	assert_eq(m.active().size(), 0)
	assert_near(m.armor_bonus(), 0.0)


func test_active_lists_effects_in_the_order_they_started() -> void:
	var m := BattleModifiers.new()
	m.apply(_effect("first", 10.0, 1.0))
	m.apply(_effect("second", 10.0, 1.0))
	var ids: Array[String] = []
	for a in m.active():
		ids.append(a.effect.id)
	assert_eq(ids, ["first", "second"] as Array[String])


# --- helpers used by the state cards ---------------------------------------------------------------------------

func test_command_points_gain_stops_at_the_cap_and_ignores_negatives() -> void:
	var p := CommandPoints.new(4.0, 10.0, 0.5)
	p.gain(3.0)
	assert_near(p.cp, 7.0)
	p.gain(100.0)
	assert_near(p.cp, 10.0)
	p.gain(-5.0)
	assert_near(p.cp, 10.0, 1e-9, "a negative gain is not a spend")


func _deck(draw_pile: Array[String], hand: Array[String], cap: int = 5) -> DeckState:
	var rules := DeckRules.new()
	rules.hand_cap = cap
	var d := DeckState.new(rules, [] as Array[String], RandomNumberGenerator.new())
	d.draw_pile = draw_pile
	d.hand = hand
	return d


func test_deck_draw_takes_cards_from_the_pile_up_to_the_count() -> void:
	var d := _deck(["a", "b", "c"] as Array[String], [] as Array[String])
	assert_eq(d.draw(2), 2)
	assert_eq(d.hand, ["c", "b"] as Array[String], "drawn from the end of the pile")
	assert_eq(d.draw_pile, ["a"] as Array[String])


func test_deck_draw_stops_at_a_full_hand() -> void:
	var d := _deck(["a", "b", "c"] as Array[String], ["x", "y", "z", "w"] as Array[String])
	assert_eq(d.draw(2), 1)
	assert_eq(d.hand.size(), 5)
	assert_eq(d.draw_pile.size(), 2, "the second card stayed in the pile")


func test_deck_draw_stops_when_nothing_is_left_and_reshuffles_the_discard() -> void:
	var d := _deck([] as Array[String], [] as Array[String])
	assert_eq(d.draw(3), 0, "nothing anywhere")
	d.discard = ["p", "q"] as Array[String]
	assert_eq(d.draw(3), 2, "the discard pile was reshuffled and drawn")
	assert_eq(d.discard.size(), 0)
	assert_eq(d.draw(0), 0)
	assert_eq(d.draw(-1), 0)


func test_deck_rules_refuse_a_doctrine_card_in_a_deck() -> void:
	var rules := DeckRules.new()
	rules.deck_min = 1
	rules.deck_max = 5
	var c := CardDefinition.new()
	c.id = "doc"
	c.card_kind = CardDefinition.CardKind.DOCTRINE
	var errs := rules.validate_deck(["doc"] as Array[String], {"doc": c})
	assert_true(_has(errs, "doctrine card 'doc'"))
	c.card_kind = CardDefinition.CardKind.ORDER
	assert_eq(rules.validate_deck(["doc"] as Array[String], {"doc": c}).size(), 0)
