class_name CardGrid
extends ScrollContainer
## A scrolling grid of CardFaces with one selected card (docs/specs/deck-screen.md). Click selects, double-click or Enter
## activates, the arrow keys move the selection and keep it in view. The grid holds the keyboard focus; its selected card is
## outlined bright while it does and dim when it does not.

signal card_selected(card_id: String)
signal card_activated(card_id: String)

var columns: int = 4
var _grid: GridContainer
var _faces: Array[CardFace] = []
var _selected: String = ""


func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 6)
	add_child(margin)
	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	margin.add_child(_grid)
	focus_entered.connect(_paint)
	focus_exited.connect(_paint)


func set_columns(n: int) -> void:
	columns = n
	_grid.columns = n


## The width that shows `columns` faces and the scroll bar.
func width_for(n: int) -> float:
	return float(n) * (CardFace.SIZE.x + 8.0) - 8.0 + 12.0 + 20.0


func clear_faces() -> void:
	for f in _faces:
		_grid.remove_child(f)
		f.queue_free()
	_faces.clear()


func add_face(def: CardDefinition, locked: bool, badge: String = "") -> CardFace:
	var f := CardFace.new()
	f.name = "Card_%s" % def.id
	f.setup(def, locked, badge)
	f.picked.connect(_on_picked)
	f.activated.connect(func(id: String) -> void: card_activated.emit(id))
	_grid.add_child(f)
	_faces.append(f)
	return f


func face_count() -> int:
	return _faces.size()


func faces() -> Array[CardFace]:
	return _faces


func face(card_id: String) -> CardFace:
	for f in _faces:
		if f.card_id == card_id:
			return f
	return null


func selected_id() -> String:
	return _selected


## Selects a card (no-op when the grid does not hold it). `scroll` brings it into view; `notify` sends card_selected.
func select(card_id: String, scroll: bool = true, notify: bool = true) -> void:
	if face(card_id) == null:
		return
	_selected = card_id
	_paint()
	if scroll:
		_show_selected.call_deferred()
	if notify:
		card_selected.emit(card_id)


func deselect() -> void:
	_selected = ""
	_paint()


func _paint() -> void:
	for f in _faces:
		f.set_selected(f.card_id == _selected, has_focus())


func _show_selected() -> void:
	var f := face(_selected)
	if f != null and is_inside_tree():
		ensure_control_visible(f)


func _on_picked(card_id: String) -> void:
	grab_focus()
	select(card_id, false)


func _gui_input(event: InputEvent) -> void:
	if _faces.is_empty():
		return
	var at := -1
	for i in _faces.size():
		if _faces[i].card_id == _selected:
			at = i
	var to := at
	if event.is_action_pressed("ui_right"):
		to = at + 1
	elif event.is_action_pressed("ui_left"):
		to = at - 1
	elif event.is_action_pressed("ui_down"):
		to = at + columns
	elif event.is_action_pressed("ui_up"):
		to = at - columns
	elif event.is_action_pressed("ui_accept"):
		if at >= 0:
			card_activated.emit(_selected)
		accept_event()
		return
	else:
		return
	accept_event()
	var last := _faces.size() - 1
	if at < 0:
		to = 0
	elif to < 0:
		to = at  # up from the top row, left from the first card: stay
	elif to > last:
		to = last if at / columns < last / columns and event.is_action_pressed("ui_down") else at  # down into a short last row
	to = clampi(to, 0, last)
	if to != at:
		select(_faces[to].card_id)
