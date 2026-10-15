class_name SfxService
extends Node
## Plays the generated sound effects through a fixed pool of AudioStreamPlayers, with voice limits and
## priorities decided by SfxVoicePool. Pitch jitter is cosmetic (non-seeded) and never affects rules.

const POOL_SIZE: int = 12

var _library: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _pool: SfxVoicePool = SfxVoicePool.new(POOL_SIZE)
var _unknown_warned: Dictionary = {}


func _init() -> void:
	_library = SfxFactory.build_library()


func _ready() -> void:
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


## Plays `sound` (a key of SfxFactory.ALL_SOUNDS). Returns true if a voice was used, false if dropped.
func play(sound: String, pitch_jitter: float = 0.08) -> bool:
	if _players.is_empty():
		return false  # not in the tree yet
	if not _library.has(sound):
		if not _unknown_warned.has(sound):
			_unknown_warned[sound] = true
			push_warning("SfxService: unknown sound '%s'" % sound)
		return false
	var settings: Dictionary = SfxFactory.SETTINGS[sound]
	var stream: AudioStreamWAV = _library[sound]
	var voice := _pool.request(settings["category"], Time.get_ticks_msec() / 1000.0, stream.get_length())
	if voice == -1:
		return false
	var player := _players[voice]
	player.stream = stream
	player.volume_db = settings["volume_db"]
	player.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	player.play()
	return true
