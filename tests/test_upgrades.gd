extends TestCase
## Card upgrades (docs/specs/progression.md, increment 5.5): the data, the number patches, the per-battle copy of the
## content, earning and equipping them, and where they apply.

const DIR: String = "user://test_upgrades"
const PATH: String = "user://test_upgrades/profile.json"
const STARTER_CARDS: Array[String] = ["rifle_squad", "gatling_gun", "tank", "artillery_strike", "helicopter_support"]

var _db: ContentDb


func _get_db() -> ContentDb:
	if _db == null:
		_db = ContentDb.load_from()
	return _db


func _clean() -> void:
	var abs_dir := ProjectSettings.globalize_path(DIR)
	if DirAccess.dir_exists_absolute(abs_dir):
		for f in DirAccess.get_files_at(abs_dir):
			DirAccess.remove_absolute(abs_dir.path_join(f))
	else:
		DirAccess.make_dir_recursive_absolute(abs_dir)


func _in_tree(n: Node) -> Node:
	tree.root.add_child(n)
	return n


func _use_temp(p: PlayerProfile) -> void:
	_clean()
	GameSession.profile_path = PATH
	GameSession.set_profile(p)


func _release_temp() -> void:
	GameSession.profile_path = ProfileStore.PATH
	GameSession.set_profile(null)
	_clean()


func _fresh() -> PlayerProfile:
	return PlayerProfile.new_game(_get_db(), 21)


func _patch(target: UpgradePatch.Target, id: String, prop: String, op: UpgradePatch.Op, value: float) -> UpgradePatch:
	var p := UpgradePatch.new()
	p.target = target
	p.target_id = id
	p.property = prop
	p.op = op
	p.value = value
	return p


# --- the data ----------------------------------------------------------------------------------------------------

func test_every_starter_card_has_two_valid_upgrades() -> void:
	var db := _get_db()
	assert_true(db.is_valid(), "content errors: %s" % ", ".join(db.errors))
	for cid in STARTER_CARDS:
		var ids := db.upgrades_of(cid)
		assert_eq(ids.size(), 2, "%s has two branches" % cid)
		for uid in ids:
			var up := db.upgrade(uid)
			assert_true(not db.cards.has(uid), "%s is not also a card id" % uid)
			assert_true(up.patches.size() >= 1)
			for p in up.patches:
				assert_eq(p.validate(db).size(), 0, "%s: %s" % [uid, ", ".join(p.validate(db))])
	assert_eq(db.upgrades.size(), 10)


func test_every_upgrade_can_be_won_in_the_campaign() -> void:
	var db := _get_db()
	var camp := db.main_campaign()
	var offered: Dictionary = {}
	for mid in camp.reward_pools:
		for id in camp.pool_of(mid):
			offered[id] = true
	for uid: String in db.upgrades:
		assert_true(offered.has(uid), "%s is in a reward pool" % uid)


# --- patches ----------------------------------------------------------------------------------------------------

func test_a_patch_adds_multiplies_and_sets() -> void:
	var w := _get_db().weapon("gatling").duplicate() as WeaponDefinition
	_patch(UpgradePatch.Target.WEAPON, "gatling", "range_tiles", UpgradePatch.Op.ADD, 2.5).apply_to(w)
	assert_near(w.range_tiles, 9.5)
	_patch(UpgradePatch.Target.WEAPON, "gatling", "damage", UpgradePatch.Op.MUL, 2.0).apply_to(w)
	assert_near(w.damage, 10.0)
	_patch(UpgradePatch.Target.WEAPON, "gatling", "shots_per_second", UpgradePatch.Op.SET, 4.0).apply_to(w)
	assert_near(w.shots_per_second, 4.0)
	_patch(UpgradePatch.Target.WEAPON, "gatling", "anti_armor", UpgradePatch.Op.SET, 1.0).apply_to(w)
	assert_true(w.anti_armor)
	_patch(UpgradePatch.Target.WEAPON, "gatling", "anti_armor", UpgradePatch.Op.SET, 0.0).apply_to(w)
	assert_true(not w.anti_armor)


