# Balance

All values are **initial guesses, unmeasured**. Tune after playtests; keep in data files, mirror here.

## Economy ([specs/deck-and-economy.md](specs/deck-and-economy.md))
| Key | Value |
|---|---|
| deck_min / deck_max / starter | 12 / 24 / 15 (3 × 5 designs) |
| max_copies (Legendary) | 3 (1) |
| initial_hand / hand_cap | 4 / 5 |
| draw_interval_s | 4 |
| cp_start / cp_cap / cp_regen_s | 5 / 10 / 1.5 per CP |

## MVP card costs (CP) — A10
Shipped in `data/cards/` (M2.1) per the M2 spec; **unmeasured**, to be swept in 2.6. Ammo Resupply is not in M2.
| Card | Kind | Cost | Identity |
|---|---|---|---|
| Rifle Squad | Deployment | 2 | cheap, flexible, fragile |
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
| Helicopter (cost 5, lockout 25 s) | HP 200, speed 3, altitude 3; 12 s on station; machine gun 6 dmg x 12/s range 8 (hover only); **4 missiles**: 50 dmg, blast 1.8 (falloff 1.0 to 0.25), range 14, 1.5/s, fired while flying in. Unmeasured |
| Rifle squad | 3 x rifle soldier |
| Artillery strike (`data/operations/artillery_strike.tres`) | 5 shells, scatter radius 3, warning 2.0 s, one shell per 0.35 s, flight 0.9 s (first impact 2.9 s after the card), 90 dmg, blast 1.8 (falloff 1.0 to 0.25), card cost 4, lockout 15 s. Walking zombies leave the circle during the delay: tune warning/flight in 2.6 |
| Mission `m2_card_defense` | 120 s, core 500 HP, deploy radius 10; waves 6 @ 4 s (0.9 s), 14 @ 25 s (0.7), 24 @ 55 s (0.5), 36 @ 85 s (0.4) = 80 Shamblers. **Not yet tuned.** A screenshot run with a 5-zombie probe says nothing about the real waves |

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
