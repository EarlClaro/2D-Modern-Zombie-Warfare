extends TestCase
## The deck editor and player-deck missions (docs/specs/progression.md, increment 5.4): the editing rules, the deck a
## battle is given, and the screen.

const DIR: String = "user://test_deck_editor"
const PATH: String = "user://test_deck_editor/profile.json"

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


## A new profile that also owns Ifv, Marksman Team and Hollow Points.
func _rich() -> PlayerProfile:
	var p := PlayerProfile.new_game(_get_db(), 3)
	for cid in ["ifv", "marksman_team", "hollow_points", "close_air_support"]:
		p.collection.append(cid)
	return p


func _use_temp(p: PlayerProfile) -> void:
	_clean()
	GameSession.profile_path = PATH
	GameSession.set_profile(p)


func _release_temp() -> void:
	GameSession.profile_path = ProfileStore.PATH
	GameSession.set_profile(null)
	_clean()


# --- the rules ---------------------------------------------------------------------------------------------------

func test_a_card_the_player_owns_can_be_added_up_to_its_copy_limit() -> void:
	var db := _get_db()
	var p := _rich()
	var before := p.deck.size()
	for i in 3:
		assert_eq(DeckBuilder.add(p, db, "ifv"), "")
	assert_eq(p.deck.size(), before + 3)
	var why := DeckBuilder.add(p, db, "ifv")
	assert_true(why.contains("at most 3"), why)
	assert_eq(p.deck.size(), before + 3, "a refused add changes nothing")
	assert_eq(DeckBuilder.add(p, db, "close_air_support"), "")
	assert_true(DeckBuilder.add(p, db, "close_air_support").contains("at most 1 copy"))


func test_cards_not_owned_and_doctrines_cannot_be_added() -> void:
	var db := _get_db()
	var p := _rich()
	assert_true(DeckBuilder.add(p, db, "nuclear_bomb").contains("do not own"))
	assert_true(DeckBuilder.add(p, db, "laser_cat").contains("do not own"))
	assert_true(DeckBuilder.add(p, db, "hollow_points").contains("doctrine"))


func test_the_deck_cannot_grow_past_the_maximum_or_shrink_below_the_minimum() -> void:
	var db := _get_db()
	var p := _rich()
	p.collection = PackedStringArray(db.cards.keys().filter(func(id: String) -> bool: return db.card(id).card_kind != CardDefinition.CardKind.DOCTRINE))
	# fill to the maximum with distinct cards
	for cid in p.collection:
		while p.deck.size() < db.deck_rules.deck_max and DeckBuilder.add(p, db, cid).is_empty():
			pass
	assert_eq(p.deck.size(), db.deck_rules.deck_max)
	assert_true(DeckBuilder.add(p, db, "sandbags") != "", "a full deck takes nothing more")
	assert_true(p.deck_is_legal(db))
	while p.deck.size() > db.deck_rules.deck_min:
		assert_eq(DeckBuilder.remove(p, db, p.deck[0]), "")
	assert_true(DeckBuilder.remove(p, db, p.deck[0]).contains("at least"))
	assert_eq(p.deck.size(), db.deck_rules.deck_min)
	assert_true(p.deck_is_legal(db), "every deck on the way was legal")


func test_swapping_a_card_works_by_adding_first() -> void:
	var db := _get_db()
	var p := _rich()
	var size := p.deck.size()
	assert_eq(DeckBuilder.add(p, db, "ifv"), "")
	assert_eq(DeckBuilder.remove(p, db, "gatling_gun"), "")
	assert_eq(p.deck.size(), size)
	assert_true(p.deck_is_legal(db))


func test_removing_a_card_that_is_not_in_the_deck_is_refused() -> void:
	var p := _rich()
	assert_true(DeckBuilder.remove(p, _get_db(), "ifv").contains("not in the deck"))


func test_the_starter_deck_can_be_put_back_and_the_collection_stays() -> void:
	var db := _get_db()
	var p := _rich()
	DeckBuilder.add(p, db, "ifv")
	assert_eq(DeckBuilder.reset(p, db), "")
	assert_eq(Array(p.deck), db.deck("starter").ids())
	assert_true(p.owns("ifv"))


