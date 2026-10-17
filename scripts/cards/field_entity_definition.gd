class_name FieldEntityDefinition
extends ContentDefinition
## What a Trap or Intel card puts on the battlefield (ADR-013): a patch of mines, or a noise lure. A card names one
## through `CardDefinition.effect_id`. Immutable data; the running mines and lures live in MineField / LureField.

enum EntityKind { MINES, LURE }

@export var display_name: String = ""
@export var entity_kind: EntityKind = EntityKind.MINES
## MINES: how many, how far from the aimed cell they are spread, how close an enemy must come to set one off, and the
## blast each one makes (damage with armour and falloff like any blast, radius in tiles).
@export var mine_count: int = 8
@export var spread_radius: float = 2.0
@export var trigger_radius: float = 0.7
@export var mine_damage: float = 70.0
@export var mine_blast_radius: float = 1.3
## LURE: enemies with nothing to attack within `lure_radius` walk to it for `lure_duration_s`.
@export var lure_radius: float = 9.0
@export var lure_duration_s: float = 10.0


func kind() -> String:
	return "entity"


func validate() -> PackedStringArray:
	var errs := super.validate()
	if display_name.is_empty():
		errs.append(_err("display_name is empty"))
	match entity_kind:
		EntityKind.MINES:
			if mine_count < 1:
				errs.append(_err("mine_count must be >= 1"))
			if spread_radius < 0.0:
				errs.append(_err("spread_radius must be >= 0"))
			if trigger_radius <= 0.0:
				errs.append(_err("trigger_radius must be > 0"))
			if mine_damage <= 0.0:
				errs.append(_err("mine_damage must be > 0"))
			if mine_blast_radius <= 0.0:
				errs.append(_err("mine_blast_radius must be > 0"))
		EntityKind.LURE:
			if lure_radius <= 0.0:
				errs.append(_err("lure_radius must be > 0"))
			if lure_duration_s <= 0.0:
				errs.append(_err("lure_duration_s must be > 0"))
	return errs
