extends TestCase
## The four state cards (Fortify, Supply Drop, Quick Draw, Hollow Points) in a real battle simulation, the content
## rules for them, and the launch option that names doctrines.

const DT: float = 1.0 / 60.0
const R := CardPlayService.Reason
const FIELD_ORDERS := "x4_field_orders"
const GOOD := Vector2i(7, 19)

var _db: ContentDb
var _made: Array[BattleController] = []


func _get_db() -> ContentDb:
	if _db == null:
		_db = ContentDb.load_from()
	return _db


func _battle(mission_id: String = FIELD_ORDERS, doctrines: PackedStringArray = PackedStringArray()) -> BattleController:
	var b := BattleController.new()
	b.auto_step = false
	b.extra_doctrines = doctrines
	b.setup(_get_db(), _get_db().mission(mission_id), 1)
	_made.append(b)
	return b


func _release() -> void:
	for b in _made:
		b.free()
	_made.clear()


func _hand(b: BattleController, ids: Array[String], cp: float = 10.0) -> void:
	b.deck.hand = ids
	b.points.cp = cp


func _run_for(b: BattleController, seconds: float) -> void:
	for i in int(round(seconds / DT)):
		b.step(DT)


func _enemy_at(b: BattleController, pos: Vector2) -> BattleEnemy:
	b._spawn_enemy(b.mission.waves[0])
	var e: BattleEnemy = b.enemies.back()
	e.ground_pos = pos
	return e


func _has(errs: PackedStringArray, needle: String) -> bool:
	for e in errs:
		if needle in e:
			return true
	return false


# --- shipped content --------------------------------------------------------------------------------------

func test_shipped_state_cards_and_the_field_orders_mission_are_valid() -> void:
	var db := _get_db()
	assert_true(db.is_valid(), "\n".join(db.errors))
	assert_eq(db.card("fortify").card_kind, CardDefinition.CardKind.ORDER)
	assert_eq(db.card("supply_drop").card_kind, CardDefinition.CardKind.SUPPLY)
	assert_eq(db.card("quick_draw").card_kind, CardDefinition.CardKind.DECK)
	assert_eq(db.card("hollow_points").card_kind, CardDefinition.CardKind.DOCTRINE)
	for cid in ["fortify", "supply_drop", "quick_draw", "hollow_points"]:
		assert_true(db.effect(db.card(cid).effect_id) != null, cid)
	assert_eq(db.mission(FIELD_ORDERS).doctrines, PackedStringArray(["hollow_points"]))
	assert_true(db.deck_rules.validate_deck(db.deck("state_cards").ids(), db.cards).is_empty())


func test_instant_kinds_are_orders_supplies_and_deck_tricks() -> void:
	var db := _get_db()
	for cid in ["fortify", "supply_drop", "quick_draw"]:
		assert_true(db.card(cid).is_instant(), cid)
	for cid in ["hollow_points", "rifle_squad", "artillery_strike", "helicopter_support"]:
		assert_true(not db.card(cid).is_instant(), cid)
	assert_true(db.card("hollow_points").uses_state_effect())
	assert_true(not db.card("tank").uses_state_effect())


func _db_with(kind: CardDefinition.CardKind, effect: StateEffectDefinition) -> ContentDb:
	var db := ContentDb.load_from()
	db.errors.clear()
	if effect != null:
		db.add_effect(effect)
	var c := CardDefinition.new()
	c.id = "probe"
	c.display_name = "Probe"
	c.card_kind = kind
	c.effect_id = "probe_fx" if effect != null else "ghost_fx"
	db.add_card(c)
	db.validate_references()
	return db


func _fx(duration: float, armor: float = 0.0, mult: float = 1.0) -> StateEffectDefinition:
	var e := StateEffectDefinition.new()
	e.id = "probe_fx"
	e.display_name = "Probe"
	e.duration_s = duration
	e.armor_bonus = armor
	e.damage_mult = mult
	return e


func test_a_state_card_naming_an_unknown_effect_is_a_reference_error() -> void:
	var db := _db_with(CardDefinition.CardKind.ORDER, null)
	assert_true(_has(db.errors, "card 'probe': unknown effect_id 'ghost_fx'"))


