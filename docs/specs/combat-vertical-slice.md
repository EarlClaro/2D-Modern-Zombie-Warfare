# Spec: Milestone 1 — Combat Vertical Slice

Status: **v0.2 approved 2026-10-15 (D1–D5 accepted as recommended).** Increments 1.1–1.5 done; 1.6 (stress test, FPS measurement, tuning, hand-over) next. Builds on the approved isometric foundation ([isometric-view.md](isometric-view.md), M0.5).

## Purpose
Prove that core combat is **satisfying and readable** on the isometric view with the fewest systems. Pillars tested: (1) combat feel, (4) isometric readability. Cards/deck (pillar 2) and mission variety (3) are out of scope.

## Scope
**Battlefield.** One 24x24 map: a base **core** in one corner area, one **enemy spawn** at the opposite edge, and one **chokepoint** (3-cell gap in a rock wall) on the route. Terrain from `MapDefinition` (grass / road / rock; same walkable/buildable data as the spike TileSet).

**Player forces (pre-placed by mission data, no cards).**
- `rifle_soldier` — mobile (LMB = move order, reuses spike click-to-move), hitscan rifle, fires when it has a target (while standing; see tick rules).
- `mg_nest` — fixed (`move_speed = 0`), hitscan machine gun, higher rate of fire, shorter lifespan pressure (it can be attacked). One code path: "fixed" is just speed 0.

**Enemy.** `shambler` only: follows mission waypoints (cell centres, straight segments on the ground plane) toward the core; if a player entity (unit or core) is within its attack range it stops and attacks it, otherwise keeps walking.

**Combat rules.** `Health`, `DamageService` (base damage, flat armor with a minimum-damage floor, blast falloff — pure & tested), targeting, firing, death.

**Mission.** `Survive` duration → win; core health ≤ 0 → fail; ADR-007 resolution; minimal result panel with restart.

**Feedback (placeholder-grade but real):** muzzle flash, recoil kick, tracer line, impact spark, hit flash, death response (collapse/fade + puff), light screen shake on core hit, programmatically generated placeholder sounds with per-category concurrency caps and cosmetic-only RNG.

**Measurements.** A stress scenario (100 shamblers) with FPS recorded on the dev machine (laptop, NVIDIA MX330 — a low-end baseline). Numbers are reported as measured, no promises.

## Non-goals
Cards/deck/CP, multiple enemy types, flow field (decision stays A6/M3), separation steering beyond a tiny spawn jitter, arcing/physical projectiles (see Decision D1), upgrades, save, final art/audio, damage types/resistances (only `armor` now; type resistances arrive with the Brute in M3).

## Tick order (fixed, in `BattleController.step(delta)`; driven by `_physics_process`, callable manually for tests)
1. Advance mission clock; spawn due wave entries (seeded RNG for spawn jitter).
2. Enemies: choose behaviour (attack target in range, else advance along path); apply their attacks (cooldown-gated) → damage queued.
3. Player units: acquire target (`TargetingService`), update weapon cooldown, fire → hitscan resolves immediately → damage queued. Mobile units process move orders.
4. Apply all queued damage via `DamageService`; collect deaths (dead entities are removed **after** all damage this tick, so simultaneous kills are consistent).
5. Evaluate mission (`MissionRules`): ADR-007 — if win and fail are true on the same tick, **fail wins**; mission ends once; later events ignored.
Presentation (flashes, sounds, shake) is driven by signals emitted during the tick and never feeds back into rules.

