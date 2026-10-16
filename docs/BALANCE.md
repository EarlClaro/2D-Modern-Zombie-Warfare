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
| Tank | Deployment | 5 (was 6; lockout 20 s) | durable, slow, expensive |
| Artillery Strike | Operation | 3 (was 4; lockout 15 s) | telegraphed AoE, delayed |
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
| Artillery strike (`data/operations/artillery_strike.tres`) | **6 shells**, scatter radius 3, **warning 1.2 s**, one shell per 0.35 s, **flight 0.7 s** (first impact 1.9 s after the card, was 2.9), **110 dmg**, blast 1.8 (falloff 1.0 to 0.25), card cost 3 (was 4), lockout 15 s |
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
| RPG soldier (card `rpg_team`, 2 per card, cost 5, was 4) | HP 70, speed 2.6; rocket 70 dmg, blast 1.2, range 7, speed 11, 0.35 shots/s |
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

## Re-sweep on `m3_combined_arms` (Runner and Brute in play), 2026-10-16
Run after ADR-011 to revisit the tank and the crowd cards (`tools/tune_cards.gd --mission=m3_combined_arms`, headless, seeded; new options `--benchenemy`, `--benchcount`, `--benchtime`). Data as committed (CP regen 3.0 s; tank 6, artillery 4, helicopter 5, RPG team 4, Howitzer 5, Rifle squad 3, Gatling 3).

**1. The mission as shipped cannot tell the cards apart:** idle 0/20, spam 20/20, cheap 20/20, mix 18/20 (core 96 / 100 / 73 %). At 1.5x the waves (counts and spawn rate) spam, cheap and mix tie at 7/12; at 2x spam 4/12, cheap 3/12, mix **0/12**; at 3x all 0/12. In this mission *spending early beats saving* (the Runner rushes arrive before a saved Tank), the reverse of `m2_card_defense`. So the drop-one tests below use 1.5x pressure.

**2. One-card bench** (kills per CP; 6 seeds; stream gap 0.1 s, 60 Shamblers / 40 Runners; Brutes 6 at 1.5 s, 150 s):
| Card (cost) | Shamblers | Runners | 6 Brutes (kills of 6) |
|---|---|---|---|
| RPG team (4) | 49 (12.3) | 33 (8.3) | 1.5 |
| Tank (6) | 60 (10.0) | 40 (6.7) | 1.3 |
| Rifle squad (3) | 15 (5.1) | 29 (9.7) | 3.7 |
| Howitzer (5) | 32 (6.3) | 31 (6.2) | 0.3 |
| Artillery (4) | 24 (6.0) | 21 (5.2) | 0 (never found a crowd of 8) |
| Helicopter (5) | 27 (5.4) | 25 (4.9) | 0 (same) |
| Gatling (3) | 11 (3.8) | 12 (4.1) | 0 (5 dmg - armor 4 = 1 dmg per bullet) |
One card cannot beat 6 Brutes (320 HP, armor 4, 30 dmg per 1.4 s): that is what they are for. The Tank kills every Shambler alone but is no better than the others against Runners and Brutes.

**3. Drop-one, cheapest-first player, 1.5x, 20 seeds** (baseline 14/20 = 70 %, core 61 %): without the **RPG team 5/20**; without Tank 20/20, Artillery 20/20, Howitzer 20/20, Helicopter 19/20, Gatling 18/20, Rifle squad 16/20. So here the **RPG team is the carry card** (best kills per CP against Shamblers and Runners), and Tank / Artillery / Howitzer / Helicopter cost more than they return for a player who spends greedily. Noise is about +/-11 points at 20 seeds.

**4. Candidate rebalance, tested with overrides only (not in the data):** RPG team 4 to 5, Artillery 4 to 3, Helicopter 5 to 4, Tank 6 to 5. Same pressure, 20 seeds: spam 7/20, cheap 10/20, mix **18/20** (the saving player wins again). Drop-one (cheap, baseline 10/20): RPG 7/20, Artillery 7/20, Rifle squad 4/20 (all now earn their slot), Tank 10/20 and Howitzer 10/20 (neutral), Gatling 14/20 (slightly negative: it does 1 damage to a Brute), **Helicopter 16/20 (still negative)**. Helicopter buffs did not fix that: missile damage 75 gave cheap 12/20 (from 10/20) but dropping it still gave 16/20; adding gun damage 9, blast 2.2 or speed 3 to 6 changed nothing further (cheap 12/20, spam 8-10/20).

