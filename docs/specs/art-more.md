# More art: ground marks, weather, icons, in-world cards, core states, result screens, ambient life, store art

Status: **v0.1, started 2026-10-18** (the user asked to start on the nine art suggestions made after docs/specs/art-polish.md). N.1 to N.4 are built; N.5 to N.8 are not. All of it is presentation only: no rule, number or enemy stat changes.

## What already exists (checked in the code before planning)

- **Zombie types:** seven have full art and data: shambler, runner, sprinter, spitter, spewer, brute, behemoth. A "crawler" and an "armoured" zombie do not exist; they are new enemies (stats, waves, balance), not art, so they are held back for a design decision (see Open question).
- **Weather:** rain, fog and dust exist (`scripts/battle/weather_view.gd`, `post_fx.gd`, wet-ground shader). Snow and lightning do not.
- **Ground marks:** `ScorchMark` exists (burnt ground under wrecks). Craters and blood stains do not.
- **Ambient motion:** smoke from burning pieces and dust behind moving units exist (`ambient_fx.gd`). Crows, a searchlight in battle, drifting cloud shadows and flickering fire pits do not.
- **Core:** every mission draws the `hq_bunker` scenery for the core. It has one look; there is no damaged or ruined version.

## Increments (each: spec line, generator or code, tests, changelog, one commit)

1. **N.1 Ground marks (built).** Crater decals (a dark pit with a lit rim, three sizes) under big blasts (artillery, missile, nuke, vehicle wrecks), and blood stains (two or three splat shapes, dark red-brown, fading slowly) where zombies die, drawn on the ground plane under units like `ScorchMark`. Capped in number so the stress mission keeps its frame time (140 stains, 60 craters, oldest first). Craters come from blasts of radius 1.7 tiles and up, with a scorch mark under them; the size is picked by radius (under 2.2 small, under 4 medium, else large). A stain follows a death when a hash of the position is under 0.65, so the same place always decides the same way. Art: `assets/fx/marks/*.png` from `tools/gen_ground_marks.gd`; code: `scripts/effects/ground_mark.gd`.
2. **N.2 Weather: snow and lightning (built).** A `snow` weather value (soft slow flakes in two layers, a white-blue grade, snow-tinted dither) and lightning for storm rain (a rare full-screen flash, a forked bolt drawn in pixels, the thunder sound from `SfxFactory`). Night Storm gets the lightning; no mission gets snow until one asks for it.
3. **N.3 Card back and status icons (built).** A card back (`assets/cards/_back.png`, 66 x 94 art px = a hand slot at 2x) face-down in empty hand slots and in the deck screen when nothing is picked (which now also shows the selected card's picture at 2x), and 12 x 12 px icons (`assets/ui/icons/<id>.png`) for Fortify, Hollow Points, Quick Draw, Supply Drop and Noise Lure, shown on the HUD in front of each order or doctrine in force. Made by `tools/gen_icons.gd`.
4. **N.4 In-world cards (built).** The Supply Drop crate on a parachute floating down near the core (`SupplyDropFx`, pictures from `tools/gen_supply_fx.gd`; no rule change), and the missile smoke trail redrawn from the pixel `smoke` strip (there was already a smooth trail).
5. **N.5 Core damage states.** `hq_bunker` in three looks (intact, damaged, ruined) chosen by the core's health share (above 66 %, above 33 %, below), swapped in the existing scenery view.
6. **N.6 Result screens.** Victory and defeat illustrations (pixel scenes in the style of the title picture) behind the result panel, and a reward-reveal animation for the card chooser (cards flip from the new card back).
7. **N.7 Ambient life.** Crows that cross the sky now and then (day only), a sweeping searchlight at the core at night, slow cloud shadows over the ground in clear weather, and flickering light on fire pits (the glow already exists; this adds the flicker and a flame sprite).
8. **N.8 Store and window art.** A window icon (`.ico` and project icon set from the logo), a Steam capsule set at the standard sizes (header 460 x 215, capsule 616 x 353, hero 3840 x 1240, library 600 x 900), and a loading screen shown while a mission loads. All from the logo and the title picture generators.

## Order and limits

Build in the order N.1 to N.8, one at a time; each is committed when its tests pass and pushed only when asked. The capsule sizes in N.8 are Valve's published sizes at the time of writing and must be checked against the current Steamworks documentation before anything is uploaded. Nothing here replaces a manual look: every picture, animation and sound needs a person to check it in a real play session.

## Open question

Crawlers and armoured zombies are new enemies. Say if they should be designed (a spec with stats and which missions use them) and I will add them as their own milestone with art, data, balance runs and tests, not as part of this art pass.

## Acceptance

- Tests pass after each increment; the stress mission still holds its frame time (tools/perf_flow.gd) after N.1 and N.7.
- Manual: marks and weather read well and do not hide units; the core states are told apart at a glance; the result screens and the reveal feel right.
