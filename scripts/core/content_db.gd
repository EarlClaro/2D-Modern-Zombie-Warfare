class_name ContentDb
extends RefCounted
## Loads and holds all definitions by stable id. Invalid definitions are reported in `errors` and are
## NOT registered, so they can never reach a battle. Unknown ids resolve to null (callers must check)
## and cross-references are verified by `validate_references()`.

var weapons: Dictionary = {}  # id -> WeaponDefinition
var units: Dictionary = {}  # id -> UnitDefinition
var enemies: Dictionary = {}  # id -> EnemyDefinition
var errors: PackedStringArray = PackedStringArray()


## Loads data/{weapons,units,enemies} under `root`, then verifies cross-references.
static func load_from(root: String = "res://data") -> ContentDb:
	var db := ContentDb.new()
	db._load_dir(root + "/weapons", "weapon")
	db._load_dir(root + "/units", "unit")
	db._load_dir(root + "/enemies", "enemy")
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


func add_weapon(def: WeaponDefinition) -> bool:
	return _register(weapons, def)


func add_unit(def: UnitDefinition) -> bool:
	return _register(units, def)


func add_enemy(def: EnemyDefinition) -> bool:
	return _register(enemies, def)


## Adds an error for every reference to an id that is not registered.
func validate_references() -> void:
	for id in units:
		var u: UnitDefinition = units[id]
		if not weapons.has(u.weapon_id):
			errors.append("unit '%s': unknown weapon_id '%s'" % [id, u.weapon_id])


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
