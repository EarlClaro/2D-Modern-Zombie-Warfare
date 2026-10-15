# Testing Strategy

## Current state
- Custom headless runner (ADR-006) implemented. GUT not used.
- Verified commands (2026-10-15):
  - `"$GODOT" --headless --path . --import --quit` — import/parse check; run it after adding new `class_name` scripts.
  - `"$GODOT" --headless --path . --script tests/run_tests.gd` — 9 tests, 0 failed, exit 0. Confirmed it reports `FAIL` and exits 1 when a test fails (temporary failing test, since removed).
- Writing tests: file `tests/test_*.gd`, `extends TestCase`, methods `test_*`; helpers `assert_true/eq/near/vec_near`. Prefer `preload` of the script under test.

## Strategy
1. **Pure-logic unit tests (headless)** — IsoProjection, DamageService, DeckState, CommandPoints, targeting filters, objective evaluation, save migration. These are `RefCounted` classes with injected RNG/config.
2. **Scene smoke tests (headless)** — instantiate a scene, run N frames, assert no errors (from M1).
3. **Manual checklists** — visuals, audio, feel, isometric readability (checklist in [specs/isometric-view.md](specs/isometric-view.md)). Reported as "pending manual verification" until the user confirms.
4. **Performance scenarios** — defined in M1/M3 (e.g. N zombies × M turrets); record hardware + measured FPS; no unmeasured claims.

## Required coverage list
From master prompt §18: card cost/spend, draw/reshuffle/hand limits, cooldown/lockout, damage/armor/falloff, target filtering, deployment constraints, wave progression, win/fail & simultaneous conditions, rewards/unlock persistence, save/load/migration, upgrades/synergies, projection round-trip, cell picking edges, ground distance vs ellipse, placement validity, sort anchors, altitude handling.

## Quality gates
No parse errors · no avoidable runtime errors/warnings · no unhandled invalid IDs · no false passes · no unrelated refactors.
