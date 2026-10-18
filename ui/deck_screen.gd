class_name DeckScreen
extends Control
## The deck editor (docs/specs/progression.md): the cards the player owns on the left, the deck on the right. Add and
## remove copies, put the starter deck back, choose a doctrine. Every change is checked by DeckBuilder (a refused change
## says why) and saved at once. The rules live in DeckBuilder; this screen only presents them.

signal closed

var _db: ContentDb
var _profile: PlayerProfile
var _owned: ItemList
var _deck: ItemList
var _details: Label
var _status: Label
var _doctrine: Label
var _upgrades: VBoxContainer
var _add: Button
var _owned_ids: Array[String] = []  # row -> card id (deckable cards, then doctrine cards)
var _deck_ids: Array[String] = []  # row -> card id


func bind(db: ContentDb, profile: PlayerProfile) -> void:
	_db = db
	_profile = profile


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := UiKit.centered()
	add_child(center)
	var panel := UiKit.panel()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	box.add_child(UiKit.label("DECK", 44, UiKit.ACCENT))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	box.add_child(row)
	row.add_child(_column("Your cards", Vector2(520, 470), "Owned"))
	row.add_child(_column("Deck", Vector2(460, 470), "Deck"))
	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(430, 0)
	side.add_theme_constant_override("separation", 12)
	row.add_child(side)
	_details = UiKit.label("", 22)
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(_details)
	_upgrades = VBoxContainer.new()
	_upgrades.name = "Upgrades"
	_upgrades.add_theme_constant_override("separation", 6)
	side.add_child(_upgrades)
	_doctrine = UiKit.label("", 22, UiKit.DIM)
	_doctrine.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(_doctrine)
	_status = UiKit.label("", 24)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_status)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 14)
	box.add_child(buttons)
	_add = UiKit.button("Add", 24, Vector2(200, 56))
	_add.name = "Add"
	_add.pressed.connect(_on_add)
	buttons.add_child(_add)
	var rem := UiKit.button("Remove", 24, Vector2(200, 56))
	rem.name = "Remove"
	rem.pressed.connect(_on_remove)
	buttons.add_child(rem)
	var reset := UiKit.button("Starter deck", 24, Vector2(220, 56))
	reset.name = "ResetDeck"
	reset.pressed.connect(_on_reset)
	buttons.add_child(reset)
	var back := UiKit.button("Back", 24, Vector2(200, 56))
	back.name = "Back"
	back.pressed.connect(close)
	buttons.add_child(back)
	box.add_child(UiKit.label("Enter or double-click: add / remove    Esc: back    Changes are saved at once", 18, UiKit.DIM))
	_refresh()
	_owned.grab_focus()


func _column(title: String, size: Vector2, list_name: String) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.add_child(UiKit.label(title, 26, UiKit.ACCENT))
	var list := ItemList.new()
	list.name = list_name
	list.custom_minimum_size = size
	list.add_theme_font_size_override("font_size", 18)
	list.add_theme_color_override("font_color", UiKit.TEXT)
	list.add_theme_color_override("font_selected_color", Color.WHITE)
	list.add_theme_color_override("guide_color", Color(0, 0, 0, 0))
	col.add_child(list)
	if list_name == "Owned":
		_owned = list
		list.item_selected.connect(_on_owned_selected)
		list.item_activated.connect(func(_i: int) -> void: _on_add())
	else:
		_deck = list
		list.item_selected.connect(_on_deck_selected)
		list.item_activated.connect(func(_i: int) -> void: _on_remove())
	return col


## Rebuilds both lists and the texts, keeping the selected cards selected where they still exist.
func _refresh(keep_owned: String = "", keep_deck: String = "") -> void:
	if _db == null or _profile == null:
		return
	_owned.clear()
	_owned_ids.clear()
	var counts := DeckBuilder.counts(_profile.deck)
	for cid in DeckBuilder.deckable_cards(_profile, _db):
		var c := _db.card(cid)
		_owned.add_item("%s   %d CP   %d / %d" % [c.display_name, c.cost, int(counts.get(cid, 0)), c.max_copies])
		_owned_ids.append(cid)
	for cid in DeckBuilder.doctrine_cards(_profile, _db):
		var c := _db.card(cid)
		var on := _profile.doctrines.has(cid)
		_owned.add_item("%s   doctrine%s" % [c.display_name, " (chosen)" if on else ""])
		_owned_ids.append(cid)
	_deck.clear()
	_deck_ids.clear()
	var ids: Array[String] = []
	for cid: String in counts:
		ids.append(cid)
	ids.sort_custom(func(a: String, b: String) -> bool:
		var ca := _db.card(a)
		var cb := _db.card(b)
		return ca.cost < cb.cost or (ca.cost == cb.cost and ca.display_name < cb.display_name))
	for cid in ids:
		var c := _db.card(cid)
		_deck.add_item("%d x %s   %d CP" % [counts[cid], c.display_name, c.cost])
		_deck_ids.append(cid)
	_select(_owned, _owned_ids, keep_owned)
	_select(_deck, _deck_ids, keep_deck)
	var chosen := _profile.doctrines[0] if not _profile.doctrines.is_empty() else ""
	_doctrine.text = "Doctrine for player-deck missions: %s" % (_db.card(chosen).display_name if _db.card(chosen) != null else "none")
	_set_status("Deck: %s" % DeckBuilder.summary(_profile, _db))
	_show_selected_details()


