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
- ☑ 5 placeholder unit (`PlaceholderUnit`: LMB moves it at 3 tiles/s in ground space, 8-way facing wedge, shadow) + tall structures (`PlaceholderStructure`, y-sorted, fade via `IsoOcclusion`) · ☑ 6 flyer (`PlaceholderFlyer`: orbits at altitude 3.0 on the Air layer, height line, ground shadow) · ☑ 7 AoE ellipse (`IsoAoeIndicator`, Q/E change radius 0.5–8, dots mark cells whose centre is in range) · ☑ 8 doc pass (this file, isometric-view, TESTING, ROADMAP, CHANGELOG).
- Exit: user approved the spike and the decisions below on 2026-10-15. Milestone 0.5 complete.
- Run the scene: `"$GODOT" --path . scenes/dev/iso_spike.tscn` (or open it in the editor and press F6). Controls: WASD/arrows pan, mouse wheel zoom toward cursor (0.5–3.0), middle-mouse drag pan.

## Decisions recorded at exit (approved 2026-10-15)
| Item | Value |
|---|---|
| Tile size | 64x32 px, ground unit = 1 tile |
| Sprite directions | 8 (facings map to the 8 principal ground directions) |
| Occlusion | Fade occluder to alpha 0.4 over 0.15 s when a subject is behind it and screen rects overlap (ADR-005) |
| Light direction | Top-left: faces lit top > lower-left > lower-right; shadows shift along ground +X (screen down-right), more with altitude |
| TileMapLayer | `DIAMOND_DOWN`, layer position `IsoProjection.TILEMAP_LAYER_OFFSET` = (−32, 0) |
| Z_PX_PER_UNIT | 32 (1 altitude unit = 1 tile height up) |
| Multi-cell sort anchor | Footprint centre in ground space (ADR-010) |
| Layers | Ground, Decals, Shadows, Entities (y-sort), Air (y-sort), HUD |

## Exit criteria
All automated tests pass (command output shown) · headless import clean · manual checklist (isometric-view.md) completed by the user in the editor · user approves the look/feel. **Do not start Milestone 1 until approved.**

## Risks
TileMapLayer iso layout mismatch (mitigated by test 8) · y-sort of mixed-size sprites (mitigated by footprint-origin convention) · mouse picking with camera zoom/offset (use canvas inverse transform).