func test_an_order_needs_a_timed_modifier_and_a_doctrine_a_permanent_one() -> void:
	assert_true(_has(_db_with(CardDefinition.CardKind.ORDER, _fx(0.0, 4.0)).errors, "an order needs"), "permanent order")
	assert_true(_has(_db_with(CardDefinition.CardKind.DOCTRINE, _fx(10.0, 4.0)).errors, "a doctrine needs"), "timed doctrine")
	var draw := _fx(5.0)
	draw.draw_count = 2
	assert_true(_has(_db_with(CardDefinition.CardKind.ORDER, draw).errors, "an order needs"), "an order that only draws")
	assert_true(_db_with(CardDefinition.CardKind.ORDER, _fx(10.0, 4.0)).errors.is_empty())
	assert_true(_db_with(CardDefinition.CardKind.DOCTRINE, _fx(0.0, 0.0, 1.2)).errors.is_empty())


func test_supply_and_deck_cards_need_their_own_effect() -> void:
	assert_true(_has(_db_with(CardDefinition.CardKind.SUPPLY, _fx(10.0, 4.0)).errors, "a supply card needs"))
	assert_true(_has(_db_with(CardDefinition.CardKind.DECK, _fx(10.0, 4.0)).errors, "a deck card needs"))
	var sup := _fx(0.0)
	sup.cp_gain = 2.0
	assert_true(_db_with(CardDefinition.CardKind.SUPPLY, sup).errors.is_empty())
	var drw := _fx(0.0)
	drw.draw_count = 1
	assert_true(_db_with(CardDefinition.CardKind.DECK, drw).errors.is_empty())


func test_an_effect_naming_an_unknown_weapon_is_a_reference_error() -> void:
	var e := _fx(0.0, 0.0, 1.5)
	e.weapon_ids = PackedStringArray(["ghost_weapon"])
	var db := _db_with(CardDefinition.CardKind.DOCTRINE, e)
	assert_true(_has(db.errors, "effect 'probe_fx': unknown weapon id 'ghost_weapon'"))


func test_a_mission_can_only_name_doctrine_cards() -> void:
	var db := ContentDb.load_from()
	db.errors.clear()
	var m: MissionDefinition = db.mission(FIELD_ORDERS).duplicate()
	m.id = "bad_doctrines"
	m.doctrines = PackedStringArray(["ghost", "fortify"])
	db.add_mission(m)
	db.validate_references()
	assert_true(_has(db.errors, "mission 'bad_doctrines': unknown doctrine card 'ghost'"))
	assert_true(_has(db.errors, "mission 'bad_doctrines': doctrine 'fortify' is not a doctrine card"))


func test_state_cards_need_an_effect_id() -> void:
	var c := CardDefinition.new()
	c.id = "probe"
	c.display_name = "Probe"
	c.card_kind = CardDefinition.CardKind.ORDER
	assert_true(_has(c.validate(), "effect_id"))
	c.effect_id = "fortify"
	assert_eq(c.validate().size(), 0, "no unit_id needed")


# --- Fortify ------------------------------------------------------------------------------------------------

func test_fortify_plays_with_no_cell_spends_cp_and_starts_the_order() -> void:
	var b := _battle()
	_hand(b, ["fortify"] as Array[String])
	var res := b.play_card(0, Vector2i(-50, -50))
	assert_true(res.ok, "an instant card ignores the cell")
	assert_near(b.points.cp, 10.0 - float(b.db.card("fortify").cost))
	assert_true(b.modifiers.is_active("fortify"))
	assert_eq(b.deck.hand.size(), 0)
	assert_eq(b.deck.discard, ["fortify"] as Array[String])
	assert_true(b.deck.is_locked("fortify"))
	_release()


func test_fortify_reduces_what_a_hit_does_to_every_ground_unit_and_then_wears_off() -> void:
	var b := _battle()
	_hand(b, ["fortify", "tank", "rifle_squad"] as Array[String])
	b.play_card(1, GOOD)
	b.points.cp = 10.0
	b.play_card(1, Vector2i(7, 21))
	b.points.cp = 10.0
	b.play_card(0, GOOD)
	var bonus := b.db.effect("fortify").armor_bonus
	var dmg := b.db.enemy("shambler").attack_damage
	var tank: BattleUnit = b.units[0]
	var soldier: BattleUnit = b.units[1]
	_enemy_at(b, tank.ground_pos + Vector2(0.4, 0.0))
	_enemy_at(b, soldier.ground_pos + Vector2(0.4, 0.0))
	var tank_hp := tank.health.hp
	var soldier_hp := soldier.health.hp
	b.step(DT)
	assert_near(tank_hp - tank.health.hp, DamageService.compute(dmg, tank.def.armor + bonus), 1e-6)
	assert_near(soldier_hp - soldier.health.hp, DamageService.compute(dmg, bonus), 1e-6)
	assert_true(soldier_hp - soldier.health.hp < dmg, "fortified")
	_run_for(b, b.db.effect("fortify").duration_s + 0.2)
	assert_true(not b.modifiers.is_active("fortify"), "the order ran out")
	b.enemies.clear()
	var late := _enemy_at(b, soldier.ground_pos + Vector2(0.4, 0.0))
	late.attack_state.reset()
	var hp := soldier.health.hp
	b.step(DT)
	assert_near(hp - soldier.health.hp, dmg, 1e-6, "full damage again")
	_release()


