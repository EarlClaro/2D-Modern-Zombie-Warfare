# Spec: Deck and Command Economy

Status: draft; implemented in Milestone 2. Values are defaults, exposed in `data/config/deck_rules.tres` (planned) and mirrored in [BALANCE.md](../BALANCE.md).

## Purpose
Define draw, hand, resources, card lifecycle and deck editing so DeckState/CommandPoints can be pure, tested logic.

## Rules (defaults)
- Deck: min 12, max 24 cards, starter 16. Max 3 copies per id (Legendary 1). Mission restrictions may ban tags/categories.
- Battle start: shuffle (seeded RNG), draw 4. Hand cap 5. Draw 1 card every 4 s while hand < cap. Draw timer pauses at cap.
- Command Points: start 5, cap 10, +1 per 1.5 s. Playing requires `cp >= cost`; cost is spent on a *valid* play only.
- Play flow: select card → targeting preview (ground cell/circle) → confirm. Invalid target / insufficient CP → card stays in hand, feedback shown.
- After play: card → discard. Draw pile empty → shuffle discard into draw pile. If both empty, no draw.
- Card kinds: Deployment (persists until destroyed/timed out; optional deployment cap), Operation (one-shot), Sortie (aircraft pass).
- Lockout: optional per-card-id `lockout_s` after play, blocking other copies (prevents spamming duplicates of heavy ops).
- Upgrades: per card id, persist between missions, apply to all copies; branches alter behavior.

## Non-goals
Rarity-weighted rewards, research, doctrines, tactical pause.

## Failure cases
Unknown card id in deck → deck invalid (error, not crash); deck below min → cannot start; play with empty hand index → ignored; RNG injected so shuffles are reproducible.

## Acceptance criteria / tests
Cost check & spend; CP cap & regen over simulated time; initial draw; periodic draw stops at cap; reshuffle on empty; no draw when everything empty; duplicates cap enforcement; lockout; invalid play leaves state unchanged; same seed → same draw order.
