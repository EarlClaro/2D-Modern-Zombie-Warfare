class_name StateEffectDefinition
extends ContentDefinition
## What a "state" card does to the battle rather than to the map: a timed order, a supply drop, a deck trick or a
## doctrine (ADR-013). A card names one through `CardDefinition.effect_id`. Immutable data; the running effects live in
## `BattleModifiers`. Every field defaults to "no effect", so a definition only sets what it uses.

@export var display_name: String = ""
## ORDER: how long the effect lasts. 0 = for the whole mission (a doctrine).
@export var duration_s: float = 0.0
## Your ground units take this much less damage per enemy hit (added to their armour; DamageService keeps its floor).
@export var armor_bonus: float = 0.0
## Damage dealt by your weapons is multiplied by this; 1 = unchanged.
@export var damage_mult: float = 1.0
## The weapons `damage_mult` applies to (weapon ids); empty = every player weapon.
@export var weapon_ids: PackedStringArray = PackedStringArray()
## SUPPLY: Command Points added at once (up to the cap) and whether limited ammo (aircraft missiles) is refilled.
@export var cp_gain: float = 0.0
@export var refill_ammo: bool = false
## DECK: cards drawn at once (as many as the hand has room for).
@export var draw_count: int = 0


func kind() -> String:
	return "effect"


## True when the effect changes damage taken or dealt while it lasts (it is tracked by BattleModifiers).
func is_modifier() -> bool:
	return armor_bonus > 0.0 or not is_equal_approx(damage_mult, 1.0)


func does_something() -> bool:
	return is_modifier() or cp_gain > 0.0 or refill_ammo or draw_count > 0


func validate() -> PackedStringArray:
	var errs := super.validate()
	if display_name.is_empty():
		errs.append(_err("display_name is empty"))
	if duration_s < 0.0:
		errs.append(_err("duration_s must be >= 0"))
	if armor_bonus < 0.0:
		errs.append(_err("armor_bonus must be >= 0"))
	if damage_mult <= 0.0:
		errs.append(_err("damage_mult must be > 0"))
	if cp_gain < 0.0:
		errs.append(_err("cp_gain must be >= 0"))
	if draw_count < 0:
		errs.append(_err("draw_count must be >= 0"))
	if not does_something():
		errs.append(_err("does nothing (set armor_bonus, damage_mult, cp_gain, refill_ammo or draw_count)"))
	return errs
