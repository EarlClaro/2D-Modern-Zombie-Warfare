extends SceneTree
## Dev tool (not a test): writes data/upgrades/*.tres, the ten first-guess upgrades of the five starter cards (two exclusive
## branches each, docs/specs/progression.md increment 5.5). Run: godot --headless --path . --script tools/gen_upgrades.gd
## The numbers are first guesses; the bot sweep that checks them is 5.6 (docs/BALANCE.md).

const W := UpgradePatch.Target.WEAPON
const U := UpgradePatch.Target.UNIT
const O := UpgradePatch.Target.OPERATION
const C := UpgradePatch.Target.CARD
const ADD := UpgradePatch.Op.ADD
const MUL := UpgradePatch.Op.MUL
const SET := UpgradePatch.Op.SET

var _errors: int = 0


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://data/upgrades"))
	_save("rifle_long_barrels", "Long Barrels", "rifle_squad", "Rifles reach 3 tiles further and hit 10 % harder, so squads can stay out of the horde's reach.",
		[_p(W, "rifle", "range_tiles", ADD, 3.0), _p(W, "rifle", "damage", MUL, 1.1)])
	_save("rifle_body_armor", "Body Armour", "rifle_squad", "Riflemen have 60 % more health and 2 armour.",
		[_p(U, "rifle_soldier", "max_health", MUL, 1.6), _p(U, "rifle_soldier", "armor", ADD, 2.0)])
	_save("gatling_crowd_spray", "Crowd Spray", "gatling_gun", "Rounds burst on hit and hurt everything close to the target, for 35 % less damage per round.",
		[_p(W, "gatling", "blast_radius", ADD, 0.7), _p(W, "gatling", "damage", MUL, 0.65)])
	_save("gatling_ap_belt", "Armour-Piercing Belt", "gatling_gun", "Rounds hit more than three times as hard and go for armoured targets first, but the gun fires 40 % slower.",
		[_p(W, "gatling", "damage", MUL, 3.2), _p(W, "gatling", "shots_per_second", MUL, 0.6), _p(W, "gatling", "anti_armor", SET, 1.0)])
	_save("tank_he_shells", "High-Explosive Shells", "tank", "The cannon's blast is 0.9 tiles wider, for 10 % less damage.",
		[_p(W, "tank_cannon", "blast_radius", ADD, 0.9), _p(W, "tank_cannon", "damage", MUL, 0.9)])
	_save("tank_reactive_armor", "Reactive Armour", "tank", "The tank has 3 more armour and 60 % more health.",
		[_p(U, "tank", "armor", ADD, 3.0), _p(U, "tank", "max_health", MUL, 1.6)])
	_save("artillery_saturation", "Saturation Barrage", "artillery_strike", "Six more shells over a much wider area, each 20 % weaker.",
		[_p(O, "artillery_strike", "shell_count", ADD, 6.0), _p(O, "artillery_strike", "target_radius", ADD, 2.0), _p(O, "artillery_strike", "shell_damage", MUL, 0.8)])
	_save("artillery_heavy_shells", "Heavy Shells", "artillery_strike", "Shells hit 80 % harder with a bigger blast and land 0.4 s sooner.",
		[_p(O, "artillery_strike", "shell_damage", MUL, 1.8), _p(O, "artillery_strike", "blast_radius", ADD, 0.4), _p(O, "artillery_strike", "warning_s", ADD, -0.4)])
	_save("helicopter_extended_station", "Extended Station", "helicopter_support", "The gunship stays on station 14 seconds longer and has 30 % more health.",
		[_p(C, "helicopter_support", "station_time_s", ADD, 14.0), _p(U, "helicopter", "max_health", MUL, 1.3)])
	_save("helicopter_rocket_pods", "Rocket Pods", "helicopter_support", "Three more rockets, each 10 % stronger.",
		[_p(W, "heli_missile", "ammo", ADD, 3.0), _p(W, "heli_missile", "damage", MUL, 1.1)])
	quit(1 if _errors > 0 else 0)


func _p(target: UpgradePatch.Target, target_id: String, property: String, op: UpgradePatch.Op, value: float) -> UpgradePatch:
	var p := UpgradePatch.new()
	p.target = target
	p.target_id = target_id
	p.property = property
	p.op = op
	p.value = value
	return p


func _save(id: String, name: String, card_id: String, text: String, patches: Array[UpgradePatch]) -> void:
	var u := UpgradeDefinition.new()
	u.id = id
	u.display_name = name
	u.description = text
	u.card_id = card_id
	u.patches = patches
	for e in u.validate():
		push_error(e)
		_errors += 1
	var err := ResourceSaver.save(u, "res://data/upgrades/%s.tres" % id)
	if err != OK:
		push_error("saving upgrade %s failed (%d)" % [id, err])
		_errors += 1
	print("wrote ", id)
