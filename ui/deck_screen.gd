class_name DeckScreen
extends Control
## The deck editor (docs/specs/progression.md, docs/specs/deck-screen.md): every card of the game as a picture card on the left
## (the ones the player does not own yet are grey and locked), the deck on the right. Add and remove copies, put the starter deck
## back, choose a doctrine. Every change is checked by DeckBuilder (a refused change says why) and saved at once. The rules live
## in DeckBuilder; this screen only presents them.

signal closed

const GRID_HEIGHT: float = 580.0

var _db: ContentDb
var _profile: PlayerProfile
var _owned: CardGrid  # every card of the game; the ones not owned are locked
var _deck: CardGrid
var _owned_title: Label
var _preview: TextureRect
var _details: Label
var _status: Label
var _doctrine: Label
var _upgrades: VBoxContainer
var _add: Button
var _owned_ids: Array[String] = []  # every card id, in the order of the left grid
var _deck_ids: Array[String] = []  # distinct card ids of the deck, in the order of the right grid


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
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	box.add_child(UiKit.label("DECK", 44, UiKit.ACCENT))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	box.add_child(row)
	_owned = CardGrid.new()
	row.add_child(_column("Cards", 5, "Owned", true))
	_deck = CardGrid.new()
	row.add_child(_column("Deck", 4, "Deck", false))
	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(400, 0)
	side.add_theme_constant_override("separation", 10)
	row.add_child(side)
	var stage := CenterContainer.new()  # the picture of the selected card (or a card back), shown at 2x
	stage.name = "CardStage"
	stage.custom_minimum_size = Vector2(0, CardArt.BACK_SIZE.y * 2.0)
	side.add_child(stage)
	_preview = TextureRect.new()
	_preview.name = "CardPreview"
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_SCALE
	stage.add_child(_preview)
	_show_preview("")
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
	box.add_child(UiKit.label("Arrows: move    Tab: other list    Enter or double-click: add / remove    Esc: back    Changes are saved at once", 18, UiKit.DIM))
	_refresh()
	_owned.grab_focus()


func _column(title: String, columns: int, grid_name: String, is_owned: bool) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	var head := UiKit.label(title, 26, UiKit.ACCENT)
	col.add_child(head)
	var grid := _owned if is_owned else _deck
	grid.name = grid_name
	grid.set_columns(columns)
	grid.custom_minimum_size = Vector2(grid.width_for(columns), GRID_HEIGHT)
	col.add_child(grid)
	if is_owned:
		_owned_title = head
		grid.card_selected.connect(_on_owned_selected)
		grid.card_activated.connect(func(_id: String) -> void: _on_add())
	else:
		grid.card_selected.connect(_on_deck_selected)
		grid.card_activated.connect(func(_id: String) -> void: _on_remove())
	return col


## Updates both grids and the texts, keeping the selected cards selected where they still exist.
func _refresh(keep_owned: String = "", keep_deck: String = "") -> void:
	if _db == null or _profile == null:
		return
	var counts := DeckBuilder.counts(_profile.deck)
	if _owned.face_count() == 0:  # the left grid always holds every card, so it is built once
		_owned_ids = DeckBuilder.catalog(_profile, _db)
		for cid in _owned_ids:
			_owned.add_face(_db.card(cid), not _profile.owns(cid))
	var unlocked := 0
	for cid in _owned_ids:
		var c := _db.card(cid)
		var f := _owned.face(cid)
		f.set_badge(_owned_badge(c, counts))
		if _profile.owns(cid):
			unlocked += 1
	_owned_title.text = "Cards   %d / %d unlocked" % [unlocked, _owned_ids.size()]
	var scroll := _deck.scroll_vertical
	_deck.clear_faces()
	_deck_ids.clear()
	var ids: Array[String] = []
	for cid: String in counts:
		ids.append(cid)
	ids.sort_custom(func(a: String, b: String) -> bool:
		var ca := _db.card(a)
		var cb := _db.card(b)
		return ca.cost < cb.cost or (ca.cost == cb.cost and ca.display_name < cb.display_name))
	for cid in ids:
		_deck.add_face(_db.card(cid), false, "x%d" % counts[cid])
		_deck_ids.append(cid)
	_deck.set_deferred("scroll_vertical", scroll)
	_select(_owned, _owned_ids, keep_owned)
	_select(_deck, _deck_ids, keep_deck)
	var chosen := _profile.doctrines[0] if not _profile.doctrines.is_empty() else ""
	_doctrine.text = "Doctrine for player-deck missions: %s" % (_db.card(chosen).display_name if _db.card(chosen) != null else "none")
	_set_status("Deck: %s" % DeckBuilder.summary(_profile, _db))
	_show_selected_details()


## The small text on a card of the left grid: copies in the deck / allowed, or ON for the chosen doctrine.
func _owned_badge(c: CardDefinition, counts: Dictionary) -> String:
	if not _profile.owns(c.id):
		return ""
	if c.card_kind == CardDefinition.CardKind.DOCTRINE:
		return "ON" if _profile.doctrines.has(c.id) else ""
	return "%d/%d" % [int(counts.get(c.id, 0)), c.max_copies]