func _select(list: ItemList, ids: Array[String], keep: String) -> void:
	if list.item_count == 0:
		return
	var at := ids.find(keep) if not keep.is_empty() else -1
	list.select(maxi(at, 0))


func _set_status(text: String, bad: bool = false) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45) if bad else UiKit.TEXT)


func selected_owned() -> String:
	var sel := _owned.get_selected_items()
	return _owned_ids[sel[0]] if not sel.is_empty() else ""


func selected_deck() -> String:
	var sel := _deck.get_selected_items()
	return _deck_ids[sel[0]] if not sel.is_empty() else ""


func _on_owned_selected(_i: int) -> void:
	_show_selected_details()


func _on_deck_selected(_i: int) -> void:
	var cid := selected_deck()
	if not cid.is_empty():
		_show_card(cid)


func _show_selected_details() -> void:
	var cid := selected_owned()
	if cid.is_empty():
		_details.text = ""
		_add.text = "Add"
		_show_upgrades("")
		return
	_show_card(cid)
	_show_upgrades(cid)


## The upgrades of a card: earned ones can be switched on (one at a time), the others are shown as not earned yet.
func _show_upgrades(card_id: String) -> void:
	for c in _upgrades.get_children():
		_upgrades.remove_child(c)  # out of the tree at once, so a rebuilt button keeps its name
		c.queue_free()
	if card_id.is_empty():
		return
	var ids := _db.upgrades_of(card_id)
	if ids.is_empty():
		return
	_upgrades.add_child(UiKit.label("Upgrades (player-deck missions)", 20, UiKit.DIM))
	for uid in ids:
		var up := _db.upgrade(uid)
		var have := _profile.unlocked_upgrades.has(uid)
		var on := String(_profile.equipped.get(card_id, "")) == uid
		var b := UiKit.button("%s%s" % [up.display_name, " (on)" if on else ("" if have else " (not earned)")], 20, Vector2(420, 44))
		b.name = "Upgrade_%s" % uid
		b.tooltip_text = up.description
		b.disabled = not have
		b.pressed.connect(_on_upgrade.bind(uid, card_id, on))
		_upgrades.add_child(b)
		var d := UiKit.label(up.description, 16, UiKit.DIM)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(420, 0)
		_upgrades.add_child(d)


## Switches an upgrade on (replacing the other branch of the card) or, pressed again, off.
func _on_upgrade(upgrade_id: String, card_id: String, was_on: bool) -> void:
	var why := DeckBuilder.unequip_upgrade(_profile, card_id) if was_on else DeckBuilder.equip_upgrade(_profile, _db, upgrade_id)
	_after_change(why, selected_owned(), selected_deck())


func _show_card(card_id: String) -> void:
	var c := _db.card(card_id)
	if c == null:
		return
	var doctrine := c.card_kind == CardDefinition.CardKind.DOCTRINE
	var lines := PackedStringArray([c.display_name, c.description])
	lines.append("Cost %d CP.%s Up to %d in a deck." % [c.cost, (" Locks out for %d s." % int(c.lockout_s)) if c.lockout_s > 0.0 else "", c.max_copies] if not doctrine else "Chosen before a mission; it is not drawn.")
	_details.text = "\n".join(lines)
	if selected_owned() == card_id:
		_add.text = ("Drop doctrine" if _profile.doctrines.has(card_id) else "Use doctrine") if doctrine else "Add"


## Adds a copy of the selected owned card (or chooses / drops it as the doctrine).
func _on_add() -> void:
	var cid := selected_owned()
	if cid.is_empty():
		return
	var c := _db.card(cid)
	var why := DeckBuilder.toggle_doctrine(_profile, _db, cid) if c.card_kind == CardDefinition.CardKind.DOCTRINE else DeckBuilder.add(_profile, _db, cid)
	_after_change(why, cid, selected_deck())


## Removes a copy of the selected deck card.
func _on_remove() -> void:
	var cid := selected_deck()
	if cid.is_empty():
		return
	_after_change(DeckBuilder.remove(_profile, _db, cid), selected_owned(), cid)


func _on_reset() -> void:
	_after_change(DeckBuilder.reset(_profile, _db), selected_owned(), "")


func _after_change(why: String, keep_owned: String, keep_deck: String) -> void:
	if not why.is_empty():
		_set_status(why, true)
		return
	GameSession.save_profile()
	_refresh(keep_owned, keep_deck)


func close() -> void:
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
