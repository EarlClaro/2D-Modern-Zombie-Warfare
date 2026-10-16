extends SceneTree
## Dev tool (not a test). Screenshots of one cutaway clip at several moments, for eyeballing it.
## Run (NOT headless): godot --path . --resolution 1600x900 --audio-driver Dummy --script tools/cutaway_shots.gd -- --clip=artillery_barrage --out=<dir> [--mission=m2_card_defense]
## Takes frames at 20 %, 34 %, 42 % and 70 % of the clip's full length (the clip is advanced by the tool, not by real time).

var _b: BattleController
var _player: CutawayPlayer
var _clip: String = "artillery_barrage"
var _out: String = ""
var _mission: String = "m2_card_defense"
var _marks: Array[float] = [0.2, 0.34, 0.42, 0.7]
var _index: int = 0
var _frames: int = 0
var _started: bool = false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--clip="):
			_clip = a.substr(7)
		elif a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--mission="):
			_mission = a.substr(10)
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
	if not _started:
		_player = _b.get_node("Cutaways") as CutawayPlayer
		if _player == null:
			push_error("no CutawayPlayer in the battle")
			quit(1)
			return false
		_started = true
		_player.play(_clip)
		_player.set_process(false)  # the tool drives the clip's clock itself
		return false
	if not _player.is_playing():
		quit()
		return false
	# step the clip by hand so each frame lands exactly on its mark
	var length := _player.plan.duration()
	if _index < _marks.size():
		var want := _marks[_index] * length
		var step := want - _player.plan.elapsed()
		if step > 0.0:
			_player.plan.tick(step)
		_player._canvas.queue_redraw()
		await_frame_then_save()
	return false


func await_frame_then_save() -> void:
	_frames += 1
	if _frames % 3 == 0:
		var img := root.get_viewport().get_texture().get_image()
		var path := "%s/%s_%d.png" % [_out, _clip, _index]
		img.save_png(path)
		print("wrote %s" % path)
		_index += 1
		if _index >= _marks.size():
			quit()
