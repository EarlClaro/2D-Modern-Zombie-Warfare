# Testing Strategy

## Current state
- Custom headless runner (ADR-006) implemented. GUT not used.
- Verified commands (2026-10-15):
  - `"$GODOT" --headless --path . --import --quit` — import/parse check; run it after adding new `class_name` scripts.
  - `"$GODOT" --headless --path . --script tests/run_tests.gd` — 124 tests (26 iso + 34 M1.1 + 23 M1.2 + 41 M1.3: 12 `MissionRules`, 11 `MapDefinition`, 18 `MissionDefinition`/db refs), 0 failed, exit 0. Confirmed it reports `FAIL` and exits 1 when a test fails (temporary failing test, since removed).
- Writing tests: file `tests/test_*.gd`, `extends TestCase`, methods `test_*`; helpers `assert_true/eq/near/vec_near`. Prefer `preload` of the script under test.

- Scene smoke check (one-off, 2026-10-15): spike scene loaded in a real window (`--path . --script <driver>`), camera set to 4 zoom/pan configs, 93 sample points mapped viewport→canvas→`IsoPicking`→cell with 0 mismatches; no engine errors. This drove the camera transform directly; **synthetic mouse events could not be injected**, so real mouse handling is manual-only. The driver lived outside the repo.

- Scene check for steps 5–7 (one-off, 2026-10-15, driver outside the repo): spike scene run in a real window; occlusion fade driven by hand (behind → alpha 0.400, in front → 1.000, hover-behind → 0.400), facing after moves (+Y → SW, +X → SE), layer order Ground, Decals, Shadows, Entities, Air; screenshots visually reviewed. Real input (clicks, Q/E keys, mouse hover) was not exercised → manual.

- Mutation sanity check (2026-10-15, temporary edits reverted): weakening the damage floor, removing the dead-target guard in `Health`, and disabling the duplicate-id check each made tests fail (4 failing tests), confirming those tests detect regressions.
- Runner robustness (2026-10-15): a test file that fails to compile previously made the runner error out before `quit()` and **hang**. It now reports `FAIL <file>: script failed to load/compile` and exits 1 (verified with a deliberately broken file, since removed). Always run the suite with a timeout (`timeout 90 ...`) when scripting it.
- Mutation check for 1.2: reversing the tie-break, ignoring `alive`, making range exclusive, banking idle cooldown, and removing the hitch guard each failed tests (6 failures across 5 mutations); code restored.
- Mutation check for 1.3: win-beats-fail on ties, removing the end-once guard, removing path-ends-at-core, removing the rock-crossing segment check, accepting waves that end after the mission, a broken `in_bounds`, and dropping the wave enemy-id reference check each failed tests (10 failures across 7 mutations); code restored.
- Shipped-data tests assert relations (e.g. MG fires faster than rifle, nest is fixed), not balance values, so tuning doesn't break them.

## Strategy
1. **Pure-logic unit tests (headless)** — IsoProjection, DamageService, DeckState, CommandPoints, targeting filters, objective evaluation, save migration. These are `RefCounted` classes with injected RNG/config.
2. **Scene smoke tests (headless)** — instantiate a scene, run N frames, assert no errors (from M1).
3. **Manual checklists** — visuals, audio, feel, isometric readability (checklist in [specs/isometric-view.md](specs/isometric-view.md)). Reported as "pending manual verification" until the user confirms.
4. **Performance scenarios** — defined in M1/M3 (e.g. N zombies × M turrets); record hardware + measured FPS; no unmeasured claims.

## Required coverage list
From master prompt §18: card cost/spend, draw/reshuffle/hand limits, cooldown/lockout, damage/armor/falloff, target filtering, deployment constraints, wave progression, win/fail & simultaneous conditions, rewards/unlock persistence, save/load/migration, upgrades/synergies, projection round-trip, cell picking edges, ground distance vs ellipse, placement validity, sort anchors, altitude handling.

## Quality gates
No parse errors · no avoidable runtime errors/warnings · no unhandled invalid IDs · no false passes · no unrelated refactors.
