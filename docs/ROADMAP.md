# Roadmap

Legend: ☐ not started · ◐ in progress · ☑ done (acceptance criteria checked). Updated with evidence only.

| Milestone | Status | Notes |
|---|---|---|
| 0 Specification foundation | ☑ | Docs written; user approved plan + ADR-005..008 (2026-10-15) |
| 0.5 Isometric spike | ☑ | [spec](specs/milestone-0.5-iso-spike.md). All 8 steps implemented; 26 passing tests. User approved the spike look/feel and decisions on 2026-10-15 (exit gate passed) |
| 1 Combat vertical slice | ☐ | [spec](specs/combat-vertical-slice.md) |
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
1. Milestone 1 (combat vertical slice): refine [the spec](specs/combat-vertical-slice.md) and propose an implementation plan + file list for approval before coding.
2. Then implement in small increments (definitions + DamageService tests first).

## Evidence log
- 2026-10-15: Godot `4.7.2.stable.official.ed1daf0bf` found via WinGet; `--headless --import --quit` exited 0 on the empty project. No tests exist yet.
- 2026-10-15: `tests/run_tests.gd` run: 9 tests, 0 failed, exit 0; failing-test sanity check exits 1.
- 2026-10-15: tests 12/12 pass (added 3 tilemap tests). Spike scene screenshot reviewed: axes, tiles and projection-drawn highlight align. Real mouse input not yet manually verified.
- 2026-10-15: tests 26/26 pass. Spike steps 5–7 run in-engine: fade/facing/layer checks passed, screenshots reviewed. Manual input checks pending.
- 2026-10-15: Milestone 0.5 exit approved by the user. Manual input checks (click/keys/hover) were reported as done by approval; the agent could not exercise real input itself.