## Data model (typed `Resource`s, stable string ids, immutable at runtime)
| Class | Fields (initial) |
|---|---|
| `WeaponDefinition` | `id`, `damage: float`, `shots_per_second: float`, `range_tiles: float`, `delivery` (enum: `HITSCAN`; `PROJECTILE` reserved), `blast_radius: float` (0 = none) |
| `UnitDefinition` | `id`, `display_name`, `max_health`, `move_speed` (0 = fixed), `footprint_radius`, `height_class` (`GROUND`), `weapon_id`, `placeholder_color` |
| `EnemyDefinition` | `id`, `display_name`, `max_health`, `armor` (flat), `move_speed`, `attack_damage`, `attack_interval_s`, `attack_range`, `footprint_radius`, `placeholder_color` |
| `MapDefinition` | `id`, `rows: PackedStringArray` (ASCII: `.` grass, `=` road, `#` rock; all rows same length) |
| `StartUnit` | `unit_id`, `cell: Vector2i` |
| `WaveEntry` | `start_s`, `enemy_id`, `count`, `interval_s`, `spawn_index` |
| `MissionDefinition` | `id`, `display_name`, `map: MapDefinition`, `core_cell`, `core_health`, `duration_s`, `spawn_cells: Array[Vector2i]`, `path_cells: Array[Vector2i]` (waypoints spawn→core), `start_units: Array[StartUnit]`, `waves: Array[WaveEntry]` |
Every definition has `validate() -> PackedStringArray` (empty = valid): positive health/rates, non-empty ids, map rectangular, cells in bounds and walkable, waves reference existing enemy ids, etc. `ContentDb` loads `data/**` by id, reports duplicates and unknown ids as errors (no crash, no silent fallback).

**As built in 1.1:** all definitions extend `ContentDefinition` (`scripts/core/content_definition.gd`: `id` + `validate()` + id format `^[a-z][a-z0-9_]*$`). `ContentDb.load_from(root)` registers valid definitions only, collects `errors` (invalid fields, bad ids, duplicates per kind, missing dirs, wrong resource type, unknown `weapon_id`). `WeaponDefinition.PROJECTILE` is rejected by validation until M2.

**As built in 1.2:** `TargetCandidate` (id, ground pos, alive) is the snapshot type. `TargetingService.pick` is nearest-first, range inclusive, exact ties → lowest id, stateless (no sticky targets). `WeaponState` starts ready, carries fractional overshoot so the long-run rate equals `shots_per_second`, never banks a burst while idle, and after a frame hitch of one interval or more drops the backlog and waits a full interval (found by a failing test, fixed).

**As built in 1.3:** `MapDefinition` (ASCII rows, `.` grass / `=` road / `#` rock, `segment_is_walkable`), `StartUnit`, `WaveEntry`, `MissionDefinition` (validates geometry: core/spawn/path/start units walkable, path ends at the core, **every straight path segment stays off rock**, waves reference valid spawns and finish before the mission ends), `MissionRules` (ADR-007: fail wins ties, ends exactly once, first result final). `ContentDb` now also loads `data/maps` and `data/missions` and checks mission → unit/enemy ids.
Shipped data: map `crossing` and mission `m1_hold_the_crossing` (core (3,20), spawn (20,3), MG nest (8,14), soldier (7,17), waves 5 @ 2 s / 12 @ 20 s / 25 @ 45 s, 90 s, core HP 500). Layout rationale: the route runs along ground (−1,+1), which is **screen-horizontal**, so the fight uses the widescreen; the rock wall runs down the main diagonal (screen-vertical) with a ~3-cell gap the route crosses. Rows (x → right on the grid, y → down; remember ground +X is screen down-right):
```
##.....................=
.##...................==
..##.................==.
...##.##............==..
....##.............==...
.....##.........##==....
......##.........==.....
.......##.......==......
........##.....==.......
.....##..##...==.....#..
..........#..==.........
............==..........
...........==...........
..........==.##.........
.........==...##..##....
........==.....##.......
.......==.......##......
......==.........##.....
.....==...........##....
....==.......##....##...
...==...............##..
..==......#..........##.
.==...................##
==.....................#
```
The `.tres` files are the source of truth and hand-editable (a one-off generator script produced the first version; it is not kept in the repo).

