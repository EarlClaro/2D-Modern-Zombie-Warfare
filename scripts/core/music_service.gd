class_name MusicService
extends Node
## Plays the music from MusicFactory on the "Music" bus (docs/specs/art-gaps.md, G.4). A loop takes about a second to make, so it is
## built on a worker thread the first time it is asked for and kept for the rest of the session (the menu and the battle share it).
## No music in the headless runner (tests, tools). Presentation only.

static var _shared: Dictionary = {}  # track -> AudioStreamWAV, kept across scenes

var _loop: AudioStreamPlayer
var _sting: AudioStreamPlayer
var _wanted: String = ""
var _task: int = -1
var _building: String = ""
var _mutex: Mutex = Mutex.new()
var _result: AudioStreamWAV = null


static func enabled() -> bool:
	return DisplayServer.get_name() != "headless"


func _ready() -> void:
	GameSettings.ensure_music_bus()
	_loop = AudioStreamPlayer.new()
	_loop.bus = "Music"
	add_child(_loop)
	_sting = AudioStreamPlayer.new()
	_sting.bus = "Music"
	add_child(_sting)


func _exit_tree() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)  # never leave a thread running into a freed node
		_task = -1


## Starts looping `track` ("menu" or "battle"); nothing happens when music is off or the track is already playing.
func play(track: String) -> void:
	if not enabled():
		return
	_wanted = track
	if _shared.has(track):
		_start(track)
	elif _task < 0:
		_building = track
		_task = WorkerThreadPool.add_task(_build_job.bind(track))


func stop() -> void:
	_wanted = ""
	if _loop != null:
		_loop.stop()


## A short sting ("victory" or "defeat"); the loop stops while it plays.
func sting(track: String) -> void:
	if not enabled() or _sting == null:
		return
	stop()
	if not _shared.has(track):
		_shared[track] = MusicFactory.build(track)  # short: a fraction of a second
	_sting.stream = _shared[track]
	_sting.play()


func is_playing() -> bool:
	return _loop != null and _loop.playing


func _build_job(track: String) -> void:
	var s := MusicFactory.build(track)
	_mutex.lock()
	_result = s
	_mutex.unlock()


func _process(_delta: float) -> void:
	if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		_mutex.lock()
		var s := _result
		_result = null
		_mutex.unlock()
		if s != null:
			_shared[_building] = s
		if _wanted == _building:
			_start(_building)
		elif not _wanted.is_empty() and not _shared.has(_wanted):
			play(_wanted)


func _start(track: String) -> void:
	if _loop == null or (_loop.playing and _loop.stream == _shared[track]):
		return
	_loop.stream = _shared[track]
	_loop.play()
