# Spec: Strike cutaways (call-in clips for big support cards)

Status: **v0.1, decisions approved by the user in an interview on 2026-10-16.** Nothing is built. Origin: "When a missile strikes, an artillery barrage, close air support from a fighter jet or bomber ... it would feel cool and epic to show a close-up with a bit of animation for 1-2 seconds before the damage hits. Like a battleship gun naval support: a small clip of a battleship near the shore firing barrages, then the damage animation or effect on the area."

Part of the Milestone 3 re-order in [unit-autonomy-and-card-types.md](unit-autonomy-and-card-types.md) (new increment 3.8).

## Purpose
Make calling in heavy support feel like an event: a short, full-screen cutaway shows who is firing (the ship, the jet, the launcher, the battery), then play returns to the battlefield where the shells, bombs or missiles land with the existing blast effects.

## Decisions (user, 2026-10-16)
| Topic | Decision |
|---|---|
| Presentation | **Full-screen cutaway; the game freezes** while it plays (no simulation ticks, so Command Points, cooldowns and enemies all hold). |
| Frequency | **Full the first time each support is used in a mission (about 1.5 s), a short version (about 0.5 s) after.** Skippable, and switchable off. |
| First batch | **Naval gunfire (battleship), close air support (jet), missile strike, artillery barrage.** |
| Scope (user, added later the same day) | **Every big attack gets a clip, from the biggest down to small ones: hypersonic missiles, nuclear bombs, satellite laser, and the rest of the support catalogue.** Handled by size **tiers** (below), so big attacks are epic and small attacks stay brief. |
| Art | **Generated for free by our own tools** (code-drawn pixel art made by a `tools/gen_*.gd` script, like the existing sprite and tile generators), not paid image services. Provenance goes in [ASSETS.md](../ASSETS.md). |

## Scope
### Flow
1. The player plays an eligible card; validation, CP spend, discard and lockout happen exactly as today.
2. The battle emits `cutaway_requested(cutaway_id)` after the play. If cutaways are on, the presentation layer freezes the simulation and plays the clip: letterbox bars, a name banner ("NAVAL GUNFIRE"), the scene, its sound.
3. When the clip ends (or is skipped) the simulation resumes; the existing telegraph, shells, missiles and blasts run as before, and the camera eases toward the impact area if it is off screen.
4. Short version: same scene cut to about 0.5 s (muzzle flash and a title card), no camera ease.

### Rules that must hold
- **Rules never depend on the presentation.** The freeze only stops ticks, so a battle with cutaways, with cutaways off, and without any HUD gives identical results for the same seed and plays (digest test). Input other than "skip" is ignored while frozen.
- One clip at a time. A second eligible play during a clip cannot happen (input is blocked); a play in the same frame as a clip ending uses the short version.
- Restart cancels any clip and clears "played this mission" memory.
- Freeze is bounded: a clip never lasts longer than its data says, plus a hard cap of 3 s.

### Tiers
| Tier | Examples | Full / short clip | Why |
|---|---|---|---|
| **Epic** | nuclear bomb, satellite laser, hypersonic missile | 2.0 s / 1.0 s | Rare, expensive, long lockout: worth the drama every time. |
| **Large** | naval gunfire, close air support, missile strike | 1.5 s / 0.5 s | The default described above. |
| **Small** | artillery barrage, mortar, combat drones launch | 0.8 s / 0.3 s | Frequent, so the freeze must stay almost unnoticeable. |
Each cutaway names its tier and gets its durations from it unless it overrides them. The hard cap stays 3 s. Any card with an area effect or an aircraft can get a clip later by adding one `CutawayDefinition` and one scene recipe, with no change to the rules.

### Data
`CutawayDefinition` (content, id-keyed): `display_name` (banner), `tier` (EPIC / LARGE / SMALL, which sets the default `full_s` and `short_s`), optional `full_s` / `short_s` overrides, `scene` (id of a code-built scene recipe), `sound` (an `SfxFactory` id). `OperationDefinition` and sortie cards get an optional `cutaway_id`. ContentDb validates the reference and the durations (> 0, full >= short, <= 3).