func test_a_read_only_profile_cannot_be_edited() -> void:
	var db := _get_db()
	var p := _rich()
	p.read_only = true
	var before := p.deck.size()
	assert_true(DeckBuilder.add(p, db, "ifv").contains("newer"))
	assert_true(DeckBuilder.remove(p, db, "tank").contains("newer"))
	assert_true(DeckBuilder.reset(p, db).contains("newer"))
	assert_true(DeckBuilder.toggle_doctrine(p, db, "hollow_points").contains("newer"))
	assert_eq(p.deck.size(), before)


func test_one_doctrine_at_a_time_and_only_owned_doctrines() -> void:
	var db := _get_db()
	var p := _rich()
	assert_eq(DeckBuilder.toggle_doctrine(p, db, "hollow_points"), "")
	assert_eq(Array(p.doctrines), ["hollow_points"])
	assert_eq(DeckBuilder.toggle_doctrine(p, db, "hollow_points"), "")
	assert_eq(p.doctrines.size(), 0, "choosing it again drops it")
	assert_true(DeckBuilder.toggle_doctrine(p, db, "tank") != "")
	var poor := PlayerProfile.new_game(db, 1)
	assert_true(DeckBuilder.toggle_doctrine(poor, db, "hollow_points") != "", "not owned yet")


func test_the_lists_are_sorted_by_cost_and_split_by_kind() -> void:
	var db := _get_db()
	var p := _rich()
	var cards := DeckBuilder.deckable_cards(p, db)
	assert_true(not cards.has("hollow_points"))
	for i in range(1, cards.size()):
		assert_true(db.card(cards[i - 1]).cost <= db.card(cards[i]).cost)
	assert_eq(Array(DeckBuilder.doctrine_cards(p, db)), ["hollow_points"])
	assert_eq(DeckBuilder.counts(PackedStringArray(["a", "b", "a"])), {"a": 2, "b": 1})
	assert_true(DeckBuilder.summary(p, db).contains("12 to 24"))


# --- what the battle is given -------------------------------------------------------------------------------------

func test_the_loadout_is_the_players_deck_and_doctrine() -> void:
	var db := _get_db()
	var p := _rich()
	DeckBuilder.add(p, db, "ifv")
	DeckBuilder.toggle_doctrine(p, db, "hollow_points")
	var lo := DeckBuilder.loadout(p, db)
	assert_eq(Array(lo["deck"]), Array(p.deck))
	assert_eq(Array(lo["doctrines"]), ["hollow_points"])


func test_an_illegal_deck_falls_back_to_the_starter_deck_for_the_battle() -> void:
	var db := _get_db()
	var p := _rich()
	p.deck = PackedStringArray(["tank", "tank"])
	p.doctrines = PackedStringArray(["hollow_points", "tank", "nuclear_bomb"])
	var lo := DeckBuilder.loadout(p, db)
	assert_eq(Array(lo["deck"]), db.deck("starter").ids())
	assert_eq(Array(lo["doctrines"]), ["hollow_points"], "only an owned doctrine card counts")


func test_a_player_deck_mission_needs_a_fallback_deck() -> void:
	var db := _get_db()
	var m: MissionDefinition = db.mission("dev_player_deck").duplicate()
	assert_eq(m.deck_source, MissionDefinition.DeckSource.PLAYER)
	assert_eq(m.validate().size(), 0)
	m.deck_id = ""
	assert_true(m.validate().size() > 0)


func test_a_battle_started_from_the_menu_draws_the_players_deck() -> void:
	var db := _get_db()
	var p := _rich()
	for i in 3:
		DeckBuilder.add(p, db, "ifv")
	DeckBuilder.toggle_doctrine(p, db, "hollow_points")
	_use_temp(p)
	GameSession.pending_mission = "dev_player_deck"
	var b := BattleController.new()
	b.auto_step = false
	_in_tree(b)
	assert_eq(b.deck.total_cards(), p.deck.size())
	var ifvs := 0
	for cid in b.deck.draw_pile + b.deck.hand:
		ifvs += 1 if cid == "ifv" else 0
	assert_eq(ifvs, 3, "the cards the player added are in the draw")
	assert_true(b.extra_doctrines.has("hollow_points"))
	b.free()
	_release_temp()


