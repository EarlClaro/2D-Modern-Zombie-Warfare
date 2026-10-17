# AGENTS.md — Instructions for Claude Code

Project: **Last Defense** (placeholder title) — 2D high-view isometric (2:1) military horde deckbuilder, Godot 4.x, typed GDScript, solo dev, PC/Steam first, offline.
Source of intent: [MasterPrompt.md](MasterPrompt.md). Where docs and the master prompt disagree, ask the user.

## Read first, every task
1. This file. 2. Relevant [docs/GDD.md](docs/GDD.md) sections. 3. [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md). 4. The feature's spec in `docs/specs/`. 5. [docs/ROADMAP.md](docs/ROADMAP.md) for current milestone.

## Environment (verified 2026-10-15)
- Godot **4.7.2-stable** (WinGet install). Console binary for CLI/headless:
  `C:\Users\ragg-sun-asterisk\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe`
  Below referred to as `$GODOT`. It is not on a short PATH name; use the full path or define the variable.
- Shell: PowerShell/Git Bash on Windows 11. Git repo initialised, no commits yet.
- Tests use a custom headless runner (ADR-006, [docs/TESTING.md](docs/TESTING.md)); GUT is not installed.

## Commands that exist today
- Import/parse check: `"$GODOT" --headless --path . --import --quit`
- Run game: `"$GODOT" --path .` (main scene = the start menu `scenes/menu/main_menu.tscn`; `-- --mission=<id>` skips the menu and goes straight into that mission, which the tools and scripted runs use; the battle scene is `scenes/battle/battle.tscn`); spike scene: `"$GODOT" --path . scenes/dev/iso_spike.tscn`
- Card mission (M2): `"$GODOT" --path . -- --mission=m2_card_defense` (1-5 or click a card to select, LMB to place, RMB/Esc to cancel; hand UI + previews; placed units act on their own, there are no move orders). Entity cards (M3.6): `--mission=x5_field_works` (Minefield / Noise Lure aimed at a cell, Convoy instant, Barracks placed). State cards (M3.5): `--mission=x4_field_orders` (order / supply / deck cards play on the click with no cell); `--doctrine=<card ids, comma separated>` adds doctrines to any mission.
- Stress mission: `"$GODOT" --path . -- --mission=s1_stress_horde`; measurements/sweeps: `tools/perf_sim.gd`, `tools/perf_flow.gd` (horde movement strategies, M3.1), `tools/perf_fps.gd` (windowed), `tools/tune.gd`, `tools/tune_pos.gd`, `tools/tune_cards.gd` (card-loop bots, one-card bench), `tools/perf_cards.gd` (windowed card mission) (usage in each file header; results in docs/BALANCE.md).
- Run tests: `"$GODOT" --headless --path . --script tests/run_tests.gd` (run `--import` first after adding `class_name` scripts). Always wrap in `timeout 120` when scripting. The runner fails any test during which an error-level message is logged, and runs tests in the first frame (`TestCase.tree` is a live SceneTree).

## Workflow rules
- One bounded task at a time. Spec → plan → small increment → tests → headless check → docs/changelog → report.
- Before editing: check `git status`; never discard user work; never overwrite existing files blindly.
- Present plan + file list before broad architectural changes.
- Do not mark anything done until acceptance criteria are checked. State which checks were actually run and which need manual verification (visuals, audio, feel).
- Never claim tests/gameplay passed unless the command was run and output seen.
- No unrelated refactors in a feature change. No speculative frameworks.
- Commit only when asked. Small commits, imperative messages.

## Hard boundaries (changing any needs an ADR + user approval)
- Camera/projection is **fixed 2:1 isometric**, no rotation. Do not change to top-down or side view.
- Genre stays real-time combined-arms deckbuilder; not a pure tower defense; no turn-based combat.
- Target PC first; offline single-player; no backend/multiplayer.
- No copied assets/IP from existing games. Record provenance in [docs/ASSETS.md](docs/ASSETS.md).

## Coding conventions
- Godot 4 typed GDScript everywhere (`var x: int`, `-> void`, typed arrays). `class_name` for reusable classes.
- Files `snake_case.gd`; classes `PascalCase`; signals past-tense `snake_case`; constants `UPPER_SNAKE`.
- **Ground-plane truth:** gameplay code uses ground coordinates (units = tiles, `Vector2`) plus separate altitude `z: float`. Only `IsoProjection` (`scripts/iso/iso_projection.gd`) contains projection math. No hard-coded `* 0.5`/`64`/`32` projection constants elsewhere.
- Content = typed `Resource` subclasses under `data/`, referenced by **stable string IDs** (never display names). Definitions are immutable at runtime; runtime state lives in separate runtime objects.
- Damage math is separate from projectile visuals. UI presents state; rules never live in UI scripts.
- Autoloads only for: game/session state, save, audio, scene transitions. Everything else is explicit references and signals.
- Randomness goes through an injected seedable `RandomNumberGenerator`.
- Don't create empty folders or boilerplate without a purpose.

## Definition of done (per feature)
Spec updated · tests added/updated and run · headless import has no errors/warnings introduced · manual checklist items listed · diff reviewed for scope · docs + CHANGELOG updated · report: files changed, behavior, commands run + results, manual checks pending, next step.
