# Spec: Props and Cover (structures)

Status: **v0.1 draft, implemented as recommended 2026-10-16** (requested directly by the user, outside the M2 plan; no hard boundary changes, so no ADR). Builds on [card-loop.md](card-loop.md). Source art: `sandbag_wall`, `concrete_barrier`, `crate_stack`, `oil_drums`, `jeep`, `supply_truck` (see [ASSETS.md](../ASSETS.md)).

## Purpose
Give the new prop art a job: cheap placeable **structures** that enemies must chew through, so the player can buy time and shape where the horde stops, plus pre-placed mission scenery that is also a target.

## Core idea
Enemies already stop and attack the nearest player entity within their attack range (`BattleController._enemy_phase`). A **structure** is a player entity with hit points and no weapon. Because it is a normal target, a wall next to the road stalls every enemy that comes within reach of it while the defenders keep shooting. There is no path blocking and no collision (hordes still ignore each other, Milestone 3 territory); a structure works as a **decoy and stall**, not a maze wall.

## Scope
- `UnitDefinition.structure: bool`. A structure is fixed (`move_speed == 0`), needs no weapon (`weapon_id` may be empty) and never shoots or moves. Validation: `weapon_id` is required unless `structure`; a structure must not move and must not have a weapon.
- `UnitDefinition.death_blast_damage` / `death_blast_radius` (both 0 = none). When the entity dies, an area blast goes off on its spot (same falloff and armor rules as any blast, enemies only, friendly fire off). Explosive barrels, a fuel truck.
- Structures turn to face the first spawn cell when placed, so a wall's long side lies across the enemy's approach.
- The blast of a dying structure hits enemies only (friendly fire stays off, so volatile structures never chain into each other); its hits are applied in the same tick, so none are lost.
- Feedback: no soldier "death" sound for a structure (a soft impact instead); the destruction frames in the sprite play as for MG nests; volatile structures use the ground-radius `Explosion` from the blast signal rather than the small vehicle fireball.
- Card preview for a structure shows no weapon range ring; a volatile structure shows its blast radius.

## Content (first guesses, to be measured)
| Structure | HP | Armor | Death blast | Card cost | Role |
|---|---|---|---|---|---|
| `sandbag_wall` | 220 | 0 | none | 1 | cheap stall |
| `concrete_barrier` | 500 | 3 | none | 2 | tough stall, shrugs off small hits |
| `crate_stack` | 110 | 0 | none | 1 | cheapest decoy |
| `oil_drums` | 70 | 0 | 70 dmg, radius 1.8 | 2 | bait that hurts the crowd that attacks it |
| `jeep` (scenery) | 160 | 0 | none | – | pre-placed in the mission |
| `supply_truck` (scenery) | 320 | 1 | 90 dmg, radius 2.4 | – | pre-placed in the mission, explodes |

New deck `fortified` (18 cards, 11 designs) and mission `x1_fortified_crossing` (the m3 waves plus the Spitter-free roster, with a jeep and a truck placed near the road). `starter`, `combined_arms`, `m2`, `m3` are untouched. The wrecked car stays art only (no definition) until scenery without hit points exists.

## Non-goals
Path blocking or flow-field avoidance, enemies choosing a route around walls, cover that reduces damage to units standing behind it, repairing structures, rotating a placed structure, an objective mission rule (escort, protect the truck), save data.

## Acceptance criteria
1. `structure` validation rejects a structure that moves or has a weapon and a unit that has no weapon without `structure`; an existing shipped unit is unaffected.
2. Playing a structure card deploys one structure facing the spawn, spends CP, never errors without a weapon (no `weapon_state` access).
3. An enemy within attack range of a structure attacks it and does not advance until it is destroyed (stall); armor reduces the damage; the structure never shoots.
4. A dying volatile structure damages enemies inside its radius with falloff, hurts none of the player's own entities, and the hits are applied in the same tick the structure dies (no lost hits).
5. All shipped data validates, previous tests unchanged and passing, `x1_fortified_crossing` can be played start to end headless.
6. Measured: do-nothing loses, a sensible mix wins; walls/drums cards are exercised one at a time with `tools/tune_cards.gd` (numbers in BALANCE.md).
7. Manual (user): how stalling feels, readability of walls against the road, explosion size/sound of drums and the truck.

## Risks
- A wall far from the road is useless and a wall on it stalls the whole horde: placement stays on buildable cells near the core (existing D2 rule), so the road itself is protected from walls by terrain.
- Cheap structures could let the player stall forever against weak waves; the sweep checks that spamming walls without firepower does not win.
