class_name GameSession
extends RefCounted
## What survives a change of scene without an autoload: the loaded settings and the mission the menu picked
## (docs/specs/menus.md). Static state only; the battle reads it once when it starts and never writes rules from it.

const MENU_SCENE: String = "res://scenes/menu/main_menu.tscn"
const BATTLE_SCENE: String = "res://scenes/battle/battle.tscn"

static var _settings: GameSettings = null
static var _profile: PlayerProfile = null
## Where the profile lives; tests point it at a temporary file.
static var profile_path: String = ProfileStore.PATH
## What loading the profile found (a ProfileStore.Status); the main menu shows `ProfileStore.note_for` of it.
static var profile_load: ProfileStore.LoadResult = null
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


## The player's profile (docs/specs/progression.md), loaded from disk on first use with the content in `db` (a database is
## loaded for the purpose when none is given). Loading never fails: the worst case is a fresh profile.
static func profile(db: ContentDb = null) -> PlayerProfile:
	if _profile == null:
		var content := db if db != null else ContentDb.load_from()
		profile_load = ProfileStore.load_from(content, profile_path)
		_profile = profile_load.profile
	return _profile


## Replaces the shared profile (tests, and "reset progress").
static func set_profile(p: PlayerProfile) -> void:
	_profile = p


## Starts the player's progress over: a new profile with a new reward seed, saved at once (the old file stays as the
## backup). Returns false if it could not be written.
static func reset_profile(db: ContentDb = null) -> bool:
	var content := db if db != null else ContentDb.load_from()
	_profile = PlayerProfile.new_game(content, ProfileStore.random_seed())
	profile_load = null
	return ProfileStore.save(_profile, profile_path)


## The cards waiting on a mission's reward: the saved offer, or one worked out again when none was saved (empty when
## nothing is waiting).
static func pending_offer(db: ContentDb, mission_id: String) -> PackedStringArray:
	var p := profile(db)
	if not p.has_pending_reward(mission_id):
		return PackedStringArray()
	var saved := p.offer_of(mission_id)
	if not saved.is_empty():
		return saved
	return p.offer_for(db, mission_id)


## Takes `card_id` as the reward of `mission_id` and saves. False if it was not on offer or the reward is not waiting.
static func claim_reward(db: ContentDb, mission_id: String, card_id: String) -> bool:
	var p := profile(db)
	if p.read_only or not p.has_pending_reward(mission_id) or not pending_offer(db, mission_id).has(card_id):
		return false
	if not p.take_reward(mission_id, card_id, db):
		return false
	save_profile()
	return true


## Writes the shared profile; false when there is none loaded, it is read-only, or the disk refused.
static func save_profile() -> bool:
	return _profile != null and ProfileStore.save(_profile, profile_path)


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