func _select(grid: CardGrid, ids: Array[String], keep: String) -> void:
	if ids.is_empty():
		grid.deselect()
		return
	var at := ids.find(keep) if not keep.is_empty() else -1
	grid.select(ids[maxi(at, 0)], true, false)


func _set_status(text: String, bad: bool = false) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45) if bad else UiKit.TEXT)


func selected_owned() -> String:
	return _owned.selected_id()


func selected_deck() -> String:
	return _deck.selected_id()


func _on_owned_selected(_id: String) -> void:
	_show_selected_details()


func _on_deck_selected(_id: String) -> void:
	var cid := selected_deck()
	if not cid.is_empty():
		_show_card(cid)


func _show_selected_details() -> void:
	var cid := selected_owned()
	if cid.is_empty():
		_details.text = ""
		_add.text = "Add"
		_add.disabled = false
		_show_upgrades("")
		_show_preview("")
		return
	_show_card(cid)
	_show_upgrades(cid)


## The picture of a card in the preview (grey when the card is locked), or the card back when there is none (nothing selected).
func _show_preview(card_id: String) -> void:
	var tex: Texture2D = CardArt.texture(card_id) if not card_id.is_empty() else null
	if tex == null:
		tex = CardArt.back()
	_preview.texture = tex
	_preview.custom_minimum_size = tex.get_size() * 2.0 if tex != null else Vector2.ZERO
	_preview.material = CardFace.grey_material() if not card_id.is_empty() and not _profile.owns(card_id) else null


## The upgrades of a card: earned ones can be switched on (one at a time), the others are shown as not earned yet.
func _show_upgrades(card_id: String) -> void:
	for c in _upgrades.get_children():
		_upgrades.remove_child(c)  # out of the tree at once, so a rebuilt button keeps its name
		c.queue_free()
	if card_id.is_empty() or not _profile.owns(card_id):
		return
	var ids := _db.upgrades_of(card_id)
	if ids.is_empty():
		return
	_upgrades.add_child(UiKit.label("Upgrades (player-deck missions)", 20, UiKit.DIM))
	for uid in ids:
		var up := _db.upgrade(uid)
		var have := _profile.unlocked_upgrades.has(uid)
		var on := String(_profile.equipped.get(card_id, "")) == uid
		var b := UiKit.button("%s%s" % [up.display_name, " (on)" if on else ("" if have else " (not earned)")], 20, Vector2(380, 44))
		b.name = "Upgrade_%s" % uid
		b.tooltip_text = up.description
		b.disabled = not have
		b.pressed.connect(_on_upgrade.bind(uid, card_id, on))
		_upgrades.add_child(b)
		var d := UiKit.label(up.description, 16, UiKit.DIM)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(380, 0)
		_upgrades.add_child(d)


## Switches an upgrade on (replacing the other branch of the card) or, pressed again, off.
func _on_upgrade(upgrade_id: String, card_id: String, was_on: bool) -> void:
	var why := DeckBuilder.unequip_upgrade(_profile, card_id) if was_on else DeckBuilder.equip_upgrade(_profile, _db, upgrade_id)
	_after_change(why, selected_owned(), selected_deck())


func _show_card(card_id: String) -> void:
	var c := _db.card(card_id)
	if c == null:
		return
	_show_preview(card_id)
	var doctrine := c.card_kind == CardDefinition.CardKind.DOCTRINE
	var lines := PackedStringArray([c.display_name, c.description])
	lines.append("Cost %d CP.%s Up to %d in a deck." % [c.cost, (" Locks out for %d s." % int(c.lockout_s)) if c.lockout_s > 0.0 else "", c.max_copies] if not doctrine else "Chosen before a mission; it is not drawn.")
	if not _profile.owns(card_id):
		lines.append(_locked_line(card_id))
	_details.text = "\n".join(lines)
	if selected_owned() == card_id:
		_add.disabled = not _profile.owns(card_id)
		if not _profile.owns(card_id):
			_add.text = "Locked"
		else:
			_add.text = ("Drop doctrine" if _profile.doctrines.has(card_id) else "Use doctrine") if doctrine else "Add"


## Where a locked card can be won: the first campaign mission whose reward can offer it.
func _locked_line(card_id: String) -> String:
	var camp := _db.main_campaign()
	var mid := camp.mission_offering(card_id) if camp != null else ""
	var m := _db.mission(mid) if not mid.is_empty() else null
	if m == null:
		return "Locked. Not found in the campaign yet."
	return "Locked. Win %s to have it offered as a reward." % m.display_name


## Adds a copy of the selected card (or chooses / drops it as the doctrine).
func _on_add() -> void:
	var cid := selected_owned()
	if cid.is_empty():
		return
	if not _profile.owns(cid):
		_set_status(_locked_line(cid), true)
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
