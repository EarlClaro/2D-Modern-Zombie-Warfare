# Game Design Document — Last Defense (working title)

Status: draft v0.2 (updated 2026-10-16 for ADR-013 and ADR-014). Source: [MasterPrompt.md](../MasterPrompt.md). Tuning values live in [BALANCE.md](BALANCE.md) / data files.

## 1. Vision
Real-time, mission-based, high-view isometric military **combined-arms deckbuilder**. The player commands modern/near-future forces against huge mutant hordes. Not a conventional tower defense: structures exist, but the identity is combined arms, doctrine/deck building, and mission variety.

**Pillars (MVP must prove all four):** (1) combat feels satisfying; (2) cards create meaningful tactical choices; (3) missions make the player want to improve the deck; (4) the isometric view always reads clearly (what is where, who attacks whom, where a card will land).

Platform: PC/Steam first. Offline single-player, local saves.

## 2. Core loop
Prepare deck → read mission → start with hand + command points → play cards in real time → react to waves → complete objective while meeting preservation thresholds → grade + reward choice → edit deck → harder mission. Ordinary mission target 3–8 min (tuning target).

## 3. Isometric view (summary — authoritative: [specs/isometric-view.md](specs/isometric-view.md))
- Fixed 2:1 dimetric, floor tile 64x32 px, no rotation, pan + zoom only (ADR-002).
- Gameplay on a flat ground plane; altitude `z` separate; projection only for rendering/input (ADR-003).
- Ground circles render as 2:1 ellipses. Y-sort by footprint base; air/effects on upper layers. 8-way facing. Light from top-left.
- Occlusion: fade tall structures (ADR-005, to be validated in spike).

## 4. Battlefield (default assumption A1)
One isometric map per mission. Base on one side or center; hordes spawn from edges/nests and approach from multiple directions along paths, creating flanks, coverage arcs and chokepoints. Terrain tile data: walkable, buildable, cover. Aircraft pass through; naval = off-map timed strikes with telegraph. Real-time only; optional tactical pause considered post-MVP.

## 5. Cards
Fields: stable `id`, name, description/flavor, category, tags, rarity (separate from power), icon, cost, cooldown/use limit, targeting mode (`ground_cell`, `ground_circle`, `unit`, `area`, `global`) + valid targets, effect id (+params), unlock condition, upgrade level/branches, doctrine requirement (later), synergy tags, audio/VFX refs, balance notes. Definitions are `Resource`s; effects are code keyed by `effect_id`.

Categories: Infantry, Armor, Artillery/Ordnance, Aviation, Naval, Drones, Command/Intel/Logistics, Experimental. MVP implements a small subset (§11).

**Card kinds (ADR-013, spec [unit-autonomy-and-card-types.md](specs/unit-autonomy-and-card-types.md)):** besides Deployment, Operation and Sortie, the card system gains data-driven kinds: **Orders** (timed buffs on everything deployed), **Traps and structures** (mines, wire), **Logistics** (supply drop, hospital, command post), **Intel and lures** (recon, flare, decoy), **Reinforcements** (a squad arriving from a map edge), **Buildings** (timed unit spawners with a cap), **High-tech support** (combat drones, orbital/railgun, EMP, satellite scan, missiles, close air support, laser, chemical and nuclear strikes), **Doctrine** (mission-long passive bonuses, chosen before the mission) and **Deck tricks** (draw, cycle, discount, reset a lockout). Roster beyond the first nine example cards belongs to later milestones.

**Units act on their own (ADR-013):** once a card is played the player gives no move orders and no rally point. Each unit has a fixed behaviour (Hold, Guard, Advance, Support) plus small habits (cover, retreat when hurt, focus fire on dangerous targets). Positioned cards keep exact-cell placement.

**Strike cutaways (ADR-014, spec [strike-cutaways.md](specs/strike-cutaways.md)):** heavy support calls show a short full-screen clip that freezes the game (about 1.5 s the first time per support per mission, shorter after, tiered epic/large/small, skippable and switchable off), then the effect lands.

### Deck and economy rules (recommended defaults — detail: [specs/deck-and-economy.md](specs/deck-and-economy.md))
| Rule | Default |
|---|---|
| Deck size | min 12, max 24; starter deck 15 (3 copies × 5 designs, M2 decision D3; 16 is impossible with 5 designs and a 3-copy cap) |
| Duplicates | max 3 copies per card id (Legendary: 1) |
| Initial hand / hand cap | 4 / 5 |
| Draw | On battle start draw 4. Then 1 card per 4 s while hand < cap |
| Reshuffle | When draw pile empty, shuffle discard into draw pile (no penalty in MVP) |
| Command Points (CP) | start 5, cap 10, +1 per 3.0 s base (tuned in M2.6, ADR-011) |
| Card types | **Deployment** (unit/structure persists until destroyed or timed out), **Operation** (one-shot effect, e.g. strike), **Sortie** (aircraft: enters, acts, exits), **Order / Supply / Deck trick** (instant, no target: timed armour or damage change, Command Points and reload, draw cards), **Doctrine** (a permanent bonus a mission starts with), **Trap / Lure** (mines and decoys on an exact cell), **Reinforcement** (a squad that walks in from a map edge), **Building** (a structure that makes units), **High tech** (autonomous aircraft such as combat drones that hunt and leave after a time) |
| After play | card goes to discard pile; no per-card cooldown in MVP except via draw cycle. Strong ops carry a per-card *lockout* (cooldown before it can be played again once redrawn) |
| Upgrades | Persistent per card id, apply to all copies, branches change behavior not just stats |
| Deck editing | Between missions, within min/max, subject to mission restrictions (e.g. "no Naval") |

