# Spec: Unit autonomy and new card types (inserted into Milestone 3)

Status: **v0.2, approved by the user on 2026-10-16 (interview decisions, then "this is good now").** Nothing is built. Origin: playtest feedback, "I want the game to be easy and not micromanage the many units. Once the player uses the card, the units or things used by the player smartly do what they do, without having to set it up in the map. There should also be more types of cards instead of just military units."

Builds on [card-loop.md](card-loop.md) (M2) and [horde-and-objectives.md](horde-and-objectives.md) (M3, which this spec re-orders; see "Effect on the M3 plan").

## Purpose
Move the player's job from *placing and ordering units* to *choosing what to play and when*. A played card does its whole job by itself, and the card pool grows beyond "put a soldier somewhere" into orders, traps, logistics, intel, reinforcements, production buildings, high-tech support, doctrine and deck tricks.

## Decisions (user, 2026-10-16)
| Topic | Decision |
|---|---|
| Placement | **Keep exact cells** for every card that has a position. The change is in what units do afterwards, not in how the card is aimed. |
| Orders | **Remove click-to-move.** Units never need orders; no rally point. |
| Autonomy depth | **Behaviours + small habits:** Hold / Guard / Advance / Support per unit, plus cover, retreat when hurt, and focus fire on dangerous targets. No flanking, formations or squad roles. |
| Timing | **Inserted into M3 now**; autonomy comes before the rest of the M3 plan. |
| Card types wanted | Orders (timed buffs), Traps and structures, Logistics, Intel and lures, Reinforcements, Buildings (produce units), High-tech military support, plus **Doctrine upgrades** and **Deck tricks** in the first batch. |
| First-batch scope | **The framework plus one real example card per type** (nine cards). The rest of the catalogue below is content for later milestones. |
| Buildings | **Timed spawner with a cap:** placed on an exact cell, makes a unit every N s up to a cap of units alive, the units guard around it, enemies can destroy it. |
| Reinforcements | **Enter from the nearest map edge** and settle on their own near the core (ground version of the helicopter sortie). |
| High-tech roster (catalogue) | Combat drones, orbital/railgun strike, EMP/stun field, recon satellite scan, chemical warfare, nuclear bombs, missiles, artillery barrage, close air support, satellite laser. Only the types need a proof now. |
| Doctrine | **Chosen before the mission** (not drawn). A pre-mission picker belongs with the deck editor (M5); until then a mission or `--doctrine=` names the doctrines it starts with. |
| Difficulty | **Selectable, enemy count only:** easy / normal / hard multiply the number of enemies in every wave; economy, core health and enemy stats stay fixed. |

## Scope
### 1. Unit behaviours
`UnitDefinition.behavior` (data) selects one of four behaviours, run by a pure, seeded-RNG-free `UnitBrain` (no randomness: same state gives the same decision):
| Behaviour | Rule | First users |
|---|---|---|
| **Hold** | Never moves. Fires at the best target in range. | Gatling gun, MG nest |
| **Guard** | Has an anchor (the cell it was placed on). If an enemy is within `leash` tiles of the anchor it walks to a firing position that is in weapon range and within the leash, fights, and returns to the anchor when nothing is in leash. | Rifle soldiers, RPG team |
| **Advance** | Moves toward the nearest enemy that threatens the core (closest to the core along its route) until it has a target in range, fights, and repositions after kills. Never goes farther than `advance_limit` tiles from the core. | Tank, jeep |
| **Support** | Follows the nearest friendly non-support unit (within `follow_range`) and applies its support (heal, repair, resupply). | Future: medic, engineer |
Existing facts that stay true: a unit must stand still to fire (except weapons with `can_fire_moving`), ground enemies cannot target aircraft, units block no build cells beyond their footprint.

**Habits** (each is data-switchable per unit so tests and balance can isolate them):
- **Cover:** a Guard unit choosing a firing position prefers a cell next to a friendly structure on the enemy side, if one is within the leash and still in range.
- **Retreat:** below `retreat_below` of max health a mobile unit walks back toward the core until it is out of enemy reach or healed; a fixed unit does not retreat.
- **Focus fire:** among targets in range, prefer by threat: armoured enemies for weapons marked anti-armour (RPG), then Spitters, then Brutes, then nearest (replaces plain nearest for units only; enemies keep nearest-wins).
Habits sit on top of the same targeting rule as today: an exact tie still goes to the lowest id.