**Reading:** the tank dominance in M2 was a roster effect (Shamblers only), as predicted: with Brutes and Runners it is no longer the carry. The new outlier is the RPG team. Artillery and the Helicopter are the weakest value per CP; a cost cut fixes Artillery but not the Helicopter, whose problem is probably not numbers (it arrives about 6 s after the card and holds position for 12 s, against waves that move on). **Not applied:** these are candidates; nothing above changed `data/`.

## Missions `x2_outskirts` and `x3_storm_night` on the 64x48 `outskirts` map (spec: [environment.md](specs/environment.md))
Same battle, two looks: `x2_outskirts` is a day cycle (starts at 0.4, 300 s per day, so it ends at dusk), `x3_storm_night` is midnight rain. 150 s, core 900 HP, deploy radius 17, deck `fortified`, two spawns that merge at the bridge, pre-placed at the gate: 2 MG nests, a rifle soldier, a jeep. 1383 enemies in 11 waves: shamblers 100 + 75 + 300 + 400, runners 100 + 175 + 150, spitters 15 + 25, brutes 12 + 30. Unmeasured first guesses, then swept:
| Sweep (`tools/tune_cards.gd --mission=x2_outskirts`) | Result |
|---|---|
| First draft, 553 enemies (6 seeds) | do nothing 0/6 (core falls at ~63 s), spam 6/6 with 100 % core, mix 6/6 with 100 % core: far too easy |
| Waves x2.5 = the shipped 1383 (4 seeds) | spam **1/4** (core 11 % left, 6 units lost), mix **4/4** (core 100 %, 3 units lost, 82 % killed) |
So a sensible mix holds comfortably, spamming cheap cards usually fails, and nothing loses: as designed, but the mix still keeps the core at full health, so the next tuning step is probably more brutes and spitters rather than more bodies. The bots do not use the gate geometry, the bunker walls or the terrain, and no seed count above 6 was run. The shipped missions were not re-swept after the final wave numbers were typed in; the 2.5x run is the same numbers within rounding.
After the art-pack-2 dressing of `outskirts` (new terrain and scenery only; waves and rules untouched): idle 0/3 (core falls at 55 s), spam 1/3 (core 30 % left), mix 3/3 (core 100 %, 89 % killed), 3 seeds, same picture as before. Frame rate (`tools/perf_world.gd`, 416 to 499 enemies, 413 pieces, night rain, not a quiet machine): 77 to 84 FPS average, 1 % low 56 to 60. Real `PointLight2D` lamps cost 9 to 18 FPS here and were dropped for additive pools.
**Performance (`tools/perf_world.gd`, windowed 1920x1080, vsync off, MX330).** These were measured while another process tree was running three `tune_cards.gd` sweeps (about three cores busy), so treat every number as a floor, not a result: scenery only (about 176 to 258 enemies from the first waves) day 101 to 108 FPS avg, 1 % low 90 to 99; night with rain 78 to 86 avg, 1 % low 60 to 83 (about 180 to 630 draw calls, depending on zoom); with a 400-enemy horde added (566 to 649 alive) 50 to 71 FPS avg earlier in the session and 10 to 24 once the other sweeps were at full load. Two changes came out of this: the night glows are one additive texture each (14 stacked circles each had cost about 380 extra draw calls), and the scenery fade pass uses a per-cell lookup built at setup (8.9 ms per pass with 600 enemies became 1.5 ms). Repeat the horde numbers on a quiet machine before quoting them.

### Cost rebalance applied (2026-10-16, after the re-sweep)
Applied to `data/cards/`: **Tank 6 to 5, Artillery 3 (was 4), RPG team 5 (was 4)**. The Helicopter stays at 5 CP, unchanged: the user chose to leave it alone for now (the tested candidate had it at 4). Tests that hard-coded the Tank's cost now read it from data.
**Verification with the shipped data (20 seeds), which differs from the candidate because of the Helicopter:**
| Mission | idle | spam | cheap | mix |
|---|---|---|---|---|
| `m3_combined_arms`, 1.5x pressure | 0/20 | 6/20 | 12/20 | **7/20** (candidate with Helicopter at 4: 7 / 10 / 18) |
| `m3_combined_arms`, as shipped | - | 19/20 | 20/20 | 14/20 |
| `m2_card_defense`, as shipped | 0/20 | **19/20** | **16/20** | **20/20** (before: 8 / 8 / 18) |
Two side effects to decide on: (1) `m2_card_defense` is now too easy (cheaper Tank and Artillery both live in its deck), so its waves need roughly 1.25-1.5x pressure to get back to the earlier spread; (2) the saving player (`mix`) falls from 18/20 to 7/20 at m3 1.5x with the Helicopter at 5 CP. `mix` waits up to 16 s for the most expensive card it could play, and a 5-CP Helicopter is now the one it saves for, so a weak 5-CP card acts as a trap for that kind of player. This is a bot-behaviour effect as well as a card one; a Helicopter cost of 4 removed it in the candidate run.

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

