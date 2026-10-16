extends SceneTree
## Dev tool (not a test). Screenshots of a mission's map from chosen camera views, for eyeballing the look.
## Run (NOT headless): godot --path . --resolution 1600x900 --audio-driver Dummy --script tools/shots.gd -- --mission=x2_outskirts --out=<dir> --view=12,38,1.5 --view=32,24,0.5
## A view is `ground_x,ground_y,zoom`. Time of day and weather come from the mission (`--time=0.5` overrides the time).

var _b: BattleController
var _views: Array[Vector3] = []
var _out: String = ""
var _mission_id: String = "x2_outskirts"
var _time: float = -1.0
var _index: int = -1
var _frames: int = 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--mission="):
			_mission_id = a.substr(10)
		elif a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--time="):
			_time = float(a.substr(7))
		elif a.begins_with("--view="):
			var p := a.substr(7).split(",")
			if p.size() == 3:
				_views.append(Vector3(float(p[0]), float(p[1]), float(p[2])))
	if _views.is_empty():
		_views.append(Vector3(32.0, 24.0, 0.6))
	if _out.is_empty():
		_out = OS.get_user_data_dir()
	DirAccess.make_dir_recursive_absolute(_out)


func _process(_delta: float) -> bool:
	if _b == null:
		var db := ContentDb.load_from()
		var mission := db.mission(_mission_id)
		if mission == null:
			push_error("unknown mission %s" % _mission_id)
			quit(1)
			return false
		if _time >= 0.0:
			mission = mission.duplicate()
			mission.time_of_day = _time
			mission.day_length_s = 0.0
		_b = load("res://scenes/battle/battle.tscn").instantiate()
		root.add_child(_b)
		_b.setup(db, mission, 1)
		_b.auto_step = false
		_next_view()
		return false
	var v := _views[_index]
	var cam := _b.camera_node()
	cam.zoom = Vector2(v.z, v.z)
	cam.position = IsoProjection.ground_to_screen(Vector2(v.x, v.y))
	_frames += 1
	if _frames == 12:
		var img := root.get_viewport().get_texture().get_image()
		var path := "%s/%s_%d.png" % [_out, _mission_id, _index]
		img.save_png(path)
		print("wrote %s (%dx%d)" % [path, img.get_width(), img.get_height()])
		_next_view()
	return false


func _next_view() -> void:
	_index += 1
	_frames = 0
	if _index >= _views.size():
		quit()
