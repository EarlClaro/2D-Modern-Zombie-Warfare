# Roadmap

Legend: ☐ not started · ◐ in progress · ☑ done (acceptance criteria checked). Updated with evidence only.

| Milestone | Status | Notes |
|---|---|---|
| 0 Specification foundation | ☑ | Docs written; user approved plan + ADR-005..008 (2026-10-15) |
| 0.5 Isometric spike | ☑ | [spec](specs/milestone-0.5-iso-spike.md). All 8 steps implemented; 26 passing tests. User approved the spike look/feel and decisions on 2026-10-15 (exit gate passed) |
| 1 Combat vertical slice | ◐ | [spec v0.2](specs/combat-vertical-slice.md) approved (D1–D5). Increments 1.1–1.5 done (playable battle with feedback pass, `battle.tscn` is the main scene); 1.6 (stress test + FPS + tuning + hand-over) next |
| 2 First card loop | ☐ | [spec](specs/deck-and-economy.md) |
| 3 Horde + mission objectives | ☐ | decide flow field (A6) with measurements |
| 4 Mission variety | ☐ | |
| 5 Progression + deck editor | ☐ | save versioning |
| 6 Combined-arms content | ☐ | |
| 7 Presentation/usability | ☐ | |
| 8 Balance/perf/release | ☐ | |

## Dependencies
0 → 0.5 → 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 (6 content may interleave after 3). Milestone 0.5 exit requires user approval of look/feel.

## Next tasks
1. User launches the game (`godot --path .`) and plays once: does it run, are the controls fine, anything unreadable? (manual items for 1.4)
2. User plays with sound on: does the feedback feel good, is anything too weak/strong/loud or hard to read? (manual criterion 9; input to 1.6 tuning)
3. Increment 1.6: stress scenario + FPS measurement + difficulty tuning (default loadout currently wins trivially).

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
