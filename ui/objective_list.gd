class_name ObjectiveList
extends CanvasLayer
## The mission's objectives on the HUD, top right: primary, bonus, lose-if, each with live progress and a mark for
## pending / holding / met / failed. Shown only for missions that declare objectives (the others keep the plain HOLD clock).
## Read-only presentation: the words come from ObjectiveText, the numbers from the tracker.

const COLOR_PENDING := Color(1.0, 1.0, 1.0)
const COLOR_HOLDING := Color(0.75, 0.9, 1.0)
const COLOR_MET := Color(0.5, 1.0, 0.55)
const COLOR_FAILED := Color(1.0, 0.45, 0.4)
const COLOR_TITLE := Color(0.85, 0.85, 0.7)

var _battle: BattleController
var _panel: PanelContainer
var _box: VBoxContainer
var _lines: Array[Label] = []  # one per row, in ObjectiveText order
var _titles: Array[Label] = []
var _shape: String = ""


func bind(battle: BattleController) -> void:
	_battle = battle


func _ready() -> void:
	layer = 5
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.position = Vector2(-20.0, 52.0)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.04, 0.05, 0.07, 0.55)
	back.set_corner_radius_all(4)
	back.set_content_margin_all(10.0)
	_panel.add_theme_stylebox_override("panel", back)
	add_child(_panel)
	_box = VBoxContainer.new()
	_panel.add_child(_box)
	visible = false


func _process(_delta: float) -> void:
	var tracker := _battle.objectives() if _battle != null else null
	var shown := tracker != null and _battle.mission != null and not _battle.mission.objectives.is_empty()
	if not shown:
		visible = false
		return
	var rows := ObjectiveText.rows(tracker)
	_rebuild_if_needed(rows)
	for i in rows.size():
		_lines[i].text = "%s %s" % [rows[i].mark, rows[i].text]
		_lines[i].add_theme_color_override("font_color", color_of(rows[i]))
	visible = not _battle.is_ended()  # the result panel lists the same objectives with their final state


## The words currently shown, for tests: group titles and rows in order.
func texts() -> PackedStringArray:
	var out := PackedStringArray()
	for c in _box.get_children():
		out.append((c as Label).text)
	return out


static func color_of(row: ObjectiveText.Row) -> Color:
	match row.state:
		ObjectiveTracker.State.MET:
			return COLOR_MET
		ObjectiveTracker.State.FAILED:
			return COLOR_FAILED
		_:
			return COLOR_HOLDING if row.mark == "[=]" else COLOR_PENDING


func _rebuild_if_needed(rows: Array[ObjectiveText.Row]) -> void:
	var shape := ""
	for r in rows:
		shape += "%d," % r.role
	if shape == _shape:
		return
	_shape = shape
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()
	_lines.clear()
	_titles.clear()
	var last_role := -1
	for r in rows:
		if int(r.role) != last_role:
			last_role = int(r.role)
			var title := _make_label(18)
			title.text = ObjectiveText.role_title(r.role)
			title.add_theme_color_override("font_color", COLOR_TITLE)
			title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			_box.add_child(title)
			_titles.append(title)
		var line := _make_label(20)
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_box.add_child(line)
		_lines.append(line)


func _make_label(font_size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	return l
