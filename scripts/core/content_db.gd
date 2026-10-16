class_name ContentDb
extends RefCounted
## Loads and holds all definitions by stable id. Invalid definitions are reported in `errors` and are
## NOT registered, so they can never reach a battle. Unknown ids resolve to null (callers must check)
## and cross-references are verified by `validate_references()`.

var weapons: Dictionary = {}  # id -> WeaponDefinition
var units: Dictionary = {}  # id -> UnitDefinition
var enemies: Dictionary = {}  # id -> EnemyDefinition
var maps: Dictionary = {}  # id -> MapDefinition
var missions: Dictionary = {}  # id -> MissionDefinition
var cards: Dictionary = {}  # id -> CardDefinition
var decks: Dictionary = {}  # id -> DeckDefinition
var operations: Dictionary = {}  # id -> OperationDefinition (battle effects of Operation cards)
var effects: Dictionary = {}  # id -> StateEffectDefinition (battle effects of Order / Supply / Deck / Doctrine cards)
var scenery_defs: Dictionary = {}  # id -> SceneryDefinition (decorations placed by maps)
var deck_rules: DeckRules  # data/config/deck_rules.tres; null if missing/invalid (reported in errors)
var errors: PackedStringArray = PackedStringArray()


## Loads data/{weapons,units,enemies,maps,missions,cards,decks,operations,effects} and data/config/deck_rules.tres under `root`, then verifies cross-references.
static func load_from(root: String = "res://data") -> ContentDb:
	var db := ContentDb.new()
	db._load_dir(root + "/weapons", "weapon")
	db._load_dir(root + "/units", "unit")
	db._load_dir(root + "/enemies", "enemy")
	db._load_dir(root + "/maps", "map")
	db._load_dir(root + "/missions", "mission")
	db._load_dir(root + "/cards", "card")
	db._load_dir(root + "/decks", "deck")
	db._load_dir(root + "/operations", "operation")
	db._load_dir(root + "/effects", "effect")
	db._load_dir(root + "/scenery", "scenery", false)
	db._load_deck_rules(root + "/config/deck_rules.tres")
	db.validate_references()
	return db


func is_valid() -> bool:
	return errors.is_empty()


func weapon(id: String) -> WeaponDefinition:
	return weapons.get(id)


func unit(id: String) -> UnitDefinition:
	return units.get(id)


func enemy(id: String) -> EnemyDefinition:
	return enemies.get(id)


func map(id: String) -> MapDefinition:
	return maps.get(id)


func mission(id: String) -> MissionDefinition:
	return missions.get(id)


func card(id: String) -> CardDefinition:
	return cards.get(id)


func deck(id: String) -> DeckDefinition:
	return decks.get(id)


func operation(id: String) -> OperationDefinition:
	return operations.get(id)


func effect(id: String) -> StateEffectDefinition:
	return effects.get(id)


func scenery(id: String) -> SceneryDefinition:
	return scenery_defs.get(id)


func add_scenery(def: SceneryDefinition) -> bool:
	return _register(scenery_defs, def)


func add_operation(def: OperationDefinition) -> bool:
	return _register(operations, def)


func add_effect(def: StateEffectDefinition) -> bool:
	return _register(effects, def)


func add_card(def: CardDefinition) -> bool:
	return _register(cards, def)


func add_deck(def: DeckDefinition) -> bool:
	return _register(decks, def)


func add_weapon(def: WeaponDefinition) -> bool:
	return _register(weapons, def)


func add_unit(def: UnitDefinition) -> bool:
	return _register(units, def)


func add_enemy(def: EnemyDefinition) -> bool:
	return _register(enemies, def)


func add_map(def: MapDefinition) -> bool:
	return _register(maps, def)


func add_mission(def: MissionDefinition) -> bool:
	return _register(missions, def)


