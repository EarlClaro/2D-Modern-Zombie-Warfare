class_name PauseMenu
extends CanvasLayer
## The in-battle pause menu (docs/specs/menus.md): Esc pauses the whole scene tree (simulation, card timers, clips),
## and Resume / Restart / Settings / Main menu / Quit are offered. It keeps running while the tree is paused.

var _battle: BattleController
var _root: Control
var _box: VBoxContainer
var _settings: SettingsScreen


func bind(battle: BattleController) -> void:
	_battle = battle
	battle.pause_requested.connect(toggle)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var center := UiKit.centered()
	_root.add_child(center)
	var panel := UiKit.panel()
	center.add_child(panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 14)
	panel.add_child(_box)
	_box.add_child(UiKit.label("PAUSED", 52, UiKit.ACCENT))
	_add("Resume", resume)
	_add("Restart", _restart)
	_add("Settings", _open_settings)
	_add("Main menu", _to_menu)
	_add("Quit", func() -> void: get_tree().quit())


func _add(text: String, handler: Callable) -> void:
	var b := UiKit.button(text, 28, Vector2(380, 60))
	b.pressed.connect(handler)
	_box.add_child(b)


func is_open() -> bool:
	return _root != null and _root.visible


func toggle() -> void:
	if is_open():
		resume()
	else:
		pause()


func pause() -> void:
	if _battle != null and _battle.is_ended():
		return  # the result panel is showing; it has its own buttons
	_root.visible = true
	get_tree().paused = true
	for b in _box.find_children("*", "Button", true, false):
		(b as Button).grab_focus()
		break


func resume() -> void:
	if _settings != null:
		_settings.queue_free()
		_settings = null
	_root.visible = false
	get_tree().paused = false


func _restart() -> void:
	resume()
	_battle.restart()


func _to_menu() -> void:
	GameSession.go_to_menu(get_tree())


func _open_settings() -> void:
	_box.get_parent().get_parent().visible = false  # hide the pause panel behind the settings screen
	_settings = SettingsScreen.new()
	_settings.allow_progress_reset = false
	_settings.closed.connect(_close_settings)
	_root.add_child(_settings)


func _close_settings() -> void:
	if _settings != null:
		_settings.queue_free()
		_settings = null
	_box.get_parent().get_parent().visible = true


func _unhandled_input(event: InputEvent) -> void:
	if is_open() and _settings == null and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		resume()