## 6. Combined arms and synergies
Tag-driven, rule-based (e.g. `marked` status from recon drone → artillery +accuracy, ground +damage; `supported_armor`; `saturation` vs dense groups; logistics refills ammo/reduces lockout). Each major synergy documents counterplay and balance risk in BALANCE.md. Post-MVP.

## 7. Military assets
Each has a ground footprint, 8-way facing, sort anchor, height class (ground/low-air/high-air), data-driven weapons shared via `WeaponDefinition`. Identities: Gatling (rate of fire, overheat), MBT (slow, durable, expensive), RPG (anti-heavy burst), howitzer (long-range, travel time, AoE), helicopter (mobile, limited duration), jet (precision strike), bomber (large AoE, telegraphed), naval gunfire (delayed heavy), drones (recon/mark), missile battery, repair vehicle, engineers, medics.

## 8. Combat and presentation
Hybrid sim: hitscan for fast small arms; custom ground+altitude movement for bullets/rockets/shells (parabolic altitude arc; shadow on ground); area queries for blasts; RigidBody2D only for selective debris. No per-bullet physics body. Damage = base × type vs armor/resistance, blast falloff, categories. Friendly fire off (MVP). Feedback is a first-class feature: muzzle flash, recoil, tracers, impacts, smoke, hit reactions, explosions, telegraphs; per-category audio concurrency limits and priority mixing. Heavy support calls (naval gunfire, close air support, missile strike, artillery barrage) play a short freezing full-screen cutaway before they land (ADR-014).

## 9. Enemies
Shambler, Runner, Brute, Spitter, Swarm Mother, Apex boss (progressive). MVP: Shambler + Runner (+ Brute if needed). Predictable behavior; no adaptive AI. Each creates a different problem (crowd, speed/gaps, armor, ranged, spawning, phases).

## 10. Missions
Data-driven: objectives (primary/secondary), win/fail conditions, wave/time settings, spawn points + approach directions, required assets, modifiers, rewards. Types over time: Defense, Survival, Assault, Escort, Rescue, Siege, Last Stand, Scavenge, Endless.
**Evaluation rule (default):** conditions evaluated once per simulation tick after all damage/death resolution. If failure and victory conditions are true on the same tick, **failure wins** (conservative; ADR-007). Grades: Bronze primary; Silver + preservation threshold; Gold + optional challenge.

## 11. MVP scope
One map (base, chokepoints, ≥1 spawn), one defense mission, base health + timer, Shambler/Runner(/Brute), 12–18 card designs targeted but only these first: **Rifle squad, Gatling gun, Tank, Artillery strike, Helicopter support**, then logistics/more. Basic draw/play/CP; result screen; reward choice and save only after battle loop works; automated tests for critical rules.

## 12. Progression (post-MVP)
Collection/unlocks, deck editor, branching upgrades, research tree, doctrines, campaign, biomes, endless mode. Rarity Common–Legendary does not imply strictly stronger. Reward = choice of 3. Versioned local save with safe migration.

## 13. Visual/audio direction
Pixel or hybrid pixel art, 2:1 iso, modern lighting/particles, placeholders (colored iso boxes/diamonds) until the loop is fun. Clear silhouettes, shadows, distinct enemy classes. Layered, non-fatiguing audio. Original/licensed assets only ([ASSETS.md](ASSETS.md)).

## 14. Assumptions and unresolved decisions
| # | Item | Default | Status |
|---|---|---|---|
| A1 | Single map per mission, multi-direction approach | as §4 | assumed |
| A2 | Ground unit = 1 tile; ranges in tiles | yes | assumed (ADR-003) |
| A3 | Base resolution 1920x1080, canvas_items stretch | yes | set in project.godot |
| A4 | Test framework | custom headless GDScript runner | proposed (ADR-006), user to approve vs GUT |
| A5 | Mouse + keyboard only for MVP | yes | assumed |
| A6 | Flow field vs per-agent nav for hordes | decide in M3; M1 data: waypoint walking is cheap (0.5–1.9 ms/tick for 100–500), separation is the real gap | open |
| A7 | Occlusion approach | fade occluders (ADR-005) | validate in spike steps 5+ |
| A8 | Sprite directions | 8 | assumed; 5-mirrored is fallback |
| A9 | Real title | Last Defense is placeholder | open |
| A11 | Selectable difficulty | easy / normal / hard scale enemy counts only (user, 2026-10-16) | decided, built in 3.9 |
| A10 | Starting deck contents | 4× Rifle Squad, 3× Gatling, 2× Tank, 3× Artillery Strike, 2× Helicopter, 2× Ammo Resupply = 16 (tune later) | proposed |
