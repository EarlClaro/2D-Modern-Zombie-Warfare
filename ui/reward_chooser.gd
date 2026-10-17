class_name RewardChooser
extends VBoxContainer
## The "pick one of three" reward (docs/specs/progression.md): one button per offered card with its cost and a line of
## what it does. Choosing claims the card in the player's profile (and saves); `claimed` tells the screen around it.
## Used by the result panel after a first win and by mission select for a reward that is still waiting.

signal claimed(card_id: String)

var _db: ContentDb
var _mission_id: String = ""
var _error: Label


func setup(db: ContentDb, mission_id: String, offer: PackedStringArray) -> void:
	_db = db
	_mission_id = mission_id
	for c in get_children():
		c.queue_free()
	add_theme_constant_override("separation", 10)
	add_child(UiKit.label("CHOOSE A REWARD", 26, UiKit.ACCENT))
	for cid in offer:
		var card := db.card(cid)
		if card == null:
			continue
		var b := UiKit.button("%s   (%d CP)\n%s" % [card.display_name, card.cost, card.description], 20, Vector2(560, 84))
		b.name = "Reward_%s" % cid
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.pressed.connect(_choose.bind(cid))
		add_child(b)
	_error = UiKit.label("", 18, Color(1.0, 0.5, 0.45))
	add_child(_error)


func _choose(card_id: String) -> void:
	if GameSession.claim_reward(_db, _mission_id, card_id):
		claimed.emit(card_id)
	else:
		_error.text = "That reward could not be taken."