func test_a_whole_number_property_stays_whole() -> void:
	var o := _get_db().operation("artillery_strike").duplicate() as OperationDefinition
	var before := o.shell_count
	_patch(UpgradePatch.Target.OPERATION, "artillery_strike", "shell_count", UpgradePatch.Op.ADD, 4.0).apply_to(o)
	assert_eq(o.shell_count, before + 4)
	_patch(UpgradePatch.Target.OPERATION, "artillery_strike", "shell_count", UpgradePatch.Op.MUL, 1.5).apply_to(o)
	assert_eq(o.shell_count, int(round(float(before + 4) * 1.5)))


func test_bad_patches_are_reported() -> void:
	var db := _get_db()
	assert_true(_patch(UpgradePatch.Target.WEAPON, "no_such_weapon", "damage", UpgradePatch.Op.ADD, 1.0).validate(db).size() > 0)
	assert_true(_patch(UpgradePatch.Target.WEAPON, "gatling", "no_such_field", UpgradePatch.Op.ADD, 1.0).validate(db).size() > 0)
	assert_true(_patch(UpgradePatch.Target.WEAPON, "gatling", "sfx_id", UpgradePatch.Op.ADD, 1.0).validate(db).size() > 0, "a text property")
	assert_true(_patch(UpgradePatch.Target.WEAPON, "gatling", "anti_armor", UpgradePatch.Op.MUL, 2.0).validate(db).size() > 0, "MUL on true/false")
	assert_true(_patch(UpgradePatch.Target.WEAPON, "gatling", "damage", UpgradePatch.Op.MUL, 0.0).validate(db).size() > 0, "multiply by zero")
	assert_eq(_patch(UpgradePatch.Target.WEAPON, "gatling", "damage", UpgradePatch.Op.MUL, 1.5).validate(db).size(), 0)


func test_an_upgrade_for_an_unknown_card_or_with_a_bad_patch_stops_the_content_loading() -> void:
	var db := ContentDb.new()
	var up := UpgradeDefinition.new()
	up.id = "orphan"
	up.display_name = "Orphan"
	up.description = "x"
	up.card_id = "no_such_card"
	up.patches = [_patch(UpgradePatch.Target.WEAPON, "none", "damage", UpgradePatch.Op.ADD, 1.0)] as Array[UpgradePatch]
	assert_true(db.add_upgrade(up))
	db.validate_references()
	var text := "\n".join(db.errors)
	assert_true(text.contains("unknown card 'no_such_card'") and text.contains("unknown weapon 'none'"), text)
	var empty := UpgradeDefinition.new()
	empty.id = "empty"
	assert_true(empty.validate().size() >= 3)


# --- the per-battle copy -------------------------------------------------------------------------------------------

func test_the_patched_content_has_the_new_numbers_and_the_shared_content_does_not() -> void:
	var db := _get_db()
	var out := UpgradeApplier.patched_db(db, PackedStringArray(["gatling_ap_belt", "tank_reactive_armor"]))
	assert_near(out.weapon("gatling").damage, db.weapon("gatling").damage * 2.2)
	assert_near(out.weapon("gatling").shots_per_second, db.weapon("gatling").shots_per_second * 0.6)
	assert_true(out.weapon("gatling").anti_armor)
	assert_near(out.unit("tank").armor, db.unit("tank").armor + 3.0)
	assert_near(out.unit("tank").max_health, db.unit("tank").max_health * 1.25)
	assert_true(not db.weapon("gatling").anti_armor, "the shared definition is untouched")
	assert_near(db.weapon("gatling").damage, 5.0)
	assert_near(db.unit("tank").armor, 5.0)
	assert_true(out.unit("rifle_soldier") == db.unit("rifle_soldier"), "definitions nothing changes are shared, not copied")
	assert_true(out.deck_rules == db.deck_rules)
	assert_true(out.card("tank") == db.card("tank"))


