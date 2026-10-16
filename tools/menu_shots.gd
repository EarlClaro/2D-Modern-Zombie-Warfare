extends SceneTree
## Dev tool (not a test). Screenshots of the menu screens for eyeballing them.
## Run (NOT headless): godot --path . --resolution 1600x900 --audio-driver Dummy --script tools/menu_shots.gd -- --out=<dir>
## Writes home.png, select.png, settings.png and pause.png.

var _out: String = ""
var _step: int = 0
var _wait: int = 0
var _menu: Node
var _battle: Node


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	if _out.is_empty():
		_out = OS.get_user_data_dir()
	DirAccess.make_dir_recursive_absolute(_out)


func _save(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [_out, name])
	print("wrote %s/%s.png" % [_out, name])


func _process(_delta: float) -> bool:
	_wait += 1
	if _wait < 6:
		return false
	_wait = 0
	match _step:
		0:
			_menu = load("res://scenes/menu/main_menu.tscn").instantiate()
			root.add_child(_menu)
		1:
			_save("home")
			_menu.call("_open_select")
		2:
			_save("select")
			_menu.call("_close_select")
			_menu.call("_open_settings")
		3:
			_save("settings")
			_menu.queue_free()
			GameSession.pending_mission = "dev_strike_range"
			_battle = load("res://scenes/battle/battle.tscn").instantiate()
			root.add_child(_battle)
		4:
			(_battle.get_node("PauseMenu") as PauseMenu).pause()
		5:
			_save("pause")
			paused = false
			quit()
	_step += 1
	return false