func test_fortify_does_not_protect_the_core() -> void:
	var b := _battle()
	_hand(b, ["fortify"] as Array[String])
	b.play_card(0, Vector2i.ZERO)
	_enemy_at(b, b.core.ground_pos + Vector2(0.3, 0.0))
	var dmg := b.db.enemy("shambler").attack_damage
	var hp := b.core.health.hp
	b.step(DT)
	assert_near(hp - b.core.health.hp, dmg, 1e-6, "armour is for units")
	_release()


func test_playing_fortify_again_after_its_lockout_refreshes_the_timer() -> void:
	var b := _battle()
	_hand(b, ["fortify", "fortify"] as Array[String])
	b.play_card(0, Vector2i.ZERO)
	_run_for(b, 12.0)
	var left := b.modifiers.time_left("fortify")
	assert_true(left < 9.0)
	b.deck.lockouts.clear()
	b.points.cp = 10.0
	b.play_card(0, Vector2i.ZERO)
	assert_near(b.modifiers.time_left("fortify"), b.db.effect("fortify").duration_s, 1e-9)
	assert_near(b.modifiers.armor_bonus(), b.db.effect("fortify").armor_bonus, 1e-9, "not stacked")
	_release()


func test_a_refused_instant_play_changes_nothing() -> void:
	var b := _battle()
	_hand(b, ["fortify"] as Array[String], 1.0)
	var before := [b.points.cp, b.deck.hand.duplicate(), b.deck.discard.duplicate(), b.deck.lockouts.duplicate()]
	var res := b.play_card(0, Vector2i.ZERO)
	assert_eq(res.reason, R.INSUFFICIENT_CP)
	assert_eq([b.points.cp, b.deck.hand, b.deck.discard, b.deck.lockouts], before)
	assert_true(not b.modifiers.is_active("fortify"))
	b.points.cp = 10.0
	b.play_card(0, Vector2i.ZERO)
	b.deck.hand = ["fortify"] as Array[String]
	assert_eq(b.play_card(0, Vector2i.ZERO).reason, R.LOCKED_OUT)
	_release()


func test_clicking_an_instant_card_plays_it_at_once_and_a_refusal_is_reported() -> void:
	var b := _battle()
	var rejected: Array = []
	b.card_rejected.connect(func(slot: int, res: CardPlayService.Result) -> void: rejected.append([slot, res.reason]))
	_hand(b, ["rifle_squad", "fortify"] as Array[String])
	b.select_slot(0)
	assert_true(b.targeting.is_selecting(), "a deployment card waits for a cell")
	b.select_slot(1)
	assert_true(b.modifiers.is_active("fortify"), "the order played on the click")
	assert_true(not b.targeting.is_selecting(), "and it dropped the old selection (the hand shifted)")
	assert_eq(rejected.size(), 0)
	_hand(b, ["fortify"] as Array[String], 0.0)
	b.deck.lockouts.clear()
	b.select_slot(0)
	assert_eq(rejected.size(), 1)
	assert_eq(rejected[0], [0, R.INSUFFICIENT_CP])
	assert_eq(b.deck.hand.size(), 1, "the card stayed in the hand")
	_release()


func test_orders_end_with_a_restart() -> void:
	var b := _battle()
	_hand(b, ["fortify"] as Array[String])
	b.play_card(0, Vector2i.ZERO)
	b.restart()
	assert_true(not b.modifiers.is_active("fortify"))
	assert_true(b.modifiers.is_active("hollow_points"), "the mission's doctrine is back")
	_release()


# --- Supply Drop -------------------------------------------------------------------------------------------------

func test_supply_drop_gives_command_points_up_to_the_cap() -> void:
	var b := _battle()
	var gain := b.db.effect("supply_drop").cp_gain
	var cost := float(b.db.card("supply_drop").cost)
	_hand(b, ["supply_drop"] as Array[String], 2.0)
	assert_true(b.play_card(0, Vector2i.ZERO).ok)
	assert_near(b.points.cp, 2.0 - cost + gain)
	_hand(b, ["supply_drop"] as Array[String], b.points.cap)
	b.deck.lockouts.clear()
	b.play_card(0, Vector2i.ZERO)
	assert_near(b.points.cp, b.points.cap, 1e-9, "never above the cap")
	_release()


