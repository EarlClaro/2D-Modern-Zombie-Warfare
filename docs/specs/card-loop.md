# Spec: Milestone 2 — First Card Loop

Status: **v0.2 approved 2026-10-15 (D1–D7 as recommended).** Increments 2.1-2.6 built; awaiting the user's go / tune / no-go. D3 applied: starter deck is 15. Builds on [combat-vertical-slice.md](combat-vertical-slice.md) (M1) and refines [deck-and-economy.md](deck-and-economy.md) (rules stay as written there except where D3 says otherwise).

## Purpose
Prove pillar 2: **playing cards creates meaningful tactical choices.** The player no longer starts with pre-placed defenders; they build the defence in real time from a drawn hand, spending Command Points (CP), with every placement previewed on the ground plane.

## Scope
**Cards (5 designs, one per MVP role):**
| Card id | Kind | What it does | Cost (initial) | Lockout |
|---|---|---|---|---|
| `rifle_squad` | Deployment | Spawns 3 `rifle_soldier`s around the target cell (mobile, can be ordered) | 2 | – |
| `gatling_gun` | Deployment | Fixed, very high rate of fire, short range, fragile (`mg_nest` family) | 3 | – |
| `tank` | Deployment | Mobile, armored, cannon with a small blast (`blast_radius > 0`) | 6 | 20 s |
| `artillery_strike` | Operation | After a visible telegraph, 5 shells land in a ground circle, each with blast falloff | 4 | 15 s |
| `helicopter_support` | Sortie | Gunship enters from an edge, strafes on station for ~12 s at altitude, leaves; ground enemies cannot hit it | 5 | 25 s |

**Systems:**
- Pure logic: `CardDefinition`, `DeckRules` (data), `DeckState` (draw pile / hand / discard / reshuffle / lockouts), `CommandPoints`, `CardPlayService` (validate → result, never mutates on failure), `PlacementRules` (is this ground cell valid for this card).
- Battle integration: `BattleController` owns a `DeckState` and `CommandPoints`, ticks them in `step()` (same fixed tick, seeded RNG), and executes a successful play (spawn units / start an operation / launch a sortie). Rules stay out of UI.
- `ProjectileSystem` (first use of PROJECTILE delivery): array-based, ground position + altitude arc, impact → blast query → `DamageService` falloff. Used by artillery shells only (see D1). Not one node per shell.
- UI: hand bar (5 slots, cost, lockout shading, number-key hints), CP bar, draw-timer, deck/discard counts; targeting preview = ground cell highlight or ground circle (ellipse via `IsoProjection`), green valid / red invalid; invalid play or too little CP leaves the card in hand and gives feedback.
- Input: `1`–`5` or click a card to select; LMB on the field to confirm; RMB / `Esc` cancels. Existing "click to move" now applies only when no card is selected.
- New mission `m2_card_defense` (same `crossing` map, no pre-placed defenders, a deck, waves tuned for card play). `m1_hold_the_crossing` stays untouched as a regression scenario.
- `UnitDefinition.armor` (needed by the tank; enemies already reduced by `DamageService`).

## Non-goals
Reward choice, deck editor, save, upgrades (M5); new enemy types and flow field (M3); Runner/Brute, type resistances; audio beyond generated placeholders (a few new ones for blast/rotor); tactical pause; multiple spawns; any card beyond the five.

