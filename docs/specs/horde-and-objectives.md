# Spec: Milestone 3 — Horde and mission objectives

Status: **v0.3 approved 2026-10-16: D1–D7 as recommended, the interview answers below, and the 3.1 decisions (ADR-012 accepted, separation on by default for flow missions, a step-cost increment added as 3.2).** 3.1 is done; nothing else is built yet.

## Purpose
Make a mission a *place with a purpose* instead of a timer: hordes that arrive from more than one direction, find their way across a map with real obstacles, and do not collapse into one stack; and missions whose win/fail conditions are data you can read on screen. Master prompt, Milestone 3: wave spawning from one or more spawn points, several archetypes, a documented path/flow-field decision, base health and timer, a defence mission with explicit victory/failure rules, objective UI with clear results, and a stress test of a representative horde in the isometric view.

## What already exists (verified in the tree, 2026-10-16)
| M3 bullet | State |
|---|---|
| Spawning from several points | `WaveEntry.spawn_index` and `MissionDefinition.spawn_cells` work; `x2_outskirts` uses two spawns that merge at a bridge. All spawns share one waypoint list (`path_cells`). |
| Several archetypes | Shambler, Runner, Brute, Spitter exist and are in missions. Balance on the combined roster is only partly swept ([BALANCE.md](../BALANCE.md)). |
| Base health and timer | Done: core HP, `duration_s`, HUD. |
| Explicit victory/failure | `MissionRules` (ADR-007): fail = core destroyed, win = timer elapsed, fail wins ties. Only these two conditions exist. |
| Movement | Straight segments between waypoints (`BattleEnemy.advance_path`), a fixed per-enemy lane offset, no separation, no obstacle awareness. Scenery on a path is rejected by `ContentDb` instead of routed around. |
| Objective UI / results | HUD shows core HP and "HOLD" countdown; `ResultPanel` shows VICTORY/DEFEAT, one reason line and four stats. |
| Stress test | `tools/perf_sim.gd`, `perf_fps.gd`, `perf_world.gd` exist; measured at <= ~650 alive enemies. |

So M3 is mostly **three new things**: a measured movement decision, an objective system, and the UI for it, plus a representative mission and stress run.

## Scope
**Movement (A6).**
- Measure first (increment 3.1): waypoint walking (today) vs a shared **flow field** on the ground grid vs flow field + **separation** (spatial hash), at 250 / 500 / 1000 / 2000 alive, headless sim ms per tick and windowed FPS. Record in BALANCE.md and decide in a new ADR.
- Recommendation going in (to be confirmed or reversed by the numbers): one flow field per mission (a distance map from the core over walkable cells, 8-neighbour, computed once at setup), enemies steer along it; light separation only if it fits the budget. Per-agent navigation (`NavigationAgent2D`) is not a candidate: it works in screen space and costs per agent.
- Pure, testable: `FlowField` (RefCounted, grid in, direction/distance out), `SpatialHash` (if separation is kept). No projection math outside `IsoProjection`; the field is in ground cells.

**Objectives.**
- `ObjectiveDefinition` (data, on the mission) with a kind and parameters; `ObjectiveTracker` (pure) updates once per tick after damage/death resolution (ADR-007) and reports progress per objective.
- Kinds for M3 (enough for a defence mission, no more): `SURVIVE` (timer, `seconds`), `CORE_HEALTH_AT_LEAST` (`fraction`, a preservation threshold), `KILL_COUNT` (`count`), `CLEAR_WAVES` (all waves spawned and no enemy alive).
- Roles: **primary** objectives all true => win; **secondary** are reported, never end the mission; any **fail** condition true => defeat (default fail: core destroyed). Fail wins ties (ADR-007).
- Missions without objectives keep today's behaviour exactly (implicit: primary SURVIVE `duration_s`, fail core destroyed). All existing missions are the regression set.

**Spawns and approaches.** Each spawn point may have its own approach (route hint); with a flow field the route is derived from the terrain, and `path_cells` becomes optional (kept for waypoint missions and for validation of hand-authored routes).

**UI.** HUD objective list: icon-free text lines with progress ("Hold 1:23 left", "Core >= 50%: 78%", "Kills 120 / 300"), primary above secondary, a clear met/failed/pending state. `ResultPanel` lists every objective with its final state and the one that decided the outcome. UI reads state only; rules stay in the tracker.

**A representative mission** (`m3_two_fronts`, name tentative): two spawn points, all four archetypes, three objectives (primary survive, secondary core health, secondary kill count), swept with `tools/tune_cards.gd` bots. It is also where the m2 pressure retune and the helicopter question are settled.

## Non-goals
Grading (Bronze/Silver/Gold), rewards, mission modifiers, assault/escort/rescue types and required-asset thresholds (all Milestone 4); progression/save (M5); new enemy types beyond the four; adaptive AI; destructible terrain; moving obstacles; tactical pause; repositioning flow for aircraft (they do not use the ground field); a second map unless 3.5 needs one.