**As built in 1.4:** `BattleController` (`scenes/battle/battle.tscn`, now the project's main scene) builds the map/core/units from a `MissionDefinition` and runs `step(delta)` in the specified order; it only *queues* damage in phases 2–3 and applies it all in phase 4, then removes the dead, then evaluates `MissionRules`. Entities: `BattleUnit`, `BattleEnemy`, `BattleCore` (a `PlaceholderStructure`, so it fades like other tall objects when something is behind it). `BattleHud` and `ResultPanel` (in `ui/`) only read state/signals. Controls: LMB = move the soldier (cell must be walkable, not the core), R = restart (replays the same seed), WASD/MMB/wheel camera. A minimal `Tracer` line shows each shot; the real feedback pass is 1.5. Enemies target the nearest player entity in attack range (D2), soldiers don't fire while moving, `weapon.blast_radius` is not used yet (all M1 weapons are single-target hitscan, D1).

**Finding from 1.4 (balance, unmeasured guesses as warned):** with the shipped numbers the default loadout wins every seed (5/5 checked, 90 s) with the core untouched, 0 units lost, and zombies dying near the wall before they reach any defender. A mission with no defenders is lost (~32 s). So both outcomes are reachable, but the default is far too easy; tuning is part of 1.6 (and difficulty should be judged together with the feedback pass).

**As built in 1.5:** all presentation lives in `BattleFeedback` (`scripts/battle/battle_feedback.gd`), which only listens to controller signals (`shot_fired(shooter, target)`, `hit_landed(target, amount)`, `enemy_died`, `unit_died`) and is covered by a test that the battle outcome is identical with and without it. Effects: `MuzzleFlash` (0.05 s), `Tracer` (0.07 s), `ImpactSpark` (0.14 s, colour by target), `DeathPuff` (0.45 s), unit recoil (`BattleUnit.kick`, 4 px draw-only offset recovering at 60 px/s, never moves the sort anchor), hit flash (`IsoEntity.flash`, white on units/enemies, red on the core), death collapse (`IsoEntity.play_death`: 0.3 s squash toward the feet + fade, body leaves the simulation immediately), `CameraShake` (via `Camera2D.offset`, hard cap 4 px, 3 px / 0.15 s on core hits). Audio: `SfxFactory` generates 5 sounds in code (22.05 kHz mono, fixed noise seeds), `SfxVoicePool` (pure) decides voices: pool of 12, caps shot 4 / impact 4 / death 3 / alert 1, alerts retrigger instead of being dropped and may steal lower-priority voices, `SfxService` plays them with ±8% pitch jitter (cosmetic, non-seeded). The core alert is throttled to once per second. A weapon picks its shot sound through the new `WeaponDefinition.sfx_id` (validated against `SfxFactory.SHOT_SOUNDS`; `mg` uses `shot_mg`).

## Interfaces (pure logic = `RefCounted`/static, testable headless)
- `DamageService.compute(base: float, armor: float, falloff: float = 1.0) -> float`: `max(base − armor, base × MIN_DAMAGE_FRACTION) × falloff`, `MIN_DAMAGE_FRACTION = 0.1`. `DamageService.blast_falloff(distance, radius) -> float` (1.0 at centre → `MIN_FALLOFF` at edge, 0 outside).
- `Health`: `hp`, `max_hp`, `take_damage(amount) -> bool` (true on the lethal hit), `is_dead()`; clamps; signals `changed`, `died` (emitted once).
- `TargetingService.pick(origin: Vector2, range: float, candidates: Array[Candidate]) -> int`: nearest alive candidate within range (ground distance), ties → lowest id, no candidates → `-1`. Candidate = `{id, pos, alive}`.
- `WeaponState`: `tick(delta, has_target) -> bool` returns true when a shot fires; fire interval = `1/shots_per_second`; cooldown carries over (no burst catch-up beyond one shot per tick).
- `MissionRules.evaluate(state) -> Result` (`RUNNING | WON | FAILED` + reason string).
- Nodes (thin): `BattleController` (owns the tick), `BattleUnit`, `BattleEnemy`, `BattleCore` (all `IsoEntity`), reuse `IsoShadow`, `IsoOcclusion`, `IsoCamera`, `IsoPicking`, `IsoTileSet` from the spike.

## Failure / edge cases
No targets → idle, cooldown still recovers; target dies/leaves range mid-cooldown → retarget on next shot; zero-length move order ignored; enemy spawn on a non-walkable cell → validation error, not a crash; unknown `unit_id`/`enemy_id` → validation error naming the id; invalid definitions never reach the battle; win/fail reported once; restart fully rebuilds state (no leaked nodes: node count returns to baseline).

## Placeholder feedback spec (cosmetic, may not alter rules)
| Event | Presentation |
|---|---|
| Shot fired | Muzzle flash at barrel (2 frames), 3–5 px recoil kick on the shooter, tracer line muzzle→target (fades ~80 ms), shot sound (pitch jitter ±8%) |
| Hit | Impact spark at target (ground point lifted to chest height), target white flash ~60 ms, hit sound |
| Enemy death | Collapse/fade ~0.3 s + dust puff, thud sound, body removed from targeting immediately |
| Core hit | Core flash red, light camera shake (≤ 4 px, 0.15 s), alert sound (priority channel, not culled by gunfire) |
| Audio | Generated `AudioStreamWAV` bursts; pool of 12 voices; per-category cap (gunshot 4, impact 4, death 3, alert 1); alerts always play |
| Readability | Health bars above entities; shadows on all; units fade tall structures (existing `IsoOcclusion`); zombies visually distinct from player units |

## Decisions needing your call (defaults recommended — will proceed with these unless you say otherwise)
- **D1 — Hitscan only in M1.** Defer the arcing `ProjectileSystem` (and its render strategy decision) to M2 where artillery/rockets need it. Rationale: M1 weapons are small arms where travel time is not tactically important (master prompt §9), and it avoids building an unproven system.
- **D2 — Enemies attack units as well as the core** (nearest player entity in attack range). Gives units tension and makes unit placement matter. Alternative: core only.
- **D3 — Soldier is player-controlled by click-to-move; MG nest is fixed.** Gives the slice minimal agency without cards. Alternative: both fixed (fully passive).
- **D4 — Placeholder audio generated in code** (no external files, no licensing issues). Replace in M7.
- **D5 — Map from ASCII rows in a `.tres`** (diff-friendly, no editor tile painting). The scene builds the `TileMapLayer` from it with the existing `IsoTileSet`.

## Acceptance criteria
Automated (all via `godot --headless --path . --script tests/run_tests.gd`):
1. `DamageService`: normal, armor reduces, floor applies when armor ≥ base, zero/negative base → 0, falloff centre/edge/outside, no negative results.
2. `Health`: damage, overkill clamp, `died` emitted exactly once, no damage after death, healing absent (not in scope).
3. `TargetingService`: nearest wins, tie → lowest id, out-of-range ignored, dead ignored, empty → -1, range measured in ground distance (an enemy at equal *ground* distance in different directions is treated equally even though screen distances differ).
4. `WeaponState`: fire cadence over simulated time (N shots in T seconds), no fire without target, cooldown continues without target.
5. `MissionRules`: win on timer with core alive; fail on core dead; same-tick win+fail → fail; ends once; running otherwise.
6. Definitions: every shipped `.tres` validates clean; deliberately bad definitions produce specific errors; `ContentDb` reports duplicate and unknown ids.
7. Battle smoke: build the mission headlessly, step N seconds with a fixed seed → deterministic result, no errors, mission ends, restart returns node count to baseline; a "no defenders" run **fails** and a "strong defenders" run **wins** (proves both outcomes are reachable).
8. Existing 26 tests still pass; headless import clean.

Manual / measured (reported honestly as pending until done):
9. Shots visibly leave the weapon and reach the target; kills legible with 20+ zombies; facing/recoil read in all 8 directions.
10. Stress scenario: 100 shamblers + 2 guns, FPS recorded in a windowed run on the dev machine (reported with hardware).
11. **You judge "is it satisfying?" (go / tune / no-go)** — the milestone's exit gate.

## Increments (each is small, tested, and reported before the next)
| # | Increment | Output |
|---|---|---|
| 1.1 ☑ | Definitions + `ContentDb` + validation + `Health` + `DamageService` | tests 1, 2, 6 (done: 34 tests; map/mission/wave definitions arrive in 1.3) |
| 1.2 ☑ | `TargetingService` + `WeaponState` | tests 3, 4 (done: 23 tests) |
| 1.3 ☑ | `MissionRules` + `MissionDefinition`/map/waves data (`crossing` mission) | test 5 (done: 41 tests) |
| 1.4 ☑ | Battle scene: map build, core, shambler movement/attack, unit/nest firing (hitscan, no polish), `BattleController.step`, result panel + restart | test 7 (done: 13 tests) + first playable (**manual play pending**) |
| 1.5 ☑ | Feedback pass (flash, recoil, tracer, spark, hit flash, death, shake, generated audio + caps, health bars) | manual criterion 9 (**feel judged by you, pending**); pure parts + wiring tested (34 tests) |
| 1.6 | Stress scenario + FPS measurement + tuning pass of `BALANCE.md` numbers; docs/changelog; hand over for the go/no-go | criteria 10, 11 |

## Files (planned)
Create:
- `scripts/combat/`: `damage_service.gd`, `health.gd`, `targeting_service.gd`, `weapon_state.gd`, `weapon_definition.gd`, `unit_definition.gd`, `enemy_definition.gd`, `battle_unit.gd`, `battle_enemy.gd`, `battle_core.gd`
- `scripts/missions/`: `mission_definition.gd`, `map_definition.gd`, `wave_entry.gd`, `start_unit.gd`, `mission_rules.gd`
- `scripts/core/`: `content_db.gd`, `sfx_service.gd` (battle-owned now; promoted to an autoload later if needed)
- `scripts/effects/`: `muzzle_flash.gd`, `tracer.gd`, `impact_spark.gd`, `death_puff.gd`, `camera_shake.gd`
- `scripts/battle/battle_controller.gd`, `scenes/battle/battle.tscn`
- `ui/battle_hud.gd`, `ui/result_panel.gd`
- `data/weapons/{rifle,mg}.tres`, `data/units/{rifle_soldier,mg_nest}.tres`, `data/enemies/shambler.tres`, `data/maps/crossing.tres`, `data/missions/m1_hold_the_crossing.tres`
- `tests/`: `test_damage_service.gd`, `test_health.gd`, `test_targeting.gd`, `test_weapon_state.gd`, `test_mission_rules.gd`, `test_content_db.gd`, `test_battle_smoke.gd`
Modify (small): `scripts/iso/placeholder_unit.gd` stays for the spike scene only; `docs/{ARCHITECTURE,ROADMAP,TESTING,BALANCE}.md`, `CHANGELOG.md`, `README.md`; `project.godot` gets `run/main_scene` → battle scene at 1.4.
Not touched: M0.5 projection/entity/occlusion code (reused as is). If a reuse need requires changing it, that is flagged first.

## Risks
- **Zombie stacking** (no separation steering): mitigated by spawn jitter; may look like a blob at 100 — measured in 1.6; proper handling in M3 with the flow-field decision.
- **Tuning**: the numbers in BALANCE are guesses; the win/fail smoke test (7) guarantees both outcomes exist, not that the difficulty is good.
- **"Satisfying" is subjective**: feedback pass (1.5) is time-boxed and judged by you; sound quality of generated placeholders will be crude.
- **Scope creep**: anything not in the table above goes to the roadmap, not into M1.
