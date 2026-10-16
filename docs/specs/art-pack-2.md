# Spec: Art pack 2 (terrains, buildings, props, vehicles, aircraft, emplacements, infantry, base, nature)

Status: **v0.2, implemented 2026-10-16; manual checks (look, scale, readability) are the user's** (requested directly by the user, outside the M2 plan; no hard-boundary changes: camera/projection untouched, offline, original art only). Builds on [environment.md](environment.md) and [props-and-cover.md](props-and-cover.md).

## Purpose
The environment pass proved the pipeline (procedural renderer, atlas, scenery data, map generator). This pass widens the catalogue so maps can be dressed as towns, farmland, forests, deserts, snowfields, airfields and fortified bases, and so the military side has more to show. It is content breadth, not new rules.

## Scope: minimum counts (each is a floor, every item is a separate sprite set or tile)
| Category (`cat`) | Min | Contents (planned; final list is in `docs/ASSETS.md`) |
|---|---|---|
| terrain tiles | 20 new (made 26) | meadow, dry grass, leaf litter, moss, mud, sand, snow, ice, gravel, asphalt, lane line (x and y), cracked asphalt, cobblestone, brick paving, concrete tile, hazard pad, steel deck, wood planks, farmland, ash, crater, shallow water, hardpan, runway (x and y) |
| buildings | 20 | town and country: cottage, bungalow, row houses, villa, farmhouse, barn, church, school, clinic, hospital, petrol station, diner, supermarket, garage, office block, tower block, factory, water tower, police station, fire station, bank, motel, train station, shed, greenhouse, ruined and burnt variants |
| props | 20 | pallets, boxes, cones, road barricade, mailbox, phone booth, bus stop, vending machine, hydrant, billboard, traffic light, power pole, transformer, AC unit, dish, wheelie bin, shopping cart, petrol pump, fountain, gravestone, picnic table, swing set, hay bale, well, scarecrow, tarp |
| military vehicles | 10 | wheeled APC, tracked IFV, light tank, heavy tank, self-propelled gun, rocket launcher truck, anti-air vehicle, armoured car, humvee, fuel tanker, ambulance, command truck, engineer dozer |
| airforce | 10 | fighter, attack jet, bomber, cargo plane, transport helicopter, gunship, utility helicopter, tiltrotor, drone, crashed jet, crashed helicopter, crashed cargo plane |
| emplacements | 10 | pillbox, AA gun, mortar pit, SAM launcher, searchlight post, anti-tank gun, sniper nest, foxhole, trench, razor wire, dragon's teeth, field artillery, ammo dump, radar dish |
| infantry | 10 | static poses: sentry, sniper, machine gunner, medic, engineer, grenadier, officer, flamethrower, heavy gunner, scout, radio operator, fallen soldier |
| base (buildings, walls, props) | 20 | hangar, control tower, mess hall, armoury, motor pool, comms centre, medical bay, guard shack, HQ building, HESCO barrier, blast wall corner, sliding gate, razor-wire fence, sandbag corner, camo net, antenna array, water tank, generator shed, fuel pump, latrine, supply stack, ammo pile, weapon rack, map table, warning sign, hazard drums, cable reel, field kitchen, medical tent, command tent |
| nature | 20 | birch, willow, palm, autumn maple, cypress, sapling, stump, snowy pine, dead pine, burnt tree, giant oak, grass tuft, tall grass, reeds, fern, flowers, mushrooms, lily pads, mossy boulder, slate outcrop, cliff chunk, dune, cactus, berry bush, thorn bush, dry bush, snow mound, ice chunk, branches |

## Design
**Where the models live.** `tools/gen_sprites.gd` stays the renderer and keeps its models. New models are written in pack files `tools/sprite_packs/pack_<name>.gd` (one per theme). A pack provides `specs()` (render specs, one per sprite set: dir, name, category, `k`, `ss`, facings, optional footprint/fades/glow overrides), `MATS` (extra palette entries, prefixed per pack) and `build(m, unit, frame) -> bool`. `gen_sprites.gd` discovers the packs, merges their materials and renders their specs; `--units=a,b` selects sets as before. Rendering gets a screen bounding-box cull so a 150-primitive model is no longer slow; existing sprites must come out byte-identical (checked).