## Horde movement and the cost of a step (M3.1, 2026-10-16; decides A6, see ADR-012)
Tools: `tools/perf_flow.gd` (new; movement strategies on the real `x2_outskirts` map: 64x48, two spawns, water, rubble, scenery, 5 waypoints) and `tools/perf_sim.gd` (extended with `--counts`, `--interval`, `--defenders` and a cost-by-enemies-alive table). Headless, same laptop as above (i7-1165G7). **Load caveat:** other processes shared this CPU the whole time (about 50-70 % busy, four old Godot processes included), and the same configuration varied by up to 2x between runs (waypoints at 500 alive: 1.10 ms in one run, 0.50 ms in another). Compare numbers **within a run, against the waypoint line**, not across runs. Enemies appear at 25/s (the shipped waves peak at about 20-40/s) until N are alive; stopped enemies stay alive; 60 % shamblers, 30 % runners, 10 % brutes; one seed unless stated. The prototype classes are in the tool, not in the game.

**Strategies:** A = today's waypoints with a random lane offset. B1 = flow field (distance field from the core, 8-neighbour, no corner cutting, scenery and terrain block), each enemy blends the four nearest cells' directions every tick. B2 = B1 refreshed every 4th tick per enemy (staggered). B3 = nearest cell's direction every tick. B4 = B2 sampled at the position plus a fixed per-enemy lane offset (0.9 tile, like A). C1/C2 = B2 + separation (counting-sort hash with 1-tile cells, push from the first 8 neighbours) every tick / every 2nd tick. C3 = B4 + separation every 4th tick with the hash rebuilt every 4th tick. C4 = C3 looking at 4 neighbours.

**Cost of the movement step alone, average ms per tick (the whole tick budget is 16.7 ms):**
| Run | Alive | A | B1 | B2 | B3 | B4 | C1 | C2 | C3 | C4 |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 (busy) | 500 | 1.10 | 4.19 | 1.78 | 1.62 | - | 6.39 | 4.02 | - | - |
| 1 | 1000 | 1.40 | 6.91 | 2.88 | 2.99 | - | 13.56 | 11.29 | - | - |
| 1 | 2000 | 3.12 | 11.70 | 3.26 | 3.21 | - | 21.38 | 7.02 | - | - |
| 2 (quieter) | 500 | 0.50 | - | 0.75 | - | 0.83 | - | - | 1.39 | 1.18 |
| 2 | 1000 | 0.96 | - | 1.48 | - | 1.43 | - | - | 2.59 | 2.23 |
| 2 | 2000 | 1.19 | - | 1.75 | - | 1.93 | - | - | 3.63 | 2.78 |
Repeat of run 1 at 1000 alive with seed 2: A 1.47, B1 5.17, B2 2.32, B3 3.67, C1 14.85, C2 7.36 (same ranking). **Reading:** the field costs little once the direction is refreshed every 4th tick (B2/B4 about 1.4-1.6x waypoints, at most 1.9 ms at 2000 alive); refreshing every tick (B1) is 4x waypoints and not worth it; nearest-cell (B3) is no cheaper than B2. Separation every tick (C1) breaks the budget at 1000+ alive (13-21 ms); the staggered, rarely rebuilt C3 costs about 1.1-1.7 ms more than B4 (2.6 ms at 1000, 3.6 ms at 2000 = 16 % and 22 % of a tick), C4 a little less.
**Field build, once at setup:** 82-117 ms for the 64x48 map (3,072 cells), 530-970 ms for an empty 128x128 (the largest allowed map). It is a GDScript binary-heap Dijkstra; a bucket queue would be much faster if a large map needs it.

**Routes (x2_outskirts):** the straight line from each spawn to the core is blocked by terrain or scenery (59.1 and 50.2 tiles). Waypoint routes are 68.0 and 66.6 tiles; the flow route found on its own is **60.7 and 59.4 tiles** (shorter than the hand-placed waypoints) and reaches the core from both spawns. Reachable cells from the core: 2,124 of 2,154 open cells (30 open cells are islands).

