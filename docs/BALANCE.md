# Balance

All values are **initial guesses, unmeasured**. Tune after playtests; keep in data files, mirror here.

## Economy ([specs/deck-and-economy.md](specs/deck-and-economy.md))
| Key | Value |
|---|---|
| deck_min / deck_max / starter | 12 / 24 / 15 (3 × 5 designs) |
| max_copies (Legendary) | 3 (1) |
| initial_hand / hand_cap | 4 / 5 |
| draw_interval_s | 4 |
| cp_start / cp_cap / cp_regen_s | 5 / 10 / **3.0** per CP (was 1.5; changed in 2.6, see the sweep) |

## MVP card costs (CP) — A10
Shipped in `data/cards/` (M2.1) per the M2 spec; **unmeasured**, to be swept in 2.6. Ammo Resupply is not in M2.
| Card | Kind | Cost | Identity |
|---|---|---|---|
| Rifle Squad | Deployment | 3 (was 2) | cheap, flexible, fragile |
| Gatling Gun | Deployment | 3 | crowd shred (overheat not in M2) |
| Tank | Deployment | 6 (lockout 20 s) | durable, slow, expensive |
| Artillery Strike | Operation | 4 (lockout 15 s) | telegraphed AoE, delayed |
| Helicopter Support | Sortie | 5 (lockout 25 s) | mobile, timed |
| Ammo Resupply | Operation | 2 | logistics: refills/relieves overheat |

## Enemy archetypes (MVP, relative)
Shambler: slow, low HP. Runner: fast, low HP. Brute: high HP, armor vs small arms.

## Milestone 1 values (spec: [combat-vertical-slice.md](specs/combat-vertical-slice.md))
Unit/enemy stats are still first guesses; the **waves were tuned in 1.6** with the headless sweeps in `tools/` (numbers below are measured, 10 seeds per row).
| Entity | Key stats |
|---|---|
| Rifle soldier | HP 80, speed 3 tiles/s, rifle 12 dmg × 3 shots/s, range 8 (fires only while standing) |
| MG nest | HP 150, fixed, MG 8 dmg × 8 shots/s, range 9 |
| Shambler | HP 60, armor 0, speed 1.2 tiles/s, attack 10 dmg / 1.0 s, attack range 0.8 |
| Core | HP 500 |
| Horde spread | spawn jitter 1.0 tile, lane offset 0.9 tile (constants in `BattleController`) |
| Mission `m1_hold_the_crossing` | 90 s; waves **6 @ 2 s (every 0.9 s), 16 @ 20 s (0.65 s), 36 @ 45 s (0.4 s)** = 58 Shamblers |
| Stress mission `s1_stress_horde` | 60 s; 100 Shamblers spawned within 5 s, core HP 100 000 (never falls), same two defenders |
| DamageService | `max(base − armor, base × 0.1) × falloff` |

### Tuning evidence (default loadout = soldier at its start cell + MG nest, **no player orders**)
The fight is Lanchester-like: defenders either hold or are overrun, with a narrow band in between, driven mostly by the third wave's spawn rate.
| Waves (1st / 2nd / 3rd) | Wins | Core left (avg) | Units lost (avg) | Verdict |
|---|---|---|---|---|
| 5 / 12 / 25 (original, 42 total) | 10/10 | 100 % | 0 | trivial, zombies die at the wall |
| 8 / 20 / 45 (73) | 0/10 | 0 % | 2.0 | hopeless |
| 6 / 16 / 34 (56), narrow lanes (0.35) | 5/10 | 35 % | 1.7 | edge, but a single column of zombies (unreadable) |
| lane spread widened to 0.9 / spawn 1.0 (readability), then: 6 / 16 / 30 | 10/10 | 99 % | 0.1 | easy |
| 6 / 16 / 34 | 9/10 | 75 % | 1.1 | slightly easy |
| 6 / 16 / 35 | 7/10 | 53 % | 1.3 | |
| **6 / 16 / 36 (shipped, 58)** | **7/10** | **50 %** | **1.5** | tense; outcome varies by seed |
| 6 / 16 / 37 | 4/10 | 11 % | 1.9 | |
| 6 / 16 / 38 | 1/10 | 8 % | 1.9 | |
| no defenders (any set) | 0 | 0 % | – | core falls at ≈ 33 s |
| 12 MG nests (test) | wins | – | – | overwhelming defence wins |

