# Spec: Isometric View

Status: draft · Milestone 0.5 · ADR-002/003/004/005/008

## Purpose
Define the single projection, coordinate conventions, picking, draw order, occlusion and sprite rules so gameplay stays flat and rendering is a thin layer.

## Scope / non-goals
In: projection math, picking, ellipses, sorting, occlusion, facings, light. Out: art production, final VFX, pathfinding (M3), 3D collision (explicitly not done).

## Constants (one place: `scripts/iso/iso_projection.gd`)
`TILE_W = 64`, `TILE_H = 32` px. Ground unit = 1 tile. `Z_PX_PER_UNIT` = pixels of vertical offset per 1.0 altitude (initial: `TILE_H`, i.e. 1 altitude unit ≈ one tile-height up; tune).

## Conventions
- Ground +X → screen down-right; ground +Y → screen down-left. Origin maps to screen (0,0).
- **ground_to_screen(g: Vector2) -> Vector2**: `((g.x − g.y)·TW/2, (g.x + g.y)·TH/2)`
- **screen_to_ground(s: Vector2) -> Vector2**: `x = s.x/TW + s.y/TH`, `y = s.y/TH − s.x/TW`
- **ground_to_screen_z(g, z)**: ground_to_screen(g) with `y −= z·Z_PX_PER_UNIT`. Shadow is drawn at `z = 0`.
- **cell_of(g) -> Vector2i** = `floor(g)`; **cell_center(c) -> Vector2** = `c + (0.5, 0.5)`. Cell (cx,cy) diamond center on screen = ground_to_screen(c + 0.5).
- **Circle→ellipse**: ground circle radius `r` → screen ellipse centered at ground_to_screen(center), semi-axes `a = r·TW/√2`, `b = r·TH/√2` (axis-aligned, 2:1). Helper `ellipse_radii(r) -> Vector2`.
- Distances/ranges/blasts/arcs are computed in ground space only.
- TileMapLayer: tile shape Isometric, tile size 64x32. **To verify in spike:** which `tile_layout` (Diamond Right/Down) makes Godot's `map_to_local` agree with `ground_to_screen(cell_center)`; the spike test asserts agreement and the answer is recorded here.

## Draw order
Layers bottom→top: ground TileMapLayer → decals/shadows → ground entities node with `y_sort_enabled` → air layer (own y-sort, above ground) → FX layer → HUD (CanvasLayer). Sort anchor = footprint base point (center of the footprint on the ground, which is the node's origin). Sprites are offset up from the origin so the origin is the foot.
Air units: node position = ground position (so sorting among air is by ground y), sprite offset by z, separate shadow sprite on ground layer at z=0.

## Occlusion (ADR-005, proposed)
Tall structures/props expose a fade rule: when any unit/enemy/placement preview's *screen rect* overlaps the structure's screen rect and that entity is behind it (sort anchor y less), structure alpha lerps to 0.4 (≈0.15 s). Validate readability in spike; fallback to silhouette shader.

## Sprites
8 facings: E, SE, S, SW, W, NW, N, NE in **screen** terms. They map to the 8 principal *ground* directions: E=(1,-1), SE=(1,0), S=(1,1), SW=(0,1), W=(-1,1), NW=(-1,0), N=(-1,-1), NE=(0,-1). Facing is derived by quantizing the **ground-space** angle into 45° sectors centered on those directions (`IsoProjection.facing_from_ground_dir`); quantizing the screen angle was rejected because ground +X projects to 26.6°, too close to a sector boundary. Zero velocity returns -1 (keep previous facing). Light from top-left; shadows fall toward bottom-right. Placeholders draw a facing wedge.

## Input
Mouse position → camera/canvas inverse transform → `screen_to_ground` → cell / circle. Previews use ground cell/circle, never the sprite position. Must be correct at all zoom levels and camera offsets.

## Failure cases
Mouse outside map → no cell valid; NaN/inf inputs rejected by callers (not projection); zoom 0 prevented by camera clamp.

## Acceptance criteria (automated)
1. `screen_to_ground(ground_to_screen(p)) ≈ p` (eps 1e-4) for samples incl. negative and |coord| up to 10 000.
2. `ground_to_screen(Vector2(1,0))` = (32,16); `(0,1)` = (−32,16); `(1,1)` = (0,32).
3. `cell_of` correct at cell corners/edges/negatives (e.g. (−0.0001, 0) → cell (−1,0)); screen points on tile diamond edges resolve deterministically.
4. Sampled points on a ground circle of radius r project onto the ellipse `(x/a)²+(y/b)²=1` within eps.
5. Altitude: z shifts screen y by `−z·Z_PX_PER_UNIT` and leaves x unchanged; ground coords unaffected.
6. Facing quantization for the 8 axis/diagonal ground directions returns expected facings.
7. Sort comparison: entity with greater ground (x+y) sorts in front.
8. TileMapLayer `map_to_local(cell)` equals `ground_to_screen(cell_center)` for sample cells (once layout chosen).

## Manual checklist (spike)
Unit behind tall object visible after fade · shadows present on ground & air · AoE ellipse matches cells it covers · hover highlight lands on the cell under the cursor at zoom 0.5/1/2 and with panned camera · 8 facings readable.

## Test plan
`tests/test_iso_projection.gd` (1–7), `tests/test_iso_tilemap.gd` (8, needs a TileMapLayer instance headless), manual checklist in the spike scene.
