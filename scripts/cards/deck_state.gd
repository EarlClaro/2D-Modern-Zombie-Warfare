class_name DeckState
extends RefCounted
## Runtime deck for one battle: draw pile, hand, discard, draw timer and per-card lockouts.
## Pure logic: no nodes, time only advances through tick(), all randomness comes from the injected RNG
## (same seed -> same draw order). Card ids are opaque here; legality is DeckRules.validate_deck's job.

var rules: DeckRules
var draw_pile: Array[String] = []  # cards are drawn from the end
var hand: Array[String] = []  # dense: playing a card shifts later cards left
var discard: Array[String] = []
var draw_timer: float = 0.0
var lockouts: Dictionary = {}  # card id -> seconds remaining

const EPS: float = 1e-6  # a 4 s draw or 20 s lockout ticked in small steps must land on time, not one float-error later

var _deck: Array[String]
var _rng: RandomNumberGenerator


func _init(p_rules: DeckRules, card_ids: Array[String], p_rng: RandomNumberGenerator) -> void:
	rules = p_rules
	_deck = card_ids.duplicate()
	_rng = p_rng


## Shuffles the whole deck into the draw pile and draws the opening hand.
func start() -> void:
	draw_pile = _deck.duplicate()
	hand.clear()
	discard.clear()
	lockouts.clear()
	draw_timer = 0.0
	_shuffle(draw_pile)
	for i in rules.initial_hand:
		draw_one()


func total_cards() -> int:
	return draw_pile.size() + hand.size() + discard.size()


## Draws one card into the hand if there is room; reshuffles the discard into the draw pile when the draw
## pile is empty. Returns false (state unchanged) when the hand is full or there is nothing to draw.
func draw_one() -> bool:
	if hand.size() >= rules.hand_cap:
		return false
	if draw_pile.is_empty():
		if discard.is_empty():
			return false
		draw_pile = discard
		discard = []
		_shuffle(draw_pile)
	hand.append(draw_pile.pop_back())
	return true


## Draws up to `count` cards (stops at a full hand or when nothing is left); returns how many were drawn.
func draw(count: int) -> int:
	var drawn := 0
	for i in maxi(count, 0):
		if not draw_one():
			break
		drawn += 1
	return drawn


func tick(delta: float) -> void:
	_tick_lockouts(delta)
	if hand.size() >= rules.hand_cap:
		return  # timer pauses at the cap and resumes from where it was
	draw_timer += maxf(delta, 0.0)
	while draw_timer + EPS >= rules.draw_interval_s:
		if not draw_one():
			draw_timer = rules.draw_interval_s  # nothing to draw (or hand now full): stay ready, don't bank time
			return
		draw_timer = maxf(draw_timer - rules.draw_interval_s, 0.0)
		if hand.size() >= rules.hand_cap:
			return


## Card id in a hand slot, or "" when the slot is empty / out of range.
func card_at(index: int) -> String:
	if index < 0 or index >= hand.size():
		return ""
	return hand[index]


## Moves a hand card to the discard pile and returns its id ("" and no change for an empty slot).
func play_from_hand(index: int) -> String:
	if index < 0 or index >= hand.size():
		return ""
	var cid: String = hand[index]
	hand.remove_at(index)
	discard.append(cid)
	return cid


func start_lockout(card_id: String, seconds: float) -> void:
	if seconds > 0.0:
		lockouts[card_id] = seconds


func lockout_remaining(card_id: String) -> float:
	return float(lockouts.get(card_id, 0.0))


func is_locked(card_id: String) -> bool:
	return lockouts.has(card_id)


func _tick_lockouts(delta: float) -> void:
	for cid in lockouts.keys():
		var left: float = lockouts[cid] - maxf(delta, 0.0)
		if left <= EPS:
			lockouts.erase(cid)
		else:
			lockouts[cid] = left


## Fisher-Yates with the injected RNG (Array.shuffle() would use the global RNG and break determinism).
func _shuffle(arr: Array[String]) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp: String = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
