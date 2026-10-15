class_name BattleHud
extends CanvasLayer
## Read-only presentation of battle state. Never changes rules.

var _battle: BattleController
var _core_bar: ProgressBar
var _core_label: Label
var _time_label: Label
var _info_label: Label
var _hint_label: Label
var _fps_label: Label
var _cards_label: Label  # interim text readout (2.2); replaced by the real hand UI in 2.3


func bind(battle: BattleController) -> void:
	_battle = battle


func _ready() -> void:
	layer = 5
	var box := VBoxContainer.new()
	box.position = Vector2(20, 16)
	add_child(box)
	_core_label = _make_label(box, 24)
	_core_bar = ProgressBar.new()
	_core_bar.custom_minimum_size = Vector2(360, 22)
	_core_bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.35, 0.85, 0.45)
	fill.set_corner_radius_all(3)
	_core_bar.add_theme_stylebox_override("fill", fill)
	box.add_child(_core_bar)
	_time_label = _make_label(box, 24)
	_info_label = _make_label(box, 20)
	_hint_label = Label.new()
	_hint_label.text = "1-5: play card at cursor   |   LMB: move soldier   |   WASD / MMB: pan   |   wheel: zoom   |   R: restart"
	_hint_label.add_theme_font_size_override("font_size", 18)
	_hint_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_hint_label.add_theme_constant_override("outline_size", 5)
	_hint_label.position = Vector2(20, 1040)
	add_child(_hint_label)
	_cards_label = Label.new()
	_cards_label.add_theme_font_size_override("font_size", 20)
	_cards_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_cards_label.add_theme_constant_override("outline_size", 6)
	_cards_label.position = Vector2(20, 960)
	add_child(_cards_label)
	_fps_label = Label.new()
	_fps_label.add_theme_font_size_override("font_size", 18)
	_fps_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_fps_label.add_theme_constant_override("outline_size", 5)
	_fps_label.position = Vector2(1780, 16)
	add_child(_fps_label)


func _process(_delta: float) -> void:
	if _fps_label != null:
		_fps_label.text = "FPS %d" % Engine.get_frames_per_second()
	if _battle == null or _battle.core == null:
		return
	_update_cards_label()
	var hp := _battle.core.health
	_core_label.text = "CORE  %d / %d" % [ceili(hp.hp), int(hp.max_hp)]
	_core_bar.value = hp.fraction() * 100.0
	var t := ceili(_battle.time_left())
	_time_label.text = "HOLD:  %d:%02d" % [t / 60, t % 60]
	_info_label.text = "Enemies %d    Kills %d    Units %d" % [_battle.enemy_count(), _battle.stats["kills"], _battle.units.size()]


func _update_cards_label() -> void:
	if not _battle.has_cards():
		_cards_label.text = ""
		return
	var parts: PackedStringArray = []
	for i in _battle.deck.hand.size():
		var def: CardDefinition = _battle.cards_by_id().get(_battle.deck.hand[i])
		var card_name := def.display_name if def != null else "?"
		var cost := def.cost if def != null else 0
		var lock := _battle.deck.lockout_remaining(_battle.deck.hand[i])
		parts.append("[%d] %s (%d)%s" % [i + 1, card_name, cost, " %ds" % ceili(lock) if lock > 0.0 else ""])
	_cards_label.text = "CP %d/%d    draw %d  discard %d\n%s" % [
		_battle.points.whole(), int(_battle.points.cap), _battle.deck.draw_pile.size(), _battle.deck.discard.size(), "   ".join(parts)]


func _make_label(parent: Control, font_size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	parent.add_child(l)
	return l
