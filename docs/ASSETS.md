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
| Rifle Soldier and Shambler sprite sheets (`assets/sprites/{rifle_soldier,shambler}/{e,se,s,sw,w,nw,n,ne}.png`) | Procedurally rendered by `tools/gen_sprites.gd` from posed body models (two-bone IK limbs, ellipsoid heads with face details, a segmented rifle; 3x3 supersampled, 3-tone shading, 1 px outline). No external assets, no AI. Regenerate (about 2.5 min each): `godot --headless --path . --script tools/gen_sprites.gd -- --units=rifle_soldier,shambler` | Original; project-owned | 2026-10-15. Placeholder-grade. True 8 facings, light always top-left. 3 columns, row-major; frames are 88x72 (soldier) / 72x72 (shambler), foot origin (44,44) / (36,44). They were 48x44 until a clipping test showed the rifle muzzle and falls were cut off at the frame edge, so frames were widened and given 28 px of room below the feet. Soldier (10 frames): 0 idle, 1-4 walk, 5-8 death (falls backwards, drops the rifle), 9 firing recoil (`fire_frame`, shown 0.09 s after each shot). Shambler (10 frames): 0 idle, 1-4 shuffle, 5 attack lunge (`attack_frame`), 6-9 death (falls forwards). Foot origin as above |
| Runner, Brute, RPG soldier, Howitzer sprites (`assets/sprites/{runner,brute,rpg_soldier,howitzer}/{e,se,s,sw,w,nw,n,ne}.png`) | Procedurally rendered by `tools/gen_sprites.gd`. Runner and Brute reuse the zombie rig (stride, lean, scale and clothing swaps); RPG soldier reuses the soldier rig with a launcher; Howitzer is a new model (split trails, shield, elevated barrel). No external assets, no AI. Regenerate: `godot --headless --path . --script tools/gen_sprites.gd -- --units=runner,brute,rpg_soldier,howitzer` | Original; project-owned | 2026-10-16. Placeholder-grade, **art only: no definitions, weapons or cards use them yet** (GDD roster entries: Runner/Brute enemies, RPG, howitzer). True 8 facings. Frames (3 columns, 10 per unit unless noted): Runner 72x72, origin (36,44); layout 0 idle, 1-4 walk, 5 attack lunge, 6-9 death. Brute 80x72, origin (40,54); same layout, 1.3x scale. RPG soldier 124x76, origin (62,46); 0 idle, 1-4 walk, 5-8 death, 9 fire recoil. Howitzer 128x104, origin (64,62); 6 frames: 0 idle, 1 firing with barrel recoil, 2-5 destruction |
| Prop sprites (`assets/sprites/{sandbag_wall,concrete_barrier,crate_stack,oil_drums,tank_trap,jeep,supply_truck,wrecked_car}/{e,se,s,sw,w,nw,n,ne}.png`) | Procedurally rendered by `tools/gen_sprites.gd` from box/cylinder/ellipsoid primitives (same renderer, light and outline as the units). Original designs, no external assets. Layouts: barricades/crates/drums/trap 4 frames (intact, damaged, broken, rubble; 2 columns; sandbag and barrier 80x64, others 64x56); jeep 80x60 and supply truck 112x76 5 frames (idle + 4 destruction, 3 columns); wrecked car 80x56 1 frame. | Generated for this project | Not yet used by any definition |
| Earlier hand-drawn soldier/zombie sheets (`assets/sprites/_handdrawn/`) | Hand-drawn pixel grids via PixelLab `pixelart_workbench draw` (free tool, no AI image generation); the recipes sit beside each sheet | Original; project-owned (PixelLab ToS: https://pixellab.ai/termsofservice) | Archived, not referenced by any definition. 32x32 frames, 5 facings (SE, E, S, NE, N). Faces and silhouettes read better than the procedural ones; kept for comparison or a later hand-polish pass |
| MG Nest sprites (`assets/sprites/mg_nest/{se,e,s,ne,n}.png`) | Same method; sandbag ring generated from an ellipse formula, gun drawn as pixel lines/blocks. Recipes beside each | Original; project-owned | 2026-10-15. Placeholder-grade. Single 32x32 frame per direction (no animation); foot origin (16,22), the barrel points along the facing |
| MG Nest, Gatling Gun, Tank, Helicopter sprites (`assets/sprites/{mg_nest,gatling_gun,tank,helicopter}/{e,se,s,sw,w,nw,n,ne}.png`) | Procedurally rendered by `tools/gen_sprites.gd` (box/cylinder/ellipsoid models, one ray per pixel through the project projection, 3-tone shading, 1 px outline; wreck frames are the same models posed apart, scorched and with fire/smoke blobs). No external assets, no AI. Regenerate: `godot --headless --path . --script tools/gen_sprites.gd -- --units=mg_nest,gatling_gun,tank,helicopter` | Original; project-owned | 2026-10-15. Placeholder-grade. True 8 facings (no mirroring, light always top-left). Frames: MG Nest and Gatling 5 (64x48, origin 32,32): 0 idle, 1-4 destruction (flash, parts flung, settling, wreck). Tank 9 (80x56, origin 40,38): 0 idle, 1-4 track scroll, 5-8 destruction (turret blown off). Helicopter 8 (96x64, origin 48,46): 0-3 rotor spin (always animated, drawn lifted by `altitude`), 4-7 destruction (first two while falling, then crash, then wreck) |
| Earlier hand-drawn MG nest (`assets/sprites/_handdrawn/mg_nest/`) | Hand-drawn pixel grids via PixelLab `pixelart_workbench draw`; recipes beside each sheet | Original; project-owned | Archived, not referenced. 5 facings, one 32x32 frame each |
| Gatling Gun, Tank, Helicopter sprites (`assets/sprites/{gatling_gun,tank,helicopter}/{e,se,s,sw,w,nw,n,ne}.png`) | Procedurally rendered by `tools/gen_sprites.gd` (box/cylinder models, one ray per pixel through the project projection, 3-tone shading, 1 px outline). No external assets, no AI. Regenerate: `godot --headless --path . --script tools/gen_sprites.gd` | Original; project-owned | 2026-10-15. Placeholder-grade. True 8 facings (no mirroring, light always top-left). Frames per sheet: Gatling 1 (64x48, origin 32,32); Tank 5 = idle + 4 track-scroll (80x56, origin 40,38); Helicopter 4 = rotor spin, always animated (96x64, origin 48,46; drawn lifted by `altitude`) |

Facings: every sprite now has all 8 (the 5-mirrored ADR-008 fallback in `SpriteSheet` remains for sheets that lack some) (`SpriteSheet.art_direction`/`faces_left`). Mirroring flips the light direction (top-left becomes top-right) on the three left-hand facings; accepted for placeholders. A direction without a texture falls back to SE. Sheet layout lives in `SpriteSheet` (`scripts/iso/sprite_sheet.gd`) on each unit/enemy definition.

Missing: real (non-placeholder) art. Sprites are ~24 px tall against 64 px tiles: judge the on-screen size manually.

PixelLab MCP tooling is available in the dev environment. Its AI generators cost credits; the workbench (`draw`/`edit`/`inspect`) is free. If AI generation is used, record prompts and license terms here.
