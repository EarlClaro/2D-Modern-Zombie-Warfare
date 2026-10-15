# Assets

## Policy
Original or properly licensed only. No assets, characters, UI, logos or designs copied from existing games. Every non-trivial asset gets a row below (source, license, date, tool/prompt if AI-generated). AI-generated placeholders must be marked and kept visually consistent.

## Conventions
| Item | Value |
|---|---|
| Projection | 2:1 dimetric, fixed camera |
| Floor tile | 64x32 px diamond |
| Light direction | top-left; shadows toward bottom-right |
| Facings | 8 (E, SE, S, SW, W, NW, N, NE); 5-mirrored fallback (ADR-008) |
| Sprite origin | footprint base point (foot/ground contact) = node origin; sprite drawn above it |
| Shadow | soft dark ellipse (2:1) at ground position; scales/fades with altitude |
| Animation fps | idle/walk 8–12, attack 12–15 (initial; revisit in M7) |
| Filtering | nearest |
| Placeholders | colored iso diamonds/boxes with facing wedge until the loop is fun |
| Style | shared outline/shading style across tiles, units, buildings |

Folders: `assets/{sprites,tiles,animations,audio,fonts}` (created when first asset is added).

## Provenance table
| Asset | Source | License | Notes |
|---|---|---|---|
| Placeholder sound effects (rifle shot, MG shot, impact, death, alert) | Generated procedurally in code by `scripts/core/sfx_factory.gd` (noise/sine synthesis, fixed seeds) | Original, no third-party material; project-owned | Crude on purpose; replace in Milestone 7 |
| Placeholder visuals (tiles, units, enemies, core, effects) | Drawn in code (`_draw`, generated tile atlas) | Original | No image files exist yet |

PixelLab MCP tooling is available in the dev environment for generating pixel-art placeholders; if used, record prompts and license terms here.
