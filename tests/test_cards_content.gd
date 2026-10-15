extends TestCase


func _card(id: String = "c1") -> CardDefinition:
	var c := CardDefinition.new()
	c.id = id
	c.display_name = "Card"
	c.cost = 2
	c.unit_id = "rifle_soldier"
	return c


func _has(errs: PackedStringArray, needle: String) -> bool:
	for e in errs:
		if needle in e:
			return true
	return false


# --- CardDefinition -------------------------------------------------------------------------------

func test_valid_card_has_no_errors() -> void:
	assert_eq(_card().validate().size(), 0)


func test_card_field_errors_name_the_card_and_field() -> void:
	var c := _card("bad_one")
	c.display_name = ""
	c.cost = -1
	c.lockout_s = -1.0
	c.max_copies = 4
	var errs := c.validate()
	for needle in ["display_name", "cost", "lockout_s", "max_copies"]:
		assert_true(_has(errs, needle), needle)
	assert_true(_has(errs, "bad_one"))


func test_deployment_and_sortie_need_a_unit_operation_needs_an_effect() -> void:
	var dep := _card()
	dep.unit_id = ""
	assert_true(_has(dep.validate(), "unit_id"))
	var sortie := _card()
	sortie.card_kind = CardDefinition.CardKind.SORTIE
	sortie.unit_id = ""
	assert_true(_has(sortie.validate(), "unit_id"))
	var op := _card()
	op.card_kind = CardDefinition.CardKind.OPERATION
	op.unit_id = ""
	assert_true(_has(op.validate(), "effect_id"))
	op.effect_id = "artillery_strike"
	assert_eq(op.validate().size(), 0)
	var zero := _card()
	zero.unit_count = 0
	assert_true(_has(zero.validate(), "unit_count"))


func test_card_id_format_is_enforced() -> void:
	assert_true(_has(_card("Bad Id").validate(), "snake_case"))


# --- DeckRules ----------------------------------------------------------------------------------

func test_default_rules_are_valid_and_match_the_spec() -> void:
	var r := DeckRules.new()
	r.id = "default"
	assert_eq(r.validate().size(), 0)
	assert_eq(r.hand_cap, 5)
	assert_eq(r.initial_hand, 4)
	assert_near(r.cp_per_second(), 1.0 / 1.5)


func test_rules_field_errors() -> void:
	var r := DeckRules.new()
	r.id = "default"
	r.deck_min = 0
	r.deck_max = -1
	r.hand_cap = 0
	r.draw_interval_s = 0.0
	r.cp_cap = 0.0
	r.cp_regen_interval_s = 0.0
	var errs := r.validate()
	for needle in ["deck_min", "deck_max", "hand_cap", "draw_interval_s", "cp_cap", "cp_regen_interval_s"]:
		assert_true(_has(errs, needle), needle)
	var r2 := DeckRules.new()
	r2.id = "default"
	r2.initial_hand = 9
	r2.cp_start = 99.0
	assert_true(_has(r2.validate(), "initial_hand"))
	assert_true(_has(r2.validate(), "cp_start"))


func _rules() -> DeckRules:
	var r := DeckRules.new()
	r.id = "default"
	return r


func _ids(card_id: String, n: int) -> Array[String]:
	var out: Array[String] = []
	for i in n:
		out.append(card_id)
	return out


func test_deck_size_window() -> void:
	var cards := {"a": _card("a"), "b": _card("b"), "c": _card("c"), "d": _card("d"), "e": _card("e"), "f": _card("f"), "g": _card("g"), "h": _card("h"), "i": _card("i")}
	var ok_ids: Array[String] = []
	for k in ["a", "b", "c", "d"]:
		ok_ids.append_array(_ids(k, 3))
	assert_eq(_rules().validate_deck(ok_ids, cards).size(), 0, "12 cards, 3 copies each is legal")
	var short := ok_ids.duplicate()
	short.pop_back()
	assert_true(_has(_rules().validate_deck(short, cards), "minimum"), "11 cards is below the minimum")
	var big: Array[String] = []
	for k in ["a", "b", "c", "d", "e", "f", "g", "h"]:
		big.append_array(_ids(k, 3))
	assert_eq(_rules().validate_deck(big, cards).size(), 0, "24 is the maximum")
	big.append("i")
	assert_true(_has(_rules().validate_deck(big, cards), "maximum"), "25 cards is too many")