**Does the player's one decision matter?** With the shipped waves, ordering the soldier at t = 0 to a cell (10 seeds each):
| Soldier parked at | Wins | Core left (avg) |
|---|---|---|
| (10,15), (6,14), (12,16) — near the nest / covering the gap | 10/10 | 92–100 % |
| (8,15) | 8/10 | 76 % |
| default (7,17) | 7/10 | 50 % |
| (9,13) | 6/10 | 50 % |
| (4,17) | 5/10 | 22 % |
| (7,21), (5,19) — far back by the core | 1/10, 0/10 | ≈ 0–1 % |
So positioning swings the result from "always lose" to "always win" — the slice has a real, if tiny, tactical choice. **Caveats:** one deterministic mission and one unit type; the sweep only varies seeds (spawn jitter), not human play; the numbers are for *this* build and will move with any combat change.

Open tuning questions for your playtest: is "50–70 % to hold by default" the right tension? is 90 s the right length? do you want the soldier to start further forward/back?

## Milestone 2 values (spec: [card-loop.md](specs/card-loop.md)): all **unmeasured first guesses**, swept in 2.6
| Entity | Key stats |
|---|---|
| Gatling gun | HP 90, fixed, 5 dmg x 18 shots/s, range 7 |
| Tank | HP 400, armor 5, speed 1.0, cannon 45 dmg x 0.5 shots/s, range 9, blast radius 1.6 (falloff 1.0 to 0.25) |
| Helicopter (cost 5, lockout 25 s) | HP 200, speed 3, altitude 3; 12 s on station; machine gun 6 dmg x 12/s range 8 (hover only); **6 missiles** (was 4; the user asked for at least 4): 50 dmg, blast 1.8 (falloff 1.0 to 0.25), range 14, 1.5/s, fired while flying in |
| Rifle squad (cost 3) | 3 x rifle soldier |
| Artillery strike (`data/operations/artillery_strike.tres`) | **6 shells**, scatter radius 3, **warning 1.2 s**, one shell per 0.35 s, **flight 0.7 s** (first impact 1.9 s after the card, was 2.9), **110 dmg**, blast 1.8 (falloff 1.0 to 0.25), card cost 4, lockout 15 s |
| Mission `m2_card_defense` | 120 s, core 500 HP, deploy radius 10; waves **30 @ 4 s (every 0.2 s), 100 @ 25 s (0.1), 220 @ 55 s (0.07), 360 @ 85 s (0.05) = 710 Shamblers**. Tuned in 2.6 (below) |

## Milestone 2 balance sweep (2.6)
**Tool:** `tools/tune_cards.gd` (usage in its header). Scripted players use the same public API as a human (hand, CP, place on a cell) and look at the table four times a second: `idle` plays nothing; `spam` plays the cheapest playable card at once, aimed at the horde where it is now; `cheap` is the same but placed and aimed well (units on the lane, artillery aimed ahead of the walking horde, only at crowds of 8+); `mix` also saves up to 16 s for the most expensive card it could play, unless the horde is at the core. `--set=kind.id.field=value` changes a definition for one run, `--drop=card` removes a card from the deck, `--bench` plays one card against a fixed stream. Seeded; 20 seeds per row unless noted.

**What the first run found:** with the data as first written (80 Shamblers in 120 s, regen 1.5 s) *every* bot won 10/10 with no unit lost, and so did hordes up to 960 Shamblers. Scaling the counts did nothing, because the spawn *interval* limits how many arrive; scaling the spawn rate as well, the defence only broke at about 25 times the shipped pressure (1,600-2,400 Shamblers). So the sweep tuned the economy first, not the horde.

**Tuning applied (all in data):** CP regen 1.5 s to 3.0 s, Rifle Squad cost 2 to 3 (one squad killed 59 of 60 sparse Shamblers alone: 29 kills per CP), artillery faster and heavier (first shell after 1.9 s, 6 x 110), helicopter 6 missiles, waves 30/100/220/360. Result on the shipped data:
| Player | Wins | Core left (avg) | Units lost (avg) | Falls at |
|---|---|---|---|---|
| idle (plays nothing) | 0/20 | 0 % | 0 | 28 s |
| spam (cheapest first, naive aim) | 8/20 | 30 % | 3.2 | 105 s |
| cheap (cheapest first, good aim) | 8/20 | 32 % | 4.7 | 110 s |
| mix (saves for heavy cards, leads artillery) | 18/20 | 90 % | 0.5 | 115 s |
Target I set (not given by the spec): do nothing always loses, naive play loses more often than it wins, good play wins most of the time. The economy change is the biggest lever: with regen 4.0 s (original cards, an earlier, non-saving bot, 10 seeds) 6x the first pressure already gave 5/10 (spam) and 8/10 (mix); at regen 1.5 s it took about 25x. **It changes the economy spec's numbers (1.5 s per CP), so it needs the user's call.**

