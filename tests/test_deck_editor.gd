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


func _row_of(list: ItemList, ids: Array[String], card_id: String) -> int:
	return ids.find(card_id)


func test_the_screen_lists_owned_cards_and_the_deck() -> void:
	var p := _rich()
	var s := _screen(p)
	var owned: ItemList = s.find_child("Owned", true, false)
	var deck: ItemList = s.find_child("Deck", true, false)
	assert_eq(owned.item_count, DeckBuilder.deckable_cards(p, _get_db()).size() + 1, "owned cards plus the one doctrine")
	assert_eq(deck.item_count, DeckBuilder.counts(p.deck).size())
	var texts := PackedStringArray()
	for i in owned.item_count:
		texts.append(owned.get_item_text(i))
	assert_true("|".join(texts).contains("doctrine"))
	s.free()
	_release_temp()


func test_the_screen_shows_a_card_back_until_a_card_is_picked_then_its_picture() -> void:
	var p := _rich()
	var s := _screen(p)
	var preview: TextureRect = s.find_child("CardPreview", true, false)
	var owned: ItemList = s.find_child("Owned", true, false)
	owned.deselect_all()
	s._show_selected_details()
	assert_true(preview != null and preview.texture == CardArt.back(), "nothing picked: a card back")
	owned.select(0)
	owned.item_selected.emit(0)
	var id: String = s._owned_ids[0]
	assert_true(preview.texture == CardArt.texture(id), "the picture of %s" % id)
	assert_eq(preview.custom_minimum_size, CardArt.texture(id).get_size() * 2.0, "shown at 2x")
	s.free()
	_release_temp()


func test_adding_and_removing_in_the_screen_changes_the_deck_and_saves() -> void:
	var db := _get_db()
	var p := _rich()
	var s := _screen(p)
	var owned: ItemList = s.find_child("Owned", true, false)
	var ifv_row := -1
	for i in owned.item_count:
		if owned.get_item_text(i).begins_with(db.card("ifv").display_name):
			ifv_row = i
	assert_true(ifv_row >= 0)
	owned.select(ifv_row)
	owned.item_selected.emit(ifv_row)
	var size := p.deck.size()
	(s.find_child("Add", true, false) as Button).pressed.emit()
	assert_eq(p.deck.size(), size + 1)
	assert_true(FileAccess.file_exists(PATH), "saved at once")
	assert_true(ProfileStore.load_from(db, PATH).profile.deck.has("ifv"))
	var deck: ItemList = s.find_child("Deck", true, false)
	assert_eq(s.selected_owned(), "ifv", "the card stays selected")
	var drow := -1
	for i in deck.item_count:
		if deck.get_item_text(i).contains(db.card("ifv").display_name):
			drow = i
	deck.select(drow)
	deck.item_selected.emit(drow)
	(s.find_child("Remove", true, false) as Button).pressed.emit()
	assert_eq(p.deck.size(), size)
	s.free()
	_release_temp()


func test_a_refused_change_is_explained_and_not_saved() -> void:
	var db := _get_db()
	var p := _rich()
	var s := _screen(p)
	var owned: ItemList = s.find_child("Owned", true, false)
	var row := -1
	for i in owned.item_count:
		if owned.get_item_text(i).begins_with(db.card("tank").display_name):
			row = i
	owned.select(row)
	owned.item_selected.emit(row)
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
	var owned: ItemList = s.find_child("Owned", true, false)
	var row := owned.item_count - 1  # doctrine cards come after the deck cards
	owned.select(row)
	owned.item_selected.emit(row)
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