func test_copy_limit_per_card() -> void:
	var cards := {"a": _card("a"), "b": _card("b"), "c": _card("c"), "d": _card("d")}
	var ids: Array[String] = []
	ids.append_array(_ids("a", 4))
	ids.append_array(_ids("b", 3))
	ids.append_array(_ids("c", 3))
	ids.append_array(_ids("d", 2))
	var errs := _rules().validate_deck(ids, cards)
	assert_true(_has(errs, "4 copies of 'a'"))
	assert_eq(errs.size(), 1, "only the offending card is reported")


func test_legendary_limit_of_one_is_enforced() -> void:
	var legend := _card("legend")
	legend.max_copies = 1
	var cards := {"legend": legend, "b": _card("b"), "c": _card("c"), "d": _card("d")}
	var ids: Array[String] = ["legend", "legend"]
	ids.append_array(_ids("b", 3))
	ids.append_array(_ids("c", 3))
	ids.append_array(_ids("d", 3))
	assert_true(_has(_rules().validate_deck(ids, cards), "'legend'"))


func test_unknown_card_in_deck_is_an_error_not_a_crash() -> void:
	var cards := {"a": _card("a")}
	var ids: Array[String] = ["a", "ghost"]
	ids.append_array(_ids("a", 2))
	var errs := _rules().validate_deck(ids, cards)
	assert_true(_has(errs, "unknown card 'ghost'"))


# --- DeckDefinition ----------------------------------------------------------------------------

func test_deck_definition_validation_and_ids() -> void:
	var d := DeckDefinition.new()
	d.id = "mine"
	d.display_name = "Mine"
	d.card_ids = PackedStringArray(["a", "a", "b"])
	assert_eq(d.validate().size(), 0)
	assert_eq(d.ids(), ["a", "a", "b"] as Array[String])
	d.card_ids = PackedStringArray(["Bad Id"])
	assert_true(_has(d.validate(), "snake_case"))
	d.display_name = ""
	assert_true(_has(d.validate(), "display_name"))


# --- ContentDb with shipped data --------------------------------------------------------------

func test_shipped_cards_rules_and_starter_deck_load_and_are_legal() -> void:
	var db := ContentDb.load_from("res://data")
	assert_true(db.is_valid(), "\n".join(db.errors))
	assert_true(db.deck_rules != null)
	for cid in ["rifle_squad", "gatling_gun", "tank", "artillery_strike", "helicopter_support"]:
		assert_true(db.card(cid) != null, cid)
	var starter := db.deck("starter")
	assert_true(starter != null)
	assert_eq(db.deck_rules.validate_deck(starter.ids(), db.cards).size(), 0)
	assert_eq(starter.card_ids.size(), 15, "starter deck = 3 copies x 5 designs (D3)")


func test_shipped_cards_are_affordable_and_kinds_match_roles() -> void:
	# Relations, not balance numbers.
	var db := ContentDb.load_from("res://data")
	for cid in db.cards:
		assert_true(float(db.card(cid).cost) <= db.deck_rules.cp_cap, "%s affordable at cap" % cid)
	assert_eq(db.card("artillery_strike").card_kind, CardDefinition.CardKind.OPERATION)
	assert_eq(db.card("helicopter_support").card_kind, CardDefinition.CardKind.SORTIE)
	assert_eq(db.card("tank").card_kind, CardDefinition.CardKind.DEPLOYMENT)
	assert_true(db.card("tank").lockout_s > 0.0, "heavy cards carry a lockout")


func test_db_reports_an_illegal_deck_and_a_card_that_can_never_be_afforded() -> void:
	var db := ContentDb.new()
	db.deck_rules = _rules()
	var expensive := _card("pricey")
	expensive.cost = 11
	db.add_card(expensive)
	var d := DeckDefinition.new()
	d.id = "tiny"
	d.display_name = "Tiny"
	d.card_ids = PackedStringArray(["pricey", "ghost"])
	db.add_deck(d)
	db.validate_references()
	assert_true(_has(db.errors, "deck 'tiny': deck has 2 cards, minimum is 12"))
	assert_true(_has(db.errors, "unknown card 'ghost'"))
	assert_true(_has(db.errors, "card 'pricey': cost 11 can never be afforded"))


func test_db_reports_missing_rules_when_a_deck_exists() -> void:
	var db := ContentDb.new()
	var d := DeckDefinition.new()
	d.id = "orphan"
	d.display_name = "Orphan"
	db.add_deck(d)
	db.validate_references()
	assert_true(_has(db.errors, "deck rules are missing"))
