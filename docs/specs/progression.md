# Spec: Progression, rewards, deck editor and the local save (Milestone 5)

Status: **v0.1, decisions taken in a user interview on 2026-10-17** (ADR-017). Increments 5.1 to 5.5 are built. Source of intent: MasterPrompt.md section 12 and Milestone 5 ("mission reward choice, unlockable cards, deck editing between missions, basic upgrades, persistent local save, tests for save/load and progression edge cases").

## Purpose
Today every mission hands you a fixed deck and nothing you do is remembered. The player should keep what they earn: finish a mission, choose a new card, build a deck from the cards they own, and find the same collection and campaign position when the game is started again.

## Decisions (user interview, 2026-10-17)
| Question | Decision |
|---|---|
| Where does a mission's deck come from? | **Hybrid.** The existing missions (m1 to x11) keep their hand-tuned fixed decks, so the balance measured with the bots stays valid. A mission may instead be flagged **player deck** and then uses the deck built in the editor. Both kinds exist side by side. |
| What does a win give? | **Pick 1 of 3 cards.** Three locked cards are offered (deterministic: the same offer after a reload); no currency in the first version. |
| Campaign shape | **Linear chain.** The player starts with the cards of the `starter` deck; missions unlock one after another in a fixed order, finished ones can be replayed. Test and dev missions are hidden unless a setting turns them on. |
| Save profiles | **One profile**, a versioned file with an automatic backup, and a "reset progress" button. |

## Scope
### Player profile (`user://profile.json`)
Plain data, separate from `GameSettings` (options stay in `settings.cfg`; progress is not an option). Fields in version 1:
- `version` (int), `reward_seed` (int, drawn once when the profile is created),
- `collection`: ids of owned cards (owning a card gives every copy up to its `max_copies`),
- `deck`: the player's deck (card ids, duplicates are copies), `doctrines`: the doctrine cards picked for the next player-deck mission,
- `missions`: for each finished mission id: `wins`, `best_core` (0..1 of core health left at the best win), `best_difficulty` (the hardest level it was won on),
- `rewards`: for each finished mission id: the card the player took ("" while the offer is unanswered).
Derived, never stored: which missions are unlocked, which cards are still locked.

### Safe saving and loading (the Milestone 5 test list)
- **Atomic write:** write `profile.json.tmp`, then rename over `profile.json`; the previous good file is first copied to `profile.json.bak`.
- **Load order:** `profile.json`, else `profile.json.bak`, else a fresh profile. A file that fails to parse is moved aside to `profile.corrupt.json` (never silently overwritten), and the player is told in the main menu.
- **Versioning:** `version` starts at 1. `ProfileMigration` upgrades an older file one step at a time (a file without `version` counts as version 0 and is migrated too). A file with a **higher** version than the game knows is loaded read-only: kept in memory, never written back.
- **Tolerance:** a missing field takes its default; a wrong-typed value takes its default; an unknown card or mission id is dropped on load (content can change between versions) and the rest of the profile is kept; a deck that is no longer legal is replaced by the starter deck; nothing hand-edited can crash the game.