func test_supply_drop_reloads_the_helicopters_missiles() -> void:
	var b := _battle()
	_hand(b, ["helicopter_support", "supply_drop"] as Array[String])
	b.play_card(0, GOOD)
	var heli: BattleAircraft = null
	for u in b.units:
		if u is BattleAircraft:
			heli = u
	assert_true(heli != null)
	var full := b.db.weapon(heli.def.secondary_weapon_id).ammo
	heli.secondary_ammo = 1
	assert_true(b.play_card(0, Vector2i.ZERO).ok)
	assert_eq(heli.secondary_ammo, full)
	_release()


func test_supply_drop_with_no_aircraft_still_plays() -> void:
	var b := _battle()
	_hand(b, ["supply_drop"] as Array[String])
	assert_true(b.play_card(0, Vector2i.ZERO).ok)
	_release()


# --- Quick Draw ----------------------------------------------------------------------------------------------------

func test_quick_draw_draws_two_cards() -> void:
	var b := _battle()
	b.deck.hand = ["quick_draw"] as Array[String]
	b.deck.draw_pile = ["a", "b", "c"] as Array[String]
	b.points.cp = 10.0
	assert_true(b.play_card(0, Vector2i.ZERO).ok)
	assert_eq(b.deck.hand, ["c", "b"] as Array[String])
	assert_eq(b.deck.draw_pile, ["a"] as Array[String])
	_release()


func test_quick_draw_cannot_overfill_the_hand() -> void:
	var b := _battle()
	b.deck.hand = ["quick_draw", "w", "x", "y", "z"] as Array[String]
	b.deck.draw_pile = ["a", "b", "c"] as Array[String]
	b.points.cp = 10.0
	assert_true(b.play_card(0, Vector2i.ZERO).ok)
	assert_eq(b.deck.hand.size(), b.deck.rules.hand_cap)
	assert_eq(b.deck.draw_pile.size(), 2, "one card fitted, one stayed in the pile")
	_release()


func test_quick_draw_is_deterministic_for_a_seed() -> void:
	var a := _battle()
	var c := _battle()
	for b: BattleController in [a, c]:
		_hand(b, ["quick_draw"] as Array[String])
		b.deck.draw_pile = ["a", "b", "c"] as Array[String]
		b.play_card(0, Vector2i.ZERO)
	assert_eq(a.deck.hand, c.deck.hand)
	_release()


# --- Hollow Points (doctrine) -----------------------------------------------------------------------------------------

func _rifle_hit(b: BattleController) -> float:
	b.units.clear()
	b.enemies.clear()
	b._pending.clear()
	var soldier := b._spawn_unit_at("rifle_soldier", IsoProjection.cell_center(GOOD))
	soldier.def = soldier.def.duplicate()
	soldier.def.behavior = UnitBrain.Behavior.HOLD  # stand and shoot; the shipped rifleman would back away from this enemy
	var e := _enemy_at(b, soldier.ground_pos + Vector2(2.0, 0.0))
	var hp := e.health.hp
	b.step(DT)
	return hp - e.health.hp


func test_the_mission_starts_with_its_doctrine_and_rifles_hit_harder() -> void:
	var with := _battle(FIELD_ORDERS)
	var without := _battle("m2_card_defense")
	assert_true(with.modifiers.is_active("hollow_points"))
	assert_true(not without.modifiers.is_active("hollow_points"))
	var base := _rifle_hit(without)
	var boosted := _rifle_hit(with)
	assert_true(base > 0.0)
	assert_near(boosted, base * 1.15, 1e-6)
	_release()


func test_a_doctrine_boosts_only_the_weapons_it_names() -> void:
	var with := _battle(FIELD_ORDERS)
	var without := _battle("m2_card_defense")
	var hits: Array[float] = []
	for b: BattleController in [without, with]:
		b.units.clear()
		b.enemies.clear()
		var gun := b._spawn_unit_at("gatling_gun", IsoProjection.cell_center(GOOD))
		var e := _enemy_at(b, gun.ground_pos + Vector2(2.0, 0.0))
		var hp := e.health.hp
		b.step(DT)
		hits.append(hp - e.health.hp)
	assert_true(hits[0] > 0.0)
	assert_near(hits[1], hits[0], 1e-9, "the gatling gun is not a rifle")
	_release()


