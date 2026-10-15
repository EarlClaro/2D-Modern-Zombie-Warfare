# Spec: Milestone 0.5 — Isometric Technical Spike

Purpose: prove the isometric foundation before any combat. Non-goals: combat, cards, UI beyond a debug label, real art.

## Deliverables (proposed implementation order, each a small commit)
1. **Test runner** (`tests/run_tests.gd`, `tests/test_helpers.gd`) per ADR-006 + first trivial test; verify it fails on a failing assertion and exits non-zero.
2. **IsoProjection** (`scripts/iso/iso_projection.gd`) + `tests/test_iso_projection.gd` (isometric-view criteria 1–6).
3. **Spike scene** `scenes/dev/iso_spike.tscn`: 16x16 TileMapLayer (programmatic placeholder TileSet of colored diamonds; walkable/blocked custom data) + Camera2D with pan (WASD/edge/MMB drag) and zoom (wheel, clamped).
4. **Picking + hover highlight** (`scripts/iso/iso_picking.gd`): cell under cursor, diamond highlight; debug label showing ground/cell. Tilemap agreement test (criterion 8); record chosen `tile_layout`.
5. **Placeholder unit**: moves toward clicked cell in 8 directions at constant ground speed, facing wedge, shadow, y-sorted. Includes a tall placeholder structure for sorting/occlusion with fade.
6. **Flying placeholder**: orbits ground path at altitude z with ground shadow, on air layer.
7. **AoE ellipse indicator**: draws ground circle radius r at hovered position using `ellipse_radii`; key to change r.
8. Update isometric-view spec with decisions, TESTING.md with real commands, ROADMAP, CHANGELOG.

## Progress
- ☑ 1 test runner · ☑ 2 IsoProjection + tests · ☑ 3 spike scene (`scenes/dev/iso_spike.tscn`, 16x16 placeholder TileMapLayer, `IsoCamera` pan/zoom) · ☑ 4 picking + hover highlight + tilemap agreement test (layout = DIAMOND_DOWN, layer offset (−32,0)).
- ☐ 5 placeholder unit + tall structure · ☐ 6 flyer · ☐ 7 AoE ellipse · ☐ 8 final doc pass.
- Run the scene: `"$GODOT" --path . scenes/dev/iso_spike.tscn` (or open it in the editor and press F6). Controls: WASD/arrows pan, mouse wheel zoom toward cursor (0.5–3.0), middle-mouse drag pan.

## Decisions to record at exit
Tile size confirmed · sprite directions (8) · occlusion approach (fade vs silhouette) · light direction · TileMapLayer layout enum · Z_PX_PER_UNIT.

## Exit criteria
All automated tests pass (command output shown) · headless import clean · manual checklist (isometric-view.md) completed by the user in the editor · user approves the look/feel. **Do not start Milestone 1 until approved.**

## Risks
TileMapLayer iso layout mismatch (mitigated by test 8) · y-sort of mixed-size sprites (mitigated by footprint-origin convention) · mouse picking with camera zoom/offset (use canvas inverse transform).
