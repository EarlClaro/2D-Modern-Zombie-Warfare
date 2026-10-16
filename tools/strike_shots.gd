extends SceneTree
## Dev tool (not a test). Plays one Operation card on the battlefield and screenshots it at several moments.
## Run (NOT headless): godot --path . --resolution 1600x900 --audio-driver Dummy --script tools/strike_shots.gd -- --card=close_air_support --out=<dir> [--cell=12,10] [--times=0.5,2.4,2.9,3.4]
## The simulation is stepped by the tool (cutaways off), so each frame lands on its time exactly.

var _b: BattleController
var _card: String = "close_air_support"
var _out: String = ""
var _cell := Vector2i(14, 12)
var _times: Array[float] = [0.4, 1.8, 2.5, 3.0]
var _frames: int = 0
var _index: int = 0
var _time: float = 0.0
var _played: bool = false
var _settle: int = 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--card="):
			_card = a.substr(7)
		elif a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--cell="):
			var p := a.substr(7).split(",")
			_cell = Vector2i(int(p[0]), int(p[1]))
		elif a.begins_with("--times="):
			_times.clear()
			for t in a.substr(8).split(","):
				_times.append(float(t))
	if _out.is_empty():
		_out = OS.get_user_data_dir()
	DirAccess.make_dir_recursive_absolute(_out)


func _process(_delta: float) -> bool:
	if _b == null:
		_b = load("res://scenes/battle/battle.tscn").instantiate()
		root.add_child(_b)
		return false
	_frames += 1
	if _frames < 5:
		return false
	if not _played:
		_b.auto_step = false
		(_b.get_node("Cutaways") as CutawayPlayer).plan.enabled = false
		_b.deck.hand = [_card] as Array[String]
		_b.points.cp = 10.0
		var res := _b.play_card(0, _cell)
		print("played %s: ok=%s" % [_card, str(res.ok)])
		_played = true
		return false
	if _index >= _times.size():
		quit()
		return false
	if _time < _times[_index] - 0.0001:
		var step := minf(1.0 / 60.0, _times[_index] - _time)
		_b.step(step)
		_time += step
		return false
	_settle += 1
	if _settle >= 3:  # let the frame render
		_settle = 0
		var img := root.get_viewport().get_texture().get_image()
		var path := "%s/%s_%d.png" % [_out, _card, _index]
		img.save_png(path)
		print("wrote %s at t=%.2f" % [path, _time])
		_index += 1
	return false