func test_the_doctrine_option_adds_doctrines_and_ignores_unknown_ids() -> void:
	var b := _battle("m2_card_defense", PackedStringArray(["hollow_points", "no_such_card", "fortify"]))
	assert_true(b.modifiers.is_active("hollow_points"))
	assert_true(not b.modifiers.is_active("fortify"), "fortify is an order, not a doctrine")
	assert_eq(b.modifiers.active().size(), 1)
	b.restart()
	assert_true(b.modifiers.is_active("hollow_points"), "kept across a restart")
	_release()


func test_a_doctrine_card_in_the_hand_cannot_be_played() -> void:
	var b := _battle()
	_hand(b, ["hollow_points"] as Array[String])
	assert_eq(b.check_card(0, Vector2i.ZERO).reason, R.UNAVAILABLE)
	var res := b.play_card(0, Vector2i.ZERO)
	assert_eq(res.reason, R.UNAVAILABLE)
	assert_eq(b.deck.hand.size(), 1)
	_release()


func test_doctrines_work_in_a_mission_without_a_deck() -> void:
	var b := _battle("m1_hold_the_crossing", PackedStringArray(["hollow_points"]))
	assert_true(b.modifiers.is_active("hollow_points"))
	_release()


func _boost_all(b: BattleController, mult: float) -> void:
	var e := StateEffectDefinition.new()
	e.id = "boost_all"
	e.display_name = "Boost"
	e.damage_mult = mult
	b.modifiers.apply(e)


func test_a_damage_effect_also_scales_projectile_and_blast_weapons() -> void:
	var b := _battle("m2_card_defense")
	_boost_all(b, 2.0)
	var target := _enemy_at(b, IsoProjection.cell_center(GOOD) + Vector2(3.0, 0.0))
	var rpg_unit := b._spawn_unit_at("rpg_soldier", IsoProjection.cell_center(GOOD))
	var rpg := b.db.weapon("rpg")
	b._fire(rpg_unit, rpg, target)
	assert_eq(b.projectiles.count(), 1)
	assert_near(b.projectiles._damage[0], rpg.damage * 2.0, 1e-6, "the missile carries the boosted damage")
	var tank := b._spawn_unit_at("tank", IsoProjection.cell_center(GOOD))
	var cannon := b.db.weapon("tank_cannon")
	assert_true(cannon.blast_radius > 0.0 and cannon.delivery == WeaponDefinition.Delivery.HITSCAN)
	b._pending.clear()
	b._fire(tank, cannon, target)
	assert_eq(b._pending.size(), 1)
	assert_near(b._pending[0].amount, cannon.damage * 2.0, 1e-6, "the blast carries the boosted damage")
	_release()


func test_a_supply_effect_without_the_reload_flag_leaves_the_missiles_alone() -> void:
	var b := _battle()
	_hand(b, ["helicopter_support"] as Array[String])
	b.play_card(0, GOOD)
	var heli: BattleAircraft = null
	for u in b.units:
		if u is BattleAircraft:
			heli = u
	heli.secondary_ammo = 1
	var e := StateEffectDefinition.new()
	e.id = "cash_only"
	e.display_name = "Cash"
	e.cp_gain = 2.0
	b.points.cp = 0.0
	b._run_state_effect(e)
	assert_eq(heli.secondary_ammo, 1)
	assert_near(b.points.cp, 2.0)
	_release()


# --- launch option ------------------------------------------------------------------------------------------------------

func test_the_doctrine_option_is_parsed_as_a_list() -> void:
	var r := BattleController.parse_user_args(PackedStringArray(["--doctrine=hollow_points, other ,", "--mission=m2_card_defense"]))
	assert_eq(r["doctrine"], PackedStringArray(["hollow_points", "other"]))
	assert_eq(r["mission"], "m2_card_defense")
	assert_true(not BattleController.parse_user_args(PackedStringArray(["--doctrine="])).has("doctrine"))


func test_launch_options_reach_the_battle() -> void:
	var b := BattleController.new()
	b.apply_launch_options(BattleController.parse_user_args(PackedStringArray(["--mission=x4_field_orders", "--seed=9", "--doctrine=hollow_points"])))
	assert_eq(b.mission_id, "x4_field_orders")
	assert_eq(b.rng_seed, 9)
	assert_eq(b.extra_doctrines, PackedStringArray(["hollow_points"]))
	b.free()
	var c := BattleController.new()
	c.apply_launch_options({})
	assert_eq(c.extra_doctrines.size(), 0, "no options, no change")
	c.free()
