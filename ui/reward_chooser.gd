class_name RewardChooser
extends VBoxContainer
## The "pick one of three" reward (docs/specs/progression.md): one button per offered card with its cost and a line of
## what it does. Choosing claims the card in the player's profile (and saves); `claimed` tells the screen around it.
## Used by the result panel after a first win and by mission select for a reward that is still waiting.

signal claimed(card_id: String)

const FLIP_HALF_S: float = 0.14  # a card turns edge-on in this long, then face-up in the same again
const FLIP_STAGGER_S: float = 0.28
const FLIP_START_S: float = 0.25
const STAGE := Vector2(104, 94)

var _db: ContentDb
var _mission_id: String = ""
var _error: Label
var _flips: Array[TextureRect] = []  # the offered cards' pictures, in the order offered
var _faces: Array[Texture2D] = []  # what each one shows once turned over
var _tweens: Array[Tween] = []


func setup(db: ContentDb, mission_id: String, offer: PackedStringArray) -> void:
	_db = db
	_mission_id = mission_id
	for c in get_children():
		c.queue_free()
	add_theme_constant_override("separation", 10)
	add_child(UiKit.label("CHOOSE A REWARD", 26, UiKit.ACCENT))
	_flips.clear()
	_faces.clear()
	for cid in offer:
		var card := db.card(cid)
		var up := db.upgrade(cid)
		var text := ""
		if up != null:
			var base := db.card(up.card_id)
			text = "Upgrade: %s   (%s)\n%s" % [up.display_name, base.display_name if base != null else up.card_id, up.description]
		elif card != null:
			text = "%s   (%d CP)\n%s" % [card.display_name, card.cost, card.description]
		else:
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		add_child(row)
		var face_id := up.card_id if up != null else cid
		var flip := _make_flip(face_id)
		flip.name = "Flip_%s" % cid
		row.add_child(flip)
		var b := UiKit.button(text, 20, Vector2(460, 94))
		b.name = "Reward_%s" % cid
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.pressed.connect(_choose.bind(cid))
		row.add_child(b)
	_error = UiKit.label("", 18, Color(1.0, 0.5, 0.45))
	add_child(_error)
	_start_reveal()


## A picture slot that begins face-down (the card back) and turns over to the card's picture.
func _make_flip(card_id: String) -> TextureRect:
	var tr := TextureRect.new()
	tr.custom_minimum_size = STAGE
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	var face := CardArt.texture(card_id)
	_faces.append(face if face != null else CardArt.back())
	tr.texture = CardArt.back() if face != null else null
	tr.pivot_offset = STAGE * 0.5
	_flips.append(tr)
	return tr


## The cards turn over one after another, left to right in the order offered (a quick squash to edge-on, then back out face-up).
func _start_reveal() -> void:
	for t in _tweens:
		t.kill()
	_tweens.clear()
	if not is_inside_tree():
		finish_reveal()
		return
	for i in _flips.size():
		var tr := _flips[i]
		if tr.texture == null or tr.texture == _faces[i]:
			continue
		var tw := create_tween()
		tw.tween_interval(FLIP_START_S + FLIP_STAGGER_S * float(i))
		tw.tween_property(tr, "scale:x", 0.0, FLIP_HALF_S).set_ease(Tween.EASE_IN)
		tw.tween_callback(func() -> void: tr.texture = _faces[i])
		tw.tween_property(tr, "scale:x", 1.0, FLIP_HALF_S).set_ease(Tween.EASE_OUT)
		_tweens.append(tw)


## Ends the reveal at once: every offered card face-up.
func finish_reveal() -> void:
	for t in _tweens:
		t.kill()
	_tweens.clear()
	for i in _flips.size():
		_flips[i].texture = _faces[i]
		_flips[i].scale = Vector2.ONE


## True when every offered card is face-up.
func revealed() -> bool:
	for i in _flips.size():
		if _flips[i].texture != _faces[i]:
			return false
	return true


## How long the whole reveal takes from the start.
func reveal_total_s() -> float:
	return FLIP_START_S + FLIP_STAGGER_S * float(maxi(_flips.size() - 1, 0)) + FLIP_HALF_S * 2.0


func _choose(card_id: String) -> void:
	if GameSession.claim_reward(_db, _mission_id, card_id):
		claimed.emit(card_id)
	else:
		_error.text = "That reward could not be taken."
