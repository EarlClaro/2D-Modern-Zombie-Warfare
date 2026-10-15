# Decision Log (ADRs)

Format: ID · Status · Decision · Rationale · Consequences. Statuses: Accepted (stated in master prompt), Proposed (needs user approval), Superseded.

## ADR-001 — Engine and language · Accepted
Godot 4.x, typed GDScript. Installed: 4.7.2-stable. Rationale: master prompt default; solo-dev friendly. Consequence: no C#/GDExtension unless a measured need arises.

## ADR-002 — Fixed 2:1 isometric camera · Accepted
Logical floor tile 64x32 px diamond (~26.57°). Tile size is a constant in one place (`IsoProjection`). Camera pan + zoom only, no rotation. Change requires a new ADR.
Consequences: art authored at 2:1; 8-direction sprites; ellipse AoE indicators.

## ADR-003 — Ground-plane truth, altitude separate · Accepted
Gameplay in ground coordinates measured in **tiles** (float); altitude `z` is a separate float; projection used only for rendering/input via `IsoProjection.ground_to_screen / screen_to_ground`. Convention: ground +X = screen down-right; ground +Y = screen down-left.
Consequences: ranges/radii in tiles; no projection math elsewhere; a ground circle of radius r is an axis-aligned screen ellipse with semi-axes `r·TW/√2` × `r·TH/√2`.

## ADR-004 — Y-sort and layering · Accepted (details in spec)
Footprint base point is the sort anchor. Layers: ground → shadows → ground entities (y-sorted) → air → FX → HUD. Aircraft never share the ground y-sort group.

## ADR-005 — Occlusion approach: fade occluders · Accepted (2026-10-15)
Tall structures/props fade to ~40% alpha when a unit/enemy/placement preview is behind them on screen. Chosen over silhouette shaders for simplicity with placeholder art and robustness at horde density. Validate in Milestone 0.5; fallback is outline-silhouette shader. Look/feel is re-confirmed by the user at spike exit.

## ADR-006 — Test framework: minimal custom headless runner (no GUT yet) · Accepted (2026-10-15)
`godot --headless --path . --script tests/run_tests.gd` runs `tests/test_*.gd` (each exposes `test_*` methods, uses a tiny assert helper, exits non-zero on failure). Rationale: no external dependency, trivial to verify, pure-logic classes need little tooling. Revisit GUT if we need mocking/scene tests. Implemented in Milestone 0.5 step 1 (`tests/run_tests.gd`, `tests/test_case.gd`); verified it exits 1 on a failing assertion.

## ADR-007 — Mission end resolution · Accepted (2026-10-15)
Objectives evaluated once per tick after damage/death resolution; if win and fail are true on the same tick, **fail wins**. Ends mission once; further events ignored.

## ADR-008 — 8-direction sprites · Accepted (2026-10-15)
Units/vehicles/enemies use 8 facings (placeholders show facing). Fallback: 5 mirrored directions if art cost is too high; requires updating ASSETS.md.

## ADR-009 — Display baseline · Accepted (set in project.godot)
1920x1080 base viewport, `canvas_items` stretch, nearest texture filtering for pixel art. Revisit in Milestone 7 for UI scaling.