func test_the_same_mission_from_the_command_line_uses_its_own_deck() -> void:
	var db := _get_db()
	var p := _rich()
	for i in 3:
		DeckBuilder.add(p, db, "ifv")
	_use_temp(p)
	var b := BattleController.new()
	b.auto_step = false
	b.mission_id = "dev_player_deck"
	_in_tree(b)
	assert_eq(b.deck.total_cards(), db.deck("starter").card_ids.size(), "a plain launch ignores the player's profile")
	assert_eq(b.extra_doctrines.size(), 0)
	b.free()
	_release_temp()


func test_a_fixed_deck_mission_ignores_the_players_deck() -> void:
	var db := _get_db()
	var p := _rich()
	for i in 3:
		DeckBuilder.add(p, db, "ifv")
	_use_temp(p)
	GameSession.pending_mission = "m2_card_defense"
	var b := BattleController.new()
	b.auto_step = false
	_in_tree(b)
	assert_eq(b.deck.total_cards(), db.deck("starter").card_ids.size())
	b.free()
	_release_temp()


func test_mission_select_says_a_mission_uses_your_deck() -> void:
	var db := _get_db()
	var p := _rich()
	var lines := MissionListing.facts(db, db.mission("dev_player_deck"), "", p)
	assert_true("\n".join(lines).contains("Deck: yours (%d cards" % p.deck.size()))
	var fixed := MissionListing.facts(db, db.mission("m2_card_defense"), "", p)
	assert_true("\n".join(fixed).contains("Deck: "), "a fixed mission still names its deck")
	assert_true(not "\n".join(fixed).contains("yours"))


# --- the screen ---------------------------------------------------------------------------------------------------

func _screen(p: PlayerProfile) -> DeckScreen:
	_use_temp(p)
	var s := DeckScreen.new()
	s.bind(_get_db(), p)
	_in_tree(s)
	return s


func _pick(grid: CardGrid, card_id: String) -> void:
	grid.select(card_id)


func test_the_screen_shows_every_card_and_greys_out_the_ones_not_owned() -> void:
	var db := _get_db()
	var p := _rich()
	var s := _screen(p)
	var owned: CardGrid = s.find_child("Owned", true, false)
	var deck: CardGrid = s.find_child("Deck", true, false)
	assert_eq(owned.face_count(), db.cards.size(), "one card for every card of the game")
	assert_eq(deck.face_count(), DeckBuilder.counts(p.deck).size())
	var locked := 0
	for f in owned.faces():
		assert_eq(f.locked, not p.owns(f.card_id), "%s: locked exactly when not owned" % f.card_id)
		assert_eq(f.material != null, f.locked, "%s: grey when locked" % f.card_id)
		locked += 1 if f.locked else 0
	assert_eq(locked, db.cards.size() - p.collection.size())
	assert_true(locked > 0, "a new game still has cards to win")
	assert_true(owned.face("nuclear_bomb").locked and not owned.face("tank").locked)
	for f in deck.faces():
		assert_true(not f.locked, "the deck holds owned cards only")
	s.free()
	_release_temp()


func test_the_cards_show_the_copies_in_the_deck_and_the_chosen_doctrine() -> void:
	var p := _rich()
	var s := _screen(p)
	var owned: CardGrid = s.find_child("Owned", true, false)
	var deck: CardGrid = s.find_child("Deck", true, false)
	var tank_copies := DeckBuilder.counts(p.deck)["tank"] as int
	assert_eq(owned.face("tank").badge, "%d/%d" % [tank_copies, _get_db().card("tank").max_copies])
	assert_eq(deck.face("tank").badge, "x%d" % tank_copies)
	assert_eq(owned.face("nuclear_bomb").badge, "", "a locked card has no count")
	assert_eq(owned.face("hollow_points").badge, "")
	_pick(owned, "hollow_points")
	(s.find_child("Add", true, false) as Button).pressed.emit()
	assert_eq(owned.face("hollow_points").badge, "ON")
	s.free()
	_release_temp()


