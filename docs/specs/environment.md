# Spec: Environment (terrain, scenery, base, big map, atmosphere)

Status: **v0.1, implemented 2026-10-16 (all five parts); manual checks (look, mood, density, readability) are the user's** (requested directly by the user, outside the M2 plan; no hard boundary changes: camera/projection untouched, offline, original art only). Builds on [isometric-view.md](isometric-view.md), [card-loop.md](card-loop.md) and [props-and-cover.md](props-and-cover.md).

## Purpose
Turn the 24x24 flat-colour test field into a place: varied ground, trees, trash, ruined and intact buildings, a real base with a perimeter, a much larger map, and a day/night cycle with weather. Presentation first; the only rules touched are what the new things occupy.

## Scope
**1. Terrain.** Tile art is a generated pixel atlas (`assets/tiles/terrain.png`, tool `tools/gen_tiles.gd`) instead of flat diamonds. Several look-variants per terrain, picked per cell from a hash of the cell (cosmetic only, deterministic). New map characters, besides `.` grass, `=` road, `#` rock: `,` dirt (walkable, buildable), `p` paved concrete (walkable, buildable; base floor), `x` rubble (walkable, not buildable), `w` water (blocked). Walkable/buildable flags in the tile data must match `MapDefinition` (existing test, extended).

**2. Scenery.** Static, non-interactive decoration: `SceneryDefinition` (id, sprite, footprint in cells, `blocks_build`, `fades` when something stands behind it) loaded by `ContentDb` from `data/scenery/`. A map lists placements as text lines `id x y [facing]` (`MapDefinition.scenery`). Scenery draws on the y-sorted entity layer, its footprint cells are not buildable, and it must not sit on an enemy's path (validated per mission). Art: trees (oak, pine, dead), bushes, boulders, logs, trash piles, dumpster, tyres, scrap, street lamp, signs, bench, wrecked car, houses, shops, apartment blocks, warehouse, their ruined versions, rubble.

**3. Base.** The core is drawn as an HQ bunker sprite (instead of the blue box) with damage states by hit-point fraction (intact, damaged, burning, ruined). A compound around it is built from scenery: perimeter walls and fences, a gate where the road enters, corner watchtowers, floodlights, tents, generator, fuel tank, container, radar mast, flag, plaza of paved tiles. Core rules (position, health, attack range) are unchanged: the core is still one cell, the HQ art is about 1.6 cells wide.

**4. Big map.** New map `outskirts` (64x48, the MapDefinition limit is 128) with a winding road, a river with a bridge, dirt and rubble, forest, a ruined district and the base compound in a corner; new mission `x2_outskirts` with two spawn points (merging lanes), Spitters in the waves, a deploy radius that covers the compound. Existing maps and missions stay untouched as regression scenarios. The map and its scenery list are produced by `tools/gen_outskirts.gd` (seeded) so they can be regenerated.

**5. Atmosphere.** Presentation-only `Atmosphere` layer: a time of day (dawn, day, dusk, night) that tints the whole scene through a `CanvasModulate`, and a weather state (clear, rain, fog, dust) drawn as particles and an overlay above the world. Missions set the start time, the length of a full day (0 = frozen) and the weather. Night brightens glows (fires, explosions, floodlights, muzzle flashes keep their colour). No gameplay effect.

## Non-goals
Terrain that slows or hurts, enemy pathfinding around scenery (still straight waypoint lines, Milestone 3), destructible scenery, interiors, seasons, wind affecting gameplay, a minimap, a map editor, save data, audio for weather (placeholder only if cheap).

## Acceptance criteria
1. Every map character has tile art and matching walkable/buildable flags; variants never change the flags; same cell, same variant every run.
2. Scenery definitions validate (id, sprite, footprint >= 1x1); a map with an unknown scenery id, an out-of-bounds placement or an overlapping footprint is a content error; shipped data is clean.
3. Scenery footprints are not buildable and not offered for card placement; a path through scenery fails mission validation.
4. The HQ shows the right damage state for the core's hit points; core health, targeting and mission outcome are unchanged.
5. `outskirts` is a valid 64x48 map; the mission loads; every enemy path segment is walkable and free of scenery; do-nothing loses and a sensible mix wins (sweep numbers in BALANCE.md).
6. Time of day and weather are deterministic functions of elapsed time and config (pure, unit-tested); the layer never touches the simulation.
7. Frame rate with the big map, ~400 scenery sprites and rain stays far above 60 FPS on the dev laptop (measured with `tools/perf_fps.gd`, reported as measured).
8. Manual (user): looks and readability of tiles/scenery/base, day-night mood, weather density, whether units stay readable against the new ground.

## Risks
- Busy ground can make units hard to read. Mitigation: low-contrast ground palettes, unit outlines already dark; check in screenshots at normal zoom.
- Large scenery can hide units: tall pieces fade when something is behind them (same fade rule as the core).
- Draw cost of many y-sorted sprites: measured in criterion 7; if needed, bake static scenery.
