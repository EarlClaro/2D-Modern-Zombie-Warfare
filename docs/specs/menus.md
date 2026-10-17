# Spec: Game shell (start menu, mission select, settings, pause)

Status: **v0.1, requested by the user on 2026-10-17** ("create the start menu, missions, settings and etc of whats needed"). Brought forward from Milestone 7 as a minimal, working shell; art, music, animation and a controls rebinding screen stay in Milestone 7. ADR-015. Built on branch `m3-menu` (worktree `../Modern Zombie Warfare 3.8`).

## Purpose
Today the game opens straight into one fixed mission and every other mission, option or card test needs command-line arguments. The player should be able to start the game, pick a mission, change basic settings, pause, leave a battle and quit without leaving the window.

## Scope
### Screens
| Screen | Content |
|---|---|
| **Main menu** (the new main scene) | Title, **Play**, **Settings**, **Quit**. A **Continue** button is not needed yet (no save system before Milestone 5). |
| **Mission select** | A list of every mission in `data/missions/`, grouped: **Missions** (ids starting `m` or `x`), **Test missions** (everything else, e.g. `s1_stress_horde`, `dev_*`). Ordered by id inside a group. Selecting one shows its facts, computed from data: name, duration, number of enemies, enemy types, deck name and size (or "no cards"), time of day and weather, core health. **Start** (also Enter / double-click) launches it; **Back** (Esc) returns. The last mission played is pre-selected. |
| **Settings** | Master volume (0 to 100 %), fullscreen, strike cutaway clips on/off, FPS counter on/off, **Reset to defaults**, **Back**. Applied immediately, saved when leaving the screen. Reachable from the main menu and from the pause menu. |
| **Pause menu** (in a battle) | Esc (when no card is selected and no clip is playing) pauses the whole battle and shows **Resume**, **Restart**, **Settings**, **Main menu**, **Quit**. Esc again resumes. Quit and Main menu act at once (no save to lose yet). |
| **Result panel** (existing) | Gains a **Main menu** button next to Restart. |

### Rules that must hold
- **Rules never depend on the shell.** The battle plays the same from the menu, from `--mission=...`, and in tests; nothing in `scripts/combat`, `scripts/cards` or `scripts/missions` reads settings or the session.
- **Pausing is real:** simulation, card timers, cutaway clips and the day cycle stop while paused (the scene tree is paused; the pause menu processes while paused). Nothing can be played while paused.
- **Command-line launch keeps working:** `godot --path . -- --mission=<id> [--seed=..] [--cutaways=off] [--doctrine=..]` still goes straight into that mission, bypassing the menu (the tools and scripted runs rely on it). Command-line options override settings.
- **Settings are plain data:** a `GameSettings` object with defaults, range clamping, and load/save to `user://settings.cfg` (Godot `ConfigFile`). A missing, unreadable or hand-edited file never crashes: bad or missing values fall back to defaults. Applying a setting (volume, window mode) is a separate step from storing it, so storing is testable without a window.
- **Session state** (the mission chosen in the menu, the seed) lives in `GameSession` (static, no autoload, no change to `project.godot` beyond the main scene), read once by the battle at start.
- Menus are built in code like the existing UI (`ui/`), keyboard and mouse operable (Tab / arrows / Enter / Esc), at the 1920 x 1080 design size with the existing `canvas_items` stretch.

## Data and code
- `scripts/core/game_settings.gd` (`GameSettings`): `master_volume` (0..1, default 0.8), `fullscreen` (false), `cutaways` (true), `show_fps` (true), `last_mission` (""); `clamp_all()`, `to_config()` / `from_config()`, `save()` / `load_from(path)`, `apply()` (bus volume in dB, window mode).
- `scripts/core/game_session.gd` (`GameSession`): static `settings` (lazy load), `pending_mission`, `pending_seed`; `take_pending()` hands them to the battle and clears them; scene paths as constants and `go_to_menu()` / `start_battle(mission_id)` helpers.
- `scripts/core/mission_listing.gd` (`MissionListing`): pure; `entries(db)` returns grouped, ordered entries; `facts(db, mission)` returns the lines shown on the details panel.
- `ui/main_menu.gd`, `ui/mission_select.gd`, `ui/settings_screen.gd`, `ui/pause_menu.gd`; `scenes/menu/main_menu.tscn`; `ui/result_panel.gd` gains the menu button.
- `data/decks/strikes.tres` and `data/missions/dev_strike_range.tres`: a deck of the six new strike cards plus artillery and riflemen, and a long mission with a steady stream of enemies, listed under **Test missions** so every cutaway clip can be tried in the real game.
- `project.godot`: main scene = the main menu.

## Non-goals
Campaign map, save slots, unlocks, deck editor (Milestone 5), key rebinding, resolution list and graphics presets, music, language options, difficulty selector (added to mission select in increment 3.9: three buttons or Left / Right, remembered in the settings), gamepad-specific layouts, animated backgrounds and final art (Milestone 7).

## Increments
1. `GameSettings`, `GameSession`, `MissionListing` with tests.
2. Main menu, mission select and settings screens; main scene switched; command-line quick launch kept.
3. Battle reads the session; pause menu; result panel menu button; FPS setting and cutaway setting honoured by the battle.
4. Strikes deck and test mission.
5. Docs, mutation check, screenshots.

## Acceptance criteria
1. Starting the game shows the main menu; Play, pick a mission, Start plays that mission; the result panel and pause menu lead back to the menu; Quit exits.
2. Every mission in `data/missions/` is listed once, in the right group, with facts that match its data.
3. Settings persist across runs; a corrupt file loads defaults without errors; volume and fullscreen take effect immediately.
4. Pause stops the battle completely (digest of elapsed time and enemy count unchanged while paused) and resume continues from the same state.
5. `--mission=` launches still skip the menu; the test suite and the tools are unaffected.
6. Test missions include a strike range where each new strike card can be played.
7. **Manual checks for the user:** look and feel of the menus, mouse and keyboard operation, that fullscreen and volume really change, the pause feel.

## Progress
All five increments are built on `m3-menu` (2026-10-17): `GameSettings`, `GameSession`, `MissionListing` (pure, tested), `MainMenu` / `MissionSelect` / `SettingsScreen` / `PauseMenu` / `UiKit`, the main scene switched in `project.godot`, `--mission=` quick launch kept, the battle reading the session, settings and a `pause_requested` signal, result panel Main menu button, deck `strikes` and mission `dev_strike_range`. Tests: 661 pass (24 new in `tests/test_menus.gd`). Screenshots of the home, select, settings and pause screens were looked at (`tools/menu_shots.gd`). Not done by me: real mouse and keyboard play, that fullscreen and volume change for real, the feel of pause.
