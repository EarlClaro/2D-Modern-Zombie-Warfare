class_name MainMenu
extends Control
## The start screen and the main scene of the game (docs/specs/menus.md): Play (mission select), Settings, Quit.
## `godot --path . -- --mission=<id>` still goes straight into that mission (scripted runs and the tools rely on it).

var _db: ContentDb
var _home: Control
var _select: MissionSelect
var _settings: SettingsScreen


func _ready() -> void:
	var cli := BattleController.parse_user_args(OS.get_cmdline_user_args())
	if cli.has("mission"):
		GameSession.settings().apply()
		get_tree().call_deferred("change_scene_to_file", GameSession.BATTLE_SCENE)
		return
	GameSession.settings().apply()
	_db = ContentDb.load_from()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UiKit.background())
	_build_home()
	if not _db.is_valid():
		_show_content_errors()


func _build_home() -> void:
	_home = UiKit.centered()
	add_child(_home)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	_home.add_child(box)
	var title := UiKit.label("LAST DEFENSE", 96, UiKit.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := UiKit.label("Hold the line.", 30, UiKit.DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	box.add_child(Control.new())
	var play := UiKit.button("Play", 34, Vector2(420, 72))
	play.pressed.connect(_open_select)
	play.disabled = _db == null or not _db.is_valid()
	box.add_child(play)
	var settings := UiKit.button("Settings", 34, Vector2(420, 72))
	settings.pressed.connect(_open_settings)
	box.add_child(settings)
	var quit := UiKit.button("Quit", 34, Vector2(420, 72))
	quit.pressed.connect(func() -> void: get_tree().quit())
	box.add_child(quit)
	for c in box.get_children():
		if c is Button:
			(c as Button).size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var ver := UiKit.label("%s   |   placeholder title and art" % ProjectSettings.get_setting("application/config/name", "Last Defense"), 16, UiKit.DIM)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(ver)
	if not play.disabled:
		play.grab_focus()


func _open_select() -> void:
	_home.visible = false
	_select = MissionSelect.new()
	_select.bind(_db)
	_select.back.connect(_close_select)
	_select.start_requested.connect(func(id: String) -> void: GameSession.start_battle(get_tree(), id))
	add_child(_select)


func _close_select() -> void:
	if _select != null:
		_select.queue_free()
		_select = null
	_home.visible = true
	_focus_first_button()


func _open_settings() -> void:
	_home.visible = false
	_settings = SettingsScreen.new()
	_settings.closed.connect(_close_settings)
	add_child(_settings)


func _close_settings() -> void:
	if _settings != null:
		_settings.queue_free()
		_settings = null
	_home.visible = true
	_focus_first_button()


func _focus_first_button() -> void:
	for b in _home.find_children("*", "Button", true, false):
		if not (b as Button).disabled:
			(b as Button).grab_focus()
			return


func _show_content_errors() -> void:
	var l := UiKit.label("Content errors:\n" + "\n".join(_db.errors), 20, Color(1.0, 0.5, 0.45))
	l.position = Vector2(30, 30)
	add_child(l)