## Decisions to approve (recommendations first)
| # | Question | Recommendation | Why |
|---|---|---|---|
| D1 | How is A6 decided? | Measure in 3.1, then ADR-012 with the numbers. Default pick: shared flow field, and separation only if the measured cost per tick stays inside the budget. | Master prompt says "only after measuring". M1 numbers show waypoint walking is cheap, so the case for a field is routing and readability, not speed. |
| D2 | What blocks a flow field? | Terrain (rock/water) and **static scenery footprints**. Player units, structures and the core ring do **not** block (enemies keep stopping to attack them). | Keeps "decoy and stall" cover as designed in [props-and-cover.md](props-and-cover.md) and avoids turning the game into a maze/tower defence (hard boundary). It also removes the authoring rule that scenery may not touch the path. |
| D3 | Are `path_cells` kept? | Yes, optional. A mission picks `routing = waypoints` (today, default so no mission changes) or `flow`. Shipped missions move to `flow` one by one only when swept. | Existing missions and balance numbers stay valid; no big-bang change. |
| D4 | Objective kinds | The four above only. | Enough for a real defence mission; more kinds belong to the mission types in M4. |
| D5 | Win by clearing waves | `CLEAR_WAVES` ends the mission early (all spawned, none alive) when it is a primary objective; otherwise the timer rules. | Lets a mission be "survive the assault" instead of "wait 120 s"; both are tested with the same tracker. |
| D6 | Separation | Cheap local avoidance via spatial hash, capped neighbours per enemy, enemies only (not vs player units). Dropped if 3.1 shows it costs more than ~25 % of the tick budget at 1000 alive. | Readability item carried since M1.6; must not cost the frame rate that M2.6 measured (204 FPS avg on the card mission). |
| D7 | Scale target | Representative horde = **1000 alive** simultaneously on a quiet machine, reported as measured (not promised), using the MX330 baseline. Existing <= 650 numbers stay in BALANCE.md. | M1.6 stopped at 500 and says "do not quote a maximum". We need one measured number above that. |

## Interview answers (2026-10-16)
- D2, D3, D4, D5, D6, D7 approved as recommended (terrain + static scenery block; opt-in `routing` per mission; four objective kinds; early win by clearing waves when primary; separation kept only if cheap; 1000-alive stress target).
- **No grade in M3:** the result screen lists each objective as met or failed. Grading, rewards, modifiers stay in M4.
- **Balance debt** (m2 mission too easy, helicopter at 5 CP trapping the saving bot) is handled **once in 3.6**, after flow routing and separation change how hordes arrive. The helicopter stays untouched until then and needs the user's go.
- **Mission map:** `m3_two_fronts` reuses `outskirts`; the two fronts stay apart (each down its own road to the core) instead of merging at the bridge. No new map art.
- **A6 gate:** after 3.1 I wrote ADR-012 as *proposed* with the measured table and waited for the user's OK. **Resolved 2026-10-16:** ADR-012 accepted as proposed (flow field, 4-tick steering refresh, per-enemy lane offset, waypoints stay the default).
- **Separation (3.1 decision):** included, **on by default for flow missions**; staggered version (pushes and hash refreshed every 4th tick, 8 neighbours).
- **Step cost (3.1 decision):** a new increment 3.2 comes first, target 1000 alive at about 10 ms per tick headless on this machine; later increments are renumbered.
- **Spawn cue (added to 3.5):** a ground marker at each spawn point plus an edge arrow when it is off-screen, shown shortly before its wave starts. Presentation only, read from mission data.
- **Commits:** I commit automatically when an increment's checks pass (only my files, clean-checkout test run, explicit file lists, usual trailer). **I push only when told.** This replaces "commit only when asked" for M3 increments, by the user's choice.

## 3.1 findings (2026-10-16; numbers in [BALANCE.md](../BALANCE.md), proposal in ADR-012)
- Flow field: about 1.4-1.6x the waypoint movement step, at most 1.9 ms per tick at 2000 alive when steering refreshes every 4th tick; every-tick refresh is 4x and not worth it. Build 0.1 s on `x2_outskirts`.
- A field alone stacks the horde into columns; a per-enemy lane offset on the sample fixes that for free. Separation fits the D6 budget (16-22 % of a tick at 1000-2000 alive) but only halves overlap at the shipped spawn density.
- **Not in the original plan:** the whole step costs about 26 ms at 1000 alive (passes the 16.7 ms tick at roughly 600-700), dominated by per-tick candidate allocation and all-pairs target search, not by movement. D7 (1000 alive) needs a step-cost increment first.
- Resolved (user, 2026-10-16): add **3.2 Step cost** (reuse candidate lists, spatial hash for enemy queries shared by targeting and blasts, no work for empty unit lists; target 1000 alive at or under about 10 ms per tick headless on this machine), and renumber: 3.3 movement, 3.4 objective model, 3.5 objective UI + spawn markers, 3.6 two-front mission + stress, 3.7 hand-over.