func test_two_patches_on_one_definition_stack_and_unknown_ids_are_skipped() -> void:
	var db := _get_db()
	var out := UpgradeApplier.patched_db(db, PackedStringArray(["gatling_crowd_spray", "no_such_upgrade", "gatling_ap_belt"]))
	assert_near(out.weapon("gatling").damage, 5.0 * 0.8 * 2.2)
	assert_near(out.weapon("gatling").blast_radius, 0.9)


func test_the_card_and_operation_upgrades_land_where_they_point() -> void:
	var db := _get_db()
	var out := UpgradeApplier.patched_db(db, PackedStringArray(["helicopter_extended_station", "artillery_heavy_shells"]))
	assert_near(out.card("helicopter_support").station_time_s, db.card("helicopter_support").station_time_s + 6.0)
	assert_near(out.operation("artillery_strike").shell_damage, db.operation("artillery_strike").shell_damage * 1.6)
	assert_near(out.operation("artillery_strike").warning_s, db.operation("artillery_strike").warning_s - 0.4)
	assert_near(db.card("helicopter_support").station_time_s, 12.0)


# --- earning and equipping ---------------------------------------------------------------------------------------

func test_taking_an_upgrade_unlocks_it_and_equips_it_when_the_card_has_none() -> void:
	var db := _get_db()
	var p := _fresh()
	p.open_reward("m1_hold_the_crossing", PackedStringArray(["rifle_long_barrels", "rifle_body_armor", "sandbags"]))
	assert_true(p.take_reward("m1_hold_the_crossing", "rifle_long_barrels", db))
	assert_true(p.unlocked_upgrades.has("rifle_long_barrels"))
	assert_true(not p.owns("rifle_long_barrels"), "an upgrade is not a card")
	assert_eq(p.equipped.get("rifle_squad"), "rifle_long_barrels")
	p.open_reward("m2_card_defense", PackedStringArray(["rifle_body_armor"]))
	p.take_reward("m2_card_defense", "rifle_body_armor", db)
	assert_eq(p.equipped.get("rifle_squad"), "rifle_long_barrels", "the second branch does not replace the first")


func test_equipping_switches_the_branch_and_needs_an_earned_upgrade() -> void:
	var db := _get_db()
	var p := _fresh()
	assert_true(not p.equip(db, "tank_he_shells"), "not earned")
	p.unlocked_upgrades = PackedStringArray(["tank_he_shells", "tank_reactive_armor"])
	assert_true(p.equip(db, "tank_he_shells"))
	assert_true(p.equip(db, "tank_reactive_armor"))
	assert_eq(Array(p.equipped_ids()), ["tank_reactive_armor"], "one branch per card")
	p.unequip("tank")
	assert_eq(p.equipped_ids().size(), 0)
	assert_true(not p.equip(db, "no_such_upgrade"))


func test_the_picker_offers_an_upgrade_only_for_a_card_the_player_owns_and_not_twice() -> void:
	var db := _get_db()
	var p := _fresh()
	var pool := PackedStringArray(["marksman_team", "rpg_team", "howitzer_battery", "mortar_team", "ifv"])
	pool.append_array(db.upgrades_of("ifv"))
	pool.append_array(db.upgrades_of("tank"))
	var usable := RewardPicker.usable_pool(db, p, pool)
	assert_true(usable.has("tank_he_shells"), "the player owns the tank")
	var no_tank := _fresh()
	no_tank.collection.remove_at(no_tank.collection.find("tank"))
	assert_true(not RewardPicker.usable_pool(db, no_tank, pool).has("tank_he_shells"), "no upgrade for a card the player lacks")
	p.unlocked_upgrades = PackedStringArray(["tank_he_shells", "tank_reactive_armor"])
	var offer := RewardPicker.offer(RewardPicker.usable_pool(db, p, pool), p.holdings(), 5, "m3_combined_arms", 9)
	assert_true(not offer.has("tank_he_shells") and not offer.has("tank_reactive_armor"), "earned upgrades are not offered again")


