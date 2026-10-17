class_name MissionSelect
extends Control
## Mission select (docs/specs/menus.md, docs/specs/progression.md): the missions in campaign order with their facts on
## the right; locked missions are greyed and cannot be started, won ones show their best result. Test missions are listed
## only when the settings say so. Start launches the mission (Enter or double-click on a row also does); Back / Esc returns.

signal back
signal start_requested(mission_id: String)

var _db: ContentDb
var _profile: PlayerProfile
var _list: ItemList
var _title: Label
var _facts: Label
var _chooser: RewardChooser
var _side: VBoxContainer
var _start: Button
var _level: String = ContentDb.NORMAL_DIFFICULTY  # the difficulty chosen here (a DifficultyDefinition id)
var _level_buttons: Dictionary = {}  # difficulty id -> its toggle button
var _ids: Array[String] = []  # item index -> mission id ("" for a group heading)


func bind(db: ContentDb) -> void:
	_db = db
	_profile = GameSession.profile(db) if db != null else null
	var saved := GameSession.settings().difficulty
	_level = saved if db != null and db.difficulty(saved) != null else ContentDb.NORMAL_DIFFICULTY


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := UiKit.centered()
	add_child(center)
	var panel := UiKit.panel()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)
	box.add_child(UiKit.label("SELECT MISSION", 44, UiKit.ACCENT))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	box.add_child(row)
	_list = ItemList.new()
	_list.custom_minimum_size = Vector2(620, 520)
	_list.add_theme_font_size_override("font_size", 26)
	_list.add_theme_color_override("font_color", UiKit.TEXT)
	_list.add_theme_color_override("font_selected_color", Color.WHITE)
	_list.add_theme_color_override("guide_color", Color(0, 0, 0, 0))
	_list.item_selected.connect(_on_selected)
	_list.item_activated.connect(func(_i: int) -> void: _start_selected())
	row.add_child(_list)
	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(620, 0)
	side.add_theme_constant_override("separation", 14)
	row.add_child(side)
	_side = side
	_title = UiKit.label("", 34, UiKit.ACCENT)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(_title)
	_facts = UiKit.label("", 24)
	_facts.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(_facts)
	if _db != null and not _db.difficulties.is_empty():
		side.add_child(UiKit.label("Difficulty (Left / Right)", 22, UiKit.DIM))
		var levels := HBoxContainer.new()
		levels.add_theme_constant_override("separation", 12)
		side.add_child(levels)
		for id in _db.difficulty_ids():
			var btn := UiKit.button(_db.difficulty(id).display_name, 24, Vector2(170, 52))
			btn.name = "Difficulty_%s" % id
			btn.toggle_mode = true
			btn.pressed.connect(set_level.bind(id))
			levels.add_child(btn)
			_level_buttons[id] = btn
		_show_level()
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	box.add_child(buttons)
	_start = UiKit.button("Start", 28, Vector2(260, 60))
	_start.name = "Start"
	_start.pressed.connect(_start_selected)
	buttons.add_child(_start)
	var b := UiKit.button("Back", 28, Vector2(260, 60))
	b.name = "Back"
	b.pressed.connect(func() -> void: back.emit())
	buttons.add_child(b)
	box.add_child(UiKit.label("Up / Down: choose    Left / Right: difficulty    Enter: start    Esc: back", 18, UiKit.DIM))
	_fill()


## (Re)builds the list; the last mission played is pre-selected, otherwise the first real mission.
func _fill(select_id: String = "") -> void:
	_list.clear()
	_ids.clear()
	if _db == null:
		return
	var group := ""
	var want := select_id if not select_id.is_empty() else GameSession.settings().last_mission
	var camp := _db.main_campaign()
	if want.is_empty() or _tag(want) == "locked":
		want = camp.next_up(_profile) if camp != null and _profile != null else ""  # the next mission to play
	var pick := -1
	for e in MissionListing.entries(_db, GameSession.settings().show_test_missions):
		if e.group != group:
			group = e.group
			var h := _list.add_item("— %s —" % group.to_upper(), null, false)
			_list.set_item_disabled(h, true)
			_list.set_item_custom_fg_color(h, UiKit.DIM)
			_ids.append("")
		var tag := _tag(e.id)
		var i := _list.add_item(e.name if tag.is_empty() else "%s   [%s]" % [e.name, tag])
		if tag == "locked":
			_list.set_item_custom_fg_color(i, UiKit.DIM)
		_ids.append(e.id)
		if pick < 0 and e.id == want:
			pick = i
	if pick < 0:
		for i in _ids.size():
			if not _ids[i].is_empty():
				pick = i
				break
	if pick >= 0:
		_list.select(pick)
		_on_selected(pick)
	_list.grab_focus()


## The difficulty chosen here.
func level() -> String:
	return _level


## Chooses a difficulty (remembered in the settings for the next battle). Unknown ids are ignored.
func set_level(id: String) -> void:
	if _db == null or _db.difficulty(id) == null:
		return
	_level = id
	GameSession.settings().difficulty = id
	_show_level()
	if _list != null and not _list.get_selected_items().is_empty():
		_on_selected(_list.get_selected_items()[0])


## The next (+1) or previous (-1) difficulty, stopping at the ends.
func cycle_level(step: int) -> void:
	if _db == null:
		return
	var ids := _db.difficulty_ids()
	var at := ids.find(_level)
	if at >= 0 and not ids.is_empty():
		set_level(ids[clampi(at + step, 0, ids.size() - 1)])


func _show_level() -> void:
	for id: String in _level_buttons:
		(_level_buttons[id] as Button).set_pressed_no_signal(id == _level)


func selected_id() -> String:
	var sel := _list.get_selected_items()
	if sel.is_empty():
		return ""
	return _ids[sel[0]]


## "locked", "won" or "" for a mission id.
func _tag(mission_id: String) -> String:
	return MissionListing.tag_for(_db, _profile, mission_id) if _db != null and _profile != null else ""


func _on_selected(index: int) -> void:
	var id := _ids[index]
	var m := _db.mission(id) if _db != null and not id.is_empty() else null
	if m == null:
		_title.text = ""
		_facts.text = ""
		_start.disabled = true
		return
	_title.text = m.display_name
	var lines := MissionListing.facts(_db, m, _level, _profile)
	if _profile != null:
		lines.append_array(MissionListing.progress_lines(_db, _profile, id))
	_facts.text = "\n".join(lines)
	_start.disabled = _tag(id) == "locked"
	_show_reward(id)


## A reward that was never answered waits here: its three cards are shown under the facts.
func _show_reward(mission_id: String) -> void:
	if _chooser != null:
		_chooser.queue_free()
		_chooser = null
	if _profile == null or not _profile.has_pending_reward(mission_id):
		return
	var offer := GameSession.pending_offer(_db, mission_id)
	if offer.is_empty():
		return
	_chooser = RewardChooser.new()
	_side.add_child(_chooser)
	_chooser.setup(_db, mission_id, offer)
	_chooser.claimed.connect(func(_card_id: String) -> void: _fill(mission_id))


func _start_selected() -> void:
	var id := selected_id()
	if not id.is_empty() and _tag(id) != "locked":
		start_requested.emit(id)


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right")):
		get_viewport().set_input_as_handled()
		cycle_level(-1 if event.is_action_pressed("ui_left") else 1)
		return
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		back.emit()