## Increments (each: tests -> mutation check -> headless import -> docs/CHANGELOG -> report -> commit (automatic, see above); push when you say)
- **3.1 Movement measurement and decision (A6).** `tools/perf_flow.gd` plus throwaway prototypes of `FlowField` and `SpatialHash` in the tool or tests. Output: BALANCE.md table, ADR-012 (proposed), your confirmation before 3.2. No game behaviour change.
- **3.2 Step cost.** Measured in 3.1: the step costs about 26 ms at 1000 alive, mostly from building a `TargetCandidate` and dictionary entry per enemy per tick (even with no units) and all-pairs target search. Reuse candidate storage, one spatial hash of enemies shared by unit targeting and blast queries, no per-tick work when no unit can fire. Behaviour must not change: same seed gives the same battle (the existing battle and card tests unchanged, plus a test that old and new queries agree). Target: 1000 alive at about 10 ms per tick headless (`tools/perf_sim.gd`), measured and reported as measured.
- **3.2 as built (2026-10-16):** `EnemyIndex` and the rewritten enemy/unit phases and blast loop; no behaviour change (12 whole-battle digests identical, 13 new equivalence tests, mutation 12/13 with the survivor equivalent); 1000 alive costs 5.5-7.8 ms per tick against the 8.9-11.9 ms of the old step on the same quieter machine, so the target (about 10 ms) is met. See BALANCE.md "Step cost after M3.2", which also corrects the 3.1 step-cost magnitude (measured under load).
- **3.3 Movement implementation.** (Separation on by default for flow missions.) `FlowField` (pure, tested: reachability, obstacles, diagonal corner rules, unreachable cells, determinism), `MissionDefinition.routing`, `BattleEnemy` steering, separation if kept, `ContentDb` validation (spawn can reach core), regression: every shipped mission passes `ContentDb` and the existing battle tests unchanged under `waypoints`.
- **3.4 Objective model.** `ObjectiveDefinition`, `ObjectiveTracker`, `MissionRules` driven by it (implicit default for old missions), content validation, tests per kind, per tie rule, "ends exactly once", restart.
- **3.5 Objective UI and results.** HUD list, result panel breakdown, spawn markers and edge arrows, tests for the pure text/state mapping, screenshots reviewed; real clicks are a manual check.
- **3.6 Two-front mission and stress run.** `m3_two_fronts` mission data, bot sweep (idle loses, a mix wins, over >= 10 seeds), windowed 1000-alive run, readability screenshots at default zoom.
- **3.7 Hand-over.** Milestone checklist, BALANCE.md/ROADMAP/CHANGELOG, your **go / tune / no-go**.

## Acceptance criteria (Milestone 3 exit)
1. A6 closed: ADR-012 with the measured numbers for the compared approaches.
2. With `flow` routing every spawn reaches the core around terrain and scenery; an unreachable spawn is a content error, not a runtime stall. Same seed gives the same battle.
3. Zombies do not stack into one point at 500+ alive (checked by a pure overlap metric, not only by eye), if separation is kept.
4. A mission can declare primary/secondary objectives and fail conditions in data; each kind is covered by tests including ties (fail wins) and single end.
5. HUD shows each objective's live progress; the result screen shows every objective's final state and why the mission ended.
6. Old missions behave identically (the existing battle/mission tests pass unchanged; M2 sweep numbers for `m2_card_defense` still reproduce on the same seeds under `waypoints`).
7. Stress: the measured 1000-alive run is reported with FPS, 1 % low, draw calls, hardware and load conditions.
8. Docs, CHANGELOG, ROADMAP updated; mutation check per increment.
9. Manual (you): real input, readability of the horde and of the objective list, whether the two-front mission feels fair.

## Failure cases to test
No walkable route from a spawn; spawn or core on blocked terrain; objective with a non-positive parameter; two primary objectives where one can never be met (flagged only if provably impossible, e.g. kill count above total spawned); primary and fail true on the same tick; mission with `CLEAR_WAVES` and a wave that spawns after the timer; restart mid-battle resets the tracker.

## Risks
- A flow field changes enemy movement everywhere it is used, which can move balance numbers. Mitigation: D3 (opt-in per mission) and a re-sweep per migrated mission.
- Separation can change how many enemies reach the defence at once (it spreads the horde), which is a balance effect as well as a visual one; measure with the bots before and after.
- The other session is editing art and the core radius in the same tree: increments stay in `scripts/missions/`, `scripts/combat/` movement, `ui/` and `data/missions/`, and are committed with explicit file lists as before.