## Adds an error for every reference to an id that is not registered.
func validate_references() -> void:
	for id in units:
		var u: UnitDefinition = units[id]
		if not u.weapon_id.is_empty() and not weapons.has(u.weapon_id):
			errors.append("unit '%s': unknown weapon_id '%s'" % [id, u.weapon_id])
		if not u.secondary_weapon_id.is_empty() and not weapons.has(u.secondary_weapon_id):
			errors.append("unit '%s': unknown secondary_weapon_id '%s'" % [id, u.secondary_weapon_id])
	for id in missions:
		var m: MissionDefinition = missions[id]
		for su in m.start_units:
			if su != null and not su.unit_id.is_empty() and not units.has(su.unit_id):
				errors.append("mission '%s': start unit references unknown unit_id '%s'" % [id, su.unit_id])
		for w in m.waves:
			if w != null and not w.enemy_id.is_empty() and not enemies.has(w.enemy_id):
				errors.append("mission '%s': wave references unknown enemy_id '%s'" % [id, w.enemy_id])
		if not m.core_scenery_id.is_empty() and not scenery_defs.has(m.core_scenery_id):
			errors.append("mission '%s': unknown core_scenery_id '%s'" % [id, m.core_scenery_id])
		if not m.deck_id.is_empty() and not decks.has(m.deck_id):
			errors.append("mission '%s': unknown deck_id '%s'" % [id, m.deck_id])
		for did in m.doctrines:
			var dc: CardDefinition = cards.get(did)
			if dc == null:
				errors.append("mission '%s': unknown doctrine card '%s'" % [id, did])
			elif dc.card_kind != CardDefinition.CardKind.DOCTRINE:
				errors.append("mission '%s': doctrine '%s' is not a doctrine card" % [id, did])
	for eid in effects:
		for wid in (effects[eid] as StateEffectDefinition).weapon_ids:
			if not weapons.has(wid):
				errors.append("effect '%s': unknown weapon id '%s'" % [eid, wid])
	_validate_card_units()
	_validate_decks()
	_validate_scenery()


## Every map's decorations must use known ids, fit on the map and not overlap; no mission may route enemies
## through a decoration or put its core, spawns or start units under one.
func _validate_scenery() -> void:
	var cells_by_map: Dictionary = {}  # map id -> {cell: true}
	for mid in maps:
		var m: MapDefinition = maps[mid]
		var taken: Dictionary = {}
		for p in m.placements():
			var def: SceneryDefinition = scenery_defs.get(p.scenery_id)
			if def == null:
				errors.append("map '%s': unknown scenery id '%s'" % [mid, p.scenery_id])
				continue
			for c in def.cells_at(p.cell):
				if not m.in_bounds(c):
					errors.append("map '%s': scenery '%s' at (%d, %d) does not fit on the map" % [mid, p.scenery_id, p.cell.x, p.cell.y])
					break
				if taken.has(c):
					errors.append("map '%s': scenery '%s' at (%d, %d) overlaps another piece at (%d, %d)" % [mid, p.scenery_id, p.cell.x, p.cell.y, c.x, c.y])
					break
				taken[c] = true
		cells_by_map[mid] = taken
	for id in missions:
		var mission: MissionDefinition = missions[id]
		if mission.map == null or not cells_by_map.has(mission.map.id):
			continue
		var taken: Dictionary = cells_by_map[mission.map.id]
		var special: Array[Vector2i] = [mission.core_cell]
		special.append_array(mission.spawn_cells)
		for su in mission.start_units:
			if su != null:
				special.append(su.cell)
		for c in special:
			if taken.has(c):
				errors.append("mission '%s': (%d, %d) is covered by scenery" % [id, c.x, c.y])
		for s in mission.spawn_cells:
			var from := IsoProjection.cell_center(s)
			for pc in mission.path_cells:
				var to := IsoProjection.cell_center(pc)
				var n := maxi(1, ceili(from.distance_to(to) / 0.2))
				for i in n + 1:
					var cell := IsoProjection.cell_of(from.lerp(to, float(i) / n))
					if taken.has(cell):
						errors.append("mission '%s': the enemy path from spawn (%d, %d) crosses scenery at (%d, %d)" % [id, s.x, s.y, cell.x, cell.y])
						break
				from = to


## Cards must point at real units of the right kind: deployments are ground units, sorties are aircraft.
func _validate_card_units() -> void:
	for id in cards:
		var c: CardDefinition = cards[id]
		if c.card_kind == CardDefinition.CardKind.OPERATION:
			if not operations.has(c.effect_id):
				errors.append("card '%s': unknown effect_id '%s'" % [id, c.effect_id])
			continue
		if c.uses_state_effect():
			_validate_state_card(c)
			continue
		var u: UnitDefinition = units.get(c.unit_id)
		if u == null:
			errors.append("card '%s': unknown unit_id '%s'" % [id, c.unit_id])
		elif c.card_kind == CardDefinition.CardKind.DEPLOYMENT and u.height_class != UnitDefinition.HeightClass.GROUND:
			errors.append("card '%s': deployment unit '%s' must be a ground unit" % [id, c.unit_id])
		elif c.card_kind == CardDefinition.CardKind.SORTIE and u.height_class == UnitDefinition.HeightClass.GROUND:
			errors.append("card '%s': sortie unit '%s' must be an aircraft" % [id, c.unit_id])


