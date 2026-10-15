# Testing Strategy

## Current state
- Custom headless runner (ADR-006) implemented. GUT not used.
- Verified commands (2026-10-15):
  - `"$GODOT" --headless --path . --import --quit` — import/parse check; run it after adding new `class_name` scripts.
  - `"$GODOT" --headless --path . --script tests/run_tests.gd` — 60 tests (26 iso + 12 `DamageService` + 8 `Health` + 14 `ContentDb`/definitions), 0 failed, exit 0. Confirmed it reports `FAIL` and exits 1 when a test fails (temporary failing test, since removed).
- Writing tests: file `tests/test_*.gd`, `extends TestCase`, methods `test_*`; helpers `assert_true/eq/near/vec_near`. Prefer `preload` of the script under test.

- Scene smoke check (one-off, 2026-10-15): spike scene loaded in a real window (`--path . --script <driver>`), camera set to 4 zoom/pan configs, 93 sample points mapped viewport→canvas→`IsoPicking`→cell with 0 mismatches; no engine errors. This drove the camera transform directly; **synthetic mouse events could not be injected**, so real mouse handling is manual-only. The driver lived outside the repo.

- Scene check for steps 5–7 (one-off, 2026-10-15, driver outside the repo): spike scene run in a real window; occlusion fade driven by hand (behind → alpha 0.400, in front → 1.000, hover-behind → 0.400), facing after moves (+Y → SW, +X → SE), layer order Ground, Decals, Shadows, Entities, Air; screenshots visually reviewed. Real input (clicks, Q/E keys, mouse hover) was not exercised → manual.

- Mutation sanity check (2026-10-15, temporary edits reverted): weakening the damage floor, removing the dead-target guard in `Health`, and disabling the duplicate-id check each made tests fail (4 failing tests), confirming those tests detect regressions.
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
