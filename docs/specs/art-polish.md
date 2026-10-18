# Art polish: logo, card pictures, thumbnails, animation frames

Status: **v0.1, started 2026-10-18** (the user asked for the game logo, more animation frames, better mission thumbnails, pictures for the cards that had only emblems, and a clean-up of pictures that looked off). P.1 and P.2 are built; P.3 and P.4 are planned below. Nothing here has been seen in a real play session.

## Increments

1. **P.1 Card pictures (built).** Every card has `assets/cards/<id>.png` (96 x 72). `tools/gen_card_pictures.gd` makes all of them, using `tools/pixel_canvas.gd` (hard-edged shapes, banded shading, ordered dither, a 1 px outline pass; no randomness).
   - Unit cards: the unit's SE idle sprite, scaled by the largest whole number that fits 90 x 66 (2x for most), so one art pixel is two screen pixels like the UI. A sprite too big for that is shrunk and its edges re-hardened.
   - Strike cards: scenes. Artillery, close air support, missile, hypersonic missile and satellite sit over a red iso target ring (missiles have an exhaust trail, the satellite a laser beam, the jet two bombs); the nuclear bomb is over a mushroom cloud; naval gunfire is a battleship on water under three shells.
   - Cards with no unit: Fortify (shield with chevrons), Quick Draw (two fanned cards and a bolt), Hollow Points (three cartridges), Supply Drop (parachute and crate), Minefield (five mine sprites on dug ground), Noise Lure (the beacon sprite with sound arcs), Combat Drones (three drone sprites, one near and bigger), Barracks (its sprite).
   - The emblem code in `ui/card_art.gd` is removed; `CardArt` only draws the file.
2. **P.2 Game logo (built).** `tools/gen_logo.gd` paints a pixel logo (`assets/ui/logo.png`, 160 x 56) for the placeholder name from the UI font's glyph bitmaps scaled by whole numbers: a banded gradient, a lit top-left edge, a 2 px extrusion, chipped corners, two sparkles and hazard tape. The name is the `LINES` constant. The main menu shows it at 4x in place of the text title.
3. **P.3 Mission thumbnails (planned).** The thumbnail becomes a small lit scene: terrain with light and shadow, props and the core drawn as tiny pixel sprites instead of a flat colour map.
4. **P.4 Animation frames (planned).** More frames for the Barracks (a smoke or fire loop, a flag) and the Combat Drone (a blinking light, a bob), within the existing `SpriteSheet` fields.

## Acceptance

- Tests pass; every card has a 96 x 72 picture with hard pixel edges.
- Manual: the cards read well at 1920 x 1080; the art matches the sprite style; the logo and thumbnails look right in the menus.