**Do they overlap?** Share of moving enemies at 30 s that have another moving enemy closer than **half** the sum of their radii ("near" = practically on top of each other), and share that are **touching** (closer than the sum):
| Spawn rate, alive | A | B2 (flow, no lane) | B4 (flow + lane) | C3 (+ separation) | C4 |
|---|---|---|---|---|---|
| 8/s, 500 (about 225 moving), near | 38.9 % | 79.0 % | 31.1 % | **4.4 %** | 19.0 % |
| same, touching | 83.4 % | 92.9 % | 80.0 % | 73.2 % | 74.8 % |
| 25/s, 500 (about 450 moving), near | 72.9 % | 95.7 % | 72.4 % | 40.8 % | 52.2 % |
| 25/s, 1000 (about 700 moving), near | 77.7 % | 95.5 % | 77.9 % | 52.3 % | 63.8 % |
| same, touching | 94.7 % | 99.4 % | 97.0 % | 91.9 % | 93.4 % |
**Reading:** a flow field with no lane offset stacks the horde into columns (near 79-96 %), worse than today; the lane offset (B4) gets back to today's level at no cost. Separation (C3) is clearly effective when bodies can fit (near 31 % to 4 % at 8/s) and only partly effective at the shipped spawn density (78 % to 52 % at 25/s): at 25/s a front of 12.5 enemies/s walking 1.2 tiles/s is denser than shamblers can pack side by side, so "touching" stays above 70 % in every variant. Not progressing (under half a tile in 5 s): 12 of about 700 in every mode including waypoints at 25/s, so not caused by the field (the cause was not investigated).

**The cost of the whole step is the bigger finding.** `perf_sim` with no defenders, 2,000 shamblers at 83/s, step cost by enemies alive (same loaded machine):
| Alive | 250-499 | 500-749 | 750-999 | 1000-1249 | 1250-1499 | 1500-1749 |
|---|---|---|---|---|---|---|
| Average step | 7.0 ms | 14.6 ms | 20.0 ms | 25.7 ms | 30.9 ms | 37.4 ms |
Phase split from a scratch profile of the same run: at 1000-1249 alive the **enemy phase takes about 13.5 ms, the unit phase about 10.8 ms (with zero player units) and applying damage about 2.3 ms**. `_unit_phase` builds a `TargetCandidate` and a dictionary entry for every living enemy every tick whether or not any unit can fire, and each unit's target search then scans every enemy; the enemy phase allocates and scans per enemy too. So the step passes the 16.7 ms tick at roughly 600-700 alive on this machine under this load, **before** any change of movement, and movement (the A6 question) adds only 1-4 ms of it. A 1,000-alive horde (spec D7) is therefore not reachable by choosing a movement strategy; it needs the per-tick allocation and the all-pairs target search removed first. Not measured: the same table on a quiet machine, and with defenders (the earlier table at 2 defenders and about 320 alive was 3.5 ms, consistent with a roughly linear cost of 10-25 us per enemy).

## Synergy notes
Add per synergy: intended counterplay and balance risk (post-MVP).

**Lighting pass 2 performance (2026-10-16, `tools/perf_world.gd`, windowed 1920x1080, vsync off, MX330, 400-enemy horde, night rain, 413 pieces; the machine was NOT quiet: four stale Godot processes from 14 Oct were running, and the same scene with every lighting part switched off measured anywhere from 45 to 77 FPS between runs).** With the whole pass on: base view (zoom 1.5) 43 to 50 FPS average, 1 % low 23 to 33; whole map (zoom 0.5) 30 to 50 FPS. Switched off (`--off=ground,post,lights,rain,ambient`): base 71 to 77 in the quiet runs. Cost by part in the quiet runs: ground shader about 5 ms (it was 21 ms before the noise went into a texture and the heavy wet effects were limited to the slick terrains and 4 reflecting lights), light field + rain + smoke about 3 ms, finishing overlay about 1 to 2 ms. Two dead ends are recorded: (1) a finishing pass that reads the screen (`hint_screen_texture`) costs about 14 ms per frame on this GPU even when it does nothing else; (2) per-pixel noise in the post and ground shaders cost tens of ms; one shared 256x256 noise texture replaced it. The acceptance target of 60 FPS at the base view is met only on a quiet machine; repeat on one before quoting.
