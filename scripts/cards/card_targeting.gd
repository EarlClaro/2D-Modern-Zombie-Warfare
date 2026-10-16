class_name CardTargeting
extends RefCounted
## The player's card-selection state, free of any node or pixel: which hand slot is selected, and what a
## placement preview would say about a cell. The HUD and the world preview only *read* this; rules stay in
## BattleController / CardPlayService / PlacementRules.

## What the preview needs to draw for the selected card over `cell` (ground space, tiles).
class Preview:
	extends RefCounted
	var slot: int = -1
	var card: CardDefinition = null
	var cell: Vector2i = Vector2i.ZERO
	var valid: bool = false
	var reason: CardPlayService.Reason = CardPlayService.Reason.EMPTY_SLOT
	var placement: PlacementRules.Reason = PlacementRules.Reason.OK
	## Empty when valid; otherwise why the play would be refused.
	var message: String = ""
	## Ground radius (tiles) of the deployed unit's weapon range / blast; 0 when the card has none.
	var range_tiles: float = 0.0
	var blast_radius: float = 0.0
	## Operations: outer edge of everything the barrage can hurt, and the circle its shells land in.
	var area_radius: float = 0.0
	var scatter_radius: float = 0.0
	## Where the deployed units would stand (ground positions).
	var ground_points: Array[Vector2] = []
	## Sorties: the aircraft's route (entry, station, exit) on the ground.
	var path_points: Array[Vector2] = []

var selected_slot: int = -1
var _selected_id: String = ""


func is_selecting() -> bool:
	return selected_slot >= 0


## Selects the hand slot; selecting the already selected slot deselects it. Returns whether a card is
## selected afterwards. An empty or out-of-range slot changes nothing.
func select(deck: DeckState, slot: int) -> bool:
	var cid := deck.card_at(slot)
	if cid.is_empty():
		return is_selecting()
	if slot == selected_slot:
		cancel()
		return false
	selected_slot = slot
	_selected_id = cid
	return true


func cancel() -> void:
	selected_slot = -1
	_selected_id = ""


## Drops the selection if the selected card is no longer in that slot (played, or the hand changed).
func sync(deck: DeckState) -> void:
	if selected_slot >= 0 and deck.card_at(selected_slot) != _selected_id:
		cancel()


## The preview for the selected card over `cell`, or null when nothing is selected. Never changes state.
func preview(battle: BattleController, cell: Vector2i) -> Preview:
	if not is_selecting() or battle.deck == null:
		return null
	var res := battle.check_card(selected_slot, cell)
	var p := Preview.new()
	p.slot = selected_slot
	p.card = res.card
	p.cell = cell
	p.valid = res.ok
	p.reason = res.reason
	p.placement = res.placement
	p.message = "" if res.ok else message_for(res, battle.deck)
	if res.card != null and res.card.card_kind == CardDefinition.CardKind.OPERATION:
		var op: OperationDefinition = battle.db.operation(res.card.effect_id)
		if op != null:
			p.area_radius = op.reach_radius()
			p.scatter_radius = op.target_radius
			p.blast_radius = op.blast_radius
	if res.card != null and res.card.card_kind == CardDefinition.CardKind.SORTIE:
		var air: UnitDefinition = battle.db.unit(res.card.unit_id)
		var gun: WeaponDefinition = battle.db.weapon(air.weapon_id) if air != null else null
		if gun != null:
			p.range_tiles = gun.range_tiles
		var rockets: WeaponDefinition = battle.db.weapon(air.secondary_weapon_id) if air != null and not air.secondary_weapon_id.is_empty() else null
		if rockets != null:
			p.range_tiles = maxf(p.range_tiles, rockets.range_tiles)
		var centre := IsoProjection.cell_center(cell)
		var route := SortiePlan.plan(float(battle.mission.map.width()), float(battle.mission.map.height()), centre, BattleController.SORTIE_MARGIN)
		p.path_points = [route.entry, route.station, route.exit]
		p.ground_points = [route.station]
	if res.card != null and res.card.card_kind == CardDefinition.CardKind.DEPLOYMENT:
		var unit: UnitDefinition = battle.db.unit(res.card.unit_id)
		var weapon: WeaponDefinition = battle.db.weapon(unit.weapon_id) if unit != null else null
		if weapon != null:
			p.range_tiles = weapon.range_tiles
			p.blast_radius = weapon.blast_radius
		elif unit != null and unit.has_death_blast():
			p.blast_radius = unit.death_blast_radius  # explosive structure: show what it will hit when it goes up
		var centre := IsoProjection.cell_center(cell)
		for off in PlacementRules.formation_offsets(res.card.unit_count):
			p.ground_points.append(centre + off)
	return p


## Short player-facing text for a refused play ("" for a successful one).
static func message_for(result: CardPlayService.Result, deck: DeckState = null) -> String:
	match result.reason:
		CardPlayService.Reason.OK:
			return ""
		CardPlayService.Reason.EMPTY_SLOT:
			return "No card in that slot"
		CardPlayService.Reason.UNKNOWN_CARD:
			return "Unknown card"
		CardPlayService.Reason.LOCKED_OUT:
			var left := deck.lockout_remaining(result.card.id) if deck != null and result.card != null else 0.0
			return "Locked out (%ds)" % ceili(left) if left > 0.0 else "Locked out"
		CardPlayService.Reason.INSUFFICIENT_CP:
			return "Need %d CP" % result.card.cost if result.card != null else "Not enough CP"
		CardPlayService.Reason.INVALID_TARGET:
			return PlacementRules.describe(result.placement)
		CardPlayService.Reason.UNAVAILABLE:
			return "Can't be played right now"
	return "Can't play that"