**Removed:** `order_move_all`, "LMB with no card moves units", the move-order hint text and the click-to-move tests (replaced by behaviour tests).

### 2. Card framework
Today a card is DEPLOYMENT, OPERATION or SORTIE. The framework adds kinds and a data-driven effect so a new card is mostly data:
- `CardKind`: add ORDER, TRAP, SUPPLY, INTEL, REINFORCEMENT, BUILDING, SUPPORT_TECH, DOCTRINE, DECK (existing kinds stay; structures keep using DEPLOYMENT).
- A `CardEffect` family (pure where possible), each with its own tests: timed **modifiers** on units (armour, fire rate, speed, heal over time), **entities** that are not units (mines: trigger on contact, one blast), **economy** (CP burst, regeneration boost), **marks and lures** on enemies (bonus damage taken, steer toward a decoy), **spawners** (building, reinforcement convoy), **deck** actions (draw, cycle, discount, reset lockout), **doctrine** modifiers (permanent for the mission).
- `ContentDb` validates the new fields and cross-references the same way it does now.
- HUD and preview: exact-cell previews for positioned cards, area previews for fields, instant cards (orders, supply, deck tricks, intel with no target) play on click with no cell, and each card kind has a colour on the hand bar.

### 3. First-batch cards (one per type; names and numbers are first guesses)
| Type | Card | What it does |
|---|---|---|
| Orders | **Fortify** | All your ground units take reduced damage (armour bonus) for 20 s. |
| Traps | **Minefield** | Places a patch of mines on an exact cell area; each mine blasts the first enemy that steps on it. |
| Logistics | **Supply Drop** | Instantly gives CP (a burst) and refills limited ammo (helicopter missiles on station). |
| Intel / lures | **Noise Lure** | A decoy on an exact cell: enemies within its radius steer toward it for 10 s instead of the core. |
| Reinforcements | **Convoy** | A squad enters from the nearest edge and settles near the core; behaves as Guard. |
| Buildings | **Barracks** | Structure that makes a rifle soldier every 12 s up to 3 alive; destroyed by enemies like any structure. |
| High tech | **Combat Drones** | 3 autonomous drones hunt targets for 20 s (air units; enemies cannot target them). |
| Doctrine | **Hollow Points** | Pre-mission doctrine: rifle weapons +15 % damage for the whole mission. |
| Deck tricks | **Quick Draw** | Draw 2 cards immediately. |
Catalogue for later milestones: Rapid Fire, Rally, Overwatch, barbed wire, tripwire, self-building turret, fuel-drum combos, field hospital, command post, flare, recon satellite scan, EMP/stun field, orbital/railgun strike, satellite laser, missile salvo, artillery barrage variants, close air support, chemical weapons, nuclear bomb, terrain actions (bridges, gates, fire).

### 4. Difficulty
`Difficulty` data (easy / normal / hard) with an enemy-count multiplier applied when waves spawn (rounded, never below 1 per entry; proposed 0.6 / 1.0 / 1.5, to be swept). Chosen by `--difficulty=` and a mission default; an in-game selector waits for a menu (Milestone 7). It changes only counts, so a card's value does not shift between levels.

## Non-goals
Flanking, formations, squad roles, adaptive AI; a rally point; a pre-mission screen and a doctrine picker UI (M5); in-game difficulty menu (M7); balancing the full catalogue (later milestones); terrain actions; naval support.

