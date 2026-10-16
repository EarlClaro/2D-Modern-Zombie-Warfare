class_name SettingsScreen
extends Control
## The options screen (docs/specs/menus.md): master volume, fullscreen, strike clips, FPS counter, reset. Values are
## applied the moment they change and saved when the screen closes. Used by the main menu and the pause menu.

signal closed

var _s: GameSettings
var _volume: HSlider
var _volume_label: Label
var _fullscreen: CheckButton
var _cutaways: CheckButton
var _fps: CheckButton
var _syncing: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := UiKit.centered()
	add_child(center)
	var panel := UiKit.panel()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	box.custom_minimum_size = Vector2(640, 0)
	panel.add_child(box)
	box.add_child(UiKit.label("SETTINGS", 44, UiKit.ACCENT))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	row.add_child(UiKit.label("Master volume", 26))
	_volume = HSlider.new()
	_volume.min_value = 0.0
	_volume.max_value = 100.0
	_volume.step = 5.0
	_volume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_volume.custom_minimum_size = Vector2(240, 36)
	_volume.value_changed.connect(_on_volume)
	row.add_child(_volume)
	_volume_label = UiKit.label("", 26, UiKit.DIM)
	_volume_label.custom_minimum_size = Vector2(70, 0)
	row.add_child(_volume_label)
	_fullscreen = _toggle(box, "Fullscreen", _on_fullscreen)
	_cutaways = _toggle(box, "Strike cutaway clips (freeze the game briefly)", _on_cutaways)
	_fps = _toggle(box, "Show FPS counter", _on_fps)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	box.add_child(buttons)
	var reset := UiKit.button("Reset to defaults", 24, Vector2(260, 56))
	reset.pressed.connect(_on_reset)
	buttons.add_child(reset)
	var back := UiKit.button("Back", 24, Vector2(260, 56))
	back.pressed.connect(close)
	buttons.add_child(back)
	box.add_child(UiKit.label("Esc: back", 18, UiKit.DIM))
	_s = GameSession.settings()
	_refresh()
	back.grab_focus()


func _toggle(parent: Control, text: String, handler: Callable) -> CheckButton:
	var c := CheckButton.new()
	c.text = text
	c.add_theme_font_size_override("font_size", 26)
	c.add_theme_color_override("font_color", UiKit.TEXT)
	c.toggled.connect(handler)
	parent.add_child(c)
	return c


## Shows the current settings in the controls without firing their handlers.
func _refresh() -> void:
	_syncing = true
	_volume.value = roundf(_s.master_volume * 100.0)
	_volume_label.text = "%d%%" % int(_volume.value)
	_fullscreen.button_pressed = _s.fullscreen
	_cutaways.button_pressed = _s.cutaways
	_fps.button_pressed = _s.show_fps
	_syncing = false


func _on_volume(v: float) -> void:
	_volume_label.text = "%d%%" % int(v)
	if _syncing:
		return
	_s.master_volume = v / 100.0
	_s.apply()


func _on_fullscreen(on: bool) -> void:
	if _syncing:
		return
	_s.fullscreen = on
	_s.apply()


func _on_cutaways(on: bool) -> void:
	if not _syncing:
		_s.cutaways = on


func _on_fps(on: bool) -> void:
	if not _syncing:
		_s.show_fps = on


func _on_reset() -> void:
	var keep := _s.last_mission
	_s.reset()
	_s.last_mission = keep
	_s.apply()
	_refresh()


func close() -> void:
	_s.save()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
