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
var deck_rules: DeckRules  # data/config/deck_rules.tres; null if missing/invalid (reported in errors)
var errors: PackedStringArray = PackedStringArray()


## Loads data/{weapons,units,enemies,maps,missions,cards,decks,operations} and data/config/deck_rules.tres under `root`, then verifies cross-references.
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


func add_operation(def: OperationDefinition) -> bool:
	return _register(operations, def)


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
		if not weapons.has(u.weapon_id):
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
		if not m.deck_id.is_empty() and not decks.has(m.deck_id):
			errors.append("mission '%s': unknown deck_id '%s'" % [id, m.deck_id])
	_validate_card_units()
	_validate_decks()


## Cards must point at real units of the right kind: deployments are ground units, sorties are aircraft.
func _validate_card_units() -> void:
	for id in cards:
		var c: CardDefinition = cards[id]
		if c.card_kind == CardDefinition.CardKind.OPERATION:
			if not operations.has(c.effect_id):
				errors.append("card '%s': unknown effect_id '%s'" % [id, c.effect_id])
			continue
		var u: UnitDefinition = units.get(c.unit_id)
		if u == null:
			errors.append("card '%s': unknown unit_id '%s'" % [id, c.unit_id])
		elif c.card_kind == CardDefinition.CardKind.DEPLOYMENT and u.height_class != UnitDefinition.HeightClass.GROUND:
			errors.append("card '%s': deployment unit '%s' must be a ground unit" % [id, c.unit_id])
		elif c.card_kind == CardDefinition.CardKind.SORTIE and u.height_class == UnitDefinition.HeightClass.GROUND:
			errors.append("card '%s': sortie unit '%s' must be an aircraft" % [id, c.unit_id])


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


func _load_dir(path: String, kind: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
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