func test_a_saved_profile_keeps_upgrades_and_repairs_nonsense() -> void:
	var db := _get_db()
	var p := _fresh()
	p.unlocked_upgrades = PackedStringArray(["tank_he_shells", "gatling_ap_belt", "ghost_upgrade"])
	p.equipped = {"tank": "tank_he_shells", "gatling_gun": "tank_reactive_armor", "rifle_squad": "rifle_body_armor", "ifv": "ghost_upgrade"}
	var q := PlayerProfile.from_dict(JSON.parse_string(JSON.stringify(p.to_dict())))
	assert_eq(Array(q.unlocked_upgrades), ["tank_he_shells", "gatling_ap_belt", "ghost_upgrade"])
	q.sanitize(db)
	assert_eq(Array(q.unlocked_upgrades), ["tank_he_shells", "gatling_ap_belt"])
	assert_eq(q.equipped.get("tank"), "tank_he_shells")
	assert_true(not q.equipped.has("gatling_gun"), "another card's upgrade")
	assert_true(not q.equipped.has("rifle_squad"), "not unlocked")
	assert_true(not q.equipped.has("ifv"), "unknown upgrade")


func test_waiting_offers_with_upgrades_are_kept_or_dropped_correctly() -> void:
	var db := _get_db()
	var p := _fresh()
	p.open_reward("m1_hold_the_crossing", PackedStringArray(["rifle_long_barrels", "tank_he_shells", "sandbags"]))
	p.unlocked_upgrades = PackedStringArray(["rifle_long_barrels"])  # earned meanwhile
	p.sanitize(db)
	assert_eq(Array(p.offer_of("m1_hold_the_crossing")), ["tank_he_shells", "sandbags"])


func test_a_reward_that_was_an_upgrade_stays_unlocked_after_a_repair() -> void:
	var db := _get_db()
	var p := _fresh()
	p.rewards["m1_hold_the_crossing"] = "gatling_crowd_spray"
	p.sanitize(db)
	assert_true(p.unlocked_upgrades.has("gatling_crowd_spray"))
	assert_true(not p.owns("gatling_crowd_spray"))


func test_claiming_an_upgrade_through_the_session_saves_it() -> void:
	var db := _get_db()
	var p := _fresh()
	p.open_reward("m1_hold_the_crossing", PackedStringArray(["rifle_long_barrels", "rpg_team", "sandbags"]))
	_use_temp(p)
	assert_true(GameSession.claim_reward(db, "m1_hold_the_crossing", "rifle_long_barrels"))
	var back := ProfileStore.load_from(db, PATH).profile
	assert_true(back.unlocked_upgrades.has("rifle_long_barrels"))
	assert_eq(back.equipped.get("rifle_squad"), "rifle_long_barrels")
	_release_temp()


func test_the_chooser_and_result_panel_name_an_upgrade() -> void:
	var db := _get_db()
	var p := _fresh()
	var offer := PackedStringArray(["tank_he_shells", "sandbags", "rpg_team"])
	p.open_reward("m3_combined_arms", offer)
	_use_temp(p)
	var panel := ResultPanel.new()
	_in_tree(panel)
	panel.show_offer(db, "m3_combined_arms", offer)
	var b: Button = panel.find_child("Reward_tank_he_shells", true, false)
	assert_true(b.text.begins_with("Upgrade: High-Explosive Shells") and b.text.contains("Tank"), b.text)
	b.pressed.emit()
	var said := false
	for l in panel.find_children("*", "Label", true, false):
		said = said or ((l as Label).visible and (l as Label).text.begins_with("Unlocked the upgrade"))
	assert_true(said)
	panel.free()
	_release_temp()


# --- where upgrades apply ----------------------------------------------------------------------------------------

