# Spec: Filling the art and sound gaps

Status: **v0.1, started 2026-10-18** (the user said "do it all" after an audit of what was still a placeholder).

## What was missing (audit 2026-10-18)
Code-drawn placeholders: the core in 12 missions (a blue cube), the Barracks, the Combat Drone, the mines and the noise-lure beacon, all combat effects (muzzle flashes, explosions, smoke, shells), the cursor and cell highlights, the health bars. No title art, no mission thumbnails. All sound is synthesised noise and sine tones; there is no music.

## Method
Art is made the v1 way: models rendered by `tools/gen_sprites.gd` (a theme pack, `tools/sprite_packs/pack_gameplay.gd`), pixel pieces drawn in code. No pxl, no AI generation, nothing copied. Sound and music are synthesised in code too.

## Increments
1. **G.1 Sprites for the placeholders (done 2026-10-18).**
   - The core: all 12 missions that had the blue cube now name `hq_bunker` (the command bunker the other 9 already used). Presentation only: radius, health and footprint are unchanged.
   - `unit_barracks` (4 facings, 4 frames: intact, damaged, burning, ruin) for `data/units/barracks.tres`; `combat_drone` (8 facings, 2 rotor frames, always animating) for `data/units/combat_drone.tres`; `field_mine` and `field_beacon` drawn by `FieldEntityView` (the red blink and the pulsing ring are still drawn on top).
   - Tests: `tests/test_gameplay_sprites.gd`.
2. **G.2 Combat effects as sprites (done 2026-10-18).** `tools/gen_fx_sheets.gd` paints three pixel strips into `assets/fx/` (explosion: fireball swelling then cooling, smoke puff, muzzle flash); `FxSheet` draws a frame by progress; `Explosion`, `VehicleExplosion`, `DeathPuff` and `MuzzleFlash` use them, and fall back to their old circles when a strip is missing. The ground shockwave ring and scorch mark are unchanged, so the visible blast still matches the damage radius. Tracers, sparks and acid stay as thin drawn lines (they are lines).
3. **G.3 Title screen and mission thumbnails (done 2026-10-18).** `tools/gen_title_art.gd` paints `assets/ui/title.png` (480 x 270, shown 4x behind the main menu and its sub-screens): night sky, moon, two skylines, a searchlight, sandbags, the bunker and a watchtower. `MissionThumbnail` (`ui/mission_thumbnail.gd`) draws each mission's map as a small isometric picture (terrain colours, the core in blue, the enemy spawns in red) in the mission list's detail pane; made on request and cached, so there are no files to keep in step with the maps.
4. **G.4 Music (done 2026-10-18).** `MusicFactory` writes four tracks in code (no files): a slow A-minor menu loop (~25 s), a driving D-minor battle loop (~18 s) with drums, and a win and a lose sting. `MusicService` builds a loop on a worker thread the first time (about a second) and keeps it for the session; it plays on a new "Music" bus. New setting `music_volume` (default 50 %, a slider in Settings). The battle loop starts with the battle and gives way to a sting when it ends. No music in the headless runner. **Not heard by the agent**: only length, loudness, looping and determinism are tested; the tune and the mix need the user's ears. Sound effects were not changed (the list was already complete for combat); no button or card click sounds yet.
5. **G.5 Cursor, highlights and health bars in pixel style.**

## Acceptance
Tests pass; `-- --mission=x5_field_works` shows the bunker, mines and beacon; no unit draws its code placeholder wedge.

## Manual checks (not done by the agent)
How the new sprites look at normal zoom and in motion (the drone rotors), and whether the barracks reads as a barracks next to the other buildings.