## An order, supply, deck or doctrine card must name an effect that does what the card's kind promises.
func _validate_state_card(c: CardDefinition) -> void:
	var e: StateEffectDefinition = effects.get(c.effect_id)
	if e == null:
		errors.append("card '%s': unknown effect_id '%s'" % [c.id, c.effect_id])
		return
	match c.card_kind:
		CardDefinition.CardKind.ORDER:
			if not e.is_modifier() or e.duration_s <= 0.0:
				errors.append("card '%s': an order needs an effect with a duration and an armour or damage change" % c.id)
		CardDefinition.CardKind.DOCTRINE:
			if not e.is_modifier() or e.duration_s > 0.0:
				errors.append("card '%s': a doctrine needs a permanent effect (duration_s = 0) with an armour or damage change" % c.id)
		CardDefinition.CardKind.SUPPLY:
			if e.cp_gain <= 0.0 and not e.refill_ammo:
				errors.append("card '%s': a supply card needs cp_gain or refill_ammo" % c.id)
		CardDefinition.CardKind.DECK:
			if e.draw_count < 1:
				errors.append("card '%s': a deck card needs draw_count >= 1" % c.id)


## Deck legality needs the rules and the card table, so it is checked here once everything is loaded.
func _validate_decks() -> void:
	for id in decks:
		var d: DeckDefinition = decks[id]
		if deck_rules == null:
			errors.append("deck '%s': cannot be checked, deck rules are missing" % id)
			continue
		for e in deck_rules.validate_deck(d.ids(), cards):
			errors.append("deck '%s': %s" % [id, e])
	for id in cards:
		var c: CardDefinition = cards[id]
		if deck_rules != null and float(c.cost) > deck_rules.cp_cap:
			errors.append("card '%s': cost %d can never be afforded (cp_cap %s)" % [id, c.cost, str(deck_rules.cp_cap)])


func _load_deck_rules(path: String) -> void:
	if not ResourceLoader.exists(path):
		errors.append("deck rules missing: %s" % path)
		return
	var res := ResourceLoader.load(path)
	if not (res is DeckRules):
		errors.append("%s is not a DeckRules" % path)
		return
	var errs: PackedStringArray = res.validate()
	if not errs.is_empty():
		errors.append_array(errs)
		return
	deck_rules = res


func _register(table: Dictionary, def: ContentDefinition) -> bool:
	var errs := def.validate()
	if not errs.is_empty():
		errors.append_array(errs)
		return false
	if table.has(def.id):
		errors.append("%s '%s': duplicate id" % [def.kind(), def.id])
		return false
	table[def.id] = def
	return true


func _load_dir(path: String, kind: String, required: bool = true) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		if required:
			errors.append("data directory missing: %s" % path)
		return
	var files := dir.get_files()
	files.sort()
	for f in files:
		var fname := f.trim_suffix(".remap")  # exported builds list remapped resources
		if not fname.ends_with(".tres"):
			continue
		var full := "%s/%s" % [path, fname]
		var res := ResourceLoader.load(full)
		if res == null:
			errors.append("failed to load %s" % full)
			continue
		match kind:
			"weapon":
				if res is WeaponDefinition:
					add_weapon(res)
				else:
					errors.append("%s is not a WeaponDefinition" % full)
			"unit":
				if res is UnitDefinition:
					add_unit(res)
				else:
					errors.append("%s is not a UnitDefinition" % full)
			"enemy":
				if res is EnemyDefinition:
					add_enemy(res)
				else:
					errors.append("%s is not an EnemyDefinition" % full)
			"map":
				if res is MapDefinition:
					add_map(res)
				else:
					errors.append("%s is not a MapDefinition" % full)
			"card":
				if res is CardDefinition:
					add_card(res)
				else:
					errors.append("%s is not a CardDefinition" % full)
			"operation":
				if res is OperationDefinition:
					add_operation(res)
				else:
					errors.append("%s is not an OperationDefinition" % full)
			"effect":
				if res is StateEffectDefinition:
					add_effect(res)
				else:
					errors.append("%s is not a StateEffectDefinition" % full)
			"scenery":
				if res is SceneryDefinition:
					add_scenery(res)
				else:
					errors.append("%s is not a SceneryDefinition" % full)
			"deck":
				if res is DeckDefinition:
					add_deck(res)
				else:
					errors.append("%s is not a DeckDefinition" % full)
			"mission":
				if res is MissionDefinition:
					add_mission(res)
				else:
					errors.append("%s is not a MissionDefinition" % full)