func test_the_loadout_lists_only_earned_equipped_upgrades_of_owned_cards() -> void:
	var db := _get_db()
	var p := _fresh()
	p.unlocked_upgrades = PackedStringArray(["tank_reactive_armor"])
	p.equipped = {"tank": "tank_reactive_armor", "gatling_gun": "gatling_ap_belt"}  # the second was never earned
	assert_eq(Array(DeckBuilder.loadout(p, db)["upgrades"]), ["tank_reactive_armor"])


func test_a_player_deck_battle_from_the_menu_runs_on_upgraded_content() -> void:
	var p := _fresh()
	p.unlocked_upgrades = PackedStringArray(["tank_reactive_armor"])
	p.equipped = {"tank": "tank_reactive_armor"}
	_use_temp(p)
	GameSession.pending_mission = "dev_player_deck"
	var b := BattleController.new()
	b.auto_step = false
	_in_tree(b)
	assert_near(b.db.unit("tank").armor, 8.0)
	assert_near(b.db.unit("tank").max_health, 500.0)
	assert_near(_get_db().unit("tank").armor, 5.0, 1e-9, "the shared content is not changed by a battle")
	b.free()
	_release_temp()


func test_fixed_deck_missions_and_command_line_runs_ignore_upgrades() -> void:
	var p := _fresh()
	p.unlocked_upgrades = PackedStringArray(["tank_reactive_armor"])
	p.equipped = {"tank": "tank_reactive_armor"}
	_use_temp(p)
	GameSession.pending_mission = "m2_card_defense"
	var fixed := BattleController.new()
	fixed.auto_step = false
	_in_tree(fixed)
	assert_near(fixed.db.unit("tank").armor, 5.0, 1e-9, "a fixed-deck mission is not upgraded")
	fixed.free()
	var cli := BattleController.new()
	cli.auto_step = false
	cli.mission_id = "dev_player_deck"
	_in_tree(cli)
	assert_near(cli.db.unit("tank").armor, 5.0, 1e-9, "a plain launch is not upgraded")
	cli.free()
	_release_temp()


# --- the deck screen ---------------------------------------------------------------------------------------------

func _select(s: DeckScreen, card_id: String) -> void:
	var owned: ItemList = s.find_child("Owned", true, false)
	for i in owned.item_count:
		if owned.get_item_text(i).begins_with(_get_db().card(card_id).display_name):
			owned.select(i)
			owned.item_selected.emit(i)
			return


func test_the_deck_screen_switches_upgrades_on_and_off() -> void:
	var db := _get_db()
	var p := _fresh()
	p.unlocked_upgrades = PackedStringArray(["tank_he_shells"])
	_use_temp(p)
	var s := DeckScreen.new()
	s.bind(db, p)
	_in_tree(s)
	_select(s, "tank")
	var earned: Button = s.find_child("Upgrade_tank_he_shells", true, false)
	var locked: Button = s.find_child("Upgrade_tank_reactive_armor", true, false)
	assert_true(earned != null and not earned.disabled)
	assert_true(locked != null and locked.disabled and locked.text.contains("not earned"))
	earned.pressed.emit()
	assert_eq(p.equipped.get("tank"), "tank_he_shells")
	assert_true(ProfileStore.load_from(db, PATH).profile.equipped.has("tank"), "saved at once")
	assert_true((s.find_child("Upgrade_tank_he_shells", true, false) as Button).text.contains("(on)"))
	(s.find_child("Upgrade_tank_he_shells", true, false) as Button).pressed.emit()
	assert_true(not p.equipped.has("tank"), "pressed again, it is switched off")
	_select(s, "tank")
	assert_eq(s.find_children("Upgrade_*", "Button", true, false).size(), 2)
	s.free()
	_release_temp()


func test_a_card_without_upgrades_shows_none() -> void:
	var p := _fresh()
	p.collection.append("sandbags")
	_use_temp(p)
	var s := DeckScreen.new()
	s.bind(_get_db(), p)
	_in_tree(s)
	_select(s, "sandbags")
	assert_eq(s.find_children("Upgrade_*", "Button", true, false).size(), 0)
	s.free()
	_release_temp()