### Campaign and unlocks
- `CampaignDefinition` (`data/campaign/main.tres`): the ordered list of mission ids. A mission is unlocked when it is first in the list or the one before it has `wins >= 1`. The start state (nothing finished) unlocks only the first.
- Mission select shows locked missions greyed with "Finish <name> first", finished ones with a mark and the best result. Test missions are listed only when `GameSettings.show_test_missions` is on (default off, a checkbox in Settings). The command line (`--mission=<id>`) ignores all locks, as it ignores the menu.
- Recording a result: a win updates `wins`, `best_core`, `best_difficulty`; a defeat records nothing. Battles started from the command line record nothing at all (tools and bots must not touch a player's file).

### Rewards
- **Reward pools** are data in the campaign (`CampaignDefinition.reward_pools`: mission id to card ids), not on the mission file, because the map generators rewrite mission files and would drop them (changed in 5.3). After the **first** win of a mission with an unanswered offer, the result panel shows three cards from the pool that the player does not own yet (fewer if fewer remain, none if none), chosen by a shuffle seeded from `reward_seed` and the mission id. The three cards are saved in the profile (`offers`) the moment the mission is won, so quitting before choosing does not lose or re-roll it; the choice is shown in the result panel, and a reward still waiting shows on the mission in mission select (`[reward waiting]`, the three cards under the facts). A profile written before rewards existed gets its offers for already-won missions when it is loaded. A card can only be taken from the saved offer, once.
- Taking a card adds it to `collection`. Replays of a won mission offer nothing. Pools are data and are written so the early campaign offers simple cards and the late campaign offers the strike and high-tech cards (the three heaviest strikes are the last rewards).
- Rewards never touch a fixed-deck mission's own deck; they only widen what the editor can pick.

### Deck editor ("Deck" on the main menu)
- Two lists: the collection on the left (cards with their cost and how many copies are allowed), the current deck on the right. Add a copy, remove a copy, "Reset to starter deck". Every change is validated with the existing `DeckRules` (12 to 24 cards, copies within `max_copies`, only owned cards); an illegal change is refused with the reason shown. Saved on every change.
- **Doctrine picker:** doctrine cards the player owns (e.g. Hollow Points) can be marked for the next player-deck mission (one at a time for now), shown on the same screen.
- Pure logic lives in `DeckBuilder` (add, remove, validate against the collection and rules, auto-repair); the screen only presents it.

### Player-deck missions
- `MissionDefinition.deck_source`: `FIXED` (default, today's behaviour, `deck_id` is the deck) or `PLAYER` (the profile's deck and doctrines are used; `deck_id` is then the fallback for command-line and test runs).
- The battle receives the deck the way it receives the mission today; nothing in `scripts/combat` or `scripts/cards` reads the profile. The profile is read by `GameSession` when the menu starts a battle, and by the result panel when it ends.
- A first player-deck mission (increment 5.6) is balanced against the bots with three sample decks built from the starting collection plus rewards, because the player's choice changes every number in BALANCE.md.

### Upgrades (increment 5.5; decided in a user interview on 2026-10-17)
Decisions: (1) **obtained as a reward option**: a pick-1-of-3 offer may contain an upgrade for a card the player owns, next to new cards, so it is "a new card or a better card"; no currency; (2) **one tier, two exclusive branches** per card (more tiers can be added later); (3) **the five starter cards first**; (4) **they apply only on player-deck missions**: fixed-deck missions and command-line runs never see them, so every bot number in BALANCE.md stays valid.
- `UpgradeDefinition` (`data/upgrades/*.tres`, written by `tools/gen_upgrades.gd`): `card_id` plus a list of `UpgradePatch`es (target kind weapon / unit / operation / card, target id, property, ADD / MUL / SET, value), validated against the real definitions when the content loads.
- `UpgradeApplier.patched_db(db, ids)` builds a copy of the content in which only the changed definitions are duplicated and patched; the shared definitions are never touched. The battle scene hands the patched copy to the battle for a menu-started player-deck mission.
- The profile keeps `unlocked_upgrades` and `equipped` (card id to upgrade id, one per card). Taking an upgrade unlocks it and equips it when the card has none; the deck screen switches the branch on and off at will (free, saved at once). The reward picker offers an upgrade only for an owned card and never twice.
- Reward pools: m1 offers the Rifle Squad upgrades next to its cards, m2 the Gatling, m3 the Tank, x1 the Artillery Strike, x2 the Helicopter.
First-guess numbers (not swept; the bot check is 5.6):
| Card | Branch A | Branch B |
|---|---|---|
| Rifle Squad | **Long Barrels**: rifle range +2 tiles | **Body Armour**: rifleman health x1.4, armour +1 |
| Gatling Gun | **Crowd Spray**: splash 0.9 tiles, damage x0.8 | **Armour-Piercing Belt**: damage x2.2, fire rate x0.6, prefers armoured targets |
| Tank | **High-Explosive Shells**: blast +0.9 tiles, damage x0.9 | **Reactive Armour**: armour +3, health x1.25 |
| Artillery Strike | **Saturation Barrage**: +4 shells, +1 tile area, shell damage x0.85 | **Heavy Shells**: shell damage x1.6, blast +0.4, lands 0.4 s sooner |
| Helicopter Support | **Extended Station**: +6 s on station, health x1.2 | **Rocket Pods**: +4 rockets, rocket damage x1.3 |

## Rules that must hold
- **Rules never depend on the profile.** The battle, combat and card code stay as testable as today: a battle is given a deck and doctrines, never a profile. Profile-aware code lives in `scripts/progression/`, `GameSession` and `ui/`.
- **Autoloads:** none added; the profile lives in `GameSession` like the settings (ADR-015).
- **Determinism:** the same `reward_seed` and mission give the same offer; tests seed it.
- **Tests and tools never write `user://profile.json`:** every store function takes a path, and tests use a temp path.
- **Balance stays measurable:** fixed-deck missions ignore the collection, so the bot numbers in BALANCE.md remain valid. The tools keep using `--mission=<id>` and the mission's own deck.

## Data and code (planned)
- `scripts/progression/player_profile.gd` (`PlayerProfile`): the data, `to_dict()` / `from_dict()` with clamping and defaults, `sanitize(db)` (drop unknown ids, repair the deck), helpers (`owns`, `is_unlocked`, `record_win`).
- `scripts/progression/profile_store.gd` (`ProfileStore`): `save(profile, path)`, `load_from(path)`, atomic write, backup, corrupt-file handling, read-only flag.
- `scripts/progression/profile_migration.gd` (`ProfileMigration`): `upgrade(dict) -> dict`, one function per version step.
- `scripts/progression/campaign_definition.gd` (`CampaignDefinition`) and `data/campaign/main.tres`; `ContentDb` loads and validates it (every id must be a mission).
- `scripts/progression/reward_picker.gd` (`RewardPicker`): pure, `offer(pool, owned, seed, mission_id) -> Array[String]`.
- `scripts/progression/deck_builder.gd` (`DeckBuilder`): pure deck editing and validation.
- `CampaignDefinition.reward_pools` (checked by the definition and by `ContentDb`); `MissionDefinition.deck_source` (enum, 5.4).
- `GameSession`: `profile()` (lazy load), `set_profile()`, deck hand-over for player-deck missions, result recording.
- `ui/deck_screen.gd`, changes to `ui/main_menu.gd` (Deck button, "progress file was damaged" note), `ui/mission_select.gd` (locks, marks), `ui/settings_screen.gd` (test missions, reset progress with a confirmation), `ui/result_panel.gd` (reward choice).
- `docs/ARCHITECTURE.md`, `docs/BALANCE.md`, `docs/ROADMAP.md`, `CHANGELOG.md`, `docs/DECISIONS.md` (ADR-017).

## Non-goals (this milestone)
Currency, shops, research tree, military doctrine trees, rarity-weighted drops, multiple save slots, cloud save, endless mode and high scores, medals (Bronze / Silver / Gold need the objective model of Milestone 3B and the mission types of Milestone 4), campaign map art, key rebinding. The result panel's reward choice is functional, not final art (Milestone 7).

## Increments
1. **5.1 Profile and safe save (done 2026-10-17, 24 tests):** `PlayerProfile`, `ProfileStore`, `ProfileMigration`, `GameSession.profile()`; tests for round trip, defaults, wrong types, unknown ids, corrupt file, backup fallback, future version read-only, migration from version 0, atomic write.
2. **5.2 Campaign and unlocks (done 2026-10-17, 18 tests):** `CampaignDefinition`, unlock rules, recording a win, mission select locks and marks, "show test missions" setting, "reset progress".
3. **5.3 Rewards (done 2026-10-17, 19 tests):** `reward_pools`, `RewardPicker`, offer saved on win, `RewardChooser` in the result panel and in mission select, collection grows; pools written for all 14 campaign missions (every non-starter card can be won; Nuclear Bomb and Satellite Laser only in the last two missions).
4. **5.4 Deck editor and player-deck missions (done 2026-10-17, 21 tests):** `DeckBuilder`, `DeckScreen` (main menu "Deck"), doctrine picker, `MissionDefinition.deck_source`, `BattleController.deck_override`; the test mission `dev_player_deck` (a copy of m2 on the player's deck) lets the editor be tried end to end. Rules as built: a change that would make the deck illegal is refused with the reason (so a swap is "add, then remove"); the doctrine is one card at a time; only a battle started from the menu uses the player's deck, the command line keeps the mission's own `deck_id`.
5. **5.5 Upgrades (done 2026-10-17, 22 tests):** interview, then `UpgradeDefinition` / `UpgradePatch` / `UpgradeApplier`, ten upgrades, rewards, the deck-screen switches.
6. **5.6 First player-deck mission and hand-over:** one new mission balanced with bots on three sample decks; docs; manual checklist for the user.

Each increment ends with tests, a headless import with no new warnings, docs and changelog.

## Manual checks the user will have to do
Mouse and keyboard on the deck screen; whether the reward choice reads; whether locked missions are clear; that quitting the game and starting it again keeps the collection, deck and campaign position; the "reset progress" button.