**One-card bench** (`--bench`, kills of 60 Shamblers, one card played once, core unbreakable; per CP in brackets) at stream gaps 0.5 / 0.2 / 0.1 / 0.05 s between zombies:
| Card (cost) | 0.5 s | 0.2 s | 0.1 s | 0.05 s |
|---|---|---|---|---|
| Rifle squad (3) | 57 (19) | 21 (7) | 15 (5.1) | 13 (4.3) |
| Gatling (3) | 36 (12) | 15 (5.0) | 12 (3.8) | 10 (3.2) |
| Tank (6) | 54 (9.0) | 60 (10) | 60 (10) | 60 (10) |
| Artillery (4) | 8 (2.0) | 14 (3.5) | 24 (5.9) | 44 (11) |
| Helicopter (5) | 16 (3.3) | 20 (4.0) | 27 (5.4) | 45 (9.1) |
Artillery and the helicopter are crowd cards (weak against a thin stream, strong against a dense one); the Gatling and Rifle squad fade as the crowd thickens; **the tank kills the whole 60-Shambler stream alone at any density.**

**Does every card earn its slot?** (deck with one card removed, 10 seeds) For `mix`: removing the tank drops it from 18/20 to **0/10**; removing artillery, helicopter, Gatling or Rifle squad changes nothing measurable (9-10/10). For `cheap`: removing the tank or the artillery/helicopter *raises* it (7/10, 6/10, 8/10 vs 8/20), removing the Gatling or Rifle squad lowers it to 2/10. So the tank is the carry card; artillery and helicopter are CP sinks for a player who spends greedily and about neutral for a good one. Nerfing the tank (damage 35 to 45, blast 1.3 to 1.5) swings `mix` between 1/20 and 12/20: a cliff, so I left it, and these are the open questions for the user.

**Caveats:** bots are not humans (perfect aim, no misclicks, no reading the screen); only one enemy type exists, and Shamblers are melee-only, so ranged hitscan with no overheat or ammo is strong against them; units never expire, so defence accumulates. The numbers are for this build only.

