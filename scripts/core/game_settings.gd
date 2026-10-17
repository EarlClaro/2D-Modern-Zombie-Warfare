class_name GameSettings
extends RefCounted
## The player's options (docs/specs/menus.md): plain data with defaults, clamping and a ConfigFile round trip.
## Storing is separate from applying: `apply()` touches the audio bus and the window, everything else is testable
## without a window. A missing, unreadable or hand-edited file never crashes; bad values fall back to defaults.

const PATH: String = "user://settings.cfg"
const SECTION: String = "game"
const MIN_DB: float = -40.0  # below this the master bus is muted instead

var master_volume: float = 0.8  # 0..1
var fullscreen: bool = false
var cutaways: bool = true  # the freezing strike clips
var show_fps: bool = true
var last_mission: String = ""  # pre-selected in mission select
var difficulty: String = "normal"  # the level mission select shows (a DifficultyDefinition id; unknown ids fall back to normal there)


## Brings every value into its legal range (a hand-edited file can hold anything).
func clamp_all() -> void:
	master_volume = clampf(master_volume, 0.0, 1.0) if is_finite(master_volume) else 0.8
	last_mission = last_mission.strip_edges()
	difficulty = difficulty.strip_edges().to_lower()
	if difficulty.is_empty():
		difficulty = "normal"


func reset() -> void:
	var d := GameSettings.new()
	master_volume = d.master_volume
	fullscreen = d.fullscreen
	cutaways = d.cutaways
	show_fps = d.show_fps
	last_mission = d.last_mission
	difficulty = d.difficulty


func to_config() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, "master_volume", master_volume)
	cfg.set_value(SECTION, "fullscreen", fullscreen)
	cfg.set_value(SECTION, "cutaways", cutaways)
	cfg.set_value(SECTION, "show_fps", show_fps)
	cfg.set_value(SECTION, "last_mission", last_mission)
	cfg.set_value(SECTION, "difficulty", difficulty)
	return cfg


## Reads the values it understands and ignores (keeps the default for) anything missing or of the wrong type.
func from_config(cfg: ConfigFile) -> void:
	var v: Variant = cfg.get_value(SECTION, "master_volume", master_volume)
	if v is float or v is int:
		master_volume = float(v)
	v = cfg.get_value(SECTION, "fullscreen", fullscreen)
	if v is bool:
		fullscreen = v
	v = cfg.get_value(SECTION, "cutaways", cutaways)
	if v is bool:
		cutaways = v
	v = cfg.get_value(SECTION, "show_fps", show_fps)
	if v is bool:
		show_fps = v
	v = cfg.get_value(SECTION, "last_mission", last_mission)
	if v is String:
		last_mission = v
	v = cfg.get_value(SECTION, "difficulty", difficulty)
	if v is String:
		difficulty = v
	clamp_all()


func save(path: String = PATH) -> bool:
	clamp_all()
	return to_config().save(path) == OK


## Loads `path`; a missing or corrupt file gives the defaults.
static func load_from(path: String = PATH) -> GameSettings:
	var s := GameSettings.new()
	if not FileAccess.file_exists(path):
		return s
	var text := FileAccess.get_file_as_string(path)
	if not looks_like_config(text):
		return s  # parsing garbage would only make the engine log errors
	var cfg := ConfigFile.new()
	if cfg.parse(text) == OK:
		s.from_config(cfg)
	return s


## Cheap check that every line is blank, a comment, a [section] or key=value, so ConfigFile never sees garbage.
static func looks_like_config(text: String) -> bool:
	for raw in text.split("\n"):
		var line := raw.strip_edges()
		if line.is_empty() or line.begins_with(";") or line.begins_with("#"):
			continue
		if line.begins_with("[") and line.ends_with("]") and line.count("[") == 1:
			continue
		var eq := line.find("=")
		if eq > 0 and line.substr(0, eq).strip_edges().is_valid_identifier() and not line.substr(eq + 1).strip_edges().is_empty():
			continue
		return false
	return true


## The master bus level for a 0..1 volume: a gentle curve (volume squared) in dB, muted at 0.
static func volume_to_db(volume: float) -> float:
	var v := clampf(volume, 0.0, 1.0)
	if v <= 0.001:
		return -80.0
	return maxf(linear_to_db(v * v), MIN_DB)


## Pushes the settings into the engine: master volume and window mode. Safe to call repeatedly and when headless.
func apply() -> void:
	var bus := AudioServer.get_bus_index("Master")
	if bus >= 0:
		AudioServer.set_bus_volume_db(bus, volume_to_db(master_volume))
		AudioServer.set_bus_mute(bus, master_volume <= 0.001)
	if DisplayServer.get_name() != "headless":
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)
