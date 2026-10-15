# Changelog

## Milestone 1 — Combat vertical slice (in progress)
- 1.1: `ContentDefinition` base, `WeaponDefinition`, `UnitDefinition`, `EnemyDefinition`, `ContentDb` (validation, duplicate/unknown-id reporting), `Health`, `DamageService` (armor with min-damage floor, blast falloff). Data: weapons `rifle`, `mg`; units `rifle_soldier`, `mg_nest`; enemy `shambler`. 34 new tests (60 total, all pass).

- 1.2: `TargetCandidate`, `TargetingService` (nearest, inclusive range, tie → lowest id, ground distance), `WeaponState` (fire cadence, carry-over, no idle burst, hitch guard). 23 new tests (83 total, all pass).
- Test runner: scripts that fail to compile now count as failures instead of hanging the run.

## Milestone 0.5 — Isometric spike (complete, approved 2026-10-15)
- Added headless test runner (`tests/run_tests.gd`, `tests/test_case.gd`).
- Added `IsoProjection` (`scripts/iso/iso_projection.gd`) with 9 tests (known values, round-trip, cell edges, ellipse, altitude, facing, sort key). All pass.
- Isometric spec: facings quantized in ground space (documented why).
- ADR-005..008 accepted.
- Spike scene `scenes/dev/iso_spike.tscn`: 16x16 placeholder TileMapLayer (code-built TileSet with walkable/buildable data), `IsoCamera` (pan/zoom toward cursor), `IsoPicking`, `IsoCellHighlight`, debug readout.
- Spike steps 5–7: `IsoEntity` base, `PlaceholderUnit` (ground-plane movement, 8-way facing wedge), `PlaceholderStructure` (tall box, footprint-centre sort anchor), `IsoOcclusion` (fade rule), `IsoShadow`, `PlaceholderFlyer` (altitude, Air layer), `IsoAoeIndicator` (projected ground circle + covered-cell dots). New projection helpers: `altitude_offset`, `cell_screen_rect`, `ground_circle_polygon`, `ground_dir_of_facing`, `facing_name`. 14 new tests (26 total, all pass).
- Resolved TileMapLayer layout: `DIAMOND_DOWN` + layer offset (−32,0) via `IsoProjection.TILEMAP_LAYER_OFFSET`; 3 tilemap tests added (12 total, all pass).

## Milestone 0 — Specification foundation
- Added `project.godot` (Godot 4.7.2, 1920x1080 base, canvas_items stretch, nearest texture filter) and `.gitignore`. Headless `--import` ran without errors.
- Added AGENTS.md, README.md, and docs: GDD, ARCHITECTURE, ROADMAP, DECISIONS, TESTING, ASSETS, BALANCE, specs (isometric-view, deck-and-economy, milestone-0.5-iso-spike, combat-vertical-slice).
- No gameplay code yet.
