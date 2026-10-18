class_name ResultPanel
extends CanvasLayer
## Shown when the mission ends: outcome, reason, a few stats, and a restart button.

var _battle: BattleController
var _root: Control
var _title: Label
var _reason: Label
var _stats: Label
var _note: Label
var _box: VBoxContainer
var _chooser: RewardChooser


func bind(battle: BattleController) -> void:
	_battle = battle
	battle.battle_ended.connect(_on_ended)
	battle.battle_started.connect(_on_started)


func _ready() -> void:
	layer = 10
	_root = CenterContainer.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var panel := PanelContainer.new()
	_root.add_child(panel)
	var box := VBoxContainer.new()
	_box = box
	box.add_theme_constant_override("separation", 14)
	box.custom_minimum_size = Vector2(520, 0)
	panel.add_child(box)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 56)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	_reason = Label.new()
	_reason.add_theme_font_size_override("font_size", 24)
	_reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_reason)
	_stats = Label.new()
	_stats.add_theme_font_size_override("font_size", 20)
	_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_stats)
	_note = Label.new()
	_note.add_theme_font_size_override("font_size", 22)
	_note.add_theme_color_override("font_color", Color(0.75, 0.9, 0.6))
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.visible = false
	box.add_child(_note)
	var button := Button.new()
	button.text = "Restart (R)"
	button.add_theme_font_size_override("font_size", 26)
	button.pressed.connect(func() -> void: _battle.restart())
	box.add_child(button)
	var menu := Button.new()
	menu.text = "Main menu"
	menu.add_theme_font_size_override("font_size", 26)
	menu.pressed.connect(func() -> void: GameSession.go_to_menu(get_tree()))
	box.add_child(menu)
	_root.visible = false


func _on_started() -> void:
	if _root != null:
		_root.visible = false
		_note.visible = false
		_clear_chooser()


## Shows the reward a first win earned: pick one of the offered cards.
func show_offer(db: ContentDb, mission_id: String, offer: PackedStringArray) -> void:
	_clear_chooser()
	_chooser = RewardChooser.new()
	_box.add_child(_chooser)
	_box.move_child(_chooser, _note.get_index() + 1)
	_chooser.setup(db, mission_id, offer)
	_chooser.claimed.connect(func(card_id: String) -> void:
		var card := db.card(card_id)
		var up := db.upgrade(card_id)
		if up != null:
			add_note("Unlocked the upgrade %s." % up.display_name)
		else:
			add_note("Added %s to your collection." % (card.display_name if card != null else card_id))
		_clear_chooser())


func _clear_chooser() -> void:
	if _chooser != null:
		_chooser.queue_free()
		_chooser = null


## A line under the stats (what the win unlocked, whether progress was saved).
func add_note(text: String) -> void:
	if _note != null:
		_note.text = text
		_note.visible = not text.is_empty()


func _on_ended(res: MissionRules.Result) -> void:
	var won := res.status == MissionRules.Status.WON
	_title.text = "VICTORY" if won else "DEFEAT"
	_title.add_theme_color_override("font_color", Color(0.5, 1.0, 0.55) if won else Color(1.0, 0.45, 0.4))
	_reason.text = res.reason
	var s := _battle.stats
	_stats.text = "Kills %d / %d    Shots %d    Units lost %d    Core %d%%" % [
		s["kills"], s["spawned"], s["shots"], s["units_lost"], roundi(_battle.core.health.fraction() * 100.0)]
	_root.visible = true
