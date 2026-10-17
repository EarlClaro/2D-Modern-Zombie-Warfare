class_name ProgressRecorder
extends Node
## Writes a won battle into the player's profile (docs/specs/progression.md). Added to the battle only when the menu
## started it: a mission launched from the command line (tools, bots, scripted runs) never touches the player's file.
## The battle itself knows nothing about this; it only emits `battle_ended`.

## Emitted after a win has been recorded; `unlocked` is the id of the mission it opened ("" if none) and
## `note` a line for the result panel.
signal recorded(unlocked: String, note: String)
## Emitted after `recorded` when the win earned a reward: the mission and the cards on offer.
signal offer_ready(mission_id: String, offer: PackedStringArray)

var _battle: BattleController
var persist: bool = true  # tests turn the disk write off


func bind(battle: BattleController) -> void:
	_battle = battle
	battle.battle_ended.connect(_on_ended)


func _on_ended(res: MissionRules.Result) -> void:
	if res.status != MissionRules.Status.WON or _battle.mission == null:
		return
	var level := _battle.difficulty()
	var core := _battle.core.health.fraction()
	var note := record(GameSession.profile(_battle.db), _battle.db, _battle.mission.id, core,
		level.id if level != null else ContentDb.NORMAL_DIFFICULTY, level.enemy_count_mult if level != null else 1.0)
	if persist:
		GameSession.save_profile()
	var unlocked := String(note.get("unlocked", ""))
	recorded.emit(unlocked, String(note.get("text", "")))
	var offer: PackedStringArray = note.get("offer", PackedStringArray())
	if not offer.is_empty():
		offer_ready.emit(_battle.mission.id, offer)


## Records a win in `profile` and says what changed: {"unlocked": id or "", "text": line for the player, "offer": the
## cards of a new reward (empty when the win earned none)}.
static func record(profile: PlayerProfile, db: ContentDb, mission_id: String, core_fraction: float, difficulty_id: String, scale: float) -> Dictionary:
	if profile.read_only:
		return {"unlocked": "", "text": "Progress is not saved (the save file comes from a newer game).", "offer": PackedStringArray()}
	profile.record_win(mission_id, core_fraction, difficulty_id, scale)
	var camp := db.main_campaign()
	var unlocked := camp.unlocked_by(profile, mission_id) if camp != null else ""
	var text := "Progress saved."
	if profile.wins_of(mission_id) == 1 and not unlocked.is_empty():
		var m := db.mission(unlocked)
		text = "Unlocked: %s" % (m.display_name if m != null else unlocked)
	else:
		unlocked = ""
	var offer := PackedStringArray()
	var camp2 := db.main_campaign()
	if camp2 != null and profile.wins_of(mission_id) == 1 and not profile.rewards.has(mission_id):
		offer = profile.offer_for(db, mission_id)
		if not offer.is_empty():
			profile.open_reward(mission_id, offer)
	return {"unlocked": unlocked, "text": text, "offer": offer}
