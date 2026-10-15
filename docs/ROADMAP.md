# Roadmap

Legend: ☐ not started · ◐ in progress · ☑ done (acceptance criteria checked). Updated with evidence only.

| Milestone | Status | Notes |
|---|---|---|
| 0 Specification foundation | ☑ | Docs written; user approved plan + ADR-005..008 (2026-10-15) |
| 0.5 Isometric spike | ◐ | [spec](specs/milestone-0.5-iso-spike.md). Steps 1–2 done (test runner, IsoProjection + 9 passing tests). Steps 3–8 (scene, picking, unit, flyer, AoE) pending |
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
1. Milestone 0.5 steps 3–4: spike scene (TileMapLayer + camera), picking + hover highlight, TileMapLayer layout test.
2. Steps 5–7: placeholder unit, flyer, AoE ellipse.
3. User runs the manual checklist and approves look/feel.

## Evidence log
- 2026-10-15: Godot `4.7.2.stable.official.ed1daf0bf` found via WinGet; `--headless --import --quit` exited 0 on the empty project. No tests exist yet.
- 2026-10-15: `tests/run_tests.gd` run: 9 tests, 0 failed, exit 0; failing-test sanity check exits 1.