**Performance, card mission (`tools/perf_cards.gd`, windowed, 1920x1061, MX330, 120 s, scripted plays: 6 artillery strikes, 6 helicopter sorties, 2 tanks, 1 Gatling; the tool's placement refused about half its plays, so only 5 units stood at once):** 204 FPS average, 1 % low 100, 0.1 % low 75, worst frame 37.9 ms, worst 1-second average 93 FPS, 2 frames over 20 ms of 24,457; peaks: 204 enemies, 8 shells in flight. Not covered: 500 enemies at once together with strikes and sorties (M1 measured 500 enemies at 98-119 FPS without effects).

## Content pass: Runner, Brute, RPG team, Howitzer, mission `m3_combined_arms` (first guesses + one sweep)
| Entity | Key stats |
|---|---|
| Runner | HP 35, speed 2.6 (Shambler 1.2), 6 dmg per 0.6 s, footprint 0.25 |
| Brute | HP 320, armor 4 (a rifle bullet does 8 instead of 12), speed 0.7, 30 dmg per 1.4 s, range 1.0, footprint 0.45 |
| RPG soldier (card `rpg_team`, 2 per card, cost 4) | HP 70, speed 2.6; rocket 70 dmg, blast 1.2, range 7, speed 11, 0.35 shots/s |
| Howitzer (card `howitzer_battery`, cost 5, lockout 12 s) | HP 140, fixed; shell 80 dmg, blast 2.0, range 16, arc 5, speed 9, 0.2 shots/s. No minimum range |
| Mission `m3_combined_arms` | 120 s, core 500, deck `combined_arms`; shambler 48 @4 s, runner 40 @20 s, shambler 100 @38 s, brute 6 @48 s, runner 80 @72 s, shambler 160 @76 s, brute 12 @95 s = 446 enemies |
Sweep (`tools/tune_cards.gd --mission=m3_combined_arms --seeds=8`, the economy values in the current data): do nothing **0/8** (core falls at ~27 s); spam (cheapest card first) **8/8**, core 91 % left; mix **7/8**, core 69 % left, 96 % killed, one loss at 32 s (runner rush before the defence was up). Wave counts were raised from a first draft (116 enemies) after it turned out to be won at 100 % core with no losses; the 446 figure is in line with the current `m2_card_defense` wave sizes. Only ~8 seeds, so read it as a rough band. The Howitzer and RPG were not measured one card at a time (`--bench`/`only=` is the tool for that).

## Structures and mission `x1_fortified_crossing` (spec: [props-and-cover.md](specs/props-and-cover.md); first guesses + one sweep)
| Structure | HP | Armor | Death blast | Card cost |
|---|---|---|---|---|
| Sandbag wall (`sandbags`) | 220 | 0 | none | 1 |
| Concrete barrier (`barrier`) | 500 | 3 | none | 2 |
| Crate stack (`crates`) | 110 | 0 | none | 1 |
| Oil drums (`fuel_drums`) | 70 | 0 | 70 dmg, radius 1.8 | 2 |
| Jeep (pre-placed at cell 8,14) | 160 | 0 | none | – |
| Supply truck (pre-placed at cell 6,16) | 320 | 1 | 90 dmg, radius 2.4 | – |
Mission: the `m3_combined_arms` waves (446 enemies), deck `fortified` (18 cards, 11 designs), jeep and truck beside the road. Enemies path along the line x+y=24 and stop to attack anything within reach, so the useful wall cells are the grass cells whose x+y is 22 (0.7 tiles from the line); the cells on the other side are 1.4 tiles away, which only the Brute can reach.
Sweep (`tools/tune_cards.gd --mission=x1_fortified_crossing --seeds=8`): do nothing **0/8** (core falls at ~29 s; the pre-placed truck and jeep still kill 22 % of the zombies when they blow up); spam (cheapest card first, so many walls) **3/8**, core 25 % left, i.e. walls alone do not win; mix **6/8**, core 63 % left, 91 % killed, 1.5 units lost. For comparison `m3_combined_arms` with the old deck: mix 7/8. The wall cards were not measured one at a time (`--bench`, `only=`), the bots place walls like riflemen (about 4.5 tiles from the core, as near the lane as the terrain allows, spread apart) and know nothing about the best cells, so treat the numbers as a floor for a player who aims them.

## Performance: projectiles (measured, M2.4)
`ProjectileSystem` with the 256-shell cap full: 0.46 ms per tick including per-shell position/altitude queries (headless, same laptop). A strike uses 5 shells. Rendering of shells/telegraphs under a 500-zombie horde is measured in 2.6.

## Performance (measured, Milestone 1.6)
**Hardware:** Windows 11 laptop, Intel Core i7-1165G7, 23.7 GB RAM, NVIDIA GeForce MX330 (used by Godot; Intel Iris Xe also present), Forward+ renderer, 1920×1061 window. A low-end GPU is a deliberately conservative baseline.
**Method:** `tools/perf_sim.gd` (simulation only, headless) and `tools/perf_fps.gd` (real scene in a window, 7 s warm-up, 12 s sampled, vsync off unless stated). Repeated runs on this laptop vary a lot (power/thermal state), so figures are ranges.

Simulation cost per tick (`BattleController.step`, 60 ticks/s budget = 16.7 ms):
| Alive enemies | avg per tick | p99 |
|---|---|---|
| ~100 | 0.48 ms | 0.9 ms |
| ~190–320 | 1.1–1.9 ms | 1.8–3.6 ms |
| ~360 (1000 spawned) | 2.2 ms | 4.6 ms |

Rendered frame rate, 100 Shamblers + 2 defenders (the stress mission): **117–198 FPS average, 1 % lows 96–133 FPS, worst frame 11–12 ms** over three runs; never below 60. With vsync on: **60.0 FPS, 0 frames over 20 ms in 12 s**.
Scaling with a profile-driven fix (before → after making ground shadows build their polygon once instead of every frame; after-numbers are the typical post-fix runs):
| Enemies alive | Before (avg FPS, 1 % low) | After (avg FPS, 1 % low) | Draw calls |
|---|---|---|---|
| 250 | 88, 67 | 100–154, 96–132 | ≈ 1500 |
| 500 | 40, 32 (worst frame 40 ms) | 98–119, 75–94 | ≈ 3000 |
Roughly 6 draw calls per enemy (body, shadow, health bar, flash states) — the next thing to look at if hordes grow beyond ~500; nothing was optimised beyond the shadow fix because nothing else was needed.

**What this does and doesn't show:** at the Milestone 1 scale (≤ ~100 enemies, 2 defenders, hitscan, no particles beyond the small effects) the game has large headroom on a weak GPU. It says nothing about artillery/air effects, larger maps, or card UI. Do not quote a maximum enemy count from this; "500 held 98–119 FPS on this machine in this test" is the measured fact.
**Readability at 100:** with the widened lanes the horde reads as a dense crowd of individual silhouettes; true separation (zombies not overlapping) is not implemented and is a Milestone 3 item (together with the flow-field decision).

## Synergy notes
Add per synergy: intended counterplay and balance risk (post-MVP).