func test_the_left_grid_is_in_card_order_and_the_title_counts_the_unlocked() -> void:
	var db := _get_db()
	var p := _rich()
	var s := _screen(p)
	var ids: Array[String] = DeckBuilder.catalog(p, db)
	assert_eq(ids.size(), db.cards.size())
	assert_eq(s._owned_ids, ids)
	var owned_count := p.collection.size()
	for i in ids.size():
		assert_eq(p.owns(ids[i]), i < owned_count, "owned cards first, then the locked ones")
	for group in [ids.slice(0, owned_count), ids.slice(owned_count)]:
		var first_doctrine := -1
		for i in group.size():
			var is_doc := db.card(group[i]).card_kind == CardDefinition.CardKind.DOCTRINE
			if is_doc and first_doctrine < 0:
				first_doctrine = i
			if first_doctrine >= 0:
				assert_true(is_doc, "doctrines come last in a group")
			elif i > 0:
				assert_true(db.card(group[i - 1]).cost <= db.card(group[i]).cost, "cheapest first")
	assert_eq(s.selected_owned(), ids[0], "a new screen starts on a card the player owns")
	assert_true(not (s.find_child("Add", true, false) as Button).disabled)
	assert_true(s._owned_title.text.contains("%d / %d" % [p.collection.size(), db.cards.size()]), s._owned_title.text)
	s.free()
	_release_temp()


func test_a_locked_card_says_where_it_can_be_won_and_cannot_be_added() -> void:
	var db := _get_db()
	var p := _rich()
	var s := _screen(p)
	var owned: CardGrid = s.find_child("Owned", true, false)
	var locked_id := ""
	for cid: String in s._owned_ids:
		if not p.owns(cid) and not db.main_campaign().mission_offering(cid).is_empty():
			locked_id = cid
			break
	assert_true(not locked_id.is_empty(), "some locked card is in a reward pool")
	_pick(owned, locked_id)
	var add := s.find_child("Add", true, false) as Button
	assert_true(add.disabled and add.text == "Locked")
	var mission := db.mission(db.main_campaign().mission_offering(locked_id))
	assert_true(s._details.text.contains("Locked. Win %s" % mission.display_name), s._details.text)
	assert_true(s._details.text.contains(db.card(locked_id).description), "the card can be read before it is won")
	var size := p.deck.size()
	s._on_add()
	assert_eq(p.deck.size(), size, "nothing was added")
	assert_true(s._status.text.contains("Locked"))
	assert_eq(s.find_children("Upgrade_*", "Button", true, false).size(), 0, "no upgrades for a card not owned")
	var preview: TextureRect = s.find_child("CardPreview", true, false)
	assert_true(preview.material != null, "the big picture is grey too")
	_pick(owned, "tank")
	assert_true(not add.disabled and add.text == "Add" and preview.material == null)
	s.free()
	_release_temp()


func test_the_campaign_knows_which_mission_can_offer_a_card() -> void:
	var camp := _get_db().main_campaign()
	assert_eq(camp.mission_offering("no_such_card"), "")
	var any_offered := false
	for cid: String in _get_db().cards:
		var mid := camp.mission_offering(cid)
		if not mid.is_empty():
			any_offered = true
			assert_true(camp.pool_of(mid).has(cid))
	assert_true(any_offered)


func test_the_screen_shows_a_card_back_until_a_card_is_picked_then_its_picture() -> void:
	var p := _rich()
	var s := _screen(p)
	var preview: TextureRect = s.find_child("CardPreview", true, false)
	var owned: CardGrid = s.find_child("Owned", true, false)
	owned.deselect()
	s._show_selected_details()
	assert_true(preview != null and preview.texture == CardArt.back(), "nothing picked: a card back")
	var id: String = s._owned_ids[0]
	owned.select(id)
	assert_true(preview.texture == CardArt.texture(id), "the picture of %s" % id)
	assert_eq(preview.custom_minimum_size, CardArt.texture(id).get_size() * 2.0, "shown at 2x")
	s.free()
	_release_temp()


func test_clicking_and_the_arrow_keys_select_cards_in_the_grid() -> void:
	var p := _rich()
	var s := _screen(p)
	var owned: CardGrid = s.find_child("Owned", true, false)
	var first: String = s._owned_ids[0]
	assert_eq(owned.selected_id(), first, "the first card starts selected")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	owned.face(s._owned_ids[3])._gui_input(click)
	assert_eq(s.selected_owned(), s._owned_ids[3])
	var right := InputEventAction.new()
	right.action = "ui_right"
	right.pressed = true
	owned._gui_input(right)
	assert_eq(s.selected_owned(), s._owned_ids[4])
	var down := InputEventAction.new()
	down.action = "ui_down"
	down.pressed = true
	owned._gui_input(down)
	assert_eq(s.selected_owned(), s._owned_ids[4 + owned.columns])
	var up := InputEventAction.new()
	up.action = "ui_up"
	up.pressed = true
	for i in 10:
		owned._gui_input(up)
	assert_eq(s.selected_owned(), s._owned_ids[(4 + owned.columns) % owned.columns], "stops at the top row")
	s.free()
	_release_temp()


