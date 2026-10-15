# Roadmap

Legend: ☐ not started · ◐ in progress · ☑ done (acceptance criteria checked). Updated with evidence only.

| Milestone | Status | Notes |
|---|---|---|
| 0 Specification foundation | ☑ | Docs written; user approved plan + ADR-005..008 (2026-10-15) |
| 0.5 Isometric spike | ☑ | [spec](specs/milestone-0.5-iso-spike.md). All 8 steps implemented; 26 passing tests. User approved the spike look/feel and decisions on 2026-10-15 (exit gate passed) |
| 1 Combat vertical slice | ☑ (exit gate taken as **go** from "Start next", 2026-10-15; real-input/audio/feel never verified by the agent) | [spec v0.2](specs/combat-vertical-slice.md). Increments 1.1–1.6 done; 178 tests at the time |
| 2 First card loop | ◐ plan approved (D1–D7 as recommended). 2.1, 2.2 done; 2.3 built (awaiting commit), 2.4 next | [spec v0.2](specs/card-loop.md) (increments 2.1–2.6); rules in [deck-and-economy](specs/deck-and-economy.md) |
| 3 Horde + mission objectives | ☐ | decide flow field (A6) with measurements |
| 4 Mission variety | ☐ | |
| 5 Progression + deck editor | ☐ | save versioning |
| 6 Combined-arms content | ☐ | |
| 7 Presentation/usability | ☐ | |
| 8 Balance/perf/release | ☐ | |

## Dependencies
0 → 0.5 → 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 (6 content may interleave after 3). Milestone 0.5 exit requires user approval of look/feel.

## Next tasks
1. **You:** play the slice (`godot --path .`, with sound), try different soldier positions, and give the milestone's exit verdict: **go** (start Milestone 2, card loop), **tune** (list what to change: effect strength, loudness, difficulty, length, controls), or **no-go**.
2. Optional: run the stress mission yourself: `godot --path . -- --mission=s1_stress_horde` (FPS shown top-right).
3. Go taken; Milestone 2 plan approved — see the M2 row and [card-loop.md](specs/card-loop.md). Next: increment 2.4 (projectile system + artillery strike).

## Evidence log
- 2026-10-15: Godot `4.7.2.stable.official.ed1daf0bf` found via WinGet; `--headless --import --quit` exited 0 on the empty project. No tests exist yet.
- 2026-10-15: `tests/run_tests.gd` run: 9 tests, 0 failed, exit 0; failing-test sanity check exits 1.
- 2026-10-15: tests 12/12 pass (added 3 tilemap tests). Spike scene screenshot reviewed: axes, tiles and projection-drawn highlight align. Real mouse input not yet manually verified.
- 2026-10-15: tests 26/26 pass. Spike steps 5–7 run in-engine: fade/facing/layer checks passed, screenshots reviewed. Manual input checks pending.
- 2026-10-15: Milestone 0.5 exit approved by the user. Manual input checks (click/keys/hover) were reported as done by approval; the agent could not exercise real input itself.
- 2026-10-15: M1 plan approved. Increment 1.1 done: 60/60 tests pass; mutation check confirmed new tests fail on broken code.
- 2026-10-15: Increment 1.2 done: 83/83 tests pass. Runner hang-on-compile-error fixed and verified. Mutation check passed.
- 2026-10-15: Increment 1.3 done: 124/124 tests pass; mutation check passed (7 mutations, all caught). Shipped mission validates, including the no-rock-crossing path rule.
- 2026-10-15: Increment 1.4 done: 137/137 tests pass; mutation check (7 mutations) passed; real scene ran to victory and restart in a window, screenshots reviewed. Default mission is far too easy (5/5 seeds won with no core damage, no unit lost); tuning scheduled for 1.6.
- 2026-10-15: Increment 1.5 done: 171/171 tests pass; runner now fails tests on any logged error (closed a false-pass hole); mutation check 8/8; real scene screenshots reviewed (muzzle/tracer/spark/hit flash/death collapse/core flash). Audio and feel are manual.
- 2026-10-15: Increment 1.6 done: 178/178 tests. Stress scenario measured (see BALANCE.md): sim 0.48 ms/tick at 100; 117–198 FPS avg at 100, 98–119 at 500 after a shadow-redraw fix (was 40). Waves retuned (6/16/36): default loadout now wins ~70 % passively and soldier placement swings 0–100 %. Milestone 1 awaits the user's go/tune/no-go.
- 2026-10-15: Milestone 1 treated as **go** (user: "Start next"). M2 plan approved with D1–D7 as recommended. Increment 2.1 done: 234/234 tests (50 new from M2.1; 6 more belong to separate sprite-sheet work in the tree); mutation check 15/15 after strengthening the reshuffle test.
- 2026-10-15: Increment 2.2 done: 276/276 tests in the tree (40 new from 2.2; 8 belong to separate sprite-sheet work). Mutation check 20/20 after strengthening two tests (squad formation, deck RNG separation). Real scene run: squad/gatling/tank placed by `play_card`, road cell rejected, tank blast ring and lockout text seen in screenshots. Number-key input and sound are manual checks.
- 2026-10-15: Increment 2.2 committed (626d0d6); a clean checkout of that commit passes 268 tests. Increment 2.3 done: 312 tests in the tree (30 new from 2.3; 14 belong to separate sprite-sheet work). Mutation check 16/16 after adding one test. Real scene run with the mouse moved over chosen cells: hand UI, CP pips with spend preview, green/red cell previews with range + blast circles and deploy zone, cursor tooltip reasons, rejection toast + card shake, lockout shading all seen in screenshots. Real clicks on cards, the number keys and RMB/Esc are manual checks.
