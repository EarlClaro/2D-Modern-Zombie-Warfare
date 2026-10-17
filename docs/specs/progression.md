# Spec: Progression, rewards, deck editor and the local save (Milestone 5)

Status: **v0.1, decisions taken in a user interview on 2026-10-17** (ADR-017). Increments 5.1 and 5.2 are built. Source of intent: MasterPrompt.md section 12 and Milestone 5 ("mission reward choice, unlockable cards, deck editing between missions, basic upgrades, persistent local save, tests for save/load and progression edge cases").

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
- `MissionDefinition.reward_pool`: card ids this mission can offer. After the **first** win of a mission with an unanswered offer, the result panel shows three cards from the pool that the player does not own yet (fewer if fewer remain, none if none), chosen by a shuffle seeded from `reward_seed` and the mission id. The offer is saved the moment the mission is won, so quitting before choosing does not lose or re-roll it; it waits in the result panel (and on the mission entry in mission select) until answered.
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

### Upgrades (increment 5.5; design confirmed with the user before it starts)
Master prompt wants meaningful, branching card upgrades (a machine gun that becomes crowd-control or armour-piercing). With no currency in the first version, the proposed form is: **upgrades are rewards too.** A reward offer may include an upgrade for a card the player owns; each card has at most two mutually exclusive branches; an upgrade is a data-driven patch to the unit's or weapon's numbers applied when the battle starts. The profile gains `upgrades` (card id to branch id). Details (which cards, which numbers, whether to add salvage) are decided with the user at the start of 5.5, so this section is a proposal, not a promise.

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
- `MissionDefinition`: `reward_pool: PackedStringArray`, `deck_source` (enum); `ContentDb` checks the pool ids are cards.
- `GameSession`: `profile()` (lazy load), `set_profile()`, deck hand-over for player-deck missions, result recording.
- `ui/deck_screen.gd`, changes to `ui/main_menu.gd` (Deck button, "progress file was damaged" note), `ui/mission_select.gd` (locks, marks), `ui/settings_screen.gd` (test missions, reset progress with a confirmation), `ui/result_panel.gd` (reward choice).
- `docs/ARCHITECTURE.md`, `docs/BALANCE.md`, `docs/ROADMAP.md`, `CHANGELOG.md`, `docs/DECISIONS.md` (ADR-017).

## Non-goals (this milestone)
Currency, shops, research tree, military doctrine trees, rarity-weighted drops, multiple save slots, cloud save, endless mode and high scores, medals (Bronze / Silver / Gold need the objective model of Milestone 3B and the mission types of Milestone 4), campaign map art, key rebinding. The result panel's reward choice is functional, not final art (Milestone 7).

## Increments
1. **5.1 Profile and safe save (done 2026-10-17, 24 tests):** `PlayerProfile`, `ProfileStore`, `ProfileMigration`, `GameSession.profile()`; tests for round trip, defaults, wrong types, unknown ids, corrupt file, backup fallback, future version read-only, migration from version 0, atomic write.
2. **5.2 Campaign and unlocks (done 2026-10-17, 18 tests):** `CampaignDefinition`, unlock rules, recording a win, mission select locks and marks, "show test missions" setting, "reset progress".
3. **5.3 Rewards:** `reward_pool`, `RewardPicker`, offer saved on win, result-panel choice, collection grows; reward pools written for the existing campaign.
4. **5.4 Deck editor and player-deck missions:** `DeckBuilder`, deck screen, doctrine picker, `deck_source`, the battle gets the player's deck.
5. **5.5 Upgrades:** short interview with the user first; then the data model, tests and the first few upgrades.
6. **5.6 First player-deck mission and hand-over:** one new mission balanced with bots on three sample decks; docs; manual checklist for the user.

Each increment ends with tests, a headless import with no new warnings, docs and changelog.

## Manual checks the user will have to do
Mouse and keyboard on the deck screen; whether the reward choice reads; whether locked missions are clear; that quitting the game and starting it again keeps the collection, deck and campaign position; the "reset progress" button.