func test_enter_and_double_click_add_and_remove() -> void:
	var p := _rich()
	var s := _screen(p)
	var owned: CardGrid = s.find_child("Owned", true, false)
	var deck: CardGrid = s.find_child("Deck", true, false)
	owned.select("ifv")
	var size := p.deck.size()
	var enter := InputEventAction.new()
	enter.action = "ui_accept"
	enter.pressed = true
	owned._gui_input(enter)
	assert_eq(p.deck.size(), size + 1, "Enter adds")
	var dbl := InputEventMouseButton.new()
	dbl.button_index = MOUSE_BUTTON_LEFT
	dbl.pressed = true
	dbl.double_click = true
	deck.face("ifv")._gui_input(dbl)
	assert_eq(p.deck.size(), size, "double-click on a deck card removes a copy")
	s.free()
	_release_temp()


func test_adding_and_removing_in_the_screen_changes_the_deck_and_saves() -> void:
	var db := _get_db()
	var p := _rich()
	var s := _screen(p)
	var owned: CardGrid = s.find_child("Owned", true, false)
	_pick(owned, "ifv")
	var size := p.deck.size()
	(s.find_child("Add", true, false) as Button).pressed.emit()
	assert_eq(p.deck.size(), size + 1)
	assert_true(FileAccess.file_exists(PATH), "saved at once")
	assert_true(ProfileStore.load_from(db, PATH).profile.deck.has("ifv"))
	var deck: CardGrid = s.find_child("Deck", true, false)
	assert_eq(s.selected_owned(), "ifv", "the card stays selected")
	assert_true(deck.face("ifv") != null, "and shows in the deck")
	_pick(deck, "ifv")
	(s.find_child("Remove", true, false) as Button).pressed.emit()
	assert_eq(p.deck.size(), size)
	assert_true(deck.face("ifv") == null)
	s.free()
	_release_temp()


func test_a_refused_change_is_explained_and_not_saved() -> void:
	var p := _rich()
	var s := _screen(p)
	var owned: CardGrid = s.find_child("Owned", true, false)
	_pick(owned, "tank")
	var size := p.deck.size()
	(s.find_child("Add", true, false) as Button).pressed.emit()  # the starter deck already holds three tanks
	assert_eq(p.deck.size(), size)
	var said := false
	for l in s.find_children("*", "Label", true, false):
		said = said or (l as Label).text.contains("at most 3")
	assert_true(said, "the reason is shown")
	assert_true(not FileAccess.file_exists(PATH), "nothing to save")
	s.free()
	_release_temp()


func test_the_doctrine_is_chosen_in_the_screen() -> void:
	var db := _get_db()
	var p := _rich()
	var s := _screen(p)
	var owned: CardGrid = s.find_child("Owned", true, false)
	_pick(owned, "hollow_points")
	assert_eq(s.selected_owned(), "hollow_points")
	assert_eq((s.find_child("Add", true, false) as Button).text, "Use doctrine")
	(s.find_child("Add", true, false) as Button).pressed.emit()
	assert_eq(Array(p.doctrines), ["hollow_points"])
	assert_eq((s.find_child("Add", true, false) as Button).text, "Drop doctrine")
	assert_true(ProfileStore.load_from(db, PATH).profile.doctrines.has("hollow_points"))
	s.free()
	_release_temp()


func test_the_starter_button_and_back_button_work() -> void:
	var db := _get_db()
	var p := _rich()
	DeckBuilder.add(p, db, "ifv")
	var s := _screen(p)
	(s.find_child("ResetDeck", true, false) as Button).pressed.emit()
	assert_eq(Array(p.deck), db.deck("starter").ids())
	var closed: Array[bool] = []
	s.closed.connect(func() -> void: closed.append(true))
	(s.find_child("Back", true, false) as Button).pressed.emit()
	assert_eq(closed.size(), 1)
	s.free()
	_release_temp()
