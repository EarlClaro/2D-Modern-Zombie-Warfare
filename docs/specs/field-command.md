# Spec: Field command (build anywhere, smarter army, long-range artillery, more missions, a harder game)

Status: **v0.1, requested by the user on 2026-10-17; interview answers the same day.** Branch `m3-field-command` (worktree `../Modern Zombie Warfare field`). ADR-016. Overrides two earlier decisions on purpose: cards are no longer limited to a circle around the base (deploy radius), and the army is no longer passive about where it stands (ADR-013's behaviours gain kiting and scouting). Milestone 3, after 3.5; numbering "F1..F5" below until the roadmap places them.

## The request (user, 2026-10-17)
1. More missions, each with a different map.
2. Fix: the player cannot build on roads; they should be able to.
3. The player can build anywhere on the map, not only inside a circle around the base.
4. The game is too easy: make it harder.
5. Army units should be smart enough not to block, or stand within reach of, zombies that are eating or damaging them.
6. Army units should scout ahead, fight nearer to and earlier at the enemy spawns, and kite the zombies there.
7. Tanks and every army vehicle should be very mobile and proactive.
8. Howitzers and other artillery should be long range and close to their real capability.
9. Propose which units would be good to bring closer to reality, which to limit, which to keep game-only.
10. (Added the same day, after the proposal) **Bring every unit up to its realistic side** (the "realistic part" column of the proposal).

## Decisions (user answers, 2026-10-17)
| Topic | Decision |
|---|---|
| Spawn areas | Keep a **no-build zone** around enemy spawn points (default 6 tiles, per mission), so players cannot camp the spawn. |
| Difficulty | **Make the game harder, no selector.** Raise the numbers; no Easy setting for now. (The selector of increment 3.9 stays later.) |
| Order | Build rules, then AI and vehicles, then artillery, then maps, then balance. Hardness is tuned **last**, after the AI changes, because smarter units change every balance number. |
| Proposal (item 9) | Delivered in the chat; recorded below for later approval. |

## Increments
- **F1 Build rules (this commit).** Roads and every other walkable ground except shallows become buildable; the deploy radius becomes optional (0 = the whole map) and every shipped mission uses the whole map; a per-mission `spawn_guard_radius` keeps a no-build circle around enemy spawns, shown red in the card preview. Placement rules stay pure.
- **F2 Smart army and mobile vehicles.** A danger map of enemy reach (attack range plus margin); a KITE behaviour (hold at weapon range, back away along the route, fall back when overwhelmed); scouting forward to engage near the spawns; units do not stand where they block a friendly or inside a zombie's reach; the tank, jeep and other vehicles become fast and proactive (hunt, flank, return). Pure rules and tests like `UnitBrain`.
- **F3 Roster realism and artillery.** Every unit gets its realistic side (table below), the missing roles are added (marksman, IFV, mortar, rocket launcher), and artillery becomes long range: the howitzer about 40 tiles with a minimum range; artillery fires on targets seen by any friendly unit (a spotter); slow fire, big area damage; self-propelled shoot-and-scoot.
- **F4 New missions.** Five maps with different layouts (river bridges, highway, airfield, town streets, mountain pass; harbour if there is time), each with its own waves, deck and weather; listed automatically in mission select.
- **F5 Balance.** Card-bot sweeps on every mission; raise enemy counts and special-enemy timing until a decent bot wins about half the time; document in BALANCE.md.

## F1 in detail
- `TerrainCatalog`: `buildable` is true for every walkable terrain except `shallows` (water). Rock and deep water stay unbuildable because nothing can stand there. Rubble, mud, ice, craters, asphalt, lanes, cobble, runways and roads are buildable.
- `MissionDefinition.deploy_radius`: `0` means no limit (valid values are >= 0); the default is 0 too, so every mission is unlimited unless it says otherwise.
- `MissionDefinition.spawn_guard_radius` (tiles, default 6, valid >= 0): a deployment cell whose centre is closer than this to any spawn cell is refused with the new reason `TOO_CLOSE_TO_SPAWN` ("Too close to the enemy spawn").
- `PlacementRules.check_deploy(map, cell, core_cell, deploy_radius, occupied, spawn_cells = [], guard_radius = 0.0)`: order of checks: bounds, buildable, spawn zone, radius (only if > 0), occupied.
- The preview draws the deploy ring only when there is a limit, and a red ring around each spawn while a deployment card is selected.
- Operations, sorties and field cards keep their own rules (already map-wide).

## Non-goals of F1
Pathing changes (enemies still walk their routes and attack what is in reach; a structure on the road is a target, not a wall), new terrain, new UI beyond the red rings.

## Acceptance criteria (F1)
1. A deployment card can be placed on roads, asphalt, runways, rubble, mud, ice and craters, and still not on rock, water or shallows.
2. In every shipped mission a deployment card can be placed anywhere on the map except the core, occupied cells and the spawn zones.
3. A cell inside the spawn guard radius is refused with its own message and changes no state.
4. A mission with `deploy_radius > 0` still limits placement as before (tests keep covering it).
5. Tests, the content check and the card-bot tool still work; docs and the changelog updated.

## Roster realism (item 10; first guesses, tuned in F5)
**Scale rule:** real distances are compressed to the map but their **ratios are kept** (a mortar reaches about a third as far as a howitzer, a tank out-ranges a rifle about two to one), and speeds are scaled so a main battle tank is clearly faster than a jogging soldier, as in real life. **Kept game-only on purpose:** no ammo or fuel (supply cards cover logistics), no transport or carrying troops, no enemy aircraft so no anti-air units. Every unit keeps its ID so decks and tests stay valid; stats change in data.

| Unit | Realistic side (what changes) | Now to game values (first guess) | Limit kept |
|---|---|---|---|
| Rifle soldier | Effective range about 400 m; fire and manoeuvre: shoots, steps back, shoots | range 8 (unchanged), speed 3.0, **kites** (F2) | squads are a single card |
| Marksman (new) | Long precise fire, slow, aimed | range 14, 0.8 shots/s, 60 damage, holds position, picks high-threat targets | game-only role name |
| RPG soldier | Short range, one heavy shot | range 7, 70 damage, reload slow (unchanged), **retreats to reload** | |
| MG team / nest | Long, steady suppressive fire | MG range 8 to 11 | fixed in place, no ammo |
| Main battle tank | Fast on road and off, fires on the move, heavy armour, long gun range | speed 1.0 to **4.0**, range 9 to **16**, fires while moving, armour 5 (unchanged), proactive hunting | cannot carry troops |
| IFV (new) | Autocannon, quick, medium armour | speed 4.5, range 12, 4 shots/s of small shells | does not carry troops |
| Jeep / scout | Fast, fragile, good for scouting and baiting | speed 0 to **5.5**, range 8, scouts ahead and draws zombies | |
| Attack helicopter | Cannon plus long-range guided missiles, fast | speed 3.0 to 4.5, cannon range 12, missile range **22** | fixed flight altitude |
| Self-propelled howitzer | 155 mm, tens of kilometres, slow fire, needs a spotter, shoot and scoot | range 16 to **40** with a minimum of 8, burst of 3 then reload, blast 2.5, fires only at targets a friendly unit can see, relocates after firing | fire rate sped up for play |
| Mortar team (new) | Short range, high arc, cheap, fast to set up | range 14, minimum 3, 1 shot per 2 s, blast 1.8 | |
| Rocket launcher (new) | Salvo of rockets over a wide area, long reload | range 40, minimum 12, 6-rocket ripple, reload 30 s | one launcher per card |
| Combat drone (3.7) | Cheap, autonomous | as already specified | limited loiter time |
| Supply truck, barrier, sandbags, crates, drums, barracks | Already as real as they need to be | unchanged | |

## Progress
- **F1 build rules, done** (see above): 717 tests at the time.
- **F2 smart army and mobile vehicles, done (2026-10-17):** new behaviour `UnitBrain.KITE` (pure `UnitBrain.kite`), `Route` (spawn-to-core polyline: `point_at`, `progress_of`, `dir_to_core`, `distance_to`), `KiteScan` plus `EnemyIndex.scan_kite` (one pass over the enemies in a unit's vision: which enemies' danger zones hold it, how many it can outrun, the push away, the crowd, the enemy nearest a spawn). Danger zone of an enemy = its attack reach + a safety margin (1.2 tiles x the unit's `danger_margin`) + the ground it covers in 0.7 s. A KITE unit: (1) falls back toward the core in a long step when more enemies crowd it than its `courage`; (2) with an enemy in a zone it backs off along the route in the shortest step that gets it clear (so it can fire in between: units still stand still to shoot), but **holds and fights** when any dangerous enemy is faster than it (it cannot outrun it) and at the core; (3) safe with a target in range: stands and fires; (4) enemies in sight: walks to the edge of its weapon range of the enemy nearest the spawn, never into that enemy's zone; (5) nothing in sight: **scouts** up the route to a waiting post `scout_post` tiles from the spawn, offset sideways by its id so a group does not stack; a friend closer than 0.7 tiles makes it step aside. New `UnitDefinition` fields `vision`, `scout_post`, `courage`, `danger_margin`. Data: rifle and RPG soldiers and the tank are KITE; **tank speed 1.0 to 4.0** with a bold `danger_margin` 0.4 and `courage` 40; new unit `scout` (a Scout Jeep: the jeep art with a machine gun, speed 5.5, KITE; in no card yet, F3 gives it one). The decoy `jeep` structure used by missions is unchanged. Tests: `tests/test_kite.gd` (33), older behaviour tests pin their units to GUARD/ADVANCE. What the tests show in a real battle: a lone rifleman scouts to its post, kills 16 shamblers walking down the route without being touched where a standing guard loses 50 hit points, turns and fights instead of running from a runner, and a battle is deterministic. Not done by me: judging how it looks and plays (screenshots only), and the balance effect (F5).