### Pure logic (tested without a window)
`CutawayPlan`: given a cutaway, whether it was seen this mission, and the settings, returns `FULL`, `SHORT` or `NONE` and the duration; tracks "seen"; resets on restart; `skip()` ends it. Everything visual reads this.

### Scenes (all drawn in code from generated sprites, 2:1 isometric rules do not apply, they are cutaway art)
| Clip | Content |
|---|---|
| **Naval gunfire** | Sea and shoreline at dusk, a battleship in side view firing a broadside: turret flashes, smoke rolling, shells leaving, recoil on the hull, spray. |
| **Close air support** | A fighter or bomber in a diving pass or flyby, afterburner, contrail, bombs or a gun run starting. |
| **Missile strike** | A launcher (truck or silo) lifting a missile on a column of smoke and fire, camera tilting up. |
| **Artillery barrage** (small) | A line of howitzers firing in sequence, recoil, flashes, dust. |
| **Hypersonic missile** (epic) | A missile screaming across the sky at extreme speed with a shock-cone and a white-hot trail, then a streak straight down. |
| **Nuclear bomb** (epic) | A bomber or missile release from high altitude, a countdown beat, then a blinding white flash that fades into a rising mushroom cloud. |
| **Satellite laser** (epic) | A satellite in orbit over a curved Earth charging, a thin beam stabbing down through the atmosphere, then the beam sweeping the target area. |
Each is 2-4 layers (backdrop, subject, effects, foreground) with a few frames of animation and screen shake; no video files.

### Cards that use them
- Existing: **Artillery Strike** gets the artillery clip.
- New data-only cards on the existing OPERATION and projectile machinery (costs and numbers are first guesses for the balance sweep): **Naval Gunfire** (heavy shells, wide scatter, long warning), **Missile Strike** (a few high-damage missiles on one spot), **Close Air Support** (a fast aircraft makes one pass along a line and drops bombs; needs a small line-strike addition).
- Epic-tier cards, named by the user: **Hypersonic Missile** (fast missiles on existing projectile machinery), **Nuclear Bomb** (one huge delayed blast on existing blast machinery, long lockout), **Satellite Laser** (a sweeping beam, which is a new effect and the likeliest to move to a later increment if it grows). They are data cards plus clips in 3.8 where the effect fits existing machinery.
- The Helicopter sortie does not get a clip in this batch.

### Controls and settings
`Space` or `Esc` or a click skips a running clip. `C` toggles cutaways on and off for the running game; `--cutaways=off` starts with them off. Persisting the choice waits for the settings menu (Milestone 7; there is no save system before M5).

## Non-goals
Video playback, voice lines, camera cinematics during normal play, clips for non-strike cards, per-card custom cutaway authoring tools, persisting the setting, clips for enemy actions.

## Increment 3.8 (after 3.7, before difficulty)
`CutawayDefinition` with tiers + ContentDb validation, `CutawayPlan` (pure), the freeze hook in `BattleController`, `CutawayPlayer` and seven scene recipes (four large/small + three epic), `tools/gen_cutaway_art.gd` for the generated sprites, sounds in `SfxFactory`, the three new cards and the line-strike, tests, mutation check, screenshots of every clip reviewed, docs and ASSETS.md. Commits automatically when its checks pass; push only when told.

## Acceptance criteria
1. Playing each supported attack shows its clip at its tier's full length the first time in a mission and short after; skipping and the off switch work; restart resets.
2. During a clip no simulation tick happens (CP, timers, enemies unchanged); after it, results match a run without clips (digest test with and without).
3. Clips never exceed their data duration or the 3 s cap, and a skip ends them within one frame.
4. All art is produced by a script in `tools/` committed with its source; ASSETS.md records it; no external or copied assets.
5. Windowed screenshots of each clip at several frames were looked at by me; the **look, the feel of the freeze and the sound are manual checks for the user.**

## Risks
- **Flow:** a freeze on every strike interrupts a real-time game. Mitigations already chosen: short repeat clips, skip, off switch. If testing shows it still hurts, the fallback is the non-freezing cutaway window (the alternative offered in the interview).
- **Art quality:** code-generated pixel art may look rough next to hand-made art; clips are isolated, so each can be redrawn later without touching rules.
- **Scope:** the Close Air Support line-strike is new simulation code; if it grows, ship the clip with the existing artillery-style effect first.
