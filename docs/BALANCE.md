# Balance

All values are **initial guesses, unmeasured**. Tune after playtests; keep in data files, mirror here.

## Economy ([specs/deck-and-economy.md](specs/deck-and-economy.md))
| Key | Value |
|---|---|
| deck_min / deck_max / starter | 12 / 24 / 16 |
| max_copies (Legendary) | 3 (1) |
| initial_hand / hand_cap | 4 / 5 |
| draw_interval_s | 4 |
| cp_start / cp_cap / cp_regen_s | 5 / 10 / 1.5 per CP |

## Proposed MVP card costs (CP) — A10
| Card | Kind | Cost | Identity |
|---|---|---|---|
| Rifle Squad | Deployment | 2 | cheap, flexible, fragile |
| Gatling Gun | Deployment | 4 | crowd shred, overheats |
| Tank | Deployment | 7 | durable, slow, expensive |
| Artillery Strike | Operation | 5 | telegraphed AoE, delayed |
| Helicopter Support | Sortie | 6 | mobile, timed |
| Ammo Resupply | Operation | 2 | logistics: refills/relieves overheat |

## Enemy archetypes (MVP, relative)
Shambler: slow, low HP. Runner: fast, low HP. Brute: high HP, armor vs small arms.

## Milestone 1 initial values (unmeasured guesses; spec: [combat-vertical-slice.md](specs/combat-vertical-slice.md))
| Entity | Key stats |
|---|---|
| Rifle soldier | HP 80, speed 3 tiles/s, rifle 12 dmg × 3 shots/s, range 8 |
| MG nest | HP 150, fixed, MG 8 dmg × 8 shots/s, range 9 |
| Shambler | HP 60, armor 0, speed 1.2 tiles/s, attack 10 dmg / 1.0 s, attack range 0.8 |
| Core | HP 500 |
| Mission | 90 s survival; waves ≈ 5 @ t=2 s, 12 @ t=20 s, 25 @ t=45 s (+ stress scenario: 100 at once) |
| DamageService | `max(base − armor, base × 0.1) × falloff` |

**Observed in 1.4 (headless sim, 5 seeds):** default loadout (soldier + MG nest) wins all 5 with the core at 500/500, 0 units lost, ~320 shots for 42 kills; no defenders loses at ~32 s. Conclusion: enemy pressure is far too low for the defenders' range/DPS (zombies are shot dead near the wall). Candidate levers for 1.6: more/faster/tougher enemies (Runner/Brute arrive later), weaker or fewer defenders, shorter range, bigger waves. Not changed yet, to keep tuning together with the feel pass.

## Performance targets
Not set. To be measured in M1/M3; recorded here with hardware.

## Synergy notes
Add per synergy: intended counterplay and balance risk (post-MVP).
