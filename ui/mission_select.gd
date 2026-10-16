class_name MissionSelect
extends Control
## Mission select (docs/specs/menus.md): every mission in the database, grouped, with its facts on the right.
## Start launches it (Enter or double-click on a row also does); Back / Esc returns.

signal back
signal start_requested(mission_id: String)

var _db: ContentDb
var _list: ItemList
var _title: Label
var _facts: Label
var _start: Button
var _ids: Array[String] = []  # item index -> mission id ("" for a group heading)


func bind(db: ContentDb) -> void:
	_db = db


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
	_title = UiKit.label("", 34, UiKit.ACCENT)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(_title)
	_facts = UiKit.label("", 24)
	_facts.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(_facts)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	box.add_child(buttons)
	_start = UiKit.button("Start", 28, Vector2(260, 60))
	_start.pressed.connect(_start_selected)
	buttons.add_child(_start)
	var b := UiKit.button("Back", 28, Vector2(260, 60))
	b.pressed.connect(func() -> void: back.emit())
	buttons.add_child(b)
	box.add_child(UiKit.label("Up / Down: choose    Enter: start    Esc: back", 18, UiKit.DIM))
	_fill()


## (Re)builds the list; the last mission played is pre-selected, otherwise the first real mission.
func _fill() -> void:
	_list.clear()
	_ids.clear()
	if _db == null:
		return
	var group := ""
	var want := GameSession.settings().last_mission
	var pick := -1
	for e in MissionListing.entries(_db):
		if e.group != group:
			group = e.group
			var h := _list.add_item("— %s —" % group.to_upper(), null, false)
			_list.set_item_disabled(h, true)
			_list.set_item_custom_fg_color(h, UiKit.DIM)
			_ids.append("")
		var i := _list.add_item(e.name)
		_ids.append(e.id)
		if pick < 0 and (e.id == want or (want.is_empty() and e.group == MissionListing.GROUP_MISSIONS)):
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


func selected_id() -> String:
	var sel := _list.get_selected_items()
	if sel.is_empty():
		return ""
	return _ids[sel[0]]


func _on_selected(index: int) -> void:
	var id := _ids[index]
	var m := _db.mission(id) if _db != null and not id.is_empty() else null
	if m == null:
		_title.text = ""
		_facts.text = ""
		_start.disabled = true
		return
	_title.text = m.display_name
	_facts.text = "\n".join(MissionListing.facts(_db, m))
	_start.disabled = false


func _start_selected() -> void:
	var id := selected_id()
	if not id.is_empty():
		start_requested.emit(id)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		back.emit()