## Effect on the M3 plan
Increments 3.1 and 3.2 are done. The rest is re-ordered and renumbered; each ends with tests, a mutation check, docs and an automatic commit as agreed (push only when told):
- **3.3 Unit behaviours:** `UnitBrain` (Hold / Guard / Advance / Support), `UnitDefinition` fields, removal of click-to-move, data for the existing units, tests for each behaviour and for determinism, re-run of the whole-battle digest tool to see what changed.
- **3.3 as built (2026-10-16):** `UnitBrain` (pure), `UnitDefinition` fields and `effective_behavior()`, `BattleUnit.anchor/stop/move_target`, `_think_and_move`/`_carry_out`/`_walk_is_clear` in the controller, `order_move_all`, the click handler, the hover highlight and the HUD move hints removed, the tank set to ADVANCE (rifle and RPG soldiers are GUARD by default, fixed units HOLD); 28 new tests; see ARCHITECTURE.md "Unit behaviours" and BALANCE.md for what changed in battles.
- **3.4 Habits:** cover, retreat, focus fire, each with tests and a switch.
- **3.4 as built (2026-10-16):** the three habits above, with fields on `UnitDefinition`, `EnemyDefinition.threat`, `WeaponDefinition.anti_armor`; tests for the pure rules (`cover_spot`, `in_cover`, `retreat`), for `best_in_range` against a slow reference, and in battle (fall back, stay put, switch off, fixed units, spitter/brute first, cover behind a wall, no shuffling). Two deviations from the spec text, both found while testing: (1) cover must override the "stop when in range" rule, because a unit always reaches weapon range before the 90 % firing spot, so cover never happened otherwise; it now keeps walking to cover (losing a second or two of fire) unless an enemy is already within 3 tiles; (2) retreat has no healing to wait for until 3.5, so it is "stay near the core while enemies are near". Cover gives no damage reduction; it works because enemies attack the nearest thing.
- **3.5 Card framework and state cards:** new `CardKind`s, `CardEffect` base, ContentDb validation, modifiers, economy, deck and doctrine effects; examples Fortify, Supply Drop, Quick Draw, Hollow Points (doctrine through the mission/CLI).
- **3.6 Entity cards:** mines, spawners (building and convoy), lure; examples Minefield, Barracks, Convoy, Noise Lure.
- **3.7 High-tech support:** combat drones (autonomous air units); example Combat Drones; framework check for the rest of the roster.
- **3.8 Strike cutaways:** full-screen freezing clips for big supports (naval gunfire, close air support, missile strike, artillery barrage), three new strike cards, generated art; see [strike-cutaways.md](strike-cutaways.md).
- **3.9 Difficulty:** multipliers, CLI, tests.
- **3.10 Autonomy and card balance sweep:** re-sweep the card bots on all mission decks (smart units change every earlier number), settle the balance debt noted in the M3 spec (m2 pressure, helicopter), and tune the new cards.
- **3.11 Flow-field movement (was 3.3):** ADR-012 as accepted; friendly Advance/Guard units reuse the field for routes around scenery.
- **3.12 Objective model (was 3.4), 3.13 Objective UI and spawn markers (was 3.5), 3.14 Two-front mission and 1000-alive stress (was 3.6), 3.15 Hand-over (was 3.7).**
M3 is now much larger than planned. At 3.10 I will ask whether to close M3 there and move 3.11-3.15 to a new milestone.

## Acceptance criteria
1. Playing any deployment card and doing nothing else lets the units fight sensibly: Guard units engage inside their leash and come back, Advance units reach a firing position, Hold units never move; no input beyond the card is ever needed.
2. Click-to-move is gone from code, HUD hints and tests; no test depends on an order API.
3. Behaviour is deterministic: the same seed and the same plays give the same battle (digest test).
4. Each habit can be switched off per unit and has a test showing the difference.
5. Each of the nine first-batch cards can be played from the hand through the real UI, has a preview where it needs one, and has pure tests for its effect; invalid plays never change state.
6. The card framework is data-driven: adding a card of an existing kind needs only a `.tres`.
7. Difficulty changes only enemy counts; with `normal` every shipped mission behaves exactly as before.
8. The card sweeps are re-run after autonomy and results are recorded in BALANCE.md; any mission that became trivial is flagged to the user.
9. Manual (user): how units feel on their own, whether previews read, whether the hand bar stays readable with the new kinds.

## Risks
- **Scope:** about nine card types plus AI behaviours in one milestone; mitigated by one example per type and by ordering (autonomy first, framework second, entities third).
- **Balance:** smarter units invalidate every M2/M3 sweep number; 3.10 exists for that, and until then costs are first guesses.
- **Testability:** unit movement is new simulation state; it must stay pure and seed-free, with whole-battle digests as the regression net.
- **Readability:** many auto-moving friendly units plus 1000 zombies must stay legible (checked in screenshots at 3.3 and 3.13).
- **Rule check:** "predictable, testable behaviour, no adaptive AI" in the master prompt stands: the four behaviours and three habits are fixed rules, not learning.