**Scenery data from the art.** The frame size and origin are already written to `frame.json`; it now also records the ground footprint (cells, from the model extents) and the height, so `tools/gen_scenery_data.gd` makes the definitions of every pack spec without a hand-written table (footprint and fade override in the spec when the estimate is wrong). Sets rendered with the four diagonal facings (vehicles, aircraft, emplacements, infantry) get `<id>` (nose or long side along +x, `facing se` or `nw`) and `<id>_y` (along +y, `facing se` or `nw` again picks the art that points the other way), so a map can park them in any of the four diagonal directions.

**Terrain.** One table (`TerrainCatalog`: id, map character, row, walkable, buildable, flat colour) replaces the two lists that had to be kept in step by a test. `MapDefinition` and `IsoTileSet` read it; `tools/gen_tiles.gd` paints the atlas from it (4 look-variants per terrain). New characters are listed in `docs/ASSETS.md`. Existing characters keep their meaning.

**Use in the game.** All new sets are scenery (not buildable, not on enemy paths, fade when tall). The `outskirts` map generator uses the new terrain, nature, town and base pieces (more varied districts, a proper motor pool, aircraft on the helipad apron, emplacements on the perimeter); `x2_outskirts` and `x3_storm_night` keep their waves and rules. Vehicles, aircraft and infantry are dressing: static, no hit points, not selectable, not cards. Making any of them a playable unit is a separate, later task with its own balance work.

## Non-goals
Animated or destructible versions of the new sets, new card or enemy rules, terrain with movement effects, edge blending between terrains, new maps or missions, audio.

## Acceptance criteria
1. Every pack spec renders every listed facing; the files exist, have the size in `frame.json`, visible art, and no frame is clipped by its edge.
2. Category counts meet the minimums above (tile count counts atlas rows, not variants); ids are unique across all content.
3. `TerrainCatalog` rows are contiguous from 0, characters unique and in `MapDefinition.LEGEND`, the atlas has one row per terrain, flags in tile data equal the map flags; existing maps validate unchanged.
4. Every new scenery definition validates (sprite, footprint, display name); the shipped maps still load with no content errors; the full test suite passes.
5. Re-rendered existing sprites are byte-identical to the committed ones.
6. Frame rate of `tools/perf_world.gd` on the dressed `outskirts` is no worse than the figures in BALANCE.md within noise (reported as measured; the machine is not quiet).
7. Manual (user): look, scale and readability of every new set against the terrain, night glows, whether any set reads badly.

## Risks
- ~150 new definitions load at start-up (textures included): measure the load time.
- Static vehicles and infantry could be mistaken for playable units: keep them out of cards and choose poses that read as dressing (parked, posted, fallen).
- Procedural art quality varies by theme: contact sheets are reviewed per pack and the weak sets redrawn before commit.

## Result (2026-10-16)
Counts made: terrains 26 new (33 in all), nature 31, buildings 33 (26 intact, 7 ruined or burnt), props 34, vehicles 15, aircraft 14, emplacements 15, infantry 14, base 36 (192 sets, 282 new scenery definitions). Existing sprites re-render byte-identical. Tests: 497 pass. `outskirts` carries 413 scenery pieces; `tools/perf_world.gd` (windowed 1920x1080, MX330, machine not quiet) 77 to 84 FPS average at night in rain with 416 to 499 enemies and 413 pieces.
Follow-up from user feedback the same day: night tint and light pools (Atmosphere), ground shadows for decorations (`SceneryShadows`), and a scale audit (a soldier is 0.94 tiles tall; ground cover must stay far below that, guarded by a height table in `tests/test_art_pack_2.gd`).
Known limits: the renderer draws a tilted cylinder only when its local +z points away from the camera, so packs build tilted round parts from crossed boxes or draw cylinders twice with opposite axes (fixing `_hit` could change older sprites). Weakest sets by the authors' own reading: bomber, crashed helicopter, ice chunk, cliff chunk, shopping cart, camo net, sandbag corner. Vehicles, aircraft and infantry are static dressing only (no stats, not cards).