## Decisions (approved as recommended)
| # | Question | Recommendation | Why |
|---|---|---|---|
| D1 | Projectile scope | Artillery shells are real arcing projectiles (`ProjectileSystem`). Tank cannon is **instant hit + blast** (hitscan with `blast_radius`, tracer, explosion). Helicopter uses hitscan. | Gets the arc/altitude/shadow/blast pipeline proven once, on the card where the arc *is* the telegraph, without a second projectile type. |
| D2 | Where can Deployments be placed? | Buildable cells (`.` grass) within `deploy_radius` (default 10 tiles) of the core, not occupied by a player entity. Operations/Sorties: any in-bounds ground cell. | Roads are the enemy route; keeping defenders off them and near the core makes placement a real choice. Radius is mission data. |
| D3 | Deck size vs duplicate cap | Starter deck = **15 cards (3 copies × 5 designs)** for M2. Min 12 / max 24 / max 3 copies stay. The "starter 16" default in deck-and-economy.md/GDD is updated to 15 until a sixth design exists. | 16 is impossible with 5 designs and a cap of 3. A sixth filler card only to hit 16 would be wasted work. |
| D4 | Lockout semantics | Per card id, starts when any copy is played; other copies stay in hand but cannot be played until it ends (shown on the card). Draws are unaffected. | Matches the existing spec; stops three tanks in one second without a hard cap. |
| D5 | Sortie flow | Player picks an **entry edge** by choosing the target cell (the gunship flies from the nearest map edge to the cell, holds station ~12 s, leaves the opposite way). It has altitude (`LOW_AIR`), shadow, and enemies skip it as a target. | Reuses the M0.5 flyer and altitude/shadow; no extra UI. |
| D6 | Mission pacing | `m2_card_defense`: 120 s, core 500 HP, waves scaled so **a good play pattern wins comfortably and doing nothing loses**. Numbers set by a sweep in the last increment, evidence in BALANCE.md (as in 1.6). | M1 lesson: balance by measurement, not by feel alone. |
| D7 | Test seam | `DeckState`/`CommandPoints`/`CardPlayService`/`PlacementRules` have no Node/scene dependency; the same seed gives the same draw order. | Required by the deck spec; keeps most M2 tests headless and fast. |

## Increments (each: tests → mutation check → headless import → docs/CHANGELOG → report → you say "commit and push")
- **2.1 Pure deck and economy.** `CardDefinition` (+ content validation, loaded by `ContentDb`), `DeckRules`, `CommandPoints`, `DeckState`, `CardPlayService`; starter deck data. Tests cover every acceptance line in deck-and-economy.md plus unknown card id / below-min deck as errors, not crashes.
- **2.2 Deployment cards in the battle.** `PlacementRules`, `UnitDefinition.armor`, tank + gatling + squad definitions/data, `BattleController` deck/CP tick and play execution, `m2_card_defense` mission data (validated). Playable via a debug key path only; no hand UI yet. Tests: placement validity, deploy spawns correct units, CP spent only on valid play, tank blast + armor.
- **2.3 Hand, CP and targeting UI.** Hand bar, CP bar, draw/lockout feedback, ground-cell/circle previews, selection and cancel input, invalid-play feedback. Tests for UI-state logic (selection, preview validity) that isn't pixels; screenshots reviewed; real-input checklist for you.
- **2.4 Projectiles and artillery strike.** `ProjectileSystem` (array-based; ground pos + altitude arc), telegraph circle, shell shadows, blast query + falloff, friendly fire off. Tests: arc landing position/time, blast falloff per distance, no hit on out-of-radius, projectile count cap; a stress check on shell counts.
- **2.5 Helicopter sortie.** Entry/exit path, altitude + shadow, strafing weapon, timed leave, ground enemies ignore it. Tests for lifetime, targeting filter, altitude isolation from ground distance.
- **2.6 Balance sweep, performance, hand-over.** Seeded sweep of play patterns (do nothing / spam cheap / good mix) in `tools/`, results in BALANCE.md; stress with strike + hordes; milestone checklist; **your go / tune / no-go**.

