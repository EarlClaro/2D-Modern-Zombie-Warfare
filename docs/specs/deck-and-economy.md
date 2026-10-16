# Spec: Deck and Command Economy

Status: pure logic **implemented in M2.1** (see *As built* below); play execution and UI follow in 2.2–2.3. Values are defaults, exposed in `data/config/deck_rules.tres` (planned) and mirrored in [BALANCE.md](../BALANCE.md).

## Purpose
Define draw, hand, resources, card lifecycle and deck editing so DeckState/CommandPoints can be pure, tested logic.

## Rules (defaults)
- Deck: min 12, max 24 cards, starter 15 (3 × 5 designs; 16 is impossible with 5 designs and the 3-copy cap, decision D3, 2026-10-15). Max 3 copies per id (Legendary 1). Mission restrictions may ban tags/categories.
- Battle start: shuffle (seeded RNG), draw 4. Hand cap 5. Draw 1 card every 4 s while hand < cap. Draw timer pauses at cap.
- Command Points: start 5, cap 10, +1 per 3.0 s (tuned from the first draft's 1.5 s in M2.6, see ADR-011). Playing requires `cp >= cost`; cost is spent on a *valid* play only.
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

## As built (M2.1)
Code in `scripts/cards/`, data in `data/cards`, `data/decks`, `data/config/deck_rules.tres`; all loaded and validated by `ContentDb`.
- `CardDefinition` (`card_kind` DEPLOYMENT / OPERATION / SORTIE, `cost`, `lockout_s`, `max_copies` 1..3, `unit_id` + `unit_count` for deployments/sorties, `effect_id` for operations). Card behaviour is not in the definition.
- `DeckRules` (tunables above + `validate_deck`: size window, unknown ids, per-card copy limit — errors, never crashes). `DeckDefinition` = list of card ids.
- `DeckState` (draw pile / dense hand / discard / draw timer / lockouts; Fisher-Yates with the injected RNG, never the global one). Draw timer pauses at the hand cap and resumes from where it stopped; with nothing to draw it stays ready rather than banking time. Lockout timers end at exactly their duration (1e-6 tolerance, as for CP).
- `CommandPoints` (float pool, regen `1 / cp_regen_interval_s`, cap, all-or-nothing `spend`; 1e-6 tolerance so waiting one full regen interval buys exactly 1 CP).
- `CardPlayService.check` / `try_play`: reason priority is empty slot → unknown card → locked out → not enough CP → invalid target; only a fully valid play spends CP, moves the card to the discard and starts its lockout.
- `ContentDb` also rejects a card that can never be afforded (`cost > cp_cap`) and any shipped deck that breaks the rules. Card → `unit_id` reference checks arrive in 2.2 together with the tank/gatling/helicopter units they point to (until then three starter cards name units that do not exist yet; nothing instantiates them).
