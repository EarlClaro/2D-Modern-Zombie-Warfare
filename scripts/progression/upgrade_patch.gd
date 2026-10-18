class_name UpgradePatch
extends Resource
## One change an upgrade makes to a number of another definition (docs/specs/progression.md, increment 5.5): add to it,
## multiply it, or set it. The change is applied to a per-battle copy (UpgradeApplier), never to the shared definition.

enum Target { WEAPON, UNIT, OPERATION, CARD }
enum Op { ADD, MUL, SET }

@export var target: Target = Target.WEAPON
@export var target_id: String = ""
@export var property: String = ""
@export var op: Op = Op.ADD
## The amount. For a true/false property use SET with 1 (true) or 0 (false).
@export var value: float = 0.0


## The definition this patch changes in `db` (null if the id is unknown).
func resolve(db: ContentDb) -> Resource:
	match target:
		Target.WEAPON:
			return db.weapon(target_id)
		Target.UNIT:
			return db.unit(target_id)
		Target.OPERATION:
			return db.operation(target_id)
		Target.CARD:
			return db.card(target_id)
	return null


## The table of `db` this patch's target lives in.
func table_of(db: ContentDb) -> Dictionary:
	match target:
		Target.WEAPON:
			return db.weapons
		Target.UNIT:
			return db.units
		Target.OPERATION:
			return db.operations
	return db.cards


func validate(db: ContentDb) -> PackedStringArray:
	var errs := PackedStringArray()
	var res := resolve(db)
	if res == null:
		errs.append("patch targets unknown %s '%s'" % [Target.keys()[target].to_lower(), target_id])
		return errs
	var has := false
	for p in res.get_property_list():
		if p["name"] == property:
			has = true
	if not has:
		errs.append("%s '%s' has no property '%s'" % [Target.keys()[target].to_lower(), target_id, property])
		return errs
	var cur: Variant = res.get(property)
	match typeof(cur):
		TYPE_FLOAT, TYPE_INT:
			pass
		TYPE_BOOL:
			if op != Op.SET:
				errs.append("'%s' is true/false: only SET works on it" % property)
		_:
			errs.append("'%s' is not a number or a true/false value" % property)
	if not is_finite(value):
		errs.append("value must be a finite number")
	if op == Op.MUL and value <= 0.0:
		errs.append("a multiplier must be > 0")
	return errs


## Changes `res` (a copy owned by the caller) in place.
func apply_to(res: Resource) -> void:
	var cur: Variant = res.get(property)
	match typeof(cur):
		TYPE_BOOL:
			res.set(property, value != 0.0)
		TYPE_INT:
			res.set(property, int(round(_combine(float(cur)))))
		TYPE_FLOAT:
			res.set(property, _combine(cur))


func _combine(current: float) -> float:
	match op:
		Op.ADD:
			return current + value
		Op.MUL:
			return current * value
	return value
