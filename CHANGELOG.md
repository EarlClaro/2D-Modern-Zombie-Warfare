# Changelog

## Milestone 0.5 — Isometric spike (in progress)
- Added headless test runner (`tests/run_tests.gd`, `tests/test_case.gd`).
- Added `IsoProjection` (`scripts/iso/iso_projection.gd`) with 9 tests (known values, round-trip, cell edges, ellipse, altitude, facing, sort key). All pass.
- Isometric spec: facings quantized in ground space (documented why).
- ADR-005..008 accepted.
- Spike scene `scenes/dev/iso_spike.tscn`: 16x16 placeholder TileMapLayer (code-built TileSet with walkable/buildable data), `IsoCamera` (pan/zoom toward cursor), `IsoPicking`, `IsoCellHighlight`, debug readout.
- Resolved TileMapLayer layout: `DIAMOND_DOWN` + layer offset (−32,0) via `IsoProjection.TILEMAP_LAYER_OFFSET`; 3 tilemap tests added (12 total, all pass).

## Milestone 0 — Specification foundation
- Added `project.godot` (Godot 4.7.2, 1920x1080 base, canvas_items stretch, nearest texture filter) and `.gitignore`. Headless `--import` ran without errors.
- Added AGENTS.md, README.md, and docs: GDD, ARCHITECTURE, ROADMAP, DECISIONS, TESTING, ASSETS, BALANCE, specs (isometric-view, deck-and-economy, milestone-0.5-iso-spike, combat-vertical-slice).
- No gameplay code yet.
