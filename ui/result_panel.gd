class_name ResultPanel
extends CanvasLayer
## Shown when the mission ends: outcome, reason, a few stats, and a restart button.

var _battle: BattleController
var _root: Control
var _title: Label
var _reason: Label
var _stats: Label


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


func _on_ended(res: MissionRules.Result) -> void:
	var won := res.status == MissionRules.Status.WON
	_title.text = "VICTORY" if won else "DEFEAT"
	_title.add_theme_color_override("font_color", Color(0.5, 1.0, 0.55) if won else Color(1.0, 0.45, 0.4))
	_reason.text = res.reason
	var s := _battle.stats
	_stats.text = "Kills %d / %d    Shots %d    Units lost %d    Core %d%%" % [
		s["kills"], s["spawned"], s["shots"], s["units_lost"], roundi(_battle.core.health.fraction() * 100.0)]
	_root.visible = true