## Acceptance criteria (Milestone 2 exit)
1. All deck/economy rules in deck-and-economy.md are covered by passing tests; same seed → same draw order.
2. All five cards can be played in `m2_card_defense` via the real UI, each with an accurate ground-plane preview (circle matches the blast footprint).
3. Invalid play (no CP, locked out, bad cell, empty slot) never changes state and shows feedback.
4. Rules/UI separation: the battle outcome with and without the HUD is identical (as in M1).
5. Do-nothing loses, a sensible mix wins, measured over ≥10 seeds each.
6. Performance: stress mission with strike + sortie active keeps the M1 baseline order of magnitude (measured, reported as measured).
7. Docs, CHANGELOG, ROADMAP updated; mutation checks done per increment.
8. Manual (you): real mouse/keyboard play, card feel, sound, readability of previews.

## Risks
- Card scope is large for one milestone; the increments are ordered so each leaves a runnable game and 2.5 can be cut or deferred without breaking the rest.
- Balance has a cliff (M1 lesson); card power compounds it. Mitigation: 2.6 sweeps before any tuning claim.
- Hand UI at 1920×1080 with canvas_items stretch must stay clear of the play area; checked in screenshots, not assumed.

## As built (M2.2)
- `PlacementRules.check_deploy(map, cell, core_cell, deploy_radius, occupied)`: reasons in priority order are out of bounds, not buildable, too far from the core (ground distance, inclusive), occupied (core cell or any living player unit's current cell). `formation_offsets(n)`: one unit in the cell centre, several on a 0.28-tile ring (stays inside the cell).
- `BattleController.check_card(slot, cell)` (never mutates) and `play_card(slot, cell)`; `CardPlayService.Reason.UNAVAILABLE` covers no deck, battle over, and operation/sortie cards (refused before any CP is spent until 2.4/2.5). `Result.placement` says why a target was invalid.
- Deck RNG is separate from the simulation RNG (seeded from the battle seed), so card plays and reshuffles never change where enemies spawn; restart replays the same opening hand.
- Area damage: `blast_radius > 0` on a hitscan weapon hits every living enemy within the ground circle around the target with `DamageService.blast_falloff` (1.0 at the centre, 0.25 at the edge) after armor; player units are never hit.
- Placeholder art: the tank and Gatling use the generic placeholder bodies (the tank currently looks like a standing soldier); real art is a later pass.
- Interim input/UI: keys 1-5 play that hand slot at the cell under the mouse; a text readout shows CP, pile sizes, hand and lockouts. The real hand UI and previews are 2.3.
- Not yet verified by anyone: number-key input in a real window, and the sound of the tank cannon (it reuses the rifle sound).

## As built (M2.3)
- Selection: `1`-`5` or a click on a card selects it (selecting it again deselects); LMB on the field places it, RMB / Esc cancels. A refused placement keeps the card selected so the player can try another cell and shows why (toast above the CP bar, card shake, and a tooltip at the cursor). A successful play clears the selection. LMB with nothing selected still orders units to move. The selection is also cleared when the battle ends, on restart, and if the selected card leaves its slot.
- Preview: target cell green/red, weapon range (and blast radius, orange) of the deployed unit as true ground circles, small dots where each unit would stand, and the deploy zone around the core while a deployment card is selected. Artillery's blast circle and the strike telegraph come with 2.4.
- Hand UI: five slots (key hint, cost badge red when unaffordable, kind colour, name, kind label, lockout seconds over a dark overlay), CP shown as ten pips (partial fill for the fractional point; a yellow outline marks the pips the selected card would spend), draw-timer bar ("NEXT CARD" / "HAND FULL"), draw/discard counts. It captures mouse clicks only inside its own area at the bottom centre; the rest of the screen reaches the field.
- Operation and sortie cards can be selected but show "Can't be played right now" until 2.4 / 2.5.
- No new sounds (refusals are visual only).
- Not yet verified by anyone: real mouse clicks on cards, the number keys and RMB/Esc in a window (the driver selected via the controller API and moved the real mouse cursor for hover), UI legibility on a different resolution or aspect ratio.

## As built (M2.4)
- Artillery strike: playing the card queues 5 shells scattered evenly over a 3-tile circle around the chosen cell (random turn and random firing order from a dedicated seeded RNG), shows a red danger zone (scatter radius + blast radius = the reach) with a shrinking countdown ring for the 2 s warning, then fires a shell every 0.35 s; each flies 0.9 s along a straight ground line with a parabolic altitude arc (6 tile-heights) and explodes with 90 damage, blast radius 1.8, armor then falloff 1.0 to 0.25, enemies only. Shells come from an off-map battery 10 tiles to one side (data: `launch_offset`).
- A strike may be aimed at any in-bounds cell (rock, road, grass); outside the map it is refused without spending anything.
- Preview while the card is selected: orange danger zone + white scatter circle at the cursor; the CP bar shows the spend as for any card.
- Explosion feedback is shared by the tank cannon and the artillery: ring, sparks, dust, a new generated `blast` sound and a 2.5 px shake (the 4 px cap still holds).
- **Observation to tune in 2.6:** the first shell lands 2.9 s after the card is played (2.0 s warning + 0.9 s flight). A horde walking at 1.2 tiles/s moves about 3.5 tiles in that time, so against moving zombies the player must lead the target; a stationary 14-zombie crowd lost 11 to one barrage, while a walking crowd left the circle and nothing died. Warning/flight/damage are first guesses in `data/operations/artillery_strike.tres`.
- Not yet verified by anyone: how the strike feels and sounds with real input, and shell visibility at different zoom levels.

## As built (M2.5)
- Helicopter support (cost 5, lockout 25 s): choosing a target cell sends one helicopter in from the **nearest map edge**, to hover over that cell for 12 s, then out the opposite edge. Any in-bounds cell can be chosen. The preview shows the route (entry -> station -> exit with an arrowhead) and the longest weapon range as a ground circle.
- Flight and sorting: the aircraft is drawn above everything (the `Air` layer) at altitude 3 (96 px), its shadow stays on the ground; it is not hurt by ground enemies, does not block building and never hides the core. Leaving the map is not a loss.
- Attack pattern (user feedback during 2.5): on the way in it fires its **4 missiles** (at least 4 is a tested requirement) at enemies within 14 tiles, one every 0.67 s, from alternating wing pylons, without turning off its flight line. When it reaches the target it stops and hovers; only then do the **machine guns** (6 dmg x 12/s, range 8) fire. Once the missiles are gone they are not refilled in that sortie. With nothing in missile range they are held, not wasted.
- Missile motion/look (user feedback): drops away from the pylon, then the motor accelerates it (average speed 14 tiles/s) on a descending line to where the target stood; drawn as a small finned rocket with a flame, a continuous white smoke trail and lingering puffs; launch smoke and flash at the pylon.
- Missile impact (user feedback): an **area** explosion, 50 damage, blast radius 1.8 tiles, armor then distance falloff, enemies only, shown as a fireball with a ground shockwave ring at the true radius, scorch mark, smoke, debris sparks, blast sound and a small shake. The tank cannon and artillery use the same explosion.
- Interim number: damage/ammo/rate values are first guesses for the 2.6 sweep. A single helicopter sortie lasts about 12 s on station plus about 6 s in and 6 s out.
- Not verified by anyone: how it feels and sounds with real input; missile visibility at other zoom levels; whether 4 missiles are the right load once balance is swept.

## As built (M2.6)
- Sweep tool `tools/tune_cards.gd`, performance tool `tools/perf_cards.gd`; method, numbers and caveats are in [BALANCE.md](../BALANCE.md) ("Milestone 2 balance sweep").
- Data changed: CP regen 3.0 s (the economy spec's 1.5 s was ~25x too generous for this mission), Rifle Squad cost 3, artillery 6 x 110 with warning 1.2 s / flight 0.7 s (first shell after 1.9 s), helicopter 6 missiles, waves 30/100/220/360.
- Not decided: tank dominance, weak artillery/helicopter value, the regen change itself (all listed for the user).
