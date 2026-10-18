extends SceneTree
## Dev tool (not a test). Screenshots of the card hand (docs/specs/card-loop.md "Card faces"), one image per hand of five cards.
## Run (NOT headless): godot --path . --resolution 1920x1080 --audio-driver Dummy --script tools/card_shots.gd -- --out=<dir> [--hand=a,b,c,d,e ...]
## Writes hand_a.png, hand_b.png, ...; `--hand=id,id,id,id,id` (repeatable) replaces the two default hands.

const HANDS: Array = [
	["rifle_squad", "gatling_gun", "tank", "artillery_strike", "helicopter_support"],
	["sandbags", "minefield", "supply_drop", "combat_drones", "rpg_team"],
]

var _out: String = ""
var _step: int = 0
var _wait: int = 0
var _battle: Node
var _stepped: bool = false
var _hands: Array = HANDS.duplicate()
var _modes: Array[String] = ["hand"]
var _crops: Array[Image] = []


func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var custom: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--hand="):
			custom.append(a.substr(7).split(","))
	if not custom.is_empty():
		_hands = custom
	if _out.is_empty():
		_out = OS.get_user_data_dir()
	DirAccess.make_dir_recursive_absolute(_out)


func _process(_delta: float) -> bool:
	_wait += 1
	if _wait < 8:
		return false
	_wait = 0
	var n := _modes.size()
	var shot := _step / n
	if shot >= _hands.size():
		_finish()
		return false
	if _battle == null:
		GameSession.pending_mission = "m2_card_defense"
		_battle = load("res://scenes/battle/battle.tscn").instantiate()
		_battle.set("deck_override", PackedStringArray(_hands[shot]))
		root.add_child(_battle)
		return false
	_battle.get("points").cp = 10.0  # every card affordable
	if not _stepped:
		_battle.call("step", 4.5)  # one draw interval: the fifth card arrives
		_stepped = true
		_wait = 3  # redraw first
		return false
	_stepped = false
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	var r := HandUi.capture_rect()
	var top := HandUi.HAND_TOP - 18.0
	var h := HandUi.SLOT_SIZE.y + 66.0
	var k := img.get_width() / 1920.0  # the window is a little smaller than the base resolution
	var crop := img.get_region(Rect2i(Vector2i(int((r.position.x - 4.0) * k), int(top * k)), Vector2i(int((r.size.x + 8.0) * k), int(h * k))))
	crop.resize(int(r.size.x + 8.0), int(h), Image.INTERPOLATE_BILINEAR)
	_crops.append(crop)
	_battle.queue_free()
	_battle = null
	_step += 1
	return false


func _finish() -> void:
	var n := _modes.size()
	for hand in _hands.size():
		var wide := 0
		var tall := 12 * (n - 1)
		for m in n:
			wide = maxi(wide, _crops[hand * n + m].get_width())
			tall += _crops[hand * n + m].get_height()
		var out := Image.create(wide, tall, false, Image.FORMAT_RGBA8)
		out.fill(Color(0.02, 0.02, 0.03))
		var y := 0
		for m in n:
			var c := _crops[hand * n + m]
			out.blit_rect(c, Rect2i(Vector2i.ZERO, c.get_size()), Vector2i((wide - c.get_width()) / 2, y))
			y += c.get_height() + 12
		var path := "%s/hand_%s.png" % [_out, "abcdefghij"[hand]]
		out.save_png(path)
		print("wrote ", path)
	quit()
