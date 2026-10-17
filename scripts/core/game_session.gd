class_name GameSession
extends RefCounted
## What survives a change of scene without an autoload: the loaded settings and the mission the menu picked
## (docs/specs/menus.md). Static state only; the battle reads it once when it starts and never writes rules from it.

const MENU_SCENE: String = "res://scenes/menu/main_menu.tscn"
const BATTLE_SCENE: String = "res://scenes/battle/battle.tscn"

static var _settings: GameSettings = null
## The mission the menu chose for the next battle ("" = none, the battle uses its own default) and its seed (0 = default).
static var pending_mission: String = ""
static var pending_seed: int = 0
## The difficulty picked in mission select for that battle ("" = the mission's own).
static var pending_difficulty: String = ""


## The shared settings, loaded from disk on first use.
static func settings() -> GameSettings:
	if _settings == null:
		_settings = GameSettings.load_from()
	return _settings


## Replaces the shared settings (tests, and "reset to defaults").
static func set_settings(s: GameSettings) -> void:
	_settings = s


## Hands the chosen mission to the battle and forgets it, so a later plain launch uses the default again.
static func take_pending() -> Dictionary:
	var out := {"mission": pending_mission, "seed": pending_seed, "difficulty": pending_difficulty}
	pending_mission = ""
	pending_seed = 0
	pending_difficulty = ""
	return out


## Hands the mission and the chosen difficulty to the next battle and remembers the mission as the last one played;
## `persist` false skips writing the settings file (tests).
static func prepare_battle(mission_id: String, persist: bool = true) -> void:
	pending_mission = mission_id
	var s := settings()
	pending_difficulty = s.difficulty
	s.last_mission = mission_id
	if persist:
		s.save()


static func start_battle(tree: SceneTree, mission_id: String) -> void:
	prepare_battle(mission_id)
	tree.paused = false
	tree.change_scene_to_file(BATTLE_SCENE)


static func go_to_menu(tree: SceneTree) -> void:
	tree.paused = false
	tree.change_scene_to_file(MENU_SCENE)
